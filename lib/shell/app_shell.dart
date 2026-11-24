// SentinelX - Adaptive App Shell
// Provides the navigation skeleton: multi-pane sidebar for Windows,
// bottom navigation bar for Android.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/core/utils/platform_utils.dart';
import 'package:sentinel_x/features/dashboard/screens/dashboard_screen.dart';
import 'package:sentinel_x/features/cameras/cameras_page.dart';
import 'package:sentinel_x/features/alerts/alerts_page.dart';
import 'package:sentinel_x/features/analytics/analytics_page.dart';
import 'package:sentinel_x/features/audio/audio_page.dart';
import 'package:sentinel_x/features/police/police_dispatch_page.dart';
import 'package:sentinel_x/features/settings/settings_page.dart';
import 'package:sentinel_x/core/providers/auth_provider.dart';
import 'package:sentinel_x/features/auth/login_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    ref.read(authServiceProvider).registerSessionResetCallback(_onSessionReset);
    // Start inference engines
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user?.role == 'police') {
        ref.read(currentPageProvider.notifier).state = AppPage.police;
      }
      final engine = ref.read(inferenceEngineProvider);
      engine.start();
      ref.read(inferenceRunningProvider.notifier).state = true;
      ref.read(mockInferenceServiceProvider).start();

      // Bind continuous real-time ONNX inference scheduler and detection sync
      final scheduler = ref.read(continuousInferenceSchedulerProvider);
      ref.read(inferenceRepositoryProvider).bindScheduler(scheduler);
      ref.read(detectionSyncServiceProvider);
    });
  }

  void _onSessionReset() {
    if (mounted) {
      resetUserSessionState(ref);
    }
  }

  @override
  void dispose() {
    ref.read(authServiceProvider).unregisterSessionResetCallback(_onSessionReset);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(currentPageProvider);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= LayoutBreakpoints.medium;

    // On Windows/wide screens: NavigationRail + content
    // On Android/narrow screens: BottomNavigationBar
    if (isWide) {
      return _DesktopShell(currentPage: currentPage);
    } else {
      return _MobileShell(currentPage: currentPage);
    }
  }
}

// ─────────────────────────────────────────────────
// DESKTOP SHELL (Windows - sidebar + content)
// ─────────────────────────────────────────────────

class _DesktopShell extends ConsumerWidget {
  final AppPage currentPage;
  const _DesktopShell({required this.currentPage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);
    final unacknowledgedCount = alerts.where((a) => !a.acknowledged).length;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar navigation
          _DesktopSidebar(
            currentPage: currentPage,
            alertCount: unacknowledgedCount,
            onPageChanged: (page) {
              ref.read(currentPageProvider.notifier).state = page;
            },
          ),
          // Vertical divider
          Container(width: 1, color: SentinelColors.divider),
          // Main content
          Expanded(
            child: _buildPage(currentPage),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends ConsumerStatefulWidget {
  final AppPage currentPage;
  final int alertCount;
  final ValueChanged<AppPage> onPageChanged;

  const _DesktopSidebar({
    required this.currentPage,
    required this.alertCount,
    required this.onPageChanged,
  });

  @override
  ConsumerState<_DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<_DesktopSidebar> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: _isExpanded ? 220 : 72,
      decoration: const BoxDecoration(
        color: SentinelColors.bgDark,
      ),
      child: Column(
        children: [
          // Logo / Brand
          _buildBrand(),
          const SizedBox(height: SentinelSpacing.lg),
          // Nav items
          ..._navItems.map((item) => _buildNavItem(item)),
          const Spacer(),
          // User Profile & Role Badge
          _buildUserProfile(user),
          const SizedBox(height: SentinelSpacing.sm),
          // Collapse toggle
          _buildCollapseButton(),
          const SizedBox(height: SentinelSpacing.base),
        ],
      ),
    );
  }

  Widget _buildUserProfile(AuthUser? user) {
    final role = user?.role.toUpperCase() ?? 'OFFLINE';
    final name = user?.name ?? 'Operator';

    final Color roleColor = switch (user?.role) {
      'admin' => SentinelColors.threatCritical,
      'police' => const Color(0xFF2979FF),
      'analyst' => SentinelColors.accent,
      _ => SentinelColors.primary,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: EdgeInsets.symmetric(
        horizontal: _isExpanded ? 10 : 6,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: SentinelColors.bgSurface,
        borderRadius: SentinelRadius.smAll,
        border: Border.all(color: SentinelColors.divider),
      ),
      child: Row(
        mainAxisAlignment: _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: roleColor.withValues(alpha: 0.2),
            child: Icon(Icons.person_outline, size: 16, color: roleColor),
          ),
          if (_isExpanded) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: SentinelTypography.bodySmall.copyWith(
                      color: SentinelColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    role,
                    style: SentinelTypography.labelSmall.copyWith(
                      color: roleColor,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, size: 16, color: SentinelColors.textTertiary),
              tooltip: 'Logout',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () async {
                resetUserSessionState(ref);
                await ref.read(authServiceProvider).logout();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: SentinelGradients.primaryGradient,
              borderRadius: SentinelRadius.smAll,
              boxShadow: SentinelShadows.glow,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SentinelX',
                    style: SentinelTypography.headlineMedium.copyWith(
                      foreground: Paint()
                        ..shader = SentinelGradients.primaryGradient
                            .createShader(
                                const Rect.fromLTWH(0, 0, 120, 24)),
                    ),
                  ),
                  Text(
                    'v0.1.0 • ACTIVE',
                    style: SentinelTypography.labelSmall.copyWith(
                      color: SentinelColors.statusOnline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItem item) {
    final isSelected = widget.currentPage == item.page;
    final hasAlert = item.page == AppPage.alerts && widget.alertCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onPageChanged(item.page),
          borderRadius: SentinelRadius.smAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 14 : 0,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? SentinelColors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: SentinelRadius.smAll,
              border: isSelected
                  ? Border.all(
                      color: SentinelColors.primary.withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: _isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: 20,
                      color: isSelected
                          ? SentinelColors.primary
                          : SentinelColors.textTertiary,
                    ),
                    if (hasAlert)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: SentinelColors.threatCritical,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              widget.alertCount > 9
                                  ? '9+'
                                  : '${widget.alertCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: SentinelTypography.titleMedium.copyWith(
                        color: isSelected
                            ? SentinelColors.textPrimary
                            : SentinelColors.textTertiary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton() {
    return IconButton(
      onPressed: () => setState(() => _isExpanded = !_isExpanded),
      icon: Icon(
        _isExpanded
            ? Icons.chevron_left_rounded
            : Icons.chevron_right_rounded,
        color: SentinelColors.textTertiary,
      ),
      tooltip: _isExpanded ? 'Collapse' : 'Expand',
    );
  }
}

// ─────────────────────────────────────────────────
// MOBILE SHELL (Android - bottom nav)
// ─────────────────────────────────────────────────

class _MobileShell extends ConsumerWidget {
  final AppPage currentPage;
  const _MobileShell({required this.currentPage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);
    final unacknowledgedCount = alerts.where((a) => !a.acknowledged).length;

    final pageIndex = _mobilePages.indexOf(currentPage).clamp(0, _mobilePages.length - 1);

    return Scaffold(
      body: _buildPage(currentPage),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: SentinelColors.bgDark,
          border: Border(
            top: BorderSide(color: SentinelColors.divider),
          ),
        ),
        child: NavigationBar(
          selectedIndex: pageIndex,
          onDestinationSelected: (index) {
            ref.read(currentPageProvider.notifier).state =
                _mobilePages[index];
          },
          backgroundColor: Colors.transparent,
          indicatorColor: SentinelColors.primary.withValues(alpha: 0.15),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: SentinelColors.primary),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Icons.videocam_outlined),
              selectedIcon: Icon(Icons.videocam, color: SentinelColors.primary),
              label: 'Cameras',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unacknowledgedCount > 0,
                label: Text('$unacknowledgedCount'),
                child: const Icon(Icons.notifications_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: unacknowledgedCount > 0,
                label: Text('$unacknowledgedCount'),
                child: const Icon(Icons.notifications, color: SentinelColors.primary),
              ),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics, color: SentinelColors.primary),
              label: 'Analytics',
            ),
            const NavigationDestination(
              icon: Icon(Icons.graphic_eq_outlined),
              selectedIcon: Icon(Icons.graphic_eq, color: SentinelColors.primary),
              label: 'Audio',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// SHARED
// ─────────────────────────────────────────────────

const _mobilePages = [
  AppPage.dashboard,
  AppPage.cameras,
  AppPage.alerts,
  AppPage.analytics,
  AppPage.audio,
];

Widget _buildPage(AppPage page) {
  return switch (page) {
    AppPage.dashboard => const DashboardScreen(),
    AppPage.cameras => const CamerasPage(),
    AppPage.alerts => const AlertsPage(),
    AppPage.analytics => const AnalyticsPage(),
    AppPage.audio => const AudioPage(),
    AppPage.police => const PoliceDispatchPage(),
    AppPage.settings => const SettingsPage(),
  };
}

class _NavItem {
  final AppPage page;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.page,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

const _navItems = [
  _NavItem(
    page: AppPage.dashboard,
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
  ),
  _NavItem(
    page: AppPage.cameras,
    label: 'Camera Feeds',
    icon: Icons.videocam_outlined,
    activeIcon: Icons.videocam,
  ),
  _NavItem(
    page: AppPage.alerts,
    label: 'Alerts',
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
  ),
  _NavItem(
    page: AppPage.police,
    label: 'Police Dispatch',
    icon: Icons.local_police_outlined,
    activeIcon: Icons.local_police,
  ),
  _NavItem(
    page: AppPage.analytics,
    label: 'Analytics',
    icon: Icons.analytics_outlined,
    activeIcon: Icons.analytics,
  ),
  _NavItem(
    page: AppPage.audio,
    label: 'Audio Monitor',
    icon: Icons.graphic_eq_outlined,
    activeIcon: Icons.graphic_eq,
  ),
  _NavItem(
    page: AppPage.settings,
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
  ),
];
