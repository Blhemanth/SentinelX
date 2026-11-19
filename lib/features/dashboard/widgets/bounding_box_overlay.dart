// SentinelX - Hardware-Accelerated Bounding Box Overlay
// CustomPainter for real-time video stream detection vector frames.
// Renders dynamic corner targeting reticles, confidence badges, and 85%+ pulse effects.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sentinel_x/services/mock_inference_service.dart';

class BoundingBoxOverlay extends StatefulWidget {
  final InferencePayload? payload;
  final bool enablePulse;

  const BoundingBoxOverlay({
    super.key,
    required this.payload,
    this.enablePulse = true,
  });

  @override
  State<BoundingBoxOverlay> createState() => _BoundingBoxOverlayState();
}

class _BoundingBoxOverlayState extends State<BoundingBoxOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;
    if (payload == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: BoundingBoxCustomPainter(
            payload: payload,
            pulseValue: _pulseAnimation.value,
          ),
        );
      },
    );
  }
}

class BoundingBoxCustomPainter extends CustomPainter {
  final InferencePayload payload;
  final double pulseValue;

  BoundingBoxCustomPainter({
    required this.payload,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final normRect = payload.boundingBox;
    // Scale normalized 0..1 coordinates to actual viewport size
    final left = normRect.left * size.width;
    final top = normRect.top * size.height;
    final width = normRect.width * size.width;
    final height = normRect.height * size.height;
    final targetRect = Rect.fromLTWH(left, top, width, height);

    final color = payload.threatColor;
    final isCritical = payload.confidence >= 0.85;

    // 1. Outer Pulse Glow (for 85%+ high threat anomalies)
    if (isCritical) {
      final pulseSpread = 4.0 + pulseValue * 8.0;
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.25 * (1.0 - pulseValue * 0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 + pulseSpread
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawRRect(
        RRect.fromRectAndRadius(targetRect.inflate(pulseSpread), const Radius.circular(6)),
        glowPaint,
      );
    }

    // 2. Semi-transparent Interior Fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: isCritical ? 0.14 : 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(4)),
      fillPaint,
    );

    // 3. Vector Bounding Box Border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCritical ? 2.0 : 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(4)),
      borderPaint,
    );

    // 4. Cyberpunk Corner Reticles / Targeting Brackets
    _drawTargetingCorners(canvas, targetRect, color);

    // 5. Threat Category & Confidence Badge Pill
    _drawThreatBadge(canvas, targetRect, color, isCritical);
  }

  void _drawTargetingCorners(Canvas canvas, Rect rect, Color color) {
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final armLength = min(16.0, min(rect.width, rect.height) * 0.25);

    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top + armLength), Offset(rect.left, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + armLength, rect.top), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(rect.right - armLength, rect.top), Offset(rect.right, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + armLength), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom - armLength), Offset(rect.left, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + armLength, rect.bottom), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(rect.right - armLength, rect.bottom), Offset(rect.right, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - armLength), cornerPaint);
  }

  void _drawThreatBadge(Canvas canvas, Rect rect, Color color, bool isCritical) {
    final emoji = isCritical ? '🚨 ' : (payload.isNormal ? '✓ ' : '⚠️ ');
    final labelText = '$emoji${payload.threatType.toUpperCase()} (${(payload.confidence * 100).toStringAsFixed(1)}%)';

    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    const hPadding = 6.0;
    const vPadding = 3.0;
    final badgeWidth = textPainter.width + hPadding * 2;
    final badgeHeight = textPainter.height + vPadding * 2;

    // Position above bounding box, or inside if too close to top edge
    final badgeTop = (rect.top - badgeHeight - 4) < 4
        ? rect.top + 4
        : rect.top - badgeHeight - 4;
    final badgeLeft = rect.left;

    final badgeRect = Rect.fromLTWH(badgeLeft, badgeTop, badgeWidth, badgeHeight);

    // Background pill
    final badgeBgPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)),
      badgeBgPaint,
    );

    // Badge border
    final badgeBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)),
      badgeBorderPaint,
    );

    // Render text
    textPainter.paint(
      canvas,
      Offset(badgeLeft + hPadding, badgeTop + vPadding),
    );
  }

  @override
  bool shouldRepaint(covariant BoundingBoxCustomPainter oldDelegate) {
    return oldDelegate.payload != payload ||
        oldDelegate.pulseValue != pulseValue;
  }
}
