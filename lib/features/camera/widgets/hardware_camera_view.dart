// SentinelX - Hardware Camera View
// Connects directly to the physical laptop webcam using the Flutter camera plugin.
// Renders live video preview with graceful fallback to animated canvas when offline.
// Features Cyberpunk surveillance HUD with:
// 1. Live hardware device name and ingestion status
// 2. Continuous real-time ONNX inference telemetry (Inference FPS, Latency, Skipped Cycles)
// 3. Prominent Degraded Mode Indicator (video_only_degraded)
// 4. Viewport canvas-clipped bounding box overlay with target reticle

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/providers/providers.dart';

class HardwareCameraView extends ConsumerStatefulWidget {
  final Widget? fallback;
  final CustomPainter? fallbackPainter;
  final CameraController? controller;
  final CameraIngestionService? ingestionService;
  final ContinuousInferenceScheduler? inferenceScheduler;

  const HardwareCameraView({
    super.key,
    this.fallback,
    this.fallbackPainter,
    this.controller,
    this.ingestionService,
    this.inferenceScheduler,
  });

  @override
  ConsumerState<HardwareCameraView> createState() => _HardwareCameraViewState();
}

class _HardwareCameraViewState extends ConsumerState<HardwareCameraView> {
  CameraController? _internalController;
  CameraIngestionService? _effectiveIngestionService;
  ContinuousInferenceScheduler? _effectiveScheduler;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _useFallback = false;
  String _statusMessage = 'Connecting to Laptop Webcam (CAM-001)...';
  String _deviceName = 'HP TrueVision HD Camera';

  CameraController? get _activeController =>
      widget.controller ??
      widget.ingestionService?.controller ??
      _effectiveIngestionService?.controller ??
      _internalController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initHardwareCamera();
      }
    });
  }

  Future<void> _initHardwareCamera() async {
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Connecting to Laptop Webcam (CAM-001)...';
      _hasError = false;
      _useFallback = false;
    });

    try {
      final CameraIngestionService ingestion =
          widget.ingestionService ?? ref.read(cameraIngestionServiceProvider);
      final ContinuousInferenceScheduler scheduler =
          widget.inferenceScheduler ?? ref.read(continuousInferenceSchedulerProvider);
      _effectiveIngestionService = ingestion;
      _effectiveScheduler = scheduler;

      if (ingestion.controller == null || !ingestion.controller!.value.isInitialized) {
        final initialized = await ingestion.initialize();
        if (!initialized || !mounted) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _statusMessage = ingestion.currentTelemetry.errorMessage ??
                  'Webcam not detected or unavailable.';
            });
          }
          return;
        }
      }

      if (!mounted) return;

      _deviceName = ingestion.deviceName;
      await ingestion.startIngestion();

      if (!scheduler.isReady) {
        await scheduler.initialize();
      }
      if (mounted) {
        scheduler.start();

        // Ensure detection sync service is active
        try {
          ref.read(detectionSyncServiceProvider);
        } catch (_) {}

        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage = 'Webcam access: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _effectiveIngestionService?.pauseIngestion();
    _effectiveScheduler?.pause();
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _activeController;

    // Optional telemetry from Riverpod streams
    final camTelemetry = ref.watch(cameraTelemetryStreamProvider).value;
    final inferenceTelemetry = ref.watch(continuousInferenceTelemetryStreamProvider).value;

    final deviceLabel = camTelemetry?.deviceName ?? _deviceName;
    final camFps = camTelemetry?.measuredFps ?? 0.0;
    final infFps = inferenceTelemetry?.inferenceFps ?? 0.0;
    final infLatency = inferenceTelemetry?.lastLatencyMs ?? 0;
    final nativeLatency = inferenceTelemetry?.nativeLatencyMs ?? 0;
    final skippedCycles = inferenceTelemetry?.skippedCycles ?? 0;
    final restartCount = inferenceTelemetry?.workerRestartCount ?? 0;
    final failureCount = inferenceTelemetry?.failedInferences ?? 0;
    final workerStatus = inferenceTelemetry?.workerStatus.toUpperCase() ?? 'IDLE';
    final isDegraded = inferenceTelemetry?.isDegradedMode ?? true;
    final latestPred = inferenceTelemetry?.latestPrediction;

    if (_isInitialized && controller != null && controller.value.isInitialized) {
      final previewSize = controller.value.previewSize;
      final previewW = previewSize?.width ?? 1280.0;
      final previewH = previewSize?.height ?? 720.0;

      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewW,
                height: previewH,
                child: CameraPreview(controller),
              ),
            ),
          ),

          // Subtle Cyberpunk surveillance filter overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  SentinelColors.bgDarkest.withValues(alpha: 0.20),
                  Colors.transparent,
                  SentinelColors.bgDarkest.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),

          // Top Left HUD: Camera Device Tag & Worker Status Badge
          Positioned(
            top: 10,
            left: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SentinelColors.bgDarkest.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SentinelColors.primary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: camFps > 0 ? SentinelColors.threatLow : SentinelColors.threatMedium,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        camFps > 0
                            ? 'CAM-001 // STREAMING (${camFps.toStringAsFixed(1)} FPS) [$deviceLabel]'
                            : 'CAM-001 // READY [$deviceLabel]',
                        style: SentinelTypography.monoSmall.copyWith(
                          color: SentinelColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SentinelColors.bgDarkest.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SentinelColors.accent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: workerStatus == 'INFERRING'
                              ? SentinelColors.threatHigh
                              : SentinelColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'WORKER: $workerStatus',
                        style: SentinelTypography.monoSmall.copyWith(
                          color: SentinelColors.accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Top Right HUD: Degraded Mode Indicator Pill
          if (isDegraded)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SentinelColors.threatMedium.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SentinelColors.threatMedium.withValues(alpha: 0.7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: SentinelColors.threatMedium,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'DEGRADED: VIDEO ONLY (-80 dB)',
                      style: SentinelTypography.monoSmall.copyWith(
                        color: SentinelColors.threatMedium,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Canvas-Clipped Bounding Box Overlay for Live Predictions
          if (latestPred != null &&
              !latestPred.isNormal &&
              latestPred.clippedBoundingBox.length == 4 &&
              latestPred.clippedBoundingBox[2] > 0.02 &&
              latestPred.clippedBoundingBox[3] > 0.02)
            _buildBoundingBoxOverlay(latestPred),

          // Bottom Left HUD: Empirical Telemetry Strip
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: SentinelColors.bgDarkest.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: SentinelColors.borderLight.withValues(alpha: 0.6)),
              ),
              child: Text(
                'CAM: ${camFps.toStringAsFixed(1)} FPS | ONNX: ${infFps.toStringAsFixed(1)} FPS | '
                'LAT: ${infLatency}ms (NATIVE: ${nativeLatency}ms) | SKIPPED: $skippedCycles | '
                'RESTARTS: $restartCount | FAILS: $failureCount',
                style: SentinelTypography.monoSmall.copyWith(
                  color: SentinelColors.textSecondary,
                  fontSize: 9.5,
                ),
              ),
            ),
          ),

          // Bottom Right HUD: Latest Prediction Pill
          if (latestPred != null)
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (latestPred.isCritical
                          ? SentinelColors.threatCritical
                          : (latestPred.isNormal
                              ? SentinelColors.threatLow
                              : SentinelColors.threatMedium))
                      .withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (latestPred.isCritical
                        ? SentinelColors.threatCritical
                        : (latestPred.isNormal
                            ? SentinelColors.threatLow
                            : SentinelColors.threatMedium)),
                  ),
                ),
                child: Text(
                  '${latestPred.predictedClass.toUpperCase()} (${(latestPred.confidence * 100).toStringAsFixed(1)}%)',
                  style: SentinelTypography.monoSmall.copyWith(
                    color: SentinelColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // 1. Explicit Simulation Fallback Mode
    if (_useFallback) {
      if (widget.fallbackPainter != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: widget.fallbackPainter),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SentinelColors.bgDarkest.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SentinelColors.threatMedium),
                ),
                child: Text(
                  'SIMULATION FALLBACK (PHYSICAL WEBCAM OFFLINE)',
                  style: SentinelTypography.monoSmall.copyWith(
                    color: SentinelColors.threatMedium,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
          ],
        );
      }
      if (widget.fallback != null) {
        return widget.fallback!;
      }
    }

    // 2. Explicit Hardware Error State
    if (_hasError) {
      return Container(
        color: SentinelColors.bgDark,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                size: 44,
                color: SentinelColors.threatMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'CAM-001 // WEBCAM NOT AVAILABLE',
                style: SentinelTypography.headlineMedium.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: SentinelTypography.monoSmall.copyWith(
                  color: SentinelColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SentinelColors.primary,
                      foregroundColor: SentinelColors.bgDarkest,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _initHardwareCamera,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('RETRY WEBCAM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  if (widget.fallbackPainter != null || widget.fallback != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SentinelColors.textSecondary,
                        side: const BorderSide(color: SentinelColors.borderLight),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () => setState(() => _useFallback = true),
                      child: const Text('USE SIMULATION', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 3. Loading & Connection Handshake State
    return Container(
      color: SentinelColors.bgDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_outlined,
              size: 40,
              color: SentinelColors.accent,
            ),
            const SizedBox(height: 12),
            Text(
              'CAM-001 // INITIALIZING HARDWARE WEBCAM',
              style: SentinelTypography.headlineMedium.copyWith(fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            Text(
              _statusMessage,
              style: SentinelTypography.monoSmall.copyWith(
                color: SentinelColors.textTertiary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SentinelColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoundingBoxOverlay(ContinuousInferencePrediction pred) {
    final x = pred.clippedBoundingBox[0];
    final y = pred.clippedBoundingBox[1];
    final w = pred.clippedBoundingBox[2];
    final h = pred.clippedBoundingBox[3];

    final color = pred.isCritical ? SentinelColors.threatCritical : SentinelColors.threatMedium;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final left = x * constraints.maxWidth;
          final top = y * constraints.maxHeight;
          final width = min(w * constraints.maxWidth, constraints.maxWidth - left);
          final height = min(h * constraints.maxHeight, constraints.maxHeight - top);

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: width,
                height: height,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 2),
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Stack(
                    children: [
                      // Top-left label tag
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          color: color,
                          child: Text(
                            '${pred.predictedClass} ${(pred.confidence * 100).toStringAsFixed(0)}%',
                            style: SentinelTypography.monoSmall.copyWith(
                              color: SentinelColors.bgDarkest,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
