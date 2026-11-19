// SentinelX - Riverpod Providers
// Central provider definitions for the entire application state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/models/models.dart';
import 'package:sentinel_x/core/inference/mock_inference_engine.dart';

export 'package:sentinel_x/services/mock_inference_service.dart';
export 'package:sentinel_x/services/onnx_inference_engine.dart';
export 'package:sentinel_x/services/inference_repository.dart';
export 'package:sentinel_x/core/services/incident_dispatch_repository.dart';
export 'package:sentinel_x/features/camera/controllers/video_feed_controller.dart';
export 'package:sentinel_x/features/audio/widgets/audio_spectrum_visualizer.dart';

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
  final engine = ref.watch(inferenceEngineProvider);
  return engine.audioStream;
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
}

// ─────────────────────────────────────────────────
// NAVIGATION STATE
// ─────────────────────────────────────────────────

enum AppPage { dashboard, cameras, alerts, analytics, audio, police, settings }

final currentPageProvider = StateProvider<AppPage>((ref) => AppPage.dashboard);
