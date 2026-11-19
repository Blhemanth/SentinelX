// SentinelX - Dynamic Audio Spectrum Visualizer & Microphone Stream Capture
// Real-time audio frequency bars, decibel level gauge, and audio spike detection (screams, gunshots).
// Hardware-accelerated CustomPainter with glowing peak-hold indicators.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/services/mock_inference_service.dart';
import 'package:sentinel_x/services/inference_repository.dart';

// ─────────────────────────────────────────────────
// AUDIO STREAM MODELS & SERVICE
// ─────────────────────────────────────────────────

@immutable
class AudioStreamFrame {
  final List<double> frequencies; // 20 spectral band magnitudes (0.0 to 1.0)
  final double decibels; // Current sound pressure level in dB
  final double peakDecibels; // Peak hold level
  final bool isAudioSpike; // True if sudden spike (>85 dB or acoustic threat)
  final String? anomalyLabel; // 'Gunshot Audio', 'Explosion', 'Scream', etc.
  final DateTime timestamp;

  const AudioStreamFrame({
    required this.frequencies,
    required this.decibels,
    required this.peakDecibels,
    required this.isAudioSpike,
    required this.timestamp,
    this.anomalyLabel,
  });

  factory AudioStreamFrame.ambient() {
    return AudioStreamFrame(
      frequencies: List.generate(20, (i) => 0.12 + (i % 4) * 0.05),
      decibels: 52.0,
      peakDecibels: 58.0,
      isAudioSpike: false,
      timestamp: DateTime.now(),
    );
  }
}

class AudioCaptureService {
  final _random = Random();
  Timer? _captureTimer;

  final StreamController<AudioStreamFrame> _audioStreamController =
      StreamController<AudioStreamFrame>.broadcast();

  Stream<AudioStreamFrame> get stream => _audioStreamController.stream;

  double _peakDecibels = 55.0;
  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  final List<double> _peakHolds = List.filled(20, 0.2);

  void startCapture() {
    if (_isCapturing) return;
    _isCapturing = true;

    // 40ms timer ≈ 25 FPS audio analysis update rate
    _captureTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => _processAudioWindow(),
    );
  }

  void stopCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _isCapturing = false;
  }

  void ingestInferenceAudio(InferencePayload payload) {
    if (_audioStreamController.isClosed) return;

    final isSpike = payload.decibels > 85.0 ||
        payload.threatType.contains('Gunshot') ||
        payload.threatType.contains('Explosion');

    if (payload.decibels > _peakDecibels) {
      _peakDecibels = payload.decibels;
    }

    _audioStreamController.add(AudioStreamFrame(
      frequencies: payload.audioFrequencies,
      decibels: payload.decibels,
      peakDecibels: _peakDecibels,
      isAudioSpike: isSpike,
      anomalyLabel: isSpike ? payload.threatType : null,
      timestamp: DateTime.now(),
    ));
  }

  void _processAudioWindow() {
    if (_audioStreamController.isClosed) return;

    // Ambient microphone noise simulation with subtle jitter
    final ambientDb = 48.0 + _random.nextDouble() * 12.0;
    final isSpike = ambientDb > 85.0;

    // Slowly decay peak decibels
    _peakDecibels = max(ambientDb, _peakDecibels * 0.992);

    final freqs = List.generate(20, (i) {
      final rollOff = 1.0 - (i / 24.0);
      final raw = (0.15 + _random.nextDouble() * 0.25) * rollOff;
      // Decay peak hold
      _peakHolds[i] = max(raw, _peakHolds[i] * 0.96);
      return raw.clamp(0.05, 1.0);
    });

    _audioStreamController.add(AudioStreamFrame(
      frequencies: freqs,
      decibels: ambientDb,
      peakDecibels: _peakDecibels,
      isAudioSpike: isSpike,
      timestamp: DateTime.now(),
    ));
  }

  void dispose() {
    stopCapture();
    _audioStreamController.close();
  }
}

// ─────────────────────────────────────────────────
// RIVERPOD PROVIDERS
// ─────────────────────────────────────────────────

final audioCaptureServiceProvider = Provider<AudioCaptureService>((ref) {
  final service = AudioCaptureService();
  service.startCapture();

  // Listen to inference payloads to inject acoustic spikes
  final sub = ref.listen(activeInferencePayloadStreamProvider, (_, next) {
    if (next.hasValue && next.value != null) {
      service.ingestInferenceAudio(next.value!);
    }
  });

  ref.onDispose(() {
    sub.close();
    service.dispose();
  });
  return service;
});

final audioStreamFrameProvider = StreamProvider<AudioStreamFrame>((ref) {
  final service = ref.watch(audioCaptureServiceProvider);
  return service.stream;
});

// ─────────────────────────────────────────────────
// DYNAMIC AUDIO SPECTRUM VISUALIZER WIDGET
// ─────────────────────────────────────────────────

class AudioSpectrumVisualizer extends ConsumerWidget {
  final double? height;
  final bool showHeader;
  final bool compact;

  const AudioSpectrumVisualizer({
    super.key,
    this.height,
    this.showHeader = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frameAsync = ref.watch(audioStreamFrameProvider);
    final frame = frameAsync.value ?? AudioStreamFrame.ambient();

    final isSpike = frame.isAudioSpike;
    final primaryColor = isSpike
        ? SentinelColors.threatCritical
        : (frame.decibels > 75.0 ? SentinelColors.threatHigh : SentinelColors.accent);

    return Container(
      height: height,
      padding: EdgeInsets.all(compact ? SentinelSpacing.sm : SentinelSpacing.md),
      decoration: BoxDecoration(
        color: SentinelColors.bgCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSpike
              ? SentinelColors.threatCritical.withValues(alpha: 0.8)
              : SentinelColors.glassBorder,
          width: isSpike ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: SentinelSpacing.sm),
                Expanded(
                  child: Text(
                    isSpike
                        ? '⚠️ ACOUSTIC SPIKE DETECTED'
                        : 'LIVE AUDIO SPECTRUM // 20-BAND',
                    style: SentinelTypography.headlineMedium.copyWith(
                      fontSize: 12,
                      color: isSpike ? SentinelColors.threatCritical : SentinelColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: SentinelSpacing.sm),
                // Decibel Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: primaryColor),
                  ),
                  child: Text(
                    '${frame.decibels.toStringAsFixed(1)} dB SPL',
                    style: SentinelTypography.monoSmall.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SentinelSpacing.sm),
          ],

          // Live Spectrum Custom Canvas
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: AudioWaveformCustomPainter(
                frequencies: frame.frequencies,
                decibels: frame.decibels,
                isSpike: isSpike,
                primaryColor: primaryColor,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Frequency Axis Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('60Hz', style: SentinelTypography.monoSmall.copyWith(fontSize: 9, color: SentinelColors.textTertiary)),
              Text('250Hz', style: SentinelTypography.monoSmall.copyWith(fontSize: 9, color: SentinelColors.textTertiary)),
              Text('1kHz', style: SentinelTypography.monoSmall.copyWith(fontSize: 9, color: SentinelColors.textTertiary)),
              Text('4kHz', style: SentinelTypography.monoSmall.copyWith(fontSize: 9, color: SentinelColors.textTertiary)),
              Text('16kHz', style: SentinelTypography.monoSmall.copyWith(fontSize: 9, color: SentinelColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// DYNAMIC WAVEFORM CUSTOM PAINTER
// ─────────────────────────────────────────────────

class AudioWaveformCustomPainter extends CustomPainter {
  final List<double> frequencies;
  final double decibels;
  final bool isSpike;
  final Color primaryColor;

  AudioWaveformCustomPainter({
    required this.frequencies,
    required this.decibels,
    required this.isSpike,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (frequencies.isEmpty || size.width == 0 || size.height == 0) return;

    final count = frequencies.length;
    const spacing = 3.0;
    final barWidth = ((size.width - (count - 1) * spacing) / count).clamp(2.0, 40.0);

    // 1. Draw Baseline Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1E283D).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), gridPaint);

    // 2. Draw Threshold Warning Line at 85 dB (equivalent to ~70% height)
    final thresholdPaint = Paint()
      ..color = SentinelColors.threatCritical.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    final threshY = size.height * (1.0 - (85.0 / 120.0));
    canvas.drawLine(Offset(0, threshY), Offset(size.width, threshY), thresholdPaint);

    // 3. Render 20 Spectral Frequency Bars
    for (int i = 0; i < count; i++) {
      final value = frequencies[i].clamp(0.04, 1.0);
      final barHeight = value * size.height;
      final x = i * (barWidth + spacing);
      final y = size.height - barHeight;

      final rect = Rect.fromLTWH(x, y, barWidth, barHeight);

      // Shaded Gradient Fill
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            primaryColor.withValues(alpha: 0.25),
            primaryColor,
          ],
        ).createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        barPaint,
      );

      // 4. Peak Hold Indicator (little bright horizontal tick above bar)
      final peakY = (y - 3.0).clamp(0.0, size.height);
      final peakPaint = Paint()
        ..color = isSpike ? Colors.white : primaryColor
        ..strokeWidth = 2.0;

      canvas.drawLine(Offset(x, peakY), Offset(x + barWidth, peakY), peakPaint);

      // 5. Ambient Glow for spike frequencies
      if (isSpike && value > 0.6) {
        final glowPaint = Paint()
          ..color = SentinelColors.threatCritical.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(4)),
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AudioWaveformCustomPainter oldDelegate) {
    return oldDelegate.frequencies != frequencies ||
        oldDelegate.decibels != decibels ||
        oldDelegate.isSpike != isSpike;
  }
}
