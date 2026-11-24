// SentinelX - Native ONNX Runtime Bridge & Execution Provider Controller
// Directly interfaces with onnxruntime C-API via Dart FFI on Windows Desktop x64 and Android ARM64.
//
// STRICT SAFETY MANDATE:
// All benchmark and synthetic test tensors are strictly confined to local developer diagnostics.
// Predictions generated from synthetic inputs are labeled:
// "SYNTHETIC TEST INPUT — NOT LIVE DETECTION"
// and are NEVER written to the production database or dispatched as live security incidents.

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// Structured inference prediction from native multimodal execution.
@immutable
class NativeInferenceOutput {
  final List<double> threatProbabilities; // 5 classes
  final List<double> boundingBox; // [x, y, w, h] normalized in [0, 1]
  final String predictedClass;
  final double confidence;
  final int latencyMs;
  final DateTime executedAt;
  final bool isSynthetic;
  final String diagnosticNotice;

  const NativeInferenceOutput({
    required this.threatProbabilities,
    required this.boundingBox,
    required this.predictedClass,
    required this.confidence,
    required this.latencyMs,
    required this.executedAt,
    this.isSynthetic = false,
    this.diagnosticNotice = '',
  });

  static const List<String> classLabels = [
    'Explosion',
    'Gunshot',
    'Fighting',
    'Accident',
    'Normal',
  ];
}

/// Structured benchmark metrics from consecutive native execution passes.
@immutable
class NativeBenchmarkResult {
  final String runtimeVersion;
  final String executionProvider;
  final List<int> individualLatenciesMs;
  final double averageLatencyMs;
  final double minLatencyMs;
  final double maxLatencyMs;
  final double throughputFps;
  final NativeInferenceOutput sampleOutput;
  final String diagnosticLabel;
  final Map<String, List<int>> tensorShapes;

  const NativeBenchmarkResult({
    required this.runtimeVersion,
    required this.executionProvider,
    required this.individualLatenciesMs,
    required this.averageLatencyMs,
    required this.minLatencyMs,
    required this.maxLatencyMs,
    required this.throughputFps,
    required this.sampleOutput,
    required this.diagnosticLabel,
    required this.tensorShapes,
  });
}

class OnnxNativeBridge {
  static final OnnxNativeBridge _instance = OnnxNativeBridge._internal();
  factory OnnxNativeBridge() => _instance;
  OnnxNativeBridge._internal();

  static bool _envInitialized = false;
  static bool _dllPreloaded = false;

  OrtSession? _session;
  OrtSessionOptions? _sessionOptions;
  String? _loadedModelPath;
  int _loadedModelSizeBytes = 0;
  bool _isSessionReady = false;

  bool get isReady => _isSessionReady && _session != null;
  String? get loadedModelPath => _loadedModelPath;
  int get loadedModelSizeBytes => _loadedModelSizeBytes;
  String get runtimeVersion => OrtEnv.version;

  /// Preloads the application's bundled onnxruntime.dll on Windows Desktop.
  ///
  /// CRITICAL WINDOWS 11 FIX:
  /// Windows 11 Germanium ships a stripped-down OS runtime at C:\Windows\System32\onnxruntime.dll
  /// which lacks required quantized operators (e.g. ConvInteger). Calling DynamicLibrary.open()
  /// with the absolute path of the application's full official DLL ensures the process
  /// binds to the correct binary before onnxruntime's lazy loader triggers.
  static void preloadNativeLibrary() {
    if (_dllPreloaded) return;
    if (Platform.isWindows) {
      final candidates = [
        File('onnxruntime.dll'),
        File('windows/flutter/ephemeral/.plugin_symlinks/onnxruntime/windows/onnxruntime.dll'),
        File('${Platform.resolvedExecutable}/../onnxruntime.dll'),
      ];
      for (final file in candidates) {
        if (file.existsSync()) {
          try {
            ffi.DynamicLibrary.open(file.absolute.path);
            _dllPreloaded = true;
            debugPrint('[SentinelX Native ONNX] Preloaded official DLL from: ${file.absolute.path}');
            break;
          } catch (e) {
            debugPrint('[SentinelX Native ONNX] DLL preload probe warning: $e');
          }
        }
      }
    }
    _dllPreloaded = true;
  }

  /// Initializes the OrtEnv runtime environment. Safe to call multiple times.
  static void ensureEnvInitialized() {
    if (!_envInitialized) {
      preloadNativeLibrary();
      OrtEnv.instance.init();
      _envInitialized = true;
      debugPrint('[SentinelX Native ONNX] OrtEnv initialized. Version: ${OrtEnv.version}');
    }
  }

  /// Lists available hardware execution providers reported by native runtime.
  List<String> getAvailableProviders() {
    ensureEnvInitialized();
    try {
      return OrtEnv.instance.availableProviders().map((p) => p.name).toList();
    } catch (_) {
      return ['cpu'];
    }
  }

  /// Loads the multimodal ONNX model from Flutter assets or local filesystem.
  /// Uses in-memory buffer loading (fromBuffer) to guarantee cross-platform
  /// compatibility and prevent Windows UTF-8/UTF-16 file path mismatch issues.
  Future<bool> initializeSession({
    String assetPath = 'assets/models/sentinelx_model.onnx',
    int numThreads = 4,
  }) async {
    try {
      ensureEnvInitialized();

      // Clean up any existing session
      disposeSession();

      // 1. Configure session options
      _sessionOptions = OrtSessionOptions()
        ..setIntraOpNumThreads(numThreads)
        ..setInterOpNumThreads(2)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

      // 2. Load model binary bytes into memory
      Uint8List modelBytes;
      if (assetPath.startsWith('assets/')) {
        final byteData = await rootBundle.load(assetPath);
        modelBytes = byteData.buffer.asUint8List();
      } else {
        final file = File(assetPath);
        if (!file.existsSync()) {
          debugPrint('[SentinelX Native ONNX] Model file not found at: $assetPath');
          return false;
        }
        modelBytes = await file.readAsBytes();
      }

      _loadedModelSizeBytes = modelBytes.length;
      _loadedModelPath = assetPath;

      // 3. Create native OrtSession from memory buffer
      _session = OrtSession.fromBuffer(modelBytes, _sessionOptions!);
      _isSessionReady = true;

      debugPrint(
        '[SentinelX Native ONNX] OrtSession ready. Inputs: ${_session!.inputNames}, '
        'Outputs: ${_session!.outputNames}',
      );
      return true;
    } catch (e, stack) {
      debugPrint('[SentinelX Native ONNX] Session initialization failed: $e\n$stack');
      disposeSession();
      return false;
    }
  }

  /// Executes inference on raw multimodal Float32 input buffers.
  ///
  /// Video shape: `[1, 16, 3, 224, 224]` (Float32, length: 2,408,448)
  /// Audio shape: `[1, 1, 128, 128]` (Float32, length: 16,384)
  Future<NativeInferenceOutput> executeInference({
    required Float32List videoFrames,
    required Float32List audioSpectrogram,
    bool isSynthetic = false,
  }) async {
    if (!isReady) {
      throw StateError('Native ONNX session is not initialized.');
    }

    // Allocate native tensors
    final videoTensor = OrtValueTensor.createTensorWithDataList(
      videoFrames,
      [1, 16, 3, 224, 224],
    );
    final audioTensor = OrtValueTensor.createTensorWithDataList(
      audioSpectrogram,
      [1, 1, 128, 128],
    );

    final runOptions = OrtRunOptions();
    final inputs = {
      'video_frames': videoTensor,
      'audio_spectrogram': audioTensor,
    };

    List<OrtValue?>? outputs;
    final sw = Stopwatch()..start();

    try {
      outputs = _session!.run(runOptions, inputs);
      sw.stop();
      final latencyMs = sw.elapsedMilliseconds;

      // Parse output 0: threat_probabilities [1, 5]
      final rawProbs = outputs[0]?.value as List;
      final probList = (rawProbs[0] as List).map((e) => (e as num).toDouble()).toList();

      // Parse output 1: bounding_boxes [1, 4]
      final rawBbox = outputs[1]?.value as List;
      final bboxList = (rawBbox[0] as List).map((e) => (e as num).toDouble()).toList();

      // Find top predicted class
      int topIndex = 0;
      double topProb = -1.0;
      for (int i = 0; i < probList.length; i++) {
        if (probList[i] > topProb) {
          topProb = probList[i];
          topIndex = i;
        }
      }
      final predictedLabel = (topIndex < NativeInferenceOutput.classLabels.length)
          ? NativeInferenceOutput.classLabels[topIndex]
          : 'Unknown';

      return NativeInferenceOutput(
        threatProbabilities: probList,
        boundingBox: bboxList,
        predictedClass: predictedLabel,
        confidence: topProb,
        latencyMs: latencyMs,
        executedAt: DateTime.now(),
        isSynthetic: isSynthetic,
        diagnosticNotice: isSynthetic ? 'SYNTHETIC TEST INPUT — NOT LIVE DETECTION' : '',
      );
    } finally {
      videoTensor.release();
      audioTensor.release();
      runOptions.release();
      if (outputs != null) {
        for (final o in outputs) {
          o?.release();
        }
      }
    }
  }

  /// Runs consecutive native inference passes using deterministic synthetic test tensors.
  ///
  /// Guaranteed Safety:
  /// Labels result as "SYNTHETIC TEST INPUT — NOT LIVE DETECTION".
  /// Never dispatches or writes to MongoDB.
  Future<NativeBenchmarkResult> runBenchmark({int passes = 3}) async {
    if (!isReady) {
      final ok = await initializeSession();
      if (!ok) {
        throw StateError('Failed to initialize native ONNX session for benchmark.');
      }
    }

    // 1. Generate deterministic synthetic video tensor [1, 16, 3, 224, 224]
    final videoElements = 1 * 16 * 3 * 224 * 224;
    final videoData = Float32List(videoElements);
    for (int i = 0; i < videoElements; i++) {
      videoData[i] = sin(i * 0.01) * 0.5 + 0.5;
    }

    // 2. Generate deterministic calibrated audio spectrogram [1, 1, 128, 128]
    final audioElements = 1 * 1 * 128 * 128;
    final audioData = Float32List(audioElements);
    for (int i = 0; i < audioElements; i++) {
      audioData[i] = -80.0 + sin(i * 0.05) * 5.0;
    }

    final latencies = <int>[];
    NativeInferenceOutput? lastOutput;

    for (int i = 0; i < passes; i++) {
      lastOutput = await executeInference(
        videoFrames: videoData,
        audioSpectrogram: audioData,
        isSynthetic: true,
      );
      latencies.add(lastOutput.latencyMs);
    }

    final sum = latencies.reduce((a, b) => a + b);
    final avg = sum / latencies.length;
    final min = latencies.reduce(minOf).toDouble();
    final max = latencies.reduce(maxOf).toDouble();
    final fps = avg > 0 ? (1000.0 / avg) : 0.0;

    return NativeBenchmarkResult(
      runtimeVersion: OrtEnv.version,
      executionProvider: 'CPUExecutionProvider (Native AVX2/Multi-Threaded)',
      individualLatenciesMs: latencies,
      averageLatencyMs: avg,
      minLatencyMs: min,
      maxLatencyMs: max,
      throughputFps: fps,
      sampleOutput: lastOutput!,
      diagnosticLabel: 'SYNTHETIC TEST INPUT — NOT LIVE DETECTION',
      tensorShapes: const {
        'video_frames': [1, 16, 3, 224, 224],
        'audio_spectrogram': [1, 1, 128, 128],
        'threat_probabilities': [1, 5],
        'bounding_boxes': [1, 4],
      },
    );
  }

  void disposeSession() {
    _session?.release();
    _session = null;
    _sessionOptions?.release();
    _sessionOptions = null;
    _isSessionReady = false;
    _loadedModelPath = null;
    _loadedModelSizeBytes = 0;
  }

  void disposeAll() {
    disposeSession();
    if (_envInitialized) {
      OrtEnv.instance.release();
      _envInitialized = false;
    }
  }

  static int minOf(int a, int b) => a < b ? a : b;
  static int maxOf(int a, int b) => a > b ? a : b;
}

final onnxNativeBridgeProvider = Provider<OnnxNativeBridge>((ref) {
  final bridge = OnnxNativeBridge();
  ref.onDispose(() => bridge.disposeSession());
  return bridge;
});

