// SentinelX - Audio Capture & Ring Buffer Unit Tests
// Tests: TemporalAudioBuffer and AudioIngestionService lifecycle, bounded memory, and error states.

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:sentinel_x/core/audio/temporal_audio_buffer.dart';
import 'package:sentinel_x/core/audio/audio_ingestion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'create':
            return null;
          case 'hasPermission':
            return true;
          case 'listInputDevices':
            return [
              {'id': 'mic-001', 'label': 'HP TrueVision Mic Array'}
            ];
          case 'dispose':
            return null;
          default:
            return null;
        }
      },
    );
  });

  group('TemporalAudioBuffer Unit Tests', () {
    late TemporalAudioBuffer buffer;

    setUp(() {
      buffer = TemporalAudioBuffer();
    });

    test('Initializes with default capacity (65,536) and zero count', () {
      expect(buffer.capacity, equals(65536));
      expect(buffer.requiredSamples, equals(64000));
      expect(buffer.currentCount, equals(0));
      expect(buffer.totalIngested, equals(0));
      expect(buffer.isReady, isFalse);
    });

    test('Pushing samples updates count and totalIngested', () {
      final samples = Float32List(1000);
      for (int i = 0; i < 1000; i++) {
        samples[i] = 0.5;
      }
      buffer.pushSamples(samples);

      expect(buffer.currentCount, equals(1000));
      expect(buffer.totalIngested, equals(1000));
      expect(buffer.isReady, isFalse);
    });

    test('Enforces strictly bounded memory (does not exceed capacity of 65,536)', () {
      // Push 100,000 samples into a 65,536-capacity buffer
      final chunk = Float32List(20000);
      for (int step = 0; step < 5; step++) {
        buffer.pushSamples(chunk);
      }

      expect(buffer.totalIngested, equals(100000));
      // Buffer count MUST remain capped at 65,536
      expect(buffer.currentCount, equals(65536));
      expect(buffer.isReady, isTrue);
    });

    test('Overwrites oldest samples chronologically (O(1) ring buffer rotation)', () {
      final smallBuffer = TemporalAudioBuffer(capacity: 8, requiredSamples: 4);

      // Push 8 samples: [1, 2, 3, 4, 5, 6, 7, 8]
      final firstBatch = Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]);
      smallBuffer.pushSamples(firstBatch);
      expect(smallBuffer.currentCount, equals(8));

      // Push 2 more: [0.9, 1.0] -> should overwrite 0.1 and 0.2
      final secondBatch = Float32List.fromList([0.9, 1.0]);
      smallBuffer.pushSamples(secondBatch);
      expect(smallBuffer.currentCount, equals(8));
      expect(smallBuffer.totalIngested, equals(10));

      // Extract 8 samples: should be [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
      final snapshot = smallBuffer.extractSnapshot(8);
      expect(snapshot[0], closeTo(0.3, 1e-5));
      expect(snapshot[1], closeTo(0.4, 1e-5));
      expect(snapshot[6], closeTo(0.9, 1e-5));
      expect(snapshot[7], closeTo(1.0, 1e-5));
    });

    test('PCM16 byte conversion normalizes correctly to Float32 [-1.0, 1.0]', () {
      // 3 samples: 0x0000 (0), 0x7FFF (+32767), 0x8000 (-32768)
      final pcmBytes = Uint8List(6);
      final byteData = ByteData.sublistView(pcmBytes);
      byteData.setInt16(0, 0, Endian.little);
      byteData.setInt16(2, 32767, Endian.little);
      byteData.setInt16(4, -32768, Endian.little);

      buffer.pushPcm16Bytes(pcmBytes);
      expect(buffer.currentCount, equals(3));

      final snapshot = buffer.extractSnapshot(3);
      expect(snapshot[0], closeTo(0.0, 1e-6));
      expect(snapshot[1], closeTo(32767.0 / 32768.0, 1e-4));
      expect(snapshot[2], closeTo(-1.0, 1e-6));
    });

    test('extractSnapshot pads with silence (0.0) when count < target', () {
      final samples = Float32List.fromList([0.5, 0.75]);
      buffer.pushSamples(samples);

      // Request 5 samples: should be [0.0, 0.0, 0.0, 0.5, 0.75]
      final snapshot = buffer.extractSnapshot(5);
      expect(snapshot.length, equals(5));
      expect(snapshot[0], equals(0.0));
      expect(snapshot[1], equals(0.0));
      expect(snapshot[2], equals(0.0));
      expect(snapshot[3], closeTo(0.5, 1e-6));
      expect(snapshot[4], closeTo(0.75, 1e-6));
    });

    test('Telemetry correctly calculates fill percentage, RMS volume, and dB level', () {
      final samples = Float32List(32768);
      for (int i = 0; i < samples.length; i++) {
        samples[i] = 0.5; // Constant 0.5 amplitude
      }
      buffer.pushSamples(samples);

      final telem = buffer.getTelemetry();
      expect(telem.currentBufferLength, equals(32768));
      expect(telem.bufferCapacity, equals(65536));
      expect(telem.bufferFillPercentage, closeTo(50.0, 0.1));
      expect(telem.isReady, isFalse);
      expect(telem.currentRmsVolume, closeTo(0.5, 1e-3));
      // 20 * log10(0.5) = -6.02 dB
      expect(telem.currentDbLevel, closeTo(-6.02, 0.1));
    });

    test('clear() resets buffer state cleanly', () {
      buffer.pushSamples(Float32List(1000));
      expect(buffer.currentCount, equals(1000));

      buffer.clear();
      expect(buffer.currentCount, equals(0));
      expect(buffer.lastRms, equals(0.0));

      final telem = buffer.getTelemetry();
      expect(telem.currentBufferLength, equals(0));
      expect(telem.bufferFillPercentage, equals(0.0));
      expect(telem.isReady, isFalse);
    });
  });

  group('AudioIngestionService Lifecycle & State Machine Tests', () {
    late AudioIngestionService service;
    late TemporalAudioBuffer ringBuffer;

    setUp(() {
      ringBuffer = TemporalAudioBuffer();
      service = AudioIngestionService(temporalBuffer: ringBuffer);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('Initial status is uninitialized with valid telemetry initial state', () {
      expect(service.status, equals(AudioConnectionStatus.uninitialized));
      expect(service.isBufferReady, isFalse);
      expect(service.currentTelemetry.status, equals(AudioConnectionStatus.uninitialized));
      expect(service.currentTelemetry.sampleRate, equals(16000));
      expect(service.currentTelemetry.channels, equals(1));
    });

    test('Fails with permissionDenied when system permission is denied', () async {
      final ok = await service.initialize(injectedHasPermission: false);
      expect(ok, isFalse);
      expect(service.status, equals(AudioConnectionStatus.permissionDenied));
      expect(service.currentTelemetry.errorMessage, contains('permission denied'));
    });

    test('Fails with noDeviceFound when no hardware microphone is detected', () async {
      final ok = await service.initialize(
        injectedHasPermission: true,
        injectedDevices: [],
      );
      expect(ok, isFalse);
      expect(service.status, equals(AudioConnectionStatus.noDeviceFound));
      expect(service.currentTelemetry.errorMessage, contains('No hardware microphone'));
    });

    test('Initializes successfully with detected hardware microphone', () async {
      final mockDevice = const InputDevice(id: 'mic-001', label: 'HP TrueVision Mic Array');
      final ok = await service.initialize(
        injectedHasPermission: true,
        injectedDevices: [mockDevice],
      );

      expect(ok, isTrue);
      expect(service.status, equals(AudioConnectionStatus.connected));
      expect(service.deviceId, equals('mic-001'));
      expect(service.deviceName, equals('HP TrueVision Mic Array'));
      expect(service.currentTelemetry.status, equals(AudioConnectionStatus.connected));
    });

    test('extractSnapshot forwards to temporal ring buffer', () {
      final samples = Float32List.fromList([0.1, 0.2, 0.3]);
      ringBuffer.pushSamples(samples);

      final snapshot = service.extractSnapshot(3);
      expect(snapshot.length, equals(3));
      expect(snapshot[0], closeTo(0.1, 1e-6));
      expect(snapshot[1], closeTo(0.2, 1e-6));
      expect(snapshot[2], closeTo(0.3, 1e-6));
    });

    test('dispose() cleans up and transitions to disposed status', () async {
      await service.dispose();
      expect(service.status, equals(AudioConnectionStatus.disposed));
    });
  });
}
