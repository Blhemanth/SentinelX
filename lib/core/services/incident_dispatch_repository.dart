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
  });

  bool get isAssignedToPolice =>
      status == DispatchStatus.assignedToPolice ||
      status == DispatchStatus.enRoute ||
      status == DispatchStatus.onScene;

  bool get isResolved => status == DispatchStatus.resolved;

  DistressIncident copyWith({
    DispatchStatus? status,
    String? assignedUnit,
    String? policeNotes,
    bool? isRecordingActive,
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
  }

  void _initDefaultSampleIncident() {
    // Seed with one initial demo incident so Police page has immediate content
    final initial = DistressIncident(
      id: 'INC-DEMO-001',
      threatType: 'Acoustic Distress: HELP, HELP',
      confidence: 0.984,
      cameraId: 'CAM-001',
      cameraName: 'Laptop Camera 1 (Local Hardware Webcam)',
      location: 'Primary Perimeter // Gate A',
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      decibels: 88.6,
      audioTranscript: 'Voice Distress Detected: "HELP! HELP! EMERGENCY!"',
      status: DispatchStatus.assignedToPolice,
      assignedUnit: 'Metro Police Patrol Unit #104 (Officer Vance)',
      policeNotes: 'Unit dispatched to Primary Perimeter. ETA 2 minutes.',
      spectralFrequencies: [
        0.2, 0.35, 0.5, 0.85, 0.92, 0.88, 0.74, 0.89, 0.95, 0.82,
        0.70, 0.65, 0.55, 0.45, 0.35, 0.30, 0.25, 0.20, 0.15, 0.10,
      ],
      clipDurationSeconds: 6,
    );
    state = [initial];
  }

  /// Triggered when "HELP, HELP" is spoken into the microphone or manually triggered.
  Future<DistressIncident> triggerDistress({
    required String cameraId,
    String? cameraName,
    String? location,
    String? customTranscript,
  }) async {
    final now = DateTime.now();
    final id = 'INC-${now.millisecondsSinceEpoch.toString().substring(7)}';

    final incident = DistressIncident(
      id: id,
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
      decibels: 89.4,
      audioTranscript: customTranscript ??
          'Critical Acoustic Distress Detected: "HELP! HELP! EMERGENCY AT SECTOR"',
      status: DispatchStatus.pendingReview,
      spectralFrequencies: [
        0.18, 0.32, 0.60, 0.89, 0.98, 0.94, 0.86, 0.92, 0.97, 0.85,
        0.78, 0.68, 0.58, 0.48, 0.38, 0.28, 0.22, 0.18, 0.14, 0.11,
      ],
      clipDurationSeconds: 6,
      isRecordingActive: true,
    );

    // Add to top of list
    state = [incident, ...state];

    // Simulate 2.5 seconds of high-fidelity video recording capture
    Future.delayed(const Duration(milliseconds: 2500), () {
      state = [
        for (final inc in state)
          if (inc.id == incident.id)
            inc.copyWith(isRecordingActive: false)
          else
            inc
      ];
    });

    // Optionally post to backend CrimeLogService
    try {
      final crimeLogService = _ref.read(crimeLogServiceProvider);
      await crimeLogService.runDetection(
        cameraId: cameraId,
        location: incident.location,
        frameTimestamp: now.toIso8601String(),
      );
    } catch (e) {
      debugPrint('[IncidentDispatch] Backend sync note: $e');
    }

    return incident;
  }

  /// Control Room (Admin) assigns incident to Police Dispatch.
  void assignToPolice(String incidentId, {String? unit}) {
    state = [
      for (final inc in state)
        if (inc.id == incidentId)
          inc.copyWith(
            status: DispatchStatus.assignedToPolice,
            assignedUnit: unit ?? 'Metro Police Patrol Unit #104 (Immediate Tactical Response)',
            policeNotes: 'Incident escalated by Control Room Admin. Dispatch alert transmitted.',
          )
        else
          inc
    ];
  }

  /// Police updates dispatch status (e.g. En Route, On Scene, Resolved).
  void updatePoliceStatus(String incidentId, DispatchStatus newStatus, {String? notes}) {
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
  }

  /// Admin or Officer dismisses / clears an incident.
  void dismissIncident(String incidentId) {
    state = state.where((inc) => inc.id != incidentId).toList();
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
final activeDistressBannerProvider = Provider<DistressIncident?>((ref) {
  final incidents = ref.watch(incidentDispatchProvider);
  return incidents.isEmpty ? null : incidents.firstWhere(
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
