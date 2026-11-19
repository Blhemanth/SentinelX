// SentinelX - Police Tactical Dispatch Page
// Dedicated response interface for Police / Dispatch role.
// Receives incidents assigned from Control Room (Admin), plays recorded video clips,
// and updates dispatch response statuses in real time.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/core/services/incident_dispatch_repository.dart';
import 'package:sentinel_x/features/dashboard/widgets/incident_video_player.dart';
import 'package:sentinel_x/shared/widgets/sentinel_widgets.dart';

class PoliceDispatchPage extends ConsumerStatefulWidget {
  const PoliceDispatchPage({super.key});

  @override
  ConsumerState<PoliceDispatchPage> createState() => _PoliceDispatchPageState();
}

class _PoliceDispatchPageState extends ConsumerState<PoliceDispatchPage> {
  String _selectedFilter = 'ALL';
  String? _expandedIncidentId;

  @override
  Widget build(BuildContext context) {
    final incidents = ref.watch(policeAssignedIncidentsProvider);

    final filtered = switch (_selectedFilter) {
      'ACTIVE' => incidents.where((i) => !i.isResolved).toList(),
      'EN_ROUTE' => incidents.where((i) => i.status == DispatchStatus.enRoute).toList(),
      'RESOLVED' => incidents.where((i) => i.isResolved).toList(),
      _ => incidents,
    };

    final totalActive = incidents.where((i) => !i.isResolved).length;
    final totalEnRoute = incidents.where((i) => i.status == DispatchStatus.enRoute).length;
    final totalResolved = incidents.where((i) => i.isResolved).length;

    return Container(
      decoration: const BoxDecoration(
        gradient: SentinelGradients.surfaceGradient,
      ),
      child: CustomScrollView(
        slivers: [
          // Header Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2979FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2979FF)),
                    ),
                    child: const Icon(Icons.local_police, color: Color(0xFF2979FF), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POLICE TACTICAL DISPATCH',
                        style: SentinelTypography.headlineMedium.copyWith(
                          color: SentinelColors.textPrimary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Connected to SentinelX Control Room • Unit #104 Active',
                        style: SentinelTypography.bodySmall.copyWith(
                          color: SentinelColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Broadcast Emergency Trigger for quick testing
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(incidentDispatchProvider.notifier).triggerDistress(
                            cameraId: 'CAM-001',
                            customTranscript: 'Patrol Distress Alert: "HELP! HELP! OFFICER NEEDS ASSISTANCE"',
                          );
                    },
                    icon: const Icon(Icons.add_alert, size: 16),
                    label: const Text('SIMULATE DISTRESS ALERT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SentinelColors.threatCritical,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Metric Counters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildMetricCard(
                    title: 'ASSIGNED DISPATCHES',
                    value: '${incidents.length}',
                    color: const Color(0xFF2979FF),
                    icon: Icons.assignment_outlined,
                  ),
                  const SizedBox(width: 12),
                  _buildMetricCard(
                    title: 'ACTIVE EMERGENCIES',
                    value: '$totalActive',
                    color: SentinelColors.threatCritical,
                    icon: Icons.emergency_outlined,
                  ),
                  const SizedBox(width: 12),
                  _buildMetricCard(
                    title: 'PATROL EN ROUTE',
                    value: '$totalEnRoute',
                    color: SentinelColors.threatHigh,
                    icon: Icons.directions_car_filled_outlined,
                  ),
                  const SizedBox(width: 12),
                  _buildMetricCard(
                    title: 'RESOLVED & SECURED',
                    value: '$totalResolved',
                    color: SentinelColors.statusOnline,
                    icon: Icons.verified_user_outlined,
                  ),
                ],
              ),
            ),
          ),

          // Filter Pills
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  _buildFilterChip('ALL (${incidents.length})', 'ALL'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ACTIVE ($totalActive)', 'ACTIVE'),
                  const SizedBox(width: 8),
                  _buildFilterChip('EN ROUTE ($totalEnRoute)', 'EN_ROUTE'),
                  const SizedBox(width: 8),
                  _buildFilterChip('RESOLVED ($totalResolved)', 'RESOLVED'),
                ],
              ),
            ),
          ),

          // Incident Queue List
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_outlined, size: 48, color: SentinelColors.statusOnline),
                    const SizedBox(height: 12),
                    Text(
                      'No Dispatches in Selected Queue',
                      style: SentinelTypography.headlineMedium.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All sectors are clear and secured.',
                      style: SentinelTypography.bodyMedium.copyWith(color: SentinelColors.textTertiary),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final inc = filtered[index];
                    final isExpanded = _expandedIncidentId == inc.id;

                    return _buildIncidentCard(inc, isExpanded);
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: SentinelTypography.headlineLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: SentinelTypography.monoSmall.copyWith(
                    color: SentinelColors.textTertiary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2979FF) : SentinelColors.bgSurface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFF2979FF) : SentinelColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: SentinelTypography.monoSmall.copyWith(
            color: isSelected ? Colors.white : SentinelColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildIncidentCard(DistressIncident inc, bool isExpanded) {
    final statusColor = switch (inc.status) {
      DispatchStatus.pendingReview => SentinelColors.threatCritical,
      DispatchStatus.assignedToPolice => const Color(0xFF2979FF),
      DispatchStatus.enRoute => SentinelColors.threatHigh,
      DispatchStatus.onScene => SentinelColors.accent,
      DispatchStatus.resolved => SentinelColors.statusOnline,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: SentinelColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: inc.isResolved ? SentinelColors.glassBorder : statusColor.withValues(alpha: 0.6),
          width: inc.isResolved ? 1.0 : 1.5,
        ),
        boxShadow: inc.isResolved
            ? []
            : [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header Bar
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        inc.status.label,
                        style: SentinelTypography.monoSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${inc.threatType} // ${inc.id}',
                        style: SentinelTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: SentinelColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${inc.cameraId} • ${inc.location} • ${DateFormat('HH:mm:ss').format(inc.timestamp)}',
                        style: SentinelTypography.monoSmall.copyWith(
                          color: SentinelColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle Video Playback Button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _expandedIncidentId = isExpanded ? null : inc.id;
                    });
                  },
                  icon: Icon(
                    isExpanded ? Icons.videocam_off : Icons.play_circle_outline,
                    size: 16,
                  ),
                  label: Text(isExpanded ? 'HIDE VIDEO' : 'VIEW RECORDED VIDEO'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2979FF),
                    side: const BorderSide(color: Color(0xFF2979FF)),
                  ),
                ),
              ],
            ),
          ),

          // Acoustic Distress Quote
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: SentinelColors.bgSurface,
            child: Row(
              children: [
                const Icon(Icons.record_voice_over, color: SentinelColors.threatCritical, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inc.audioTranscript,
                    style: SentinelTypography.monoSmall.copyWith(
                      color: SentinelColors.threatCritical,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  '${inc.decibels.toStringAsFixed(1)} dB • ${(inc.confidence * 100).toStringAsFixed(0)}% MATCH',
                  style: SentinelTypography.monoSmall.copyWith(
                    color: SentinelColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Embedded Video Player (Shown if expanded or active)
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IncidentVideoPlayer(incident: inc),
                  const SizedBox(height: 8),
                  Text(
                    'Recorded 6-second forensic buffer captured at moment of acoustic trigger.',
                    style: SentinelTypography.monoSmall.copyWith(
                      color: SentinelColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

          // Assigned Unit & Police Actions
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.badge, size: 16, color: SentinelColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ASSIGNED: ${inc.assignedUnit ?? "Unit #104"}',
                    style: SentinelTypography.monoSmall.copyWith(
                      color: SentinelColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                // Police Action Buttons
                if (inc.status != DispatchStatus.resolved) ...[
                  if (inc.status == DispatchStatus.assignedToPolice)
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(incidentDispatchProvider.notifier).updatePoliceStatus(
                              inc.id,
                              DispatchStatus.enRoute,
                              notes: 'Patrol Unit #104 en route with sirens engaged. ETA 90s.',
                            );
                      },
                      icon: const Icon(Icons.directions_car, size: 14),
                      label: const Text('EN ROUTE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SentinelColors.threatHigh,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (inc.status == DispatchStatus.enRoute)
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(incidentDispatchProvider.notifier).updatePoliceStatus(
                              inc.id,
                              DispatchStatus.onScene,
                              notes: 'Patrol Unit #104 on scene at perimeter gate. Assessing subject.',
                            );
                      },
                      icon: const Icon(Icons.location_on, size: 14),
                      label: const Text('ON SCENE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SentinelColors.accent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(incidentDispatchProvider.notifier).updatePoliceStatus(
                            inc.id,
                            DispatchStatus.resolved,
                            notes: 'Subject assisted, sector secured and cleared. Incident neutralized.',
                          );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text('MARK RESOLVED & SECURE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SentinelColors.statusOnline,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: SentinelColors.statusOnline.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: SentinelColors.statusOnline),
                        const SizedBox(width: 6),
                        Text(
                          'INCIDENT NEUTRALIZED & SECURED',
                          style: SentinelTypography.monoSmall.copyWith(
                            color: SentinelColors.statusOnline,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
