// SentinelX - Detection Sync & Incident Throttling Service
// Connects continuous ONNX inference predictions to the Node.js / Express backend.
//
// SAFETY & THROTTLING MANDATES:
// 1. Normal Suppression: 'Normal' predictions are NEVER synced as crime logs.
// 2. Cooldown Throttling: Anomaly incidents from the same camera/class within cooldown (5s)
//    are throttled to prevent spamming the database with 40+ records/minute.
// 3. Minimum Confidence Threshold: Only incidents with confidence >= 0.50 are eligible for creation.
// 4. Viewport Bounding Box: Syncs canvas-clipped coordinates [x, y, w, h].

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentinel_x/core/services/crime_log_service.dart';
import 'package:sentinel_x/core/ml/continuous_inference_scheduler.dart';

@immutable
class SyncTelemetry {
  final int totalReceived;
  final int suppressedNormal;
  final int syncedIncidents;
  final int throttledIncidents;
  final int failedSyncs;
  final DateTime? lastSyncTime;
  final String? lastSyncedClass;
  final double? lastSyncedConfidence;
  final String? lastError;

  const SyncTelemetry({
    required this.totalReceived,
    required this.suppressedNormal,
    required this.syncedIncidents,
    required this.throttledIncidents,
    required this.failedSyncs,
    this.lastSyncTime,
    this.lastSyncedClass,
    this.lastSyncedConfidence,
    this.lastError,
  });

  factory SyncTelemetry.initial() => const SyncTelemetry(
        totalReceived: 0,
        suppressedNormal: 0,
        syncedIncidents: 0,
        throttledIncidents: 0,
        failedSyncs: 0,
      );
}

class DetectionSyncService {
  final CrimeLogService crimeLogService;
  final Duration cooldownDuration;
  final double minConfidenceThreshold;

  // Track last synced timestamp by (cameraId:threatClass)
  final Map<String, DateTime> _lastSyncedTimestamps = <String, DateTime>{};

  StreamSubscription<ContinuousInferencePrediction>? _predictionSubscription;

  int _totalReceived = 0;
  int _suppressedNormal = 0;
  int _syncedIncidents = 0;
  int _throttledIncidents = 0;
  int _failedSyncs = 0;
  DateTime? _lastSyncTime;
  String? _lastSyncedClass;
  double? _lastSyncedConfidence;
  String? _lastError;

  final StreamController<SyncTelemetry> _telemetryController =
      StreamController<SyncTelemetry>.broadcast();
  Stream<SyncTelemetry> get telemetryStream => _telemetryController.stream;

  SyncTelemetry _currentTelemetry = SyncTelemetry.initial();
  SyncTelemetry get currentTelemetry => _currentTelemetry;

  DetectionSyncService({
    required this.crimeLogService,
    this.cooldownDuration = const Duration(seconds: 5),
    this.minConfidenceThreshold = 0.50,
  });

  /// Starts listening to the continuous inference scheduler prediction stream.
  void bindToScheduler(ContinuousInferenceScheduler scheduler) {
    _predictionSubscription?.cancel();
    _predictionSubscription = scheduler.predictionStream.listen(
      _handlePrediction,
      onError: (err) {
        _lastError = 'Prediction stream error: $err';
        _emitTelemetry();
      },
    );
  }

  /// Processes an individual prediction from the ONNX scheduler.
  @visibleForTesting
  Future<void> handlePrediction(ContinuousInferencePrediction prediction) =>
      _handlePrediction(prediction);

  Future<void> _handlePrediction(ContinuousInferencePrediction prediction) async {
    _totalReceived++;

    // 1. Rule 1: Normal predictions never create database logs
    if (prediction.isNormal) {
      _suppressedNormal++;
      _emitTelemetry();
      return;
    }

    // 2. Rule 2: Minimum confidence check
    if (prediction.confidence < minConfidenceThreshold) {
      _throttledIncidents++;
      _emitTelemetry();
      return;
    }

    // 3. Rule 3: Sliding window cooldown per camera + class
    final throttleKey = '${prediction.cameraId}:${prediction.predictedClass}';
    final now = DateTime.now();
    final lastSync = _lastSyncedTimestamps[throttleKey];

    if (lastSync != null && now.difference(lastSync) < cooldownDuration) {
      _throttledIncidents++;
      _emitTelemetry();
      return;
    }

    // 4. Construct authoritative CrimeLog payload
    final classProbs = <String, double>{};
    for (int i = 0; i < prediction.threatProbabilities.length; i++) {
      if (i < ContinuousInferencePrediction.classTaxonomy.length) {
        classProbs[ContinuousInferencePrediction.classTaxonomy[i]] =
            prediction.threatProbabilities[i];
      }
    }

    final payload = <String, dynamic>{
      'cameraId': prediction.cameraId,
      'threatClass': prediction.predictedClass,
      'confidence': prediction.confidence,
      'boundingBox': {
        'x': prediction.clippedBoundingBox[0],
        'y': prediction.clippedBoundingBox[1],
        'w': prediction.clippedBoundingBox[2],
        'h': prediction.clippedBoundingBox[3],
      },
      'classProbabilities': classProbs,
      'frameTimestamp': prediction.timestamp.toIso8601String(),
      'detectionSource': 'ml_real',
      'detectionStatus': prediction.confidence >= 0.85
          ? 'anomaly_detected'
          : (prediction.confidence >= 0.50 ? 'anomaly_detected' : 'low_confidence_review'),
      'location': 'Command Center - Hardware Webcam',
      'metrics': {
        'modelInferenceMs': prediction.latencyMs,
        'totalLatencyMs': prediction.latencyMs,
      },
      'audioTranscript': 'VIDEO ONLY — CALIBRATED SILENCE BASELINE (-80.0 dB)',
    };

    try {
      final result = await crimeLogService.createCrimeLog(payload);
      if (result != null) {
        _lastSyncedTimestamps[throttleKey] = now;
        _syncedIncidents++;
        _lastSyncTime = now;
        _lastSyncedClass = prediction.predictedClass;
        _lastSyncedConfidence = prediction.confidence;
        _lastError = null;
      } else {
        _failedSyncs++;
        _lastError = 'CrimeLog API returned null response.';
      }
    } catch (e) {
      _failedSyncs++;
      _lastError = 'API sync exception: $e';
      debugPrint('[DetectionSyncService] Sync failure: $e');
    }

    _emitTelemetry();
  }

  void _emitTelemetry() {
    _currentTelemetry = SyncTelemetry(
      totalReceived: _totalReceived,
      suppressedNormal: _suppressedNormal,
      syncedIncidents: _syncedIncidents,
      throttledIncidents: _throttledIncidents,
      failedSyncs: _failedSyncs,
      lastSyncTime: _lastSyncTime,
      lastSyncedClass: _lastSyncedClass,
      lastSyncedConfidence: _lastSyncedConfidence,
      lastError: _lastError,
    );

    if (!_telemetryController.isClosed) {
      _telemetryController.add(_currentTelemetry);
    }
  }

  /// Clears throttle cooldown state (useful for tests)
  void resetThrottles() {
    _lastSyncedTimestamps.clear();
  }

  Future<void> dispose() async {
    await _predictionSubscription?.cancel();
    _predictionSubscription = null;
    await _telemetryController.close();
  }
}
