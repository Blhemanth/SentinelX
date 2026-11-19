// SentinelX - Alerts Page
// Full-screen alerts management with filtering, priority badges,
// acknowledge/dismiss actions, and sorted by recency & severity.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/models/models.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/shared/widgets/sentinel_widgets.dart';

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ThreatLevel? _filterLevel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allAlerts = ref.watch(alertsProvider);

    final activeAlerts = allAlerts.where((a) => !a.acknowledged).toList();
    final acknowledgedAlerts = allAlerts.where((a) => a.acknowledged).toList();

    final filteredActive = _filterLevel != null
        ? activeAlerts.where((a) => a.threatLevel == _filterLevel).toList()
        : activeAlerts;
    final filteredAcknowledged = _filterLevel != null
        ? acknowledgedAlerts.where((a) => a.threatLevel == _filterLevel).toList()
        : acknowledgedAlerts;

    return Container(
      decoration: const BoxDecoration(
        gradient: SentinelGradients.surfaceGradient,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Text('Security Alerts', style: SentinelTypography.displayMedium),
                const Spacer(),
                if (allAlerts.isNotEmpty)
                  SentinelButton(
                    label: 'Clear All',
                    icon: Icons.clear_all_rounded,
                    isPrimary: false,
                    isCompact: true,
                    onPressed: () {
                      ref.read(alertsProvider.notifier).clearAll();
                    },
                  ),
              ],
            ),
          ),

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _filterLevel == null,
                  onTap: () => setState(() => _filterLevel = null),
                ),
                ...ThreatLevel.values.reversed
                    .where((t) => t != ThreatLevel.none)
                    .map((level) => _FilterChip(
                          label: level.label,
                          color: level.color,
                          isSelected: _filterLevel == level,
                          count: allAlerts
                              .where((a) => a.threatLevel == level)
                              .length,
                          onTap: () => setState(() => _filterLevel = level),
                        )),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: SentinelColors.bgCard,
              borderRadius: SentinelRadius.smAll,
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: SentinelColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: SentinelTypography.labelLarge,
              unselectedLabelColor: SentinelColors.textTertiary,
              dividerHeight: 0,
              tabs: [
                Tab(text: 'All (${allAlerts.length})'),
                Tab(text: 'Active (${filteredActive.length})'),
                Tab(text: 'Acknowledged (${filteredAcknowledged.length})'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Alert list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AlertList(
                  alerts: _filterLevel != null
                      ? allAlerts
                          .where((a) => a.threatLevel == _filterLevel)
                          .toList()
                      : allAlerts,
                ),
                _AlertList(alerts: filteredActive),
                _AlertList(alerts: filteredAcknowledged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.color,
    required this.isSelected,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (color ?? SentinelColors.primary).withValues(alpha: 0.15)
                : SentinelColors.bgCard,
            borderRadius: SentinelRadius.smAll,
            border: Border.all(
              color: isSelected
                  ? (color ?? SentinelColors.primary).withValues(alpha: 0.5)
                  : SentinelColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (color != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: SentinelTypography.labelSmall.copyWith(
                  color: isSelected
                      ? (color ?? SentinelColors.primary)
                      : SentinelColors.textTertiary,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: SentinelTypography.labelSmall.copyWith(
                    color: color ?? SentinelColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertList extends ConsumerWidget {
  final List<SecurityAlert> alerts;
  const _AlertList({required this.alerts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: SentinelColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No alerts',
              style: SentinelTypography.headlineMedium.copyWith(
                color: SentinelColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All clear — no threats detected',
              style: SentinelTypography.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: alerts.length,
      itemBuilder: (context, index) => _AlertCard(alert: alerts[index]),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  final SecurityAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        borderColor: alert.acknowledged
            ? null
            : alert.threatLevel.color.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: alert.threatLevel.color.withValues(alpha: 0.12),
                    borderRadius: SentinelRadius.smAll,
                  ),
                  child: Icon(
                    alert.detectionType.icon,
                    color: alert.threatLevel.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: SentinelTypography.titleMedium.copyWith(
                          decoration: alert.acknowledged
                              ? TextDecoration.lineThrough
                              : null,
                          color: alert.acknowledged
                              ? SentinelColors.textTertiary
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${alert.cameraName} • ${DateFormat('MMM dd, HH:mm:ss').format(alert.timestamp)}',
                        style: SentinelTypography.labelSmall,
                      ),
                    ],
                  ),
                ),
                ThreatBadge(level: alert.threatLevel),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              alert.description,
              style: SentinelTypography.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!alert.acknowledged) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SentinelButton(
                    label: 'Acknowledge',
                    icon: Icons.check_circle_outline,
                    isCompact: true,
                    color: SentinelColors.statusOnline,
                    onPressed: () {
                      ref
                          .read(alertsProvider.notifier)
                          .acknowledgeAlert(alert.id);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
