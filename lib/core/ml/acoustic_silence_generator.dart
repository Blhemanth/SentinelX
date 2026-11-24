// SentinelX - Acoustic Silence Generator & Degraded Mode Handler
// Generates calibrated acoustic silence baseline Float32 tensors for video-only feeds.
// Replicates server_ml/preprocessor.py get_acoustic_silence() behavior in Dart.
//
// INTEGRITY NOTICE:
// Live microphone pipeline is not yet attached. All inferences executed with this baseline
// are formally marked as DEGRADED MODE (video_only_degraded) and must NOT claim validated
// multi-modal classification accuracy.

import 'package:flutter/foundation.dart';

@immutable
class AcousticSilenceMetadata {
  final int batchSize;
  final int channels;
  final int nMels;
  final int timeSteps;
  final double silenceDb;
  final String modalityMode;
  final String diagnosticNotice;

  const AcousticSilenceMetadata({
    this.batchSize = 1,
    this.channels = 1,
    this.nMels = 128,
    this.timeSteps = 128,
    this.silenceDb = -80.0,
    this.modalityMode = 'video_only_degraded',
    this.diagnosticNotice = 'DEGRADED MODE: VIDEO ONLY — CALIBRATED SILENCE BASELINE (-80.0 dB)',
  });

  int get totalElements => batchSize * channels * nMels * timeSteps;
  int get byteSize => totalElements * 4; // Float32 = 4 bytes
  List<int> get shape => [batchSize, channels, nMels, timeSteps];
}

class AcousticSilenceGenerator {
  static const double defaultSilenceDb = -80.0;
  static const int defaultNMels = 128;
  static const int defaultTimeSteps = 128;

  final AcousticSilenceMetadata metadata;
  final Float32List _cachedSilenceTensor;

  AcousticSilenceGenerator({
    double silenceDb = defaultSilenceDb,
    int nMels = defaultNMels,
    int timeSteps = defaultTimeSteps,
  })  : metadata = AcousticSilenceMetadata(
          silenceDb: silenceDb,
          nMels: nMels,
          timeSteps: timeSteps,
        ),
        _cachedSilenceTensor = _createTensor(silenceDb, nMels, timeSteps);

  /// Returns the pre-allocated immutable-view Float32 tensor [1, 1, 128, 128]
  /// filled with -80.0 dB (log-decibel acoustic silence).
  Float32List get silenceTensor => _cachedSilenceTensor;

  /// Creates a fresh copy if caller needs independent buffer mutation
  Float32List createCopy() => Float32List.fromList(_cachedSilenceTensor);

  static Float32List _createTensor(double db, int mels, int steps) {
    final length = 1 * 1 * mels * steps; // 16,384 elements (65,536 bytes)
    final tensor = Float32List(length);
    tensor.fillRange(0, length, db);
    return tensor;
  }
}
