// SentinelX - Incident Video Player
// Authenticated CCTV video clip playback for recorded distress events.
// Displays timecode HUD, audio distress spike synchronized to "HELP, HELP",
// frame scrubber, and forensic playback controls.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/services/incident_dispatch_repository.dart';

class IncidentVideoPlayer extends StatefulWidget {
  final DistressIncident incident;
  final bool autoPlay;

  const IncidentVideoPlayer({
    super.key,
    required this.incident,
    this.autoPlay = true,
  });

  @override
  State<IncidentVideoPlayer> createState() => _IncidentVideoPlayerState();
}

class _IncidentVideoPlayerState extends State<IncidentVideoPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isPlaying = true;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.incident.clipDurationSeconds),
    )..addListener(() {
        setState(() {});
      });

    if (widget.autoPlay) {
      _animController.repeat();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _animController.stop();
        _isPlaying = false;
      } else {
        _animController.repeat();
        _isPlaying = true;
      }
    });
  }

  void _toggleSpeed() {
    setState(() {
      _playbackSpeed = _playbackSpeed == 1.0 ? 0.5 : (_playbackSpeed == 0.5 ? 2.0 : 1.0);
      _animController.duration = Duration(
        milliseconds: (widget.incident.clipDurationSeconds * 1000 / _playbackSpeed).round(),
      );
      if (_isPlaying) {
        _animController.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _animController.value;
    final currentSecond = (progress * widget.incident.clipDurationSeconds).toStringAsFixed(1);
    final totalSecond = widget.incident.clipDurationSeconds.toStringAsFixed(1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: SentinelColors.threatCritical.withValues(alpha: 0.6)),
        ),
        child: Stack(
          children: [
            // Synthetic High-Def Incident CCTV Canvas Feed
            CustomPaint(
              painter: _CctvPlaybackPainter(
                progress: progress,
                cameraId: widget.incident.cameraId,
                threatType: widget.incident.threatType,
                frequencies: widget.incident.spectralFrequencies,
              ),
              child: const SizedBox.expand(),
            ),

            // Top CCTV HUD: Camera ID, Timestamp, REC badge
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SentinelColors.threatCritical,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'RECORDED CLIP',
                          style: SentinelTypography.monoSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.incident.cameraId} // ${widget.incident.cameraName}',
                    style: SentinelTypography.monoSmall.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'TIME: 00:0$currentSecond / 00:0$totalSecond',
                    style: SentinelTypography.monoSmall.copyWith(
                      color: SentinelColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Acoustic Distress Spike Overlay (Triggered around progress 0.35 to 0.75)
            if (progress >= 0.30 && progress <= 0.80)
              Positioned(
                top: 40,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.record_voice_over, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'ACOUSTIC PEAK: "${widget.incident.audioTranscript}"',
                        style: SentinelTypography.monoSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Player Control Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: Colors.black.withValues(alpha: 0.85),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scrubber Bar
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                        activeTrackColor: SentinelColors.threatCritical,
                        inactiveTrackColor: Colors.grey.shade800,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (val) {
                          _animController.value = val;
                        },
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: _togglePlayPause,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: _toggleSpeed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: SentinelColors.glassBorder),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${_playbackSpeed}x',
                              style: SentinelTypography.monoSmall.copyWith(
                                color: SentinelColors.textPrimary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.volume_up, size: 14, color: SentinelColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.incident.decibels.toStringAsFixed(1)} dB SPL',
                          style: SentinelTypography.monoSmall.copyWith(
                            color: SentinelColors.threatCritical,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: SentinelColors.threatCritical.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'CONF: ${(widget.incident.confidence * 100).toStringAsFixed(1)}%',
                            style: SentinelTypography.monoSmall.copyWith(
                              color: SentinelColors.threatCritical,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// CCTV VIDEO PLAYBACK PAINTER
// ─────────────────────────────────────────────────

class _CctvPlaybackPainter extends CustomPainter {
  final double progress;
  final String cameraId;
  final String threatType;
  final List<double> frequencies;

  _CctvPlaybackPainter({
    required this.progress,
    required this.cameraId,
    required this.threatType,
    required this.frequencies,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark CCTV background gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF0D1117),
          const Color(0xFF161B22),
          const Color(0xFF090C10),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Scanlines
    final scanlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    // 3. Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    final cols = 6;
    final rows = 4;
    for (int i = 1; i < cols; i++) {
      final x = size.width * (i / cols);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (int j = 1; j < rows; j++) {
      final y = size.height * (j / rows);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 4. Detected Target Bounding Box pulsating
    final isDistressSpike = progress >= 0.30 && progress <= 0.80;
    final pulseScale = isDistressSpike ? (1.0 + sin(progress * pi * 8) * 0.05) : 1.0;

    final boxW = size.width * 0.38 * pulseScale;
    final boxH = size.height * 0.48 * pulseScale;
    final boxX = (size.width - boxW) / 2 + sin(progress * 2 * pi) * 15;
    final boxY = (size.height - boxH) / 2 + 10;
    final targetRect = Rect.fromLTWH(boxX, boxY, boxW, boxH);

    final boxBorderPaint = Paint()
      ..color = isDistressSpike ? const Color(0xFFFF3B5C) : const Color(0xFFFFBB33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDistressSpike ? 2.5 : 1.5;

    final boxFillPaint = Paint()
      ..color = (isDistressSpike ? const Color(0xFFFF3B5C) : const Color(0xFFFFBB33))
          .withValues(alpha: 0.08);

    canvas.drawRect(targetRect, boxFillPaint);
    canvas.drawRect(targetRect, boxBorderPaint);

    // Corner brackets
    final cornerLen = 14.0;
    final cornerPaint = Paint()
      ..color = isDistressSpike ? const Color(0xFFFF3B5C) : const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Top-Left
    canvas.drawLine(targetRect.topLeft, targetRect.topLeft + Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(targetRect.topLeft, targetRect.topLeft + Offset(0, cornerLen), cornerPaint);
    // Top-Right
    canvas.drawLine(targetRect.topRight, targetRect.topRight - Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(targetRect.topRight, targetRect.topRight + Offset(0, cornerLen), cornerPaint);
    // Bottom-Left
    canvas.drawLine(targetRect.bottomLeft, targetRect.bottomLeft + Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(targetRect.bottomLeft, targetRect.bottomLeft - Offset(0, cornerLen), cornerPaint);
    // Bottom-Right
    canvas.drawLine(targetRect.bottomRight, targetRect.bottomRight - Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(targetRect.bottomRight, targetRect.bottomRight - Offset(0, cornerLen), cornerPaint);

    // 5. Subject silhouette / figure placeholder inside bounding box
    final figurePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final headCenter = Offset(targetRect.center.dx, targetRect.top + targetRect.height * 0.25);
    canvas.drawCircle(headCenter, targetRect.height * 0.12, figurePaint);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(targetRect.center.dx, targetRect.top + targetRect.height * 0.65),
        width: targetRect.width * 0.6,
        height: targetRect.height * 0.55,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, figurePaint);
  }

  @override
  bool shouldRepaint(covariant _CctvPlaybackPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
