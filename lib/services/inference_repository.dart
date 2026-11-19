// SentinelX - Inference Repository & Hybrid Fallback Switcher
// Automatically detects local .onnx weights; if absent, gracefully falls back to MockInferenceService.
// Exposes simulation mode banner state and unified real-time detection payload stream.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentinel_x/services/mock_inference_service.dart';
import 'package:sentinel_x/services/onnx_inference_engine.dart';

enum ActiveInferenceMode {
  onnxNative,
  simulationFallback;

  bool get isNative => this == ActiveInferenceMode.onnxNative;
  bool get isSimulation => this == ActiveInferenceMode.simulationFallback;

  String get label => switch (this) {
    ActiveInferenceMode.onnxNative => 'Local ONNX Hardware Engine',
    ActiveInferenceMode.simulationFallback => 'Simulation Fallback Mode',
  };
}

@immutable
class InferenceRepositoryState {
  final ActiveInferenceMode mode;
  final bool isModelLoaded;
  final String modelPath;
  final String bannerMessage;
  final bool showSimulationBanner;
  final int lastInferenceLatencyMs;
  final ModelMetadata metadata;

  const InferenceRepositoryState({
    required this.mode,
    required this.isModelLoaded,
    required this.modelPath,
    required this.bannerMessage,
    required this.showSimulationBanner,
    required this.lastInferenceLatencyMs,
    required this.metadata,
  });

  InferenceRepositoryState copyWith({
    ActiveInferenceMode? mode,
    bool? isModelLoaded,
    String? modelPath,
    String? bannerMessage,
    bool? showSimulationBanner,
    int? lastInferenceLatencyMs,
    ModelMetadata? metadata,
  }) {
    return InferenceRepositoryState(
      mode: mode ?? this.mode,
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
      modelPath: modelPath ?? this.modelPath,
      bannerMessage: bannerMessage ?? this.bannerMessage,
      showSimulationBanner: showSimulationBanner ?? this.showSimulationBanner,
      lastInferenceLatencyMs: lastInferenceLatencyMs ?? this.lastInferenceLatencyMs,
      metadata: metadata ?? this.metadata,
    );
  }

  factory InferenceRepositoryState.initial() {
    final hasLocalModel = File('assets/models/sentinelx_model.onnx').existsSync();
    return InferenceRepositoryState(
      mode: hasLocalModel ? ActiveInferenceMode.onnxNative : ActiveInferenceMode.simulationFallback,
      isModelLoaded: hasLocalModel,
      modelPath: 'assets/models/sentinelx_model.onnx',
      bannerMessage: hasLocalModel
          ? 'DirectML / ONNX Runtime Active (sentinelx_model.onnx)'
          : 'Running in Simulation Mode. Load .onnx model file in Settings.',
      showSimulationBanner: !hasLocalModel,
      lastInferenceLatencyMs: 14,
      metadata: ModelMetadata.defaultDirectML(path: 'assets/models/sentinelx_model.onnx'),
    );
  }
}

// ─────────────────────────────────────────────────
// REPOSITORY IMPLEMENTATION
// ─────────────────────────────────────────────────

class InferenceRepository {
  final OnnxInferenceEngine _onnxEngine;
  final MockInferenceService _mockService;

  final StreamController<InferenceRepositoryState> _stateController =
      StreamController<InferenceRepositoryState>.broadcast();

  Stream<InferenceRepositoryState> get stateStream => _stateController.stream;

  InferenceRepositoryState _state = InferenceRepositoryState.initial();
  InferenceRepositoryState get state => _state;

  StreamSubscription<InferencePayload>? _mockSubscription;
  final StreamController<InferencePayload> _unifiedPayloadController =
      StreamController<InferencePayload>.broadcast();

  Stream<InferencePayload> get payloadStream => _unifiedPayloadController.stream;

  InferenceRepository({
    required OnnxInferenceEngine onnxEngine,
    required MockInferenceService mockService,
  })  : _onnxEngine = onnxEngine,
        _mockService = mockService;

  void _updateState(InferenceRepositoryState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Checks for sentinelx_model.onnx in local application storage or assets.
  Future<void> initialize() async {
    _mockService.start();

    // Listen to mock stream by default
    _mockSubscription?.cancel();
    _mockSubscription = _mockService.payloadStream.listen((payload) {
      if (!_unifiedPayloadController.isClosed) {
        _unifiedPayloadController.add(payload);
      }
    });

    final detectedPath = await _findLocalModelPath();

    if (detectedPath != null) {
      final success = await _onnxEngine.initialize(customPath: detectedPath);
      if (success) {
        _updateState(_state.copyWith(
          mode: ActiveInferenceMode.onnxNative,
          isModelLoaded: true,
          modelPath: detectedPath,
          showSimulationBanner: false,
          bannerMessage: 'DirectML / ONNX Runtime Active',
          metadata: _onnxEngine.metadata,
        ));
        return;
      }
    }

    // Fallback: Gracefully activate simulation mode
    _updateState(_state.copyWith(
      mode: ActiveInferenceMode.simulationFallback,
      isModelLoaded: false,
      showSimulationBanner: true,
      bannerMessage: 'Running in Simulation Mode. Load .onnx model file in Settings.',
    ));
  }

  Future<String?> _findLocalModelPath() async {
    try {
      // 1. Check local workspace asset
      final workspaceFile = File('assets/models/sentinelx_model.onnx');
      if (await workspaceFile.exists()) {
        return workspaceFile.path;
      }

      // 2. Check Flutter Asset Bundle
      try {
        final byteData = await rootBundle.load('assets/models/sentinelx_model.onnx');
        if (byteData.lengthInBytes > 0) {
          return 'assets/models/sentinelx_model.onnx';
        }
      } catch (_) {}

      // 3. Check App Documents Directory
      final appDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${appDir.path}${Platform.pathSeparator}sentinelx_model.onnx');
      if (await targetFile.exists()) {
        return targetFile.path;
      }
    } catch (e) {
      debugPrint('[InferenceRepository] Model auto-detection exception: $e');
    }
    return null;
  }

  /// Manually loads a user-selected .onnx model file.
  Future<bool> loadCustomModel(String absolutePath) async {
    try {
      final file = File(absolutePath);
      if (!await file.exists()) {
        return false;
      }

      final success = await _onnxEngine.initialize(customPath: absolutePath);
      if (success) {
        final fileSize = await file.length();
        final updatedMeta = ModelMetadata(
          modelName: file.uri.pathSegments.last,
          modelPath: absolutePath,
          fileSizeBytes: fileSize,
          quantization: _onnxEngine.metadata.quantization,
          inputShape: _onnxEngine.metadata.inputShape,
          executionProvider: _onnxEngine.metadata.executionProvider,
          isLoaded: true,
          loadedAt: DateTime.now(),
        );

        _updateState(_state.copyWith(
          mode: ActiveInferenceMode.onnxNative,
          isModelLoaded: true,
          modelPath: absolutePath,
          showSimulationBanner: false,
          bannerMessage: 'Loaded ${updatedMeta.modelName} via ${_onnxEngine.metadata.executionProvider.displayName}',
          metadata: updatedMeta,
        ));
        return true;
      }
    } catch (e) {
      debugPrint('[InferenceRepository] Error loading custom model: $e');
    }
    return false;
  }

  /// Benchmarks execution latency (ms) on the local engine.
  Future<int> benchmark() async {
    final latency = await _onnxEngine.benchmarkLatency();
    _updateState(_state.copyWith(lastInferenceLatencyMs: latency));
    return latency;
  }

  /// Dismiss the simulation warning banner.
  void dismissBanner() {
    _updateState(_state.copyWith(showSimulationBanner: false));
  }

  void dispose() {
    _mockSubscription?.cancel();
    _unifiedPayloadController.close();
    _stateController.close();
    _onnxEngine.dispose();
  }
}

// ─────────────────────────────────────────────────
// RIVERPOD PROVIDERS
// ─────────────────────────────────────────────────

final onnxInferenceEngineProvider = Provider<OnnxInferenceEngine>((ref) {
  final engine = OnnxInferenceEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});

final inferenceRepositoryProvider = Provider<InferenceRepository>((ref) {
  final onnxEngine = ref.watch(onnxInferenceEngineProvider);
  final mockService = ref.watch(mockInferenceServiceProvider);

  final repository = InferenceRepository(
    onnxEngine: onnxEngine,
    mockService: mockService,
  );
  repository.initialize();

  ref.onDispose(() => repository.dispose());
  return repository;
});

final inferenceRepositoryStateProvider =
    StreamProvider<InferenceRepositoryState>((ref) {
  final repo = ref.watch(inferenceRepositoryProvider);
  return repo.stateStream;
});

final activeInferencePayloadStreamProvider =
    StreamProvider<InferencePayload>((ref) {
  final repo = ref.watch(inferenceRepositoryProvider);
  return repo.payloadStream;
});
