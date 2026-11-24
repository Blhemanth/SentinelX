// SentinelX - Mel Filterbank Matrix Generator
// Generates 128 triangular Mel-scale filters across 513 FFT frequency bins (0..8000 Hz).
// Matches PyTorch torchaudio.transforms.MelScale(n_mels=128, sample_rate=16000, n_stft=513, mel_scale='htk')
// with zero external dependencies and fast sparse evaluation.

import 'dart:math' as math;
import 'dart:typed_data';

class MelFilter {
  final int index;
  final int startBin;
  final int centerBin;
  final int endBin;
  final Float32List weights;

  const MelFilter({
    required this.index,
    required this.startBin,
    required this.centerBin,
    required this.endBin,
    required this.weights,
  });

  /// Applies this triangular filter to a 513-bin power spectrum.
  double apply(Float32List powerSpectrum) {
    double sum = 0.0;
    final count = endBin - startBin + 1;
    for (int i = 0; i < count; i++) {
      sum += powerSpectrum[startBin + i] * weights[i];
    }
    return sum;
  }
}

class MelFilterbank {
  static const int sampleRate = 16000;
  static const int nFft = 1024;
  static const int nBins = 513; // nFft / 2 + 1
  static const int nMels = 128;
  static const double fMin = 0.0;
  static const double fMax = 8000.0;

  final List<MelFilter> filters;

  MelFilterbank._(this.filters);

  static MelFilterbank? _cachedInstance;

  factory MelFilterbank() {
    _cachedInstance ??= _generate();
    return _cachedInstance!;
  }

  static double hzToMelHtk(double hz) {
    return 2595.0 * (math.log(1.0 + hz / 700.0) / math.ln10);
  }

  static double melToHzHtk(double mel) {
    return 700.0 * (math.pow(10.0, mel / 2595.0) - 1.0);
  }

  static MelFilterbank _generate() {
    final minMel = hzToMelHtk(fMin);
    final maxMel = hzToMelHtk(fMax);

    // 128 filters require 130 points (128 centers + 2 endpoints)
    final melPoints = Float64List(nMels + 2);
    final hzPoints = Float64List(nMels + 2);
    final melStep = (maxMel - minMel) / (nMels + 1);

    for (int i = 0; i < nMels + 2; i++) {
      melPoints[i] = minMel + i * melStep;
      hzPoints[i] = melToHzHtk(melPoints[i]);
    }

    final fftFreqs = Float64List(nBins);
    final freqStep = fMax / (nBins - 1);
    for (int k = 0; k < nBins; k++) {
      fftFreqs[k] = k * freqStep;
    }

    final generatedFilters = <MelFilter>[];

    for (int m = 0; m < nMels; m++) {
      final leftHz = hzPoints[m];
      final centerHz = hzPoints[m + 1];
      final rightHz = hzPoints[m + 2];

      int startBin = -1;
      int endBin = -1;
      int centerBin = -1;

      // Find active bin range
      for (int k = 0; k < nBins; k++) {
        final f = fftFreqs[k];
        if (f >= leftHz && f <= rightHz) {
          if (startBin == -1) startBin = k;
          endBin = k;
        }
        if (k < nBins - 1 && fftFreqs[k] <= centerHz && fftFreqs[k + 1] >= centerHz) {
          centerBin = (centerHz - fftFreqs[k] < fftFreqs[k + 1] - centerHz) ? k : k + 1;
        }
      }

      if (startBin == -1) startBin = 0;
      if (endBin == -1) endBin = 0;
      if (centerBin == -1) centerBin = startBin;

      final count = endBin - startBin + 1;
      final weights = Float32List(count);

      for (int i = 0; i < count; i++) {
        final k = startBin + i;
        final f = fftFreqs[k];

        final downSlope = (centerHz > leftHz) ? (f - leftHz) / (centerHz - leftHz) : 0.0;
        final upSlope = (rightHz > centerHz) ? (rightHz - f) / (rightHz - centerHz) : 0.0;
        weights[i] = math.max(0.0, math.min(downSlope, upSlope));
      }

      generatedFilters.add(MelFilter(
        index: m,
        startBin: startBin,
        centerBin: centerBin,
        endBin: endBin,
        weights: weights,
      ));
    }

    return MelFilterbank._(generatedFilters);
  }

  /// Projects a 513-bin power spectrum into 128 Mel frequency bands.
  ///
  /// [powerSpectrum]: Input Float32List of length 513.
  /// [melEnergies]: Pre-allocated Float32List of length 128 where result is written.
  void project(Float32List powerSpectrum, Float32List melEnergies) {
    assert(powerSpectrum.length >= nBins);
    assert(melEnergies.length >= nMels);

    for (int m = 0; m < nMels; m++) {
      melEnergies[m] = filters[m].apply(powerSpectrum);
    }
  }
}
