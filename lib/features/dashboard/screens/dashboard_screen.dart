// SentinelX - Adaptive Dashboard Screen
// Automatically switches between Windows Desktop Command Center (>=900px)
// and Android Mobile Field Patrol (<900px).
// Powered by real-time streams from MockInferenceService.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/features/settings/screens/model_settings_screen.dart';
import 'package:sentinel_x/shared/widgets/sentinel_widgets.dart';
import 'package:sentinel_x/features/dashboard/widgets/bounding_box_overlay.dart';
import 'package:sentinel_x/features/camera/widgets/hardware_camera_view.dart';
import 'package:sentinel_x/features/camera/widgets/phone_camera_stream_view.dart';
import 'package:sentinel_x/features/dashboard/widgets/control_room_incident_modal.dart';

// ─────────────────────────────────────────────────
// ROOT ADAPTIVE DASHBOARD SCREEN
// ─────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedCameraId = 'CAM-001';
  int _mobileTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return _WindowsDesktopDashboard(
            selectedCameraId: _selectedCameraId,
            onCameraSelected: (id) => setState(() => _selectedCameraId = id),
          );
        } else {
          return _AndroidMobileDashboard(
            selectedCameraId: _selectedCameraId,
            onCameraSelected: (id) => setState(() => _selectedCameraId = id),
            currentTab: _mobileTabIndex,
            onTabChanged: (index) => setState(() => _mobileTabIndex = index),
          );
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────
// WINDOWS DESKTOP DASHBOARD (Width >= 900px)
// ─────────────────────────────────────────────────

class _WindowsDesktopDashboard extends ConsumerWidget {
  final String selectedCameraId;
  final ValueChanged<String> onCameraSelected;

  const _WindowsDesktopDashboard({
    required this.selectedCameraId,
    required this.onCameraSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryAsync = ref.watch(telemetryStreamProvider);
    final payloadAsync = ref.watch(activeInferencePayloadStreamProvider);
    final recentAlerts = ref.watch(recentInferenceAlertsProvider);

    final telemetry = telemetryAsync.value ??
        const TelemetryData(
          fps: 60.0,
          latencyMs: 14,
          cpuUsage: 21.0,
          vramUsageGb: 1.55,
        );

    final payload = payloadAsync.value;
    final repoAsync = ref.watch(inferenceRepositoryStateProvider);
    final repoState = repoAsync.value ?? ref.watch(inferenceRepositoryProvider).state;

    return Scaffold(
      backgroundColor: SentinelColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: SentinelGradients.surfaceGradient,
        ),
      child: Column(
        children: [
          // 1. Header Telemetry Bar
          _HeaderTelemetryBar(telemetry: telemetry),

          // Simulation Mode Warning Banner
          if (repoState.showSimulationBanner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: SentinelColors.threatMedium.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: SentinelColors.threatMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      repoState.bannerMessage,
                      style: SentinelTypography.bodySmall.copyWith(
                        color: SentinelColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ModelSettingsScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      'Configure Model',
                      style: SentinelTypography.labelSmall.copyWith(
                        color: SentinelColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref
                        .read(inferenceRepositoryProvider)
                        .dismissBanner(),
                    icon: const Icon(Icons.close, size: 16),
                    color: SentinelColors.textTertiary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: SentinelColors.divider),

          // Main Desktop Body: Multi-Camera + Audio/Threat + Incident Log Sidebar
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left & Center Panes: Surveillance Grid & Threat/Audio Panel
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: const EdgeInsets.all(SentinelSpacing.base),
                    child: Column(
                      children: [
                        // Multi-Camera Grid
                        Expanded(
                          flex: 6,
                          child: _MultiCameraGrid(
                            selectedCameraId: selectedCameraId,
                            onCameraSelected: onCameraSelected,
                            currentPayload: payload,
                          ),
                        ),
                        const SizedBox(height: SentinelSpacing.base),
                        // Audio Spectrogram & Threat Confidence Panel
                        Expanded(
                          flex: 4,
                          child: _AudioAndThreatPanel(
                            payload: payload,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Vertical Divider
                Container(width: 1, color: SentinelColors.divider),

                // Right Pane: Incident Log Sidebar
                SizedBox(
                  width: 360,
                  child: _IncidentLogSidebar(
                    alerts: recentAlerts,
                    onAcknowledge: (alert) {
                      ref
                          .read(recentInferenceAlertsProvider.notifier)
                          .removeAlert(alert);
                    },
                    onClearAll: () {
                      ref
                          .read(recentInferenceAlertsProvider.notifier)
                          .clearAll();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

// ─────────────────────────────────────────────────
// HEADER TELEMETRY BAR (Desktop)
// ─────────────────────────────────────────────────

class _HeaderTelemetryBar extends ConsumerWidget {
  final TelemetryData telemetry;

  const _HeaderTelemetryBar({required this.telemetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(inferenceRepositoryStateProvider);
    final repoState = repoAsync.value ?? ref.watch(inferenceRepositoryProvider).state;
    final isNative = repoState.isModelLoaded;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: SentinelSpacing.lg),
      color: SentinelColors.bgDark.withValues(alpha: 0.90),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          // Connection Status
          PulsingDot(
            color: isNative ? SentinelColors.statusOnline : SentinelColors.threatMedium,
            size: 8,
          ),
          const SizedBox(width: SentinelSpacing.sm),
          Text(
            isNative ? 'SYSTEM ARMED // LIVE ONNX' : 'SYSTEM ARMED // SIMULATION',
            style: SentinelTypography.monoSmall.copyWith(
              color: isNative ? SentinelColors.statusOnline : SentinelColors.threatMedium,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: SentinelSpacing.md),
          // Clickable Execution Provider Tag
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ModelSettingsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SentinelColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: SentinelColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isNative
                        ? repoState.metadata.executionProvider.displayName.split(' ').first
                        : 'Simulation EP',
                    style: SentinelTypography.labelSmall.copyWith(
                      color: SentinelColors.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.settings, size: 10, color: SentinelColors.accent),
                ],
              ),
            ),
          ),
          const SizedBox(width: SentinelSpacing.md),

          // Active Stream Feeds Count Badge
          _TelemetryBadge(
            icon: Icons.camera_indoor_outlined,
            label: 'FEEDS',
            value: '${telemetry.activeCameras} ARMED',
            color: SentinelColors.accent,
          ),
          const SizedBox(width: SentinelSpacing.md),

          // Video Feed Source Metric
          _TelemetryBadge(
            icon: Icons.videocam_outlined,
            label: 'FEED',
            value: 'WEBCAM // DIRECTSHOW',
            color: SentinelColors.statusOnline,
          ),
          const SizedBox(width: SentinelSpacing.md),

          // FPS Metric
          _TelemetryBadge(
            icon: Icons.speed_rounded,
            label: 'FPS',
            value: telemetry.fps.toStringAsFixed(1),
            color: SentinelColors.accent,
          ),
          const SizedBox(width: SentinelSpacing.md),

          // Latency Metric
          _TelemetryBadge(
            icon: Icons.timer_outlined,
            label: 'LATENCY',
            value: '${telemetry.latencyMs}ms',
            color: SentinelColors.threatLow,
          ),
          const SizedBox(width: SentinelSpacing.md),

          // CPU Metric
          _TelemetryMetricBar(
            label: 'CPU',
            valueText: '${telemetry.cpuUsage.toStringAsFixed(1)}%',
            ratio: (telemetry.cpuUsage / 100.0).clamp(0.0, 1.0),
            color: SentinelColors.primary,
          ),
          const SizedBox(width: SentinelSpacing.md),

          // VRAM Metric
          _TelemetryMetricBar(
            label: 'VRAM',
            valueText:
                '${telemetry.vramUsageGb.toStringAsFixed(2)} / ${telemetry.totalVramGb.toStringAsFixed(0)} GB',
            ratio: (telemetry.vramUsageGb / telemetry.totalVramGb).clamp(0.0, 1.0),
            color: SentinelColors.threatMedium,
          ),
        ],
      ),
    ),
  );
}
}

class _TelemetryBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TelemetryBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: SentinelTypography.monoSmall.copyWith(
            color: SentinelColors.textTertiary,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: SentinelTypography.monoSmall.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TelemetryMetricBar extends StatelessWidget {
  final String label;
  final String valueText;
  final double ratio;
  final Color color;

  const _TelemetryMetricBar({
    required this.label,
    required this.valueText,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: SentinelTypography.monoSmall.copyWith(
            color: SentinelColors.textTertiary,
            fontSize: 10,
          ),
        ),
        SizedBox(
          width: 50,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: SentinelColors.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          valueText,
          style: SentinelTypography.monoSmall.copyWith(
            color: SentinelColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// MULTI-CAMERA SURVEILLANCE GRID (Desktop)
// ─────────────────────────────────────────────────

class _MultiCameraGrid extends ConsumerWidget {
  final String selectedCameraId;
  final ValueChanged<String> onCameraSelected;
  final InferencePayload? currentPayload;

  const _MultiCameraGrid({
    required this.selectedCameraId,
    required this.onCameraSelected,
    required this.currentPayload,
  });

  static const _cameras = [
    {'id': 'CAM-001', 'name': 'Laptop Camera 1 (Local Hardware Webcam)'},
    {'id': 'CAM-002', 'name': 'Phone Camera 2 (Wireless IP Stream)'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePayload =
        (currentPayload?.sourceCameraId == selectedCameraId) ? currentPayload : null;

    final selectedCamInfo = _cameras.firstWhere(
      (c) => c['id'] == selectedCameraId,
      orElse: () => _cameras[0],
    );

    final pendingDistress = ref.watch(activeDistressBannerProvider);

    return GlassCard(
      padding: const EdgeInsets.all(SentinelSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              const Icon(Icons.videocam_outlined,
                  size: 18, color: SentinelColors.accent),
              const SizedBox(width: SentinelSpacing.sm),
              Expanded(
                child: Text(
                  'SURVEILLANCE FEED // ${selectedCamInfo['id']} • ${selectedCamInfo['name']}',
                  style: SentinelTypography.headlineMedium.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: SentinelSpacing.sm),
              if (activePayload != null && !activePayload.isNormal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: activePayload.threatColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: activePayload.threatColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PulsingDot(
                        color: SentinelColors.threatCritical,
                        size: 6,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'FLAGGED: ${activePayload.threatType.toUpperCase()} (${(activePayload.confidence * 100).toStringAsFixed(1)}%)',
                        style: SentinelTypography.monoSmall.copyWith(
                          color: activePayload.threatColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PulsingDot(
                        color: SentinelColors.statusOnline, size: 6),
                    const SizedBox(width: 6),
                    Text(
                      'FEED LIVE • 1080P @ 30 FPS',
                      style: SentinelTypography.monoSmall.copyWith(
                        color: SentinelColors.statusOnline,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Camera Selector Pills (CAM-001 vs CAM-002)
          Row(
            children: _cameras.map((c) {
              final isSel = c['id'] == selectedCameraId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onCameraSelected(c['id']!),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSel ? SentinelColors.accent.withValues(alpha: 0.2) : SentinelColors.bgSurface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSel ? SentinelColors.accent : SentinelColors.glassBorder,
                        width: isSel ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          c['id'] == 'CAM-002' ? Icons.phone_android : Icons.laptop_chromebook,
                          size: 13,
                          color: isSel ? SentinelColors.accent : SentinelColors.textTertiary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${c['id']} // ${c['id'] == 'CAM-002' ? "PHONE CAM" : "LAPTOP WEBCAM"}',
                          style: SentinelTypography.monoSmall.copyWith(
                            color: isSel ? SentinelColors.accent : SentinelColors.textSecondary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // Acoustic Distress Voice Trigger Bar ("HELP, HELP")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E88E5).withValues(alpha: 0.18),
                  SentinelColors.threatCritical.withValues(alpha: 0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: SentinelColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.mic, color: SentinelColors.accent, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ACOUSTIC SURVEILLANCE: Say "HELP, HELP" or tap trigger to record incident clip for Control Room & Police',
                    style: SentinelTypography.monoSmall.copyWith(
                      color: SentinelColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    ref.read(incidentDispatchProvider.notifier).triggerDistress(
                      cameraId: selectedCameraId,
                      cameraName: selectedCamInfo['name'],
                    );
                    ref.read(mockInferenceServiceProvider).triggerTestThreat('Acoustic Distress: HELP, HELP');
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SentinelColors.threatCritical,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.record_voice_over, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'TRIGGER "HELP, HELP"',
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
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Control Room Emergency Incident Banner (shown if an incident is awaiting review)
          if (pendingDistress != null && pendingDistress.status == DispatchStatus.pendingReview) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SentinelColors.threatCritical.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: SentinelColors.threatCritical, width: 1.5),
              ),
              child: Row(
                children: [
                  const PulsingDot(color: SentinelColors.threatCritical, size: 8),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🚨 CONTROL ROOM ALERT: ${pendingDistress.threatType} on ${pendingDistress.cameraId}',
                      style: SentinelTypography.monoSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ControlRoomIncidentModal.show(context, pendingDistress);
                    },
                    icon: const Icon(Icons.play_circle_fill, size: 12),
                    label: const Text('VIEW RECORDED CLIP & ASSIGN TO POLICE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SentinelColors.threatCritical,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Threat Drill & Verification Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SentinelColors.bgDark.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SentinelColors.glassBorder),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'DRILL INJECTOR:',
                    style: SentinelTypography.monoSmall.copyWith(
                      color: SentinelColors.textTertiary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildDrillChip(
                    label: 'NORMAL // SECURE',
                    color: SentinelColors.statusOnline,
                    icon: Icons.shield,
                    isSelected: activePayload?.isNormal ?? true,
                    onTap: () {
                      ref.read(mockInferenceServiceProvider).clearTestThreat();
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildDrillChip(
                    label: '🎙️ HELP, HELP (VOICE DISTRESS)',
                    color: SentinelColors.threatCritical,
                    icon: Icons.record_voice_over,
                    isSelected: activePayload?.threatType.contains('HELP') ?? false,
                    onTap: () {
                      ref.read(incidentDispatchProvider.notifier).triggerDistress(
                        cameraId: selectedCameraId,
                        cameraName: selectedCamInfo['name'],
                      );
                      ref.read(mockInferenceServiceProvider).triggerTestThreat('Acoustic Distress: HELP, HELP');
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildDrillChip(
                    label: 'WEAPON DETECTED',
                    color: SentinelColors.threatCritical,
                    icon: Icons.warning_rounded,
                    isSelected: activePayload?.threatType == 'Weapon Detected',
                    onTap: () {
                      ref.read(mockInferenceServiceProvider).triggerTestThreat('Weapon Detected');
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildDrillChip(
                    label: 'FIGHTING',
                    color: SentinelColors.threatHigh,
                    icon: Icons.sports_kabaddi,
                    isSelected: activePayload?.threatType == 'Fighting',
                    onTap: () {
                      ref.read(mockInferenceServiceProvider).triggerTestThreat('Fighting');
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildDrillChip(
                    label: 'EXPLOSION',
                    color: SentinelColors.threatCritical,
                    icon: Icons.local_fire_department,
                    isSelected: activePayload?.threatType == 'Explosion',
                    onTap: () {
                      ref.read(mockInferenceServiceProvider).triggerTestThreat('Explosion');
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildDrillChip(
                    label: 'GUNSHOT AUDIO',
                    color: SentinelColors.accent,
                    icon: Icons.volume_up,
                    isSelected: activePayload?.threatType == 'Gunshot Audio',
                    onTap: () {
                      ref.read(mockInferenceServiceProvider).triggerTestThreat('Gunshot Audio');
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildDrillChip(
                    label: 'CROWD PANIC',
                    color: SentinelColors.threatMedium,
                    icon: Icons.groups,
                    isSelected: activePayload?.threatType == 'Crowd Panic',
                    onTap: () {
                      ref.read(mockInferenceServiceProvider).triggerTestThreat('Crowd Panic');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SentinelSpacing.sm),

          // Main Viewport + Mini Preview Tiles
          Expanded(
            child: Row(
              children: [
                // Primary Large Camera Feed with Bounding Box Overlay
                Expanded(
                  flex: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Real Hardware Laptop Camera Feed vs Phone Wireless Camera Feed
                        if (selectedCameraId == 'CAM-002')
                          PhoneCameraStreamView(
                            fallbackPainter: _CameraCanvasPainter(
                              cameraId: selectedCameraId,
                              location: selectedCamInfo['name']!,
                              isFlagged: activePayload != null &&
                                  !activePayload.isNormal,
                            ),
                          )
                        else
                          HardwareCameraView(
                            fallbackPainter: _CameraCanvasPainter(
                              cameraId: selectedCameraId,
                              location: selectedCamInfo['name']!,
                              isFlagged: activePayload != null &&
                                  !activePayload.isNormal,
                            ),
                          ),

                        // Active Bounding Box Overlay with Corner Reticles and Pulse
                        if (activePayload != null)
                          BoundingBoxOverlay(payload: activePayload),
                      ],
                    ),
                  ),
                ),

                // Mini-preview Secondary Camera Tiles Strip (Only shown if multiple cameras exist)
                if (_cameras.length > 1) ...[
                  const SizedBox(width: SentinelSpacing.sm),
                  SizedBox(
                    width: 140,
                    child: Column(
                      children: _cameras
                          .where((cam) => cam['id'] != selectedCameraId)
                          .map((cam) {
                      final isCamFlagged =
                          currentPayload?.sourceCameraId == cam['id'] &&
                              !(currentPayload?.isNormal ?? true);

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () => onCameraSelected(cam['id']!),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              decoration: BoxDecoration(
                                color: SentinelColors.bgDark,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isCamFlagged
                                      ? SentinelColors.threatCritical
                                      : SentinelColors.glassBorder,
                                  width: isCamFlagged ? 2 : 1,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomPaint(
                                    painter: _MiniFeedPainter(
                                      cameraId: cam['id']!,
                                      isFlagged: isCamFlagged,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    left: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      color:
                                          Colors.black.withValues(alpha: 0.7),
                                      child: Text(
                                        cam['id']!,
                                        style: SentinelTypography.monoSmall
                                            .copyWith(
                                          fontSize: 9,
                                          color: isCamFlagged
                                              ? SentinelColors.threatCritical
                                              : SentinelColors.accent,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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

  Widget _buildDrillChip({
    required String label,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? color : SentinelColors.glassBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? color : SentinelColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              label,
              style: SentinelTypography.monoSmall.copyWith(
                color: isSelected ? color : SentinelColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// AUDIO & THREAT CONFIDENCE PANEL (Desktop)
// ─────────────────────────────────────────────────

class _AudioAndThreatPanel extends StatelessWidget {
  final InferencePayload? payload;

  const _AudioAndThreatPanel({required this.payload});

  @override
  Widget build(BuildContext context) {
    final confidence = payload?.confidence ?? 0.0;
    final threatType = payload?.threatType ?? 'Monitoring...';
    final isAnomaly = payload != null && !payload!.isNormal;
    final threatColor = payload?.threatColor ?? SentinelColors.threatLow;

    return GlassCard(
      padding: const EdgeInsets.all(SentinelSpacing.md),
      child: Row(
        children: [
          // Left: Dynamic 20-Band Spectral Visualizer
          const Expanded(
            flex: 6,
            child: AudioSpectrumVisualizer(
              showHeader: true,
              compact: true,
            ),
          ),

          const SizedBox(width: SentinelSpacing.lg),
          Container(width: 1, color: SentinelColors.divider),
          const SizedBox(width: SentinelSpacing.lg),

          // Right: Real-time Threat Confidence Gauge
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'THREAT CONFIDENCE',
                      style: SentinelTypography.headlineMedium
                          .copyWith(fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: threatColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: threatColor),
                      ),
                      child: Text(
                        payload?.severityLabel ?? 'CLEAR',
                        style: SentinelTypography.monoSmall.copyWith(
                          color: threatColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SentinelSpacing.sm),
                Text(
                  threatType.toUpperCase(),
                  style: SentinelTypography.headlineLarge.copyWith(
                    color: isAnomaly
                        ? threatColor
                        : SentinelColors.textPrimary,
                    fontSize: 22,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: SentinelSpacing.sm),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: confidence,
                    minHeight: 12,
                    backgroundColor: SentinelColors.bgSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(threatColor),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MODEL PROBABILITY',
                      style: SentinelTypography.monoSmall.copyWith(
                        fontSize: 10,
                        color: SentinelColors.textTertiary,
                      ),
                    ),
                    Text(
                      '${(confidence * 100).toStringAsFixed(1)}%',
                      style: SentinelTypography.monoSmall.copyWith(
                        color: threatColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
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
// INCIDENT LOG SIDEBAR (Desktop)
// ─────────────────────────────────────────────────

class _IncidentLogSidebar extends StatelessWidget {
  final List<InferencePayload> alerts;
  final ValueChanged<InferencePayload> onAcknowledge;
  final VoidCallback onClearAll;

  const _IncidentLogSidebar({
    required this.alerts,
    required this.onAcknowledge,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');

    return Container(
      color: SentinelColors.bgDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: SentinelColors.threatHigh),
                const SizedBox(width: SentinelSpacing.sm),
                Text('INCIDENT QUEUE', style: SentinelTypography.headlineMedium),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SentinelColors.threatCritical.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: SentinelTypography.monoSmall.copyWith(
                      color: SentinelColors.threatCritical,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (alerts.isNotEmpty)
                  TextButton(
                    onPressed: onClearAll,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 24),
                    ),
                    child: Text(
                      'Clear',
                      style: SentinelTypography.labelSmall
                          .copyWith(color: SentinelColors.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: SentinelColors.divider),

          // Scrollable List
          Expanded(
            child: alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 48,
                            color: SentinelColors.textTertiary
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No active incidents',
                          style: SentinelTypography.bodyMedium.copyWith(
                            color: SentinelColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All sectors clear',
                          style: SentinelTypography.labelSmall.copyWith(
                            color: SentinelColors.statusOnline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(SentinelSpacing.md),
                    itemCount: alerts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      return Container(
                        padding: const EdgeInsets.all(SentinelSpacing.sm),
                        decoration: BoxDecoration(
                          color: SentinelColors.bgCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: alert.threatColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: alert.threatColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    alert.threatType,
                                    style: SentinelTypography.titleMedium
                                        .copyWith(
                                      color: SentinelColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${(alert.confidence * 100).toStringAsFixed(0)}%',
                                  style: SentinelTypography.monoSmall.copyWith(
                                    color: alert.threatColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.videocam_outlined,
                                    size: 12,
                                    color: SentinelColors.textTertiary),
                                const SizedBox(width: 4),
                                Text(
                                  alert.sourceCameraId,
                                  style: SentinelTypography.monoSmall.copyWith(
                                    color: SentinelColors.accent,
                                    fontSize: 10,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  timeFormat.format(alert.timestamp),
                                  style: SentinelTypography.monoSmall.copyWith(
                                    color: SentinelColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () => onAcknowledge(alert),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check,
                                            size: 12,
                                            color: SentinelColors.accent),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Dismiss',
                                          style: SentinelTypography.labelSmall
                                              .copyWith(
                                            color: SentinelColors.accent,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// ANDROID MOBILE DASHBOARD (Width < 900px)
// ─────────────────────────────────────────────────

class _AndroidMobileDashboard extends ConsumerWidget {
  final String selectedCameraId;
  final ValueChanged<String> onCameraSelected;
  final int currentTab;
  final ValueChanged<int> onTabChanged;

  const _AndroidMobileDashboard({
    required this.selectedCameraId,
    required this.onCameraSelected,
    required this.currentTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payloadAsync = ref.watch(activeInferencePayloadStreamProvider);
    final telemetryAsync = ref.watch(telemetryStreamProvider);
    final recentAlerts = ref.watch(recentInferenceAlertsProvider);
    final repoAsync = ref.watch(inferenceRepositoryStateProvider);
    final repoState = repoAsync.value ?? ref.watch(inferenceRepositoryProvider).state;

    final payload = payloadAsync.value;
    final telemetry = telemetryAsync.value;
    final orientation = MediaQuery.of(context).orientation;

    if (orientation == Orientation.landscape) {
      return Scaffold(
        backgroundColor: SentinelColors.bgDarkest,
        appBar: AppBar(
          backgroundColor: SentinelColors.bgDark,
          toolbarHeight: 40,
          title: Text(
            'SENTINELX PATROL // LANDSCAPE FIELD VIEW',
            style: SentinelTypography.headlineMedium.copyWith(fontSize: 13),
          ),
          actions: [
            if (telemetry != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '${telemetry.fps.toStringAsFixed(0)} FPS • ${telemetry.latencyMs}ms',
                    style: SentinelTypography.monoSmall.copyWith(
                      color: SentinelColors.accent,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            if (repoState.showSimulationBanner)
              _MobileSimulationBanner(
                message: repoState.bannerMessage,
                onDismiss: () => ref.read(inferenceRepositoryProvider).dismissBanner(),
              ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 65,
                    child: _MobileCameraTab(
                      selectedCameraId: selectedCameraId,
                      onCameraSelected: onCameraSelected,
                      payload: payload,
                    ),
                  ),
                  Container(width: 1, color: SentinelColors.divider),
                  Expanded(
                    flex: 35,
                    child: Column(
                      children: [
                        Expanded(
                          flex: 5,
                          child: _MobileAudioTab(payload: payload),
                        ),
                        Container(height: 1, color: SentinelColors.divider),
                        Expanded(
                          flex: 5,
                          child: _MobileAlertsTab(
                            alerts: recentAlerts,
                            onAcknowledge: (alert) {
                              ref
                                  .read(recentInferenceAlertsProvider.notifier)
                                  .removeAlert(alert);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: SentinelColors.bgDarkest,
      appBar: AppBar(
        backgroundColor: SentinelColors.bgDark,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.shield_outlined,
                color: SentinelColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'SENTINELX PATROL',
              style: SentinelTypography.headlineMedium.copyWith(fontSize: 16),
            ),
          ],
        ),
        actions: [
          if (telemetry != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${telemetry.fps.toStringAsFixed(0)} FPS',
                  style: SentinelTypography.monoSmall.copyWith(
                    color: SentinelColors.accent,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (repoState.showSimulationBanner)
            _MobileSimulationBanner(
              message: repoState.bannerMessage,
              onDismiss: () => ref.read(inferenceRepositoryProvider).dismissBanner(),
            ),
          Expanded(
            child: IndexedStack(
              index: currentTab,
              children: [
                // Tab 0: Live Camera Feed
                _MobileCameraTab(
                  selectedCameraId: selectedCameraId,
                  onCameraSelected: onCameraSelected,
                  payload: payload,
                ),

                // Tab 1: Audio Monitor & Decibel Meter
                _MobileAudioTab(
                  payload: payload,
                ),

                // Tab 2: Alert Logs
                _MobileAlertsTab(
                  alerts: recentAlerts,
                  onAcknowledge: (alert) {
                    ref
                        .read(recentInferenceAlertsProvider.notifier)
                        .removeAlert(alert);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: SentinelColors.bgDark,
          border: Border(top: BorderSide(color: SentinelColors.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentTab,
          onTap: onTabChanged,
          backgroundColor: Colors.transparent,
          selectedItemColor: SentinelColors.accent,
          unselectedItemColor: SentinelColors.textTertiary,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.videocam_outlined),
              activeIcon: Icon(Icons.videocam),
              label: 'Live Cam',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.graphic_eq_outlined),
              activeIcon: Icon(Icons.graphic_eq),
              label: 'Audio',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: recentAlerts.isNotEmpty,
                label: Text('${recentAlerts.length}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              activeIcon: const Icon(Icons.notifications),
              label: 'Alerts',
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileSimulationBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _MobileSimulationBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: SentinelColors.threatMedium.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: SentinelColors.threatMedium),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: SentinelTypography.bodySmall.copyWith(
                color: SentinelColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 14),
            color: SentinelColors.textTertiary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// MOBILE TAB 0: LIVE CAMERA FEED
// ─────────────────────────────────────────────────

class _MobileCameraTab extends StatelessWidget {
  final String selectedCameraId;
  final ValueChanged<String> onCameraSelected;
  final InferencePayload? payload;

  const _MobileCameraTab({
    required this.selectedCameraId,
    required this.onCameraSelected,
    required this.payload,
  });

  @override
  Widget build(BuildContext context) {
    final activePayload =
        (payload?.sourceCameraId == selectedCameraId) ? payload : null;
    final isAnomaly = activePayload != null && !activePayload.isNormal;

    return Column(
      children: [
        // Camera Status Bar (Only 1 camera: Laptop Webcam)
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: SentinelColors.bgDark.withValues(alpha: 0.85),
          child: Row(
            children: [
              const PulsingDot(color: SentinelColors.statusOnline, size: 6),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LIVE FEED // CAM-001 (LAPTOP WEBCAM)',
                  style: SentinelTypography.monoSmall.copyWith(
                    color: SentinelColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE',
                style: SentinelTypography.labelSmall.copyWith(
                  color: SentinelColors.statusOnline,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),

        // Video Viewport with Floating Anomaly Banner
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Real Hardware Laptop Camera Feed with canvas fallback
              HardwareCameraView(
                fallbackPainter: _CameraCanvasPainter(
                  cameraId: selectedCameraId,
                  location: 'Laptop Webcam',
                  isFlagged: isAnomaly,
                ),
              ),

              // Bounding Box Overlay with Corner Reticles and Pulse
              if (activePayload != null)
                BoundingBoxOverlay(payload: activePayload),

              // Floating Anomaly Banner
              if (isAnomaly)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: activePayload.threatColor.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: SentinelShadows.medium,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                activePayload.threatType.toUpperCase(),
                                style: SentinelTypography.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${(activePayload.confidence * 100).toStringAsFixed(1)}% Confidence • ${activePayload.sourceCameraId}',
                                style: SentinelTypography.bodySmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// MOBILE TAB 1: AUDIO MONITOR & DECIBEL METER
// ─────────────────────────────────────────────────

class _MobileAudioTab extends StatelessWidget {
  final InferencePayload? payload;

  const _MobileAudioTab({required this.payload});

  @override
  Widget build(BuildContext context) {
    final decibels = payload?.decibels ?? 54.0;
    final isLoud = decibels > 85.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SentinelSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Circular Decibel Meter
          GlassCard(
            padding: const EdgeInsets.all(SentinelSpacing.lg),
            child: Column(
              children: [
                Text(
                  'ACOUSTIC DECIBEL METER',
                  style: SentinelTypography.headlineMedium.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (decibels / 120.0).clamp(0.0, 1.0),
                        strokeWidth: 14,
                        backgroundColor: SentinelColors.bgSurface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isLoud
                              ? SentinelColors.threatCritical
                              : SentinelColors.accent,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            decibels.toStringAsFixed(1),
                            style: SentinelTypography.displayMedium.copyWith(
                              color: isLoud
                                  ? SentinelColors.threatCritical
                                  : SentinelColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'dB SPL',
                            style: SentinelTypography.monoSmall.copyWith(
                              color: SentinelColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLoud
                        ? SentinelColors.threatCritical.withValues(alpha: 0.15)
                        : SentinelColors.statusOnline.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isLoud
                        ? 'THRESHOLD EXCEEDED (>85 dB)'
                        : 'NOMINAL AMBIENT (<85 dB)',
                    style: SentinelTypography.labelSmall.copyWith(
                      color: isLoud
                          ? SentinelColors.threatCritical
                          : SentinelColors.statusOnline,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: SentinelSpacing.base),

          // Dynamic Audio Spectrum Visualizer
          const SizedBox(
            height: 240,
            child: AudioSpectrumVisualizer(
              showHeader: true,
              compact: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// MOBILE TAB 2: ALERT LOGS
// ─────────────────────────────────────────────────

class _MobileAlertsTab extends StatefulWidget {
  final List<InferencePayload> alerts;
  final ValueChanged<InferencePayload> onAcknowledge;

  const _MobileAlertsTab({
    required this.alerts,
    required this.onAcknowledge,
  });

  @override
  State<_MobileAlertsTab> createState() => _MobileAlertsTabState();
}

class _MobileAlertsTabState extends State<_MobileAlertsTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.alerts.where((a) {
      if (_filter == 'Critical') return a.isCritical;
      if (_filter == 'High') return a.isHigh;
      if (_filter == 'Audio') {
        return a.threatType.contains('Audio') ||
            a.threatType.contains('Gunshot') ||
            a.threatType.contains('Explosion');
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Critical', 'High', 'Audio'].map((tag) {
                final isSelected = _filter == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: SentinelColors.primary.withValues(alpha: 0.3),
                    backgroundColor: SentinelColors.bgCard,
                    labelStyle: SentinelTypography.labelSmall.copyWith(
                      color: isSelected
                          ? SentinelColors.textPrimary
                          : SentinelColors.textTertiary,
                    ),
                    onSelected: (_) => setState(() => _filter = tag),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // List of Incident Cards
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No incidents match filter',
                    style: SentinelTypography.bodyMedium
                        .copyWith(color: SentinelColors.textTertiary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(SentinelSpacing.base),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final alert = filtered[index];
                    return GlassCard(
                      borderColor: alert.threatColor.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(SentinelSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: alert.threatColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  alert.severityLabel,
                                  style: SentinelTypography.labelSmall.copyWith(
                                    color: alert.threatColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  alert.threatType,
                                  style: SentinelTypography.titleMedium
                                      .copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(alert.confidence * 100).toStringAsFixed(1)}%',
                                style: SentinelTypography.monoSmall.copyWith(
                                  color: alert.threatColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${alert.sourceCameraId} • ${alert.location}',
                            style: SentinelTypography.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('MMM d, HH:mm:ss')
                                    .format(alert.timestamp),
                                style: SentinelTypography.monoSmall.copyWith(
                                  color: SentinelColors.textTertiary,
                                  fontSize: 10,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => widget.onAcknowledge(alert),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SentinelColors.bgCard,
                                  foregroundColor: SentinelColors.accent,
                                  elevation: 0,
                                  side: const BorderSide(
                                      color: SentinelColors.accent),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  minimumSize: const Size(60, 28),
                                ),
                                child: const Text('Acknowledge'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// CUSTOM PAINTERS (CCTV Canvas)
// ─────────────────────────────────────────────────

class _CameraCanvasPainter extends CustomPainter {
  final String cameraId;
  final String location;
  final bool isFlagged;

  _CameraCanvasPainter({
    required this.cameraId,
    required this.location,
    required this.isFlagged,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF070B12);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Subtle surveillance grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF132238).withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Crosshairs in center
    final crosshairPaint = Paint()
      ..color = SentinelColors.accent.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx - 20, cy), Offset(cx + 20, cy), crosshairPaint);
    canvas.drawLine(Offset(cx, cy - 20), Offset(cx, cy + 20), crosshairPaint);

    // Corner targeting brackets
    _drawTargetBrackets(canvas, size);

    // HUD Text
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Camera ID Top-Left
    textPainter.text = TextSpan(
      text: '$cameraId // REC [●]',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: isFlagged
            ? SentinelColors.threatCritical
            : SentinelColors.statusOnline,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(12, 12));

    // Bottom-Left Location
    textPainter.text = TextSpan(
      text: location.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: Color(0xFF6B82A8),
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(12, size.height - 24));
  }

  void _drawTargetBrackets(Canvas canvas, Size size) {
    final bracketPaint = Paint()
      ..color = SentinelColors.accent.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const bSize = 16.0;
    const pad = 10.0;

    // Top-Left
    final p1 = Path()
      ..moveTo(pad, pad + bSize)
      ..lineTo(pad, pad)
      ..lineTo(pad + bSize, pad);
    canvas.drawPath(p1, bracketPaint);

    // Top-Right
    final p2 = Path()
      ..moveTo(size.width - pad - bSize, pad)
      ..lineTo(size.width - pad, pad)
      ..lineTo(size.width - pad, pad + bSize);
    canvas.drawPath(p2, bracketPaint);

    // Bottom-Left
    final p3 = Path()
      ..moveTo(pad, size.height - pad - bSize)
      ..lineTo(pad, size.height - pad)
      ..lineTo(pad + bSize, size.height - pad);
    canvas.drawPath(p3, bracketPaint);

    // Bottom-Right
    final p4 = Path()
      ..moveTo(size.width - pad - bSize, size.height - pad)
      ..lineTo(size.width - pad, size.height - pad)
      ..lineTo(size.width - pad, size.height - pad - bSize);
    canvas.drawPath(p4, bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _CameraCanvasPainter oldDelegate) {
    return oldDelegate.cameraId != cameraId ||
        oldDelegate.isFlagged != isFlagged;
  }
}

class _MiniFeedPainter extends CustomPainter {
  final String cameraId;
  final bool isFlagged;

  _MiniFeedPainter({required this.cameraId, required this.isFlagged});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF090E17);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final linePaint = Paint()
      ..color = (isFlagged
              ? SentinelColors.threatCritical
              : const Color(0xFF1B2E4B))
          .withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniFeedPainter oldDelegate) {
    return oldDelegate.isFlagged != isFlagged;
  }
}


