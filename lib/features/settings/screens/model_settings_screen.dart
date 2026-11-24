// SentinelX - Model Asset & ONNX Runtime Settings Screen
// Manages local .onnx model weights, hardware execution provider settings,
// model metadata inspection, and interactive inference latency benchmarking.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/services/inference_repository.dart';
import 'package:sentinel_x/services/onnx_native_bridge.dart';
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
  bool _isNativeBenchmarking = false;
  NativeBenchmarkResult? _nativeBenchmarkResult;

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

  Future<void> _runNativeBenchmark() async {
    setState(() {
      _isNativeBenchmarking = true;
      _statusMessage = 'Executing genuine native ONNX Runtime inference via Dart FFI...';
    });

    try {
      final repo = ref.read(inferenceRepositoryProvider);
      final result = await repo.benchmarkNativeOnnx(passes: 3);

      if (mounted) {
        setState(() {
          _isNativeBenchmarking = false;
          _nativeBenchmarkResult = result;
          _statusMessage = 'Native ONNX execution proof successful: ${result.averageLatencyMs.toStringAsFixed(1)} ms avg (${result.throughputFps.toStringAsFixed(2)} FPS)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isNativeBenchmarking = false;
          _statusMessage = 'Native ONNX execution error: $e';
        });
      }
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
                          _pathController.text = 'assets/models/sentinelx_model.onnx';
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

            // 5. Native ONNX Runtime FFI Execution Proof Card (Phase 4.2)
            GlassCard(
              padding: const EdgeInsets.all(SentinelSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.developer_board_rounded, size: 20, color: SentinelColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'NATIVE ONNX RUNTIME PROOF (PHASE 4.2)',
                          style: SentinelTypography.headlineMedium.copyWith(fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: SentinelColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: SentinelColors.accent),
                        ),
                        child: Text(
                          'DART FFI IN-PROCESS',
                          style: SentinelTypography.monoSmall.copyWith(
                            color: SentinelColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SentinelSpacing.md),

                  // Mandatory Project Safety Warning Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SYNTHETIC TEST INPUT — NOT LIVE DETECTION',
                                style: SentinelTypography.headlineMedium.copyWith(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Deterministic synthetic test tensors are executed locally via native ONNX Runtime FFI for tensor contract verification. Results are never dispatched or saved to production database.',
                                style: SentinelTypography.bodySmall.copyWith(
                                  color: SentinelColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: SentinelSpacing.md),
                  _MetadataRow(label: 'Model Path', value: 'assets/models/sentinelx_model.onnx'),
                  _MetadataRow(label: 'Model Format', value: 'INT8 Quantized Opset 18 (19.44 MB)'),
                  _MetadataRow(
                    label: 'Input Video Tensor',
                    value: '[1, 16, 3, 224, 224] Float32 (2,408,448 floats)',
                  ),
                  _MetadataRow(
                    label: 'Input Audio Tensor',
                    value: '[1, 1, 128, 128] Float32 (16,384 floats)',
                  ),
                  _MetadataRow(
                    label: 'Output Tensors',
                    value: 'threat_probabilities [1, 5] & bounding_boxes [1, 4]',
                  ),
                  _MetadataRow(
                    label: 'Class Taxonomy',
                    value: 'Explosion, Gunshot, Fighting, Accident, Normal',
                  ),
                  _MetadataRow(
                    label: 'BBox Format',
                    value: '[x, y, w, h] normalized in [0, 1]',
                  ),
                  _MetadataRow(
                    label: 'Execution Provider',
                    value: 'CPUExecutionProvider (Native AVX2/Multi-Threaded)',
                  ),

                  const SizedBox(height: SentinelSpacing.md),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isNativeBenchmarking ? null : _runNativeBenchmark,
                        icon: _isNativeBenchmarking
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_circle_filled_rounded, size: 18),
                        label: Text(_isNativeBenchmarking ? 'Running FFI Benchmark...' : 'Run Native ONNX Benchmark (3 Passes)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SentinelColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),

                  if (_nativeBenchmarkResult != null) ...[
                    const SizedBox(height: SentinelSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SentinelColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SentinelColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'NATIVE BENCHMARK RESULTS',
                                style: SentinelTypography.monoSmall.copyWith(
                                  color: SentinelColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_nativeBenchmarkResult!.averageLatencyMs.toStringAsFixed(1)} ms Avg',
                                style: SentinelTypography.headlineMedium.copyWith(
                                  color: SentinelColors.statusOnline,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${_nativeBenchmarkResult!.throughputFps.toStringAsFixed(2)} FPS)',
                                style: SentinelTypography.monoSmall.copyWith(
                                  color: SentinelColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: SentinelColors.border, height: 16),
                          Text(
                            'Pass Latencies: ${_nativeBenchmarkResult!.individualLatenciesMs.map((l) => '$l ms').join('  •  ')}',
                            style: SentinelTypography.monoSmall.copyWith(fontSize: 11, color: SentinelColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Min: ${_nativeBenchmarkResult!.minLatencyMs.toInt()} ms  |  Max: ${_nativeBenchmarkResult!.maxLatencyMs.toInt()} ms',
                            style: SentinelTypography.monoSmall.copyWith(fontSize: 11, color: SentinelColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sample Output [SYNTHETIC TEST]: ${_nativeBenchmarkResult!.sampleOutput.predictedClass} '
                            '(${( _nativeBenchmarkResult!.sampleOutput.confidence * 100).toStringAsFixed(1)}%)',
                            style: SentinelTypography.monoSmall.copyWith(
                              fontSize: 11,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Class Probabilities: ${_nativeBenchmarkResult!.sampleOutput.threatProbabilities.map((p) => p.toStringAsFixed(3)).toList()}',
                            style: SentinelTypography.monoSmall.copyWith(fontSize: 10, color: SentinelColors.textTertiary),
                          ),
                          Text(
                            'Bounding Box: ${_nativeBenchmarkResult!.sampleOutput.boundingBox.map((b) => b.toStringAsFixed(3)).toList()}',
                            style: SentinelTypography.monoSmall.copyWith(fontSize: 10, color: SentinelColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: SentinelSpacing.base),

            // 6. Remote H200 Training Pipeline Notice
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
