// SentinelX - Settings Page
// Configuration panel for inference engine, camera management,
// alert thresholds, and system preferences.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/features/settings/screens/model_settings_screen.dart';
import 'package:sentinel_x/shared/widgets/sentinel_widgets.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  double _threatThreshold = 0.6;
  bool _audioEnabled = true;
  bool _autoAcknowledge = false;
  bool _pushNotifications = true;
  final String _modelPath = 'assets/models/sentinelx_v1.onnx';

  @override
  Widget build(BuildContext context) {
    final isRunning = ref.watch(inferenceRunningProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: SentinelGradients.surfaceGradient,
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text('Settings', style: SentinelTypography.displayMedium),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(SentinelSpacing.base),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Inference Engine Section
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Inference Engine',
                        icon: Icons.memory_outlined,
                      ),
                      const SizedBox(height: SentinelSpacing.md),
                      _SettingsTile(
                        title: 'Engine Status',
                        subtitle: isRunning
                            ? 'Running • Mock Inference Pipeline'
                            : 'Stopped',
                        trailing: Switch(
                          value: isRunning,
                          activeThumbColor: SentinelColors.statusOnline,
                          onChanged: (value) {
                            final engine = ref.read(inferenceEngineProvider);
                            if (value) {
                              engine.start();
                            } else {
                              engine.stop();
                            }
                            ref.read(inferenceRunningProvider.notifier).state =
                                value;
                          },
                        ),
                      ),
                      _SettingsTile(
                        title: 'ONNX Model Weights & Hardware EP',
                        subtitle: 'DirectML / NNAPI • $_modelPath',
                        trailing: IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ModelSettingsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.memory_outlined,
                            size: 20,
                            color: SentinelColors.accent,
                          ),
                          tooltip: 'Manage ONNX Runtime & Weights',
                        ),
                      ),
                      _SettingsTile(
                        title: 'Active Cameras',
                        subtitle: 'CAM-001 (Laptop Webcam)',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: SentinelColors.statusOnline.withValues(alpha: 0.15),
                            borderRadius: SentinelRadius.smAll,
                            border: Border.all(color: SentinelColors.statusOnline.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '1 HARDWARE CAM',
                            style: SentinelTypography.monoSmall.copyWith(
                              color: SentinelColors.statusOnline,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SentinelSpacing.md),

                // Detection Settings
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Detection Configuration',
                        icon: Icons.tune_outlined,
                      ),
                      const SizedBox(height: SentinelSpacing.md),
                      _SettingsTile(
                        title: 'Threat Alert Threshold',
                        subtitle:
                            'Alert when score ≥ ${_threatThreshold.toStringAsFixed(2)}',
                        trailing: SizedBox(
                          width: 140,
                          child: Slider(
                            value: _threatThreshold,
                            min: 0.1,
                            max: 1.0,
                            divisions: 18,
                            activeColor: _getThreatColor(_threatThreshold),
                            label: _threatThreshold.toStringAsFixed(2),
                            onChanged: (value) {
                              setState(() => _threatThreshold = value);
                            },
                          ),
                        ),
                      ),
                      _SettingsTile(
                        title: 'Audio Analysis',
                        subtitle: _audioEnabled
                            ? 'Monitoring audio streams'
                            : 'Audio disabled',
                        trailing: Switch(
                          value: _audioEnabled,
                          activeThumbColor: SentinelColors.accent,
                          onChanged: (value) {
                            setState(() => _audioEnabled = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SentinelSpacing.md),

                // Notification Settings
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Notifications',
                        icon: Icons.notifications_outlined,
                      ),
                      const SizedBox(height: SentinelSpacing.md),
                      _SettingsTile(
                        title: 'Push Notifications',
                        subtitle: 'Send alerts to mobile devices',
                        trailing: Switch(
                          value: _pushNotifications,
                          activeThumbColor: SentinelColors.primary,
                          onChanged: (value) {
                            setState(() => _pushNotifications = value);
                          },
                        ),
                      ),
                      _SettingsTile(
                        title: 'Auto-Acknowledge Low Threats',
                        subtitle: 'Automatically dismiss low-severity alerts',
                        trailing: Switch(
                          value: _autoAcknowledge,
                          activeThumbColor: SentinelColors.primary,
                          onChanged: (value) {
                            setState(() => _autoAcknowledge = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SentinelSpacing.md),

                // System Info
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'System Information',
                        icon: Icons.info_outline_rounded,
                      ),
                      const SizedBox(height: SentinelSpacing.md),
                      _InfoRow('Application', 'SentinelX v0.1.0'),
                      _InfoRow('Framework', 'Flutter 3.41.5'),
                      _InfoRow('Inference', 'Mock Pipeline (ONNX-ready)'),
                      _InfoRow('State Management', 'Riverpod'),
                      _InfoRow('Build', 'Debug'),
                      const SizedBox(height: SentinelSpacing.md),
                      Text(
                        'Fine-tuned ONNX models can be loaded via the '
                        'model path setting above. The mock inference '
                        'pipeline generates synthetic detections for '
                        'UI development and testing.',
                        style: SentinelTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SentinelSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Color _getThreatColor(double value) {
    if (value >= 0.8) return SentinelColors.threatCritical;
    if (value >= 0.6) return SentinelColors.threatHigh;
    if (value >= 0.4) return SentinelColors.threatMedium;
    return SentinelColors.threatLow;
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SentinelSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SentinelTypography.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: SentinelTypography.bodySmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: SentinelTypography.bodySmall),
          Text(
            value,
            style: SentinelTypography.monoSmall.copyWith(
              color: SentinelColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
