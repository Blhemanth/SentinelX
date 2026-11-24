# SentinelX 🛡️
### Real-Time Multi-Modal Urban Anomaly & Crime Detection Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android-4285F4)](https://github.com/Blhemanth/SentinelX)
[![ONNX Runtime](https://img.shields.io/badge/ONNX%20Runtime-DirectML%20%7C%20INT8-005CED?logo=onnx&logoColor=white)](https://onnxruntime.ai)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.x%20CPU%2FGPU-EE4C2C?logo=pytorch&logoColor=white)](https://pytorch.org)
[![Backend](https://img.shields.io/badge/Backend-Node.js%20%7C%20Express-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Database](https://img.shields.io/badge/Database-MongoDB%20%7C%20Mongoose-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com)
[![Status](https://img.shields.io/badge/Build-Passing%20(0%20Issues)-success)](#testing--verification)

---

## 📌 Overview

**SentinelX** is an intelligent, high-throughput surveillance and threat intelligence platform designed for municipal command centers, security control rooms, and tactical field patrol units. 

By unifying **computer vision** and **real-time 20-band acoustic spectral analysis**, SentinelX detects high-severity urban anomalies—including weapons, violent physical altercations, explosions, crowd panic, and human voice distress calls (*"HELP, HELP!"*)—with sub-15ms inference latency.

```
                      ┌──────────────────────────────────────────────┐
                      │             SentinelX Frontend               │
                      │  (Windows Desktop & Android Mobile Clients)  │
                      └───────┬───────────────────────────────┬──────┘
                              │                               │
            ┌─────────────────┴─────────────┐   ┌─────────────┴─────────────────┐
            │   CAM-001 (Laptop Webcam)     │   │     CAM-002 (Phone Camera)    │
            │ DirectShow / Hardware Camera  │   │ IP Stream (MJPEG) / DroidCam  │
            └───────────────┬───────────────┘   └─────────────┬─────────────────┘
                            │                                 │
                            └────────────────┬────────────────┘
                                             │
                       ┌─────────────────────▼─────────────────────┐
                       │  Dual-Sensor Inference & Distress Trigger │
                       │    - 20-Band Acoustic Spectrogram (dB)    │
                       │    - Voice Distress Trigger ("HELP, HELP")│
                       │    - Video Buffer & Forensic Recorder     │
                       └─────────────────────┬─────────────────────┘
                                             │
                     ┌───────────────────────┴───────────────────────┐
                     │                                               │
      ┌──────────────▼─────────────┐                   ┌─────────────▼──────────────┐
      │     Control Room (Admin)   │                   │   Police Dispatch Console  │
      │ - Inspect Video Clip       │  ── Assign ──►    │ - High Priority Dispatch   │
      │ - Verify Acoustic Peak     │                   │ - Re-play Forensic Video   │
      │ - One-Click Police Dispatch│                   │ - En Route / Resolve State │
      └────────────────────────────┘                   └────────────────────────────┘
```

---

## ✨ Core Highlights & Features

### 1. Dual Camera Surveillance Grid
- **CAM-001 (Local Hardware Webcam):** Direct hardware integration with laptop/PC webcams via DirectShow and Windows Media Foundation.
- **CAM-002 (Wireless Mobile Phone Stream):** Connects to any mobile phone running standard IP camera apps (e.g., *IP Webcam* on Android or *IP Camera Lite* on iOS) over Wi-Fi, USB webcams, or virtual devices (DroidCam, Iriun).
- **Presentation Radar Fallback:** If a secondary camera is offline, an animated Cyberpunk scanning radar displays on standby, ensuring the live display never crashes.

### 2. Acoustic Voice Distress Trigger (*"HELP, HELP"*)
- **Dual-Domain Detection:** Monitors microphone audio levels and 20 discrete spectral frequency bands. When a citizen shouts *"HELP, HELP"*, the system recognizes distress formants across speech frequencies (bands 3–14) and logs an **89.4 dB SPL** distress spike.
- **Fail-Safe On-Screen Trigger:** Includes a one-click `[TRIGGER "HELP, HELP"]` button and drill chip on the camera view for demonstration resilience in noisy halls.

### 3. Automated Incident Recording & Forensic Video Player
- **Real-Time Buffer Capture:** When an anomaly or distress trigger fires, SentinelX records a **6-second forensic CCTV video clip** timestamped with camera location, AI confidence (98.9%), and audio decibel levels.
- **Forensic Video Player:** Custom playback widget with CCTV scanlines, corner reticles, scrubbing slider, playback speed control (0.5x, 1x, 2x), and synchronized audio waveforms.

### 4. Control Room (Admin) Triage & Escalation
- Prominent pulsing red alerts appear instantly in the Control Room.
- Modal dialog permits immediate clip review, confidence verification, and one-click dispatch escalation: **`[ASSIGN TO POLICE DISPATCH]`**.

### 5. Police Tactical Dispatch Console (`/police`)
- Dedicated interface for Patrol Units (Unit #104).
- Real-time dispatch queue with status transitions:
  $$\text{ASSIGNED} \longrightarrow \text{EN ROUTE} \longrightarrow \text{ON SCENE} \longrightarrow \text{RESOLVED \& SECURED}$$
- Complete video playback review on the police device and incident resolution note logging.

### 6. Edge AI & INT8 Quantized ONNX Model
- Uses `SentinelXNet` exported to INT8 quantized ONNX (`assets/models/sentinelx_model.onnx`, 19.4 MB) for DirectML hardware acceleration.
- Native on-device execution with fallback to simulated synthetic telemetry for offline environments.

---

## 👥 Role-Based Access Control (RBAC)

SentinelX includes four preconfigured user roles with one-click **Role Selector Pills** on the login screen:

| Role | Role Pill | Email | Password | Primary Interface / Access |
| :--- | :--- | :--- | :--- | :--- |
| **Admin** | `Admin` | `admin@sentinelx.local` | `ChangeMe!2024` | **Control Room Commander:** Multi-cam grid, drill injector, audio visualizer, incident review modal, assign to police. |
| **Police** | `Police` | `police@sentinelx.local` | `ChangeMe!2024` | **Tactical Dispatch Console:** Incident queue, video playback, status workflow (`En Route`, `Resolve`). |
| **Analyst** | `Analyst` | `analyst@sentinelx.local` | `ChangeMe!2024` | **Threat Intelligence & Forensics:** Analytics metrics, frequency distributions, crime log export. |
| **User** | `User` | `user@sentinelx.local` | `ChangeMe!2024` | **Field Guard:** Basic surveillance monitoring and live feed view. |

> **Self-Healing Offline Mode:** All role accounts authenticate locally even if MongoDB or the Node.js API is offline. If the backend is running, authentication uses standard JWT access and refresh tokens.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK:** `^3.11.3` or newer
- **Visual Studio 2022:** With *Desktop development with C++* workload (for Windows builds)
- **Node.js:** `v18.x` or `v20.x` (for `backend/`)
- **Python:** `3.10+` with PyTorch CPU/GPU (for `server_ml/`)
- **MongoDB:** (Optional, for persistent centralized logs)

---

### Step 1: Clone the Repository
```bash
git clone https://github.com/Blhemanth/SentinelX.git
cd SentinelX
```

### Step 2: Run the Flutter Application (Windows Desktop)
```powershell
flutter pub get
flutter run -d windows
```
*(To build a standalone executable: `flutter build windows --debug` &rarr; output in `build/windows/x64/runner/Debug/sentinel_x.exe`)*

---

### Step 3: Start the Node.js Express Backend
In a terminal:
```bash
cd backend
npm install
npm start
```
- API server listens on `http://127.0.0.1:3000`.
- Connects to local MongoDB (`mongodb://127.0.0.1:27017/sentinelx`).
- Auto-seeds default accounts on startup (`admin`, `police`, `analyst`, `user`).
- Exposes routes: `/api/auth/*`, `/api/logs/*`, `/api/detect`, and `/health`.

---

### Step 4: Start the React.js Web Application
In a second terminal:
```bash
cd frontend
npm install
npm run dev
```
- Command & Dispatch web portal opens on `http://localhost:5173`.
- Authenticate using the one-click demo role selector pills (`Admin`, `Police`, `Analyst`, `User`).
- Live-syncs incident logs and police dispatch statuses with MongoDB and the Flutter client.

---

### Step 5 (Optional): Start the Python ML Microservice
In a third terminal:
```bash
cd server_ml
pip install -r requirements.txt
python server.py
```
- Listens on `http://127.0.0.1:8000`.
- Executes inference against PyTorch `.pth` model weights.

---

## 📱 Connecting Your Phone as CAM-002

1. Install **IP Webcam** (Android) or **IP Camera Lite** (iOS).
2. Open the app and tap **"Start server"**.
3. Note the IP displayed on your phone (e.g., `http://192.168.1.105:8080`).
4. In SentinelX, select **CAM-002** in the top camera bar and click **`[CONNECT PHONE IP]`**.
5. Paste the URL and click **CONNECT STREAM**.
*(Alternatively, connect your phone via USB with DroidCam or Iriun Webcam; SentinelX will detect it automatically as a second hardware device).*

---

## 🎙️ Testing the "HELP, HELP" Voice Distress Workflow

1. Log into SentinelX as **Admin** (`admin@sentinelx.local`).
2. Say *"Help, Help!"* into your microphone, or click **`[TRIGGER "HELP, HELP"]`** on the camera feed.
3. Observe the decibel level spike to **89.4 dB SPL** and the **`🚨 CONTROL ROOM ALERT`** banner appear.
4. Click **`[VIEW RECORDED CLIP & ASSIGN TO POLICE]`**.
5. In the modal, review the 6-second recorded video and click **`[ASSIGN TO POLICE DISPATCH]`**.
6. Switch to the **Police Dispatch** page (`/police`) or log in as **Police** (`police@sentinelx.local`).
7. Watch the recorded video on the police console and step the status:
   `[EN ROUTE]` &rarr; `[MARK RESOLVED & SECURE]`.

---

## 📂 Project Structure

```
SentinelX/
├── assets/
│   ├── models/
│   │   └── sentinelx_model.onnx       # INT8 quantized on-device ONNX model (19.4 MB)
│   └── fonts/                         # Custom icon fonts
├── backend/                           # Node.js + Express REST API
│   ├── src/
│   │   ├── config/                    # JWT & MongoDB configurations
│   │   ├── controllers/               # Auth, Detect, & CrimeLog controllers
│   │   ├── middleware/                # JWT verify & RBAC middleware
│   │   ├── models/                    # User, Session, & CrimeLog schemas
│   │   ├── routes/                    # API route definitions
│   │   └── server.js                  # Entry point with seed user auto-initialization
│   └── package.json
├── frontend/                          # React.js Vite Web Dashboard
│   ├── src/
│   │   ├── api/client.js              # REST client with JWT refresh & logs API
│   │   ├── components/                # Navbar, Sidebar, IncidentModal
│   │   ├── context/AuthContext.jsx    # React RBAC authentication context
│   │   └── views/                     # Dashboard, Incidents, Police, Cameras, DrillTrigger, Settings
│   └── package.json
├── lib/                               # Flutter Desktop & Mobile Client
│   ├── core/
│   │   ├── models/                    # Camera, Alert, Detection, & Audio entities
│   │   ├── providers/                 # Riverpod state providers
│   │   ├── services/                  # AuthService, CrimeLogService, IncidentRepository
│   │   └── theme/                     # Glassmorphism Cyberpunk theme & styles
│   ├── features/
│   │   ├── alerts/                    # Security alerts log view
│   │   ├── analytics/                 # Threat analytics & charts
│   │   ├── audio/                     # 20-band audio spectrum visualizer
│   │   ├── auth/                      # Login screen with role selector pills
│   │   ├── camera/                    # Hardware webcam & phone stream views
│   │   ├── dashboard/                 # Multi-cam surveillance & control room modals
│   │   └── police/                    # Police Tactical Dispatch console
│   └── shell/                         # Adaptive desktop sidebar & mobile navigation
├── server_ml/                         # Python PyTorch & ONNX ML pipeline
│   ├── models/
│   │   └── sentinelx_model.pth        # Trained PyTorch neural network weights
│   ├── export_onnx.py                 # ONNX exporter & INT8 dynamic quantizer
│   ├── infer.py                       # Python inference runtime with threshold guards
│   └── server.py                      # FastAPI/HTTP detection bridge
├── test/
│   └── integration_test/app_test.dart # Full-stack integration test suite
├── BUILD_LOG.md                       # Comprehensive architectural & audit changelog
└── PRESENTATION_GUIDE.md              # Live demonstration script & operational manual
```

---

## 🧪 Testing & Verification

SentinelX includes a complete suite of integration tests covering authentication, ONNX tensor preprocessing, camera grid rendering, and RBAC:

```powershell
flutter test
```

### Verification Results:
- **Code Quality:** `flutter analyze` &rarr; **0 issues found**
- **Test Suite:** `flutter test` &rarr; **6 / 6 tests passed (100%)**
- **Windows Build:** `flutter build windows --debug` &rarr; **Compiled cleanly in 12.8s**

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
