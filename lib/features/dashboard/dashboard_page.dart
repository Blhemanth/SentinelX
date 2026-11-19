// SentinelX - Dashboard Page
// The main command center view showing real-time threat overview,
// system metrics, detection feed, and threat timeline.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/models/models.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/shared/widgets/sentinel_widgets.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1000;

    return Container(
      decoration: const BoxDecoration(
        gradient: SentinelGradients.surfaceGradient,
      ),
      child: CustomScrollView(
        slivers: [
          // Top bar
          SliverToBoxAdapter(child: _DashboardHeader()),
          // Metrics row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SentinelSpacing.base,
              ),
              child: _MetricsRow(),
            ),
          ),
          // Main content
          SliverPadding(
            padding: const EdgeInsets.all(SentinelSpacing.base),
            sliver: SliverToBoxAdapter(
              child: isWide
                  ? _WideLayout()
                  : _NarrowLayout(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────

class _DashboardHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(inferenceRunningProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        SentinelSpacing.base, SentinelSpacing.lg,
        SentinelSpacing.base, SentinelSpacing.md,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Command Center', style: SentinelTypography.displayMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  PulsingDot(
                    color: isRunning
                        ? SentinelColors.statusOnline
                        : SentinelColors.statusOffline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRunning
                        ? 'INFERENCE ACTIVE • ${DateFormat('HH:mm:ss').format(DateTime.now())}'
                        : 'INFERENCE STOPPED',
                    style: SentinelTypography.monoSmall.copyWith(
                      color: isRunning
                          ? SentinelColors.statusOnline
                          : SentinelColors.statusOffline,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          SentinelButton(
            label: isRunning ? 'Pause' : 'Resume',
            icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
            isPrimary: !isRunning,
            isCompact: true,
            onPressed: () {
              final engine = ref.read(inferenceEngineProvider);
              if (isRunning) {
                engine.stop();
              } else {
                engine.start();
              }
              ref.read(inferenceRunningProvider.notifier).state = !isRunning;
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// METRICS ROW
// ─────────────────────────────────────────────────

class _MetricsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(metricsStreamProvider);

    return metricsAsync.when(
      data: (metrics) => _buildMetrics(metrics),
      loading: () => _buildMetrics(null),
      error: (_, _) => _buildMetrics(null),
    );
  }

  Widget _buildMetrics(SystemMetrics? metrics) {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 1000
          ? 5
          : constraints.maxWidth > 600
              ? 3
              : 2;

      return Wrap(
        spacing: SentinelSpacing.md,
        runSpacing: SentinelSpacing.md,
        children: [
          _metricItem(
            constraints.maxWidth,
            crossAxisCount,
            'Active Cameras',
            '${metrics?.activeCameras ?? 0}',
            Icons.videocam_outlined,
            SentinelColors.accent,
          ),
          _metricItem(
            constraints.maxWidth,
            crossAxisCount,
            'Total Detections',
            '${metrics?.totalDetections ?? 0}',
            Icons.center_focus_strong_outlined,
            SentinelColors.primary,
          ),
          _metricItem(
            constraints.maxWidth,
            crossAxisCount,
            'Active Alerts',
            '${metrics?.activeAlerts ?? 0}',
            Icons.warning_amber_rounded,
            SentinelColors.threatHigh,
          ),
          _metricItem(
            constraints.maxWidth,
            crossAxisCount,
            'Inference Latency',
            '${metrics?.inferenceLatencyMs.toStringAsFixed(1) ?? '—'}ms',
            Icons.speed_outlined,
            SentinelColors.statusOnline,
          ),
          _metricItem(
            constraints.maxWidth,
            crossAxisCount,
            'FPS Processed',
            '${metrics?.framesProcessedPerSec ?? 0}',
            Icons.auto_graph_outlined,
            SentinelColors.primaryLight,
            progress: (metrics?.framesProcessedPerSec ?? 0) / 120,
          ),
        ],
      );
    });
  }

  Widget _metricItem(double totalWidth, int crossAxisCount, String label,
      String value, IconData icon, Color color, {double? progress}) {
    final itemWidth =
        (totalWidth - (crossAxisCount - 1) * SentinelSpacing.md) / crossAxisCount;

    return SizedBox(
      width: itemWidth,
      child: MetricTile(
        label: label,
        value: value,
        icon: icon,
        accentColor: color,
        progress: progress,
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// WIDE LAYOUT (desktop two-column)
// ─────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Threat Timeline + System Performance
        Expanded(
          flex: 3,
          child: Column(
            children: [
              const _ThreatTimelineCard(),
              const SizedBox(height: SentinelSpacing.md),
              const _SystemPerformanceCard(),
            ],
          ),
        ),
        const SizedBox(width: SentinelSpacing.md),
        // Right: Detection Feed + Recent Alerts
        Expanded(
          flex: 2,
          child: Column(
            children: [
              const _DetectionFeedCard(),
              const SizedBox(height: SentinelSpacing.md),
              const _RecentAlertsCard(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// NARROW LAYOUT (mobile single-column)
// ─────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ThreatTimelineCard(),
        SizedBox(height: SentinelSpacing.md),
        _DetectionFeedCard(),
        SizedBox(height: SentinelSpacing.md),
        _RecentAlertsCard(),
        SizedBox(height: SentinelSpacing.md),
        _SystemPerformanceCard(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// THREAT TIMELINE CHART
// ─────────────────────────────────────────────────

class _ThreatTimelineCard extends ConsumerWidget {
  const _ThreatTimelineCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(threatTimelineProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Threat Timeline',
            icon: Icons.timeline_outlined,
          ),
          const SizedBox(height: SentinelSpacing.sm),
          SizedBox(
            height: 200,
            child: timeline.length < 3
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 32,
                          color: SentinelColors.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Collecting data...',
                          style: SentinelTypography.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 0.25,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: SentinelColors.border.withValues(alpha: 0.3),
                          strokeWidth: 0.5,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 0.25,
                            getTitlesWidget: (value, meta) {
                              final label = switch (value) {
                                0.0 => 'SAFE',
                                0.5 => 'MED',
                                1.0 => 'CRIT',
                                _ => '',
                              };
                              return Text(
                                label,
                                style: SentinelTypography.labelSmall,
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (timeline.length - 1).toDouble(),
                      minY: 0,
                      maxY: 1,
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            timeline.length,
                            (i) => FlSpot(
                              i.toDouble(),
                              timeline[i].threatScore,
                            ),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          gradient: SentinelGradients.threatGradient,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                SentinelColors.threatCritical
                                    .withValues(alpha: 0.2),
                                SentinelColors.threatLow
                                    .withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 200),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// DETECTION FEED
// ─────────────────────────────────────────────────

class _DetectionFeedCard extends ConsumerWidget {
  const _DetectionFeedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detections = ref.watch(detectionsAccumulatorProvider);
    final recent = detections.take(15).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionHeader(
            title: 'Live Detection Feed',
            icon: Icons.center_focus_strong_outlined,
            trailing: Text(
              '${detections.length} total',
              style: SentinelTypography.monoSmall,
            ),
          ),
          const SizedBox(height: SentinelSpacing.sm),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SentinelSpacing.xxl),
              child: Center(
                child: Text(
                  'No detections yet',
                  style: SentinelTypography.bodyMedium,
                ),
              ),
            )
          else
            ...recent.map((d) => _DetectionRow(detection: d)),
        ],
      ),
    );
  }
}

class _DetectionRow extends StatelessWidget {
  final Detection detection;
  const _DetectionRow({required this.detection});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SentinelSpacing.sm,
        vertical: SentinelSpacing.xs + 2,
      ),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: detection.threat.color.withValues(alpha: 0.04),
        borderRadius: SentinelRadius.smAll,
      ),
      child: Row(
        children: [
          Icon(detection.type.icon, size: 16, color: detection.threat.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detection.type.label,
                  style: SentinelTypography.titleMedium.copyWith(
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${detection.cameraId} • ${(detection.confidence * 100).toStringAsFixed(0)}%',
                  style: SentinelTypography.labelSmall,
                ),
              ],
            ),
          ),
          ThreatBadge(level: detection.threat, compact: true),
          const SizedBox(width: 6),
          Text(
            DateFormat('HH:mm:ss').format(detection.timestamp),
            style: SentinelTypography.monoSmall.copyWith(fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// RECENT ALERTS
// ─────────────────────────────────────────────────

class _RecentAlertsCard extends ConsumerWidget {
  const _RecentAlertsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);
    final recent = alerts.take(8).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionHeader(
            title: 'Recent Alerts',
            icon: Icons.warning_amber_rounded,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (alerts.isNotEmpty)
                  PulsingDot(color: SentinelColors.threatCritical, size: 6),
                const SizedBox(width: 6),
                Text(
                  '${alerts.where((a) => !a.acknowledged).length} active',
                  style: SentinelTypography.monoSmall.copyWith(
                    color: SentinelColors.threatHigh,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SentinelSpacing.sm),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SentinelSpacing.xxl),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 28,
                      color: SentinelColors.statusOnline.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All clear',
                      style: SentinelTypography.bodyMedium.copyWith(
                        color: SentinelColors.statusOnline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recent.map((alert) => _AlertRow(alert: alert)),
        ],
      ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  final SecurityAlert alert;
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(SentinelSpacing.sm),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: alert.threatLevel.color.withValues(alpha: 0.06),
        borderRadius: SentinelRadius.smAll,
        border: alert.acknowledged
            ? null
            : Border.all(
                color: alert.threatLevel.color.withValues(alpha: 0.2),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: alert.threatLevel.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: SentinelTypography.titleMedium.copyWith(
                    fontSize: 12,
                    color: alert.acknowledged
                        ? SentinelColors.textTertiary
                        : null,
                    decoration: alert.acknowledged
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${alert.cameraName} • ${DateFormat('HH:mm:ss').format(alert.timestamp)}',
                  style: SentinelTypography.labelSmall,
                ),
              ],
            ),
          ),
          if (!alert.acknowledged)
            IconButton(
              onPressed: () {
                ref.read(alertsProvider.notifier).acknowledgeAlert(alert.id);
              },
              icon: Icon(
                Icons.check_circle_outline,
                size: 18,
                color: SentinelColors.statusOnline.withValues(alpha: 0.7),
              ),
              tooltip: 'Acknowledge',
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              padding: EdgeInsets.zero,
            )
          else
            Icon(
              Icons.check_circle,
              size: 16,
              color: SentinelColors.textMuted,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// SYSTEM PERFORMANCE
// ─────────────────────────────────────────────────

class _SystemPerformanceCard extends ConsumerWidget {
  const _SystemPerformanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(metricsStreamProvider);

    return metricsAsync.when(
      data: (metrics) => _buildCard(metrics),
      loading: () => _buildCard(null),
      error: (_, _) => _buildCard(null),
    );
  }

  Widget _buildCard(SystemMetrics? metrics) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'System Performance',
            icon: Icons.monitor_heart_outlined,
          ),
          const SizedBox(height: SentinelSpacing.sm),
          _PerformanceBar(
            label: 'CPU',
            value: metrics?.cpuUsage ?? 0,
            color: SentinelColors.primary,
          ),
          const SizedBox(height: SentinelSpacing.sm),
          _PerformanceBar(
            label: 'GPU',
            value: metrics?.gpuUsage ?? 0,
            color: SentinelColors.accent,
          ),
          const SizedBox(height: SentinelSpacing.sm),
          _PerformanceBar(
            label: 'RAM',
            value: metrics?.memoryUsage ?? 0,
            color: SentinelColors.primaryLight,
          ),
          const SizedBox(height: SentinelSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Network: ${metrics?.networkBandwidth.toStringAsFixed(0) ?? '—'} Mbps',
                style: SentinelTypography.monoSmall,
              ),
              Text(
                'Latency: ${metrics?.inferenceLatencyMs.toStringAsFixed(1) ?? '—'}ms',
                style: SentinelTypography.monoSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _PerformanceBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedValue = (value / 100).clamp(0.0, 1.0);
    final isHigh = value > 80;

    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: SentinelTypography.labelSmall.copyWith(
              color: SentinelColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: SentinelRadius.smAll,
            child: LinearProgressIndicator(
              value: normalizedValue,
              backgroundColor: SentinelColors.bgDarkest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isHigh ? SentinelColors.threatHigh : color,
              ),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(
            '${value.toStringAsFixed(0)}%',
            style: SentinelTypography.monoSmall.copyWith(
              color: isHigh ? SentinelColors.threatHigh : color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
