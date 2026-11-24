// SentinelX - Reusable UI Components
// Glassmorphic cards, threat indicators, status badges, metric tiles, etc.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/models/models.dart';

// ─────────────────────────────────────────────────
// GLASS CARD
// ─────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderColor,
    this.borderRadius = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: SentinelColors.bgCard.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? SentinelColors.glassBorder,
                width: 1,
              ),
              boxShadow: SentinelShadows.soft,
            ),
            padding: padding ?? const EdgeInsets.all(SentinelSpacing.base),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// THREAT LEVEL BADGE
// ─────────────────────────────────────────────────

class ThreatBadge extends StatelessWidget {
  final ThreatLevel level;
  final bool compact;

  const ThreatBadge({
    super.key,
    required this.level,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SentinelRadius.pill),
        border: Border.all(
          color: level.color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        level.label,
        style: (compact
                ? SentinelTypography.labelSmall
                : SentinelTypography.labelLarge)
            .copyWith(color: level.color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// CAMERA STATUS INDICATOR
// ─────────────────────────────────────────────────

class CameraStatusDot extends StatefulWidget {
  final CameraStatus status;
  final double size;

  const CameraStatusDot({
    super.key,
    required this.status,
    this.size = 10,
  });

  @override
  State<CameraStatusDot> createState() => _CameraStatusDotState();
}

class _CameraStatusDotState extends State<CameraStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.status == CameraStatus.online ||
        widget.status == CameraStatus.recording) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.status) {
    CameraStatus.online => SentinelColors.statusOnline,
    CameraStatus.recording => SentinelColors.statusProcessing,
    CameraStatus.maintenance => SentinelColors.statusWarning,
    CameraStatus.offline => SentinelColors.statusOffline,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color,
            boxShadow: [
              BoxShadow(
                color: _color.withValues(
                  alpha: 0.4 + _controller.value * 0.3,
                ),
                blurRadius: 6 + _controller.value * 4,
                spreadRadius: _controller.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────
// METRIC TILE (for dashboard stats)
// ─────────────────────────────────────────────────

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final String? subtitle;
  final double? progress;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.subtitle,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? SentinelColors.accent;

    return GlassCard(
      padding: const EdgeInsets.all(SentinelSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: SentinelRadius.smAll,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: SentinelTypography.bodySmall.copyWith(color: color),
                ),
            ],
          ),
          const SizedBox(height: SentinelSpacing.md),
          Text(value, style: SentinelTypography.monoLarge),
          const SizedBox(height: SentinelSpacing.xs),
          Text(
            label,
            style: SentinelTypography.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          if (progress != null) ...[
            const SizedBox(height: SentinelSpacing.sm),
            ClipRRect(
              borderRadius: SentinelRadius.smAll,
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                backgroundColor: SentinelColors.bgDarkest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SentinelSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isBounded = constraints.hasBoundedWidth;

          if (!isBounded) {
            // Unbounded horizontal parent: shrink-wrap cleanly without flex
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: SentinelColors.accent),
                  const SizedBox(width: SentinelSpacing.sm),
                ],
                Text(
                  title,
                  style: SentinelTypography.headlineMedium,
                ),
                if (trailing != null) ...[
                  const SizedBox(width: SentinelSpacing.sm),
                  trailing!,
                ],
              ],
            );
          }

          // Bounded parent (standard card/page): stretch across full width
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: SentinelColors.accent),
                      const SizedBox(width: SentinelSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        style: SentinelTypography.headlineMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: SentinelSpacing.sm),
                trailing!,
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// PULSING DOT (for live indicators)
// ─────────────────────────────────────────────────

class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({
    super.key,
    this.color = SentinelColors.threatCritical,
    this.size = 8,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: 0.3 + _controller.value * 0.4,
                ),
                blurRadius: 4 + _controller.value * 6,
                spreadRadius: _controller.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────
// SENTINEL BUTTON
// ─────────────────────────────────────────────────

class SentinelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isCompact;
  final Color? color;

  const SentinelButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.isCompact = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? SentinelColors.primary;

    if (isPrimary) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [btnColor, btnColor.withValues(alpha: 0.8)],
          ),
          borderRadius: SentinelRadius.smAll,
          boxShadow: [
            BoxShadow(
              color: btnColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: SentinelRadius.smAll,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 20,
                vertical: isCompact ? 8 : 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: SentinelTypography.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: btnColor,
        side: BorderSide(color: btnColor.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: SentinelRadius.smAll),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 20,
          vertical: isCompact ? 8 : 12,
        ),
      ),
    );
  }
}
