// SentinelX - Auth Riverpod Providers
// Exposes AuthService and auth state to the widget tree.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/services/auth_service.dart';
import 'package:sentinel_x/core/services/api_service.dart';
import 'package:sentinel_x/core/services/crime_log_service.dart';

export 'package:sentinel_x/core/services/auth_service.dart';
export 'package:sentinel_x/core/services/api_service.dart';
export 'package:sentinel_x/core/services/crime_log_service.dart';

// ─── Auth Service singleton ───────────────────────────────────────────────
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService();
});

// ─── API Service (depends on authService for token injection) ────────────
final apiServiceProvider = Provider<ApiService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ApiService(authService: authService);
});

// ─── Crime Log Service ────────────────────────────────────────────────────
final crimeLogServiceProvider = Provider<CrimeLogService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return CrimeLogService(apiService);
});

// ─── Auth State (derived) ─────────────────────────────────────────────────
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authServiceProvider).isAuthenticated;
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authServiceProvider).currentUser;
});

// ─── Auth initialization (run once at startup) ────────────────────────────
final authInitProvider = FutureProvider<bool>((ref) async {
  final authService = ref.read(authServiceProvider);
  return authService.initialize();
});

// ─── Role-based helpers ────────────────────────────────────────────────────
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isAdmin ?? false;
});

final isAnalystProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isAnalyst ?? false;
});

final isPoliceProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isPolice ?? false;
});
