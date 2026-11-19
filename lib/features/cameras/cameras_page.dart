// SentinelX - Camera Feeds Page
// Grid of camera feeds with simulated video canvas, bounding box overlays,
// and individual camera detail view.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/models/models.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/shared/widgets/sentinel_widgets.dart';
import 'package:sentinel_x/features/camera/widgets/hardware_camera_view.dart';

class CamerasPage extends ConsumerWidget {
  const CamerasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameras = ref.watch(cameraFeedsProvider);
    final selectedCamera = ref.watch(selectedCameraProvider);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1000;

    return Container(
      decoration: const BoxDecoration(
        gradient: SentinelGradients.surfaceGradient,
      ),
      child: isWide
          ? _DesktopCameraLayout(
              cameras: cameras,
              selectedCamera: selectedCamera,
            )
          : _MobileCameraLayout(cameras: cameras),
    );
  }
}

// ─────────────────────────────────────────────────
// DESKTOP: Grid + Detail Panel
// ─────────────────────────────────────────────────

class _DesktopCameraLayout extends ConsumerWidget {
  final List<CameraFeed> cameras;
  final CameraFeed? selectedCamera;

  const _DesktopCameraLayout({
    required this.cameras,
    this.selectedCamera,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Camera Grid
        Expanded(
          flex: selectedCamera != null ? 3 : 1,
          child: _CameraGrid(cameras: cameras),
        ),
        // Detail Panel (when a camera is selected)
        if (selectedCamera != null) ...[
          Container(width: 1, color: SentinelColors.divider),
          SizedBox(
            width: 380,
            child: _CameraDetailPanel(camera: selectedCamera!),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// MOBILE: Scrollable list
// ─────────────────────────────────────────────────

class _MobileCameraLayout extends StatelessWidget {
  final List<CameraFeed> cameras;
  const _MobileCameraLayout({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Text('Camera Feeds', style: SentinelTypography.displayMedium),
                const Spacer(),
                ThreatBadge(level: ThreatLevel.none),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 16 / 11,
            ),
            itemCount: cameras.length,
            itemBuilder: (context, index) => _CameraCard(
              camera: cameras[index],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// CAMERA GRID
// ─────────────────────────────────────────────────

class _CameraGrid extends StatelessWidget {
  final List<CameraFeed> cameras;
  const _CameraGrid({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Text('Camera Feeds', style: SentinelTypography.displayMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SentinelColors.statusOnline.withValues(alpha: 0.1),
                    borderRadius: SentinelRadius.smAll,
                    border: Border.all(
                      color: SentinelColors.statusOnline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PulsingDot(
                        color: SentinelColors.statusOnline,
                        size: 6,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${cameras.where((c) => c.status == CameraStatus.online || c.status == CameraStatus.recording).length}/${cameras.length} Online',
                        style: SentinelTypography.labelSmall.copyWith(
                          color: SentinelColors.statusOnline,
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
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 16 / 10,
            ),
            itemCount: cameras.length,
            itemBuilder: (context, index) => _CameraCard(
              camera: cameras[index],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// CAMERA CARD (simulated video feed with detections)
// ─────────────────────────────────────────────────

class _CameraCard extends ConsumerStatefulWidget {
  final CameraFeed camera;
  const _CameraCard({required this.camera});

  @override
  ConsumerState<_CameraCard> createState() => _CameraCardState();
}

class _CameraCardState extends ConsumerState<_CameraCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isOffline = widget.camera.status == CameraStatus.offline;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(selectedCameraProvider.notifier).state = widget.camera;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: SentinelColors.bgCard,
            borderRadius: SentinelRadius.lgAll,
            border: Border.all(
              color: _isHovered
                  ? SentinelColors.primary.withValues(alpha: 0.5)
                  : SentinelColors.border,
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: _isHovered ? SentinelShadows.glow : SentinelShadows.soft,
          ),
          child: ClipRRect(
            borderRadius: SentinelRadius.lgAll,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Real Hardware Laptop Camera Feed with canvas fallback
                if (!isOffline)
                  HardwareCameraView(
                    fallback: _SimulatedVideoCanvas(cameraId: widget.camera.id),
                  )
                else
                  _OfflineOverlay(),

                // Detection bounding boxes overlay
                if (!isOffline)
                  _DetectionOverlay(cameraId: widget.camera.id),

                // Camera info overlay (top)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _CameraInfoBar(camera: widget.camera),
                ),

                // Bottom info bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _CameraBottomBar(camera: widget.camera),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// SIMULATED VIDEO CANVAS (renders animated scene)
// ─────────────────────────────────────────────────

class _SimulatedVideoCanvas extends StatefulWidget {
  final String cameraId;
  const _SimulatedVideoCanvas({required this.cameraId});

  @override
  State<_SimulatedVideoCanvas> createState() => _SimulatedVideoCanvasState();
}

class _SimulatedVideoCanvasState extends State<_SimulatedVideoCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ScenePainter(
            animValue: _controller.value,
            cameraId: widget.cameraId,
          ),
        );
      },
    );
  }
}

class _ScenePainter extends CustomPainter {
  final double animValue;
  final String cameraId;

  _ScenePainter({required this.animValue, required this.cameraId});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(cameraId.hashCode);

    // Dark gradient background (simulating night vision / CCTV)
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(
            const Color(0xFF0D1117),
            const Color(0xFF111827),
            (sin(animValue * pi * 2) + 1) / 2,
          )!,
          Color.lerp(
            const Color(0xFF111827),
            const Color(0xFF0D1117),
            (cos(animValue * pi * 2) + 1) / 2,
          )!,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Draw grid lines (surveillance overlay)
    final gridPaint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 0.5;

    for (int i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 1; i < 12; i++) {
      final x = size.width * i / 12;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Draw some "buildings" / scene elements
    final buildingPaint = Paint()..color = const Color(0x15FFFFFF);
    for (int i = 0; i < 5; i++) {
      final bx = random.nextDouble() * size.width * 0.8;
      final bw = 20.0 + random.nextDouble() * 50;
      final bh = 40.0 + random.nextDouble() * (size.height * 0.5);
      canvas.drawRect(
        Rect.fromLTWH(bx, size.height - bh, bw, bh),
        buildingPaint,
      );
    }

    // Animated scan line
    final scanY = (animValue * size.height * 2) % size.height;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          SentinelColors.accent.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(0, scanY - 20, size.width, 40),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 20, size.width, 40),
      scanPaint,
    );

    // Noise grain effect
    final noisePaint = Paint()..color = const Color(0x05FFFFFF);
    for (int i = 0; i < 30; i++) {
      final nx = (random.nextDouble() * size.width + animValue * 100) %
          size.width;
      final ny = (random.nextDouble() * size.height + animValue * 50) %
          size.height;
      canvas.drawCircle(Offset(nx, ny), 0.5, noisePaint);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

// ─────────────────────────────────────────────────
// DETECTION BOUNDING BOX OVERLAY
// ─────────────────────────────────────────────────

class _DetectionOverlay extends ConsumerWidget {
  final String cameraId;
  const _DetectionOverlay({required this.cameraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detections = ref.watch(detectionsAccumulatorProvider);
    final cameraDetections = detections
        .where((d) => d.cameraId == cameraId)
        .take(4)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: cameraDetections.map((detection) {
            final rect = detection.bbox.toRect(
              Size(constraints.maxWidth, constraints.maxHeight),
            );
            return Positioned(
              left: rect.left.clamp(0, constraints.maxWidth - 20),
              top: rect.top.clamp(0, constraints.maxHeight - 20),
              child: _BoundingBoxWidget(
                detection: detection,
                width: rect.width.clamp(20, constraints.maxWidth),
                height: rect.height.clamp(20, constraints.maxHeight),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _BoundingBoxWidget extends StatelessWidget {
  final Detection detection;
  final double width;
  final double height;

  const _BoundingBoxWidget({
    required this.detection,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: detection.threat.color.withValues(alpha: 0.7),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: detection.threat.color.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            '${detection.type.label} ${(detection.confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// CAMERA INFO OVERLAYS
// ─────────────────────────────────────────────────

class _CameraInfoBar extends StatelessWidget {
  final CameraFeed camera;
  const _CameraInfoBar({required this.camera});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          CameraStatusDot(status: camera.status, size: 8),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              camera.name,
              style: SentinelTypography.labelLarge.copyWith(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: SentinelRadius.smAll,
            ),
            child: Text(
              camera.id,
              style: SentinelTypography.monoSmall.copyWith(fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraBottomBar extends StatelessWidget {
  final CameraFeed camera;
  const _CameraBottomBar({required this.camera});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Text(
            camera.location,
            style: SentinelTypography.labelSmall.copyWith(fontSize: 8),
          ),
          const Spacer(),
          Text(
            '${camera.resolution} • ${camera.fps}fps',
            style: SentinelTypography.monoSmall.copyWith(fontSize: 8),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// OFFLINE OVERLAY
// ─────────────────────────────────────────────────

class _OfflineOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: SentinelColors.bgDarkest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 28,
              color: SentinelColors.statusOffline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              'OFFLINE',
              style: SentinelTypography.labelSmall.copyWith(
                color: SentinelColors.statusOffline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// CAMERA DETAIL PANEL (desktop sidebar)
// ─────────────────────────────────────────────────

class _CameraDetailPanel extends ConsumerWidget {
  final CameraFeed camera;
  const _CameraDetailPanel({required this.camera});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detections = ref.watch(detectionsAccumulatorProvider);
    final cameraDetections = detections
        .where((d) => d.cameraId == camera.id)
        .take(10)
        .toList();

    return Container(
      color: SentinelColors.bgDark,
      child: Column(
        children: [
          // Close button
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('Camera Detail', style: SentinelTypography.headlineMedium),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ref.read(selectedCameraProvider.notifier).state = null;
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: SentinelColors.divider),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera info card
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CameraStatusDot(status: camera.status),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(camera.name, style: SentinelTypography.titleLarge),
                                  Text(camera.id, style: SentinelTypography.monoSmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SentinelSpacing.md),
                        _DetailRow('Location', camera.location),
                        _DetailRow('Resolution', camera.resolution),
                        _DetailRow('Frame Rate', '${camera.fps} FPS'),
                        _DetailRow('Status', camera.status.name.toUpperCase()),
                        _DetailRow(
                          'Coordinates',
                          '${camera.latitude.toStringAsFixed(4)}, ${camera.longitude.toStringAsFixed(4)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SentinelSpacing.md),

                  // Recent detections
                  Text(
                    'Recent Detections (${cameraDetections.length})',
                    style: SentinelTypography.titleMedium,
                  ),
                  const SizedBox(height: SentinelSpacing.sm),
                  if (cameraDetections.isEmpty)
                    Text(
                      'No recent detections',
                      style: SentinelTypography.bodySmall,
                    )
                  else
                    ...cameraDetections.map((d) => Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: d.threat.color.withValues(alpha: 0.06),
                        borderRadius: SentinelRadius.smAll,
                      ),
                      child: Row(
                        children: [
                          Icon(d.type.icon, size: 14, color: d.threat.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.type.label,
                              style: SentinelTypography.bodySmall.copyWith(
                                color: SentinelColors.textPrimary,
                              ),
                            ),
                          ),
                          ThreatBadge(level: d.threat, compact: true),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: SentinelTypography.bodySmall),
          Flexible(
            child: Text(
              value,
              style: SentinelTypography.monoSmall.copyWith(
                color: SentinelColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
