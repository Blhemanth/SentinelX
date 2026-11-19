// SentinelX - Design System & Theme Configuration
// Provides the entire visual identity: colors, typography, spacing, shadows, gradients.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────
// COLOR PALETTE
// ─────────────────────────────────────────────────

class SentinelColors {
  SentinelColors._();

  // Primary brand gradient anchor
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF8B7CF6);
  static const Color primaryDark = Color(0xFF4A3FB5);

  // Accent / Cyberpunk teal
  static const Color accent = Color(0xFF00CFCF);
  static const Color accentLight = Color(0xFF5CEBDF);
  static const Color accentDark = Color(0xFF009E9E);

  // Threat severity spectrum
  static const Color threatCritical = Color(0xFFFF3B5C);
  static const Color threatHigh = Color(0xFFFF6B35);
  static const Color threatMedium = Color(0xFFFFBB33);
  static const Color threatLow = Color(0xFF00E676);
  static const Color threatNone = Color(0xFF69F0AE);

  // Surface / Background (dark mode)
  static const Color bgDarkest = Color(0xFF0A0A14);
  static const Color bgDark = Color(0xFF0F0F23);
  static const Color bgSurface = Color(0xFF161631);
  static const Color bgCard = Color(0xFF1C1C3D);
  static const Color bgElevated = Color(0xFF24244A);
  static const Color bgHover = Color(0xFF2D2D5A);

  // Text
  static const Color textPrimary = Color(0xFFF0F0FF);
  static const Color textSecondary = Color(0xFFB0B0D0);
  static const Color textTertiary = Color(0xFF7070A0);
  static const Color textMuted = Color(0xFF505070);

  // Status
  static const Color statusOnline = Color(0xFF00E676);
  static const Color statusOffline = Color(0xFFFF3B5C);
  static const Color statusWarning = Color(0xFFFFBB33);
  static const Color statusProcessing = Color(0xFF448AFF);

  // Borders & Dividers
  static const Color border = Color(0xFF2A2A50);
  static const Color borderLight = Color(0xFF3A3A60);
  static const Color divider = Color(0xFF1E1E3E);

  // Glassmorphism overlays
  static const Color glassWhite = Color(0x0DFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
}

// ─────────────────────────────────────────────────
// GRADIENTS
// ─────────────────────────────────────────────────

class SentinelGradients {
  SentinelGradients._();

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SentinelColors.primary, SentinelColors.accent],
  );

  static const LinearGradient threatGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      SentinelColors.threatLow,
      SentinelColors.threatMedium,
      SentinelColors.threatHigh,
      SentinelColors.threatCritical,
    ],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [SentinelColors.bgDark, SentinelColors.bgDarkest],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SentinelColors.bgCard, SentinelColors.bgSurface],
  );

  static const LinearGradient accentGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x336C5CE7), Color(0x0000CFCF)],
  );

  static const RadialGradient dangerPulse = RadialGradient(
    center: Alignment.center,
    radius: 0.8,
    colors: [Color(0x33FF3B5C), Color(0x00FF3B5C)],
  );
}

// ─────────────────────────────────────────────────
// SPACING SYSTEM (8px base grid)
// ─────────────────────────────────────────────────

class SentinelSpacing {
  SentinelSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;
}

// ─────────────────────────────────────────────────
// BORDER RADIUS
// ─────────────────────────────────────────────────

class SentinelRadius {
  SentinelRadius._();

  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 100;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

// ─────────────────────────────────────────────────
// SHADOWS & ELEVATION
// ─────────────────────────────────────────────────

class SentinelShadows {
  SentinelShadows._();

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get glow => [
    BoxShadow(
      color: SentinelColors.primary.withValues(alpha: 0.3),
      blurRadius: 24,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> get accentGlow => [
    BoxShadow(
      color: SentinelColors.accent.withValues(alpha: 0.3),
      blurRadius: 24,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> get dangerGlow => [
    BoxShadow(
      color: SentinelColors.threatCritical.withValues(alpha: 0.4),
      blurRadius: 24,
      spreadRadius: 2,
    ),
  ];
}

// ─────────────────────────────────────────────────
// TYPOGRAPHY
// ─────────────────────────────────────────────────

class SentinelTypography {
  SentinelTypography._();

  static TextStyle get displayLarge => GoogleFonts.exo2(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    color: SentinelColors.textPrimary,
  );

  static TextStyle get displayMedium => GoogleFonts.exo2(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: SentinelColors.textPrimary,
  );

  static TextStyle get headlineLarge => GoogleFonts.exo2(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: SentinelColors.textPrimary,
  );

  static TextStyle get headlineMedium => GoogleFonts.exo2(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: SentinelColors.textPrimary,
  );

  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: SentinelColors.textPrimary,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: SentinelColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: SentinelColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: SentinelColors.textSecondary,
    height: 1.45,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: SentinelColors.textTertiary,
  );

  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: SentinelColors.textPrimary,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: SentinelColors.textTertiary,
  );

  static TextStyle get monoLarge => GoogleFonts.jetBrainsMono(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: SentinelColors.accent,
  );

  static TextStyle get monoMedium => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: SentinelColors.accent,
  );

  static TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: SentinelColors.textTertiary,
  );
}

// ─────────────────────────────────────────────────
// THEME DATA
// ─────────────────────────────────────────────────

class SentinelTheme {
  SentinelTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: SentinelColors.bgDarkest,
      colorScheme: const ColorScheme.dark(
        primary: SentinelColors.primary,
        secondary: SentinelColors.accent,
        surface: SentinelColors.bgSurface,
        error: SentinelColors.threatCritical,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: SentinelColors.textPrimary,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: SentinelColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: SentinelRadius.lgAll,
          side: const BorderSide(color: SentinelColors.border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: SentinelColors.bgDark,
        elevation: 0,
        titleTextStyle: SentinelTypography.headlineMedium,
        iconTheme: const IconThemeData(color: SentinelColors.textSecondary),
      ),
      iconTheme: const IconThemeData(
        color: SentinelColors.textSecondary,
        size: 20,
      ),
      dividerTheme: const DividerThemeData(
        color: SentinelColors.divider,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: SentinelColors.bgElevated,
          borderRadius: SentinelRadius.smAll,
          border: Border.all(color: SentinelColors.border),
        ),
        textStyle: SentinelTypography.bodySmall.copyWith(
          color: SentinelColors.textPrimary,
        ),
      ),
    );
  }
}
