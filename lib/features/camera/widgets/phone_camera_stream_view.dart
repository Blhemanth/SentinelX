// SentinelX - Phone Camera Stream View
// Handles CAM-002: Mobile Phone Camera feed.
// Supports:
// 1. Second hardware camera device (DroidCam / Iriun / USB Cam)
// 2. Wireless IP Camera HTTP stream / snapshot polling (e.g. http://192.168.1.x:8080/shot.jpg)
// 3. High-definition Cyberpunk mobile camera simulator fallback with live scanning reticles

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:sentinel_x/core/theme/sentinel_theme.dart';

class PhoneCameraStreamView extends StatefulWidget {
  final Widget? fallback;
  final CustomPainter? fallbackPainter;

  const PhoneCameraStreamView({
    super.key,
    this.fallback,
    this.fallbackPainter,
  });

  @override
  State<PhoneCameraStreamView> createState() => _PhoneCameraStreamViewState();
}

class _PhoneCameraStreamViewState extends State<PhoneCameraStreamView> {
  CameraController? _controller;
  bool _isHardwareConnected = false;
  String _phoneIp = 'http://192.168.1.100:8080';
  bool _isIpStreaming = false;
  Timer? _snapshotTimer;
  ImageProvider? _currentIpFrame;

  @override
  void initState() {
    super.initState();
    _checkSecondaryHardwareCamera();
  }

  Future<void> _checkSecondaryHardwareCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.length > 1) {
        // A second camera (DroidCam, Iriun, or external camera) exists!
        final secondaryCam = cameras[1];
        final controller = CameraController(
          secondaryCam,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        _controller = controller;
        await controller.initialize();
        if (mounted) {
          setState(() {
            _isHardwareConnected = true;
          });
        }
      }
    } catch (e) {
      debugPrint('[PhoneCam] Secondary hardware camera probe: $e');
    }
  }

  void _startIpStreamPolling(String url) {
    _snapshotTimer?.cancel();
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final shotUrl = cleanUrl.contains('/shot.jpg') ? cleanUrl : '$cleanUrl/shot.jpg';

    _snapshotTimer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      try {
        final res = await http.get(Uri.parse(shotUrl)).timeout(const Duration(milliseconds: 800));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty && mounted) {
          setState(() {
            _currentIpFrame = MemoryImage(res.bodyBytes);
            _isIpStreaming = true;
          });
        }
      } catch (_) {
        // Fallback to simulator if IP camera unreachable
        if (mounted && _isIpStreaming) {
          setState(() => _isIpStreaming = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _snapshotTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _showConfigureDialog() {
    final textCtrl = TextEditingController(text: _phoneIp);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SentinelColors.bgCard,
        title: Row(
          children: [
            const Icon(Icons.phone_android, color: SentinelColors.accent, size: 20),
            const SizedBox(width: 8),
            Text('Configure Phone Camera (CAM-002)',
                style: SentinelTypography.headlineMedium.copyWith(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your phone IP from the "IP Webcam" app (Android/iOS) or local stream URL:',
              style: SentinelTypography.bodySmall.copyWith(color: SentinelColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: 'http://192.168.1.X:8080',
                labelText: 'Phone IP Stream URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: You can also use DroidCam or Iriun Webcam over USB / Wi-Fi without entering an IP!',
              style: SentinelTypography.monoSmall.copyWith(color: SentinelColors.textTertiary, fontSize: 10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _phoneIp = textCtrl.text.trim();
              });
              _startIpStreamPolling(_phoneIp);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: SentinelColors.primary),
            child: const Text('CONNECT STREAM'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Hardware secondary webcam view (DroidCam, Iriun, etc.)
    if (_isHardwareConnected && _controller != null && _controller!.value.isInitialized) {
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
          _buildPhoneWatermark(),
        ],
      );
    }

    // 2. Wireless IP camera snapshot stream
    if (_isIpStreaming && _currentIpFrame != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image(image: _currentIpFrame!, fit: BoxFit.cover),
          _buildPhoneWatermark(),
        ],
      );
    }

    // 3. High-Tech Cyberpunk Standby / Live Mobile Simulator View
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.fallbackPainter != null)
          CustomPaint(painter: widget.fallbackPainter)
        else
          CustomPaint(painter: _PhoneCameraStandbyPainter()),

        // Phone connection prompt overlay
        Positioned(
          top: 12,
          right: 12,
          child: ElevatedButton.icon(
            onPressed: _showConfigureDialog,
            icon: const Icon(Icons.wifi, size: 14),
            label: const Text('CONNECT PHONE IP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SentinelColors.bgSurface.withValues(alpha: 0.85),
              foregroundColor: SentinelColors.accent,
              side: const BorderSide(color: SentinelColors.accent),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ),

        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: SentinelColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_android, size: 12, color: SentinelColors.accent),
                const SizedBox(width: 6),
                Text(
                  'CAM-002: MOBILE PHONE STREAM (STANDBY // READY)',
                  style: SentinelTypography.monoSmall.copyWith(
                    color: SentinelColors.accent,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneWatermark() {
    return Positioned(
      bottom: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          'CAM-002 // MOBILE WIRELESS FEED',
          style: SentinelTypography.monoSmall.copyWith(
            color: SentinelColors.accent,
            fontSize: 9,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// STANDBY PAINTER FOR PHONE CAMERA
// ─────────────────────────────────────────────────

class _PhoneCameraStandbyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF090C10),
          const Color(0xFF131922),
          const Color(0xFF0A0E14),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Crosshairs and grid
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Center targeting reticle
    final center = Offset(size.width / 2, size.height / 2);
    final reticlePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 45, reticlePaint);
    canvas.drawCircle(center, 70, reticlePaint);
    canvas.drawLine(center - const Offset(85, 0), center + const Offset(85, 0), reticlePaint);
    canvas.drawLine(center - const Offset(0, 85), center + const Offset(0, 85), reticlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
