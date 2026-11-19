// SentinelX - Analytics Page
// Visualization dashboard with detection type distribution,
// threat level history, camera activity heatmap, and detection trends.

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/models/models.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/shared/widgets/sentinel_widgets.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                'Analytics & Insights',
                style: SentinelTypography.displayMedium,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(SentinelSpacing.base),
            sliver: SliverToBoxAdapter(
              child: isWide
                  ? _WideAnalytics()
                  : _NarrowAnalytics(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideAnalytics extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(child: _DetectionDistributionChart()),
            const SizedBox(width: SentinelSpacing.md),
            const Expanded(child: _ThreatLevelPieChart()),
          ],
        ),
        const SizedBox(height: SentinelSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(flex: 3, child: _DetectionTrendChart()),
            const SizedBox(width: SentinelSpacing.md),
            const Expanded(flex: 2, child: _CameraActivityList()),
          ],
        ),
      ],
    );
  }
}

class _NarrowAnalytics extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _DetectionDistributionChart(),
        SizedBox(height: SentinelSpacing.md),
        _ThreatLevelPieChart(),
        SizedBox(height: SentinelSpacing.md),
        _DetectionTrendChart(),
        SizedBox(height: SentinelSpacing.md),
        _CameraActivityList(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// DETECTION TYPE DISTRIBUTION (Bar Chart)
// ─────────────────────────────────────────────────

class _DetectionDistributionChart extends ConsumerWidget {
  const _DetectionDistributionChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detections = ref.watch(detectionsAccumulatorProvider);

    // Count by detection type
    final typeCounts = <DetectionType, int>{};
    for (final d in detections) {
      typeCounts[d.type] = (typeCounts[d.type] ?? 0) + 1;
    }

    final sortedEntries = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final displayEntries = sortedEntries.take(8).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Detection Distribution',
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: SentinelSpacing.md),
          SizedBox(
            height: 220,
            child: displayEntries.isEmpty
                ? Center(
                    child: Text(
                      'Accumulating data...',
                      style: SentinelTypography.bodyMedium,
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (displayEntries.isNotEmpty
                              ? displayEntries.first.value.toDouble()
                              : 10) *
                          1.2,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => SentinelColors.bgElevated,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex < displayEntries.length) {
                              return BarTooltipItem(
                                '${displayEntries[groupIndex].key.label}\n${rod.toY.toInt()}',
                                SentinelTypography.bodySmall.copyWith(
                                  color: SentinelColors.textPrimary,
                                ),
                              );
                            }
                            return null;
                          },
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
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, _) => Text(
                              value.toInt().toString(),
                              style: SentinelTypography.labelSmall,
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, _) {
                              final idx = value.toInt();
                              if (idx < displayEntries.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    displayEntries[idx]
                                        .key
                                        .label
                                        .substring(0, min(3, displayEntries[idx].key.label.length)),
                                    style: SentinelTypography.labelSmall
                                        .copyWith(fontSize: 8),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: SentinelColors.border.withValues(alpha: 0.2),
                          strokeWidth: 0.5,
                        ),
                      ),
                      barGroups: List.generate(
                        displayEntries.length,
                        (i) => BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: displayEntries[i].value.toDouble(),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  displayEntries[i].key.defaultThreat.color
                                      .withValues(alpha: 0.6),
                                  displayEntries[i].key.defaultThreat.color,
                                ],
                              ),
                              width: 14,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// THREAT LEVEL PIE CHART
// ─────────────────────────────────────────────────

class _ThreatLevelPieChart extends ConsumerWidget {
  const _ThreatLevelPieChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detections = ref.watch(detectionsAccumulatorProvider);

    final threatCounts = <ThreatLevel, int>{};
    for (final d in detections) {
      threatCounts[d.threat] = (threatCounts[d.threat] ?? 0) + 1;
    }

    final total = detections.length;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Threat Level Breakdown',
            icon: Icons.pie_chart_outline_rounded,
          ),
          const SizedBox(height: SentinelSpacing.md),
          SizedBox(
            height: 220,
            child: total == 0
                ? Center(
                    child: Text(
                      'No data yet',
                      style: SentinelTypography.bodyMedium,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                            sections: ThreatLevel.values.map((level) {
                              final count = threatCounts[level] ?? 0;
                              if (count == 0) {
                                return PieChartSectionData(
                                  value: 0,
                                  showTitle: false,
                                  radius: 0,
                                );
                              }
                              final pct = (count / total * 100);
                              return PieChartSectionData(
                                value: count.toDouble(),
                                title: '${pct.toStringAsFixed(0)}%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                color: level.color,
                                radius: 50,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: SentinelSpacing.md),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: ThreatLevel.values.reversed.map((level) {
                          final count = threatCounts[level] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: level.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${level.label}: $count',
                                  style: SentinelTypography.bodySmall,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// DETECTION TREND (Line Chart over time)
// ─────────────────────────────────────────────────

class _DetectionTrendChart extends ConsumerWidget {
  const _DetectionTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(threatTimelineProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Detection Trend',
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: SentinelSpacing.md),
          SizedBox(
            height: 200,
            child: timeline.length < 3
                ? Center(
                    child: Text(
                      'Building trend data...',
                      style: SentinelTypography.bodyMedium,
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: SentinelColors.border.withValues(alpha: 0.2),
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
                            reservedSize: 28,
                            getTitlesWidget: (value, _) => Text(
                              value.toInt().toString(),
                              style: SentinelTypography.labelSmall,
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (timeline.length - 1).toDouble(),
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            timeline.length,
                            (i) => FlSpot(
                              i.toDouble(),
                              timeline[i].detectionCount.toDouble(),
                            ),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: SentinelColors.accent,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                SentinelColors.accent.withValues(alpha: 0.15),
                                SentinelColors.accent.withValues(alpha: 0.01),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 250),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// CAMERA ACTIVITY LIST
// ─────────────────────────────────────────────────

class _CameraActivityList extends ConsumerWidget {
  const _CameraActivityList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameras = ref.watch(cameraFeedsProvider);
    final detections = ref.watch(detectionsAccumulatorProvider);

    // Count detections per camera
    final cameraCounts = <String, int>{};
    for (final d in detections) {
      cameraCounts[d.cameraId] = (cameraCounts[d.cameraId] ?? 0) + 1;
    }

    final sortedCameras = cameras.toList()
      ..sort((a, b) =>
          (cameraCounts[b.id] ?? 0).compareTo(cameraCounts[a.id] ?? 0));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Camera Activity',
            icon: Icons.videocam_outlined,
          ),
          const SizedBox(height: SentinelSpacing.sm),
          ...sortedCameras.take(8).map((camera) {
            final count = cameraCounts[camera.id] ?? 0;
            final maxCount = cameraCounts.values.isEmpty
                ? 1
                : cameraCounts.values.reduce(max);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CameraStatusDot(status: camera.status, size: 8),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: Text(
                      camera.id,
                      style: SentinelTypography.monoSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: SentinelRadius.smAll,
                      child: LinearProgressIndicator(
                        value: maxCount > 0 ? count / maxCount : 0,
                        backgroundColor: SentinelColors.bgDarkest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          SentinelColors.accent.withValues(alpha: 0.7),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$count',
                      style: SentinelTypography.monoSmall,
                      textAlign: TextAlign.right,
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
