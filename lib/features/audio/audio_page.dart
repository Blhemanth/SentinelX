// SentinelX - Audio Monitor Page
// Real-time audio classification display with frequency waveform visualization,
// audio event timeline, and classification history.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/models/models.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/shared/widgets/sentinel_widgets.dart';

class AudioPage extends ConsumerStatefulWidget {
  const AudioPage({super.key});

  @override
  ConsumerState<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends ConsumerState<AudioPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioIngestionServiceProvider).startStreaming().catchError((e) {
        debugPrint('[AudioPage] Auto-start audio streaming note: $e');
        return false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1000;

    return Container(
      decoration: const BoxDecoration(
        gradient: SentinelGradients.surfaceGradient,
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Audio Monitor',
                    style: SentinelTypography.displayMedium,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: SentinelColors.accent.withValues(alpha: 0.1),
                      borderRadius: SentinelRadius.smAll,
                      border: Border.all(
                        color: SentinelColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PulsingDot(
                          color: SentinelColors.accent,
                          size: 6,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LISTENING',
                          style: SentinelTypography.labelSmall.copyWith(
                            color: SentinelColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(SentinelSpacing.base),
            sliver: SliverToBoxAdapter(
              child: isWide ? _WideLayout() : _NarrowLayout(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _LiveWaveformCard(),
        const SizedBox(height: SentinelSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(flex: 3, child: _AudioEventTimeline()),
            const SizedBox(width: SentinelSpacing.md),
            const Expanded(flex: 2, child: _AudioClassificationSummary()),
          ],
        ),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _LiveWaveformCard(),
        SizedBox(height: SentinelSpacing.md),
        _AudioClassificationSummary(),
        SizedBox(height: SentinelSpacing.md),
        _AudioEventTimeline(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// LIVE WAVEFORM VISUALIZATION
// ─────────────────────────────────────────────────

class _LiveWaveformCard extends ConsumerWidget {
  const _LiveWaveformCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frameAsync = ref.watch(audioStreamFrameProvider);
    final frame = frameAsync.valueOrNull ?? AudioStreamFrame.ambient();

    final audioAsync = ref.watch(audioStreamProvider);
    final latestEvent = audioAsync.valueOrNull;

    final audioTelemAsync = ref.watch(audioTelemetryStreamProvider);
    final telem = audioTelemAsync.valueOrNull;
    final isStreaming = telem != null && telem.status == AudioConnectionStatus.streaming;

    final double displayDb = isStreaming ? telem.currentDbFs : frame.decibels;
    final String devName = telem?.deviceName.isNotEmpty == true ? telem!.deviceName : 'Realtek High Definition Audio';
    final String stateLabel = isStreaming ? telem.acousticStateLabel : 'AWAITING HARDWARE';

    final bool isSpike = isStreaming ? telem.isAcousticPeak : frame.isAudioSpike;
    final Color badgeColor = isSpike
        ? SentinelColors.threatCritical
        : (displayDb > -40.0 ? SentinelColors.accent : SentinelColors.textSecondary);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Live Audio Waveform ($devName)',
            icon: Icons.graphic_eq_rounded,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: SentinelRadius.smAll,
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${displayDb.toStringAsFixed(1)} dBFS',
                    style: SentinelTypography.monoMedium.copyWith(
                      color: badgeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (latestEvent != null) ...[
                  const SizedBox(width: 8),
                  ThreatBadge(level: latestEvent.threat, compact: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: SentinelSpacing.md),
          SizedBox(
            height: 120,
            child: (frame.frequencies.any((f) => f > 0.005) || isStreaming)
                ? _WaveformVisualizer(
                    bands: frame.frequencies,
                    threatColor: isSpike ? SentinelColors.threatCritical : SentinelColors.accent,
                  )
                : Center(
                    child: Text(
                      isStreaming
                          ? 'Microphone active • $stateLabel'
                          : 'Awaiting audio data...',
                      style: SentinelTypography.bodyMedium,
                    ),
                  ),
          ),
          if (latestEvent != null || isStreaming) ...[
            const SizedBox(height: SentinelSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  latestEvent != null
                      ? 'Classification: ${latestEvent.classification.toUpperCase()}'
                      : 'Classification: MODEL UNVALIDATED // $stateLabel',
                  style: SentinelTypography.monoSmall.copyWith(
                    color: latestEvent != null ? SentinelColors.threatCritical : SentinelColors.accent,
                  ),
                ),
                Text(
                  latestEvent != null
                      ? 'Confidence: ${(latestEvent.confidence * 100).toStringAsFixed(1)}%'
                      : 'Signal: ${displayDb > -75.0 ? "LIVE RAW PCM" : "DIGITAL SILENCE"}',
                  style: SentinelTypography.monoSmall,
                ),
                Text(
                  'Source: ${latestEvent?.cameraId ?? devName}',
                  style: SentinelTypography.monoSmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WaveformVisualizer extends StatelessWidget {
  final List<double> bands;
  final Color threatColor;

  const _WaveformVisualizer({
    required this.bands,
    required this.threatColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveformPainter(bands: bands, color: threatColor),
      size: Size.infinite,
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bands;
  final Color color;

  _WaveformPainter({required this.bands, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final barWidth = size.width / bands.length;
    final maxHeight = size.height * 0.9;

    for (int i = 0; i < bands.length; i++) {
      final value = bands[i].clamp(0.0, 1.0);
      if (value < 0.005) continue;
      final barHeight = value * maxHeight;
      final x = i * barWidth;
      final y = (size.height - barHeight) / 2;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.8),
            color,
          ],
        ).createShader(Rect.fromLTWH(x, y, barWidth - 1, barHeight));

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 1, y, barWidth - 2, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rrect, paint);

      // Glow effect for high bands
      if (bands[i] > 0.7) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRRect(rrect, glowPaint);
      }
    }

    // Center line
    final linePaint = Paint()
      ..color = SentinelColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.bands != bands || oldDelegate.color != color;
}

// ─────────────────────────────────────────────────
// AUDIO EVENT TIMELINE
// ─────────────────────────────────────────────────

class _AudioEventTimeline extends ConsumerWidget {
  const _AudioEventTimeline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(audioEventsAccumulatorProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionHeader(
            title: 'Audio Event Log',
            icon: Icons.history_rounded,
            trailing: Text(
              '${events.length} events',
              style: SentinelTypography.monoSmall,
            ),
          ),
          const SizedBox(height: SentinelSpacing.sm),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SentinelSpacing.xxl),
              child: Center(
                child: Text(
                  'No acoustic anomalies detected\n(Physical microphone actively monitoring)',
                  style: SentinelTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...events.take(20).map((event) => _AudioEventRow(event: event)),
        ],
      ),
    );
  }
}

class _AudioEventRow extends StatelessWidget {
  final AudioEvent event;
  const _AudioEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SentinelSpacing.sm,
        vertical: SentinelSpacing.xs + 2,
      ),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: event.threat.color.withValues(alpha: 0.04),
        borderRadius: SentinelRadius.smAll,
      ),
      child: Row(
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            size: 14,
            color: event.threat.color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.classification.toUpperCase().replaceAll('_', ' '),
                  style: SentinelTypography.titleMedium.copyWith(fontSize: 11),
                ),
                Text(
                  '${event.cameraId} • ${event.decibelLevel.toStringAsFixed(0)}dB • ${(event.confidence * 100).toStringAsFixed(0)}%',
                  style: SentinelTypography.labelSmall,
                ),
              ],
            ),
          ),
          ThreatBadge(level: event.threat, compact: true),
          const SizedBox(width: 6),
          Text(
            DateFormat('HH:mm:ss').format(event.timestamp),
            style: SentinelTypography.monoSmall.copyWith(fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// AUDIO CLASSIFICATION SUMMARY
// ─────────────────────────────────────────────────

class _AudioClassificationSummary extends ConsumerWidget {
  const _AudioClassificationSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(audioEventsAccumulatorProvider);

    // Count by classification
    final classCounts = <String, int>{};
    for (final e in events) {
      classCounts[e.classification] =
          (classCounts[e.classification] ?? 0) + 1;
    }

    final sortedClasses = classCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Classification Summary',
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: SentinelSpacing.sm),
          if (sortedClasses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SentinelSpacing.xl),
              child: Center(
                child: Text(
                  'No classifications yet\n(Awaiting ONNX anomaly verification)',
                  style: SentinelTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...sortedClasses.map((entry) {
              final maxCount = sortedClasses.first.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.toUpperCase().replaceAll('_', ' '),
                          style: SentinelTypography.labelSmall.copyWith(
                            color: SentinelColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: SentinelTypography.monoSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: SentinelRadius.smAll,
                      child: LinearProgressIndicator(
                        value: entry.value / maxCount,
                        backgroundColor: SentinelColors.bgDarkest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          SentinelColors.accent.withValues(alpha: 0.6),
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
