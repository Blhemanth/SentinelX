// SentinelX - Mock Inference Service
// Simulates local ONNX audio-visual anomaly detection pipeline.
// Emits real-time synthetic detection payloads, acoustic frequencies, and telemetry.

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────
// DOMAIN MODELS
// ─────────────────────────────────────────────────

/// Normalized detection payload from the local ONNX inference pipeline.
@immutable
class InferencePayload {
  final String threatType;
  final double confidence;
  final Rect boundingBox;
  final List<double> audioFrequencies;
  final DateTime timestamp;
  final String sourceCameraId;
  final double decibels;
  final String location;

  const InferencePayload({
    required this.threatType,
    required this.confidence,
    required this.boundingBox,
    required this.audioFrequencies,
    required this.timestamp,
    required this.sourceCameraId,
    required this.decibels,
    required this.location,
  });

  bool get isNormal => threatType == 'Normal';
  bool get isCritical => !isNormal && confidence >= 0.85;
  bool get isHigh => !isNormal && confidence >= 0.70 && confidence < 0.85;
  bool get isMedium => !isNormal && confidence < 0.70;

  Color get threatColor {
    if (isNormal) return const Color(0xFF00E676);
    if (isCritical) return const Color(0xFFFF3B5C);
    if (isHigh) return const Color(0xFFFF6B35);
    return const Color(0xFFFFBB33);
  }

  String get severityLabel {
    if (isNormal) return 'NORMAL';
    if (isCritical) return 'CRITICAL';
    if (isHigh) return 'HIGH';
    return 'MEDIUM';
  }
}

/// Real-time hardware telemetry data.
@immutable
class TelemetryData {
  final double fps;
  final int latencyMs;
  final double cpuUsage;
  final double vramUsageGb;
  final double totalVramGb;
  final bool isConnected;
  final String deviceType;
  final int activeCameras;

  const TelemetryData({
    required this.fps,
    required this.latencyMs,
    required this.cpuUsage,
    required this.vramUsageGb,
    this.totalVramGb = 8.0,
    this.isConnected = true,
    this.deviceType = 'DirectML / ONNX Runtime (FP16)',
    this.activeCameras = 1,
  });
}

// ─────────────────────────────────────────────────
// SERVICE IMPLEMENTATION
// ─────────────────────────────────────────────────

class MockInferenceService {
  final _random = Random();
  Timer? _inferenceTimer;
  Timer? _telemetryTimer;

  final StreamController<InferencePayload> _payloadController =
      StreamController<InferencePayload>.broadcast();
  final StreamController<TelemetryData> _telemetryController =
      StreamController<TelemetryData>.broadcast();

  Stream<InferencePayload> get payloadStream => _payloadController.stream;
  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  final List<InferencePayload> _recentAlerts = [];
  List<InferencePayload> get recentAlerts => List.unmodifiable(_recentAlerts);

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String? _manualThreatTrigger;

  /// Manually triggers a synthetic threat for testing or drill demonstration.
  void triggerTestThreat([String? threat]) {
    _manualThreatTrigger = threat ?? _threatPool.first;
  }

  /// Clears manual threat and returns camera to normal safe state.
  void clearTestThreat() {
    _manualThreatTrigger = null;
  }

  static const _cameras = [
    {'id': 'CAM-001', 'name': 'Laptop Camera 1 (Local Hardware Webcam)'},
    {'id': 'CAM-002', 'name': 'Phone Camera 2 (Wireless IP Stream)'},
  ];

  static const _threatPool = [
    'Acoustic Distress: HELP, HELP',
    'Weapon Detected',
    'Fighting',
    'Gunshot Audio',
    'Explosion',
    'Crowd Panic',
    'Vandalism',
    'Trespassing',
  ];

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Emit initial telemetry immediately
    _emitTelemetry();

    // Start high-frequency telemetry timer (every 500ms for smooth meters)
    _telemetryTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _emitTelemetry(),
    );

    // Start synthetic inference timer (1200ms interval for realistic pipeline throughput)
    _inferenceTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) => _emitInference(),
    );
  }

  void stop() {
    _isRunning = false;
    _inferenceTimer?.cancel();
    _telemetryTimer?.cancel();
    _inferenceTimer = null;
    _telemetryTimer = null;
  }

  void _emitTelemetry() {
    if (_payloadController.isClosed) return;

    // Simulated realistic telemetry jitter
    final fps = 58.0 + _random.nextDouble() * 2.0; // 58.0 - 60.0 FPS
    final latency = 12 + _random.nextInt(5); // 12 - 16 ms
    final cpu = 18.5 + _random.nextDouble() * 5.0; // 18.5% - 23.5%
    final vram = 1.48 + _random.nextDouble() * 0.20; // 1.48 - 1.68 GB

    _telemetryController.add(TelemetryData(
      fps: fps,
      latencyMs: latency,
      cpuUsage: cpu,
      vramUsageGb: vram,
    ));
  }

  void _emitInference() {
    if (_payloadController.isClosed) return;

    final camera = _cameras[_random.nextInt(_cameras.length)];
    final String threatType;
    final double confidence;
    final Rect boundingBox;
    final double decibels;
    final bool isAnomaly;

    if (_manualThreatTrigger != null) {
      isAnomaly = true;
      threatType = _manualThreatTrigger!;
      confidence = 0.88 + _random.nextDouble() * 0.09;

      // Centered anomaly detection box
      boundingBox = const Rect.fromLTWH(0.20, 0.20, 0.45, 0.55);
      if (threatType.contains('HELP') || threatType.contains('Distress')) {
        decibels = 88.5 + _random.nextDouble() * 5.0;
      } else {
        decibels = (threatType == 'Gunshot Audio' || threatType == 'Explosion') ? 92.0 : 74.0;
      }
    } else {
      // Normal baseline state: Clean surveillance monitoring without false alarms
      isAnomaly = false;
      threatType = 'Normal';
      confidence = 0.94 + _random.nextDouble() * 0.05;

      // Stable pedestrian / user bounding box over webcam viewport
      boundingBox = const Rect.fromLTWH(0.25, 0.15, 0.50, 0.70);
      decibels = 42.0 + _random.nextDouble() * 8.0; // Ambient room decibels (42-50 dB)
    }

    // Generate 20 spectral float values (0.0 to 1.0)
    final audioFrequencies = _generateSpectralFrequencies(threatType);

    final payload = InferencePayload(
      threatType: threatType,
      confidence: confidence,
      boundingBox: boundingBox,
      audioFrequencies: audioFrequencies,
      timestamp: DateTime.now(),
      sourceCameraId: camera['id']!,
      decibels: decibels,
      location: camera['name']!,
    );

    // Keep rolling log of anomalies
    if (isAnomaly) {
      _recentAlerts.insert(0, payload);
      if (_recentAlerts.length > 50) {
        _recentAlerts.removeLast();
      }
    }

    _payloadController.add(payload);
  }

  List<double> _generateSpectralFrequencies(String threat) {
    final frequencies = <double>[];
    for (int i = 0; i < 20; i++) {
      double base;
      if (threat.contains('HELP') || threat.contains('Distress')) {
        // High vocal energy across human speech formant frequencies (bands 3 to 14)
        base = (i >= 3 && i <= 14) ? (0.82 + _random.nextDouble() * 0.18) : (0.22 + _random.nextDouble() * 0.25);
      } else if (threat == 'Explosion') {
        // Broad spectrum high energy
        base = 0.65 + _random.nextDouble() * 0.35;
      } else if (threat == 'Gunshot Audio') {
        // High frequency acoustic snap
        base = i > 12 ? (0.75 + _random.nextDouble() * 0.25) : (0.25 + _random.nextDouble() * 0.40);
      } else if (threat == 'Fighting' || threat == 'Crowd Panic') {
        // Mid-range vocal agitation
        base = (i >= 5 && i <= 14) ? (0.60 + _random.nextDouble() * 0.35) : (0.20 + _random.nextDouble() * 0.30);
      } else {
        // Normal ambient pink noise pattern (slight roll-off at higher frequencies)
        final rollOff = 1.0 - (i / 25.0);
        base = (0.15 + _random.nextDouble() * 0.25) * rollOff;
      }
      frequencies.add(base.clamp(0.05, 1.0));
    }
    return frequencies;
  }

  void acknowledgeAlert(InferencePayload alert) {
    _recentAlerts.remove(alert);
  }

  void clearAlerts() {
    _recentAlerts.clear();
  }

  void dispose() {
    stop();
    _payloadController.close();
    _telemetryController.close();
  }
}

// ─────────────────────────────────────────────────
// RIVERPOD PROVIDERS
// ─────────────────────────────────────────────────

final mockInferenceServiceProvider = Provider<MockInferenceService>((ref) {
  final service = MockInferenceService();
  service.start();
  ref.onDispose(() => service.dispose());
  return service;
});

final inferencePayloadStreamProvider = StreamProvider<InferencePayload>((ref) {
  final service = ref.watch(mockInferenceServiceProvider);
  return service.payloadStream;
});

final telemetryStreamProvider = StreamProvider<TelemetryData>((ref) {
  final service = ref.watch(mockInferenceServiceProvider);
  return service.telemetryStream;
});

final recentInferenceAlertsProvider =
    StateNotifierProvider<RecentInferenceAlertsNotifier, List<InferencePayload>>(
        (ref) {
  final service = ref.watch(mockInferenceServiceProvider);
  return RecentInferenceAlertsNotifier(service);
});

class RecentInferenceAlertsNotifier extends StateNotifier<List<InferencePayload>> {
  final MockInferenceService _service;
  StreamSubscription<InferencePayload>? _sub;

  RecentInferenceAlertsNotifier(this._service) : super([]) {
    _sub = _service.payloadStream.listen((payload) {
      if (!payload.isNormal) {
        state = [payload, ...state.take(49)];
      }
    });
  }

  void removeAlert(InferencePayload payload) {
    state = state.where((item) => item != payload).toList();
  }

  void clearAll() {
    state = [];
    _service.clearAlerts();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
