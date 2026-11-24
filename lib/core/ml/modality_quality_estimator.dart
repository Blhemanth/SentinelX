// SentinelX - Modality Quality Estimator
// High-performance, deterministic estimation of visual and acoustic signal quality.
// Evaluates brightness, contrast, sharpness, temporal freezing, RMS energy, SNR,
// clipping, digital silence, and stream freshness in pure Dart.

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sentinel_x/core/camera/camera_frame.dart';
import 'package:sentinel_x/core/camera/temporal_frame_buffer.dart';
import 'package:sentinel_x/core/audio/temporal_audio_buffer.dart';

@immutable
class VideoQualityMetrics {
  /// Average pixel luma across sampled pixels (0.0 to 255.0)
  final double brightness;

  /// Standard deviation of pixel luma (contrast measure, 0.0 to 127.5)
  final double contrast;

  /// High-frequency gradient / Laplacian variance score (sharpness measure)
  final double sharpness;

  /// Flagged true if average brightness < 30.0 (severely underexposed / pitch black)
  final bool isUnderExposed;

  /// Flagged true if average brightness > 225.0 (severely overexposed / washed out)
  final bool isOverExposed;

  /// Flagged true if contrast < 15.0 (flat image, fog, covered lens)
  final bool isLowContrast;

  /// Flagged true if sharpness < 15.0 (out of focus, smudged lens)
  final bool isBlurred;

  /// Flagged true if current frame is near-identical to previous frame (< 0.5% difference)
  final bool isFrozen;

  /// Age of newest frame relative to evaluation timestamp (ms)
  final int ageMs;

  /// Flagged true if age > 2000 ms
  final bool isStale;

  /// Normalized aggregate reliability score [0.0, 1.0]
  final double reliabilityScore;

  /// Explanatory warning notices
  final List<String> qualityWarnings;

  const VideoQualityMetrics({
    required this.brightness,
    required this.contrast,
    required this.sharpness,
    required this.isUnderExposed,
    required this.isOverExposed,
    required this.isLowContrast,
    required this.isBlurred,
    required this.isFrozen,
    required this.ageMs,
    required this.isStale,
    required this.reliabilityScore,
    required this.qualityWarnings,
  });

  factory VideoQualityMetrics.uninitialized() {
    return const VideoQualityMetrics(
      brightness: 0.0,
      contrast: 0.0,
      sharpness: 0.0,
      isUnderExposed: true,
      isOverExposed: false,
      isLowContrast: true,
      isBlurred: true,
      isFrozen: false,
      ageMs: 999999,
      isStale: true,
      reliabilityScore: 0.0,
      qualityWarnings: ['Video stream uninitialized or empty'],
    );
  }

  @override
  String toString() =>
      'VideoQuality(score: ${(reliabilityScore * 100).toStringAsFixed(1)}%, '
      'bright: ${brightness.toStringAsFixed(1)}, cont: ${contrast.toStringAsFixed(1)}, '
      'sharp: ${sharpness.toStringAsFixed(1)}, frozen: $isFrozen, stale: $isStale)';
}

@immutable
class AudioQualityMetrics {
  /// Root-Mean-Square signal amplitude [0.0, 1.0]
  final double rmsEnergy;

  /// Decibel relative to full scale: 20 * log10(RMS) [-100.0, 0.0] dBFS
  final double dbLevel;

  /// Estimated Signal-to-Noise Ratio (dB)
  final double estimatedSnrDb;

  /// Percentage of samples hitting dynamic range saturation (>= 0.99)
  final double clippingPercentage;

  /// Flagged true if RMS < 1e-4 or dBFS <= -90.0 (near or total digital silence)
  final bool isSilent;

  /// Flagged true if dBFS < -65.0 (extremely faint audio, mic distance / obstruction)
  final bool isLowEnergy;

  /// Flagged true if clippingPercentage > 1.0% (amplifier saturation or wind pop)
  final bool isClipped;

  /// Flagged true if SNR < 6.0 dB when dynamic energy is detected
  final bool isNoisy;

  /// Age of newest audio chunk relative to evaluation timestamp (ms)
  final int ageMs;

  /// Flagged true if age > 2000 ms
  final bool isStale;

  /// Normalized aggregate reliability score [0.0, 1.0]
  final double reliabilityScore;

  /// Explanatory warning notices
  final List<String> qualityWarnings;

  const AudioQualityMetrics({
    required this.rmsEnergy,
    required this.dbLevel,
    required this.estimatedSnrDb,
    required this.clippingPercentage,
    required this.isSilent,
    required this.isLowEnergy,
    required this.isClipped,
    required this.isNoisy,
    required this.ageMs,
    required this.isStale,
    required this.reliabilityScore,
    required this.qualityWarnings,
  });

  factory AudioQualityMetrics.uninitialized() {
    return const AudioQualityMetrics(
      rmsEnergy: 0.0,
      dbLevel: -100.0,
      estimatedSnrDb: 0.0,
      clippingPercentage: 0.0,
      isSilent: true,
      isLowEnergy: true,
      isClipped: false,
      isNoisy: false,
      ageMs: 999999,
      isStale: true,
      reliabilityScore: 0.0,
      qualityWarnings: ['Audio stream uninitialized or empty'],
    );
  }

  @override
  String toString() =>
      'AudioQuality(score: ${(reliabilityScore * 100).toStringAsFixed(1)}%, '
      'dB: ${dbLevel.toStringAsFixed(1)}, SNR: ${estimatedSnrDb.toStringAsFixed(1)}dB, '
      'clip: ${clippingPercentage.toStringAsFixed(2)}%, silent: $isSilent, stale: $isStale)';
}

class ModalityQualityEstimator {
  Uint8List? _previousRgbSample;
  double _noiseFloorRms = 0.001; // Adaptive noise floor tracking (~ -60 dBFS)

  /// Evaluates the visual quality of the latest frame in the temporal buffer.
  /// Operates on a regular subsampling grid (stride=4, 56x56 = 3,136 samples)
  /// ensuring execution in under 0.8 ms in compiled Dart.
  VideoQualityMetrics estimateVideoQuality(
    TemporalFrameBuffer videoBuffer, {
    DateTime? nowUtc,
    Duration maxStaleDuration = const Duration(milliseconds: 2000),
  }) {
    if (videoBuffer.currentCount == 0) {
      return VideoQualityMetrics.uninitialized();
    }

    final metadata = videoBuffer.getWindowMetadata(
      maxStaleDuration: maxStaleDuration,
      nowUtc: nowUtc,
    );

    final CameraFrame latestFrame = videoBuffer.getFrames().last;
    final Uint8List rgbBytes = latestFrame.rgbBytes;
    final int width = latestFrame.width;
    final int height = latestFrame.height;

    final warnings = <String>[];
    const stride = 4; // Subsample grid: 224 / 4 = 56 samples per axis
    final int sampleWidth = width ~/ stride;
    final int sampleHeight = height ~/ stride;
    final int totalSamples = sampleWidth * sampleHeight;

    final lumaGrid = Float32List(totalSamples);
    double sumLuma = 0.0;
    double sumSqLuma = 0.0;

    int sampleIdx = 0;
    for (int y = 0; y < height; y += stride) {
      final rowOffset = y * width * 3;
      for (int x = 0; x < width; x += stride) {
        final pxOffset = rowOffset + (x * 3);
        final r = rgbBytes[pxOffset];
        final g = rgbBytes[pxOffset + 1];
        final b = rgbBytes[pxOffset + 2];

        // Rec. 601 luma: 0.299 R + 0.587 G + 0.114 B
        final luma = (0.299 * r) + (0.587 * g) + (0.114 * b);
        lumaGrid[sampleIdx++] = luma;
        sumLuma += luma;
        sumSqLuma += luma * luma;
      }
    }

    final meanLuma = sumLuma / totalSamples;
    final varianceLuma = (sumSqLuma / totalSamples) - (meanLuma * meanLuma);
    final contrast = math.sqrt(math.max(0.0, varianceLuma));

    // High-frequency gradient (Laplacian sharpness estimate on 56x56 grid)
    double gradientSum = 0.0;
    int edgeCount = 0;
    for (int y = 1; y < sampleHeight - 1; y++) {
      final row = y * sampleWidth;
      for (int x = 1; x < sampleWidth - 1; x++) {
        final c = lumaGrid[row + x];
        final top = lumaGrid[row - sampleWidth + x];
        final bottom = lumaGrid[row + sampleWidth + x];
        final left = lumaGrid[row + x - 1];
        final right = lumaGrid[row + x + 1];
        final lap = (4.0 * c - top - bottom - left - right).abs();
        gradientSum += lap;
        edgeCount++;
      }
    }
    final sharpness = edgeCount > 0 ? gradientSum / edgeCount : 0.0;

    // Temporal frozen frame detection
    bool isFrozen = false;
    final currentSample = Uint8List(totalSamples);
    for (int i = 0; i < totalSamples; i++) {
      currentSample[i] = lumaGrid[i].round().clamp(0, 255);
    }

    if (_previousRgbSample != null && _previousRgbSample!.length == totalSamples) {
      int diffCount = 0;
      for (int i = 0; i < totalSamples; i++) {
        if ((currentSample[i] - _previousRgbSample![i]).abs() > 3) {
          diffCount++;
        }
      }
      final diffRatio = diffCount / totalSamples;
      if (diffRatio < 0.005) {
        // Less than 0.5% of pixels changed
        isFrozen = true;
        warnings.add('Camera stream is frozen / static (frame delta < 0.5%)');
      }
    }
    _previousRgbSample = currentSample;

    final isUnderExposed = meanLuma < 30.0;
    final isOverExposed = meanLuma > 225.0;
    final isLowContrast = contrast < 15.0;
    final isBlurred = sharpness < 15.0;
    final isStale = metadata.isStale;

    if (isUnderExposed) warnings.add('Video underexposed (brightness: ${meanLuma.toStringAsFixed(1)} < 30)');
    if (isOverExposed) warnings.add('Video overexposed (brightness: ${meanLuma.toStringAsFixed(1)} > 225)');
    if (isLowContrast) warnings.add('Video low contrast (${contrast.toStringAsFixed(1)} < 15)');
    if (isBlurred) warnings.add('Video blurred / low sharpness (${sharpness.toStringAsFixed(1)} < 15)');
    if (isStale) warnings.add('Video stream stale (${metadata.ageMs}ms > 2000ms)');

    // Compute composite video reliability score [0.0, 1.0]
    double score = 1.0;
    if (isStale) {
      score = 0.0;
    } else if (isFrozen) {
      score *= 0.1;
    } else {
      // Exposure penalty
      if (meanLuma < 30.0) {
        score *= (meanLuma / 30.0).clamp(0.1, 1.0);
      } else if (meanLuma > 225.0) {
        score *= ((255.0 - meanLuma) / 30.0).clamp(0.1, 1.0);
      }

      // Contrast penalty
      if (contrast < 20.0) {
        score *= (contrast / 20.0).clamp(0.2, 1.0);
      }

      // Sharpness penalty
      if (sharpness < 20.0) {
        score *= (sharpness / 20.0).clamp(0.3, 1.0);
      }
    }

    return VideoQualityMetrics(
      brightness: meanLuma,
      contrast: contrast,
      sharpness: sharpness,
      isUnderExposed: isUnderExposed,
      isOverExposed: isOverExposed,
      isLowContrast: isLowContrast,
      isBlurred: isBlurred,
      isFrozen: isFrozen,
      ageMs: metadata.ageMs,
      isStale: isStale,
      reliabilityScore: score.clamp(0.0, 1.0),
      qualityWarnings: List<String>.unmodifiable(warnings),
    );
  }

  /// Evaluates acoustic signal quality directly from a TemporalAudioBuffer.
  AudioQualityMetrics estimateAudioBufferQuality(
    TemporalAudioBuffer? audioBuffer, {
    bool isAudioServiceReady = false,
    DateTime? nowUtc,
    Duration maxStaleDuration = const Duration(milliseconds: 2000),
  }) {
    if (audioBuffer == null || !isAudioServiceReady || audioBuffer.currentCount == 0) {
      return AudioQualityMetrics.uninitialized();
    }
    final meta = audioBuffer.getWindowMetadata(
      maxStaleDuration: maxStaleDuration,
      nowUtc: nowUtc,
    );
    final snapshot = audioBuffer.extractSnapshot(64000);
    return estimateAudioQuality(
      snapshot,
      audioMeta: meta,
      nowUtc: nowUtc,
      maxStaleDuration: maxStaleDuration,
    );
  }

  /// Evaluates acoustic signal quality from a 4-second PCM16 Float32 snapshot.
  /// Operates in O(N) over 64,000 samples (< 0.5 ms in compiled Dart).
  AudioQualityMetrics estimateAudioQuality(
    Float32List samples, {
    AudioWindowMetadata? audioMeta,
    DateTime? nowUtc,
    Duration maxStaleDuration = const Duration(milliseconds: 2000),
  }) {
    if (samples.isEmpty) {
      return AudioQualityMetrics.uninitialized();
    }

    final warnings = <String>[];
    final len = samples.length;

    double sumSq = 0.0;
    int clippedCount = 0;

    for (int i = 0; i < len; i++) {
      final s = samples[i];
      sumSq += s * s;
      if (s.abs() >= 0.99) {
        clippedCount++;
      }
    }

    final rms = math.sqrt(sumSq / len);
    final dbLevel = rms > 1e-5
        ? (20.0 * (math.log(rms) / math.ln10)).clamp(-100.0, 0.0)
        : -100.0;

    final clippingPct = (clippedCount / len) * 100.0;

    // Adaptive noise floor tracking (minimum energy observed with slow upward drift)
    if (rms > 1e-5 && rms < _noiseFloorRms) {
      _noiseFloorRms = rms;
    } else {
      _noiseFloorRms = (_noiseFloorRms * 0.999) + (rms * 0.001);
    }

    final snrLinear = rms / math.max(_noiseFloorRms, 1e-5);
    final snrDb = snrLinear > 1.0
        ? (20.0 * (math.log(snrLinear) / math.ln10)).clamp(0.0, 60.0)
        : 0.0;

    final ageMs = audioMeta?.ageMs ?? 0;
    final isStale = audioMeta?.isStale ?? false;
    final isSilent = dbLevel <= -90.0 || rms < 1e-4;
    final isLowEnergy = dbLevel < -65.0 && !isSilent;
    final isClipped = clippingPct > 1.0;
    final isNoisy = snrDb < 6.0 && !isSilent && !isLowEnergy;

    if (isSilent) warnings.add('Audio digital silence detected (dB: ${dbLevel.toStringAsFixed(1)} <= -90)');
    if (isLowEnergy) warnings.add('Audio low acoustic energy (dB: ${dbLevel.toStringAsFixed(1)} < -65)');
    if (isClipped) warnings.add('Audio signal saturation / clipping (${clippingPct.toStringAsFixed(2)}% samples clipped)');
    if (isNoisy) warnings.add('Audio low SNR / heavy background noise (SNR: ${snrDb.toStringAsFixed(1)} dB < 6 dB)');
    if (isStale) warnings.add('Audio stream stale (${ageMs}ms > 2000ms)');

    // Compute composite audio reliability score [0.0, 1.0]
    double score = 1.0;
    if (isStale) {
      score = 0.0;
    } else if (isSilent) {
      score = 0.05; // Calibrated silence fallback
    } else {
      // Energy profile scoring
      if (dbLevel < -65.0) {
        score *= ((dbLevel + 90.0) / 25.0).clamp(0.1, 1.0);
      }

      // Clipping penalty
      if (clippingPct > 1.0) {
        score *= (1.0 - (clippingPct / 20.0)).clamp(0.2, 1.0);
      }

      // SNR penalty
      if (snrDb < 15.0) {
        score *= (snrDb / 15.0).clamp(0.3, 1.0);
      }
    }

    return AudioQualityMetrics(
      rmsEnergy: rms,
      dbLevel: dbLevel,
      estimatedSnrDb: snrDb,
      clippingPercentage: clippingPct,
      isSilent: isSilent,
      isLowEnergy: isLowEnergy,
      isClipped: isClipped,
      isNoisy: isNoisy,
      ageMs: ageMs,
      isStale: isStale,
      reliabilityScore: score.clamp(0.0, 1.0),
      qualityWarnings: List<String>.unmodifiable(warnings),
    );
  }

  /// Resets temporal state (e.g. on stream reconnection)
  void reset() {
    _previousRgbSample = null;
    _noiseFloorRms = 0.001;
  }
}
