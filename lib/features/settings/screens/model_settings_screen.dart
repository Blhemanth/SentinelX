// SentinelX - Model Asset & ONNX Runtime Settings Screen
// Manages local .onnx model weights, hardware execution provider settings,
// model metadata inspection, and interactive inference latency benchmarking.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/services/inference_repository.dart';
import 'package:sentinel_x/shared/widgets/sentinel_widgets.dart';

class ModelSettingsScreen extends ConsumerStatefulWidget {
  const ModelSettingsScreen({super.key});

  @override
  ConsumerState<ModelSettingsScreen> createState() => _ModelSettingsScreenState();
}

class _ModelSettingsScreenState extends ConsumerState<ModelSettingsScreen> {
  final TextEditingController _pathController = TextEditingController();
  bool _isBenchmarking = false;
  int? _benchmarkLatencyMs;
  double? _benchmarkFps;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final repoState = ref.read(inferenceRepositoryProvider).state;
    _pathController.text = repoState.modelPath;
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadModel(String path) async {
    setState(() => _statusMessage = 'Validating model file...');
    final repo = ref.read(inferenceRepositoryProvider);
    final success = await repo.loadCustomModel(path);

    if (mounted) {
      setState(() {
        if (success) {
          _statusMessage = 'Successfully loaded ONNX model!';
        } else {
          _statusMessage = 'Model file not found. Running in simulation mode.';
        }
      });
    }
  }

  Future<void> _runBenchmark() async {
    setState(() {
      _isBenchmarking = true;
      _statusMessage = 'Executing single-frame tensor inference...';
    });

    final repo = ref.read(inferenceRepositoryProvider);
    final latency = await repo.benchmark();

    if (mounted) {
      setState(() {
        _isBenchmarking = false;
        _benchmarkLatencyMs = latency;
        _benchmarkFps = 1000.0 / latency;
        _statusMessage = 'Benchmark complete: $latency ms (${_benchmarkFps!.toStringAsFixed(1)} FPS)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(inferenceRepositoryStateProvider);
    final repoState = repoAsync.value ?? ref.watch(inferenceRepositoryProvider).state;
    final meta = repoState.metadata;

    return Scaffold(
      backgroundColor: SentinelColors.bgDarkest,
      appBar: AppBar(
        backgroundColor: SentinelColors.bgDark,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.memory_rounded, color: SentinelColors.accent, size: 20),
            const SizedBox(width: 8),
            Text('ONNX RUNTIME & MODEL SETTINGS', style: SentinelTypography.headlineMedium.copyWith(fontSize: 16)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SentinelSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Simulation Fallback Warning Banner
            if (repoState.showSimulationBanner)
              _SimulationWarningBanner(
                message: repoState.bannerMessage,
                onDismiss: () => ref.read(inferenceRepositoryProvider).dismissBanner(),
              ),

            const SizedBox(height: SentinelSpacing.base),

            // 2. Model File Selector Card
            GlassCard(
              padding: const EdgeInsets.all(SentinelSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_open_rounded, size: 18, color: SentinelColors.accent),
                      const SizedBox(width: 8),
                      Text('LOCAL MODEL ASSET FILE', style: SentinelTypography.headlineMedium.copyWith(fontSize: 14)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: repoState.isModelLoaded
                              ? SentinelColors.statusOnline.withValues(alpha: 0.15)
                              : SentinelColors.threatMedium.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: repoState.isModelLoaded
                                ? SentinelColors.statusOnline
                                : SentinelColors.threatMedium,
                          ),
                        ),
                        child: Text(
                          repoState.mode.label.toUpperCase(),
                          style: SentinelTypography.monoSmall.copyWith(
                            color: repoState.isModelLoaded
                                ? SentinelColors.statusOnline
                                : SentinelColors.threatMedium,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SentinelSpacing.md),
                  TextField(
                    controller: _pathController,
                    style: SentinelTypography.monoSmall.copyWith(color: SentinelColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Model Path (.onnx)',
                      labelStyle: SentinelTypography.bodySmall,
                      hintText: 'C:\\SentinelX\\models\\sentinelx_model.onnx',
                      hintStyle: SentinelTypography.monoSmall.copyWith(color: SentinelColors.textTertiary),
                      filled: true,
                      fillColor: SentinelColors.bgSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: SentinelColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: SentinelColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: SentinelColors.accent),
                      ),
                      prefixIcon: const Icon(Icons.file_present_rounded, color: SentinelColors.textTertiary),
                    ),
                  ),
                  const SizedBox(height: SentinelSpacing.md),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _loadModel(_pathController.text.trim()),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Load / Verify Model'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SentinelColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          _pathController.text = 'assets/models/sentinelx_v1.onnx';
                          _loadModel(_pathController.text);
                        },
                        icon: const Icon(Icons.restore_page_rounded, size: 16),
                        label: const Text('Preset INT8'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SentinelColors.accent,
                          side: const BorderSide(color: SentinelColors.accent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _statusMessage!,
                      style: SentinelTypography.monoSmall.copyWith(
                        color: SentinelColors.accent,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: SentinelSpacing.base),

            // 3. Model Metadata Inspection Card
            GlassCard(
              padding: const EdgeInsets.all(SentinelSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 18, color: SentinelColors.accent),
                      const SizedBox(width: 8),
                      Text('MODEL METADATA & EXECUTION PROVIDER', style: SentinelTypography.headlineMedium.copyWith(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: SentinelSpacing.md),
                  _MetadataRow(label: 'Model Name', value: meta.modelName),
                  _MetadataRow(label: 'File Size', value: meta.formattedFileSize),
                  _MetadataRow(label: 'Quantization Type', value: meta.quantization.label),
                  _MetadataRow(label: 'Input Tensor Shape', value: '${meta.formattedInputShape} (NCHW)'),
                  _MetadataRow(label: 'Execution Provider', value: meta.executionProvider.displayName),
                  _MetadataRow(label: 'CPU Thread Pool', value: '${meta.numThreads} Threads'),
                  _MetadataRow(
                    label: 'Status',
                    value: repoState.isModelLoaded ? 'ACTIVE (READY)' : 'FALLBACK SIMULATION',
                    valueColor: repoState.isModelLoaded ? SentinelColors.statusOnline : SentinelColors.threatMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: SentinelSpacing.base),

            // 4. Hardware Inference Latency Benchmark Card
            GlassCard(
              padding: const EdgeInsets.all(SentinelSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed_rounded, size: 18, color: SentinelColors.statusOnline),
                      const SizedBox(width: 8),
                      Text('LOCAL HARDWARE BENCHMARK', style: SentinelTypography.headlineMedium.copyWith(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Measures single-frame tensor inference latency on your local GPU/CPU.',
                    style: SentinelTypography.bodySmall.copyWith(color: SentinelColors.textSecondary),
                  ),
                  const SizedBox(height: SentinelSpacing.md),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isBenchmarking ? null : _runBenchmark,
                        icon: _isBenchmarking
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(_isBenchmarking ? 'Running...' : 'Run Latency Benchmark'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SentinelColors.statusOnline,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const Spacer(),
                      if (_benchmarkLatencyMs != null) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$_benchmarkLatencyMs ms',
                              style: SentinelTypography.displayMedium.copyWith(
                                color: SentinelColors.statusOnline,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            Text(
                              '${_benchmarkFps!.toStringAsFixed(1)} FPS Throughput',
                              style: SentinelTypography.monoSmall.copyWith(
                                color: SentinelColors.accent,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: SentinelSpacing.base),

            // 5. Remote H200 Training Pipeline Notice
            Container(
              padding: const EdgeInsets.all(SentinelSpacing.md),
              decoration: BoxDecoration(
                color: SentinelColors.bgCard.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SentinelColors.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_sync_outlined, color: SentinelColors.accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REMOTE H200 GPU TRAINING STATUS',
                          style: SentinelTypography.monoSmall.copyWith(
                            color: SentinelColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fine-tuning audio-visual weights on remote NVIDIA H200. When INT8 export completes, place sentinelx_model.onnx in your application folder.',
                          style: SentinelTypography.bodySmall.copyWith(color: SentinelColors.textTertiary, fontSize: 11),
                        ),
                      ],
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

class _SimulationWarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _SimulationWarningBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SentinelSpacing.md),
      decoration: BoxDecoration(
        color: SentinelColors.threatMedium.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SentinelColors.threatMedium.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: SentinelColors.threatMedium, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: SentinelTypography.bodySmall.copyWith(
                color: SentinelColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18, color: SentinelColors.textTertiary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetadataRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: SentinelTypography.bodySmall.copyWith(color: SentinelColors.textSecondary)),
          Text(
            value,
            style: SentinelTypography.monoSmall.copyWith(
              color: valueColor ?? SentinelColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
