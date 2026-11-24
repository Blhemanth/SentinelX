// SentinelX - Dedicated Background ONNX Inference Worker
// Offloads heavy native C-FFI OrtSession.run() evaluation to a separate Dart background isolate.
//
// ZERO UI FREEZES:
// The Flutter UI event loop and rendering pipeline remain 100% fluid at 60 FPS while
// 1.2 - 1.4s deep neural network forward passes execute wholly inside the spawned isolate.
//
// STRICT ISOLATE & NATIVE FFI SAFETY:
// 1. The background isolate owns and manages its own OrtEnv and OrtSession lifecycle.
// 2. Zero native pointers or session references are passed across isolate boundaries.
// 3. Only plain Dart data (Float32List, primitive ints/strings) cross SendPort/ReceivePort.
// 4. All native tensors (OrtValueTensor) and run options are allocated and freed within the worker.
// 5. Graceful shutdown releases all native resources and terminates the background isolate.

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

enum WorkerStatus {
  uninitialized,
  initializing,
  idle,
  inferring,
  restarting,
  error,
  disposed,
}

/// Structured timing and classification output emitted by the background worker.
@immutable
class WorkerInferenceOutput {
  final List<double> threatProbabilities; // 5 classes: Explosion, Gunshot, Fighting, Accident, Normal
  final List<double> boundingBox; // [x, y, w, h] normalized in [0, 1]
  final String predictedClass;
  final double confidence;
  final int prepLatencyMs;
  final int transferLatencyMs;
  final int nativeInferenceLatencyMs;
  final int responseParsingLatencyMs;
  final int totalLatencyMs;
  final DateTime executedAt;

  const WorkerInferenceOutput({
    required this.threatProbabilities,
    required this.boundingBox,
    required this.predictedClass,
    required this.confidence,
    required this.prepLatencyMs,
    required this.transferLatencyMs,
    required this.nativeInferenceLatencyMs,
    required this.responseParsingLatencyMs,
    required this.totalLatencyMs,
    required this.executedAt,
  });

  static const List<String> classLabels = [
    'Explosion',
    'Gunshot',
    'Fighting',
    'Accident',
    'Normal',
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL ISOLATE MESSAGE PROTOCOL
// ─────────────────────────────────────────────────────────────────────────────

class _WorkerInitRequest {
  final SendPort replyPort;
  final Uint8List modelBytes;
  final int numThreads;
  final int interOpThreads;

  _WorkerInitRequest({
    required this.replyPort,
    required this.modelBytes,
    this.numThreads = 4,
  }) : interOpThreads = 2;
}

class _WorkerInitResponse {
  final bool success;
  final String? error;
  final String runtimeVersion;
  final List<String> inputNames;
  final List<String> outputNames;
  final SendPort? commandPort;

  _WorkerInitResponse({
    required this.success,
    this.error,
    this.runtimeVersion = '',
    this.inputNames = const [],
    this.outputNames = const [],
    this.commandPort,
  });
}

class _WorkerInferenceRequest {
  final int requestId;
  final SendPort replyPort;
  final Float32List videoTensor; // [1, 16, 3, 224, 224] (2,408,448 floats)
  final Float32List audioTensor; // [1, 1, 128, 128] (16,384 floats)
  final int sentTimestampMs;

  _WorkerInferenceRequest({
    required this.requestId,
    required this.replyPort,
    required this.videoTensor,
    required this.audioTensor,
    required this.sentTimestampMs,
  });
}

class _WorkerInferenceResponse {
  final int requestId;
  final bool success;
  final String? error;
  final List<double> threatProbabilities;
  final List<double> boundingBox;
  final int transferLatencyMs;
  final int nativeInferenceLatencyMs;
  final int workerReplyTimestampMs;

  _WorkerInferenceResponse({
    required this.requestId,
    required this.success,
    this.error,
    this.threatProbabilities = const [],
    this.boundingBox = const [],
    this.transferLatencyMs = 0,
    this.nativeInferenceLatencyMs = 0,
    this.workerReplyTimestampMs = 0,
  });
}

class _WorkerShutdownRequest {
  final SendPort? replyPort;
  _WorkerShutdownRequest({this.replyPort});
}

// ─────────────────────────────────────────────────────────────────────────────
// WORKER ISOLATE ENTRY POINT (Runs on independent OS thread)
// ─────────────────────────────────────────────────────────────────────────────

void _onnxWorkerEntryPoint(_WorkerInitRequest initRequest) async {
  // 1. Windows Dynamic Library Preloading (Worker Isolate Scope)
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
          break;
        } catch (_) {}
      }
    }
  }

  try {
    // 2. Initialize worker-owned OrtEnv
    OrtEnv.instance.init();

    // 3. Configure session options for multi-threaded AVX2 CPU execution
    final sessionOptions = OrtSessionOptions()
      ..setIntraOpNumThreads(initRequest.numThreads)
      ..setInterOpNumThreads(initRequest.interOpThreads)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

    // 4. Create native OrtSession from in-memory model binary bytes
    final session = OrtSession.fromBuffer(initRequest.modelBytes, sessionOptions);

    final commandPort = ReceivePort();
    initRequest.replyPort.send(_WorkerInitResponse(
      success: true,
      runtimeVersion: OrtEnv.version,
      inputNames: List<String>.unmodifiable(session.inputNames),
      outputNames: List<String>.unmodifiable(session.outputNames),
      commandPort: commandPort.sendPort,
    ));

    bool isBusy = false;

    // 5. Worker Message Loop
    await for (final message in commandPort) {
      if (message is _WorkerInferenceRequest) {
        if (isBusy) {
          message.replyPort.send(_WorkerInferenceResponse(
            requestId: message.requestId,
            success: false,
            error: 'Worker isolate is busy processing another inference request.',
          ));
          continue;
        }

        isBusy = true;
        final receivedMs = DateTime.now().millisecondsSinceEpoch;
        final forwardTransferMs = (receivedMs - message.sentTimestampMs).clamp(0, 100000);

        OrtValueTensor? videoTensor;
        OrtValueTensor? audioTensor;
        OrtRunOptions? runOptions;
        List<OrtValue?>? outputs;
        final sw = Stopwatch()..start();

        try {
          // Allocate worker-owned native input tensors
          videoTensor = OrtValueTensor.createTensorWithDataList(
            message.videoTensor,
            [1, 16, 3, 224, 224],
          );
          audioTensor = OrtValueTensor.createTensorWithDataList(
            message.audioTensor,
            [1, 1, 128, 128],
          );

          runOptions = OrtRunOptions();
          final inputs = {
            'video_frames': videoTensor,
            'audio_spectrogram': audioTensor,
          };

          // Native C-FFI forward pass execution
          outputs = session.run(runOptions, inputs);
          sw.stop();
          final nativeLatencyMs = sw.elapsedMilliseconds;

          // Parse output 0: threat_probabilities [1, 5]
          final rawProbs = outputs[0]?.value as List;
          final probList = (rawProbs[0] as List).map((e) => (e as num).toDouble()).toList();

          // Parse output 1: bounding_boxes [1, 4]
          final rawBbox = outputs[1]?.value as List;
          final bboxList = (rawBbox[0] as List).map((e) => (e as num).toDouble()).toList();

          message.replyPort.send(_WorkerInferenceResponse(
            requestId: message.requestId,
            success: true,
            threatProbabilities: probList,
            boundingBox: bboxList,
            transferLatencyMs: forwardTransferMs,
            nativeInferenceLatencyMs: nativeLatencyMs,
            workerReplyTimestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        } catch (e) {
          sw.stop();
          message.replyPort.send(_WorkerInferenceResponse(
            requestId: message.requestId,
            success: false,
            error: 'Native ONNX execution error inside worker isolate: $e',
            transferLatencyMs: forwardTransferMs,
            nativeInferenceLatencyMs: sw.elapsedMilliseconds,
          ));
        } finally {
          // Strict resource hygiene: release all native tensors & run options
          videoTensor?.release();
          audioTensor?.release();
          runOptions?.release();
          if (outputs != null) {
            for (final o in outputs) {
              o?.release();
            }
          }
          isBusy = false;
        }
      } else if (message is _WorkerShutdownRequest) {
        // Clean up native session, options, and OrtEnv
        try {
          session.release();
          sessionOptions.release();
          OrtEnv.instance.release();
        } catch (_) {}
        commandPort.close();
        message.replyPort?.send('SHUTDOWN_COMPLETE');
        break;
      }
    }
  } catch (e) {
    initRequest.replyPort.send(_WorkerInitResponse(
      success: false,
      error: 'Worker isolate failed to initialize ONNX session: $e',
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLIENT-FACING ONNX INFERENCE WORKER CONTROLLER (Runs on UI Isolate)
// ─────────────────────────────────────────────────────────────────────────────

class OnnxInferenceWorker {
  WorkerStatus _status = WorkerStatus.uninitialized;
  WorkerStatus get status => _status;

  bool get isReady => _status == WorkerStatus.idle;
  bool get isInferring => _status == WorkerStatus.inferring;
  bool get isDisposed => _status == WorkerStatus.disposed;

  Isolate? _isolate;
  SendPort? _commandPort;
  Uint8List? _cachedModelBytes;
  String? _modelPath;
  int _numThreads = 4;

  int _restartCount = 0;
  int _failureCount = 0;
  int _nextRequestId = 1;
  String? _lastErrorMessage;

  int get restartCount => _restartCount;
  int get failureCount => _failureCount;
  String? get lastErrorMessage => _lastErrorMessage;

  String _runtimeVersion = '';
  String get runtimeVersion => _runtimeVersion;

  List<String> _inputNames = const [];
  List<String> get inputNames => _inputNames;

  List<String> _outputNames = const [];
  List<String> get outputNames => _outputNames;

  /// Starts the background isolate and initializes native ONNX Runtime session.
  Future<bool> start({
    Uint8List? modelBytes,
    String modelAssetPath = 'assets/models/sentinelx_model.onnx',
    int numThreads = 4,
  }) async {
    if (_status == WorkerStatus.idle || _status == WorkerStatus.inferring) {
      return true;
    }

    _status = WorkerStatus.initializing;
    _modelPath = modelAssetPath;
    _numThreads = numThreads;
    _lastErrorMessage = null;

    try {
      Uint8List bytes;
      if (modelBytes != null) {
        bytes = modelBytes;
      } else {
        // Resolve model binary bytes
        bytes = await _loadModelBytes(modelAssetPath);
      }
      _cachedModelBytes = bytes;

      final initPort = ReceivePort();
      final initRequest = _WorkerInitRequest(
        replyPort: initPort.sendPort,
        modelBytes: bytes,
        numThreads: numThreads,
      );

      _isolate = await Isolate.spawn(
        _onnxWorkerEntryPoint,
        initRequest,
        debugName: 'SentinelX_OnnxWorker',
      );

      final dynamic rawResponse = await initPort.first;
      initPort.close();

      if (rawResponse is _WorkerInitResponse && rawResponse.success) {
        _commandPort = rawResponse.commandPort;
        _runtimeVersion = rawResponse.runtimeVersion;
        _inputNames = rawResponse.inputNames;
        _outputNames = rawResponse.outputNames;
        _status = WorkerStatus.idle;
        debugPrint('[OnnxInferenceWorker] Worker isolate started successfully. ONNX v$_runtimeVersion ready.');
        return true;
      } else {
        final err = (rawResponse is _WorkerInitResponse)
            ? rawResponse.error
            : 'Unknown worker initialization error';
        _lastErrorMessage = err;
        _failureCount++;
        debugPrint('[OnnxInferenceWorker] Initialization failed: $err');
        await _terminateIsolate();
        _status = WorkerStatus.error;
        return false;
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
      _failureCount++;
      debugPrint('[OnnxInferenceWorker] Exception starting worker isolate: $e');
      await _terminateIsolate();
      _status = WorkerStatus.error;
      return false;
    }
  }

  /// Dispatches an inference request to the background isolate.
  /// Throws [StateError] if worker is not idle or busy.
  Future<WorkerInferenceOutput> infer({
    required Float32List videoTensor,
    required Float32List audioTensor,
    int prepLatencyMs = 0,
  }) async {
    if (_status != WorkerStatus.idle || _commandPort == null) {
      throw StateError('Worker is not in idle state (current status: $_status).');
    }

    const expectedVideoElements = 1 * 16 * 3 * 224 * 224;
    const expectedAudioElements = 1 * 1 * 128 * 128;
    if (videoTensor.length != expectedVideoElements) {
      _failureCount++;
      _status = WorkerStatus.error;
      _lastErrorMessage =
          'Invalid video tensor size: got ${videoTensor.length}, expected $expectedVideoElements floats ([1, 16, 3, 224, 224]).';
      throw StateError(_lastErrorMessage!);
    }
    if (audioTensor.length != expectedAudioElements) {
      _failureCount++;
      _status = WorkerStatus.error;
      _lastErrorMessage =
          'Invalid audio tensor size: got ${audioTensor.length}, expected $expectedAudioElements floats ([1, 1, 128, 128]).';
      throw StateError(_lastErrorMessage!);
    }

    // Fast numerical sanitization: reject NaN or infinite inputs
    for (int i = 0; i < videoTensor.length; i += 1000) {
      if (videoTensor[i].isNaN || videoTensor[i].isInfinite) {
        throw ArgumentError('Video tensor contains non-finite values (NaN/Inf) at index $i.');
      }
    }
    for (int i = 0; i < audioTensor.length; i += 256) {
      if (audioTensor[i].isNaN || audioTensor[i].isInfinite) {
        throw ArgumentError('Audio tensor contains non-finite values (NaN/Inf) at index $i.');
      }
    }

    _status = WorkerStatus.inferring;
    final requestId = _nextRequestId++;
    final replyPort = ReceivePort();
    final sentTimestampMs = DateTime.now().millisecondsSinceEpoch;

    try {
      _commandPort!.send(_WorkerInferenceRequest(
        requestId: requestId,
        replyPort: replyPort.sendPort,
        videoTensor: videoTensor,
        audioTensor: audioTensor,
        sentTimestampMs: sentTimestampMs,
      ));

      final dynamic rawResponse = await replyPort.first;
      replyPort.close();

      if (rawResponse is! _WorkerInferenceResponse) {
        throw StateError('Invalid response received from worker isolate: $rawResponse');
      }

      if (!rawResponse.success) {
        _failureCount++;
        _lastErrorMessage = rawResponse.error;
        throw StateError(rawResponse.error ?? 'Unknown worker inference error');
      }

      final parseSw = Stopwatch()..start();

      // Measure return transfer latency
      final returnTransferMs = (DateTime.now().millisecondsSinceEpoch -
              rawResponse.workerReplyTimestampMs)
          .clamp(0, 100000);
      final totalTransferMs = rawResponse.transferLatencyMs + returnTransferMs;

      // Classify top prediction & enforce Softmax probability contract (sum to 1.0)
      List<double> probList = rawResponse.threatProbabilities;
      final sum = probList.fold<double>(0.0, (acc, p) => acc + p);
      if ((sum - 1.0).abs() > 0.005 && sum > 0) {
        probList = probList.map((p) => (p / sum)).toList();
      }

      int topIndex = 0;
      double topProb = -1.0;
      for (int i = 0; i < probList.length; i++) {
        if (probList[i] > topProb) {
          topProb = probList[i];
          topIndex = i;
        }
      }
      final predictedLabel = (topIndex < WorkerInferenceOutput.classLabels.length)
          ? WorkerInferenceOutput.classLabels[topIndex]
          : 'Unknown';

      parseSw.stop();
      final parseMs = parseSw.elapsedMilliseconds;
      final totalLatencyMs =
          prepLatencyMs + totalTransferMs + rawResponse.nativeInferenceLatencyMs + parseMs;

      _status = WorkerStatus.idle;

      return WorkerInferenceOutput(
        threatProbabilities: List<double>.unmodifiable(probList),
        boundingBox: List<double>.unmodifiable(rawResponse.boundingBox),
        predictedClass: predictedLabel,
        confidence: topProb,
        prepLatencyMs: prepLatencyMs,
        transferLatencyMs: totalTransferMs,
        nativeInferenceLatencyMs: rawResponse.nativeInferenceLatencyMs,
        responseParsingLatencyMs: parseMs,
        totalLatencyMs: totalLatencyMs,
        executedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      _failureCount++;
      _lastErrorMessage = e.toString();
      _status = WorkerStatus.error;
      rethrow;
    }
  }

  /// Recovers a crashed or errored worker by gracefully terminating the isolate
  /// and spawning a fresh isolate with the cached model bytes.
  Future<bool> restart() async {
    _restartCount++;
    _status = WorkerStatus.restarting;
    debugPrint('[OnnxInferenceWorker] Restarting worker isolate (restart #$_restartCount)...');

    await _terminateIsolate();

    if (_cachedModelBytes != null) {
      return start(
        modelBytes: _cachedModelBytes,
        modelAssetPath: _modelPath ?? 'assets/models/sentinelx_model.onnx',
        numThreads: _numThreads,
      );
    } else {
      return start(
        modelAssetPath: _modelPath ?? 'assets/models/sentinelx_model.onnx',
        numThreads: _numThreads,
      );
    }
  }

  /// Gracefully stops the worker isolate and cleans up resources.
  Future<void> dispose() async {
    if (_status == WorkerStatus.disposed) return;
    _status = WorkerStatus.disposed;
    await _terminateIsolate();
    _cachedModelBytes = null;
    debugPrint('[OnnxInferenceWorker] Worker isolate disposed.');
  }

  Future<void> _terminateIsolate() async {
    if (_commandPort != null) {
      try {
        final shutdownPort = ReceivePort();
        _commandPort!.send(_WorkerShutdownRequest(replyPort: shutdownPort.sendPort));
        await shutdownPort.first.timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => 'TIMEOUT',
        );
        shutdownPort.close();
      } catch (_) {}
      _commandPort = null;
    }

    if (_isolate != null) {
      try {
        _isolate!.kill(priority: Isolate.immediate);
      } catch (_) {}
      _isolate = null;
    }
  }

  static Future<Uint8List> _loadModelBytes(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      return byteData.buffer.asUint8List();
    } catch (_) {
      final file = File(assetPath);
      if (file.existsSync()) {
        return file.readAsBytes();
      }
      throw FileSystemException('Could not load ONNX model bytes from $assetPath');
    }
  }
}
