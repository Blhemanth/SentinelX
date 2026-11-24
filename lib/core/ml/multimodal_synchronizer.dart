// SentinelX - Multimodal Audio-Visual Synchronizer
// Evaluates timestamp alignment, temporal coverage, and stream health between
// the 16-frame video buffer and 4-second audio buffer before ONNX Runtime ingestion.
//
// SYNCHRONIZATION POLICIES & THRESHOLDS:
// 1. Reference Anchor: Newest moment of perception (t_video_end vs t_audio_end).
// 2. Maximum Allowable Skew: <= 1000 ms. (Target <= 500 ms).
//    Offsets > 1000 ms represent desynchronized streams; fusion is rejected and degraded to silence.
// 3. Stale Threshold: <= 2000 ms from current time. Frozen streams are flagged stale.
// 4. Modality States: synchronized, desynchronized, videoOnlyDegraded, audioOnlyDegraded, uninitializedOrStale.
// 5. Monotonic & UTC Dual Tracking: Immune to NTP adjustments, records exact offset and jitter.

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sentinel_x/core/camera/temporal_frame_buffer.dart';
import 'package:sentinel_x/core/audio/temporal_audio_buffer.dart';

enum MultimodalSyncState {
  /// Both streams healthy, fresh (<= 2000ms), and temporally aligned (offset <= 1000ms).
  synchronized,

  /// Both streams active, but temporal skew exceeds threshold (> 1000ms).
  desynchronized,

  /// Video is fresh, but audio is missing, uninitialized, buffering, or stale.
  videoOnlyDegraded,

  /// Audio is fresh, but video is missing, uninitialized, or stale.
  audioOnlyDegraded,

  /// Neither sensor stream is fresh or available.
  uninitializedOrStale,
}

@immutable
class MultimodalSyncTelemetry {
  final MultimodalSyncState syncState;
  final VideoWindowMetadata videoWindow;
  final AudioWindowMetadata? audioWindow;
  final int audioVideoOffsetMs; // signed: videoEnd - audioEnd
  final int absoluteOffsetMs; // |videoEnd - audioEnd|
  final int syncDelayMs;
  final int totalEvaluations;
  final int synchronizedCount;
  final int desynchronizedCount;
  final int rejectionCount;
  final double meanOffsetMs;
  final int maxOffsetMs;
  final double offsetJitterMs;
  final DateTime lastSyncEvaluationUtc;

  const MultimodalSyncTelemetry({
    required this.syncState,
    required this.videoWindow,
    this.audioWindow,
    required this.audioVideoOffsetMs,
    required this.absoluteOffsetMs,
    required this.syncDelayMs,
    required this.totalEvaluations,
    required this.synchronizedCount,
    required this.desynchronizedCount,
    required this.rejectionCount,
    required this.meanOffsetMs,
    required this.maxOffsetMs,
    required this.offsetJitterMs,
    required this.lastSyncEvaluationUtc,
  });

  factory MultimodalSyncTelemetry.initial() {
    final now = DateTime.now().toUtc();
    return MultimodalSyncTelemetry(
      syncState: MultimodalSyncState.uninitializedOrStale,
      videoWindow: VideoWindowMetadata.empty(),
      audioWindow: AudioWindowMetadata.empty(),
      audioVideoOffsetMs: 0,
      absoluteOffsetMs: 0,
      syncDelayMs: 0,
      totalEvaluations: 0,
      synchronizedCount: 0,
      desynchronizedCount: 0,
      rejectionCount: 0,
      meanOffsetMs: 0.0,
      maxOffsetMs: 0,
      offsetJitterMs: 0.0,
      lastSyncEvaluationUtc: now,
    );
  }

  @override
  String toString() =>
      'SyncTelemetry(state: ${syncState.name}, offset: ${audioVideoOffsetMs}ms, jitter: ${offsetJitterMs.toStringAsFixed(1)}ms, rejections: $rejectionCount)';
}

@immutable
class SyncEvaluation {
  final MultimodalSyncState syncState;
  final bool isMultimodal;
  final int audioVideoOffsetMs;
  final int absoluteOffsetMs;
  final int syncDelayMs;
  final VideoWindowMetadata videoWindow;
  final AudioWindowMetadata? audioWindow;
  final String diagnosticNotice;
  final MultimodalSyncTelemetry telemetry;

  const SyncEvaluation({
    required this.syncState,
    required this.isMultimodal,
    required this.audioVideoOffsetMs,
    required this.absoluteOffsetMs,
    required this.syncDelayMs,
    required this.videoWindow,
    this.audioWindow,
    required this.diagnosticNotice,
    required this.telemetry,
  });
}

class MultimodalSynchronizer {
  /// Maximum allowable temporal skew between video and audio end timestamps (ms).
  /// Exceeding this threshold marks the streams as desynchronized and triggers fallback.
  final int maxAllowableSkewMs;

  /// Target ideal temporal skew threshold (ms).
  final int targetSkewMs;

  /// Maximum duration after which a stream is declared stale / frozen (ms).
  final int maxStaleDurationMs;

  /// Minimum valid (non-padded) frames in the 16-frame buffer to consider video warm.
  final int minValidVideoFrames;

  int _totalEvaluations = 0;
  int _synchronizedCount = 0;
  int _desynchronizedCount = 0;
  int _rejectionCount = 0;

  // Rolling history of recent absolute offsets (last 50 evaluations)
  final List<int> _recentOffsetsMs = <int>[];

  MultimodalSyncTelemetry _latestTelemetry = MultimodalSyncTelemetry.initial();
  MultimodalSyncTelemetry get latestTelemetry => _latestTelemetry;

  MultimodalSynchronizer({
    this.maxAllowableSkewMs = 1000,
    this.targetSkewMs = 500,
    this.maxStaleDurationMs = 2000,
    this.minValidVideoFrames = 8,
  });

  /// Evaluates synchronization between current video and audio buffers.
  SyncEvaluation evaluate({
    required TemporalFrameBuffer videoBuffer,
    required TemporalAudioBuffer? audioBuffer,
    required bool isAudioServiceReady,
    DateTime? nowUtc,
    int? nowMonotonicUs,
  }) {
    final evalSw = Stopwatch()..start();
    _totalEvaluations++;

    final now = nowUtc ?? DateTime.now().toUtc();
    final staleDuration = Duration(milliseconds: maxStaleDurationMs);

    final videoMeta = videoBuffer.getWindowMetadata(
      maxStaleDuration: staleDuration,
      nowUtc: now,
    );

    final audioMeta = audioBuffer?.getWindowMetadata(
      maxStaleDuration: staleDuration,
      nowUtc: now,
    );

    // Determine individual stream validity
    final isVideoValid = videoBuffer.currentCount >= minValidVideoFrames &&
        !videoMeta.isStale &&
        videoMeta.frameCount >= 16;

    final isAudioValid = audioBuffer != null &&
        isAudioServiceReady &&
        audioBuffer.isReady &&
        audioMeta != null &&
        !audioMeta.isStale;

    MultimodalSyncState state;
    int offsetMs = 0;
    int absOffsetMs = 0;
    String notice;

    if (!isVideoValid && !isAudioValid) {
      state = MultimodalSyncState.uninitializedOrStale;
      notice = 'SENSORS OFFLINE OR STALE: Video Age=${videoMeta.ageMs}ms, Audio Age=${audioMeta?.ageMs ?? -1}ms';
    } else if (isVideoValid && !isAudioValid) {
      state = MultimodalSyncState.videoOnlyDegraded;
      notice = audioBuffer == null
          ? 'VIDEO-ONLY DEGRADED: Microphone unattached — SILENCE BASELINE (-80.0 dB)'
          : (!audioBuffer.isReady)
              ? 'VIDEO-ONLY DEGRADED: Audio buffer warming up (${audioBuffer.currentCount}/64000) — SILENCE BASELINE (-80.0 dB)'
              : (audioMeta?.isStale ?? true)
                  ? 'VIDEO-ONLY DEGRADED: Microphone stream stalled (${audioMeta?.ageMs ?? -1}ms > ${maxStaleDurationMs}ms) — SILENCE BASELINE (-80.0 dB)'
                  : 'VIDEO-ONLY DEGRADED: Audio service offline — SILENCE BASELINE (-80.0 dB)';
    } else if (!isVideoValid && isAudioValid) {
      state = MultimodalSyncState.audioOnlyDegraded;
      notice = videoMeta.isStale
          ? 'AUDIO-ONLY DEGRADED: Camera stream stalled (${videoMeta.ageMs}ms > ${maxStaleDurationMs}ms)'
          : 'AUDIO-ONLY DEGRADED: Video buffer warming up (${videoBuffer.currentCount}/16 frames)';
    } else {
      // Both streams valid: perform temporal alignment calculation
      final vEndUtc = videoMeta.windowEndUtc;
      final aEndUtc = audioMeta!.windowEndUtc;

      // Monotonic difference preferred if available, fallback to UTC difference
      if (videoMeta.windowEndMonotonicUs > 0 && audioMeta.windowEndMonotonicUs > 0) {
        final diffUs = videoMeta.windowEndMonotonicUs - audioMeta.windowEndMonotonicUs;
        offsetMs = diffUs ~/ 1000;
      } else {
        offsetMs = vEndUtc.difference(aEndUtc).inMilliseconds;
      }
      absOffsetMs = offsetMs.abs();

      _recordOffset(absOffsetMs);

      if (absOffsetMs <= maxAllowableSkewMs) {
        state = MultimodalSyncState.synchronized;
        _synchronizedCount++;
        notice = 'MULTIMODAL SYNCHRONIZED: Offset = ${offsetMs}ms (<= ${maxAllowableSkewMs}ms limit), Jitter = ${_calculateJitter().toStringAsFixed(1)}ms';
      } else {
        state = MultimodalSyncState.desynchronized;
        _desynchronizedCount++;
        _rejectionCount++;
        notice = 'MULTIMODAL DESYNCHRONIZED: Offset = ${offsetMs}ms > ${maxAllowableSkewMs}ms limit — FUSION REJECTED (SILENCE FALLBACK)';
      }
    }

    evalSw.stop();
    final delayMs = evalSw.elapsedMilliseconds;

    _latestTelemetry = MultimodalSyncTelemetry(
      syncState: state,
      videoWindow: videoMeta,
      audioWindow: audioMeta,
      audioVideoOffsetMs: offsetMs,
      absoluteOffsetMs: absOffsetMs,
      syncDelayMs: delayMs,
      totalEvaluations: _totalEvaluations,
      synchronizedCount: _synchronizedCount,
      desynchronizedCount: _desynchronizedCount,
      rejectionCount: _rejectionCount,
      meanOffsetMs: _calculateMeanOffset(),
      maxOffsetMs: _calculateMaxOffset(),
      offsetJitterMs: _calculateJitter(),
      lastSyncEvaluationUtc: now,
    );

    return SyncEvaluation(
      syncState: state,
      isMultimodal: state == MultimodalSyncState.synchronized,
      audioVideoOffsetMs: offsetMs,
      absoluteOffsetMs: absOffsetMs,
      syncDelayMs: delayMs,
      videoWindow: videoMeta,
      audioWindow: audioMeta,
      diagnosticNotice: notice,
      telemetry: _latestTelemetry,
    );
  }

  void _recordOffset(int absOffset) {
    _recentOffsetsMs.add(absOffset);
    if (_recentOffsetsMs.length > 50) {
      _recentOffsetsMs.removeAt(0);
    }
  }

  double _calculateMeanOffset() {
    if (_recentOffsetsMs.isEmpty) return 0.0;
    final sum = _recentOffsetsMs.reduce((a, b) => a + b);
    return sum / _recentOffsetsMs.length;
  }

  int _calculateMaxOffset() {
    if (_recentOffsetsMs.isEmpty) return 0;
    return _recentOffsetsMs.reduce(math.max);
  }

  double _calculateJitter() {
    if (_recentOffsetsMs.length < 2) return 0.0;
    final mean = _calculateMeanOffset();
    double sumSqDiff = 0.0;
    for (final val in _recentOffsetsMs) {
      final diff = val - mean;
      sumSqDiff += diff * diff;
    }
    return math.sqrt(sumSqDiff / _recentOffsetsMs.length);
  }

  /// Resets synchronization counters and offset histories.
  void reset() {
    _totalEvaluations = 0;
    _synchronizedCount = 0;
    _desynchronizedCount = 0;
    _rejectionCount = 0;
    _recentOffsetsMs.clear();
    _latestTelemetry = MultimodalSyncTelemetry.initial();
  }
}
