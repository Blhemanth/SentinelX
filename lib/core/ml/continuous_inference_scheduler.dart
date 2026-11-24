// SentinelX - Continuous Real-Time ONNX Inference Scheduler
// Orchestrates continuous execution of assets/models/sentinelx_model.onnx
// against the 16-frame temporal buffer fed by CameraIngestionService.
//
// CONCURRENCY & INTEGRITY POLICY:
// 1. Dedicated Background Worker Isolate: Heavy native C-FFI forward passes execute off the UI thread.
// 2. Strict Non-Blocking Concurrency Guard: Drops/skips frame triggers while inference is in flight.
// 3. Multimodal Integrity: Executes in DEGRADED MODE (video_only_degraded) with calibrated -80.0 dB silence.
// 4. Viewport Canvas Boundary Clipping: Enforces x + w <= 1.0 and y + h <= 1.0 on Sigmoid bounding box.
// 5. Memory Hygiene: Releases all native tensors, maintains zero memory leaks over long sessions.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sentinel_x/core/camera/camera_frame.dart';
import 'package:sentinel_x/core/camera/temporal_frame_buffer.dart';
import 'package:sentinel_x/core/camera/camera_ingestion_service.dart';
import 'package:sentinel_x/services/onnx_native_bridge.dart';
import 'package:sentinel_x/core/ml/acoustic_silence_generator.dart';
import 'package:sentinel_x/core/ml/onnx_inference_worker.dart';
import 'package:sentinel_x/core/audio/audio_ingestion_service.dart';
import 'package:sentinel_x/core/audio/audio_preprocessor.dart';
import 'package:sentinel_x/core/ml/multimodal_synchronizer.dart';
import 'package:sentinel_x/core/ml/modality_quality_estimator.dart';
import 'package:sentinel_x/core/ml/adaptive_fusion_manager.dart';

enum ContinuousInferenceStatus {
  uninitialized,
  initializing,
  running,
  paused,
  error,
  disposed,
}

@immutable
class ContinuousInferencePrediction {
  final String cameraId;
  final List<double> threatProbabilities; // 5 classes: Explosion, Gunshot, Fighting, Accident, Normal
  final String predictedClass;
  final double confidence;
  final List<double> rawBoundingBox; // [x, y, w, h] from model Sigmoid
  final List<double> clippedBoundingBox; // [x, y, w, h] clipped to [0, 1] viewport canvas
  final bool isNormal;
  final bool isCritical;
  final bool isDegradedMode;
  final String diagnosticNotice;
  final int latencyMs;
  final DateTime timestamp;
  final int frameIndex;
  final MultimodalSyncState syncState;
  final int audioVideoOffsetMs;
  final DateTime? videoWindowStartUtc;
  final DateTime? videoWindowEndUtc;
  final DateTime? audioWindowStartUtc;
  final DateTime? audioWindowEndUtc;
  final int syncDelayMs;
  final VideoQualityMetrics? videoQuality;
  final AudioQualityMetrics? audioQuality;
  final AdaptiveFusionWeights? fusionWeights;
  final double? calibratedConfidence;
  final List<double>? calibratedThreatProbabilities;
  final bool isBboxReliable;

  const ContinuousInferencePrediction({
    required this.cameraId,
    required this.threatProbabilities,
    required this.predictedClass,
    required this.confidence,
    required this.rawBoundingBox,
    required this.clippedBoundingBox,
    required this.isNormal,
    required this.isCritical,
    required this.isDegradedMode,
    required this.diagnosticNotice,
    required this.latencyMs,
    required this.timestamp,
    required this.frameIndex,
    this.syncState = MultimodalSyncState.videoOnlyDegraded,
    this.audioVideoOffsetMs = 0,
    this.videoWindowStartUtc,
    this.videoWindowEndUtc,
    this.audioWindowStartUtc,
    this.audioWindowEndUtc,
    this.syncDelayMs = 0,
    this.videoQuality,
    this.audioQuality,
    this.fusionWeights,
    this.calibratedConfidence,
    this.calibratedThreatProbabilities,
    this.isBboxReliable = true,
  });

  /// Whether prediction is low confidence (< 0.50) and should be suppressed from emergency alarms
  bool get isLowConfidence => confidence < 0.50;

  /// Whether prediction is actionable for security alert
  bool get isActionable => !isNormal && confidence >= 0.70;

  /// Explainable confidence classification tier
  String get confidenceTier {
    if (isNormal) return 'NORMAL (CLEAR)';
    if (confidence >= 0.85) return 'CRITICAL (ACTIONABLE)';
    if (confidence >= 0.70) return 'HIGH (ACTIONABLE)';
    if (confidence >= 0.50) return 'MEDIUM (REVIEW)';
    return 'LOW (SUPPRESSED / NOISE)';
  }

  /// 5-Class taxonomy matching runtime inference contract
  static const List<String> classTaxonomy = [
    'Explosion',
    'Gunshot',
    'Fighting',
    'Accident',
    'Normal',
  ];
}

@immutable
class InferenceTelemetry {
  final ContinuousInferenceStatus status;
  final String cameraId;
  final double inferenceFps;
  final int lastLatencyMs;
  final double avgLatencyMs;
  final double p95LatencyMs;
  final int minLatencyMs;
  final int maxLatencyMs;
  final int totalInferences;
  final int successfulInferences;
  final int skippedCycles;
  final int failedInferences;
  final bool isDegradedMode;
  final String degradedNotice;
  final ContinuousInferencePrediction? latestPrediction;
  final String? errorMessage;
  final String workerStatus;
  final bool isWorkerActive;
  final int workerRestartCount;
  final int nativeLatencyMs;
  final int transferLatencyMs;
  final int prepLatencyMs;
  final MultimodalSyncTelemetry? syncTelemetry;
  final AdaptiveFusionWeights? latestFusionWeights;
  final VideoQualityMetrics? latestVideoQuality;
  final AudioQualityMetrics? latestAudioQuality;

  const InferenceTelemetry({
    required this.status,
    required this.cameraId,
    required this.inferenceFps,
    required this.lastLatencyMs,
    required this.avgLatencyMs,
    required this.p95LatencyMs,
    required this.minLatencyMs,
    required this.maxLatencyMs,
    required this.totalInferences,
    required this.successfulInferences,
    required this.skippedCycles,
    required this.failedInferences,
    required this.isDegradedMode,
    required this.degradedNotice,
    this.latestPrediction,
    this.errorMessage,
    this.workerStatus = 'idle',
    this.isWorkerActive = true,
    this.workerRestartCount = 0,
    this.nativeLatencyMs = 0,
    this.transferLatencyMs = 0,
    this.prepLatencyMs = 0,
    this.syncTelemetry,
    this.latestFusionWeights,
    this.latestVideoQuality,
    this.latestAudioQuality,
  });

  factory InferenceTelemetry.initial({String cameraId = 'CAM-001'}) {
    return InferenceTelemetry(
      status: ContinuousInferenceStatus.uninitialized,
      cameraId: cameraId,
      inferenceFps: 0.0,
      lastLatencyMs: 0,
      avgLatencyMs: 0.0,
      p95LatencyMs: 0.0,
      minLatencyMs: 0,
      maxLatencyMs: 0,
      totalInferences: 0,
      successfulInferences: 0,
      skippedCycles: 0,
      failedInferences: 0,
      isDegradedMode: true,
      degradedNotice: 'DEGRADED MODE: VIDEO ONLY — CALIBRATED SILENCE BASELINE (-80.0 dB)',
      workerStatus: 'uninitialized',
      isWorkerActive: true,
      workerRestartCount: 0,
      nativeLatencyMs: 0,
      transferLatencyMs: 0,
      prepLatencyMs: 0,
      syncTelemetry: null,
      latestFusionWeights: null,
      latestVideoQuality: null,
      latestAudioQuality: null,
    );
  }

  /// Accurate model status label for dashboard display
  String get modelStatusLabel {
    if (status == ContinuousInferenceStatus.error || errorMessage != null) {
      return 'MODEL ERROR';
    }
    if (status == ContinuousInferenceStatus.uninitialized) {
      return 'MODEL UNVALIDATED';
    }
    if (status == ContinuousInferenceStatus.running) {
      if (latestPrediction != null && latestPrediction!.isLowConfidence) {
        return 'LOW CONFIDENCE (< 0.50)';
      }
      return 'MODEL RUNNING';
    }
    if (status == ContinuousInferenceStatus.paused) {
      return 'MODEL PAUSED';
    }
    return 'MODEL STANDBY';
  }
}

class ContinuousInferenceScheduler {
  final CameraIngestionService cameraService;
  final TemporalFrameBuffer temporalBuffer;
  final AudioIngestionService? audioService;
  final AudioPreprocessor? audioPreprocessor;
  final OnnxInferenceWorker? worker;
  final OnnxNativeBridge? nativeBridge;
  final AcousticSilenceGenerator silenceGenerator;
  final MultimodalSynchronizer synchronizer;
  final ModalityQualityEstimator qualityEstimator;
  final AdaptiveFusionManager fusionManager;
  final String cameraId;

  ContinuousInferenceStatus _status = ContinuousInferenceStatus.uninitialized;
  ContinuousInferenceStatus get status => _status;

  StreamSubscription<CameraFrame>? _frameSubscription;
  bool _isInferring = false;
  bool get isInferring => _isInferring;

  int _totalInferences = 0;
  int _successfulInferences = 0;
  int _skippedCycles = 0;
  int _failedInferences = 0;
  int _lastLatencyMs = 0;
  int _lastNativeLatencyMs = 0;
  int _lastTransferLatencyMs = 0;
  int _lastPrepLatencyMs = 0;
  bool _isDegradedMode = true;
  String _diagnosticNotice = 'DEGRADED MODE: VIDEO ONLY — CALIBRATED SILENCE BASELINE (-80.0 dB)';

  ContinuousInferencePrediction? _latestPrediction;
  String? _errorMessage;

  // Latency & FPS sliding windows (last 50 observations)
  final List<int> _recentLatencies = <int>[];
  final List<DateTime> _recentInferenceTimes = <DateTime>[];

  final StreamController<ContinuousInferencePrediction> _predictionController =
      StreamController<ContinuousInferencePrediction>.broadcast();
  Stream<ContinuousInferencePrediction> get predictionStream => _predictionController.stream;

  final StreamController<InferenceTelemetry> _telemetryController =
      StreamController<InferenceTelemetry>.broadcast();
  Stream<InferenceTelemetry> get telemetryStream => _telemetryController.stream;

  InferenceTelemetry _currentTelemetry;
  InferenceTelemetry get currentTelemetry => _currentTelemetry;

  bool get isReady => (worker?.isReady ?? false) || (nativeBridge?.isReady ?? false);

  ContinuousInferenceScheduler({
    required this.cameraService,
    required this.temporalBuffer,
    this.audioService,
    AudioPreprocessor? audioPreprocessor,
    this.worker,
    this.nativeBridge,
    AcousticSilenceGenerator? silenceGenerator,
    MultimodalSynchronizer? synchronizer,
    ModalityQualityEstimator? qualityEstimator,
    AdaptiveFusionManager? fusionManager,
    this.cameraId = 'CAM-001',
  })  : audioPreprocessor = audioPreprocessor ?? AudioPreprocessor(),
        silenceGenerator = silenceGenerator ?? AcousticSilenceGenerator(),
        synchronizer = synchronizer ?? MultimodalSynchronizer(),
        qualityEstimator = qualityEstimator ?? ModalityQualityEstimator(),
        fusionManager = fusionManager ?? const AdaptiveFusionManager(),
        _currentTelemetry = InferenceTelemetry.initial(cameraId: cameraId);

  /// Initializes native session inside background worker (or native bridge) and prepares for execution.
  Future<bool> initialize({String modelAssetPath = 'assets/models/sentinelx_model.onnx'}) async {
    _status = ContinuousInferenceStatus.initializing;
    _emitTelemetry();

    try {
      if (worker != null) {
        if (!worker!.isReady) {
          final ok = await worker!.start(modelAssetPath: modelAssetPath);
          if (!ok) {
            _status = ContinuousInferenceStatus.error;
            _errorMessage = 'Failed to initialize background ONNX worker: ${worker!.lastErrorMessage}';
            _emitTelemetry();
            return false;
          }
        }
      } else if (nativeBridge != null) {
        if (!nativeBridge!.isReady) {
          final ok = await nativeBridge!.initializeSession(assetPath: modelAssetPath);
          if (!ok) {
            _status = ContinuousInferenceStatus.error;
            _errorMessage = 'Failed to initialize native ONNX session for continuous inference.';
            _emitTelemetry();
            return false;
          }
        }
      } else {
        _status = ContinuousInferenceStatus.error;
        _errorMessage = 'No ONNX execution engine (worker or bridge) configured.';
        _emitTelemetry();
        return false;
      }

      _status = ContinuousInferenceStatus.paused;
      _emitTelemetry();
      return true;
    } catch (e) {
      _status = ContinuousInferenceStatus.error;
      _errorMessage = 'Initialization exception: $e';
      _emitTelemetry();
      return false;
    }
  }

  /// Begins listening to real-time camera frames and executing inference cycles.
  void start() {
    if (_status == ContinuousInferenceStatus.running) return;

    if (_status == ContinuousInferenceStatus.uninitialized ||
        _status == ContinuousInferenceStatus.error) {
      debugPrint('[ContinuousInferenceScheduler] Cannot start: scheduler status is $_status');
      return;
    }

    _status = ContinuousInferenceStatus.running;
    _errorMessage = null;

    // Start physical microphone audio stream if configured and not already streaming
    if (audioService != null && audioService!.status != AudioConnectionStatus.streaming) {
      audioService!.startStreaming().catchError((e) {
        debugPrint('[ContinuousInferenceScheduler] Audio ingestion auto-start note: $e');
        return false;
      });
    }

    _frameSubscription?.cancel();
    _frameSubscription = cameraService.frameStream.listen(
      _onCameraFrameReceived,
      onError: (err) {
        _errorMessage = 'Camera stream error: $err';
        _emitTelemetry();
      },
    );

    _emitTelemetry();
    debugPrint('[ContinuousInferenceScheduler] Continuous ONNX inference started on camera $cameraId.');
  }

  /// Pauses continuous inference while retaining initialized native session.
  void pause() {
    if (_status == ContinuousInferenceStatus.running) {
      _frameSubscription?.cancel();
      _frameSubscription = null;
      _status = ContinuousInferenceStatus.paused;
      if (audioService != null && audioService!.status == AudioConnectionStatus.streaming) {
        audioService!.pause().catchError((e) {
          debugPrint('[ContinuousInferenceScheduler] Audio ingestion pause note: $e');
        });
      }
      _emitTelemetry();
      debugPrint('[ContinuousInferenceScheduler] Continuous inference paused.');
    }
  }

  /// Handles incoming camera frame from ingestion service.
  /// Enforces non-blocking concurrency guard: skips frame if prior inference is still in flight.
  Future<void> _onCameraFrameReceived(CameraFrame frame) async {
    if (_status != ContinuousInferenceStatus.running) return;

    // Strict Concurrency Guard: Do not queue overlapping forward passes
    if (_isInferring) {
      _skippedCycles++;
      _emitTelemetry();
      return;
    }

    _isInferring = true;
    _totalInferences++;

    try {
      if (!isReady) {
        throw StateError('Inference engine is not initialized.');
      }

      // 1. Build continuous video tensor [1, 16, 3, 224, 224] from temporal buffer
      final prepSw = Stopwatch()..start();
      final videoTensor = temporalBuffer.toTensor1x16x3x224x224();

      // Estimate Video Quality
      final videoQuality = qualityEstimator.estimateVideoQuality(temporalBuffer);

      // Estimate Audio Quality
      final audioQuality = qualityEstimator.estimateAudioBufferQuality(
        audioService?.temporalBuffer,
        isAudioServiceReady: audioService?.isBufferReady ?? false,
      );

      // 2. Multimodal Synchronization & Fusion Evaluation
      final syncEval = synchronizer.evaluate(
        videoBuffer: temporalBuffer,
        audioBuffer: audioService?.temporalBuffer,
        isAudioServiceReady: audioService?.isBufferReady ?? false,
      );

      Float32List audioTensor;
      bool isDegraded;
      String notice;

      if (syncEval.syncState == MultimodalSyncState.synchronized) {
        final audioSamples = audioService!.extractSnapshot(64000);
        final prepResult = audioPreprocessor!.processAudio(audioSamples);
        if (prepResult.isValid) {
          audioTensor = prepResult.audioTensor;
          isDegraded = false;
          notice = syncEval.diagnosticNotice;
        } else {
          audioTensor = silenceGenerator.silenceTensor;
          isDegraded = true;
          notice = 'AUDIO PREPROCESSING FAILED: ${prepResult.errorMessage} - USING SILENCE';
        }
      } else {
        audioTensor = silenceGenerator.silenceTensor;
        isDegraded = true;
        notice = syncEval.diagnosticNotice;
      }

      _isDegradedMode = isDegraded;
      _diagnosticNotice = notice;
      prepSw.stop();
      _lastPrepLatencyMs = prepSw.elapsedMilliseconds;

      List<double> threatProbabilities;
      List<double> rawBoundingBox;
      String predictedClass;
      double confidence;

      // 3. Execute inference: background worker isolate (preferred) or native bridge
      if (worker != null) {
        final workerOutput = await worker!.infer(
          videoTensor: videoTensor,
          audioTensor: audioTensor,
          prepLatencyMs: _lastPrepLatencyMs,
        );

        _lastNativeLatencyMs = workerOutput.nativeInferenceLatencyMs;
        _lastTransferLatencyMs = workerOutput.transferLatencyMs;
        _lastLatencyMs = workerOutput.totalLatencyMs;

        threatProbabilities = workerOutput.threatProbabilities;
        rawBoundingBox = workerOutput.boundingBox;
        predictedClass = workerOutput.predictedClass;
        confidence = workerOutput.confidence;
      } else if (nativeBridge != null) {
        final nativeOutput = await nativeBridge!.executeInference(
          videoFrames: videoTensor,
          audioSpectrogram: audioTensor,
          isSynthetic: false,
        );

        _lastNativeLatencyMs = nativeOutput.latencyMs;
        _lastTransferLatencyMs = 0;
        _lastLatencyMs = nativeOutput.latencyMs + _lastPrepLatencyMs;

        threatProbabilities = nativeOutput.threatProbabilities;
        rawBoundingBox = nativeOutput.boundingBox;
        predictedClass = nativeOutput.predictedClass;
        confidence = nativeOutput.confidence;
      } else {
        throw StateError('No inference backend configured.');
      }

      _recordLatencyMetrics(_lastLatencyMs);

      // Verify and guarantee Softmax probability contract (sum to 1.0)
      final probSum = threatProbabilities.fold<double>(0.0, (acc, p) => acc + p);
      if ((probSum - 1.0).abs() > 0.005 && probSum > 0) {
        threatProbabilities = threatProbabilities.map((p) => p / probSum).toList();
      }

      // 4. Viewport Canvas Boundary Clipping on Bounding Box
      final clippedBbox = _clipBoundingBox(rawBoundingBox);

      // 5. Apply Explainable Deterministic Adaptive Fusion Calibration
      final fusionOutput = fusionManager.applyFusion(
        rawProbabilities: threatProbabilities,
        rawBoundingBox: clippedBbox,
        rawPredictedClass: predictedClass,
        rawConfidence: confidence,
        videoQuality: videoQuality,
        audioQuality: audioQuality,
        syncState: syncEval.syncState,
        isDegradedMode: isDegraded,
      );

      // 6. Build structured continuous prediction with degraded mode, sync and fusion metadata
      final prediction = ContinuousInferencePrediction(
        cameraId: cameraId,
        threatProbabilities: List<double>.unmodifiable(threatProbabilities),
        predictedClass: predictedClass,
        confidence: confidence,
        rawBoundingBox: List<double>.unmodifiable(rawBoundingBox),
        clippedBoundingBox: List<double>.unmodifiable(clippedBbox),
        isNormal: predictedClass == 'Normal',
        isCritical: confidence >= 0.85 && predictedClass != 'Normal',
        isDegradedMode: isDegraded,
        diagnosticNotice: notice,
        latencyMs: _lastLatencyMs,
        timestamp: DateTime.now().toUtc(),
        frameIndex: frame.frameIndex,
        syncState: syncEval.syncState,
        audioVideoOffsetMs: syncEval.audioVideoOffsetMs,
        videoWindowStartUtc: syncEval.videoWindow.windowStartUtc,
        videoWindowEndUtc: syncEval.videoWindow.windowEndUtc,
        audioWindowStartUtc: syncEval.audioWindow?.windowStartUtc,
        audioWindowEndUtc: syncEval.audioWindow?.windowEndUtc,
        syncDelayMs: syncEval.syncDelayMs,
        videoQuality: videoQuality,
        audioQuality: audioQuality,
        fusionWeights: fusionOutput.weights,
        calibratedConfidence: fusionOutput.calibratedConfidence,
        calibratedThreatProbabilities: fusionOutput.calibratedThreatProbabilities,
        isBboxReliable: fusionOutput.isBboxReliable,
      );

      _latestPrediction = prediction;
      _successfulInferences++;

      // 7. Emit prediction to subscribers (UI HUD, Sync Service)
      if (!_predictionController.isClosed) {
        _predictionController.add(prediction);
      }

      _emitTelemetry();
    } catch (e, stack) {
      _failedInferences++;
      _errorMessage = 'Inference cycle failed: $e';
      debugPrint('[ContinuousInferenceScheduler] Error: $e\n$stack');
      _emitTelemetry();
    } finally {
      _isInferring = false;
    }
  }

  /// Clips model Sigmoid output coordinates to guarantee canvas boundaries:
  /// x in [0, 1], y in [0, 1], w <= 1 - x, h <= 1 - y
  List<double> _clipBoundingBox(List<double> raw) {
    if (raw.length < 4) return const [0.0, 0.0, 0.0, 0.0];

    final x = raw[0].clamp(0.0, 1.0);
    final y = raw[1].clamp(0.0, 1.0);
    final wRaw = raw[2].clamp(0.0, 1.0);
    final hRaw = raw[3].clamp(0.0, 1.0);

    final wClipped = min(wRaw, 1.0 - x).clamp(0.0, 1.0);
    final hClipped = min(hRaw, 1.0 - y).clamp(0.0, 1.0);

    return [x, y, wClipped, hClipped];
  }

  void _recordLatencyMetrics(int latencyMs) {
    _recentLatencies.add(latencyMs);
    if (_recentLatencies.length > 50) {
      _recentLatencies.removeAt(0);
    }

    final now = DateTime.now();
    _recentInferenceTimes.add(now);
    if (_recentInferenceTimes.length > 20) {
      _recentInferenceTimes.removeAt(0);
    }
  }

  double _calculateInferenceFps() {
    if (_recentInferenceTimes.length < 2) return 0.0;
    final durationMs = _recentInferenceTimes.last
        .difference(_recentInferenceTimes.first)
        .inMilliseconds;
    if (durationMs <= 0) return 0.0;
    return (_recentInferenceTimes.length - 1) / (durationMs / 1000.0);
  }

  double _calculateAvgLatency() {
    if (_recentLatencies.isEmpty) return 0.0;
    final sum = _recentLatencies.reduce((a, b) => a + b);
    return sum / _recentLatencies.length;
  }

  double _calculateP95Latency() {
    if (_recentLatencies.isEmpty) return 0.0;
    final sorted = List<int>.from(_recentLatencies)..sort();
    final index = (sorted.length * 0.95).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)].toDouble();
  }

  int _calculateMinLatency() {
    if (_recentLatencies.isEmpty) return 0;
    return _recentLatencies.reduce(min);
  }

  int _calculateMaxLatency() {
    if (_recentLatencies.isEmpty) return 0;
    return _recentLatencies.reduce(max);
  }

  void _emitTelemetry() {
    _currentTelemetry = InferenceTelemetry(
      status: _status,
      cameraId: cameraId,
      inferenceFps: _calculateInferenceFps(),
      lastLatencyMs: _lastLatencyMs,
      avgLatencyMs: _calculateAvgLatency(),
      p95LatencyMs: _calculateP95Latency(),
      minLatencyMs: _calculateMinLatency(),
      maxLatencyMs: _calculateMaxLatency(),
      totalInferences: _totalInferences,
      successfulInferences: _successfulInferences,
      skippedCycles: _skippedCycles,
      failedInferences: _failedInferences,
      isDegradedMode: _isDegradedMode,
      degradedNotice: _diagnosticNotice,
      latestPrediction: _latestPrediction,
      errorMessage: _errorMessage,
      workerStatus: worker?.status.name ?? (nativeBridge != null ? 'native_bridge' : 'none'),
      isWorkerActive: worker != null,
      workerRestartCount: worker?.restartCount ?? 0,
      nativeLatencyMs: _lastNativeLatencyMs,
      transferLatencyMs: _lastTransferLatencyMs,
      prepLatencyMs: _lastPrepLatencyMs,
      syncTelemetry: synchronizer.latestTelemetry,
      latestFusionWeights: _latestPrediction?.fusionWeights,
      latestVideoQuality: _latestPrediction?.videoQuality,
      latestAudioQuality: _latestPrediction?.audioQuality,
    );

    if (!_telemetryController.isClosed) {
      _telemetryController.add(_currentTelemetry);
    }
  }

  /// Releases scheduler subscriptions and controllers cleanly
  Future<void> dispose() async {
    pause();
    _status = ContinuousInferenceStatus.disposed;
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    await worker?.dispose();
    await _predictionController.close();
    await _telemetryController.close();
  }
}
