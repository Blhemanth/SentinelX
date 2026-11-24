// SentinelX - Phase 4.4.3: Modality Quality Estimator & Adaptive Fusion Unit Tests
// Tests determinism, signal quality scoring, adaptive reliability weighting,
// graceful asymmetric degradation, and bounding-box reliability gating.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel_x/core/camera/camera_frame.dart';
import 'package:sentinel_x/core/camera/temporal_frame_buffer.dart';
import 'package:sentinel_x/core/audio/temporal_audio_buffer.dart';
import 'package:sentinel_x/core/ml/multimodal_synchronizer.dart';
import 'package:sentinel_x/core/ml/modality_quality_estimator.dart';
import 'package:sentinel_x/core/ml/adaptive_fusion_manager.dart';

CameraFrame _createTestFrame({
  required Uint8List bytes,
  DateTime? timestamp,
  int frameIndex = 1,
}) {
  return CameraFrame(
    cameraId: 'CAM-TEST',
    deviceName: 'Test Synthetic Camera',
    frameIndex: frameIndex,
    timestamp: timestamp ?? DateTime.now().toUtc(),
    width: 224,
    height: 224,
    pixelFormat: 'RGB888',
    rgbBytes: bytes,
    acquisitionLatencyMs: 10,
    monotonicUs: 1000000,
    status: CameraFrameStatus.valid,
  );
}

void main() {
  group('ModalityQualityEstimator - Video Quality Scoring', () {
    late ModalityQualityEstimator estimator;
    late TemporalFrameBuffer buffer;

    setUp(() {
      estimator = ModalityQualityEstimator();
      buffer = TemporalFrameBuffer();
    });

    test('Empty buffer returns uninitialized metrics', () {
      final q = estimator.estimateVideoQuality(buffer);
      expect(q.isUnderExposed, isTrue);
      expect(q.isStale, isTrue);
      expect(q.reliabilityScore, equals(0.0));
      expect(q.qualityWarnings, contains('Video stream uninitialized or empty'));
    });

    test('Clean natural pattern frame produces high reliability score', () {
      final now = DateTime.now().toUtc();
      // Generate synthetic checkerboard pattern (high contrast, good exposure, sharp)
      final bytes = Uint8List(224 * 224 * 3);
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final idx = (y * 224 + x) * 3;
          final isWhite = ((x ~/ 16) + (y ~/ 16)) % 2 == 0;
          final val = isWhite ? 200 : 50;
          bytes[idx] = val;
          bytes[idx + 1] = val;
          bytes[idx + 2] = val;
        }
      }

      buffer.addFrame(_createTestFrame(bytes: bytes, timestamp: now));

      final q = estimator.estimateVideoQuality(buffer, nowUtc: now);
      expect(q.isUnderExposed, isFalse);
      expect(q.isOverExposed, isFalse);
      expect(q.isLowContrast, isFalse);
      expect(q.isBlurred, isFalse);
      expect(q.isFrozen, isFalse);
      expect(q.isStale, isFalse);
      expect(q.reliabilityScore, greaterThanOrEqualTo(0.85));
      expect(q.qualityWarnings, isEmpty);
    });

    test('Pitch black / severely underexposed frame flags underexposed and lowers score', () {
      final now = DateTime.now().toUtc();
      final bytes = Uint8List(224 * 224 * 3); // All 0s
      buffer.addFrame(_createTestFrame(bytes: bytes, timestamp: now));

      final q = estimator.estimateVideoQuality(buffer, nowUtc: now);
      expect(q.isUnderExposed, isTrue);
      expect(q.brightness, lessThan(30.0));
      expect(q.reliabilityScore, lessThan(0.30));
      expect(q.qualityWarnings.any((w) => w.contains('underexposed')), isTrue);
    });

    test('Washed out / overexposed frame flags overexposed and lowers score', () {
      final now = DateTime.now().toUtc();
      final bytes = Uint8List(224 * 224 * 3)..fillRange(0, 224 * 224 * 3, 245);
      buffer.addFrame(_createTestFrame(bytes: bytes, timestamp: now));

      final q = estimator.estimateVideoQuality(buffer, nowUtc: now);
      expect(q.isOverExposed, isTrue);
      expect(q.brightness, greaterThan(225.0));
      expect(q.reliabilityScore, lessThan(0.35));
      expect(q.qualityWarnings.any((w) => w.contains('overexposed')), isTrue);
    });

    test('Flat uniform gray frame flags low contrast and blur', () {
      final now = DateTime.now().toUtc();
      final bytes = Uint8List(224 * 224 * 3)..fillRange(0, 224 * 224 * 3, 128);
      buffer.addFrame(_createTestFrame(bytes: bytes, timestamp: now));

      final q = estimator.estimateVideoQuality(buffer, nowUtc: now);
      expect(q.isLowContrast, isTrue);
      expect(q.isBlurred, isTrue);
      expect(q.contrast, lessThan(5.0));
      expect(q.sharpness, equals(0.0));
      expect(q.reliabilityScore, lessThan(0.40));
    });

    test('Stale frame (>2000ms old) flags isStale and zeroes reliability', () {
      final oldTime = DateTime.now().toUtc().subtract(const Duration(seconds: 3));
      final now = DateTime.now().toUtc();
      final bytes = Uint8List(224 * 224 * 3)..fillRange(0, 224 * 224 * 3, 100);
      buffer.addFrame(_createTestFrame(bytes: bytes, timestamp: oldTime));

      final q = estimator.estimateVideoQuality(buffer, nowUtc: now);
      expect(q.isStale, isTrue);
      expect(q.reliabilityScore, equals(0.0));
      expect(q.qualityWarnings.any((w) => w.contains('stale')), isTrue);
    });

    test('Identical frames in succession flag isFrozen', () {
      final now = DateTime.now().toUtc();
      final bytes = Uint8List(224 * 224 * 3)..fillRange(0, 224 * 224 * 3, 150);

      buffer.addFrame(_createTestFrame(
        bytes: Uint8List.fromList(bytes),
        timestamp: now.subtract(const Duration(milliseconds: 100)),
        frameIndex: 1,
      ));
      final q1 = estimator.estimateVideoQuality(buffer, nowUtc: now);
      expect(q1.isFrozen, isFalse);

      buffer.addFrame(_createTestFrame(
        bytes: Uint8List.fromList(bytes),
        timestamp: now,
        frameIndex: 2,
      ));
      final q2 = estimator.estimateVideoQuality(buffer, nowUtc: now);
      expect(q2.isFrozen, isTrue);
      expect(q2.reliabilityScore, lessThanOrEqualTo(0.35));
      expect(q2.qualityWarnings.any((w) => w.contains('frozen')), isTrue);
    });
  });

  group('ModalityQualityEstimator - Audio Quality Scoring', () {
    late ModalityQualityEstimator estimator;

    setUp(() {
      estimator = ModalityQualityEstimator();
    });

    test('Empty samples returns uninitialized metrics', () {
      final q = estimator.estimateAudioQuality(Float32List(0));
      expect(q.isSilent, isTrue);
      expect(q.isStale, isTrue);
      expect(q.reliabilityScore, equals(0.0));
      expect(q.qualityWarnings, contains('Audio stream uninitialized or empty'));
    });

    test('Digital silence (all zeros) flags isSilent and sets calibrated 0.05 score', () {
      final samples = Float32List(64000); // 4 seconds of silence
      final q = estimator.estimateAudioQuality(samples);
      expect(q.isSilent, isTrue);
      expect(q.dbLevel, lessThanOrEqualTo(-90.0));
      expect(q.reliabilityScore, equals(0.05));
      expect(q.qualityWarnings.any((w) => w.contains('silence')), isTrue);
    });

    test('Clean speech-like audio produces healthy reliability score', () {
      // 16kHz sine wave at moderate volume (~ -20 dBFS)
      final samples = Float32List(64000);
      for (int i = 0; i < 64000; i++) {
        samples[i] = 0.1 * (i % 32 < 16 ? 1.0 : -1.0); // Simple 500Hz square
      }

      final q = estimator.estimateAudioQuality(samples);
      expect(q.isSilent, isFalse);
      expect(q.isLowEnergy, isFalse);
      expect(q.isClipped, isFalse);
      expect(q.dbLevel, closeTo(-20.0, 3.0));
      expect(q.reliabilityScore, greaterThanOrEqualTo(0.80));
    });

    test('Severely clipped audio (>1% clipped samples) flags isClipped', () {
      final samples = Float32List(64000);
      for (int i = 0; i < 64000; i++) {
        // 5% of samples at 1.0 saturation
        samples[i] = (i % 20 == 0) ? 1.0 : 0.05;
      }

      final q = estimator.estimateAudioQuality(samples);
      expect(q.isClipped, isTrue);
      expect(q.clippingPercentage, greaterThan(1.0));
      expect(q.qualityWarnings.any((w) => w.contains('clipping')), isTrue);
    });

    test('Stale audio metadata zeroes reliability score', () {
      final samples = Float32List(64000);
      for (int i = 0; i < 64000; i++) {
        samples[i] = 0.1;
      }
      final meta = AudioWindowMetadata(
        windowStartUtc: DateTime.now().subtract(const Duration(seconds: 4)),
        windowEndUtc: DateTime.now().subtract(const Duration(seconds: 3)),
        windowStartMonotonicUs: 0,
        windowEndMonotonicUs: 1000000,
        sampleCount: 64000,
        durationMs: 4000,
        chunkCount: 16,
        meanChunkIntervalMs: 250.0,
        ageMs: 3000,
        isStale: true,
        rmsVolume: 0.1,
        dbLevel: -20.0,
      );

      final q = estimator.estimateAudioQuality(samples, audioMeta: meta);
      expect(q.isStale, isTrue);
      expect(q.reliabilityScore, equals(0.0));
      expect(q.qualityWarnings.any((w) => w.contains('stale')), isTrue);
    });
  });

  group('AdaptiveFusionManager - Fusion States and Reliability Weighting', () {
    const manager = AdaptiveFusionManager();

    test('Both modalities healthy yields balancedMultimodal state', () {
      const vQ = VideoQualityMetrics(
        brightness: 120.0,
        contrast: 45.0,
        sharpness: 35.0,
        isUnderExposed: false,
        isOverExposed: false,
        isLowContrast: false,
        isBlurred: false,
        isFrozen: false,
        ageMs: 15,
        isStale: false,
        reliabilityScore: 0.90,
        qualityWarnings: [],
      );

      const aQ = AudioQualityMetrics(
        rmsEnergy: 0.08,
        dbLevel: -22.0,
        estimatedSnrDb: 25.0,
        clippingPercentage: 0.0,
        isSilent: false,
        isLowEnergy: false,
        isClipped: false,
        isNoisy: false,
        ageMs: 20,
        isStale: false,
        reliabilityScore: 0.85,
        qualityWarnings: [],
      );

      final weights = manager.computeWeights(
        videoQuality: vQ,
        audioQuality: aQ,
        syncState: MultimodalSyncState.synchronized,
        isDegradedMode: false,
      );

      expect(weights.fusionState, equals(MultimodalFusionState.balancedMultimodal));
      expect(weights.videoWeight, closeTo(0.51, 0.05));
      expect(weights.audioWeight, closeTo(0.49, 0.05));
      expect(weights.videoWeight + weights.audioWeight, closeTo(1.0, 0.01));
      expect(weights.isBboxReliable, isTrue);
      expect(weights.confidenceMultiplier, equals(1.0));
    });

    test('Video healthy, audio silent yields fallbackSilence state (100% video weight)', () {
      const vQ = VideoQualityMetrics(
        brightness: 120.0,
        contrast: 45.0,
        sharpness: 35.0,
        isUnderExposed: false,
        isOverExposed: false,
        isLowContrast: false,
        isBlurred: false,
        isFrozen: false,
        ageMs: 15,
        isStale: false,
        reliabilityScore: 0.90,
        qualityWarnings: [],
      );

      const aQ = AudioQualityMetrics(
        rmsEnergy: 0.0,
        dbLevel: -95.0,
        estimatedSnrDb: 0.0,
        clippingPercentage: 0.0,
        isSilent: true,
        isLowEnergy: false,
        isClipped: false,
        isNoisy: false,
        ageMs: 20,
        isStale: false,
        reliabilityScore: 0.05,
        qualityWarnings: ['Audio digital silence detected'],
      );

      final weights = manager.computeWeights(
        videoQuality: vQ,
        audioQuality: aQ,
        syncState: MultimodalSyncState.synchronized,
        isDegradedMode: false,
      );

      expect(weights.fusionState, equals(MultimodalFusionState.fallbackSilence));
      expect(weights.videoWeight, equals(1.0));
      expect(weights.audioWeight, equals(0.0));
      expect(weights.isBboxReliable, isTrue);
      expect(weights.confidenceMultiplier, equals(0.90));
    });

    test('Video frozen, audio healthy yields fallbackFrozen state and disables visual bbox', () {
      const vQ = VideoQualityMetrics(
        brightness: 120.0,
        contrast: 45.0,
        sharpness: 35.0,
        isUnderExposed: false,
        isOverExposed: false,
        isLowContrast: false,
        isBlurred: false,
        isFrozen: true,
        ageMs: 15,
        isStale: false,
        reliabilityScore: 0.25,
        qualityWarnings: ['Video stream frozen'],
      );

      const aQ = AudioQualityMetrics(
        rmsEnergy: 0.1,
        dbLevel: -20.0,
        estimatedSnrDb: 30.0,
        clippingPercentage: 0.0,
        isSilent: false,
        isLowEnergy: false,
        isClipped: false,
        isNoisy: false,
        ageMs: 20,
        isStale: false,
        reliabilityScore: 0.90,
        qualityWarnings: [],
      );

      final weights = manager.computeWeights(
        videoQuality: vQ,
        audioQuality: aQ,
        syncState: MultimodalSyncState.synchronized,
        isDegradedMode: false,
      );

      expect(weights.fusionState, equals(MultimodalFusionState.fallbackFrozen));
      expect(weights.videoWeight, equals(0.0));
      expect(weights.audioWeight, equals(1.0));
      expect(weights.isBboxReliable, isFalse); // Visual bbox disabled when camera frozen
      expect(weights.confidenceMultiplier, equals(0.70));
    });

    test('Desynchronized streams reject fusion and activate desynchronizedFallback', () {
      const vQ = VideoQualityMetrics(
        brightness: 120.0,
        contrast: 45.0,
        sharpness: 35.0,
        isUnderExposed: false,
        isOverExposed: false,
        isLowContrast: false,
        isBlurred: false,
        isFrozen: false,
        ageMs: 15,
        isStale: false,
        reliabilityScore: 0.90,
        qualityWarnings: [],
      );

      const aQ = AudioQualityMetrics(
        rmsEnergy: 0.1,
        dbLevel: -20.0,
        estimatedSnrDb: 30.0,
        clippingPercentage: 0.0,
        isSilent: false,
        isLowEnergy: false,
        isClipped: false,
        isNoisy: false,
        ageMs: 20,
        isStale: false,
        reliabilityScore: 0.90,
        qualityWarnings: [],
      );

      final weights = manager.computeWeights(
        videoQuality: vQ,
        audioQuality: aQ,
        syncState: MultimodalSyncState.desynchronized,
        isDegradedMode: false,
      );

      expect(weights.fusionState, equals(MultimodalFusionState.desynchronizedFallback));
      expect(weights.videoWeight, equals(1.0));
      expect(weights.audioWeight, equals(0.0));
      expect(weights.confidenceMultiplier, equals(0.85));
    });

    test('Both degraded yields bothDegraded state and heavy confidence attenuation', () {
      const vQ = VideoQualityMetrics(
        brightness: 10.0,
        contrast: 5.0,
        sharpness: 2.0,
        isUnderExposed: true,
        isOverExposed: false,
        isLowContrast: true,
        isBlurred: true,
        isFrozen: false,
        ageMs: 15,
        isStale: false,
        reliabilityScore: 0.15,
        qualityWarnings: ['Video severely underexposed', 'Video blurred'],
      );

      const aQ = AudioQualityMetrics(
        rmsEnergy: 0.0005,
        dbLevel: -66.0,
        estimatedSnrDb: 3.0,
        clippingPercentage: 5.0,
        isSilent: false,
        isLowEnergy: true,
        isClipped: true,
        isNoisy: true,
        ageMs: 20,
        isStale: false,
        reliabilityScore: 0.18,
        qualityWarnings: ['Low energy', 'Clipped', 'Noisy'],
      );

      final weights = manager.computeWeights(
        videoQuality: vQ,
        audioQuality: aQ,
        syncState: MultimodalSyncState.synchronized,
        isDegradedMode: false,
      );

      expect(weights.fusionState, equals(MultimodalFusionState.bothDegraded));
      expect(weights.isBboxReliable, isFalse);
      expect(weights.confidenceMultiplier, equals(0.50));
    });

    test('applyFusion calibers confidence and probabilities deterministically', () {
      const vQ = VideoQualityMetrics(
        brightness: 10.0,
        contrast: 5.0,
        sharpness: 2.0,
        isUnderExposed: true,
        isOverExposed: false,
        isLowContrast: true,
        isBlurred: true,
        isFrozen: false,
        ageMs: 15,
        isStale: false,
        reliabilityScore: 0.15,
        qualityWarnings: ['Video underexposed'],
      );

      const aQ = AudioQualityMetrics(
        rmsEnergy: 0.0005,
        dbLevel: -66.0,
        estimatedSnrDb: 3.0,
        clippingPercentage: 5.0,
        isSilent: false,
        isLowEnergy: true,
        isClipped: true,
        isNoisy: true,
        ageMs: 20,
        isStale: false,
        reliabilityScore: 0.18,
        qualityWarnings: ['Low energy'],
      );

      final rawProbs = [0.90, 0.02, 0.03, 0.02, 0.03]; // 5 classes
      final rawBox = [0.1, 0.2, 0.3, 0.4];

      final output = manager.applyFusion(
        rawProbabilities: rawProbs,
        rawBoundingBox: rawBox,
        rawPredictedClass: 'Explosion',
        rawConfidence: 0.90,
        videoQuality: vQ,
        audioQuality: aQ,
        syncState: MultimodalSyncState.synchronized,
        isDegradedMode: false,
      );

      expect(output.rawConfidence, equals(0.90));
      // With multiplier 0.50, calibrated confidence should be 0.45
      expect(output.calibratedConfidence, closeTo(0.45, 0.01));
      // Output bounding box preserved, but marked unreliable
      expect(output.isBboxReliable, isFalse);
      expect(output.boundingBox, equals(rawBox));
      // Calibrated probabilities shifted towards uniform 0.20
      // 0.90 * 0.50 + 0.20 * 0.50 = 0.45 + 0.10 = 0.55
      expect(output.calibratedThreatProbabilities[0], closeTo(0.55, 0.01));
    });
  });
}
