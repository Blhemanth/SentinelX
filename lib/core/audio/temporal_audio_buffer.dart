// SentinelX - Bounded Circular Temporal Audio Ring Buffer
// Manages a fixed-capacity ring buffer of 16 kHz mono Float32 audio samples.
// Ensures strict bounded memory: oldest samples are overwritten automatically,
// preventing unbounded audio buffer accumulation over hours of continuous operation.

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sentinel_x/core/utils/monotonic_clock.dart';

@immutable
class AudioWindowMetadata {
  final DateTime windowStartUtc;
  final DateTime windowEndUtc;
  final int windowStartMonotonicUs;
  final int windowEndMonotonicUs;
  final int sampleCount;
  final int durationMs; // 4000 ms for 64,000 samples
  final int chunkCount;
  final double meanChunkIntervalMs;
  final bool isStale;
  final int ageMs;
  final double rmsVolume;
  final double dbLevel;

  const AudioWindowMetadata({
    required this.windowStartUtc,
    required this.windowEndUtc,
    required this.windowStartMonotonicUs,
    required this.windowEndMonotonicUs,
    required this.sampleCount,
    required this.durationMs,
    required this.chunkCount,
    required this.meanChunkIntervalMs,
    required this.isStale,
    required this.ageMs,
    required this.rmsVolume,
    required this.dbLevel,
  });

  factory AudioWindowMetadata.empty() {
    final now = DateTime.now().toUtc();
    return AudioWindowMetadata(
      windowStartUtc: now.subtract(const Duration(milliseconds: 4000)),
      windowEndUtc: now,
      windowStartMonotonicUs: 0,
      windowEndMonotonicUs: 0,
      sampleCount: 0,
      durationMs: 4000,
      chunkCount: 0,
      meanChunkIntervalMs: 0.0,
      isStale: true,
      ageMs: 999999,
      rmsVolume: 0.0,
      dbLevel: -100.0,
    );
  }

  @override
  String toString() =>
      'AudioWindow(samples: $sampleCount, duration: ${durationMs}ms, chunks: $chunkCount, stale: $isStale, age: ${ageMs}ms, dB: ${dbLevel.toStringAsFixed(1)})';
}

@immutable
class AudioBufferTelemetry {
  final int totalSamplesIngested;
  final int currentBufferLength;
  final int bufferCapacity;
  final double bufferFillPercentage;
  final bool isReady;
  final double currentRmsVolume;
  final double currentDbLevel; // Decibels Relative to Full Scale (dBFS), <= 0.0 dBFS

  const AudioBufferTelemetry({
    required this.totalSamplesIngested,
    required this.currentBufferLength,
    required this.bufferCapacity,
    required this.bufferFillPercentage,
    required this.isReady,
    required this.currentRmsVolume,
    required this.currentDbLevel,
  });

  /// Explicit alias for decibels relative to full scale.
  double get currentDbFs => currentDbLevel;

  /// Digital silence threshold (calibrated baseline: -75.0 dBFS or lower)
  bool get isDigitalSilence => currentDbLevel <= -75.0;

  /// Ambient quiet background noise (-75.0 to -40.0 dBFS)
  bool get isAmbientQuiet => currentDbLevel > -75.0 && currentDbLevel <= -40.0;

  /// Conversational speech / office sound (-40.0 to -18.0 dBFS)
  bool get isSpeechNormal => currentDbLevel > -40.0 && currentDbLevel <= -18.0;

  /// Acoustic spike or shouting (> -18.0 dBFS)
  bool get isAcousticPeak => currentDbLevel > -18.0;

  /// Human-readable acoustic energy classification
  String get acousticStateLabel {
    if (isDigitalSilence) return 'DIGITAL SILENCE (-80 dBFS baseline)';
    if (isAmbientQuiet) return 'AMBIENT ROOM NOISE';
    if (isSpeechNormal) return 'CONVERSATIONAL SPEECH';
    return 'ACOUSTIC SPIKE / PEAK';
  }

  @override
  String toString() =>
      'AudioBuffer(fill: ${bufferFillPercentage.toStringAsFixed(1)}%, ready: $isReady, dBFS: ${currentDbLevel.toStringAsFixed(1)} [$acousticStateLabel])';
}

class TemporalAudioBuffer {
  /// Default capacity: 65,536 samples (exactly 4.096 seconds at 16,000 Hz)
  static const int defaultCapacity = 65536;

  /// Required samples to produce a complete 128-frame Mel-spectrogram
  static const int defaultRequiredSamples = 64000; // 4.0 seconds at 16 kHz

  final int capacity;
  final int requiredSamples;
  final Float32List _buffer;

  int _head = 0;
  int _count = 0;
  int _totalIngested = 0;
  double _lastRms = 0.0;

  DateTime _lastChunkUtc = DateTime.now().toUtc();
  int _lastChunkMonotonicUs = 0;
  int _chunkCount = 0;
  DateTime? _previousChunkUtc;
  final List<int> _recentChunkIntervalsMs = <int>[];

  TemporalAudioBuffer({
    this.capacity = defaultCapacity,
    this.requiredSamples = defaultRequiredSamples,
  })  : assert(capacity >= requiredSamples),
        _buffer = Float32List(capacity);

  int get currentCount => _count;
  int get totalIngested => _totalIngested;
  bool get isReady => _count >= requiredSamples;
  double get lastRms => _lastRms;
  int get chunkCount => _chunkCount;
  DateTime get lastChunkUtc => _lastChunkUtc;
  int get lastChunkMonotonicUs => _lastChunkMonotonicUs;

  /// Pushes a sequence of raw Float32 audio samples into the ring buffer.
  /// Overwrites oldest samples when capacity is reached ($O(1)$ constant memory).
  void pushSamples(
    Float32List samples, {
    DateTime? captureTime,
    int? monotonicUs,
  }) {
    if (samples.isEmpty) return;

    final now = captureTime ?? DateTime.now().toUtc();
    final monoUs = monotonicUs ?? MonotonicClock.nowMicros;

    if (_previousChunkUtc != null) {
      final interval = now.difference(_previousChunkUtc!).inMilliseconds.abs();
      _recentChunkIntervalsMs.add(interval);
      if (_recentChunkIntervalsMs.length > 20) {
        _recentChunkIntervalsMs.removeAt(0);
      }
    }
    _previousChunkUtc = now;
    _lastChunkUtc = now;
    _lastChunkMonotonicUs = monoUs;
    _chunkCount++;

    double sumSq = 0.0;
    final len = samples.length;

    for (int i = 0; i < len; i++) {
      final s = samples[i].clamp(-1.0, 1.0);
      _buffer[_head] = s;
      _head = (_head + 1) % capacity;
      if (_count < capacity) {
        _count++;
      }
      sumSq += s * s;
    }

    _totalIngested += len;
    _lastRms = math.sqrt(sumSq / len);
  }

  /// Pushes raw 16-bit little-endian PCM bytes, converting them to normalized Float32.
  void pushPcm16Bytes(
    Uint8List pcmBytes, {
    DateTime? captureTime,
    int? monotonicUs,
  }) {
    if (pcmBytes.isEmpty) return;
    final numSamples = pcmBytes.length ~/ 2;
    if (numSamples == 0) return;

    final byteData = ByteData.sublistView(pcmBytes);
    final floatSamples = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final sampleInt16 = byteData.getInt16(i * 2, Endian.little);
      floatSamples[i] = sampleInt16 / 32768.0;
    }

    pushSamples(floatSamples, captureTime: captureTime, monotonicUs: monotonicUs);
  }

  /// Extracts the most recent [numSamples] in chronological order.
  /// If the buffer contains fewer than [numSamples], the available samples are padded
  /// with silence (0.0) on the left.
  Float32List extractSnapshot([int? numSamples]) {
    final target = numSamples ?? requiredSamples;
    final snapshot = Float32List(target);

    final available = math.min(_count, target);
    final padCount = target - available;

    // Zero-fill padding
    for (int i = 0; i < padCount; i++) {
      snapshot[i] = 0.0;
    }

    // Copy available samples chronologically from oldest to newest
    final startIdx = (_head - available + capacity) % capacity;
    for (int i = 0; i < available; i++) {
      snapshot[padCount + i] = _buffer[(startIdx + i) % capacity];
    }

    return snapshot;
  }

  /// Calculates real-time telemetry metrics.
  AudioBufferTelemetry getTelemetry() {
    final fillPct = (_count / capacity) * 100.0;
    // Decibel level relative to full scale: 20 * log10(RMS)
    final dbLevel = _lastRms > 1e-5
        ? (20.0 * (math.log(_lastRms) / math.ln10)).clamp(-100.0, 0.0)
        : -100.0;

    return AudioBufferTelemetry(
      totalSamplesIngested: _totalIngested,
      currentBufferLength: _count,
      bufferCapacity: capacity,
      bufferFillPercentage: fillPct,
      isReady: isReady,
      currentRmsVolume: _lastRms,
      currentDbLevel: dbLevel,
    );
  }

  /// Returns detailed temporal window coverage metadata for synchronization analysis.
  AudioWindowMetadata getWindowMetadata({
    Duration maxStaleDuration = const Duration(milliseconds: 2000),
    DateTime? nowUtc,
  }) {
    if (_chunkCount == 0) {
      return AudioWindowMetadata.empty();
    }

    final now = nowUtc ?? DateTime.now().toUtc();
    final ageMs = now.difference(_lastChunkUtc).inMilliseconds.abs();
    final isStale = ageMs > maxStaleDuration.inMilliseconds;

    // Standard 4.0-second temporal coverage for 64,000 samples @ 16 kHz
    const durationMs = 4000;
    final windowEndUtc = _lastChunkUtc;
    final windowStartUtc = _lastChunkUtc.subtract(const Duration(milliseconds: durationMs));
    final windowEndMonoUs = _lastChunkMonotonicUs;
    final windowStartMonoUs = _lastChunkMonotonicUs > 4000000
        ? _lastChunkMonotonicUs - 4000000
        : 0;

    double totalInterval = 0.0;
    for (final interval in _recentChunkIntervalsMs) {
      totalInterval += interval;
    }
    final meanInterval = _recentChunkIntervalsMs.isNotEmpty
        ? totalInterval / _recentChunkIntervalsMs.length
        : 0.0;

    final dbLevel = _lastRms > 1e-5
        ? (20.0 * (math.log(_lastRms) / math.ln10)).clamp(-100.0, 0.0)
        : -100.0;

    return AudioWindowMetadata(
      windowStartUtc: windowStartUtc,
      windowEndUtc: windowEndUtc,
      windowStartMonotonicUs: windowStartMonoUs,
      windowEndMonotonicUs: windowEndMonoUs,
      sampleCount: _count,
      durationMs: durationMs,
      chunkCount: _chunkCount,
      meanChunkIntervalMs: meanInterval,
      isStale: isStale,
      ageMs: ageMs,
      rmsVolume: _lastRms,
      dbLevel: dbLevel,
    );
  }

  /// Wipes all samples and resets the ring buffer to empty.
  void clear() {
    _buffer.fillRange(0, capacity, 0.0);
    _head = 0;
    _count = 0;
    _lastRms = 0.0;
    _chunkCount = 0;
    _lastChunkMonotonicUs = 0;
    _previousChunkUtc = null;
    _recentChunkIntervalsMs.clear();
  }
}
