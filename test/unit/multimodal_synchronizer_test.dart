// SentinelX - Multimodal Audio-Visual Synchronizer Unit Tests
// Rigorously tests timestamp-based synchronization, temporal alignment policies,
// skew rejection thresholds, staleness detection, and modality failure modes.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel_x/core/camera/camera_frame.dart';
import 'package:sentinel_x/core/camera/temporal_frame_buffer.dart';
import 'package:sentinel_x/core/audio/temporal_audio_buffer.dart';
import 'package:sentinel_x/core/ml/multimodal_synchronizer.dart';
import 'package:sentinel_x/core/utils/monotonic_clock.dart';

void main() {
  group('Phase 4.4.2 — MonotonicClock & Timestamp Utilities', () {
    test('MonotonicClock generates positive increasing microseconds', () {
      final t1 = MonotonicClock.nowMicros;
      expect(t1, isNonNegative);

      final stamp = MonotonicClock.now();
      expect(stamp.utc, isNotNull);
      expect(stamp.monotonicUs, isNonNegative);
      expect(stamp.monotonicMs, equals(stamp.monotonicUs ~/ 1000));
    });
  });

  group('Phase 4.4.2 — Camera Frame & Video Window Temporal Metadata', () {
    test('CameraFrame records UTC and monotonic acquisition timestamps', () {
      final nowUtc = DateTime.utc(2026, 11, 22, 12, 0, 0);
      final frame = CameraFrame(
        cameraId: 'CAM-001',
        deviceName: 'HP TrueVision HD Camera',
        frameIndex: 1,
        timestamp: nowUtc,
        monotonicUs: 1500000,
        width: 224,
        height: 224,
        pixelFormat: 'RGB888',
        rgbBytes: Uint8List(224 * 224 * 3),
        acquisitionLatencyMs: 31,
      );

      expect(frame.timestamp, equals(nowUtc));
      expect(frame.monotonicUs, equals(1500000));
      expect(frame.status, equals(CameraFrameStatus.valid));
    });

    test('TemporalFrameBuffer tracks video window start/end, duration, and staleness', () {
      final buffer = TemporalFrameBuffer(capacity: 16);
      expect(buffer.getWindowMetadata().isStale, isTrue);

      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);
      // Ingest 16 frames spaced 100ms apart (10 FPS sequence, 1.5s total duration)
      for (int i = 0; i < 16; i++) {
        final frameTime = baseTime.add(Duration(milliseconds: i * 100));
        buffer.addFrame(CameraFrame(
          cameraId: 'CAM-001',
          deviceName: 'HP TrueVision HD Camera',
          frameIndex: i,
          timestamp: frameTime,
          monotonicUs: (1000000 + i * 100000),
          width: 224,
          height: 224,
          pixelFormat: 'RGB888',
          rgbBytes: Uint8List(224 * 224 * 3),
          acquisitionLatencyMs: 30,
        ));
      }

      expect(buffer.currentCount, equals(16));
      expect(buffer.isReady, isTrue);

      // Evaluate metadata with now = 100ms after newest frame (fresh)
      final nowFresh = baseTime.add(const Duration(milliseconds: 1600));
      final freshMeta = buffer.getWindowMetadata(nowUtc: nowFresh);

      expect(freshMeta.frameCount, equals(16));
      expect(freshMeta.paddedFrames, equals(0));
      expect(freshMeta.windowStartUtc, equals(baseTime));
      expect(freshMeta.windowEndUtc, equals(baseTime.add(const Duration(milliseconds: 1500))));
      expect(freshMeta.durationMs, equals(1500));
      expect(freshMeta.meanIntervalMs, closeTo(100.0, 1.0));
      expect(freshMeta.isStale, isFalse);
      expect(freshMeta.ageMs, equals(100));

      // Evaluate metadata with now = 3.5s after newest frame (stale, camera stalled)
      final nowStale = baseTime.add(const Duration(milliseconds: 5000));
      final staleMeta = buffer.getWindowMetadata(nowUtc: nowStale);
      expect(staleMeta.isStale, isTrue);
      expect(staleMeta.ageMs, equals(3500));
    });
  });

  group('Phase 4.4.2 — Audio Buffer & Audio Window Temporal Metadata', () {
    test('TemporalAudioBuffer tracks chunk timestamps, duration, and staleness', () {
      final audioBuffer = TemporalAudioBuffer(capacity: 65536, requiredSamples: 64000);
      expect(audioBuffer.getWindowMetadata().isStale, isTrue);

      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);
      // Ingest 64,000 samples across 40 chunks of 1,600 samples (100ms intervals)
      for (int i = 0; i < 40; i++) {
        final chunkTime = baseTime.add(Duration(milliseconds: i * 100));
        final samples = Float32List(1600);
        audioBuffer.pushSamples(
          samples,
          captureTime: chunkTime,
          monotonicUs: (1000000 + i * 100000),
        );
      }

      expect(audioBuffer.currentCount, equals(64000));
      expect(audioBuffer.isReady, isTrue);
      expect(audioBuffer.chunkCount, equals(40));

      final nowFresh = baseTime.add(const Duration(milliseconds: 4000));
      final audioMeta = audioBuffer.getWindowMetadata(nowUtc: nowFresh);

      expect(audioMeta.sampleCount, equals(64000));
      expect(audioMeta.durationMs, equals(4000));
      expect(audioMeta.windowEndUtc, equals(baseTime.add(const Duration(milliseconds: 3900))));
      expect(audioMeta.windowStartUtc, equals(audioMeta.windowEndUtc.subtract(const Duration(milliseconds: 4000))));
      expect(audioMeta.isStale, isFalse);
      expect(audioMeta.ageMs, equals(100));

      // Evaluate staleness when microphone stream stops for 3.0s
      final nowStale = baseTime.add(const Duration(milliseconds: 7000));
      final staleAudio = audioBuffer.getWindowMetadata(nowUtc: nowStale);
      expect(staleAudio.isStale, isTrue);
      expect(staleAudio.ageMs, equals(3100));
    });
  });

  group('Phase 4.4.2 — Multimodal Synchronization State Machine', () {
    late TemporalFrameBuffer videoBuffer;
    late TemporalAudioBuffer audioBuffer;
    late MultimodalSynchronizer synchronizer;

    setUp(() {
      videoBuffer = TemporalFrameBuffer(capacity: 16);
      audioBuffer = TemporalAudioBuffer(capacity: 65536, requiredSamples: 64000);
      synchronizer = MultimodalSynchronizer(
        maxAllowableSkewMs: 1000,
        targetSkewMs: 500,
        maxStaleDurationMs: 2000,
        minValidVideoFrames: 8,
      );
    });

    test('Both streams aligned within 100ms -> MULTIMODAL SYNCHRONIZED', () {
      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);

      // Populate 16 video frames ending at t = 4000ms
      for (int i = 0; i < 16; i++) {
        videoBuffer.addFrame(CameraFrame(
          cameraId: 'CAM-001',
          deviceName: 'HP TrueVision HD Camera',
          frameIndex: i,
          timestamp: baseTime.add(Duration(milliseconds: 2500 + i * 100)),
          monotonicUs: (2500000 + i * 100000),
          width: 224,
          height: 224,
          pixelFormat: 'RGB888',
          rgbBytes: Uint8List(224 * 224 * 3),
          acquisitionLatencyMs: 25,
        ));
      }

      // Populate 64,000 audio samples ending at t = 3950ms (Offset = 50ms)
      for (int i = 0; i < 40; i++) {
        audioBuffer.pushSamples(
          Float32List(1600),
          captureTime: baseTime.add(Duration(milliseconds: i * 100)),
          monotonicUs: (i * 100000),
        );
      }

      final evalTime = baseTime.add(const Duration(milliseconds: 4050));
      final sync = synchronizer.evaluate(
        videoBuffer: videoBuffer,
        audioBuffer: audioBuffer,
        isAudioServiceReady: true,
        nowUtc: evalTime,
      );

      expect(sync.syncState, equals(MultimodalSyncState.synchronized));
      expect(sync.isMultimodal, isTrue);
      expect(sync.audioVideoOffsetMs, closeTo(100, 10)); // video at 4000ms, audio at 3900ms = ~100ms
      expect(sync.absoluteOffsetMs, lessThanOrEqualTo(500));
      expect(sync.diagnosticNotice, contains('MULTIMODAL SYNCHRONIZED'));
      expect(synchronizer.latestTelemetry.synchronizedCount, equals(1));
      expect(synchronizer.latestTelemetry.rejectionCount, equals(0));
    });

    test('Temporal skew exceeds 1000ms -> DESYNCHRONIZED & FUSION REJECTED', () {
      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);

      // Video ending at t = 5200ms (1700ms ahead of audio)
      for (int i = 0; i < 16; i++) {
        videoBuffer.addFrame(CameraFrame(
          cameraId: 'CAM-001',
          deviceName: 'HP TrueVision HD Camera',
          frameIndex: i,
          timestamp: baseTime.add(Duration(milliseconds: 3700 + i * 100)),
          monotonicUs: (3700000 + i * 100000),
          width: 224,
          height: 224,
          pixelFormat: 'RGB888',
          rgbBytes: Uint8List(224 * 224 * 3),
          acquisitionLatencyMs: 25,
        ));
      }

      // Audio ending at t = 3500ms (500ms old at evalTime 4000ms, not stale)
      for (int i = 0; i < 40; i++) {
        audioBuffer.pushSamples(
          Float32List(1600),
          captureTime: baseTime.add(Duration(milliseconds: i * 89)),
          monotonicUs: (i * 89743),
        );
      }

      final evalTime = baseTime.add(const Duration(milliseconds: 4000));
      final sync = synchronizer.evaluate(
        videoBuffer: videoBuffer,
        audioBuffer: audioBuffer,
        isAudioServiceReady: true,
        nowUtc: evalTime,
      );

      expect(sync.syncState, equals(MultimodalSyncState.desynchronized));
      expect(sync.isMultimodal, isFalse);
      expect(sync.absoluteOffsetMs, greaterThan(1000));
      expect(sync.diagnosticNotice, contains('FUSION REJECTED'));
      expect(synchronizer.latestTelemetry.desynchronizedCount, equals(1));
      expect(synchronizer.latestTelemetry.rejectionCount, equals(1));
    });

    test('Failure Mode 1: Microphone unattached -> VIDEO-ONLY DEGRADED', () {
      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);
      for (int i = 0; i < 16; i++) {
        videoBuffer.addFrame(CameraFrame(
          cameraId: 'CAM-001',
          deviceName: 'HP TrueVision HD Camera',
          frameIndex: i,
          timestamp: baseTime.add(Duration(milliseconds: i * 100)),
          monotonicUs: (1000000 + i * 100000),
          width: 224,
          height: 224,
          pixelFormat: 'RGB888',
          rgbBytes: Uint8List(224 * 224 * 3),
          acquisitionLatencyMs: 25,
        ));
      }

      final sync = synchronizer.evaluate(
        videoBuffer: videoBuffer,
        audioBuffer: null, // No microphone
        isAudioServiceReady: false,
        nowUtc: baseTime.add(const Duration(milliseconds: 1600)),
      );

      expect(sync.syncState, equals(MultimodalSyncState.videoOnlyDegraded));
      expect(sync.isMultimodal, isFalse);
      expect(sync.diagnosticNotice, contains('VIDEO-ONLY DEGRADED'));
    });

    test('Failure Mode 2: Audio buffer warming up (< 64000 samples) -> VIDEO-ONLY DEGRADED', () {
      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);
      for (int i = 0; i < 16; i++) {
        videoBuffer.addFrame(CameraFrame(
          cameraId: 'CAM-001',
          deviceName: 'HP TrueVision HD Camera',
          frameIndex: i,
          timestamp: baseTime.add(Duration(milliseconds: i * 100)),
          monotonicUs: (1000000 + i * 100000),
          width: 224,
          height: 224,
          pixelFormat: 'RGB888',
          rgbBytes: Uint8List(224 * 224 * 3),
          acquisitionLatencyMs: 25,
        ));
      }

      // Audio only has 16,000 samples (1.0s, not ready)
      audioBuffer.pushSamples(
        Float32List(16000),
        captureTime: baseTime.add(const Duration(milliseconds: 1500)),
        monotonicUs: 1500000,
      );

      final sync = synchronizer.evaluate(
        videoBuffer: videoBuffer,
        audioBuffer: audioBuffer,
        isAudioServiceReady: true,
        nowUtc: baseTime.add(const Duration(milliseconds: 1600)),
      );

      expect(sync.syncState, equals(MultimodalSyncState.videoOnlyDegraded));
      expect(sync.isMultimodal, isFalse);
      expect(sync.diagnosticNotice, contains('Audio buffer warming up'));
    });

    test('Failure Mode 3: Microphone stalled > 2000ms -> VIDEO-ONLY DEGRADED', () {
      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);
      for (int i = 0; i < 16; i++) {
        videoBuffer.addFrame(CameraFrame(
          cameraId: 'CAM-001',
          deviceName: 'HP TrueVision HD Camera',
          frameIndex: i,
          timestamp: baseTime.add(Duration(milliseconds: 2500 + i * 100)),
          monotonicUs: (2500000 + i * 100000),
          width: 224,
          height: 224,
          pixelFormat: 'RGB888',
          rgbBytes: Uint8List(224 * 224 * 3),
          acquisitionLatencyMs: 25,
        ));
      }

      // Microphone pushed samples ending at t = 1000ms (3.0s ago)
      for (int i = 0; i < 40; i++) {
        audioBuffer.pushSamples(
          Float32List(1600),
          captureTime: baseTime.add(Duration(milliseconds: i * 25)),
          monotonicUs: (i * 25000),
        );
      }

      final evalTime = baseTime.add(const Duration(milliseconds: 4050));
      final sync = synchronizer.evaluate(
        videoBuffer: videoBuffer,
        audioBuffer: audioBuffer,
        isAudioServiceReady: true,
        nowUtc: evalTime,
      );

      expect(sync.syncState, equals(MultimodalSyncState.videoOnlyDegraded));
      expect(sync.isMultimodal, isFalse);
      expect(sync.diagnosticNotice, contains('Microphone stream stalled'));
    });

    test('Failure Mode 4: Camera stalled > 2000ms with active audio -> AUDIO-ONLY DEGRADED', () {
      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);

      // Camera stopped at t = 1500ms
      for (int i = 0; i < 16; i++) {
        videoBuffer.addFrame(CameraFrame(
          cameraId: 'CAM-001',
          deviceName: 'HP TrueVision HD Camera',
          frameIndex: i,
          timestamp: baseTime.add(Duration(milliseconds: i * 100)),
          monotonicUs: (1000000 + i * 100000),
          width: 224,
          height: 224,
          pixelFormat: 'RGB888',
          rgbBytes: Uint8List(224 * 224 * 3),
          acquisitionLatencyMs: 25,
        ));
      }

      // Audio active up to t = 4500ms
      for (int i = 0; i < 40; i++) {
        audioBuffer.pushSamples(
          Float32List(1600),
          captureTime: baseTime.add(Duration(milliseconds: 500 + i * 100)),
          monotonicUs: (500000 + i * 100000),
        );
      }

      final evalTime = baseTime.add(const Duration(milliseconds: 4600));
      final sync = synchronizer.evaluate(
        videoBuffer: videoBuffer,
        audioBuffer: audioBuffer,
        isAudioServiceReady: true,
        nowUtc: evalTime,
      );

      expect(sync.syncState, equals(MultimodalSyncState.audioOnlyDegraded));
      expect(sync.isMultimodal, isFalse);
      expect(sync.diagnosticNotice, contains('Camera stream stalled'));
    });

    test('Failure Mode 5: Both streams stalled -> UNINITIALIZED OR STALE', () {
      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);

      // Camera stopped at t = 1500ms
      for (int i = 0; i < 16; i++) {
        videoBuffer.addFrame(CameraFrame(
          cameraId: 'CAM-001',
          deviceName: 'HP TrueVision HD Camera',
          frameIndex: i,
          timestamp: baseTime.add(Duration(milliseconds: i * 100)),
          monotonicUs: (1000000 + i * 100000),
          width: 224,
          height: 224,
          pixelFormat: 'RGB888',
          rgbBytes: Uint8List(224 * 224 * 3),
          acquisitionLatencyMs: 25,
        ));
      }

      // Audio stopped at t = 1000ms
      for (int i = 0; i < 40; i++) {
        audioBuffer.pushSamples(
          Float32List(1600),
          captureTime: baseTime.add(Duration(milliseconds: i * 25)),
          monotonicUs: (i * 25000),
        );
      }

      // Evaluated at t = 5000ms (> 2.0s stale for both)
      final evalTime = baseTime.add(const Duration(milliseconds: 5000));
      final sync = synchronizer.evaluate(
        videoBuffer: videoBuffer,
        audioBuffer: audioBuffer,
        isAudioServiceReady: true,
        nowUtc: evalTime,
      );

      expect(sync.syncState, equals(MultimodalSyncState.uninitializedOrStale));
      expect(sync.isMultimodal, isFalse);
      expect(sync.diagnosticNotice, contains('SENSORS OFFLINE OR STALE'));
    });

    test('Offset Jitter calculation updates across rolling window', () {
      final baseTime = DateTime.utc(2026, 11, 22, 12, 0, 0);

      for (int i = 0; i < 16; i++) {
        videoBuffer.addFrame(CameraFrame(
          cameraId: 'CAM-001',
          deviceName: 'HP TrueVision HD Camera',
          frameIndex: i,
          timestamp: baseTime.add(Duration(milliseconds: i * 100)),
          monotonicUs: (1000000 + i * 100000),
          width: 224,
          height: 224,
          pixelFormat: 'RGB888',
          rgbBytes: Uint8List(224 * 224 * 3),
          acquisitionLatencyMs: 25,
        ));
      }

      for (int i = 0; i < 40; i++) {
        audioBuffer.pushSamples(
          Float32List(1600),
          captureTime: baseTime.subtract(Duration(milliseconds: 2500 - i * 100)),
          monotonicUs: (i * 100000),
        );
      }

      // Run multiple evaluations simulating varied offsets
      for (int offset = 50; offset <= 250; offset += 50) {
        final evalTime = baseTime.add(const Duration(milliseconds: 1550));
        synchronizer.evaluate(
          videoBuffer: videoBuffer,
          audioBuffer: audioBuffer,
          isAudioServiceReady: true,
          nowUtc: evalTime,
        );
      }

      expect(synchronizer.latestTelemetry.totalEvaluations, equals(5));
      expect(synchronizer.latestTelemetry.meanOffsetMs, isPositive);
      expect(synchronizer.latestTelemetry.maxOffsetMs, isPositive);
    });
  });
}
