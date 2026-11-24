# SentinelX — Prioritized Development Roadmap (Next Phases)

**Date:** November 22, 2026  
**Document Status:** Phase 2 & Phase 3 Completed — Awaiting Approval for Phase 4  
**Context:** Resulting from the Comprehensive System, Security, ML, and E2E Audits  

---

## 1. Overall Application Maturity Assessment

The SentinelX platform is currently at **Late Beta Production Candidate** status:
- **What is Production-Ready:** The Node.js Express REST API, MongoDB Mongoose schemas, Bcrypt password hashing, RBAC authorization matrix, and React Web management views are production-grade and fully integrated.
- **What is Fully Functional & Verified (Phase 2 & Phase 3 Complete):** 
  - Sub-second JWT refresh collisions solved via `crypto.randomUUID()` `jti` nonces with token rotation.
  - Complete RBAC coverage including `'police'` registration and startup JWT secret validation.
  - Genuine Python ML video decoding (OpenCV 16-frame uniform sampling, 224x224 ImageNet normalization).
  - Genuine Mel-spectrogram acoustic decoding (`torchaudio` 128 Mel-bands in dB, 16kHz) matching `prepare_dataset.py`.
  - PyTorch checkpoint `server_ml/models/sentinelx_model.pth` execution with `strict=True` with no synthetic random fallbacks.
  - Express-to-Python IPC bridge (FastAPI HTTP + stdin streaming fallback to avoid Windows command length limits) and MongoDB `ml_real` persistence.
- **What Remains Simulated & Targeted Next:**
  - On-device ONNX forward passes in Flutter currently use simulated latency in `OnnxInferenceEngine.dart` instead of C-FFI runtime bindings (Phase 4).
  - React surveillance feeds use simulated canvas loops rather than WebRTC/HLS streams (Phase 5).

---

## 2. Prioritized Roadmap Overview

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              DEVELOPMENT ROADMAP PHASES                                │
├─────────┬────────────────────────────────────────────┬──────────────┬──────────────────┤
│ Phase   │ Description                                │ Priority     │ Target Subsystems│
├─────────┼────────────────────────────────────────────┼──────────────┼──────────────────┤
│ Phase 2 │ Security Hardening & Critical Bug Fixes   │ COMPLETED    │ backend/         │
│ Phase 3 │ Real Python Video/Audio Ingestion Pipeline │ COMPLETED    │ server_ml/       │
│ Phase 4 │ Native ONNX Runtime C-FFI in Flutter       │ P1 (NEXT)    │ lib/, windows/   │
│ Phase 5 │ Real Video Streaming for Web Console       │ P2           │ frontend/, bkd/  │
│ Phase 6 │ Containerization & Production CI/CD        │ P3           │ Root, Dockerfile │
└─────────┴────────────────────────────────────────────┴──────────────┴──────────────────┘
```

---

## 3. Phase-by-Phase Task Breakdown

### Phase 2: Security Hardening & Critical Bug Fixes (COMPLETED)

#### Objectives:
Eliminate the verified high-severity JWT refresh collision bug, fix role assignment omissions, and prevent insecure development fallback secrets.

- [x] **Task 2.1: Fix Refresh Token Collision via Nonce (`jti`)**
  - **File:** `backend/src/config/jwt.js`
  - **Status:** **Completed & Verified.** Refresh tokens generate `jti: crypto.randomUUID()` guaranteeing sub-second uniqueness under high concurrency.
- [x] **Task 2.2: Add `'police'` to Admin Register Role Sanitizer**
  - **File:** `backend/src/controllers/auth.controller.js`
  - **Status:** **Completed & Verified.** Admins can provision `police` accounts alongside `analyst`, `admin`, and `user`.
- [x] **Task 2.3: Enforce Strict JWT Secret Validation**
  - **File:** `backend/src/config/jwt.js`
  - **Status:** **Completed & Verified.** Server halts with descriptive error if fallback or empty secret is detected in production.
- [x] **Task 2.4: Return Access Token upon Registration**
  - **File:** `backend/src/controllers/auth.controller.js`
  - **Status:** **Completed & Verified.** Access and refresh tokens returned directly upon registration.

---

### Phase 3: Real Python Video/Audio Ingestion Pipeline (COMPLETED)

#### Objectives:
Transition `server_ml/infer.py` and `server_ml/inference_api.py` from synthetic random tensors (`torch.randn`) to genuine video frame and audio spectrogram decoders.

- [x] **Task 3.1: OpenCV Video Clip Slicer**
  - **Files:** `server_ml/preprocessor.py`, `server_ml/infer.py`, `server_ml/inference_api.py`
  - **Status:** **Completed & Verified.** `preprocess_video()` decodes arbitrary MP4/AVI/WebM inputs, extracts 16 uniform frames, resizes to 224x224, applies ImageNet normalization, producing `[1, 16, 3, 224, 224]`.
- [x] **Task 3.2: Acoustic Mel-Spectrogram Decoder**
  - **Files:** `server_ml/preprocessor.py`, `server_ml/infer.py`, `server_ml/inference_api.py`
  - **Status:** **Completed & Verified.** `preprocess_audio()` loads PCM WAV via `scipy.io.wavfile`, downmixes to mono 16kHz, computes 128-band Mel-spectrogram in dB with fixed 128 temporal steps, producing `[1, 1, 128, 128]`. `get_acoustic_silence()` generates -80.0 dB baseline for video-only feeds.
- [x] **Task 3.3: Remove Hardcoded Threshold Override**
  - **Files:** `server_ml/infer.py`
  - **Status:** **Completed & Verified.** Removed static `confidence = 0.94` fallback; network logits are processed via Softmax to yield genuine threat classifications, bounding boxes, and probabilities.
- [x] **Task 3.4: Express-Python Bridge & MongoDB Ingestion**
  - **Files:** `backend/src/services/mlBridge.service.js`, `backend/src/controllers/detect.controller.js`, `backend/src/models/CrimeLog.js`
  - **Status:** **Completed & Verified.** Dual-dispatch HTTP/stdin streaming IPC bridge saves genuine threat events with `detectionSource: 'ml_real'`, raw logits, and inference latency telemetry.

---

### Phase 4: Native ONNX Runtime C-FFI Integration in Flutter (P1 — Next)

#### Objectives:
Link Flutter's `OnnxInferenceEngine` to the native ONNX Runtime C-API on Windows (DirectML) and Android (NNAPI), replacing simulated `Future.delayed()` calls with real on-device neural execution.

- [ ] **Task 4.1: Integrate `onnxruntime` Flutter Package**
  - **Files:** `pubspec.yaml`, `lib/services/onnx_inference_engine.dart`
  - **Action:** Add `onnxruntime` plugin dependency to link prebuilt `onnxruntime.dll` on Windows and `libonnxruntime.so` on Android.
- [ ] **Task 4.2: Wire Preprocessed Tensors to Native Session**
  - **Files:** `lib/services/onnx_inference_engine.dart`
  - **Action:** Pass `ImageToTensorPreprocessor.preprocessRgb` output buffer into `OrtSession.run()` and parse output tensor shapes `[1, 5]` and `[1, 4]`.
- [ ] **Task 4.3: Real-Time DirectML Hardware Benchmarking**
  - **Files:** `lib/features/settings/screens/model_settings_screen.dart`
  - **Action:** Measure and display real DirectML GPU latency on Windows desktop.

---

### Phase 5: Real Video Surveillance Streaming for React Web (P2)

#### Objectives:
Replace simulated 2D canvas surveillance graphics with live video streams from `CAM-001` and `CAM-002`.

- [ ] **Task 5.1: WebRTC / RTSP Ingestion Gateway**
  - **Files:** `backend/src/services/`
  - **Action:** Add a lightweight WebRTC or HLS proxy stream forwarding local webcam frames and phone IP streams to the browser.
- [ ] **Task 5.2: React Video Player Integration**
  - **Files:** `frontend/src/views/CameraFeedsView.jsx`, `IncidentModal.jsx`
  - **Action:** Embed HTML5 `<video>` elements with canvas bounding box overlays driven by live MongoDB detection coordinates.

---

### Phase 6: Containerization & Production CI/CD (P3)

#### Objectives:
Provide push-button containerized deployment across multi-node environments.

- [ ] **Task 6.1: Docker Compose Orchestration**
  - **Files:** `docker-compose.yml`, `backend/Dockerfile`, `frontend/Dockerfile`, `server_ml/Dockerfile`
  - **Action:** Configure container network coordinating MongoDB, Express, FastAPI, and Vite.
- [ ] **Task 6.2: Automated GitHub Actions CI Pipeline**
  - **Files:** `.github/workflows/ci.yml`
  - **Action:** Run `flutter test`, `flutter analyze`, `npm test` (backend), and `pytest` (server_ml) on every pull request.

---

## 4. Phase Verification Status Summary

| Phase | Verification Test Suite | Pass Rate | Audit Documentation |
|---|---|---|---|
| Phase 2: Security & Auth | `backend/test_phase2_fixes.js` | 8/8 (100%) | [`PHASE2_IMPLEMENTATION_REPORT.md`](file:///b:/SentinelX/PHASE2_IMPLEMENTATION_REPORT.md) |
| Phase 3: Real Python ML Ingestion | `server_ml/test_ml_pipeline.py` & `backend/test_ml_express_integration.js` | 23/23 (100%) | [`ML_PIPELINE_IMPLEMENTATION.md`](file:///b:/SentinelX/ML_PIPELINE_IMPLEMENTATION.md), [`ML_PIPELINE_TEST_REPORT.md`](file:///b:/SentinelX/ML_PIPELINE_TEST_REPORT.md) |

---

## 5. Recommended Next Step

**Wait for User Approval.** Upon user approval, proceed directly to **Phase 4: Native ONNX Runtime C-FFI in Flutter**.
