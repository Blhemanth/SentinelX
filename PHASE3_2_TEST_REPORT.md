# SentinelX — Phase 3.2 ML Data Integrity Test Report

**Author:** Senior QA Automation Engineer & Backend Architect  
**Date:** November 22, 2026  
**Repository Working Directory:** `B:\SentinelX`  
**Execution Environment:** Windows x86_64, Node.js v20.x, Python 3.13 (PyTorch 2.15 CPU), Local MongoDB Community Edition (`127.0.0.1:27017`), Flutter 3.x.

---

## 1. Executive Summary

| Test Suite | Purpose | Tests | Passed | Failed | Duration | Pass Rate |
|---|---|---|---|---|---|---|
| **`test_phase3_2_integrity.js`** | Targeted 9-point ML data integrity & fallback suite | 10 | 10 | 0 | 1.8s | **100%** |
| **`test_ml_express_integration.js`**| End-to-end Express <-> Python ML bridge suite | 11 | 11 | 0 | 9.2s | **100%** |
| **`test_phase2_suite.js`** | JWT nonces, rotation, RBAC, cookies & sessions | 17 | 17 | 0 | 4.1s | **100%** |
| **`test_ml_pipeline.py`** | PyTorch checkpoint, OpenCV, Mel-spectrogram, FastAPI | 12 | 12 | 0 | 2.9s | **100%** |
| **`npm run build` (`frontend`)** | React Vite production build & syntax verification | - | - | 0 | 542ms | **100%** |
| **`flutter analyze`** | Static analysis & null-safety validation across `lib/` | - | - | 0 | 39.5s | **100%** |
| **`flutter test`** | Multi-platform Flutter unit & integration tests | 6 | 6 | 0 | 11.2s | **100%** |
| **TOTAL** | **Full System Regression Suite** | **56** | **56** | **0** | **~69s** | **100%** |

---

## 2. Phase 3.2 Targeted Integrity Test Suite (`test_phase3_2_integrity.js`)

Executed command: `node backend/test_phase3_2_integrity.js`

```
========================================================
 SENTINELX - PHASE 3.2 ML DATA INTEGRITY TEST SUITE     
========================================================

Connected to test MongoDB: mongodb://127.0.0.1:27017/sentinelx_audit

[Phase 3.2 Test] ✓ PASS - Auth: Analyst account registered and authenticated
[Phase 3.2 Test] ✓ PASS - Test 1: Normal detection persistence with detectionStatus "normal" 
  (Status: normal, Severity: normal)
[Phase 3.2 Test] ✓ PASS - Test 2: Confirmed anomaly persistence with detectionStatus "anomaly_detected" 
  (Status: anomaly_detected, Severity: critical)
[Phase 3.2 Test] ✓ PASS - Test 3: Low-confidence detection persistence with detectionStatus "low_confidence_review" 
  (Status: low_confidence_review, Severity: low)
[Phase 3.2 Test] ✓ PASS - Test 4: Subprocess fallback persistence with detectionStatus & detectionSource "subprocess_fallback" 
  (Status: subprocess_fallback, Source: subprocess_fallback, Severity: low)
[Phase 3.2 Test] ✓ PASS - Test 5: Subprocess failure tagged as "subprocess_fallback" and NEVER as "ml_real" 
  (Fallback DB Record Source: subprocess_fallback, Misclassified count: 0)
[Phase 3.2 Test] ✓ PASS - Test 6: Missing detectionStatus on legacy records defaults safely to "normal" 
  (Legacy record detectionStatus: normal)
[Phase 3.2 Test] ✓ PASS - Test 7: React logic parses detectionStatus and excludes fallback records from activeEmergencies 
  (Active Emergencies Count: 1 (Expected: 1, Explosion only))
[Phase 3.2 Test] ✓ PASS - Test 8: Flutter logic parses detectionStatus and ignores subprocess_fallback items 
  (Parsed Incidents: Gunshot:anomaly_detected, Fighting:low_confidence_review)
[Phase 3.2 Test] ✓ PASS - Test 9: Pre-save hook forces severity "low" for subprocess_fallback regardless of confidence 
  (Severity for 99% confidence fallback: low (Expected: 'low'))

========================================================
TOTAL INTEGRITY TESTS: 10 | PASSED: 10 | FAILED: 0
========================================================
```

---

## 3. Express <-> Python ML Bridge Regression Suite (`test_ml_express_integration.js`)

Executed command: `node backend/test_ml_express_integration.js`

```
====================================================
 SENTINELX - EXPRESS <-> PYTHON ML INTEGRATION SUITE
====================================================

Connected to test MongoDB: mongodb://127.0.0.1:27017/sentinelx_audit
Generating real sample media (MP4 & WAV) via OpenCV & Scipy...
Media generated: Video 6326 bytes, Audio 32044 bytes.

[ML Integration Test] ✓ PASS - Auth: Analyst account registered and authenticated
[ML Integration Test] ✓ PASS - API Response Status: /api/detect responds with HTTP 200 (Status: 200)
[ML Integration Test] ✓ PASS - Threat Classification: Valid class predicted from model taxonomy (Threat: Fighting)
[ML Integration Test] ✓ PASS - Confidence Score: Valid confidence value in [0.0, 1.0] (Confidence: 28.21%)
[ML Integration Test] ✓ PASS - Bounding Box: Valid normalized bounding box coords (Box: [0.4128, 0.4855, 0.5592, 0.5027])
[ML Integration Test] ✓ PASS - Metrics Tracking: Separate preprocessing and inference latencies recorded (Infer: 335.88ms, Total: 793.64ms)
[ML Integration Test] ✓ PASS - Detection Source: Genuine detection tagged as "ml_real" (Source: ml_real)
[ML Integration Test] ✓ PASS - MongoDB Persistence: CrimeLog saved with detectionSource "ml_real" (DB ID: 6b01ed841caf3ec121bf84bc, Source: ml_real)
[ML Integration Test] ✓ PASS - MongoDB Schema: Metrics subdocument stored in database (Total Latency in DB: 793.64ms)
[ML Integration Test] ✓ PASS - Drill Trigger: POST /api/logs/trigger responds with HTTP 201 (Status: 201)
[ML Integration Test] ✓ PASS - Drill Distinction: Manually triggered drill explicitly saved with detectionSource "drill_simulation" (Drill Source in DB: drill_simulation)

====================================================
TOTAL INTEGRATION TESTS: 11 | PASSED: 11 | FAILED: 0
====================================================
```

---

## 4. Phase 2 Security Regression Suite (`test_phase2_suite.js`)

Executed command: `node backend/test_phase2_suite.js`

```
====================================================
   SENTINELX - PHASE 2 SECURITY VERIFICATION SUITE  
====================================================

Connected to test MongoDB: mongodb://127.0.0.1:27017/sentinelx_audit

--- TASK 2: Strict JWT Secret Validation Tests ---
[Phase2 Test] ✓ PASS - JWT Config: Rejects short access secret in production
[Phase2 Test] ✓ PASS - JWT Config: Rejects default dev secret in production
[Phase2 Test] ✓ PASS - JWT Config: Rejects identical access and refresh secrets in production
[Phase2 Test] ✓ PASS - JWT Config: Accepts strong, distinct secrets in production

--- TASK 1: Sub-Second Refresh Token Collision Fix ---
[Phase2 Test] ✓ PASS - Refresh Token Generation: 100 tokens generated in same millisecond are 100% unique (Generated: 100, Unique: 100)
[Phase2 Test] ✓ PASS - Refresh Token Payload: Every token contains a distinct crypto.randomUUID jti nonce (Unique JTIs: 100)

--- TASK 3: Admin Provisioning of Police Role ---
[Phase2 Test] ✓ PASS - Admin Provisioning: Admin successfully registers account with role "police" (Status: 201, Role: police)
[Phase2 Test] ✓ PASS - Database Verification: User account stored in MongoDB with role "police" (DB Role: police)
[Phase2 Test] ✓ PASS - Privilege Escalation Prevention: Public registration requesting role "police" is sanitized to "user" (Assigned Role: user)

--- TASK 4: Cookie-Based Auth & Session Management ---
[Phase2 Test] ✓ PASS - Login Cookie: Server sends HttpOnly refreshToken cookie with Path=/api/auth
[Phase2 Test] ✓ PASS - Login Dual Support: Response body still contains refreshToken for Flutter/native clients
[Phase2 Test] ✓ PASS - Cookie Refresh: /api/auth/refresh succeeds using only HttpOnly cookie without request body
[Phase2 Test] ✓ PASS - Cookie Rotation: Refresh endpoint sets rotated HttpOnly cookie in response
[Phase2 Test] ✓ PASS - Token Rotation Invalidation: Old refresh token cannot be reused (session revoked)
[Phase2 Test] ✓ PASS - Live Sub-Second Session Rotation: 5 consecutive rapid refreshes succeed with zero duplicate key errors

--- TASK 4 (Cont): Permissive Logout & Cookie Clearing ---
[Phase2 Test] ✓ PASS - Permissive Logout: /api/auth/logout succeeds and clears cookie without requiring valid Bearer token
[Phase2 Test] ✓ PASS - Session Revocation: Database session marked isRevoked: true

====================================================
TOTAL PHASE 2 TESTS: 17 | PASSED: 17 | FAILED: 0
====================================================
```

---

## 5. Python ML Pipeline Verification Suite (`test_ml_pipeline.py`)

Executed command: `python server_ml/test_ml_pipeline.py`

```
====================================================
   SENTINELX - PHASE 3 ML PIPELINE TEST SUITE       
====================================================

test_01_strict_checkpoint_loading ... ok
test_02_video_preprocessing_shape_and_range ... ok
test_03_short_video_padding ... ok
test_04_audio_preprocessing_shape_and_db_scale ... ok
test_05_acoustic_silence_baseline ... ok
test_06_corrupt_inputs_raise_errors ... ok
test_07_multimodal_inference_forward_pass ... ok
test_08_video_only_inference ... ok
test_09_fastapi_health_and_info ... ok
test_10_fastapi_detect_base64_json ... ok
test_11_fastapi_detect_multipart_upload ... ok
test_12_fastapi_rejects_corrupted_video ... ok

Ran 12 tests in 2.929s
OK
[Bench] Real Multimodal Inference: Class=Fighting (28.25%) | VideoPrep=76.9ms | AudioPrep=5.7ms | ModelInfer=330.0ms | Total=414.7ms
```

---

## 6. Client Builds and Static Analysis

### 6.1 React Web Application
- **Command:** `cd frontend; npm run build`
- **Output:**
  ```
  vite v8.3.8 building client environment for production...
  transforming...
  ✓ 2140 modules transformed.
  rendering chunks...
  dist/index.html                   0.45 kB │ gzip:  0.29 kB
  dist/assets/index-BFC-n_xh.css    4.28 kB │ gzip:  1.46 kB
  dist/assets/index-yAWY53QT.js   323.19 kB │ gzip: 92.39 kB
  ✓ built in 542ms
  ```
- **Result:** **PASSED (0 errors, 0 warnings).**

### 6.2 Flutter Mobile/Desktop Client
- **Command:** `flutter analyze`
- **Output:** `No issues found! (ran in 39.5s)`
- **Result:** **PASSED (0 errors, 0 warnings).**
- **Command:** `flutter test`
- **Output:**
  ```
  00:00 +0: loading B:/SentinelX/test/integration_test/app_test.dart
  00:00 +0: App initializes cleanly wrapped in ProviderScope with dark theme
  00:01 +1: Native Inference Mode: sentinelx_model.onnx initializes with DirectML / NNAPI
  00:01 +2: ImageToTensorPreprocessor creates correct [1, 3, 640, 640] NCHW tensor
  00:01 +3: InferenceRepository initializes with native ONNX model state
  00:01 +4: Desktop Command Center renders on screens >= 900px
  00:02 +5: AuthGate presents LoginScreen with RBAC selector pills
  00:02 +6: All tests passed!
  ```
- **Result:** **PASSED (6/6 tests passed).**

---

## 7. Final Verification Verdict

### **PHASE 3 FULLY APPROVED (100% VERIFIED)**
Both defects identified in Phase 3.1 have been resolved and validated:
1. `detectionStatus` (`normal`, `anomaly_detected`, `low_confidence_review`, `subprocess_fallback`) is fully persisted in MongoDB `CrimeLog`, exposed via Express REST APIs, and rendered across React and Flutter.
2. Subprocess fallback failures are cleanly classified as `detectionSource: 'subprocess_fallback'` and `detectionStatus: 'subprocess_fallback'`, never contaminating genuine `ml_real` detection records and prevented from triggering emergency dispatch alarms.

All 56 automated tests across backend, security, ML, React, and Flutter pass with zero failures.
