// SentinelX - Riverpod Providers
// Central provider definitions for the entire application state.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/models/models.dart';
import 'package:sentinel_x/core/inference/mock_inference_engine.dart';
import 'package:sentinel_x/core/camera/camera_frame.dart';
import 'package:sentinel_x/core/camera/temporal_frame_buffer.dart';
import 'package:sentinel_x/core/camera/camera_ingestion_service.dart';
import 'package:sentinel_x/core/ml/acoustic_silence_generator.dart';
import 'package:sentinel_x/core/ml/onnx_inference_worker.dart';
import 'package:sentinel_x/core/ml/continuous_inference_scheduler.dart';
import 'package:sentinel_x/core/ml/detection_sync_service.dart';
import 'package:sentinel_x/core/audio/temporal_audio_buffer.dart';
import 'package:sentinel_x/core/audio/audio_preprocessor.dart';
import 'package:sentinel_x/core/audio/audio_ingestion_service.dart';
import 'package:sentinel_x/core/ml/multimodal_synchronizer.dart';
import 'package:sentinel_x/core/ml/modality_quality_estimator.dart';
import 'package:sentinel_x/core/ml/adaptive_fusion_manager.dart';
import 'package:sentinel_x/core/providers/auth_provider.dart';
import 'package:sentinel_x/core/services/incident_dispatch_repository.dart';
import 'package:sentinel_x/features/audio/widgets/audio_spectrum_visualizer.dart';

export 'package:sentinel_x/services/mock_inference_service.dart';
export 'package:sentinel_x/services/onnx_inference_engine.dart';
export 'package:sentinel_x/services/onnx_native_bridge.dart';
export 'package:sentinel_x/services/inference_repository.dart';
export 'package:sentinel_x/core/services/incident_dispatch_repository.dart';
export 'package:sentinel_x/core/camera/camera_frame.dart';
export 'package:sentinel_x/core/camera/temporal_frame_buffer.dart';
export 'package:sentinel_x/core/camera/camera_ingestion_service.dart';
export 'package:sentinel_x/core/audio/fft.dart';
export 'package:sentinel_x/core/audio/mel_filterbank.dart';
export 'package:sentinel_x/core/audio/temporal_audio_buffer.dart';
export 'package:sentinel_x/core/audio/audio_preprocessor.dart';
export 'package:sentinel_x/core/audio/audio_ingestion_service.dart';
export 'package:sentinel_x/core/ml/acoustic_silence_generator.dart';
export 'package:sentinel_x/core/ml/onnx_inference_worker.dart';
export 'package:sentinel_x/core/ml/continuous_inference_scheduler.dart';
export 'package:sentinel_x/core/ml/multimodal_synchronizer.dart';
export 'package:sentinel_x/core/ml/modality_quality_estimator.dart';
export 'package:sentinel_x/core/ml/adaptive_fusion_manager.dart';
export 'package:sentinel_x/core/ml/detection_sync_service.dart';
export 'package:sentinel_x/features/camera/controllers/video_feed_controller.dart';
export 'package:sentinel_x/features/audio/widgets/audio_spectrum_visualizer.dart';

// ─────────────────────────────────────────────────
// CAMERA INGESTION & TEMPORAL FRAME BUFFER PROVIDERS
// ─────────────────────────────────────────────────

final temporalFrameBufferProvider = Provider<TemporalFrameBuffer>((ref) {
  return TemporalFrameBuffer();
});

final cameraIngestionServiceProvider = Provider<CameraIngestionService>((ref) {
  final buffer = ref.watch(temporalFrameBufferProvider);
  final service = CameraIngestionService(cameraId: 'CAM-001', temporalBuffer: buffer);
  ref.onDispose(() => service.dispose());
  return service;
});

final cameraTelemetryStreamProvider = StreamProvider<CameraTelemetry>((ref) {
  final service = ref.watch(cameraIngestionServiceProvider);
  return service.telemetryStream;
});

final cameraFrameStreamProvider = StreamProvider<CameraFrame>((ref) {
  final service = ref.watch(cameraIngestionServiceProvider);
  return service.frameStream;
});

// ─────────────────────────────────────────────────
// AUDIO INGESTION & TEMPORAL AUDIO BUFFER PROVIDERS
// ─────────────────────────────────────────────────

final temporalAudioBufferProvider = Provider<TemporalAudioBuffer>((ref) {
  return TemporalAudioBuffer();
});

final audioPreprocessorProvider = Provider<AudioPreprocessor>((ref) {
  return AudioPreprocessor();
});

final audioIngestionServiceProvider = Provider<AudioIngestionService>((ref) {
  final buffer = ref.watch(temporalAudioBufferProvider);
  final service = AudioIngestionService(temporalBuffer: buffer);
  ref.onDispose(() => service.dispose());
  return service;
});

final audioTelemetryStreamProvider = StreamProvider<AudioTelemetry>((ref) {
  final service = ref.watch(audioIngestionServiceProvider);
  return service.telemetryStream;
});

// ─────────────────────────────────────────────────
// CONTINUOUS REAL-TIME ONNX INFERENCE PROVIDERS
// ─────────────────────────────────────────────────

final acousticSilenceGeneratorProvider = Provider<AcousticSilenceGenerator>((ref) {
  return AcousticSilenceGenerator();
});

final onnxInferenceWorkerProvider = Provider<OnnxInferenceWorker>((ref) {
  final worker = OnnxInferenceWorker();
  ref.onDispose(() => worker.dispose());
  return worker;
});

final multimodalSynchronizerProvider = Provider<MultimodalSynchronizer>((ref) {
  return MultimodalSynchronizer();
});

final modalityQualityEstimatorProvider = Provider<ModalityQualityEstimator>((ref) {
  return ModalityQualityEstimator();
});

final adaptiveFusionManagerProvider = Provider<AdaptiveFusionManager>((ref) {
  return const AdaptiveFusionManager();
});

final continuousInferenceSchedulerProvider = Provider<ContinuousInferenceScheduler>((ref) {
  final cameraService = ref.watch(cameraIngestionServiceProvider);
  final temporalBuffer = ref.watch(temporalFrameBufferProvider);
  final audioService = ref.watch(audioIngestionServiceProvider);
  final audioPrep = ref.watch(audioPreprocessorProvider);
  final worker = ref.watch(onnxInferenceWorkerProvider);
  final silenceGen = ref.watch(acousticSilenceGeneratorProvider);
  final synchronizer = ref.watch(multimodalSynchronizerProvider);
  final qualityEstimator = ref.watch(modalityQualityEstimatorProvider);
  final fusionManager = ref.watch(adaptiveFusionManagerProvider);

  final scheduler = ContinuousInferenceScheduler(
    cameraService: cameraService,
    temporalBuffer: temporalBuffer,
    audioService: audioService,
    audioPreprocessor: audioPrep,
    worker: worker,
    silenceGenerator: silenceGen,
    synchronizer: synchronizer,
    qualityEstimator: qualityEstimator,
    fusionManager: fusionManager,
    cameraId: 'CAM-001',
  );

  ref.onDispose(() => scheduler.dispose());
  return scheduler;
});

final continuousInferencePredictionStreamProvider =
    StreamProvider<ContinuousInferencePrediction>((ref) {
  final scheduler = ref.watch(continuousInferenceSchedulerProvider);
  return scheduler.predictionStream;
});

final continuousInferenceTelemetryStreamProvider =
    StreamProvider<InferenceTelemetry>((ref) {
  final scheduler = ref.watch(continuousInferenceSchedulerProvider);
  return scheduler.telemetryStream;
});

final detectionSyncServiceProvider = Provider<DetectionSyncService>((ref) {
  final crimeLogService = ref.watch(crimeLogServiceProvider);
  final scheduler = ref.watch(continuousInferenceSchedulerProvider);

  final syncService = DetectionSyncService(crimeLogService: crimeLogService);
  syncService.bindToScheduler(scheduler);

  ref.onDispose(() => syncService.dispose());
  return syncService;
});

final detectionSyncTelemetryStreamProvider = StreamProvider<SyncTelemetry>((ref) {
  final syncService = ref.watch(detectionSyncServiceProvider);
  return syncService.telemetryStream;
});

// ─────────────────────────────────────────────────
// INFERENCE ENGINE (singleton)
// ─────────────────────────────────────────────────

final inferenceEngineProvider = Provider<MockInferenceEngine>((ref) {
  final engine = MockInferenceEngine();
  engine.initialize(cameraCount: 1);
  ref.onDispose(() => engine.dispose());
  return engine;
});

// ─────────────────────────────────────────────────
// INFERENCE RUNNING STATE
// ─────────────────────────────────────────────────

final inferenceRunningProvider = StateProvider<bool>((ref) => false);

// ─────────────────────────────────────────────────
// CAMERA FEEDS
// ─────────────────────────────────────────────────

final cameraFeedsProvider = StateNotifierProvider<CameraFeedsNotifier, List<CameraFeed>>((ref) {
  final engine = ref.watch(inferenceEngineProvider);
  return CameraFeedsNotifier(engine);
});

class CameraFeedsNotifier extends StateNotifier<List<CameraFeed>> {
  final MockInferenceEngine _engine;

  CameraFeedsNotifier(this._engine) : super([]) {
    state = _engine.generateCameraFeeds();
  }

  void refresh() {
    state = _engine.generateCameraFeeds();
  }
}

// ─────────────────────────────────────────────────
// SELECTED CAMERA
// ─────────────────────────────────────────────────

final selectedCameraProvider = StateProvider<CameraFeed?>((ref) => null);

// ─────────────────────────────────────────────────
// LIVE DETECTIONS (stream)
// ─────────────────────────────────────────────────

final detectionsStreamProvider = StreamProvider<List<Detection>>((ref) {
  final engine = ref.watch(inferenceEngineProvider);
  return engine.detectionStream;
});

// ─────────────────────────────────────────────────
// DETECTIONS ACCUMULATOR (keeps rolling window)
// ─────────────────────────────────────────────────

final detectionsAccumulatorProvider =
    StateNotifierProvider<DetectionsAccumulator, List<Detection>>((ref) {
  final notifier = DetectionsAccumulator();
  ref.listen(detectionsStreamProvider, (_, next) {
    next.whenData((detections) => notifier.addDetections(detections));
  });
  return notifier;
});

class DetectionsAccumulator extends StateNotifier<List<Detection>> {
  static const int maxDetections = 200;

  DetectionsAccumulator() : super([]);

  void addDetections(List<Detection> newDetections) {
    final combined = [...newDetections, ...state];
    if (combined.length > maxDetections) {
      state = combined.sublist(0, maxDetections);
    } else {
      state = combined;
    }
  }

  void clear() => state = [];
}

// ─────────────────────────────────────────────────
// AUDIO EVENTS (stream)
// ─────────────────────────────────────────────────

final audioStreamProvider = StreamProvider<AudioEvent>((ref) {
  final controller = StreamController<AudioEvent>.broadcast();

  // 1. Listen to continuous inference predictions for acoustic/multimodal anomalies
  final scheduler = ref.watch(continuousInferenceSchedulerProvider);
  final subPred = scheduler.predictionStream.listen((pred) {
    if (!pred.isNormal && pred.confidence >= 0.50) {
      final threatLvl = pred.isCritical
          ? ThreatLevel.critical
          : (pred.confidence >= 0.75 ? ThreatLevel.high : ThreatLevel.medium);
      controller.add(AudioEvent(
        id: 'ONNX-${pred.frameIndex}-${pred.timestamp.millisecondsSinceEpoch}',
        cameraId: pred.cameraId,
        classification: pred.predictedClass.toLowerCase(),
        confidence: pred.confidence,
        threat: threatLvl,
        timestamp: pred.timestamp,
        frequencyBands: List.filled(20, 0.5),
        decibelLevel: -15.0,
      ));
    }
  });

  // 2. Listen to audio stream frames for real physical acoustic spikes (> -18.0 dBFS)
  final captureService = ref.watch(audioCaptureServiceProvider);
  DateTime lastSpikeTime = DateTime.fromMillisecondsSinceEpoch(0);
  final subFrame = captureService.stream.listen((frame) {
    if (frame.isAudioSpike) {
      final now = DateTime.now();
      // Throttle spikes to at most 1 per 2 seconds
      if (now.difference(lastSpikeTime).inMilliseconds >= 2000) {
        lastSpikeTime = now;
        final conf = ((frame.decibels + 80.0) / 80.0).clamp(0.0, 1.0);
        controller.add(AudioEvent(
          id: 'SPIKE-${now.millisecondsSinceEpoch}',
          cameraId: 'CAM-001 (MIC)',
          classification: 'acoustic_spike',
          confidence: conf,
          threat: ThreatLevel.none,
          timestamp: now,
          frequencyBands: frame.frequencies,
          decibelLevel: frame.decibels,
        ));
      }
    }
  });

  ref.onDispose(() {
    subPred.cancel();
    subFrame.cancel();
    controller.close();
  });

  return controller.stream;
});

final audioEventsAccumulatorProvider =
    StateNotifierProvider<AudioEventsAccumulator, List<AudioEvent>>((ref) {
  final notifier = AudioEventsAccumulator();
  ref.listen(audioStreamProvider, (_, next) {
    next.whenData((event) => notifier.addEvent(event));
  });
  return notifier;
});

class AudioEventsAccumulator extends StateNotifier<List<AudioEvent>> {
  static const int maxEvents = 50;

  AudioEventsAccumulator() : super([]);

  void addEvent(AudioEvent event) {
    state = [event, ...state.take(maxEvents - 1)];
  }
}

// ─────────────────────────────────────────────────
// SYSTEM METRICS (stream)
// ─────────────────────────────────────────────────

final metricsStreamProvider = StreamProvider<SystemMetrics>((ref) {
  final engine = ref.watch(inferenceEngineProvider);
  return engine.metricsStream;
});

// ─────────────────────────────────────────────────
// SECURITY ALERTS
// ─────────────────────────────────────────────────

final alertsProvider =
    StateNotifierProvider<AlertsNotifier, List<SecurityAlert>>((ref) {
  final notifier = AlertsNotifier();
  final engine = ref.watch(inferenceEngineProvider);

  // Listen for new alerts from inference engine
  final sub = engine.alertStream.listen((alert) {
    notifier.addAlert(alert);
  });
  ref.onDispose(() => sub.cancel());

  return notifier;
});

class AlertsNotifier extends StateNotifier<List<SecurityAlert>> {
  static const int maxAlerts = 100;

  AlertsNotifier() : super([]);

  void addAlert(SecurityAlert alert) {
    state = [alert, ...state.take(maxAlerts - 1)];
  }

  void acknowledgeAlert(String alertId) {
    state = [
      for (final alert in state)
        if (alert.id == alertId) alert.copyWith(acknowledged: true) else alert,
    ];
  }

  void clearAll() => state = [];
}

// ─────────────────────────────────────────────────
// THREAT TIMELINE
// ─────────────────────────────────────────────────

final threatTimelineProvider =
    StateNotifierProvider<ThreatTimelineNotifier, List<ThreatTimelineEntry>>(
        (ref) {
  final notifier = ThreatTimelineNotifier();
  ref.listen(detectionsStreamProvider, (_, next) {
    next.whenData((detections) {
      if (detections.isNotEmpty) {
        final maxThreat = detections.fold<double>(
          0.0,
          (max, d) =>
              d.threat.numericValue > max ? d.threat.numericValue : max,
        );
        notifier.addEntry(ThreatTimelineEntry(
          time: DateTime.now(),
          threatScore: maxThreat,
          detectionCount: detections.length,
        ));
      }
    });
  });
  return notifier;
});

class ThreatTimelineNotifier extends StateNotifier<List<ThreatTimelineEntry>> {
  static const int maxEntries = 120; // ~2 minutes at 1 entry/sec

  ThreatTimelineNotifier() : super([]);

  void addEntry(ThreatTimelineEntry entry) {
    state = [...state.take(maxEntries - 1), entry];
  }

  void clearAll() => state = [];
}

// ─────────────────────────────────────────────────
// NAVIGATION STATE
// ─────────────────────────────────────────────────

enum AppPage { dashboard, cameras, alerts, analytics, audio, police, settings }

final currentPageProvider = StateProvider<AppPage>((ref) => AppPage.dashboard);

// ─────────────────────────────────────────────────
// USER SESSION STATE PURGE (LOGOUT & SWITCH USER)
// ─────────────────────────────────────────────────

/// Resets all user-specific, alert, and surveillance telemetry state on logout/login.
void resetUserSessionState(dynamic ref) {
  try {
    ref.read(detectionsAccumulatorProvider.notifier).clear();
  } catch (_) {}
  try {
    ref.read(alertsProvider.notifier).clearAll();
  } catch (_) {}
  try {
    ref.read(threatTimelineProvider.notifier).clearAll();
  } catch (_) {}
  try {
    ref.read(incidentDispatchProvider.notifier).clearAll();
  } catch (_) {}
  try {
    ref.read(selectedCameraProvider.notifier).state = null;
  } catch (_) {}
  try {
    ref.read(currentPageProvider.notifier).state = AppPage.dashboard;
  } catch (_) {}
}
