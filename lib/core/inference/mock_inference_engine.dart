// SentinelX - Mock Inference Engine
// Synthetic ML inference pipeline that generates realistic detection data.
// Will be swapped with real ONNX runtime when fine-tuned models are ready.

import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';
import 'package:sentinel_x/core/models/models.dart';

class MockInferenceEngine {
  final _random = Random();
  final _uuid = const Uuid();
  Timer? _inferenceTimer;
  Timer? _audioTimer;
  Timer? _metricsTimer;

  final StreamController<List<Detection>> _detectionController =
      StreamController<List<Detection>>.broadcast();
  final StreamController<AudioEvent> _audioController =
      StreamController<AudioEvent>.broadcast();
  final StreamController<SystemMetrics> _metricsController =
      StreamController<SystemMetrics>.broadcast();
  final StreamController<SecurityAlert> _alertController =
      StreamController<SecurityAlert>.broadcast();

  Stream<List<Detection>> get detectionStream => _detectionController.stream;
  Stream<AudioEvent> get audioStream => _audioController.stream;
  Stream<SystemMetrics> get metricsStream => _metricsController.stream;
  Stream<SecurityAlert> get alertStream => _alertController.stream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // Simulated state
  double _currentThreatLevel = 0.0;
  int _totalDetectionCount = 0;
  int _activeAlertCount = 0;
  final List<String> _cameraIds = [];

  void initialize({int cameraCount = 1}) {
    _cameraIds.clear();
    for (int i = 0; i < cameraCount; i++) {
      _cameraIds.add('CAM-${(i + 1).toString().padLeft(3, '0')}');
    }
  }

  List<CameraFeed> generateCameraFeeds() {
    return [
      const CameraFeed(
        id: 'CAM-001',
        name: 'Laptop Camera 1',
        location: 'Integrated Laptop Webcam (Hardware)',
        status: CameraStatus.online,
        latitude: 28.6139,
        longitude: 77.2090,
        fps: 30,
        resolution: '1920x1080',
      ),
    ];
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Detection inference at ~3 FPS (simulated)
    _inferenceTimer = Timer.periodic(
      const Duration(milliseconds: 350),
      (_) => _generateDetections(),
    );

    // Audio events every 1-4 seconds
    _audioTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) => _generateAudioEvent(),
    );

    // System metrics every second
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _generateMetrics(),
    );
  }

  void stop() {
    _isRunning = false;
    _inferenceTimer?.cancel();
    _audioTimer?.cancel();
    _metricsTimer?.cancel();
  }

  void dispose() {
    stop();
    _detectionController.close();
    _audioController.close();
    _metricsController.close();
    _alertController.close();
  }

  void _generateDetections() {
    if (_detectionController.isClosed) return;

    final cameraId = _cameraIds.isNotEmpty ? _cameraIds.first : 'CAM-001';
    final confidence = 0.93 + _random.nextDouble() * 0.05;

    // Normal baseline detection: person visible in webcam viewport
    final detection = Detection(
      id: _uuid.v4(),
      cameraId: cameraId,
      type: DetectionType.person,
      bbox: const BoundingBox(
        x: 0.25,
        y: 0.15,
        width: 0.50,
        height: 0.70,
      ),
      confidence: confidence,
      threat: ThreatLevel.none,
      timestamp: DateTime.now(),
      label: 'Person (${(confidence * 100).toStringAsFixed(1)}%) - SECURE',
    );

    _totalDetectionCount++;
    _currentThreatLevel = 0.02; // Safe baseline threat level

    _detectionController.add([detection]);
  }

  void _generateAudioEvent() {
    if (_audioController.isClosed) return;

    final cameraId = _cameraIds.isNotEmpty ? _cameraIds.first : 'CAM-001';

    // Ambient room audio waveform
    final bands = List.generate(32, (i) {
      final baseFreq = sin(i * 0.25 + DateTime.now().millisecond * 0.005);
      return (baseFreq.abs() * 0.35 + 0.05).clamp(0.0, 1.0);
    });

    _audioController.add(AudioEvent(
      id: _uuid.v4(),
      cameraId: cameraId,
      classification: 'ambient',
      confidence: 0.94 + _random.nextDouble() * 0.04,
      threat: ThreatLevel.none,
      timestamp: DateTime.now(),
      frequencyBands: bands,
      decibelLevel: 42 + _random.nextDouble() * 8,
    ));
  }

  void _generateMetrics() {
    if (_metricsController.isClosed) return;

    final onlineCameras =
        _cameraIds.length - _random.nextInt(3);

    _metricsController.add(SystemMetrics(
      cpuUsage: 25 + _random.nextDouble() * 45,
      gpuUsage: 40 + _random.nextDouble() * 50,
      memoryUsage: 35 + _random.nextDouble() * 30,
      networkBandwidth: 120 + _random.nextDouble() * 380,
      activeCameras: onlineCameras,
      totalDetections: _totalDetectionCount,
      activeAlerts: _activeAlertCount,
      inferenceLatencyMs: 8 + _random.nextDouble() * 22,
      framesProcessedPerSec: 85 + _random.nextInt(35),
    ));
  }

  void triggerAlert(Detection detection, [String? cameraId]) {
    if (_alertController.isClosed) return;

    _activeAlertCount++;
    final targetCameraId = cameraId ?? (_cameraIds.isNotEmpty ? _cameraIds.first : 'CAM-001');
    const cameraName = 'CAM-001 (Laptop Webcam)';

    _alertController.add(SecurityAlert(
      id: _uuid.v4(),
      cameraId: targetCameraId,
      cameraName: cameraName,
      detectionType: detection.type,
      threatLevel: detection.threat,
      priority: detection.threat == ThreatLevel.critical
          ? AlertPriority.critical
          : AlertPriority.urgent,
      title:
          '${detection.threat.label} - ${detection.type.label} Detected',
      description:
          '${detection.type.label} detected on laptop camera '
          'with ${(detection.confidence * 100).toStringAsFixed(1)}% confidence.',
      timestamp: DateTime.now(),
    ));
  }

  // Snapshot methods for initial state
  SystemMetrics get currentMetrics => SystemMetrics(
    cpuUsage: 32 + _random.nextDouble() * 20,
    gpuUsage: 45 + _random.nextDouble() * 25,
    memoryUsage: 40 + _random.nextDouble() * 15,
    networkBandwidth: 200 + _random.nextDouble() * 100,
    activeCameras: _cameraIds.length,
    totalDetections: _totalDetectionCount,
    activeAlerts: _activeAlertCount,
    inferenceLatencyMs: 12.0,
    framesProcessedPerSec: 95,
  );

  double get currentThreatLevel => _currentThreatLevel;
}
