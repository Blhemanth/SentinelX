// SentinelX - Dynamic Audio Spectrum Visualizer & Microphone Stream Capture
// Real-time audio frequency bars, decibel level gauge, and audio spike detection.
// Grounded strictly on physical PCM sample buffers and 1024-point Radix-2 FFT spectral analysis.
// Zero mock/random jitter: displays true dBFS (<= 0.0 dBFS) and physical acoustic energy.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/providers/providers.dart';

// ─────────────────────────────────────────────────
// AUDIO STREAM MODELS & SERVICE
// ─────────────────────────────────────────────────

@immutable
class AudioStreamFrame {
  final List<double> frequencies; // 20 spectral band magnitudes (0.0 to 1.0)
  final double decibels; // Current sound level in dBFS (<= 0.0 dBFS)
  final double peakDecibels; // Peak hold level in dBFS
  final bool isAudioSpike; // True if sudden spike (> -18.0 dBFS or acoustic threat)
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
      frequencies: List.filled(20, 0.0),
      decibels: -80.0,
      peakDecibels: -80.0,
      isAudioSpike: false,
      timestamp: DateTime.now(),
    );
  }
}

class AudioCaptureService {
  final TemporalAudioBuffer? _temporalBuffer;
  final Radix2FFT1024 _fft = Radix2FFT1024();
  final Float32List _powerSpectrum = Float32List(513);

  // 20 Logarithmic/Auditory Band Bin Boundaries across 513 FFT bins (16 kHz / 1024 = 15.625 Hz/bin)
  // Covers ~31 Hz to 8000 Hz
  static const List<int> _bandStartBins = [
    2, 4, 6, 9, 13, 18, 25, 34, 46, 61,
    81, 106, 137, 176, 223, 279, 345, 419, 481, 501
  ];
  static const List<int> _bandEndBins = [
    3, 5, 8, 12, 17, 24, 33, 45, 60, 80,
    105, 136, 175, 222, 278, 344, 418, 480, 500, 512
  ];

  Timer? _captureTimer;

  final StreamController<AudioStreamFrame> _audioStreamController =
      StreamController<AudioStreamFrame>.broadcast();

  Stream<AudioStreamFrame> get stream => _audioStreamController.stream;

  double _peakDecibels = -80.0;
  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  final List<double> _peakHolds = List.filled(20, 0.0);

  AudioCaptureService({TemporalAudioBuffer? temporalBuffer})
      : _temporalBuffer = temporalBuffer;

  void startCapture() {
    if (_isCapturing) return;
    _isCapturing = true;

    // 40ms timer = 25 FPS audio analysis update rate
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

    final isSpike = payload.decibels > -18.0 ||
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

    final buffer = _temporalBuffer;
    if (buffer == null || buffer.currentCount == 0) {
      _peakDecibels = math.max(-80.0, _peakDecibels - 0.4);
      _audioStreamController.add(AudioStreamFrame(
        frequencies: List.filled(20, 0.0),
        decibels: -80.0,
        peakDecibels: _peakDecibels,
        isAudioSpike: false,
        timestamp: DateTime.now(),
      ));
      return;
    }

    // Extract 1024-sample snapshot for real-time FFT
    final samples = buffer.extractSnapshot(1024);

    // Compute RMS and dBFS
    double sumSq = 0.0;
    for (int i = 0; i < 1024; i++) {
      final s = samples[i];
      sumSq += s * s;
    }
    final rms = math.sqrt(sumSq / 1024.0);
    final double currentDbFs = (rms > 1e-4)
        ? (20.0 * math.log(rms) / math.ln10).clamp(-80.0, 0.0)
        : -80.0;

    // Update peak decibel with decay
    if (currentDbFs > _peakDecibels) {
      _peakDecibels = currentDbFs;
    } else {
      _peakDecibels = math.max(-80.0, _peakDecibels - 0.4);
    }

    final isSpike = currentDbFs > -18.0;

    // Compute 20-band FFT spectrum from real PCM samples
    final freqs = List<double>.filled(20, 0.0);

    if (currentDbFs > -75.0) {
      _fft.computePowerSpectrum(samples, _powerSpectrum);

      for (int i = 0; i < 20; i++) {
        final start = _bandStartBins[i];
        final end = _bandEndBins[i];
        final count = end - start + 1;

        double bandSum = 0.0;
        for (int k = start; k <= end; k++) {
          bandSum += _powerSpectrum[k];
        }
        final avgPower = bandSum / count;

        double mag = 0.0;
        if (avgPower > 1e-8) {
          final bandDb = 10.0 * math.log(avgPower) / math.ln10;
          mag = ((bandDb + 80.0) / 80.0).clamp(0.0, 1.0);
        }

        // Apply peak hold decay
        _peakHolds[i] = math.max(mag, _peakHolds[i] * 0.90);
        freqs[i] = _peakHolds[i];
      }
    } else {
      // Digital silence: decay peak holds to zero
      for (int i = 0; i < 20; i++) {
        _peakHolds[i] = math.max(0.0, _peakHolds[i] * 0.85);
        freqs[i] = _peakHolds[i];
      }
    }

    _audioStreamController.add(AudioStreamFrame(
      frequencies: freqs,
      decibels: currentDbFs,
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
  final buffer = ref.watch(temporalAudioBufferProvider);
  final service = AudioCaptureService(temporalBuffer: buffer);
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

    final audioTelemAsync = ref.watch(audioTelemetryStreamProvider);
    final telem = audioTelemAsync.valueOrNull;
    final isHardwareStreaming = telem != null && telem.status == AudioConnectionStatus.streaming;

    final double displayDb = isHardwareStreaming ? telem.currentDbFs : frame.decibels;
    final String acousticLabel = isHardwareStreaming
        ? telem.acousticStateLabel
        : (frame.decibels <= -75.0 ? 'DIGITAL SILENCE (-80 dBFS)' : 'AMBIENT ROOM NOISE');

    final isSpike = isHardwareStreaming ? telem.isAcousticPeak : frame.isAudioSpike;
    final primaryColor = isSpike
        ? SentinelColors.threatCritical
        : (displayDb > -20.0 ? SentinelColors.threatHigh : SentinelColors.accent);

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
                        : (isHardwareStreaming
                            ? 'MIC // $acousticLabel'
                            : 'LIVE AUDIO SPECTRUM // 20-BAND'),
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
                    '${displayDb.toStringAsFixed(1)} dBFS',
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

    // 2. Draw Threshold Warning Line at -18.0 dBFS (equivalent to 77.5% height)
    final thresholdPaint = Paint()
      ..color = SentinelColors.threatCritical.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;
    final threshY = size.height * (1.0 - 0.775);
    canvas.drawLine(Offset(0, threshY), Offset(size.width, threshY), thresholdPaint);

    // 3. Render 20 Spectral Frequency Bars
    for (int i = 0; i < count; i++) {
      final value = frequencies[i].clamp(0.0, 1.0);
      if (value < 0.005) continue; // Zero bar or digital silence, do not draw fake bar

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
