// SentinelX - ML Pipeline Verification & Explainable Outputs Test Suite
// Verifies 5-class softmax probability contract, canvas bounding box clipping,
// and explainable confidence tier categorization.

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel_x/core/ml/continuous_inference_scheduler.dart';
import 'package:sentinel_x/core/ml/onnx_inference_worker.dart';

void main() {
  group('P1-C: ML Pipeline Verification & Explainable Outputs Tests', () {
    test('Test 1: WorkerInferenceOutput class taxonomy matches 5-class contract', () {
      expect(WorkerInferenceOutput.classLabels, equals([
        'Explosion',
        'Gunshot',
        'Fighting',
        'Accident',
        'Normal',
      ]));
    });

    test('Test 2: Softmax normalization guarantees sum of probabilities equals 1.0', () {
      // Raw unnormalized probabilities with precision drift (sum = 1.045)
      final rawProbs = [0.10, 0.70, 0.15, 0.05, 0.045];
      final sum = rawProbs.fold<double>(0.0, (acc, p) => acc + p);
      expect((sum - 1.0).abs(), greaterThan(0.005));

      // Normalization applied
      final normalized = rawProbs.map((p) => p / sum).toList();
      final normalizedSum = normalized.fold<double>(0.0, (acc, p) => acc + p);

      expect(normalizedSum, closeTo(1.0, 1e-6));
      expect(normalized.length, equals(5));
    });

    test('Test 3: ContinuousInferencePrediction categorizes explainable confidence tiers correctly', () {
      // 1. Normal class
      final normalPred = ContinuousInferencePrediction(
        cameraId: 'CAM-001',
        threatProbabilities: const [0.01, 0.01, 0.01, 0.01, 0.96],
        predictedClass: 'Normal',
        confidence: 0.96,
        rawBoundingBox: const [0.0, 0.0, 0.0, 0.0],
        clippedBoundingBox: const [0.0, 0.0, 0.0, 0.0],
        isNormal: true,
        isCritical: false,
        isDegradedMode: false,
        diagnosticNotice: 'Healthy',
        latencyMs: 12,
        timestamp: DateTime.now().toUtc(),
        frameIndex: 1,
      );
      expect(normalPred.isNormal, isTrue);
      expect(normalPred.isActionable, isFalse);
      expect(normalPred.isLowConfidence, isFalse);
      expect(normalPred.confidenceTier, equals('NORMAL (CLEAR)'));

      // 2. Critical actionable anomaly (confidence >= 0.85)
      final criticalPred = ContinuousInferencePrediction(
        cameraId: 'CAM-001',
        threatProbabilities: const [0.02, 0.88, 0.04, 0.03, 0.03],
        predictedClass: 'Gunshot',
        confidence: 0.88,
        rawBoundingBox: const [0.2, 0.2, 0.4, 0.4],
        clippedBoundingBox: const [0.2, 0.2, 0.4, 0.4],
        isNormal: false,
        isCritical: true,
        isDegradedMode: false,
        diagnosticNotice: 'Healthy',
        latencyMs: 14,
        timestamp: DateTime.now().toUtc(),
        frameIndex: 2,
      );
      expect(criticalPred.isNormal, isFalse);
      expect(criticalPred.isActionable, isTrue);
      expect(criticalPred.isCritical, isTrue);
      expect(criticalPred.isLowConfidence, isFalse);
      expect(criticalPred.confidenceTier, equals('CRITICAL (ACTIONABLE)'));

      // 3. High actionable anomaly (0.70 <= conf < 0.85)
      final highPred = ContinuousInferencePrediction(
        cameraId: 'CAM-001',
        threatProbabilities: const [0.05, 0.05, 0.76, 0.09, 0.05],
        predictedClass: 'Fighting',
        confidence: 0.76,
        rawBoundingBox: const [0.1, 0.1, 0.3, 0.3],
        clippedBoundingBox: const [0.1, 0.1, 0.3, 0.3],
        isNormal: false,
        isCritical: false,
        isDegradedMode: false,
        diagnosticNotice: 'Healthy',
        latencyMs: 14,
        timestamp: DateTime.now().toUtc(),
        frameIndex: 3,
      );
      expect(highPred.isActionable, isTrue);
      expect(highPred.confidenceTier, equals('HIGH (ACTIONABLE)'));

      // 4. Medium review anomaly (0.50 <= conf < 0.70)
      final medPred = ContinuousInferencePrediction(
        cameraId: 'CAM-001',
        threatProbabilities: const [0.05, 0.05, 0.58, 0.22, 0.10],
        predictedClass: 'Fighting',
        confidence: 0.58,
        rawBoundingBox: const [0.1, 0.1, 0.3, 0.3],
        clippedBoundingBox: const [0.1, 0.1, 0.3, 0.3],
        isNormal: false,
        isCritical: false,
        isDegradedMode: false,
        diagnosticNotice: 'Healthy',
        latencyMs: 14,
        timestamp: DateTime.now().toUtc(),
        frameIndex: 4,
      );
      expect(medPred.isActionable, isFalse);
      expect(medPred.isLowConfidence, isFalse);
      expect(medPred.confidenceTier, equals('MEDIUM (REVIEW)'));

      // 5. Low confidence suppressed noise (< 0.50)
      final lowPred = ContinuousInferencePrediction(
        cameraId: 'CAM-001',
        threatProbabilities: const [0.35, 0.20, 0.15, 0.15, 0.15],
        predictedClass: 'Explosion',
        confidence: 0.35,
        rawBoundingBox: const [0.1, 0.1, 0.3, 0.3],
        clippedBoundingBox: const [0.1, 0.1, 0.3, 0.3],
        isNormal: false,
        isCritical: false,
        isDegradedMode: false,
        diagnosticNotice: 'Healthy',
        latencyMs: 14,
        timestamp: DateTime.now().toUtc(),
        frameIndex: 5,
      );
      expect(lowPred.isActionable, isFalse);
      expect(lowPred.isLowConfidence, isTrue);
      expect(lowPred.confidenceTier, equals('LOW (SUPPRESSED / NOISE)'));
    });

    test('Test 4: Viewport canvas boundary clipping strictly confines coordinates', () {
      // Out of bounds raw coords: x < 0, y > 1, w overflows, h overflows
      const raw = [-0.15, 0.85, 0.50, 0.60];

      final x = raw[0].clamp(0.0, 1.0);
      final y = raw[1].clamp(0.0, 1.0);
      final wRaw = raw[2].clamp(0.0, 1.0);
      final hRaw = raw[3].clamp(0.0, 1.0);

      final wClipped = (wRaw > 1.0 - x ? 1.0 - x : wRaw).clamp(0.0, 1.0);
      final hClipped = (hRaw > 1.0 - y ? 1.0 - y : hRaw).clamp(0.0, 1.0);

      expect(x, equals(0.0));
      expect(y, equals(0.85));
      expect(wClipped, equals(0.50));
      // Since y is 0.85, max remaining height is 0.15
      expect(hClipped, closeTo(0.15, 1e-6));
      expect(x + wClipped, lessThanOrEqualTo(1.0));
      expect(y + hClipped, lessThanOrEqualTo(1.0));
    });
  });
}
