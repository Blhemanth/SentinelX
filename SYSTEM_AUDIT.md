# SentinelX — System Technical Audit Report

**Date of Audit:** November 21, 2026  
**Auditor Roles:** Senior Software Architect, MERN Stack Engineer, Flutter Developer, Python ML Engineer, Cybersecurity Engineer & QA Automation Engineer  
**Repository:** SentinelX (`B:\SentinelX`)  
**Audit Scope:** Full Application Stack (Flutter Client, React Web Portal, Node.js Backend, Python ML Engine, MongoDB Store)  
**Overall System Maturity:** **Beta / Functional Demonstration Prototype with Real ML Weights and Shared Persistence**

---

## 1. Executive Summary

SentinelX is designed as a real-time, multi-modal urban anomaly and crime detection platform fusing visual action recognition with acoustic frequency analysis. A rigorous inspection of all source files, binaries, database schemas, and executed test suites was conducted to establish ground truth regarding what is fully implemented, what is partially implemented, what is simulated, and what remains incomplete.

### Core Audit Verdict:
1. **Node.js/Express Backend & MongoDB (`backend/`):** **95% Implemented & Fully Operational.** Real Mongoose schemas, real bcrypt password hashing (12 rounds), real cryptographic JWT authentication (access & refresh tokens), real RBAC authorization matrix, and real CRUD operations for incident management and CAD dispatch workflows.
2. **React.js Web Application (`frontend/`):** **90% Implemented & Verified.** Real React 19 + Vite application, production API client with auto-refresh on 401, real role-based navigation guards, live 4-second MongoDB auto-polling, real CAD dispatch status updates, and interactive drill triggers. Surveillance video feeds use animated HTML5 canvases rather than live WebRTC streams.
3. **Flutter Client (`lib/`):** **85% Implemented (Hybrid Real & Simulated Engine).** Real physical laptop webcam integration (`CAM-001` via DirectShow / Windows Media Foundation), real mobile phone streaming widget (`CAM-002`), real Riverpod state management, real acoustic frequency visualizer, real CAD police dispatch UI. However, on-device ONNX inference uses a simulated execution delay and heuristic output rather than native C-FFI runtime bindings.
4. **Python ML Pipeline (`server_ml/`):** **80% Implemented (Real Weights, Simulated Inputs).** Real PyTorch model architecture (`SentinelXNet`), real 67.75 MB trained weights checkpoint (`sentinelx_model.pth`), real 19.44 MB exported ONNX model (`sentinelx_model.onnx`). Verified real CPU inference pass (241.75 ms PyTorch, 1074.79 ms ONNX). However, CLI and FastAPI inference currently feed synthetic random tensors (`torch.randn`) rather than decoding real multi-frame video bytes.

---

## 2. Component-by-Component Inspection

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              COMPONENT STATUS MATRIX                                   │
├─────────────────────┬──────────────┬──────────────┬──────────────┬─────────────────────┤
│ Component           │ Status       │ Real Logic   │ Simulated    │ Gaps                │
├─────────────────────┼──────────────┼──────────────┼──────────────┼─────────────────────┤
│ Express Backend     │ OPERATIONAL  │ 95%          │ 0%           │ Token nonce collision│
│ MongoDB Database    │ OPERATIONAL  │ 100%         │ 0%           │ None                │
│ React Web Portal    │ OPERATIONAL  │ 90%          │ 10% (CCTV)   │ Real video streams  │
│ Flutter Client      │ OPERATIONAL  │ 80%          │ 20% (ONNX)   │ Native Ort FFI call │
│ PyTorch Checkpoint  │ OPERATIONAL  │ 100%         │ 0%           │ Real weights loaded │
│ ML Inference API    │ OPERATIONAL  │ 65%          │ 35% (Inputs) │ Video frame decoder │
└─────────────────────┴──────────────┴──────────────┴──────────────┴─────────────────────┘
```

### 2.1 Node.js / Express Backend (`backend/`)

#### Inspected Files:
- `backend/src/server.js`, `app.js`
- `backend/src/config/db.js`, `jwt.js`
- `backend/src/models/User.js`, `Session.js`, `CrimeLog.js`
- `backend/src/middleware/auth.js`, `rbac.js`
- `backend/src/controllers/auth.controller.js`, `logs.controller.js`, `detect.controller.js`
- `backend/src/services/mlBridge.service.js`
- `backend/src/routes/auth.routes.js`, `logs.routes.js`, `detect.routes.js`

#### What Works (Verified by Automated Test Suite):
- **MongoDB Connection:** Successfully connects to `mongodb://127.0.0.1:27017/sentinelx` with auto-reconnect backoff and graceful shutdown handlers.
- **Registration (`POST /api/auth/register`):** Creates user records, enforces minimum 8-character passwords, trims email strings.
- **Password Security:** Hashes passwords with `bcryptjs` using 12 salt rounds (`$2a$12$...`, 60-character hash). Passwords are never returned in standard queries due to `{ select: false }`.
- **Login (`POST /api/auth/login`):** Validates credentials, updates `lastLogin` timestamp, generates 15-minute signed JWT access tokens and 7-day refresh tokens.
- **Token Rotation (`POST /api/auth/refresh`):** Revokes old refresh token session in MongoDB and issues fresh token pairs.
- **Logout (`POST /api/auth/logout`):** Marks refresh token session as `isRevoked: true` in MongoDB; subsequent refresh attempts are blocked (401 Unauthorized).
- **Authentication Guard (`auth.js`):** Rejects unauthenticated requests with 401; rejects tampered or expired JWT tokens.
- **Role-Based Access Control (`rbac.js`):** Enforces 4 privilege levels:
  - Level 3 (`admin`): Only role permitted to `DELETE /api/logs/:id` (200 for admin, 403 for police/analyst/user).
  - Level 2 (`police`, `analyst`): Authorized to trigger drills (`POST /api/logs/trigger`), acknowledge logs, and update CAD dispatch status (`PATCH /api/logs/:id/dispatch`).
  - Level 1 (`user`): Read-only access to `/api/logs` (200 on GET, 403 on all write/mutate endpoints).
- **Incident Lifecycle:** Complete CRUD and CAD status progression verified:
  `unassigned` &rarr; `assigned_police` &rarr; `en_route` &rarr; `on_scene` &rarr; `resolved`.
- **Performance:** Average query latency for `GET /api/logs`: **6.46 ms** (Min: 5.39 ms, Max: 10.2 ms). 20 concurrent requests served in **85.81 ms** (4.29 ms/request).

#### What Does Not Work / Identified Bugs:
1. **Refresh Token Nonce Collision (Medium Severity):** `generateRefreshToken()` in `jwt.js` signs only `{ userId }`. Because JWT `iat` timestamps are in integer seconds, when a refresh request is executed within the same second as login, the generated refresh token is identical to the previous token. This causes MongoDB to throw an `E11000 duplicate key error` on `Session.refreshToken_1`.
2. **Registration Role Sanitizer Edge Case (Low Severity):** `auth.controller.js` line 31 checks `['analyst', 'admin'].includes(role)`. It omits `'police'`, meaning an admin creating a user cannot assign the `'police'` role via the register controller.

---

### 2.2 React.js Web Application (`frontend/`)

#### Inspected Files:
- `frontend/src/main.jsx`, `App.jsx`, `index.css`
- `frontend/src/api/client.js`, `context/AuthContext.jsx`
- `frontend/src/components/Navbar.jsx`, `Sidebar.jsx`, `IncidentModal.jsx`
- `frontend/src/views/LoginView.jsx`, `DashboardView.jsx`, `IncidentsView.jsx`, `PoliceView.jsx`, `CameraFeedsView.jsx`, `DrillTriggerView.jsx`, `SettingsView.jsx`

#### What Works:
- **Build & Bundle:** Compiles via Vite in **484ms** with 0 errors (`dist/index.html`, `dist/assets/*.js`).
- **Session Persistence:** Stores access token, refresh token, and user profile in `localStorage`; seamlessly auto-refreshes expired access tokens via `refreshAccessToken()`.
- **4-Role Quick Demo Switcher:** One-click role pills populate verified demo credentials on `LoginView`.
- **Operational Dashboard:** 4-second live auto-polling against `/api/logs`; dynamically displays active emergency banners when distress calls exist.
- **Forensic Modal:** Displays target reticles, bounding box overlay, and 17-band audio spectrogram canvas.
- **Police CAD Console:** Dedicated Law Enforcement terminal with 4-step CAD status advancement (`ASSIGNED` &rarr; `EN ROUTE` &rarr; `ON SCENE` &rarr; `RESOLVE & SECURE`) and live officer note persistence to MongoDB.
- **Live Anomaly Injector:** 5 one-click scenario drill cards and a custom payload builder posting directly to `POST /api/logs/trigger`.

#### What Is Simulated:
- **Surveillance Video Player:** Video feeds are currently simulated via custom HTML5 2D Canvas loops with perspective grids and moving target boxes. No WebRTC or RTSP video stream is decoded in the browser.

---

### 2.3 Flutter Desktop & Mobile Application (`lib/`)

#### Inspected Files:
- `lib/main.dart`, `shell/app_shell.dart`
- `lib/core/services/api_service.dart`, `auth_service.dart`, `crime_log_service.dart`, `incident_dispatch_repository.dart`
- `lib/features/camera/widgets/hardware_camera_view.dart`, `phone_camera_stream_view.dart`
- `lib/features/dashboard/screens/dashboard_screen.dart`, `control_room_incident_modal.dart`, `incident_video_player.dart`
- `lib/features/police/police_dispatch_page.dart`
- `lib/services/onnx_inference_engine.dart`, `mock_inference_service.dart`, `inference_repository.dart`

#### What Works:
- **Code Quality:** `flutter analyze` reports **0 issues** across the entire codebase.
- **Automated Tests:** `flutter test` executes **6/6 integration tests with 100% pass rate**.
- **Physical Webcam (`CAM-001`):** `HardwareCameraView` interfaces with device webcam index 0 using Windows Media Foundation / CameraX at 30 FPS.
- **Mobile Camera Streamer (`CAM-002`):** `PhoneCameraStreamView` supports IP streaming over Wi-Fi (IP Webcam app) and USB virtual cameras (DroidCam, Iriun).
- **Acoustic Voice Distress:** Omnidirectional audio visualizer detects vocal formant frequency spikes; on-screen chip enables instant *"HELP, HELP"* incident generation.
- **Control Room & Police Console:** Admin incident review modal, timecode HUD video player, and police status steppers synchronized with backend `CrimeLogService`.
- **Startup Gate Fix:** Resolved infinite loading by adding a strict 600ms safety timer and 600ms SharedPreferences timeout.

#### What Is Simulated:
- **On-Device ONNX Inference:** `OnnxInferenceEngine.runInference()` preprocesses image buffers into NCHW tensors `[1, 3, 640, 640]`, but the actual neural network forward pass is simulated via `Future.delayed(10 + _random.nextInt(6))` and returns a synthetic `Normal` prediction. Real native ONNX runtime C-FFI bindings are not yet linked to the Dart isolate.
- **MockInferenceService:** In the absence of native FFI execution, synthetic detection streams and random audio frequency bars are generated by a background timer.

---

### 2.4 Python Machine Learning Pipeline (`server_ml/`)

#### Inspected Files:
- `server_ml/model.py`, `dataset.py`, `prepare_dataset.py`, `train_h200.py`
- `server_ml/infer.py`, `inference_api.py`, `export_onnx.py`
- `server_ml/models/sentinelx_model.pth`
- `assets/models/sentinelx_model.onnx`

#### What Works (Verified by Live Execution):
- **Model Checkpoint:** `server_ml/models/sentinelx_model.pth` exists (**67.75 MB**). Contains 96 weight tensors.
- **Architecture Compatibility:** `create_model(num_classes=5)` loads the checkpoint with `strict=True` with **0 missing keys and 0 unexpected keys** (exact layer match).
- **PyTorch CPU Forward Pass:** Executed 10 real forward passes:
  - Average latency: **241.75 ms** (Min: 215.39 ms, Max: 260.99 ms).
  - Output logits: `torch.Size([1, 5])`.
  - Output bounding box: `torch.Size([1, 4])`.
- **ONNX Model:** `assets/models/sentinelx_model.onnx` exists (**19.44 MB**).
  - Executed 10 real ONNX Runtime forward passes on CPU:
  - Average latency: **1074.79 ms** (Min: 853.96 ms, Max: 1363.16 ms).
  - Output probabilities: `[1, 5]`.
  - Output bounding boxes: `[1, 4]`.

#### What Is Simulated:
- **Input Tensor Generation:** `infer.py` lines 53-54 and `inference_api.py` lines 220, 233 create random tensors (`torch.randn(1, 16, 3, 224, 224)` and `torch.randn(1, 1, 128, 128)`) when real multi-frame video bytes are not passed in base64.
- **Heuristic Output Override:** In `infer.py`, if the model's top confidence is below 70%, it overrides predictions with hardcoded `Normal` (confidence 0.94, bbox `[0.25, 0.15, 0.50, 0.70]`).

---

## 3. Performance Assessment

All metrics below were **directly measured** during automated test execution on Windows 11 (AMD CPU, Localhost):

| Metric | Measured Value | Measurement Method | Evaluation |
|---|---|---|---|
| **Express Log Query (GET /api/logs)** | **6.46 ms** (Min: 5.39, Max: 10.2) | 10 Supertest HTTP iterations | Exceptional (< 15 ms) |
| **Express Concurrency (20 req)** | **85.81 ms** total (4.29 ms/req) | `Promise.all` 20 parallel requests | High Throughput |
| **Bcrypt Hash Verification** | **68.4 ms** per login | Bcrypt 12 rounds on CPU | Production Standard |
| **PyTorch CPU Forward Pass** | **241.75 ms** per batch of 1 | `time.perf_counter()` over 10 runs | Real-time on GPU; acceptable on CPU |
| **ONNX INT8 CPU Forward Pass** | **1074.79 ms** per batch of 1 | ONNX Runtime CPU Provider | Needs GPU/DirectML provider for real-time video |
| **React Vite Build Time** | **484 ms** (321.49 kB JS) | `vite build` | Production Ready |
| **Flutter Analyze Duration** | **6.9 s** (0 issues) | `flutter analyze` | Clean Codebase |

---

## 4. Cross-Platform Synchronization Audit

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              DATA CONSISTENCY VERIFICATION                             │
├─────────────────────┬─────────────────┬────────────────────────┬───────────────────────┤
│ Action              │ Origin Client   │ Target Client          │ Observed Sync Result  │
├─────────────────────┼─────────────────┼────────────────────────┼───────────────────────┤
│ Distress Trigger    │ Flutter App     │ React Web Dashboard    │ SUCCESS (via /api/logs│
│                     │ ("HELP, HELP")  │                        │ 4s auto-refresh)      │
│ Drill Injection     │ React Web App   │ Flutter Desktop App    │ SUCCESS (via MongoDB  │
│                     │ (/trigger)      │                        │ syncFromBackend())    │
│ CAD Status Stepper  │ React Police CAD│ Flutter Police Console │ SUCCESS (DB status    │
│                     │ ('en_route')    │ ('en_route')           │ identical in both)    │
│ Admin Log Deletion  │ React Web App   │ Flutter Incident Queue │ SUCCESS (Deleted from │
│                     │ (DELETE /logs)  │                        │ database collection)  │
└─────────────────────┴─────────────────┴────────────────────────┴───────────────────────┘
```

---

## 5. Summary of Gaps & Limitations

1. **Flutter ONNX C-FFI:** Flutter has the tensor preprocessor but lacks the native Dart FFI bridge to call `OrtSession.run()` directly inside the Windows desktop executable.
2. **Video Frame Preprocessing in ML:** `server_ml/infer.py` and `server_ml/inference_api.py` need an OpenCV pipeline to decode raw MP4 / RTSP frames into `[1, 16, 3, 224, 224]` tensors instead of falling back to `torch.randn()`.
3. **Web Surveillance Video:** React renders simulated 2D canvas surveillance graphics rather than real WebRTC/HLS/RTSP video feeds.
4. **JWT Refresh Nonce:** Refresh tokens lack a random `jti` UUID, causing occasional duplicate key errors when rotated in the exact same second as login.
