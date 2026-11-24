// SentinelX — Phase 4.3.1: Camera Ingestion & Temporal Rolling Buffer Test Suite
// Verifies hardware frame metadata, bounded rolling capacity of 16, monotonic timestamps,
// pre-16 padding behavior, ImageNet planar tensor construction, memory stability, and error states.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:sentinel_x/core/camera/camera_frame.dart';
import 'package:sentinel_x/core/camera/temporal_frame_buffer.dart';
import 'package:sentinel_x/core/camera/camera_ingestion_service.dart';

void main() {
  group('Phase 4.3.1 — Camera Frame & Temporal Rolling Buffer Tests', () {
    /// Helper to generate a test frame with custom index, timestamp, and pixel pattern
    CameraFrame createTestFrame({
      required int index,
      required DateTime timestamp,
      int width = 224,
      int height = 224,
      String cameraId = 'CAM-001',
      String deviceName = 'HP TrueVision HD Camera',
      int latencyMs = 25,
      int fillByte = 128,
    }) {
      final bytes = Uint8List(width * height * 3);
      bytes.fillRange(0, bytes.length, fillByte);
      return CameraFrame(
        cameraId: cameraId,
        deviceName: deviceName,
        frameIndex: index,
        timestamp: timestamp,
        width: width,
        height: height,
        pixelFormat: 'RGB888',
        rgbBytes: bytes,
        acquisitionLatencyMs: latencyMs,
        status: CameraFrameStatus.valid,
      );
    }

    // Test 1: CameraFrame metadata fidelity and planar ImageNet normalization
    test('Test 1: CameraFrame retains full metadata and computes ImageNet planar Float32 tensor', () {
      final now = DateTime.now().toUtc();
      final frame = createTestFrame(
        index: 42,
        timestamp: now,
        latencyMs: 18,
        fillByte: 255, // All white pixels
      );

      expect(frame.cameraId, equals('CAM-001'));
      expect(frame.deviceName, equals('HP TrueVision HD Camera'));
      expect(frame.frameIndex, equals(42));
      expect(frame.timestamp, equals(now));
      expect(frame.width, equals(224));
      expect(frame.height, equals(224));
      expect(frame.pixelFormat, equals('RGB888'));
      expect(frame.byteSize, equals(224 * 224 * 3)); // 150,528 bytes
      expect(frame.acquisitionLatencyMs, equals(18));
      expect(frame.status, equals(CameraFrameStatus.valid));

      // ImageNet standardization:
      // Red: (1.0 - 0.485) / 0.229 = 0.515 / 0.229 ≈ 2.2489
      // Green: (1.0 - 0.456) / 0.224 = 0.544 / 0.224 ≈ 2.4285
      // Blue: (1.0 - 0.406) / 0.225 = 0.594 / 0.225 ≈ 2.6400
      final planarTensor = frame.toPlanarNormalized();
      expect(planarTensor.length, equals(3 * 224 * 224));

      final channelSize = 224 * 224;
      expect(planarTensor[0], closeTo(2.2489, 0.01)); // R channel
      expect(planarTensor[channelSize], closeTo(2.4285, 0.01)); // G channel
      expect(planarTensor[2 * channelSize], closeTo(2.6400, 0.01)); // B channel
    });

    // Test 2: TemporalFrameBuffer capacity enforcement (bounded rolling buffer)
    test('Test 2: TemporalFrameBuffer maintains strict rolling capacity of exactly 16 frames', () {
      final buffer = TemporalFrameBuffer(capacity: 16);
      expect(buffer.isReady, isFalse);
      expect(buffer.currentCount, equals(0));

      final baseTime = DateTime.now().toUtc();

      // Ingest 25 frames sequentially
      for (int i = 1; i <= 25; i++) {
        buffer.addFrame(createTestFrame(
          index: i,
          timestamp: baseTime.add(Duration(milliseconds: i * 33)),
        ));
      }

      // Must clamp to 16 frames max
      expect(buffer.currentCount, equals(16));
      expect(buffer.isReady, isTrue);
      expect(buffer.totalIngestedCount, equals(25));
      expect(buffer.droppedFramesCount, equals(9)); // 25 - 16 = 9 evicted

      final storedFrames = buffer.getFrames();
      expect(storedFrames.length, equals(16));
      // First frame in buffer should be frame index 10 (earliest non-evicted)
      expect(storedFrames.first.frameIndex, equals(10));
      // Last frame in buffer should be frame index 25 (most recent)
      expect(storedFrames.last.frameIndex, equals(25));
    });

    // Test 3: Chronological timestamp ordering
    test('Test 3: TemporalFrameBuffer preserves strict monotonic timestamp ordering', () {
      final buffer = TemporalFrameBuffer(capacity: 16);
      final startTime = DateTime.utc(2026, 11, 22, 12, 0, 0);

      for (int i = 0; i < 16; i++) {
        buffer.addFrame(createTestFrame(
          index: i,
          timestamp: startTime.add(Duration(milliseconds: i * 100)),
        ));
      }

      final frames = buffer.getFrames();
      for (int i = 0; i < frames.length - 1; i++) {
        final current = frames[i].timestamp;
        final next = frames[i + 1].timestamp;
        expect(current.isBefore(next) || current.isAtSameMomentAs(next), isTrue,
            reason: 'Frame at $i ($current) must not be after frame at ${i + 1} ($next)');
      }
    });

    // Test 4: Pre-16 frame behavior (repeats earliest frame to build 16 frames)
    test('Test 4: Pre-16 frame warmup: getPaddedSequence pads earliest frame to yield exactly 16 frames', () {
      final buffer = TemporalFrameBuffer(capacity: 16);
      final startTime = DateTime.utc(2026, 11, 22, 12, 0, 0);

      // Ingest only 4 frames
      for (int i = 1; i <= 4; i++) {
        buffer.addFrame(createTestFrame(
          index: i,
          timestamp: startTime.add(Duration(milliseconds: i * 100)),
        ));
      }

      expect(buffer.currentCount, equals(4));
      expect(buffer.isReady, isFalse);

      final paddedSequence = buffer.getPaddedSequence();
      expect(paddedSequence.length, equals(16));

      // First 12 frames should be padded clones of frame #1
      for (int i = 0; i < 12; i++) {
        expect(paddedSequence[i].status, equals(CameraFrameStatus.padded));
        expect(paddedSequence[i].rgbBytes, equals(paddedSequence[12].rgbBytes));
      }

      // Last 4 frames should be the genuine valid frames #1, #2, #3, #4
      expect(paddedSequence[12].status, equals(CameraFrameStatus.valid));
      expect(paddedSequence[12].frameIndex, equals(1));
      expect(paddedSequence[15].status, equals(CameraFrameStatus.valid));
      expect(paddedSequence[15].frameIndex, equals(4));
    });

    // Test 5: Full 1x16x3x224x224 tensor construction
    test('Test 5: toTensor1x16x3x224x224 generates exact 2,408,448 Float32 elements for ONNX graph', () {
      final buffer = TemporalFrameBuffer(capacity: 16);
      final startTime = DateTime.utc(2026, 11, 22, 12, 0, 0);

      for (int i = 0; i < 16; i++) {
        buffer.addFrame(createTestFrame(
          index: i,
          timestamp: startTime.add(Duration(milliseconds: i * 33)),
          fillByte: i * 15,
        ));
      }

      final tensor = buffer.toTensor1x16x3x224x224();
      // 1 * 16 * 3 * 224 * 224 = 2,408,448 floats (~9.63 MB)
      expect(tensor.length, equals(2408448));
      // First frame was 0 -> normalized R: (0 - 0.485)/0.229 = -2.1179
      expect(tensor[0], closeTo(-2.1179, 0.01));
    });

    // Test 6: Memory stability and bounding (No memory growth on long-running capture)
    test('Test 6: Frame-buffer memory usage is strictly bounded at ~2.30 MB over 1,000 frames', () {
      final buffer = TemporalFrameBuffer(capacity: 16);
      final startTime = DateTime.utc(2026, 11, 22, 12, 0, 0);

      // Ingest 1,000 frames continuously
      for (int i = 0; i < 1000; i++) {
        buffer.addFrame(createTestFrame(
          index: i,
          timestamp: startTime.add(Duration(milliseconds: i * 33)),
        ));
      }

      expect(buffer.currentCount, equals(16));
      expect(buffer.totalIngestedCount, equals(1000));
      expect(buffer.droppedFramesCount, equals(984)); // 1000 - 16 = 984

      // 16 frames * 224 * 224 * 3 bytes = 2,408,448 bytes (~2.30 MB)
      final expectedMemory = 16 * (224 * 224 * 3);
      expect(buffer.memoryUsageBytes, equals(expectedMemory));
      expect(buffer.memoryUsageBytes / (1024 * 1024), closeTo(2.30, 0.05));
    });

    // Test 7: Device enumeration failure handling
    test('Test 7: CameraIngestionService handles no device detected gracefully', () async {
      final service = CameraIngestionService(
        cameraId: 'CAM-001',
      );

      final success = await service.initialize(injectedCameras: const <CameraDescription>[]);
      expect(success, isFalse);
      expect(service.status, equals(CameraConnectionStatus.noDeviceFound));
      expect(service.currentTelemetry.errorMessage, contains('No hardware camera device detected'));

      await service.dispose();
    });

    // Test 8: Buffer rejection on mismatched frame dimensions
    test('Test 8: TemporalFrameBuffer rejects frames with incompatible spatial dimensions', () {
      final buffer = TemporalFrameBuffer(capacity: 16);
      final invalidFrame = createTestFrame(
        index: 1,
        timestamp: DateTime.now().toUtc(),
        width: 640, // Expected 224
        height: 480,
      );

      expect(() => buffer.addFrame(invalidFrame), throwsArgumentError);
    });

    // Test 9: Telemetry metric accuracy
    test('Test 9: CameraTelemetry reports accurate buffer readiness, memory, and latency metrics', () {
      final buffer = TemporalFrameBuffer(capacity: 16);
      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);

      for (int i = 1; i <= 8; i++) {
        buffer.addFrame(createTestFrame(
          index: i,
          timestamp: baseTime.add(Duration(milliseconds: i * 100)),
          latencyMs: 22,
        ));
      }

      final telemetry = CameraTelemetry(
        status: CameraConnectionStatus.streaming,
        deviceName: 'HP TrueVision HD Camera',
        cameraId: 'CAM-001',
        measuredFps: 10.0,
        lastAcquisitionLatencyMs: 22,
        bufferCount: buffer.currentCount,
        isBufferReady: buffer.isReady,
        totalCaptured: 8,
        droppedFrames: buffer.droppedFramesCount,
        initializationTimeMs: 145,
        reconnectCount: 0,
        memoryUsageBytes: buffer.memoryUsageBytes,
      );

      expect(telemetry.cameraId, equals('CAM-001'));
      expect(telemetry.deviceName, equals('HP TrueVision HD Camera'));
      expect(telemetry.bufferCount, equals(8));
      expect(telemetry.isBufferReady, isFalse); // Only 8/16
      expect(telemetry.lastAcquisitionLatencyMs, equals(22));
      expect(telemetry.initializationTimeMs, equals(145));
      expect(telemetry.memoryUsageBytes, equals(8 * 150528));
    });

    // Test 10: Clean resource disposal resets all buffer state
    test('Test 10: Buffer disposal and clear resets memory to 0 bytes and unreadies state', () {
      final buffer = TemporalFrameBuffer(capacity: 16);
      for (int i = 0; i < 16; i++) {
        buffer.addFrame(createTestFrame(
          index: i,
          timestamp: DateTime.now().toUtc().add(Duration(milliseconds: i * 33)),
        ));
      }

      expect(buffer.isReady, isTrue);
      expect(buffer.memoryUsageBytes, greaterThan(0));

      buffer.clear();
      expect(buffer.currentCount, equals(0));
      expect(buffer.isReady, isFalse);
      expect(buffer.memoryUsageBytes, equals(0));
      expect(buffer.totalIngestedCount, equals(0));
      expect(buffer.droppedFramesCount, equals(0));
    });
  });
}
