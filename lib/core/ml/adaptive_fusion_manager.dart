// SentinelX - Adaptive Multimodal Fusion Manager
// Provides explainable, deterministic modality reliability weighting and fusion.
// Modulates inference outputs based on real-time visual and acoustic quality scores.
// Supports graceful asymmetric degradation without retraining the frozen ONNX model.

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sentinel_x/core/ml/modality_quality_estimator.dart';
import 'package:sentinel_x/core/ml/multimodal_synchronizer.dart';

enum MultimodalFusionState {
  /// Both modalities exhibit healthy quality and temporal alignment.
  balancedMultimodal,

  /// Video is healthy; audio is degraded, noisy, clipped, or silent.
  videoDominant,

  /// Audio is healthy; video is dark, blurred, low-contrast, or frozen.
  audioDominant,

  /// Both modalities exhibit poor quality or low reliability scores.
  bothDegraded,

  /// Audio is uninitialized, disconnected, or falling back to silence baseline.
  fallbackSilence,

  /// Video is stalled, frozen, or stale.
  fallbackFrozen,

  /// Streams are desynchronized; fusion rejected and fallback activated.
  desynchronizedFallback,
}

@immutable
class AdaptiveFusionWeights {
  /// Contribution weight assigned to the visual modality [0.0, 1.0]
  final double videoWeight;

  /// Contribution weight assigned to the acoustic modality [0.0, 1.0]
  final double audioWeight;

  /// Qualitative fusion operational state
  final MultimodalFusionState fusionState;

  /// Human-readable explanation of why weights were modulated
  final String adaptationReason;

  /// Flag indicating whether the predicted spatial bounding box is grounded and reliable
  final bool isBboxReliable;

  /// Multiplier applied to raw model confidence to penalize degraded inputs [0.0, 1.0]
  final double confidenceMultiplier;

  const AdaptiveFusionWeights({
    required this.videoWeight,
    required this.audioWeight,
    required this.fusionState,
    required this.adaptationReason,
    required this.isBboxReliable,
    required this.confidenceMultiplier,
  });

  factory AdaptiveFusionWeights.initial() {
    return const AdaptiveFusionWeights(
      videoWeight: 1.0,
      audioWeight: 0.0,
      fusionState: MultimodalFusionState.fallbackSilence,
      adaptationReason: 'System initializing; default video-only weighting',
      isBboxReliable: true,
      confidenceMultiplier: 1.0,
    );
  }

  @override
  String toString() =>
      'FusionWeights(state: ${fusionState.name}, V: ${(videoWeight * 100).toStringAsFixed(1)}%, '
      'A: ${(audioWeight * 100).toStringAsFixed(1)}%, bboxValid: $isBboxReliable)';
}

@immutable
class AdaptiveFusionOutput {
  final List<double> rawThreatProbabilities;
  final List<double> calibratedThreatProbabilities;
  final String predictedClass;
  final double rawConfidence;
  final double calibratedConfidence;
  final List<double> boundingBox;
  final bool isBboxReliable;
  final AdaptiveFusionWeights weights;
  final VideoQualityMetrics videoQuality;
  final AudioQualityMetrics audioQuality;
  final MultimodalSyncState syncState;
  final String explainableNotice;

  const AdaptiveFusionOutput({
    required this.rawThreatProbabilities,
    required this.calibratedThreatProbabilities,
    required this.predictedClass,
    required this.rawConfidence,
    required this.calibratedConfidence,
    required this.boundingBox,
    required this.isBboxReliable,
    required this.weights,
    required this.videoQuality,
    required this.audioQuality,
    required this.syncState,
    required this.explainableNotice,
  });
}

class AdaptiveFusionManager {
  /// Minimum reliability score for a modality to be considered healthy
  final double healthyThreshold;

  /// Severe degradation floor below which a modality is zeroed out
  final double criticalThreshold;

  const AdaptiveFusionManager({
    this.healthyThreshold = 0.50,
    this.criticalThreshold = 0.20,
  });

  /// Evaluates modality quality metrics and synchronization state to compute
  /// deterministic fusion weights and explainable adaptation notices.
  AdaptiveFusionWeights computeWeights({
    required VideoQualityMetrics videoQuality,
    required AudioQualityMetrics audioQuality,
    required MultimodalSyncState syncState,
    required bool isDegradedMode,
  }) {
    // 1. Handle desynchronization
    if (syncState == MultimodalSyncState.desynchronized) {
      return const AdaptiveFusionWeights(
        videoWeight: 1.0,
        audioWeight: 0.0,
        fusionState: MultimodalFusionState.desynchronizedFallback,
        adaptationReason: 'Audio-video skew exceeds 1000ms hard limit. Audio discarded, video fallback active.',
        isBboxReliable: true,
        confidenceMultiplier: 0.85, // Penalize desynchronized state
      );
    }

    // 2. Handle stream stalls / staleness
    if (videoQuality.isStale || videoQuality.isFrozen) {
      if (audioQuality.reliabilityScore >= healthyThreshold) {
        return AdaptiveFusionWeights(
          videoWeight: 0.0,
          audioWeight: 1.0,
          fusionState: MultimodalFusionState.fallbackFrozen,
          adaptationReason: videoQuality.isFrozen
              ? 'Camera video stream frozen (<0.5% delta). Grounding shifted 100% to acoustic modality; visual bbox disabled.'
              : 'Camera video stream stalled (>2000ms age). Visual bbox disabled.',
          isBboxReliable: false,
          confidenceMultiplier: 0.70, // Penalize frozen camera
        );
      } else {
        return const AdaptiveFusionWeights(
          videoWeight: 0.5,
          audioWeight: 0.5,
          fusionState: MultimodalFusionState.bothDegraded,
          adaptationReason: 'Camera stalled/frozen and microphone degraded. Dual sensor fallback.',
          isBboxReliable: false,
          confidenceMultiplier: 0.40,
        );
      }
    }

    // 3. Handle silence fallback / warming-up audio
    if (isDegradedMode || audioQuality.isSilent || audioQuality.isStale) {
      final reason = audioQuality.isSilent
          ? 'Microphone stream silent (<= -90 dBFS). Audio tensor set to -80.0 dB silence plane; 100% visual weighting.'
          : audioQuality.isStale
              ? 'Microphone stream stalled (>2000ms). Audio tensor set to silence; 100% visual weighting.'
              : 'Audio pipeline in degraded mode (buffering or offline). Visual weighting active.';

      return AdaptiveFusionWeights(
        videoWeight: 1.0,
        audioWeight: 0.0,
        fusionState: MultimodalFusionState.fallbackSilence,
        adaptationReason: reason,
        isBboxReliable: !videoQuality.isBlurred && !videoQuality.isUnderExposed,
        confidenceMultiplier: 0.90, // Slight penalty for single-modality
      );
    }

    // 4. Continuous reliability weighting based on quality scores
    final rV = videoQuality.reliabilityScore;
    final rA = audioQuality.reliabilityScore;
    const epsilon = 1e-4;

    double wV = rV / (rV + rA + epsilon);
    double wA = rA / (rV + rA + epsilon);

    MultimodalFusionState state;
    String reason;
    bool isBboxValid = true;
    double confMult = 1.0;

    if (rV >= healthyThreshold && rA >= healthyThreshold) {
      state = MultimodalFusionState.balancedMultimodal;
      reason = 'Both video (${(rV * 100).toStringAsFixed(1)}%) and audio (${(rA * 100).toStringAsFixed(1)}%) healthy. Balanced fusion active.';
      confMult = 1.0;
      isBboxValid = true;
    } else if (rV >= healthyThreshold && rA < healthyThreshold) {
      state = MultimodalFusionState.videoDominant;
      // Asymmetric squashing: if audio is poor, reduce its weight further
      if (rA < criticalThreshold) {
        wV = 1.0;
        wA = 0.0;
        reason = 'Audio severely degraded (${audioQuality.qualityWarnings.join(", ")}). Audio zeroed out; 100% video weighting.';
      } else {
        wV = math.min(1.0, wV * 1.25);
        wA = 1.0 - wV;
        reason = 'Audio degraded (${audioQuality.qualityWarnings.join(", ")}). Video weighted dominant (${(wV * 100).toStringAsFixed(1)}%).';
      }
      confMult = 0.85;
      isBboxValid = true;
    } else if (rV < healthyThreshold && rA >= healthyThreshold) {
      state = MultimodalFusionState.audioDominant;
      if (rV < criticalThreshold) {
        wV = 0.0;
        wA = 1.0;
        isBboxValid = false;
        reason = 'Video severely degraded (${videoQuality.qualityWarnings.join(", ")}). Visual bbox disabled; 100% audio weighting.';
      } else {
        wA = math.min(1.0, wA * 1.25);
        wV = 1.0 - wA;
        isBboxValid = !videoQuality.isBlurred;
        reason = 'Video degraded (${videoQuality.qualityWarnings.join(", ")}). Audio weighted dominant (${(wA * 100).toStringAsFixed(1)}%).';
      }
      confMult = 0.80;
    } else {
      // Both degraded
      state = MultimodalFusionState.bothDegraded;
      wV = 0.5;
      wA = 0.5;
      isBboxValid = false;
      confMult = 0.50; // Severe confidence penalty when sensors are degraded
      reason = 'Both modalities degraded (Video: ${(rV * 100).toStringAsFixed(1)}%, Audio: ${(rA * 100).toStringAsFixed(1)}%). Confidence heavily attenuated.';
    }

    return AdaptiveFusionWeights(
      videoWeight: wV.clamp(0.0, 1.0),
      audioWeight: wA.clamp(0.0, 1.0),
      fusionState: state,
      adaptationReason: reason,
      isBboxReliable: isBboxValid,
      confidenceMultiplier: confMult.clamp(0.1, 1.0),
    );
  }

  /// Post-processes model inference outputs by applying adaptive fusion weights.
  /// Preserves the raw prediction as baseline while emitting calibrated threat outputs.
  AdaptiveFusionOutput applyFusion({
    required List<double> rawProbabilities,
    required List<double> rawBoundingBox,
    required String rawPredictedClass,
    required double rawConfidence,
    required VideoQualityMetrics videoQuality,
    required AudioQualityMetrics audioQuality,
    required MultimodalSyncState syncState,
    required bool isDegradedMode,
  }) {
    final weights = computeWeights(
      videoQuality: videoQuality,
      audioQuality: audioQuality,
      syncState: syncState,
      isDegradedMode: isDegradedMode,
    );

    // Calibrate confidence by multiplying by confidenceMultiplier
    final calibratedConfidence = rawConfidence * weights.confidenceMultiplier;

    // Calibrate probabilities: interpolate towards uniform baseline if confidence is heavily attenuated
    final calibratedProbs = List<double>.generate(rawProbabilities.length, (i) {
      final p = rawProbabilities[i];
      final uniform = 1.0 / rawProbabilities.length;
      return (p * weights.confidenceMultiplier) + (uniform * (1.0 - weights.confidenceMultiplier));
    });

    final notice = '[${weights.fusionState.name.toUpperCase()}] V=${(weights.videoWeight * 100).toStringAsFixed(0)}% A=${(weights.audioWeight * 100).toStringAsFixed(0)}% | ${weights.adaptationReason}';

    return AdaptiveFusionOutput(
      rawThreatProbabilities: List<double>.unmodifiable(rawProbabilities),
      calibratedThreatProbabilities: List<double>.unmodifiable(calibratedProbs),
      predictedClass: rawPredictedClass,
      rawConfidence: rawConfidence,
      calibratedConfidence: calibratedConfidence,
      boundingBox: List<double>.unmodifiable(rawBoundingBox),
      isBboxReliable: weights.isBboxReliable,
      weights: weights,
      videoQuality: videoQuality,
      audioQuality: audioQuality,
      syncState: syncState,
      explainableNotice: notice,
    );
  }
}
