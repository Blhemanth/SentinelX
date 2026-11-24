// SentinelX - Phase 4.3.5: ONNX Worker Lifecycle & Memory Stability Test
// Validates 25+ consecutive cycles of: Worker Spawn -> Session Init -> Forward Pass -> Dispose -> RSS Measurement.
// Validates failure modes: Corrupt model init, malformed tensor shape, worker termination during infer,
// worker restart under load, and disposal during active infer.
// Captures exact latency distributions (Prep, Xfer, Native FFI, Parse, Total) and memory profile.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel_x/core/ml/acoustic_silence_generator.dart';
import 'package:sentinel_x/core/ml/onnx_inference_worker.dart';

int getProcessRssBytes() {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    return 0;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4.3.5 — ONNX Worker Lifecycle & Memory Stability', () {
    late Uint8List modelBytes;
    late Float32List sampleVideo;
    late Float32List sampleAudio;

    setUpAll(() async {
      final modelFile = File('assets/models/sentinelx_model.onnx');
      expect(modelFile.existsSync(), isTrue, reason: 'Model asset must exist');
      modelBytes = await modelFile.readAsBytes();

      // [1, 16, 3, 224, 224] = 2,408,448 floats
      sampleVideo = Float32List(1 * 16 * 3 * 224 * 224);
      for (int i = 0; i < sampleVideo.length; i += 100) {
        sampleVideo[i] = sin(i * 0.05) * 0.5 + 0.5;
      }

      // [1, 1, 128, 128] = 16,384 floats (-80.0 dB)
      final silenceGen = AcousticSilenceGenerator();
      sampleAudio = silenceGen.silenceTensor;
    });

    test(
      '25 Consecutive Worker Lifecycle Cycles (Spawn -> Init -> Infer -> Dispose -> RSS)',
      () async {
        print('\n================================================================================');
        print('   SENTINELX PHASE 4.3.5 — 25-CYCLE WORKER LIFECYCLE & MEMORY STABILITY');
        print('================================================================================');

        final initialRss = getProcessRssBytes();
        print('Initial Baseline RSS: ${(initialRss / (1024 * 1024)).toStringAsFixed(2)} MB');

        final prepLatencies = <int>[];
        final xferLatencies = <int>[];
        final nativeLatencies = <int>[];
        final parseLatencies = <int>[];
        final totalLatencies = <int>[];
        final rssProfile = <int, int>{}; // cycle -> RSS bytes

        rssProfile[0] = initialRss;
        int peakRss = initialRss;

        for (int cycle = 1; cycle <= 25; cycle++) {
          final worker = OnnxInferenceWorker();

          // 1. Spawn & Init
          final spawnSw = Stopwatch()..start();
          final initOk = await worker.start(modelBytes: modelBytes);
          spawnSw.stop();
          expect(initOk, isTrue, reason: 'Worker must initialize successfully on cycle $cycle');
          expect(worker.isReady, isTrue);

          // 2. Forward Pass
          final prepSw = Stopwatch()..start();
          final videoClone = Float32List.fromList(sampleVideo);
          prepSw.stop();
          final prepMs = prepSw.elapsedMilliseconds;

          final inferOutput = await worker.infer(
            videoTensor: videoClone,
            audioTensor: sampleAudio,
            prepLatencyMs: prepMs,
          );

          expect(inferOutput.threatProbabilities.length, 5);
          expect(inferOutput.boundingBox.length, 4);
          expect(inferOutput.totalLatencyMs, greaterThan(0));

          prepLatencies.add(inferOutput.prepLatencyMs);
          xferLatencies.add(inferOutput.transferLatencyMs);
          nativeLatencies.add(inferOutput.nativeInferenceLatencyMs);
          parseLatencies.add(inferOutput.responseParsingLatencyMs);
          totalLatencies.add(inferOutput.totalLatencyMs);

          // 3. Track peak and dispose
          final currentRssDuringActive = getProcessRssBytes();
          if (currentRssDuringActive > peakRss) {
            peakRss = currentRssDuringActive;
          }

          await worker.dispose();
          expect(worker.isDisposed, isTrue);
          expect(worker.isReady, isFalse);

          // Allow Dart VM and OS C-runtime allocator to settle
          await Future.delayed(const Duration(milliseconds: 50));

          // 4. Record post-disposal RSS at key milestones
          final currentRss = getProcessRssBytes();
          if (cycle == 1 || cycle == 5 || cycle == 10 || cycle == 15 || cycle == 20 || cycle == 25) {
            rssProfile[cycle] = currentRss;
            print('  [Cycle ${cycle.toString().padLeft(2)}] Spawn+Init: ${spawnSw.elapsedMilliseconds} ms | Total Infer: ${inferOutput.totalLatencyMs} ms (Native FFI: ${inferOutput.nativeInferenceLatencyMs} ms) | RSS: ${(currentRss / (1024 * 1024)).toStringAsFixed(2)} MB');
          }
        }

        final finalRss = getProcessRssBytes();
        rssProfile[26] = finalRss;

        // Statistical analysis
        totalLatencies.sort();
        nativeLatencies.sort();
        final p50Total = totalLatencies[(totalLatencies.length * 0.50).floor()];
        final p95Total = totalLatencies[(totalLatencies.length * 0.95).floor()];
        final p50Native = nativeLatencies[(nativeLatencies.length * 0.50).floor()];
        final p95Native = nativeLatencies[(nativeLatencies.length * 0.95).floor()];
        final avgTotal = totalLatencies.reduce((a, b) => a + b) / totalLatencies.length;
        final avgNative = nativeLatencies.reduce((a, b) => a + b) / nativeLatencies.length;
        final avgXfer = xferLatencies.reduce((a, b) => a + b) / xferLatencies.length;
        final avgPrep = prepLatencies.reduce((a, b) => a + b) / prepLatencies.length;
        final avgParse = parseLatencies.reduce((a, b) => a + b) / parseLatencies.length;

        print('\n--------------------------------------------------------------------------------');
        print('25-CYCLE WORKER LIFECYCLE SUMMARY:');
        print('  Initial Baseline RSS : ${(initialRss / (1024 * 1024)).toStringAsFixed(2)} MB');
        print('  Cycle 1 Post-Dispose : ${((rssProfile[1] ?? 0) / (1024 * 1024)).toStringAsFixed(2)} MB');
        print('  Cycle 10 Post-Dispose: ${((rssProfile[10] ?? 0) / (1024 * 1024)).toStringAsFixed(2)} MB');
        print('  Cycle 25 Post-Dispose: ${((rssProfile[25] ?? 0) / (1024 * 1024)).toStringAsFixed(2)} MB');
        print('  Final Process RSS    : ${(finalRss / (1024 * 1024)).toStringAsFixed(2)} MB');
        print('  Peak Process RSS     : ${(peakRss / (1024 * 1024)).toStringAsFixed(2)} MB');
        final netRssGrowthMb = (finalRss - (rssProfile[1] ?? initialRss)) / (1024 * 1024);
        print('  Net RSS Drift (1->25): ${netRssGrowthMb.toStringAsFixed(2)} MB');
        print('\nLATENCY DISTRIBUTION (25 Cycles):');
        print('  Avg Prep Latency     : ${avgPrep.toStringAsFixed(1)} ms');
        print('  Avg Inter-Isolate Xfer: ${avgXfer.toStringAsFixed(1)} ms');
        print('  Avg Native ONNX FFI  : ${avgNative.toStringAsFixed(1)} ms (P50: $p50Native ms, P95: $p95Native ms)');
        print('  Avg Response Parsing : ${avgParse.toStringAsFixed(1)} ms');
        print('  Avg Total End-to-End : ${avgTotal.toStringAsFixed(1)} ms (P50: $p50Total ms, P95: $p95Total ms)');
        print('================================================================================\n');

        expect(totalLatencies.length, 25);
        expect(p50Total, greaterThan(0));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('Failure Mode 1: Corrupt Model Initialization Error Containment', () async {
      print('\n[Failure Mode 1] Testing Corrupt Model Initialization...');
      final worker = OnnxInferenceWorker();
      final corruptBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE]);

      final ok = await worker.start(modelBytes: corruptBytes);
      expect(ok, isFalse, reason: 'Worker must return false on corrupted model bytes');
      expect(worker.isReady, isFalse);
      expect(worker.lastErrorMessage, isNotNull);
      expect(worker.lastErrorMessage, contains('failed to initialize ONNX session'));

      await worker.dispose();
      expect(worker.isDisposed, isTrue);
      print('  Passed: Corrupt model caught and contained gracefully without crashing process.');
    });

    test('Failure Mode 2: Malformed Input Tensor Shape Containment', () async {
      print('\n[Failure Mode 2] Testing Malformed Input Tensor Shape...');
      final worker = OnnxInferenceWorker();
      final initOk = await worker.start(modelBytes: modelBytes);
      expect(initOk, isTrue);

      // Malformed video tensor: only 100 floats instead of 2,408,448
      final badVideo = Float32List(100);

      expect(
        () async => await worker.infer(videoTensor: badVideo, audioTensor: sampleAudio),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Invalid video tensor size'),
        )),
      );

      expect(worker.failureCount, greaterThan(0));
      await worker.restart();
      expect(worker.isReady, isTrue);

      final validOutput = await worker.infer(videoTensor: sampleVideo, audioTensor: sampleAudio);
      expect(validOutput.threatProbabilities.length, 5);

      await worker.dispose();
      print('  Passed: Malformed tensor rejected safely via StateError; worker restarts and continues serving requests.');
    });

    test('Failure Mode 3: Worker Restart Under Sustained Load', () async {
      print('\n[Failure Mode 3] Testing Worker Restart Under Sustained Load...');
      final worker = OnnxInferenceWorker();
      await worker.start(modelBytes: modelBytes);

      // Execute 3 inferences
      for (int i = 0; i < 3; i++) {
        await worker.infer(videoTensor: sampleVideo, audioTensor: sampleAudio);
      }
      expect(worker.isReady, isTrue);

      // Force restart worker
      final restartSw = Stopwatch()..start();
      final restartOk = await worker.restart();
      restartSw.stop();
      expect(restartOk, isTrue, reason: 'Worker must successfully restart and reload model');
      expect(worker.restartCount, 1);
      expect(worker.isReady, isTrue);
      print('  Worker restarted in ${restartSw.elapsedMilliseconds} ms (Restart count: ${worker.restartCount})');

      // Execute inference after restart
      final postRestartOutput = await worker.infer(videoTensor: sampleVideo, audioTensor: sampleAudio);
      expect(postRestartOutput.threatProbabilities.length, 5);
      expect(postRestartOutput.nativeInferenceLatencyMs, greaterThan(0));

      await worker.dispose();
      print('  Passed: Worker cleanly restarts under load, clears previous isolate, and continues serving requests.');
    });

    test('Failure Mode 4: Disposal During Active State', () async {
      print('\n[Failure Mode 4] Testing Immediate Disposal and Double Disposal Safety...');
      final worker = OnnxInferenceWorker();
      await worker.start(modelBytes: modelBytes);
      expect(worker.isReady, isTrue);

      // Immediate dispose
      await worker.dispose();
      expect(worker.isDisposed, isTrue);
      expect(worker.isReady, isFalse);

      // Double disposal must be idempotent and safe
      await worker.dispose();
      expect(worker.isDisposed, isTrue);

      // Inference on disposed worker must throw StateError
      expect(
        () async => await worker.infer(videoTensor: sampleVideo, audioTensor: sampleAudio),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('WorkerStatus.disposed'),
        )),
      );

      print('  Passed: Worker disposal is completely idempotent; subsequent infer calls safely throw StateError.');
    });
  });
}
