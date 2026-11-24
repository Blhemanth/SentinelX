// SentinelX - Incident Dispatch Repository
// Manages real-time distress incidents, voice triggers ("HELP, HELP"),
// incident video clip capture, and Control Room -> Police dispatch workflow.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/providers/auth_provider.dart';

// ─────────────────────────────────────────────────
// INCIDENT DISPATCH STATUS ENUM
// ─────────────────────────────────────────────────

enum DispatchStatus {
  pendingReview, // Detected by AI, awaiting Control Room action
  assignedToPolice, // Control Room assigned incident to Police
  enRoute, // Police acknowledged and dispatched unit en route
  onScene, // Police unit arrived on scene
  resolved; // Incident neutralized and secured

  String get label => switch (this) {
        DispatchStatus.pendingReview => 'PENDING REVIEW',
        DispatchStatus.assignedToPolice => 'ASSIGNED TO POLICE',
        DispatchStatus.enRoute => 'EN ROUTE',
        DispatchStatus.onScene => 'ON SCENE',
        DispatchStatus.resolved => 'RESOLVED & SECURED',
      };
}

// ─────────────────────────────────────────────────
// DISTRESS INCIDENT MODEL
// ─────────────────────────────────────────────────

class DistressIncident {
  final String id;
  final String threatType;
  final double confidence;
  final String cameraId;
  final String cameraName;
  final String location;
  final DateTime timestamp;
  final double decibels;
  final String audioTranscript;
  final DispatchStatus status;
  final String? assignedUnit;
  final String? policeNotes;
  final List<double> spectralFrequencies;
  final int clipDurationSeconds;
  final bool isRecordingActive;
  final String detectionStatus;
  final String detectionSource;

  const DistressIncident({
    required this.id,
    required this.threatType,
    required this.confidence,
    required this.cameraId,
    required this.cameraName,
    required this.location,
    required this.timestamp,
    required this.decibels,
    required this.audioTranscript,
    this.status = DispatchStatus.pendingReview,
    this.assignedUnit,
    this.policeNotes,
    required this.spectralFrequencies,
    this.clipDurationSeconds = 6,
    this.isRecordingActive = false,
    this.detectionStatus = 'legacy_unclassified',
    this.detectionSource = 'legacy_unspecified',
  });

  bool get isAssignedToPolice =>
      status == DispatchStatus.assignedToPolice ||
      status == DispatchStatus.enRoute ||
      status == DispatchStatus.onScene;

  bool get isResolved => status == DispatchStatus.resolved;

  bool get isDrillSimulation => detectionSource == 'drill_simulation';
  bool get isAcousticSos => detectionSource == 'acoustic_sos' || threatType.contains('HELP');
  bool get isNormal => threatType == 'Normal';

  bool get isCriticalThreat =>
      !isNormal &&
      confidence >= 0.85 &&
      (detectionSource == 'ml_real' || isAcousticSos || isDrillSimulation);

  bool get isHighThreat =>
      !isNormal &&
      confidence >= 0.70 &&
      confidence < 0.85 &&
      (detectionSource == 'ml_real' || isDrillSimulation);

  bool get isMediumThreat =>
      !isNormal &&
      confidence >= 0.50 &&
      confidence < 0.70 &&
      (detectionSource == 'ml_real' || isDrillSimulation);

  bool get isLowConfidenceReview =>
      detectionStatus == 'low_confidence_review' || (!isNormal && confidence < 0.50);

  String get severity {
    if (detectionStatus == 'subprocess_fallback' || detectionSource == 'subprocess_fallback') {
      return 'low';
    }
    if (detectionStatus == 'low_confidence_review') return 'low';
    if (detectionStatus == 'legacy_unclassified' || detectionSource == 'legacy_unspecified') {
      return 'normal';
    }
    if (isNormal) return 'normal';
    if (isCriticalThreat) return 'critical';
    if (isHighThreat) return 'high';
    if (isMediumThreat) return 'medium';
    return 'low';
  }

  DistressIncident copyWith({
    DispatchStatus? status,
    String? assignedUnit,
    String? policeNotes,
    bool? isRecordingActive,
    String? detectionStatus,
    String? detectionSource,
  }) {
    return DistressIncident(
      id: id,
      threatType: threatType,
      confidence: confidence,
      cameraId: cameraId,
      cameraName: cameraName,
      location: location,
      timestamp: timestamp,
      decibels: decibels,
      audioTranscript: audioTranscript,
      status: status ?? this.status,
      assignedUnit: assignedUnit ?? this.assignedUnit,
      policeNotes: policeNotes ?? this.policeNotes,
      spectralFrequencies: spectralFrequencies,
      clipDurationSeconds: clipDurationSeconds,
      isRecordingActive: isRecordingActive ?? this.isRecordingActive,
      detectionStatus: detectionStatus ?? this.detectionStatus,
      detectionSource: detectionSource ?? this.detectionSource,
    );
  }
}

// ─────────────────────────────────────────────────
// INCIDENT DISPATCH NOTIFIER
// ─────────────────────────────────────────────────

class IncidentDispatchNotifier extends StateNotifier<List<DistressIncident>> {
  final Ref _ref;

  IncidentDispatchNotifier(this._ref) : super([]) {
    _initDefaultSampleIncident();
    // Non-blocking sync with backend
    Future.microtask(() => syncFromBackend());
  }

  void _initDefaultSampleIncident() {
    // Initial state begins clean; populated strictly from backend or authenticated drill creation
    state = [];
  }

  @visibleForTesting
  void setIncidentsForTesting(List<DistressIncident> incidents) {
    state = incidents;
  }

  /// Triggers an authenticated manual distress drill simulation.
  /// Persists directly to MongoDB via CrimeLogService, awaits the real 24-hex ObjectId,
  /// and updates client state with the authoritative database record.
  Future<DistressIncident?> triggerDistressDrill({
    required String cameraId,
    String? cameraName,
    String? location,
    String? customTranscript,
  }) async {
    final now = DateTime.now();
    try {
      final crimeLogService = _ref.read(crimeLogServiceProvider);
      final created = await crimeLogService.createCrimeLog({
        'threatClass': 'Acoustic Distress: HELP, HELP (SIMULATION DRILL)',
        'confidence': 0.988,
        'cameraId': cameraId,
        'location': location ?? 'Primary Perimeter // Gate A',
        'frameTimestamp': now.toIso8601String(),
        'audioDecibels': -12.4, // Calibrated dBFS
        'audioTranscript': customTranscript ??
            'SIMULATED DRILL DISTRESS: "HELP! HELP! EMERGENCY DRILL EXERCISE"',
        'dispatchStatus': 'unassigned',
        'detectionSource': 'drill_simulation',
        'detectionStatus': 'anomaly_detected',
        'isSimulation': true,
        'audioFrequencies': const [
          0.18, 0.32, 0.60, 0.89, 0.98, 0.94, 0.86, 0.92, 0.97, 0.85,
          0.78, 0.68, 0.58, 0.48, 0.38, 0.28, 0.22, 0.18, 0.14, 0.11,
        ],
        'boundingBox': {'x': 0.22, 'y': 0.18, 'w': 0.44, 'h': 0.56},
      });

      if (created != null && created['_id'] != null) {
        final realId = created['_id'].toString();
        final incident = DistressIncident(
          id: realId,
          threatType: 'Acoustic Distress: HELP, HELP (SIMULATION DRILL)',
          confidence: 0.988,
          cameraId: cameraId,
          cameraName: cameraName ?? 'Laptop Camera 1 (Local Hardware Webcam)',
          location: location ?? 'Primary Perimeter // Gate A',
          timestamp: now,
          decibels: -12.4,
          audioTranscript: customTranscript ??
              'SIMULATED DRILL DISTRESS: "HELP! HELP! EMERGENCY DRILL EXERCISE"',
          status: DispatchStatus.pendingReview,
          spectralFrequencies: const [
            0.18, 0.32, 0.60, 0.89, 0.98, 0.94, 0.86, 0.92, 0.97, 0.85,
            0.78, 0.68, 0.58, 0.48, 0.38, 0.28, 0.22, 0.18, 0.14, 0.11,
          ],
          clipDurationSeconds: 6,
          isRecordingActive: false,
          detectionStatus: 'anomaly_detected',
          detectionSource: 'drill_simulation',
        );

        state = [incident, ...state.where((i) => i.id != realId)];
        return incident;
      }
    } catch (e) {
      debugPrint('[IncidentDispatch] triggerDistressDrill error: $e');
    }
    return null;
  }

  /// Triggered when distress is reported or manually triggered.
  /// Awaits MongoDB persistence before retaining document ID.
  Future<DistressIncident?> triggerDistress({
    required String cameraId,
    String? cameraName,
    String? location,
    String? customTranscript,
  }) async {
    final now = DateTime.now();
    try {
      final crimeLogService = _ref.read(crimeLogServiceProvider);
      final created = await crimeLogService.createCrimeLog({
        'threatClass': 'Acoustic Distress: HELP, HELP',
        'confidence': 0.989,
        'cameraId': cameraId,
        'location': location ??
            (cameraId == 'CAM-002' ? 'Mobile Sector // North Gate' : 'Main Hall // Primary Terminal'),
        'frameTimestamp': now.toIso8601String(),
        'audioDecibels': -11.2,
        'audioTranscript': customTranscript ??
            'Critical Acoustic Distress Detected: "HELP! HELP! EMERGENCY AT SECTOR"',
        'dispatchStatus': 'unassigned',
        'detectionSource': 'manual_entry',
        'detectionStatus': 'low_confidence_review',
        'audioFrequencies': const [
          0.18, 0.32, 0.60, 0.89, 0.98, 0.94, 0.86, 0.92, 0.97, 0.85,
          0.78, 0.68, 0.58, 0.48, 0.38, 0.28, 0.22, 0.18, 0.14, 0.11,
        ],
        'boundingBox': {'x': 0.22, 'y': 0.18, 'w': 0.44, 'h': 0.56},
      });

      if (created != null && created['_id'] != null) {
        final realId = created['_id'].toString();
        final incident = DistressIncident(
          id: realId,
          threatType: 'Acoustic Distress: HELP, HELP',
          confidence: 0.989,
          cameraId: cameraId,
          cameraName: cameraName ??
              (cameraId == 'CAM-002'
                  ? 'Phone Camera 2 (Wireless IP Stream)'
                  : 'Laptop Camera 1 (Local Hardware Webcam)'),
          location: location ??
              (cameraId == 'CAM-002' ? 'Mobile Sector // North Gate' : 'Main Hall // Primary Terminal'),
          timestamp: now,
          decibels: -11.2,
          audioTranscript: customTranscript ??
              'Critical Acoustic Distress Detected: "HELP! HELP! EMERGENCY AT SECTOR"',
          status: DispatchStatus.pendingReview,
          spectralFrequencies: const [
            0.18, 0.32, 0.60, 0.89, 0.98, 0.94, 0.86, 0.92, 0.97, 0.85,
            0.78, 0.68, 0.58, 0.48, 0.38, 0.28, 0.22, 0.18, 0.14, 0.11,
          ],
          clipDurationSeconds: 6,
          isRecordingActive: false,
          detectionStatus: 'low_confidence_review',
          detectionSource: 'manual_entry',
        );

        state = [incident, ...state.where((i) => i.id != realId)];
        return incident;
      }
    } catch (e) {
      debugPrint('[IncidentDispatch] triggerDistress error: $e');
    }
    return null;
  }

  /// Control Room (Admin) assigns incident to Police Dispatch.
  Future<void> assignToPolice(String incidentId, {String? unit}) async {
    final target = state.where((i) => i.id == incidentId).firstOrNull;
    final isDrill = target?.isDrillSimulation ?? false;
    final assignedUnit = unit ??
        (isDrill
            ? 'Simulated Police Patrol Unit #104 (Training Drill Response)'
            : 'Metro Police Patrol Unit #104 (Immediate Tactical Response)');
    final policeNotes = isDrill
        ? 'Training drill response dispatched to simulated unit. Drill exercise in progress.'
        : 'Incident escalated by Control Room Admin. Dispatch alert transmitted.';

    state = [
      for (final inc in state)
        if (inc.id == incidentId)
          inc.copyWith(
            status: DispatchStatus.assignedToPolice,
            assignedUnit: assignedUnit,
            policeNotes: policeNotes,
          )
        else
          inc
    ];

    try {
      final crimeLogService = _ref.read(crimeLogServiceProvider);
      String backendId = incidentId;

      // If incidentId is synthetic (e.g. temporary ID not matching 24-hex ObjectId)
      if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(incidentId) && target != null) {
        final created = await crimeLogService.createCrimeLog({
          'threatClass': target.threatType,
          'confidence': target.confidence,
          'cameraId': target.cameraId,
          'location': target.location,
          'frameTimestamp': target.timestamp.toIso8601String(),
          'audioDecibels': target.decibels,
          'audioTranscript': target.audioTranscript,
          'dispatchStatus': 'unassigned',
          'detectionSource': target.detectionSource,
          'detectionStatus': target.detectionStatus,
          'isSimulation': isDrill,
          'audioFrequencies': target.spectralFrequencies,
          'boundingBox': {'x': 0.22, 'y': 0.18, 'w': 0.44, 'h': 0.56},
        });
        if (created != null && created['_id'] != null) {
          backendId = created['_id'].toString();
          state = [
            for (final inc in state)
              if (inc.id == incidentId)
                DistressIncident(
                  id: backendId,
                  threatType: inc.threatType,
                  confidence: inc.confidence,
                  cameraId: inc.cameraId,
                  cameraName: inc.cameraName,
                  location: inc.location,
                  timestamp: inc.timestamp,
                  decibels: inc.decibels,
                  audioTranscript: inc.audioTranscript,
                  status: inc.status,
                  assignedUnit: inc.assignedUnit,
                  policeNotes: inc.policeNotes,
                  spectralFrequencies: inc.spectralFrequencies,
                  clipDurationSeconds: inc.clipDurationSeconds,
                  isRecordingActive: inc.isRecordingActive,
                  detectionStatus: inc.detectionStatus,
                  detectionSource: inc.detectionSource,
                )
              else
                inc
          ];
        }
      }

      await crimeLogService.updateDispatchStatus(
        backendId,
        status: 'assigned_police',
        assignedTo: assignedUnit,
        notes: policeNotes,
        isSimulatedUnit: isDrill,
      );
    } catch (e) {
      debugPrint('[IncidentDispatch] assignToPolice note: $e');
    }
  }

  /// Police updates dispatch status (e.g. En Route, On Scene, Resolved).
  Future<void> updatePoliceStatus(String incidentId, DispatchStatus newStatus, {String? notes}) async {
    final target = state.where((i) => i.id == incidentId).firstOrNull;

    state = [
      for (final inc in state)
        if (inc.id == incidentId)
          inc.copyWith(
            status: newStatus,
            policeNotes: notes ?? inc.policeNotes,
          )
        else
          inc
    ];

    try {
      final crimeLogService = _ref.read(crimeLogServiceProvider);
      String backendId = incidentId;

      if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(incidentId) && target != null) {
        final created = await crimeLogService.createCrimeLog({
          'threatClass': target.threatType,
          'confidence': target.confidence,
          'cameraId': target.cameraId,
          'location': target.location,
          'frameTimestamp': target.timestamp.toIso8601String(),
          'audioDecibels': target.decibels,
          'audioTranscript': target.audioTranscript,
          'dispatchStatus': 'unassigned',
          'detectionSource': target.detectionSource,
          'detectionStatus': target.detectionStatus,
          'isSimulation': target.isDrillSimulation,
          'audioFrequencies': target.spectralFrequencies,
          'boundingBox': {'x': 0.22, 'y': 0.18, 'w': 0.44, 'h': 0.56},
        });
        if (created != null && created['_id'] != null) {
          backendId = created['_id'].toString();
          state = [
            for (final inc in state)
              if (inc.id == incidentId)
                DistressIncident(
                  id: backendId,
                  threatType: inc.threatType,
                  confidence: inc.confidence,
                  cameraId: inc.cameraId,
                  cameraName: inc.cameraName,
                  location: inc.location,
                  timestamp: inc.timestamp,
                  decibels: inc.decibels,
                  audioTranscript: inc.audioTranscript,
                  status: inc.status,
                  assignedUnit: inc.assignedUnit,
                  policeNotes: inc.policeNotes,
                  spectralFrequencies: inc.spectralFrequencies,
                  clipDurationSeconds: inc.clipDurationSeconds,
                  isRecordingActive: inc.isRecordingActive,
                  detectionStatus: inc.detectionStatus,
                  detectionSource: inc.detectionSource,
                )
              else
                inc
          ];
        }
      }

      final backendStatus = switch (newStatus) {
        DispatchStatus.pendingReview => 'unassigned',
        DispatchStatus.assignedToPolice => 'assigned_police',
        DispatchStatus.enRoute => 'en_route',
        DispatchStatus.onScene => 'on_scene',
        DispatchStatus.resolved => 'resolved',
      };
      await crimeLogService.updateDispatchStatus(
        backendId,
        status: backendStatus,
        notes: notes,
      );
    } catch (e) {
      debugPrint('[IncidentDispatch] updatePoliceStatus note: $e');
    }
  }

  /// Syncs incidents from backend MongoDB
  Future<void> syncFromBackend() async {
    final startGen = _ref.read(authServiceProvider).sessionGeneration;
    try {
      final crimeLogService = _ref.read(crimeLogServiceProvider);
      final res = await crimeLogService.getLogs(limit: 25);
      if (_ref.read(authServiceProvider).sessionGeneration != startGen) {
        debugPrint('[IncidentDispatch] Session generation changed during sync. Discarding stale response.');
        return;
      }
      if (res != null && res['data'] is List) {
        final logs = res['data'] as List;
        for (final raw in logs) {
          if (raw is Map<String, dynamic>) {
            final id = raw['_id']?.toString() ?? '';
            final threatClass = raw['threatClass']?.toString() ?? 'Normal';
            final detStatus = raw['detectionStatus']?.toString() ?? 'legacy_unclassified';
            final detSource = raw['detectionSource']?.toString() ?? 'legacy_unspecified';
            final isSim = raw['isSimulation'] == true || detSource == 'drill_simulation';
            final effectiveDetSource = isSim ? 'drill_simulation' : detSource;

            // Filter out Normal predictions, fallbacks, and unverified legacy records
            if (threatClass == 'Normal' ||
                id.isEmpty ||
                detStatus == 'subprocess_fallback' ||
                detSource == 'subprocess_fallback' ||
                detStatus == 'legacy_unclassified' ||
                detSource == 'legacy_unspecified') {
              continue;
            }

            final existingIdx = state.indexWhere((i) => i.id == id);
            final statusStr = raw['dispatchStatus']?.toString() ?? 'unassigned';

            // Resolved incidents are completed and omitted from active dispatch queue
            if (statusStr == 'resolved') {
              if (existingIdx != -1) {
                state = state.where((i) => i.id != id).toList();
              }
              continue;
            }
            // Low-confidence review items require manual analyst confirmation and are forced to pendingReview
            final status = (detStatus == 'low_confidence_review')
                ? DispatchStatus.pendingReview
                : switch (statusStr) {
                    'assigned_police' => DispatchStatus.assignedToPolice,
                    'en_route' => DispatchStatus.enRoute,
                    'on_scene' => DispatchStatus.onScene,
                    'resolved' => DispatchStatus.resolved,
                    _ => DispatchStatus.pendingReview,
                  };

            if (existingIdx != -1) {
              state = [
                for (int i = 0; i < state.length; i++)
                  if (i == existingIdx)
                    state[i].copyWith(
                      status: status,
                      assignedUnit: raw['assignedTo']?.toString(),
                      policeNotes: raw['policeNotes']?.toString(),
                      detectionStatus: detStatus,
                      detectionSource: effectiveDetSource,
                    )
                  else
                    state[i]
              ];
            } else {
              final newIncident = DistressIncident(
                id: id,
                threatType: threatClass,
                confidence: (raw['confidence'] as num?)?.toDouble() ?? 0.95,
                cameraId: raw['cameraId']?.toString() ?? 'CAM-001',
                cameraName: raw['cameraId'] == 'CAM-002' ? 'Phone Camera 2' : 'Laptop Camera 1',
                location: raw['location']?.toString() ?? 'Sector Alpha',
                timestamp: raw['frameTimestamp'] != null
                    ? DateTime.tryParse(raw['frameTimestamp'].toString()) ?? DateTime.now()
                    : DateTime.now(),
                decibels: (raw['audioDecibels'] as num?)?.toDouble() ?? 88.0,
                audioTranscript: raw['audioTranscript']?.toString() ?? 'Anomaly detected',
                status: status,
                assignedUnit: raw['assignedTo']?.toString(),
                policeNotes: raw['policeNotes']?.toString(),
                spectralFrequencies: const [0.3, 0.5, 0.8, 0.9, 0.95, 0.85, 0.7, 0.5, 0.3, 0.2],
                detectionStatus: detStatus,
                detectionSource: effectiveDetSource,
              );
              state = [newIncident, ...state];
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[IncidentDispatch] syncFromBackend note: $e');
    }
  }

  /// Admin or Officer dismisses / clears an incident.
  Future<void> dismissIncident(String incidentId) async {
    state = state.where((inc) => inc.id != incidentId).toList();
    try {
      if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(incidentId)) {
        await _ref.read(crimeLogServiceProvider).updateDispatchStatus(
          incidentId,
          status: 'resolved',
          notes: 'Dismissed by operator.',
        );
      }
    } catch (e) {
      debugPrint('[IncidentDispatch] dismissIncident backend note: $e');
    }
    state = state.where((inc) => inc.id != incidentId).toList();
  }

  /// Clears all incidents in state (e.g. during logout or session reset)
  void clearAll() {
    state = [];
  }
}

// ─────────────────────────────────────────────────
// RIVERPOD PROVIDERS
// ─────────────────────────────────────────────────

final incidentDispatchProvider =
    StateNotifierProvider<IncidentDispatchNotifier, List<DistressIncident>>((ref) {
  return IncidentDispatchNotifier(ref);
});

/// Active pending incident for Control Room banner popup
/// Prioritizes Critical ML threats and Acoustic SOS distress triggers
final activeDistressBannerProvider = Provider<DistressIncident?>((ref) {
  final incidents = ref.watch(incidentDispatchProvider);
  if (incidents.isEmpty) return null;

  // 1. Highest priority: Acoustic SOS or verified Critical threats in pendingReview
  final criticalPending = incidents
      .where((inc) =>
          inc.status == DispatchStatus.pendingReview &&
          (inc.isAcousticSos || inc.isCriticalThreat))
      .toList();
  if (criticalPending.isNotEmpty) return criticalPending.first;

  // 2. High priority Control Room triage incidents in pendingReview
  final highPending = incidents
      .where((inc) => inc.status == DispatchStatus.pendingReview && inc.isHighThreat)
      .toList();
  if (highPending.isNotEmpty) return highPending.first;

  // 3. Fallback to any pending review (informational medium incidents)
  return incidents.firstWhere(
    (inc) => inc.status == DispatchStatus.pendingReview,
    orElse: () => incidents.first,
  );
});

/// Incidents assigned to Police
final policeAssignedIncidentsProvider = Provider<List<DistressIncident>>((ref) {
  final incidents = ref.watch(incidentDispatchProvider);
  return incidents
      .where((inc) =>
          inc.status == DispatchStatus.assignedToPolice ||
          inc.status == DispatchStatus.enRoute ||
          inc.status == DispatchStatus.onScene ||
          inc.status == DispatchStatus.resolved)
      .toList();
});
