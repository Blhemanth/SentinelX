# SentinelX — Phase 3.2 ML Data Integrity Patch Implementation Report

**Author:** Senior Node.js Backend Engineer & ML Integration Engineer  
**Date:** November 22, 2026  
**Repository Working Directory:** `B:\SentinelX`  
**Evaluation Scope:** Resolution of the two data integrity defects identified during Phase 3.1 independent code verification.

---

## 1. Executive Summary

Phase 3.2 addresses two critical database and client integration defects identified in the Phase 3.1 independent code verification:
1. **Defect 1 (`detectionStatus` omission):** `detectionStatus` (`'normal'`, `'anomaly_detected'`, `'low_confidence_review'`, `'subprocess_fallback'`) was emitted by Python ML and returned in Express HTTP responses, but dropped upon MongoDB persistence because it was omitted from the `CrimeLog` Mongoose schema and `CrimeLog.create({...})` invocation.
2. **Defect 2 (Subprocess fallback misclassification):** When genuine Python inference failed, the subprocess fallback mock object (`Normal`, `confidence: 0.50`, `model_loaded: false`) was saved to MongoDB hardcoded as `detectionSource: 'ml_real'`.

Both defects have been completely resolved without altering the trained neural model, model architecture, preprocessing pipelines, JWT authentication, or database schemas beyond the required field addition.

---

## 2. Technical Modifications

### 2.1 Mongoose Schema Updates (`backend/src/models/CrimeLog.js`)

1. **Added `detectionStatus` Field:**
   ```javascript
   // Threat detection state
   detectionStatus: {
     type: String,
     enum: ['normal', 'anomaly_detected', 'low_confidence_review', 'subprocess_fallback'],
     default: 'normal',
     index: true,
   },
   ```
   - **Safe Legacy Default:** Defaults to `'normal'` so existing documents without this field remain readable and valid.
   - **Indexed:** Added compound index `crimeLogSchema.index({ detectionStatus: 1, frameTimestamp: -1 })` for efficient status-based filtering in analytical dashboards.

2. **Expanded `detectionSource` Enum:**
   ```javascript
   // Distinguish genuine ML detections from simulated drills & fallbacks
   detectionSource: {
     type: String,
     enum: ['ml_real', 'drill_simulation', 'acoustic_sos', 'manual_entry', 'subprocess_fallback'],
     default: 'ml_real',
     index: true,
   },
   ```
   - Added `'subprocess_fallback'` to distinguish genuine neural inference from engine failure fallbacks.

3. **Updated Pre-Save Severity Calculation Hook:**
   ```javascript
   // Pre-save: derive severity from threatClass + confidence + detectionStatus
   crimeLogSchema.pre('save', function (next) {
     if (this.detectionStatus === 'subprocess_fallback' || this.detectionSource === 'subprocess_fallback') {
       this.severity = 'low';
     } else if (this.detectionStatus === 'low_confidence_review') {
       this.severity = 'low';
     } else if (this.threatClass === 'Normal') {
       this.severity = 'normal';
     } else if (this.confidence >= 0.85) {
       this.severity = 'critical';
     } else if (this.confidence >= 0.70) {
       this.severity = 'high';
     } else if (this.confidence >= 0.50) {
       this.severity = 'medium';
     } else {
       this.severity = 'low';
     }
     next();
   });
   ```
   - **Safety Guarantee:** Subprocess fallbacks and low-confidence review predictions are guaranteed to receive `severity: 'low'`, preventing them from triggering critical police dispatch or audible red alerts.

---

### 2.2 Express Controller Updates (`backend/src/controllers/detect.controller.js`)

1. **Subprocess Fallback Discrimination:**
   ```javascript
   const isFallback = Boolean(
     mlResult.is_fallback ||
     mlResult.detection_status === 'subprocess_fallback' ||
     mlResult.detection_source === 'subprocess_fallback' ||
     mlResult.model_loaded === false
   );

   const detectionSource = isFallback
     ? 'subprocess_fallback'
     : (mlResult.detection_source || 'ml_real');

   const detectionStatus = isFallback
     ? 'subprocess_fallback'
     : (mlResult.detection_status || 'normal');
   ```

2. **Persistence Propagation:**
   Passed `detectionStatus: result.detectionStatus` and `detectionSource: result.detectionSource` to `CrimeLog.create({...})`.
   All model outputs (5 class probabilities, raw logits, bounding boxes, latency metrics) are strictly preserved.

---

### 2.3 ML Bridge Service Updates (`backend/src/services/mlBridge.service.js`)

Updated `runPythonSubprocess` fallback resolver:
```javascript
resolve({
  threat_class: 'Normal',
  confidence: 0.50,
  raw_logits: [0.0, 0.0, 0.0, 0.0, 0.0],
  bbox: [0.0, 0.0, 0.0, 0.0],
  class_probabilities: { Explosion: 0.1, Gunshot: 0.1, Fighting: 0.1, Accident: 0.1, Normal: 0.6 },
  detection_status: 'subprocess_fallback',
  detection_source: 'subprocess_fallback',
  is_fallback: true,
  device: 'fallback-safe',
  model_loaded: false,
  metrics: { video_preprocess_ms: 0, audio_preprocess_ms: 0, model_inference_ms: 0, total_latency_ms: 5 },
  model_version: '1.0.0',
});
```

---

### 2.4 Demonstrator Drill Updates (`backend/src/controllers/logs.controller.js`)

Updated `mockTrigger`:
- Explicitly sets `detectionStatus: 'anomaly_detected'` along with `detectionSource: 'drill_simulation'`.

---

### 2.5 React Web Client Updates (`frontend/src/`)

1. **Emergency Filter Hardening (`frontend/src/views/DashboardView.jsx`):**
   ```javascript
   const activeEmergencies = recentLogs.filter(
     (log) =>
       (log.severity === 'critical' || log.threatClass?.includes('HELP')) &&
       log.detectionStatus !== 'subprocess_fallback' &&
       log.detectionSource !== 'subprocess_fallback' &&
       log.dispatchStatus !== 'resolved'
   );
   ```
   Ensures engine fallbacks never enter the critical emergency banner.

2. **Incident Table Rendering (`DashboardView.jsx`):**
   - Added visual badge `REVIEW` (amber) when `log.detectionStatus === 'low_confidence_review'`.
   - Added visual badge `FALLBACK` (yellow) when `log.detectionStatus === 'subprocess_fallback'` or `log.detectionSource === 'subprocess_fallback'`.

3. **Telemetry & Header Modal Updates (`frontend/src/components/IncidentModal.jsx`):**
   - Displays `Detection Status` with dynamic status coloring (`#34D399` for normal, `text-amber-400` for review, `text-yellow-400` for fallback, `text-red-400` for confirmed anomaly).
   - Displays `Detection Source` (`ML REAL`, `DRILL SIMULATION`, `SUBPROCESS FALLBACK`).
   - Adds `REVIEW NEEDED` or `SUBPROCESS FALLBACK` pill badges to the header.

---

### 2.6 Flutter Mobile/Desktop Client Updates (`lib/`)

1. **Data Model Updates (`lib/core/services/incident_dispatch_repository.dart`):**
   - Added `detectionStatus` (default `'normal'`) and `detectionSource` (default `'ml_real'`) to `DistressIncident`.
   - Updated `copyWith` to support both fields.

2. **Backend Synchronization Hardening (`syncFromBackend`):**
   ```dart
   final id = raw['_id']?.toString() ?? '';
   final threatClass = raw['threatClass']?.toString() ?? 'Normal';
   final detStatus = raw['detectionStatus']?.toString() ?? 'normal';
   final detSource = raw['detectionSource']?.toString() ?? 'ml_real';

   // Filter out Normal predictions and subprocess fallbacks from auto-dispatching
   if (threatClass == 'Normal' ||
       id.isEmpty ||
       detStatus == 'subprocess_fallback' ||
       detSource == 'subprocess_fallback') {
     continue;
   }
   ```
   Guarantees fallback records are ignored by the mobile/desktop tactical dispatch queue.

---

## 3. Verification & Compliance Checklist

- [x] **No model retraining** performed.
- [x] **No model architecture changes** introduced.
- [x] **No preprocessing changes** made to video or audio.
- [x] **JWT auth and RBAC preserved** without regression.
- [x] **MongoDB shared database preserved** for both React and Flutter.
- [x] **Existing records remain backward-compatible** via schema defaults (`'normal'`).
- [x] **Low-confidence detections marked for review** across backend, React, and Flutter.
- [x] **Subprocess fallbacks tagged accurately** as `subprocess_fallback` and prevented from triggering emergency dispatch.
