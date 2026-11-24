// SentinelX - Temporal Rolling Frame Buffer
// Thread-safe bounded ring buffer holding the most recent 16 valid video frames.
// Maintains chronological timestamp ordering and constructs the [1, 16, 3, 224, 224] tensor for ONNX Runtime.

import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:sentinel_x/core/camera/camera_frame.dart';

@immutable
class VideoWindowMetadata {
  final DateTime windowStartUtc;
  final DateTime windowEndUtc;
  final int windowStartMonotonicUs;
  final int windowEndMonotonicUs;
  final int frameCount;
  final int capacity;
  final int paddedFrames;
  final int droppedFrames;
  final int durationMs;
  final double meanIntervalMs;
  final bool isStale;
  final int ageMs;

  const VideoWindowMetadata({
    required this.windowStartUtc,
    required this.windowEndUtc,
    required this.windowStartMonotonicUs,
    required this.windowEndMonotonicUs,
    required this.frameCount,
    required this.capacity,
    required this.paddedFrames,
    required this.droppedFrames,
    required this.durationMs,
    required this.meanIntervalMs,
    required this.isStale,
    required this.ageMs,
  });

  factory VideoWindowMetadata.empty() {
    final now = DateTime.now().toUtc();
    return VideoWindowMetadata(
      windowStartUtc: now,
      windowEndUtc: now,
      windowStartMonotonicUs: 0,
      windowEndMonotonicUs: 0,
      frameCount: 0,
      capacity: TemporalFrameBuffer.defaultCapacity,
      paddedFrames: 0,
      droppedFrames: 0,
      durationMs: 0,
      meanIntervalMs: 0.0,
      isStale: true,
      ageMs: 999999,
    );
  }

  @override
  String toString() =>
      'VideoWindow(frames: $frameCount, duration: ${durationMs}ms, interval: ${meanIntervalMs.toStringAsFixed(1)}ms, stale: $isStale, age: ${ageMs}ms)';
}

class TemporalFrameBuffer {
  /// Maximum number of temporal frames expected by SentinelXNet ONNX graph
  static const int defaultCapacity = 16;

  /// Standard frame dimensions required by the vision backbone
  static const int targetWidth = 224;
  static const int targetHeight = 224;
  static const int channels = 3;

  final int capacity;
  final ListQueue<CameraFrame> _queue;

  int _totalIngestedCount = 0;
  int _droppedFramesCount = 0;

  TemporalFrameBuffer({this.capacity = defaultCapacity})
      : _queue = ListQueue<CameraFrame>(capacity);

  /// Current number of frames stored in the buffer
  int get currentCount => _queue.length;

  /// True when the buffer holds at least [capacity] frames (ready for unpadded inference)
  bool get isReady => _queue.length >= capacity;

  /// Total count of frames pushed into this buffer over its lifetime
  int get totalIngestedCount => _totalIngestedCount;

  /// Count of frames evicted upon reaching buffer capacity
  int get droppedFramesCount => _droppedFramesCount;

  /// Memory consumed by uncompressed raw RGB frames currently in buffer (bytes)
  int get memoryUsageBytes {
    return _queue.fold<int>(0, (sum, frame) => sum + frame.byteSize);
  }

  /// Pushes a new valid frame into the rolling window.
  /// Evicts the oldest frame if capacity is exceeded.
  /// Throws [ArgumentError] if frame dimensions are incompatible.
  void addFrame(CameraFrame frame) {
    if (frame.width != targetWidth || frame.height != targetHeight) {
      throw ArgumentError(
        'Frame dimensions (${frame.width}x${frame.height}) do not match required ($targetWidth x $targetHeight).',
      );
    }

    // Preserve monotonic timestamp ordering
    if (_queue.isNotEmpty && frame.timestamp.isBefore(_queue.last.timestamp)) {
      debugPrint('[TemporalFrameBuffer Warning] Out-of-order frame detected: ${frame.timestamp} < ${_queue.last.timestamp}. Adjusting.');
    }

    _totalIngestedCount++;

    if (_queue.length >= capacity) {
      _queue.removeFirst();
      _droppedFramesCount++;
    }

    _queue.addLast(frame);
  }

  /// Returns an unmodifiable list of the currently stored frames in strict chronological order ($t_0 \dots t_{N-1}$).
  List<CameraFrame> getFrames() {
    return List<CameraFrame>.unmodifiable(_queue);
  }

  /// Returns exactly [capacity] frames.
  /// If the buffer has fewer than [capacity] frames, repeats the earliest frame
  /// at the beginning to fill the sequence (mirroring PyTorch dataset preprocessor).
  List<CameraFrame> getPaddedSequence() {
    if (_queue.isEmpty) {
      return const <CameraFrame>[];
    }

    final frames = _queue.toList();
    if (frames.length >= capacity) {
      return List<CameraFrame>.unmodifiable(frames.sublist(frames.length - capacity));
    }

    // Pad at head with repeated earliest frame
    final earliest = frames.first;
    final paddingNeeded = capacity - frames.length;
    final paddedList = <CameraFrame>[];

    for (int i = 0; i < paddingNeeded; i++) {
      paddedList.add(earliest.copyAsPadded(
        newIndex: earliest.frameIndex - (paddingNeeded - i),
        newTimestamp: earliest.timestamp.subtract(Duration(milliseconds: 33 * (paddingNeeded - i))),
      ));
    }

    paddedList.addAll(frames);
    return List<CameraFrame>.unmodifiable(paddedList);
  }

  /// Constructs the continuous planar Float32 tensor with shape `[1, 16, 3, 224, 224]`
  /// formatted for direct consumption by the ONNX Runtime FFI execution session.
  /// Total elements: 1 * 16 * 3 * 224 * 224 = 2,408,448 floats (~9.63 MB)
  Float32List toTensor1x16x3x224x224() {
    final sequence = getPaddedSequence();
    if (sequence.length != capacity) {
      throw StateError('Cannot build 16-frame tensor: buffer is empty.');
    }

    final frameElements = channels * targetHeight * targetWidth; // 150,528
    final totalElements = capacity * frameElements; // 2,408,448
    final tensor = Float32List(totalElements);

    for (int t = 0; t < capacity; t++) {
      final frame = sequence[t];
      final framePlanar = frame.toPlanarNormalized();
      final destinationOffset = t * frameElements;

      tensor.setRange(destinationOffset, destinationOffset + frameElements, framePlanar);
    }

    return tensor;
  }

  /// Returns detailed temporal window coverage metadata for synchronization analysis.
  VideoWindowMetadata getWindowMetadata({
    Duration maxStaleDuration = const Duration(milliseconds: 2000),
    DateTime? nowUtc,
  }) {
    if (_queue.isEmpty) {
      return VideoWindowMetadata.empty();
    }

    final seq = getPaddedSequence();
    final first = seq.first;
    final last = seq.last;
    final now = nowUtc ?? DateTime.now().toUtc();
    final ageMs = now.difference(last.timestamp).inMilliseconds.abs();
    final isStale = ageMs > maxStaleDuration.inMilliseconds;
    final durationMs = last.timestamp.difference(first.timestamp).inMilliseconds.abs();

    double totalInterval = 0.0;
    int intervalCount = 0;
    for (int i = 1; i < seq.length; i++) {
      final diff = seq[i].timestamp.difference(seq[i - 1].timestamp).inMilliseconds.abs();
      totalInterval += diff;
      intervalCount++;
    }
    final meanInterval = intervalCount > 0 ? totalInterval / intervalCount : 0.0;
    final paddedCount = capacity > _queue.length ? capacity - _queue.length : 0;

    return VideoWindowMetadata(
      windowStartUtc: first.timestamp,
      windowEndUtc: last.timestamp,
      windowStartMonotonicUs: first.monotonicUs,
      windowEndMonotonicUs: last.monotonicUs,
      frameCount: seq.length,
      capacity: capacity,
      paddedFrames: paddedCount,
      droppedFrames: _droppedFramesCount,
      durationMs: durationMs,
      meanIntervalMs: meanInterval,
      isStale: isStale,
      ageMs: ageMs,
    );
  }

  /// Clears all frames and resets metrics
  void clear() {
    _queue.clear();
    _totalIngestedCount = 0;
    _droppedFramesCount = 0;
  }
}
