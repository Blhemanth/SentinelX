// SentinelX - Incident Dispatch & Distress Drill Verification Test Suite
// Milestone: P1-D Help Detection, SOS Workflow & Incident Dispatch Restoration

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentinel_x/core/providers/providers.dart';
import 'package:sentinel_x/core/providers/auth_provider.dart';
import 'package:sentinel_x/core/services/incident_dispatch_repository.dart';

class MockCrimeLogService extends Fake implements CrimeLogService {
  final List<Map<String, dynamic>> createdLogs = [];
  final List<Map<String, dynamic>> dispatchUpdates = [];
  final List<Map<String, dynamic>> backendDb = [];

  @override
  Future<Map<String, dynamic>?> createCrimeLog(Map<String, dynamic> logData) async {
    final hexId = '6740ad88${(createdLogs.length + 1).toString().padLeft(16, '0')}';
    final record = {
      ...logData,
      '_id': hexId,
      'createdAt': DateTime.now().toIso8601String(),
    };
    createdLogs.add(record);
    backendDb.add(record);
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

    // Update in-memory db
    final idx = backendDb.indexWhere((item) => item['_id'] == logId);
    if (idx != -1) {
      backendDb[idx]['dispatchStatus'] = status;
      if (assignedTo != null) backendDb[idx]['assignedTo'] = assignedTo;
      if (notes != null) backendDb[idx]['policeNotes'] = notes;
    }
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
    return {
      'status': 'success',
      'data': List<Map<String, dynamic>>.from(backendDb),
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('P1-D: Incident Dispatch, Distress Drill & Authorization Suite', () {
    test('1. Manual drill creation creates simulation record with valid 24-hex MongoDB ObjectId', () async {
      final mockService = MockCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(incidentDispatchProvider.notifier);
      final drillIncident = await notifier.triggerDistressDrill(
        cameraId: 'CAM-001',
        cameraName: 'Laptop Camera 1',
        location: 'Zone 1 Admin Plaza',
      );

      expect(drillIncident, isNotNull);
      expect(mockService.createdLogs.length, equals(1));
      final logPayload = mockService.createdLogs.first;

      // Verify drill metadata flags
      expect(logPayload['isSimulation'], isTrue);
      expect(logPayload['detectionSource'], equals('drill_simulation'));
      expect(logPayload['cameraId'], equals('CAM-001'));

      // Verify genuine MongoDB 24-hex ObjectId returned and bound to client state
      expect(drillIncident!.id, equals('6740ad880000000000000001'));
      expect(RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(drillIncident.id), isTrue);
      expect(drillIncident.isDrillSimulation, isTrue);
      expect(drillIncident.status, equals(DispatchStatus.pendingReview));

      // Verify incident is in Riverpod state list
      final stateList = container.read(incidentDispatchProvider);
      expect(stateList.any((i) => i.id == drillIncident.id), isTrue);
    });

    test('2. Initial incident state begins empty without fake INC-DEMO-001 placeholder', () {
      final mockService = MockCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final initialIncidents = container.read(incidentDispatchProvider);
      expect(initialIncidents, isEmpty);
      expect(initialIncidents.any((i) => i.id == 'INC-DEMO-001'), isFalse);
    });

    test('3. Assigning drill incident directs to simulated police training unit', () async {
      final mockService = MockCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(incidentDispatchProvider.notifier);
      final drill = await notifier.triggerDistressDrill(cameraId: 'CAM-001');
      expect(drill, isNotNull);

      // Control Room operator dispatches the drill incident
      await notifier.assignToPolice(drill!.id);

      expect(mockService.dispatchUpdates.length, equals(1));
      final update = mockService.dispatchUpdates.first;
      expect(update['logId'], equals(drill.id));
      expect(update['status'], equals('assigned_police'));
      expect(update['isSimulatedUnit'], isTrue);
      expect(update['assignedTo'], contains('Simulated Police Patrol Unit'));

      // Check client state reflects assignment
      final stateIncidents = container.read(incidentDispatchProvider);
      final updated = stateIncidents.firstWhere((i) => i.id == drill.id);
      expect(updated.status, equals(DispatchStatus.assignedToPolice));
      expect(updated.isAssignedToPolice, isTrue);
      expect(updated.assignedUnit, contains('Simulated Police Patrol Unit'));
    });

    test('4. Full tactical status progression: pendingReview -> assignedToPolice -> enRoute -> onScene -> resolved', () async {
      final mockService = MockCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(incidentDispatchProvider.notifier);
      final drill = await notifier.triggerDistressDrill(cameraId: 'CAM-001');
      final incidentId = drill!.id;

      // 1. Assign to Police
      await notifier.assignToPolice(incidentId);
      expect(container.read(incidentDispatchProvider).first.status, equals(DispatchStatus.assignedToPolice));

      // 2. Unit En Route
      await notifier.updatePoliceStatus(incidentId, DispatchStatus.enRoute, notes: 'Unit en route (ETA 3 mins)');
      expect(container.read(incidentDispatchProvider).first.status, equals(DispatchStatus.enRoute));

      // 3. Unit On Scene
      await notifier.updatePoliceStatus(incidentId, DispatchStatus.onScene, notes: 'Unit on scene at Gate A');
      expect(container.read(incidentDispatchProvider).first.status, equals(DispatchStatus.onScene));

      // 4. Resolved
      await notifier.updatePoliceStatus(incidentId, DispatchStatus.resolved, notes: 'Exercise completed. Area clear.');
      expect(container.read(incidentDispatchProvider).first.status, equals(DispatchStatus.resolved));

      // Verify all 4 status transitions were transmitted with correct backend log IDs
      expect(mockService.dispatchUpdates.length, equals(4));
      expect(mockService.dispatchUpdates[0]['status'], equals('assigned_police'));
      expect(mockService.dispatchUpdates[1]['status'], equals('en_route'));
      expect(mockService.dispatchUpdates[2]['status'], equals('on_scene'));
      expect(mockService.dispatchUpdates[3]['status'], equals('resolved'));
    });

    test('5. Dismiss incident removes incident from client state and resolves it on backend', () async {
      final mockService = MockCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(incidentDispatchProvider.notifier);
      final drill = await notifier.triggerDistressDrill(cameraId: 'CAM-001');
      expect(container.read(incidentDispatchProvider).length, equals(1));

      // Dismiss incident
      await notifier.dismissIncident(drill!.id);

      // Verify removed from client state
      expect(container.read(incidentDispatchProvider), isEmpty);

      // Verify resolved dispatch status update posted to backend
      expect(mockService.dispatchUpdates.any((u) => u['logId'] == drill.id && u['status'] == 'resolved'), isTrue);
    });

    test('6. syncFromBackend retains authenticated drill simulations and maps statuses accurately', () async {
      final mockService = MockCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      // Pre-populate backend DB with a drill and a real incident
      mockService.backendDb.addAll([
        {
          '_id': '6740ad8800000000000000aa',
          'threatClass': 'Acoustic Distress: HELP, HELP (SIMULATION DRILL)',
          'confidence': 0.99,
          'cameraId': 'CAM-001',
          'location': 'West Wing',
          'frameTimestamp': DateTime.now().toIso8601String(),
          'audioDecibels': -14.2,
          'audioTranscript': 'HELP! HELP! EMERGENCY DRILL',
          'dispatchStatus': 'en_route',
          'assignedTo': 'Simulated Police Patrol Unit #104 (Training Drill Response)',
          'detectionSource': 'drill_simulation',
          'detectionStatus': 'anomaly_detected',
          'isSimulation': true,
        },
        {
          '_id': '6740ad8800000000000000bb',
          'threatClass': 'Weapon Detected',
          'confidence': 0.94,
          'cameraId': 'CAM-002',
          'location': 'East Gate',
          'frameTimestamp': DateTime.now().toIso8601String(),
          'audioDecibels': -20.5,
          'audioTranscript': 'Metal click detected',
          'dispatchStatus': 'unassigned',
          'detectionSource': 'model_inference',
          'detectionStatus': 'verified_threat',
          'isSimulation': false,
        },
      ]);

      final notifier = container.read(incidentDispatchProvider.notifier);
      await notifier.syncFromBackend();

      final list = container.read(incidentDispatchProvider);
      expect(list.length, equals(2));

      final drill = list.firstWhere((i) => i.id == '6740ad8800000000000000aa');
      expect(drill.isDrillSimulation, isTrue);
      expect(drill.status, equals(DispatchStatus.enRoute));
      expect(drill.assignedUnit, contains('Simulated Police Patrol Unit'));

      final realThreat = list.firstWhere((i) => i.id == '6740ad8800000000000000bb');
      expect(realThreat.isDrillSimulation, isFalse);
      expect(realThreat.status, equals(DispatchStatus.pendingReview));
    });

    test('7. Active distress banner provider selects pending acoustic SOS drills', () async {
      final mockService = MockCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(incidentDispatchProvider.notifier);
      expect(container.read(activeDistressBannerProvider), isNull);

      final drill = await notifier.triggerDistressDrill(cameraId: 'CAM-001');
      expect(drill, isNotNull);

      // Banner should surface the active pending drill
      final bannerIncident = container.read(activeDistressBannerProvider);
      expect(bannerIncident, isNotNull);
      expect(bannerIncident!.id, equals(drill!.id));
      expect(bannerIncident.isDrillSimulation, isTrue);
    });

    test('8. Logout / clearAll resets all incident state in memory', () async {
      final mockService = MockCrimeLogService();
      final container = ProviderContainer(
        overrides: [
          crimeLogServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(incidentDispatchProvider.notifier);
      await notifier.triggerDistressDrill(cameraId: 'CAM-001');
      expect(container.read(incidentDispatchProvider).isNotEmpty, isTrue);

      notifier.clearAll();
      expect(container.read(incidentDispatchProvider), isEmpty);
    });
  });
}
