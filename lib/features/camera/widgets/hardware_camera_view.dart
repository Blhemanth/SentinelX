// SentinelX - Hardware Camera View
// Connects directly to the physical laptop webcam using the Flutter camera plugin.
// Renders live video preview with graceful fallback to animated canvas when offline.

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';

class HardwareCameraView extends StatefulWidget {
  final Widget? fallback;
  final CustomPainter? fallbackPainter;

  const HardwareCameraView({
    super.key,
    this.fallback,
    this.fallbackPainter,
  });

  @override
  State<HardwareCameraView> createState() => _HardwareCameraViewState();
}

class _HardwareCameraViewState extends State<HardwareCameraView> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _statusMessage = 'Connecting to Laptop Webcam (CAM-001)...';

  @override
  void initState() {
    super.initState();
    _initHardwareCamera();
  }

  Future<void> _initHardwareCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _statusMessage = 'No hardware webcam detected. Using fallback simulator.';
          });
        }
        return;
      }

      // Select primary laptop webcam
      final primaryCam = cameras.first;
      final controller = CameraController(
        primaryCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _controller = controller;
      await controller.initialize();

      if (mounted) {
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized && _controller != null && _controller!.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.previewSize?.height ?? 1280,
              height: _controller!.value.previewSize?.width ?? 720,
              child: CameraPreview(_controller!),
            ),
          ),
          // Subtle Cyberpunk surveillance filter overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  SentinelColors.bgDarkest.withValues(alpha: 0.15),
                  Colors.transparent,
                  SentinelColors.bgDarkest.withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Fallback while loading or if hardware webcam is unavailable
    if (widget.fallbackPainter != null) {
      return CustomPaint(painter: widget.fallbackPainter);
    }

    if (widget.fallback != null) {
      return widget.fallback!;
    }

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
              'CAM-001 // LAPTOP WEBCAM',
              style: SentinelTypography.headlineMedium.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              _statusMessage,
              style: SentinelTypography.monoSmall.copyWith(
                color: _hasError ? SentinelColors.threatMedium : SentinelColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            if (!_hasError)
              const SizedBox(
                width: 24,
                height: 24,
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
}
