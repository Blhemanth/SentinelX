// SentinelX - Core Data Models
// Defines all domain entities: Camera, Detection, Alert, Threat, AudioEvent.

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────

enum ThreatLevel {
  none,
  low,
  medium,
  high,
  critical;

  String get label => switch (this) {
    ThreatLevel.none => 'CLEAR',
    ThreatLevel.low => 'LOW',
    ThreatLevel.medium => 'MEDIUM',
    ThreatLevel.high => 'HIGH',
    ThreatLevel.critical => 'CRITICAL',
  };

  Color get color => switch (this) {
    ThreatLevel.none => const Color(0xFF69F0AE),
    ThreatLevel.low => const Color(0xFF00E676),
    ThreatLevel.medium => const Color(0xFFFFBB33),
    ThreatLevel.high => const Color(0xFFFF6B35),
    ThreatLevel.critical => const Color(0xFFFF3B5C),
  };

  double get numericValue => switch (this) {
    ThreatLevel.none => 0.0,
    ThreatLevel.low => 0.25,
    ThreatLevel.medium => 0.5,
    ThreatLevel.high => 0.75,
    ThreatLevel.critical => 1.0,
  };
}

enum CameraStatus { online, offline, maintenance, recording }

enum DetectionType {
  person,
  vehicle,
  weapon,
  fight,
  crowdAnomaly,
  loitering,
  trespassing,
  fireSmoke,
  abandonedObject,
  vandalism,
  audioAnomaly;

  String get label => switch (this) {
    DetectionType.person => 'Person',
    DetectionType.vehicle => 'Vehicle',
    DetectionType.weapon => 'Weapon',
    DetectionType.fight => 'Fight',
    DetectionType.crowdAnomaly => 'Crowd Anomaly',
    DetectionType.loitering => 'Loitering',
    DetectionType.trespassing => 'Trespassing',
    DetectionType.fireSmoke => 'Fire/Smoke',
    DetectionType.abandonedObject => 'Abandoned Object',
    DetectionType.vandalism => 'Vandalism',
    DetectionType.audioAnomaly => 'Audio Anomaly',
  };

  IconData get icon => switch (this) {
    DetectionType.person => Icons.person_outline,
    DetectionType.vehicle => Icons.directions_car_outlined,
    DetectionType.weapon => Icons.gpp_bad_outlined,
    DetectionType.fight => Icons.sports_mma_outlined,
    DetectionType.crowdAnomaly => Icons.groups_outlined,
    DetectionType.loitering => Icons.timer_outlined,
    DetectionType.trespassing => Icons.block_outlined,
    DetectionType.fireSmoke => Icons.local_fire_department_outlined,
    DetectionType.abandonedObject => Icons.inventory_2_outlined,
    DetectionType.vandalism => Icons.broken_image_outlined,
    DetectionType.audioAnomaly => Icons.graphic_eq_outlined,
  };

  ThreatLevel get defaultThreat => switch (this) {
    DetectionType.person => ThreatLevel.none,
    DetectionType.vehicle => ThreatLevel.none,
    DetectionType.weapon => ThreatLevel.critical,
    DetectionType.fight => ThreatLevel.high,
    DetectionType.crowdAnomaly => ThreatLevel.medium,
    DetectionType.loitering => ThreatLevel.low,
    DetectionType.trespassing => ThreatLevel.medium,
    DetectionType.fireSmoke => ThreatLevel.critical,
    DetectionType.abandonedObject => ThreatLevel.high,
    DetectionType.vandalism => ThreatLevel.medium,
    DetectionType.audioAnomaly => ThreatLevel.medium,
  };
}

enum AlertPriority { info, warning, urgent, critical }

// ─────────────────────────────────────────────────
// DOMAIN MODELS
// ─────────────────────────────────────────────────

class CameraFeed {
  final String id;
  final String name;
  final String location;
  final CameraStatus status;
  final double latitude;
  final double longitude;
  final String? streamUrl;
  final int fps;
  final String resolution;

  const CameraFeed({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.streamUrl,
    this.fps = 30,
    this.resolution = '1920x1080',
  });

  CameraFeed copyWith({
    String? id,
    String? name,
    String? location,
    CameraStatus? status,
    double? latitude,
    double? longitude,
    String? streamUrl,
    int? fps,
    String? resolution,
  }) {
    return CameraFeed(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      streamUrl: streamUrl ?? this.streamUrl,
      fps: fps ?? this.fps,
      resolution: resolution ?? this.resolution,
    );
  }
}

class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Rect toRect(Size canvasSize) {
    final clampedX = x.clamp(0.0, 1.0);
    final clampedY = y.clamp(0.0, 1.0);
    final renderW = math.max(0.0, math.min(width, 1.0 - clampedX));
    final renderH = math.max(0.0, math.min(height, 1.0 - clampedY));
    return Rect.fromLTWH(
      clampedX * canvasSize.width,
      clampedY * canvasSize.height,
      renderW * canvasSize.width,
      renderH * canvasSize.height,
    );
  }
}

class Detection {
  final String id;
  final String cameraId;
  final DetectionType type;
  final BoundingBox bbox;
  final double confidence;
  final ThreatLevel threat;
  final DateTime timestamp;
  final String? label;

  const Detection({
    required this.id,
    required this.cameraId,
    required this.type,
    required this.bbox,
    required this.confidence,
    required this.threat,
    required this.timestamp,
    this.label,
  });
}

class SecurityAlert {
  final String id;
  final String cameraId;
  final String cameraName;
  final DetectionType detectionType;
  final ThreatLevel threatLevel;
  final AlertPriority priority;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool acknowledged;
  final String? assignedTo;

  const SecurityAlert({
    required this.id,
    required this.cameraId,
    required this.cameraName,
    required this.detectionType,
    required this.threatLevel,
    required this.priority,
    required this.title,
    required this.description,
    required this.timestamp,
    this.acknowledged = false,
    this.assignedTo,
  });

  SecurityAlert copyWith({
    bool? acknowledged,
    String? assignedTo,
  }) {
    return SecurityAlert(
      id: id,
      cameraId: cameraId,
      cameraName: cameraName,
      detectionType: detectionType,
      threatLevel: threatLevel,
      priority: priority,
      title: title,
      description: description,
      timestamp: timestamp,
      acknowledged: acknowledged ?? this.acknowledged,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }
}

class AudioEvent {
  final String id;
  final String cameraId;
  final String classification; // gunshot, scream, glass_break, etc.
  final double confidence;
  final ThreatLevel threat;
  final DateTime timestamp;
  final List<double> frequencyBands; // For waveform visualization
  final double decibelLevel;

  const AudioEvent({
    required this.id,
    required this.cameraId,
    required this.classification,
    required this.confidence,
    required this.threat,
    required this.timestamp,
    required this.frequencyBands,
    required this.decibelLevel,
  });
}

class SystemMetrics {
  final double cpuUsage;
  final double gpuUsage;
  final double memoryUsage;
  final double networkBandwidth;
  final int activeCameras;
  final int totalDetections;
  final int activeAlerts;
  final double inferenceLatencyMs;
  final int framesProcessedPerSec;

  const SystemMetrics({
    required this.cpuUsage,
    required this.gpuUsage,
    required this.memoryUsage,
    required this.networkBandwidth,
    required this.activeCameras,
    required this.totalDetections,
    required this.activeAlerts,
    required this.inferenceLatencyMs,
    required this.framesProcessedPerSec,
  });
}

class ThreatTimelineEntry {
  final DateTime time;
  final double threatScore;
  final int detectionCount;

  const ThreatTimelineEntry({
    required this.time,
    required this.threatScore,
    required this.detectionCount,
  });
}
