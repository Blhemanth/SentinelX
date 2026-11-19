// SentinelX - Application Entry Point
// Real-time Audio-Visual Urban Anomaly & Crime Detection System
//
// Targets: Windows Desktop (Control Room) & Android Mobile (Field Guard)
// Auth:    JWT-based with role-aware routing (admin | analyst | user)
// Backend: Node.js Express API + Python FastAPI ML microservice
// State Management: Riverpod

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/providers/auth_provider.dart';
import 'package:sentinel_x/features/auth/login_screen.dart';
import 'package:sentinel_x/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SentinelXApp()));
}

class SentinelXApp extends StatelessWidget {
  final Widget? home;
  const SentinelXApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SentinelX',
      debugShowCheckedModeBanner: false,
      theme: SentinelTheme.dark,
      home: home ?? const _AuthGate(),
    );
  }
}

// ─── Auth Gate ─────────────────────────────────────────────────────────────
// Checks for a persisted JWT session. Routes to LoginScreen or AppShell.
// Includes a fail-safe maximum splash duration of 1.5s to prevent infinite loading.

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _timedOut = false;
  Timer? _splashSafetyTimer;

  @override
  void initState() {
    super.initState();
    // Safety guard: never leave the user waiting on splash for more than 1.5 seconds
    _splashSafetyTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && !_timedOut) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _splashSafetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authInit = ref.watch(authInitProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (_timedOut) {
      return isAuthenticated ? const AppShell() : const LoginScreen();
    }

    return authInit.when(
      loading: () => _SentinelSplash(
        onSkip: () => setState(() => _timedOut = true),
      ),
      error: (err, stack) => const LoginScreen(),
      data: (isAuth) {
        if (isAuth || isAuthenticated) {
          return const AppShell();
        }
        return const LoginScreen();
      },
    );
  }
}

// ─── Splash Screen ──────────────────────────────────────────────────────────
// Shown briefly while checking persisted auth tokens on startup.
// Allows clicking/tapping to proceed immediately to LoginScreen.

class _SentinelSplash extends StatelessWidget {
  final VoidCallback? onSkip;
  const _SentinelSplash({this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SentinelColors.bgDarkest,
      body: InkWell(
        onTap: onSkip,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(gradient: SentinelGradients.surfaceGradient),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: SentinelGradients.primaryGradient,
                    borderRadius: SentinelRadius.smAll,
                    boxShadow: SentinelShadows.glow,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'SentinelX',
                  style: SentinelTypography.headlineLarge.copyWith(
                    color: SentinelColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Initializing secure session...',
                  style: SentinelTypography.bodySmall.copyWith(
                    color: SentinelColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SentinelColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
