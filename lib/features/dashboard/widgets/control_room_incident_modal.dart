// SentinelX - Control Room Incident Action Modal
// Admin dialogue to inspect recorded incident video clip, analyze distress audio,
// and assign the incident to Police / Tactical Dispatch with a single click.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/features/dashboard/widgets/incident_video_player.dart';

class ControlRoomIncidentModal extends ConsumerWidget {
  final DistressIncident incident;

  const ControlRoomIncidentModal({
    super.key,
    required this.incident,
  });

  static void show(BuildContext context, DistressIncident incident) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ControlRoomIncidentModal(incident: incident),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 720,
        decoration: BoxDecoration(
          color: SentinelColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SentinelColors.threatCritical, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: SentinelColors.threatCritical.withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: SentinelColors.threatCritical.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                border: Border(
                  bottom: BorderSide(
                    color: SentinelColors.threatCritical.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SentinelColors.threatCritical,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'CONTROL ROOM // DISTRESS DISPATCH',
                          style: SentinelTypography.monoSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'INCIDENT ID: ${incident.id}',
                      style: SentinelTypography.monoSmall.copyWith(
                        color: SentinelColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: SentinelColors.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Modal Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Player
                  IncidentVideoPlayer(incident: incident),
                  const SizedBox(height: 16),

                  // Metadata Cards Row
                  Row(
                    children: [
                      // Location & Camera
                      Expanded(
                        child: _buildInfoTile(
                          icon: Icons.videocam_outlined,
                          title: 'CAMERA / LOCATION',
                          value: '${incident.cameraId} • ${incident.location}',
                          accentColor: SentinelColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Audio Transcript
                      Expanded(
                        child: _buildInfoTile(
                          icon: Icons.record_voice_over,
                          title: 'ACOUSTIC SIGNATURE',
                          value: incident.audioTranscript,
                          accentColor: SentinelColors.threatCritical,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Status
                      Expanded(
                        child: _buildInfoTile(
                          icon: Icons.local_police_outlined,
                          title: 'DISPATCH STATUS',
                          value: incident.status.label,
                          accentColor: incident.isAssignedToPolice
                              ? const Color(0xFF2979FF)
                              : SentinelColors.threatCritical,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action Bar
                  Row(
                    children: [
                      // Dismiss button
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(incidentDispatchProvider.notifier).dismissIncident(incident.id);
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('DISMISS / FALSE ALARM'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SentinelColors.textSecondary,
                          side: const BorderSide(color: SentinelColors.glassBorder),
                        ),
                      ),
                      const Spacer(),
                      // Assign to Police Button
                      ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(incidentDispatchProvider.notifier)
                              .assignToPolice(incident.id);
                          Navigator.of(context).pop();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF1E88E5),
                              content: Row(
                                children: [
                                  const Icon(Icons.local_police, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'INCIDENT ${incident.id} ASSIGNED TO POLICE DISPATCH UNIT #104!',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ref.read(currentPageProvider.notifier).state = AppPage.police;
                                    },
                                    child: const Text('VIEW POLICE PAGE',
                                        style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
                                  ),
                                ],
                              ),
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        },
                        icon: const Icon(Icons.local_police, color: Colors.white),
                        label: Text(
                          incident.isAssignedToPolice
                              ? 'RE-ESCALATE TO POLICE'
                              : 'ASSIGN TO POLICE DISPATCH',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2979FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SentinelColors.bgSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SentinelColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: SentinelTypography.monoSmall.copyWith(
                  color: SentinelColors.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: SentinelTypography.bodySmall.copyWith(
              color: SentinelColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
