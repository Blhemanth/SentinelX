// SentinelX - User Session State Reset Unit Test
// Verifies that during logout and account switching, all client-side Riverpod
// state is purged, and session generations are incremented.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentinel_x/core/models/models.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/core/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('User Session State Purge & Isolation Tests', () {
    test('resetUserSessionState purges all telemetry, alerts, and navigation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. Populate state across providers
      container.read(detectionsAccumulatorProvider.notifier).addDetections([
        Detection(
          id: 'det-1',
          cameraId: 'CAM-001',
          type: DetectionType.person,
          threat: ThreatLevel.high,
          confidence: 0.88,
          timestamp: DateTime.now(),
          bbox: const BoundingBox(x: 10, y: 10, width: 50, height: 50),
          label: 'Fighting',
        ),
      ]);

      container.read(alertsProvider.notifier).addAlert(
        SecurityAlert(
          id: 'alert-1',
          cameraId: 'CAM-001',
          cameraName: 'Gate A',
          detectionType: DetectionType.person,
          threatLevel: ThreatLevel.critical,
          priority: AlertPriority.critical,
          title: 'Distress Alert',
          description: 'Distress call detected',
          timestamp: DateTime.now(),
        ),
      );

      container.read(threatTimelineProvider.notifier).addEntry(
        ThreatTimelineEntry(
          time: DateTime.now(),
          threatScore: 0.95,
          detectionCount: 1,
        ),
      );

      container.read(currentPageProvider.notifier).state = AppPage.police;

      // Verify state was populated
      expect(container.read(detectionsAccumulatorProvider), isNotEmpty);
      expect(container.read(alertsProvider), isNotEmpty);
      expect(container.read(threatTimelineProvider), isNotEmpty);
      expect(container.read(currentPageProvider), equals(AppPage.police));

      // 2. Invoke session purge
      resetUserSessionState(container);

      // 3. Verify all state is cleanly wiped
      expect(container.read(detectionsAccumulatorProvider), isEmpty);
      expect(container.read(alertsProvider), isEmpty);
      expect(container.read(threatTimelineProvider), isEmpty);
      expect(container.read(incidentDispatchProvider), isEmpty);
      expect(container.read(selectedCameraProvider), isNull);
      expect(container.read(currentPageProvider), equals(AppPage.dashboard));
    });

    test('AuthService sessionGeneration increments on logout and session reset', () async {
      final authService = AuthService();
      final initialGen = authService.sessionGeneration;

      bool resetCallbackFired = false;
      authService.registerSessionResetCallback(() {
        resetCallbackFired = true;
      });

      authService.triggerSessionReset();

      expect(authService.sessionGeneration, equals(initialGen + 1));
      expect(resetCallbackFired, isTrue);

      await authService.logout();
      expect(authService.sessionGeneration, equals(initialGen + 2));
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser, isNull);
    });
  });
}
