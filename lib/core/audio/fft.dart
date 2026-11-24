// SentinelX - Fast 1024-Point Radix-2 Real FFT Engine
// Implements Cooley-Tukey Decimation-in-Time (DIT) FFT with precomputed twiddle factors.
// Specifically optimized for real-time audio Mel-spectrogram processing at 16 kHz.

import 'dart:math' as math;
import 'dart:typed_data';

class Radix2FFT1024 {
  static const int fftSize = 1024;
  static const int halfSize = 512;
  static const int outputBins = 513; // Nyquist bin included: 0 .. 512

  // Precomputed tables
  static final Uint16List _bitReversalTable = _initBitReversal();
  static final Float64List _cosTable = Float64List(fftSize ~/ 2);
  static final Float64List _sinTable = Float64List(fftSize ~/ 2);
  static final Float64List _hannWindow = _initHannWindow();

  static bool _tablesInitialized = false;

  Radix2FFT1024() {
    _ensureInitialized();
  }

  static void _ensureInitialized() {
    if (_tablesInitialized) return;
    for (int i = 0; i < fftSize ~/ 2; i++) {
      final angle = -2.0 * math.pi * i / fftSize;
      _cosTable[i] = math.cos(angle);
      _sinTable[i] = math.sin(angle);
    }
    _tablesInitialized = true;
  }

  static Uint16List _initBitReversal() {
    final table = Uint16List(fftSize);
    int j = 0;
    for (int i = 0; i < fftSize - 1; i++) {
      table[i] = j;
      int k = fftSize ~/ 2;
      while (k <= j) {
        j -= k;
        k ~/= 2;
      }
      j += k;
    }
    table[fftSize - 1] = fftSize - 1;
    return table;
  }

  static Float64List _initHannWindow() {
    final window = Float64List(fftSize);
    // Periodic Hann window matching torchaudio / PyTorch torch.hann_window(1024, periodic=True)
    for (int i = 0; i < fftSize; i++) {
      window[i] = 0.5 - 0.5 * math.cos(2.0 * math.pi * i / fftSize);
    }
    return window;
  }

  /// Returns the precomputed 1024-point periodic Hann window
  Float64List get hannWindow => _hannWindow;

  /// Applies Hann window and computes the 513-bin Power Spectrum (|X[k]|^2).
  ///
  /// [input]: Float32List of length 1024.
  /// [powerSpectrum]: Pre-allocated Float32List of length 513 where result is written.
  void computePowerSpectrum(Float32List input, Float32List powerSpectrum) {
    assert(input.length >= fftSize);
    assert(powerSpectrum.length >= outputBins);
    _ensureInitialized();

    final real = Float64List(fftSize);
    final imag = Float64List(fftSize);

    // Apply window and bit-reversal permutation
    for (int i = 0; i < fftSize; i++) {
      final rev = _bitReversalTable[i];
      real[rev] = input[i] * _hannWindow[i];
      imag[rev] = 0.0;
    }

    // Cooley-Tukey butterfly stages
    int l = 2;
    while (l <= fftSize) {
      final halfL = l ~/ 2;
      final step = fftSize ~/ l;

      for (int i = 0; i < fftSize; i += l) {
        for (int j = 0; j < halfL; j++) {
          final tableIdx = j * step;
          final wr = _cosTable[tableIdx];
          final wi = _sinTable[tableIdx];

          final tr = real[i + j + halfL];
          final ti = imag[i + j + halfL];

          final vr = tr * wr - ti * wi;
          final vi = tr * wi + ti * wr;

          final ur = real[i + j];
          final ui = imag[i + j];

          real[i + j] = ur + vr;
          imag[i + j] = ui + vi;

          real[i + j + halfL] = ur - vr;
          imag[i + j + halfL] = ui - vi;
        }
      }
      l *= 2;
    }

    // Calculate power spectrum for non-redundant positive frequencies (k = 0..512)
    for (int k = 0; k < outputBins; k++) {
      final r = real[k];
      final im = imag[k];
      powerSpectrum[k] = (r * r + im * im).toDouble();
    }
  }
}
