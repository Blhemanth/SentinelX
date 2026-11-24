// SentinelX - Digital Signal Processing (DSP) Audio Preprocessor
// Converts raw 16 kHz PCM waveforms into normalized 128x128 Mel-spectrogram tensors.
// Mathematically identical to server_ml/preprocessor.py and PyTorch torchaudio:
// 1. Center reflection padding (512 samples on each end)
// 2. 1024-point STFT with periodic Hann window and 512 hop length
// 3. 128-band HTK Mel filterbank projection (0..8000 Hz)
// 4. Amplitude-to-Decibel conversion with 80.0 dB dynamic range clamping
// 5. Normalization / padding to exact tensor shape [1, 1, 128, 128] (16,384 Float32 elements).

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'fft.dart';
import 'mel_filterbank.dart';

@immutable
class PreprocessedAudioOutput {
  final Float32List audioTensor; // Exactly 16,384 Float32 elements [1, 1, 128, 128]
  final double minDb;
  final double maxDb;
  final double meanDb;
  final int timeFramesGenerated;
  final double latencyMs;
  final bool isValid;
  final String? errorMessage;

  const PreprocessedAudioOutput({
    required this.audioTensor,
    required this.minDb,
    required this.maxDb,
    required this.meanDb,
    required this.timeFramesGenerated,
    required this.latencyMs,
    required this.isValid,
    this.errorMessage,
  });

  /// Factory for failed preprocessing state (never silently produces corrupt audio)
  factory PreprocessedAudioOutput.failure(String error, [double latencyMs = 0.0]) {
    return PreprocessedAudioOutput(
      audioTensor: Float32List(16384),
      minDb: 0.0,
      maxDb: 0.0,
      meanDb: 0.0,
      timeFramesGenerated: 0,
      latencyMs: latencyMs,
      isValid: false,
      errorMessage: error,
    );
  }
}

class AudioPreprocessor {
  static const int sampleRate = 16000;
  static const int nFft = 1024;
  static const int hopLength = 512;
  static const int nMels = 128;
  static const int targetTimeSteps = 128;
  static const int tensorElements = 1 * 1 * nMels * targetTimeSteps; // 16,384 floats

  final Radix2FFT1024 _fft = Radix2FFT1024();
  final MelFilterbank _filterbank = MelFilterbank();

  /// Processes raw 16 kHz mono PCM samples into a normalized [1, 1, 128, 128] Mel-spectrogram tensor.
  ///
  /// [samples]: Float32List of normalized PCM audio in range [-1.0, 1.0].
  PreprocessedAudioOutput processAudio(Float32List samples) {
    final sw = Stopwatch()..start();

    if (samples.isEmpty) {
      return PreprocessedAudioOutput.failure('Input audio sample buffer is empty (0 samples).');
    }

    try {
      final numSamples = samples.length;
      final padSize = nFft ~/ 2; // 512 samples reflection padding

      // 1. Center Reflection Padding (matching PyTorch torchaudio center=True, pad_mode='reflect')
      final paddedLength = numSamples + 2 * padSize;
      final padded = Float32List(paddedLength);

      // Left reflection: reflect around sample 0 (skip index 0 to match reflect mode)
      for (int i = 0; i < padSize; i++) {
        final reflectIdx = (padSize - i).clamp(0, numSamples - 1);
        padded[i] = samples[reflectIdx];
      }

      // Center: copy input waveform
      for (int i = 0; i < numSamples; i++) {
        padded[padSize + i] = samples[i];
      }

      // Right reflection: reflect around last sample
      for (int i = 0; i < padSize; i++) {
        final reflectIdx = (numSamples - 2 - i).clamp(0, numSamples - 1);
        padded[padSize + numSamples + i] = samples[reflectIdx];
      }

      // 2. Compute STFT frames
      final numFrames = 1 + (paddedLength - nFft) ~/ hopLength;
      if (numFrames <= 0) {
        return PreprocessedAudioOutput.failure('Insufficient audio length to compute STFT ($numSamples samples).');
      }

      final frameBuffer = Float32List(nFft);
      final powerSpectrum = Float32List(nFft ~/ 2 + 1); // 513 bins
      final melEnergies = Float32List(nMels);

      // Raw decibel matrix [nMels, numFrames]
      final rawDecibels = List<Float32List>.generate(nMels, (_) => Float32List(numFrames));
      double globalMaxDb = -1e9;
      double globalMinDb = 1e9;

      for (int t = 0; t < numFrames; t++) {
        final offset = t * hopLength;
        for (int i = 0; i < nFft; i++) {
          frameBuffer[i] = padded[offset + i];
        }

        // Compute 513-bin Power Spectrum
        _fft.computePowerSpectrum(frameBuffer, powerSpectrum);

        // Project onto 128 Mel frequency bands
        _filterbank.project(powerSpectrum, melEnergies);

        // Convert power to decibels: 10 * log10(max(power, 1e-10))
        for (int m = 0; m < nMels; m++) {
          final p = melEnergies[m];
          final db = 10.0 * (math.log(math.max(p, 1e-10)) / math.ln10);
          rawDecibels[m][t] = db;
          if (db > globalMaxDb) globalMaxDb = db;
          if (db < globalMinDb) globalMinDb = db;
        }
      }

      // 3. Top-dB Clamping (AmplitudeToDB top_db = 80.0)
      // Clamps all values to [globalMaxDb - 80.0, globalMaxDb]
      final floorDb = globalMaxDb - 80.0;
      double clampedMinDb = 1e9;
      double clampedSumDb = 0.0;

      for (int m = 0; m < nMels; m++) {
        for (int t = 0; t < numFrames; t++) {
          if (rawDecibels[m][t] < floorDb) {
            rawDecibels[m][t] = floorDb;
          }
          final v = rawDecibels[m][t];
          if (v < clampedMinDb) clampedMinDb = v;
          clampedSumDb += v;
        }
      }

      // 4. Time Dimension Slicing / Padding to exact 128 steps
      // Output tensor layout: [1, 1, 128, 128] contiguous Float32List
      final outputTensor = Float32List(tensorElements);
      // Matching server_ml/preprocessor.py: pad with mel_db.min()
      final padValue = clampedMinDb.isFinite ? clampedMinDb : -80.0;

      for (int m = 0; m < nMels; m++) {
        final rowOffset = m * targetTimeSteps;
        for (int t = 0; t < targetTimeSteps; t++) {
          if (t < numFrames) {
            final val = rawDecibels[m][t];
            outputTensor[rowOffset + t] = val.isFinite ? val : -80.0;
          } else {
            // Pad remaining time steps with minimum dB (acoustic silence)
            outputTensor[rowOffset + t] = padValue;
          }
        }
      }

      // 5. Numerical Integrity Validation
      for (int i = 0; i < tensorElements; i++) {
        if (!outputTensor[i].isFinite) {
          return PreprocessedAudioOutput.failure('Generated audio tensor contains non-finite values (NaN or Inf).');
        }
      }

      sw.stop();
      final totalFrames = nMels * numFrames;
      final meanDb = totalFrames > 0 ? clampedSumDb / totalFrames : 0.0;

      return PreprocessedAudioOutput(
        audioTensor: outputTensor,
        minDb: clampedMinDb,
        maxDb: globalMaxDb,
        meanDb: meanDb,
        timeFramesGenerated: numFrames,
        latencyMs: sw.elapsedMicroseconds / 1000.0,
        isValid: true,
      );
    } catch (e) {
      sw.stop();
      return PreprocessedAudioOutput.failure('Audio preprocessing exception: $e', sw.elapsedMicroseconds / 1000.0);
    }
  }
}
