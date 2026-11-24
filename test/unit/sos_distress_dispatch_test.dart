// SentinelX - SOS Distress Workflow & Incident Dispatch Test Suite
// Verifies distress trigger creation, synthetic ID reconciliation,
// and safe law enforcement dispatch without Mongoose ObjectId CastError.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/core/providers/auth_provider.dart';
import 'package:sentinel_x/core/services/incident_dispatch_repository.dart';

class FakeCrimeLogService extends Fake implements CrimeLogService {
  final List<Map<String, dynamic>> createdLogs = [];
  final List<Map<String, dynamic>> dispatchUpdates = [];

  @override
  Future<Map<String, dynamic>?> createCrimeLog(Map<String, dynamic> logData) async {
    const fakeObjectId = '507f1f77bcf86cd799439011'; // 24-char hex MongoDB ObjectId
    final record = {...logData, '_id': fakeObjectId};
    createdLogs.add(record);
    return record;
  }

  @override
  Future<bool> updateDispatchStatus(
    String logId, {
    required String status,
    String? assignedTo,
    String? notes,
    bool? isSimulatedUnit,
  }) async {
    dispatchUpdates.add({
      'logId': logId,
      'status': status,
      'assignedTo': assignedTo,
      'notes': notes,
      'isSimulatedUnit': isSimulatedUnit,
    });
    return true;
  }

  @override
  Future<Map<String, dynamic>?> getLogs({
    int page = 1,
    int limit = 20,
    String? severity,
    String? threatClass,
    String? cameraId,
    bool? acknowledged,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return {'success': true, 'data': []};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('P1-D: SOS Distress Dispatch & ID Reconciliation Tests', () {
    test('Test 1: triggerDistress creates incident and resolves genuine MongoDB ObjectId', () async {
      final fakeService = FakeCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(incidentDispatchProvider.notifier);
      final incident = await notifier.triggerDistress(
        cameraId: 'CAM-001',
        cameraName: 'Laptop Camera 1',
      );

      // Verify created log was posted to backend
      expect(fakeService.createdLogs.length, equals(1));
      expect(fakeService.createdLogs.first['cameraId'], equals('CAM-001'));
      expect(fakeService.createdLogs.first['detectionSource'], equals('manual_entry'));

      // Verify incident ID in state was reconciled to the genuine 24-hex ObjectId
      expect(incident, isNotNull);
      expect(incident!.id, equals('507f1f77bcf86cd799439011'));
      expect(RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(incident.id), isTrue);
    });

    test('Test 2: assignToPolice with synthetic INC-DEMO-001 provisions backend record and avoids CastError', () async {
      final fakeService = FakeCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(incidentDispatchProvider.notifier);

      // Seed state with legacy synthetic incident to test migration
      notifier.setIncidentsForTesting([
        DistressIncident(
          id: 'INC-DEMO-001',
          threatType: 'Acoustic Distress: HELP, HELP',
          confidence: 0.95,
          cameraId: 'CAM-001',
          cameraName: 'Laptop Camera 1',
          location: 'Sector 4',
          timestamp: DateTime.now(),
          decibels: 92.5,
          audioTranscript: 'HELP, HELP',
          status: DispatchStatus.pendingReview,
          spectralFrequencies: const [0.1, 0.2, 0.3, 0.4, 0.5],
        ),
      ]);

      final initialList = container.read(incidentDispatchProvider);
      expect(initialList.first.id, equals('INC-DEMO-001'));

      // Assign to police dispatch
      await notifier.assignToPolice('INC-DEMO-001', unit: 'Unit #104');

      // Verify that backend createCrimeLog was invoked to provision a valid ObjectId
      expect(fakeService.createdLogs.isNotEmpty, isTrue);

      // Verify that updateDispatchStatus was called with the genuine 24-hex ObjectId (NOT INC-DEMO-001)
      expect(fakeService.dispatchUpdates.length, equals(1));
      final update = fakeService.dispatchUpdates.first;
      expect(update['logId'], equals('507f1f77bcf86cd799439011'));
      expect(update['status'], equals('assigned_police'));
      expect(RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(update['logId'] as String), isTrue);

      // Verify state reflects assigned status
      final updatedList = container.read(incidentDispatchProvider);
      expect(updatedList.first.id, equals('507f1f77bcf86cd799439011'));
      expect(updatedList.first.status, equals(DispatchStatus.assignedToPolice));
    });

    test('Test 3: updatePoliceStatus transitions status safely with valid backend ID', () async {
      final fakeService = FakeCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(incidentDispatchProvider.notifier);

      // Trigger distress first to get valid ID
      final incident = await notifier.triggerDistress(cameraId: 'CAM-001');
      expect(incident, isNotNull);
      final validId = incident!.id;

      // Police unit acknowledges and marks En Route
      await notifier.updatePoliceStatus(validId, DispatchStatus.enRoute, notes: 'Unit en route');

      expect(fakeService.dispatchUpdates.length, equals(1));
      final enRouteUpdate = fakeService.dispatchUpdates.last;
      expect(enRouteUpdate['logId'], equals(validId));
      expect(enRouteUpdate['status'], equals('en_route'));

      // Police unit arrives On Scene
      await notifier.updatePoliceStatus(validId, DispatchStatus.onScene, notes: 'Arrived at Gate A');

      expect(fakeService.dispatchUpdates.length, equals(2));
      final onSceneUpdate = fakeService.dispatchUpdates.last;
      expect(onSceneUpdate['logId'], equals(validId));
      expect(onSceneUpdate['status'], equals('on_scene'));
    });
  });
}
