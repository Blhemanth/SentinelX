// SentinelX - Phase 4.2: Native ONNX Runtime FFI Execution Test Suite
// Verifies genuine in-process execution of assets/models/sentinelx_model.onnx
// on Windows Desktop x64 via onnxruntime C-API bindings.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel_x/services/onnx_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4.2 — Native ONNX Runtime Compatibility & Execution Proof', () {
    late OnnxNativeBridge bridge;

    setUpAll(() {
      OnnxNativeBridge.preloadNativeLibrary();
      bridge = OnnxNativeBridge();
    });

    tearDownAll(() {
      bridge.disposeAll();
    });

    test('Test 1: Native ONNX Runtime environment initializes successfully', () {
      OnnxNativeBridge.ensureEnvInitialized();
      final version = bridge.runtimeVersion;
      print('[Test 1] Native ONNX Runtime Version: $version');
      expect(version, isNotEmpty);

      final providers = bridge.getAvailableProviders();
      print('[Test 1] Available Native Providers: $providers');
      expect(providers, isNotEmpty);
      expect(providers, contains('cpu'));
    });

    test('Test 2: Model asset exists and has valid quantized size', () {
      final modelFile = File('assets/models/sentinelx_model.onnx');
      expect(modelFile.existsSync(), isTrue, reason: 'assets/models/sentinelx_model.onnx must exist');
      
      final size = modelFile.lengthSync();
      print('[Test 2] Model File Size: $size bytes (~${(size / (1024 * 1024)).toStringAsFixed(2)} MB)');
      expect(size, greaterThan(15 * 1024 * 1024), reason: 'Model should be ~19.4 MB');
      expect(size, lessThan(30 * 1024 * 1024));
    });

    test('Test 3: OrtSession initializes from memory buffer with correct tensor signatures', () async {
      final success = await bridge.initializeSession(
        assetPath: 'assets/models/sentinelx_model.onnx',
        numThreads: 4,
      );
      expect(success, isTrue, reason: 'Session must load cleanly from buffer');
      expect(bridge.isReady, isTrue);
      expect(bridge.loadedModelSizeBytes, greaterThan(0));
      print('[Test 3] Session initialized. Buffer size: ${bridge.loadedModelSizeBytes} bytes');
    });

    test('Test 4: Single-pass native inference executes with deterministic synthetic tensors', () async {
      // 1. Synthetic video tensor [1, 16, 3, 224, 224] Float32
      final videoElements = 1 * 16 * 3 * 224 * 224;
      final videoData = Float32List(videoElements);
      for (int i = 0; i < videoElements; i++) {
        videoData[i] = sin(i * 0.01) * 0.5 + 0.5;
      }

      // 2. Synthetic audio tensor [1, 1, 128, 128] Float32
      final audioElements = 1 * 1 * 128 * 128;
      final audioData = Float32List(audioElements);
      for (int i = 0; i < audioElements; i++) {
        audioData[i] = -80.0 + sin(i * 0.05) * 5.0;
      }

      final output = await bridge.executeInference(
        videoFrames: videoData,
        audioSpectrogram: audioData,
        isSynthetic: true,
      );

      print('[Test 4] Inference Completed in ${output.latencyMs} ms');
      print('[Test 4] Predicted Class: ${output.predictedClass} (confidence: ${(output.confidence * 100).toStringAsFixed(2)}%)');
      print('[Test 4] Threat Probabilities [1, 5]: ${output.threatProbabilities}');
      print('[Test 4] Bounding Box [1, 4]: ${output.boundingBox}');

      // Validate threat probabilities
      expect(output.threatProbabilities.length, equals(5));
      for (final prob in output.threatProbabilities) {
        expect(prob.isFinite, isTrue);
        expect(prob, greaterThanOrEqualTo(0.0));
        expect(prob, lessThanOrEqualTo(1.01)); // Softmax sum ~ 1.0
      }

      // Validate bounding box
      expect(output.boundingBox.length, equals(4));
      for (final coord in output.boundingBox) {
        expect(coord.isFinite, isTrue);
      }

      // Validate latency is realistic for genuine deep learning inference (>100 ms on CPU)
      expect(output.latencyMs, greaterThan(100), reason: 'Real 19.4 MB INT8 inference takes >100ms on CPU');

      // Safety check: Synthetic flag and diagnostic notice
      expect(output.isSynthetic, isTrue);
      expect(output.diagnosticNotice, equals('SYNTHETIC TEST INPUT — NOT LIVE DETECTION'));
    });

    test('Test 5: Multi-pass benchmark measures empirical latency and throughput', () async {
      final benchmark = await bridge.runBenchmark(passes: 3);

      print('[Test 5] Benchmark Summary:');
      print('  Runtime Version: ${benchmark.runtimeVersion}');
      print('  Execution Provider: ${benchmark.executionProvider}');
      print('  Pass Latencies: ${benchmark.individualLatenciesMs.map((l) => '$l ms').join(', ')}');
      print('  Average Latency: ${benchmark.averageLatencyMs.toStringAsFixed(1)} ms');
      print('  Min Latency: ${benchmark.minLatencyMs.toInt()} ms');
      print('  Max Latency: ${benchmark.maxLatencyMs.toInt()} ms');
      print('  Throughput: ${benchmark.throughputFps.toStringAsFixed(2)} FPS');
      print('  Diagnostic Notice: ${benchmark.diagnosticLabel}');

      expect(benchmark.individualLatenciesMs.length, equals(3));
      expect(benchmark.averageLatencyMs, greaterThan(100.0));
      expect(benchmark.throughputFps, greaterThan(0.0));
      expect(benchmark.diagnosticLabel, equals('SYNTHETIC TEST INPUT — NOT LIVE DETECTION'));
      expect(benchmark.tensorShapes['video_frames'], equals([1, 16, 3, 224, 224]));
      expect(benchmark.tensorShapes['audio_spectrogram'], equals([1, 1, 128, 128]));
      expect(benchmark.tensorShapes['threat_probabilities'], equals([1, 5]));
      expect(benchmark.tensorShapes['bounding_boxes'], equals([1, 4]));
    });

    test('Test 6: Invalid model path fails gracefully without native crash', () async {
      final dummyBridge = OnnxNativeBridge();
      final ok = await dummyBridge.initializeSession(assetPath: 'nonexistent/model.onnx');
      expect(ok, isFalse);
      expect(dummyBridge.isReady, isFalse);
    });

    test('Test 7: Clean resource disposal releases native session without memory leak', () {
      bridge.disposeSession();
      expect(bridge.isReady, isFalse);
      expect(bridge.loadedModelPath, isNull);
      expect(bridge.loadedModelSizeBytes, equals(0));
    });
  });
}
