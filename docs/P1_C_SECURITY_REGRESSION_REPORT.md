# SentinelX — Phase P1-C: Security & Regression Report

**Milestone:** P1-C (ML Model Integration, Inference Verification & Classification Validation)  
**Date:** November 23, 2026  
**Auditor:** Principal Application Security Auditor & System Architect  
**Status:** COMPLETE & AUTHORITATIVE  

---

## 1. Executive Summary

This report assesses the security posture and verifies that the ML integration implemented in Phase P1-C preserves all architectural trust boundaries established in Phase P0.

Specific focus was placed on:
1. **Multi-Tenant Data Isolation & IDOR Prevention:** Ensuring unprivileged civilian users cannot view or manipulate incidents belonging to other accounts.
2. **Acoustic Event vs Threat Classification Separation:** Ensuring physical acoustic spikes ($> -18.0\text{ dBFS}$) from clapping, coughing, or ambient noise do NOT trigger police dispatch or high-threat classifications.
3. **No Client-Side Authority on Dispatches:** Guaranteeing that emergency police dispatch is governed by backend authorization, requiring authenticated staff roles.

All 19 backend isolation tests and 18 frontend unit tests passed with 100% compliance.

---

## 2. Multi-Tenant Data Isolation Audit

Following the P0 security overhaul, the backend enforces strict authorization policies in [`backend/src/controllers/crimeLogController.js`](file:///b:/SentinelX/backend/src/controllers/crimeLogController.js):

```javascript
// Incident Creation: Never trust client-supplied createdBy or userId
const incidentData = {
  ...req.body,
  createdBy: req.user.userId, // Strictly derived from verified JWT
};
```

### Automated Isolation Verification Matrix (`backend/test_user_isolation.js`):

| Test ID | Security Scenario | Attack Vector Tested | Result |
|:---:|:---|:---|:---:|
| **#1** | UserId Spoofing Prevention | User A passes User B's `createdBy` in POST `/api/logs` payload | **PASSED** (Ignored; bound to User A) |
| **#4** | Listing Data Isolation (User A) | User A calls GET `/api/logs` | **PASSED** (User B logs strictly excluded) |
| **#5** | Listing Data Isolation (User B) | User B calls GET `/api/logs` | **PASSED** (User A logs strictly excluded) |
| **#6** | IDOR Direct Inspection | User B queries `/api/logs/:id` belonging to User A | **PASSED** (HTTP 403 Forbidden) |
| **#7** | Legitimate Owner Access | User A queries `/api/logs/:id` belonging to User A | **PASSED** (HTTP 200 OK) |
| **#8** | Unauthenticated Access | Request missing JWT token | **PASSED** (HTTP 401 Unauthorized) |
| **#9** | Civilian Dispatch Tampering | Civilian user attempts PATCH `/api/logs/:id/dispatch` | **PASSED** (HTTP 403 Forbidden) |
| **#10**| Civilian Incident Acknowledge | Civilian user attempts PATCH `/api/logs/:id/acknowledge` | **PASSED** (HTTP 403 Forbidden) |
| **#11**| Civilian Incident Deletion | Civilian user attempts DELETE `/api/logs/:id` | **PASSED** (HTTP 403 Forbidden) |
| **#12**| Analyst Oversight Visibility | Analyst queries `/api/logs` | **PASSED** (Global surveillance visibility) |
| **#15**| Legacy Unowned Records Safety | Civilian queries record created prior to P0 (`createdBy: null`)| **PASSED** (HTTP 403 Forbidden) |
| **#17**| Aggregated Stats Isolation | Civilian queries `/api/logs/stats` | **PASSED** (Scoped strictly to user count) |
| **#19**| Admin Authorized Deletion | Administrator deletes incident record | **PASSED** (HTTP 200 OK) |

**Summary:** 19/19 tests passed (100.0%). Zero IDOR or cross-tenant leaks.

---

## 3. Acoustic Event vs Threat Classification Separation

In [`lib/core/providers/providers.dart`](file:///b:/SentinelX/lib/core/providers/providers.dart):

```dart
// Real physical acoustic spikes (> -18.0 dBFS)
final subFrame = captureService.stream.listen((frame) {
  if (frame.isAudioSpike) {
    ...
    controller.add(AudioEvent(
      id: 'SPIKE-${now.millisecondsSinceEpoch}',
      cameraId: 'CAM-001 (MIC)',
      classification: 'acoustic_spike',
      confidence: conf,
      threat: ThreatLevel.none, // Corrected from ThreatLevel.high
      timestamp: now,
      frequencyBands: frame.frequencies,
      decibelLevel: frame.decibels,
    ));
  }
});
```

### Security Justification:
- An acoustic spike ($> -18.0\text{ dBFS}$) is an **acoustic energy measurement**, not a confirmed crime classification.
- In previous versions, loud sounds erroneously triggered `ThreatLevel.high`, which could initiate emergency alarms.
- By binding acoustic spikes to `ThreatLevel.none`, raw microphone energy events provide visual monitoring telemetry in the Audio Monitor without triggering spurious police dispatches.

---

## 4. Input Sanitization & DoS Defense

The `OnnxInferenceWorker` implements strict input validation guards:
1. **Buffer Size Enforcement:** Rejects inputs not matching $2,408,448$ floats (video) or $16,384$ floats (audio) before dispatching to native C++ libraries.
2. **Numerical Sanitization:** Validates that input buffers contain no `NaN` or `Infinity` floats, preventing internal ONNX Runtime arithmetic exceptions or undefined behavior.
3. **Isolate Isolation:** If an internal C++ fault were to occur inside `onnxruntime.dll`, it is contained within the worker isolate. The main Flutter UI isolate remains stable, and the worker isolate restarts automatically.
