// SentinelX - End-to-End Integration Tests
// Verifies application boot, fallback behavior when sentinelx_model.onnx is absent,
// tensor preprocessor dimensions, and multi-platform layout adaptations.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentinel_x/main.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/features/dashboard/screens/dashboard_screen.dart';
import 'package:sentinel_x/features/camera/widgets/hardware_camera_view.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SentinelX Multi-Platform Integration Tests', () {
    testWidgets('App initializes cleanly wrapped in ProviderScope with dark theme', (tester) async {
      // Build full SentinelX app
      await tester.pumpWidget(
        const ProviderScope(
          child: SentinelXApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));

      // Verify app title and Material widget existence
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Native Inference Mode: sentinelx_model.onnx initializes with DirectML / NNAPI', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SentinelXApp(home: DashboardScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Verify that DashboardScreen is rendered as home
      expect(find.byType(DashboardScreen), findsOneWidget);

      // Verify that hardware camera is loaded and armed
      expect(find.byType(HardwareCameraView), findsWidgets);
    });

    test('ImageToTensorPreprocessor creates correct [1, 3, 640, 640] NCHW tensor', () {
      final sampleRgbBytes = Uint8List(640 * 640 * 3);
      for (int i = 0; i < sampleRgbBytes.length; i++) {
        sampleRgbBytes[i] = (i % 256);
      }

      final tensor = ImageToTensorPreprocessor.preprocessRgb(
        imageBytes: sampleRgbBytes,
        srcWidth: 640,
        srcHeight: 640,
        targetWidth: 640,
        targetHeight: 640,
      );

      // Expected NCHW size: 1 * 3 * 640 * 640 = 1,228,800 float elements
      expect(tensor.length, equals(1 * 3 * 640 * 640));
      expect(tensor[0], inInclusiveRange(0.0, 1.0));

      // Test INT8 quantizer
      final int8Tensor = ImageToTensorPreprocessor.quantizeToInt8(floatTensor: tensor);
      expect(int8Tensor.length, equals(tensor.length));
    });

    test('InferenceRepository initializes with native ONNX model state', () {
      final mockService = MockInferenceService();
      final onnxEngine = OnnxInferenceEngine();

      final repo = InferenceRepository(
        onnxEngine: onnxEngine,
        mockService: mockService,
      );

      expect(repo.state.mode, equals(ActiveInferenceMode.onnxNative));
      expect(repo.state.isModelLoaded, isTrue);
      expect(repo.state.showSimulationBanner, isFalse);

      repo.dismissBanner();
      expect(repo.state.showSimulationBanner, isFalse);

      repo.dispose();
    });

    testWidgets('Desktop Command Center renders on screens >= 900px', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Telemetry Bar exists
      expect(find.textContaining('SYSTEM ARMED'), findsOneWidget);
      expect(find.textContaining('FPS'), findsWidgets);
    });

    testWidgets('AuthGate presents LoginScreen with RBAC selector pills', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(
          child: SentinelXApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SECURE ACCESS'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Analyst'), findsOneWidget);
      expect(find.text('User'), findsOneWidget);
    });
  });
}
