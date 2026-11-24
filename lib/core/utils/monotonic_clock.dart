// SentinelX - Monotonic Clock & Timestamp Provider
// Provides high-resolution monotonic time (QueryPerformanceCounter on Windows)
// to ensure accurate jitter and synchronization measurement immune to NTP clock adjustments.

import 'package:flutter/foundation.dart';

@immutable
class MonotonicTimestamp {
  final DateTime utc;
  final int monotonicUs;

  const MonotonicTimestamp({
    required this.utc,
    required this.monotonicUs,
  });

  int get monotonicMs => monotonicUs ~/ 1000;

  @override
  String toString() =>
      'MonotonicTimestamp(utc: ${utc.toIso8601String()}, monotonicUs: $monotonicUs)';
}

class MonotonicClock {
  static final Stopwatch _stopwatch = Stopwatch()..start();

  /// Elapsed monotonic microseconds since process start
  static int get nowMicros => _stopwatch.elapsedMicroseconds;

  /// Elapsed monotonic milliseconds since process start
  static int get nowMillis => _stopwatch.elapsedMilliseconds;

  /// Captures both current UTC DateTime and monotonic microsecond counter atomically
  static MonotonicTimestamp now() {
    final nowUs = _stopwatch.elapsedMicroseconds;
    final nowUtc = DateTime.now().toUtc();
    return MonotonicTimestamp(utc: nowUtc, monotonicUs: nowUs);
  }
}
