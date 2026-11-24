// SentinelX - Audio Measurement & Decibel Calibration Test Suite
// Verifies dBFS calculations, digital silence vs ambient noise separation,
// acoustic categorization labels, and audio telemetry streaming.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel_x/core/audio/temporal_audio_buffer.dart';
import 'package:sentinel_x/core/audio/audio_ingestion_service.dart';

void main() {
  group('P1-B: Audio Measurement & dBFS Unit Calibration Tests', () {
    late TemporalAudioBuffer buffer;

    setUp(() {
      buffer = TemporalAudioBuffer(capacity: 1024, requiredSamples: 512);
    });

    test('Test 1: Digital silence (all zeros) produces <= -75.0 dBFS and flags isDigitalSilence', () {
      final silence = Float32List(512); // All zeros
      buffer.pushSamples(silence);

      final telem = buffer.getTelemetry();

      expect(telem.currentDbLevel, equals(-100.0));
      expect(telem.currentDbFs, equals(-100.0));
      expect(telem.isDigitalSilence, isTrue);
      expect(telem.isAmbientQuiet, isFalse);
      expect(telem.isSpeechNormal, isFalse);
      expect(telem.isAcousticPeak, isFalse);
      expect(telem.acousticStateLabel, contains('DIGITAL SILENCE'));
    });

    test('Test 2: Ambient quiet room noise (RMS ~ 0.01) produces ~ -40.0 dBFS and flags isAmbientQuiet', () {
      // 0.01 amplitude DC / constant produces RMS = 0.01 => 20 * log10(0.01) = -40.0 dBFS
      final ambient = Float32List(512)..fillRange(0, 512, 0.01);
      buffer.pushSamples(ambient);

      final telem = buffer.getTelemetry();

      expect(telem.currentDbLevel, closeTo(-40.0, 0.1));
      expect(telem.currentDbFs, closeTo(-40.0, 0.1));
      expect(telem.isDigitalSilence, isFalse);
      expect(telem.isAmbientQuiet, isTrue);
      expect(telem.isSpeechNormal, isFalse);
      expect(telem.isAcousticPeak, isFalse);
      expect(telem.acousticStateLabel, equals('AMBIENT ROOM NOISE'));
    });

    test('Test 3: Normal conversational speech (RMS ~ 0.05) produces ~ -26.0 dBFS and flags isSpeechNormal', () {
      // 0.05 amplitude produces RMS = 0.05 => 20 * log10(0.05) ≈ -26.02 dBFS
      final speech = Float32List(512)..fillRange(0, 512, 0.05);
      buffer.pushSamples(speech);

      final telem = buffer.getTelemetry();

      expect(telem.currentDbLevel, closeTo(-26.02, 0.1));
      expect(telem.isDigitalSilence, isFalse);
      expect(telem.isAmbientQuiet, isFalse);
      expect(telem.isSpeechNormal, isTrue);
      expect(telem.isAcousticPeak, isFalse);
      expect(telem.acousticStateLabel, equals('CONVERSATIONAL SPEECH'));
    });

    test('Test 4: Shouting / acoustic peak (RMS ~ 0.50) produces ~ -6.0 dBFS and flags isAcousticPeak', () {
      // 0.50 amplitude produces RMS = 0.50 => 20 * log10(0.50) ≈ -6.02 dBFS
      final peak = Float32List(512)..fillRange(0, 512, 0.50);
      buffer.pushSamples(peak);

      final telem = buffer.getTelemetry();

      expect(telem.currentDbLevel, closeTo(-6.02, 0.1));
      expect(telem.isDigitalSilence, isFalse);
      expect(telem.isAmbientQuiet, isFalse);
      expect(telem.isSpeechNormal, isFalse);
      expect(telem.isAcousticPeak, isTrue);
      expect(telem.acousticStateLabel, equals('ACOUSTIC SPIKE / PEAK'));
    });

    test('Test 5: Full scale digital maximum (amplitude = 1.0) produces exactly 0.0 dBFS', () {
      final maxSignal = Float32List(512)..fillRange(0, 512, 1.0);
      buffer.pushSamples(maxSignal);

      final telem = buffer.getTelemetry();

      expect(telem.currentDbLevel, closeTo(0.0, 0.001));
      expect(telem.currentDbFs, closeTo(0.0, 0.001));
      expect(telem.isAcousticPeak, isTrue);
    });

    test('Test 6: AudioTelemetry getters mirror dBFS and acoustic categorization correctly', () {
      final telem = AudioTelemetry(
        status: AudioConnectionStatus.streaming,
        deviceName: 'Realtek High Definition Audio',
        deviceId: 'realtek-01',
        sampleRate: 16000,
        channels: 1,
        currentDbLevel: -42.5,
        currentRmsVolume: 0.0075,
        totalSamplesIngested: 32000,
        bufferCount: 1024,
        bufferCapacity: 2048,
        bufferFillPercentage: 50.0,
        isBufferReady: true,
        initializationTimeMs: 15,
        timestamp: DateTime.now().toUtc(),
      );

      expect(telem.currentDbFs, equals(-42.5));
      expect(telem.isAmbientQuiet, isTrue);
      expect(telem.isDigitalSilence, isFalse);
      expect(telem.acousticStateLabel, equals('AMBIENT ROOM NOISE'));
    });
  });
}
