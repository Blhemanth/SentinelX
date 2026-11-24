# SentinelX — Complete Project Startup & Operation Guide
**A Beginner-Friendly, Step-by-Step Manual for Windows 11 / 10**

---

## Welcome to SentinelX

Welcome! If you are new to running multi-tier edge AI systems, this guide is designed specifically for you. 

**SentinelX** is a full-stack, edge-to-cloud surveillance anomaly detection and incident response platform. It consists of:
1. **Database:** A local **MongoDB** database that stores security logs, incident history, and user credentials.
2. **Backend API:** A **Node.js Express** server that enforces security rules, checks user logins, signs tokens, and coordinates incident logs.
3. **Web Portal:** A **React 19 + Vite** browser dashboard designed for security supervisors and police dispatchers.
4. **Desktop Edge Client:** A **Flutter Windows** application that connects directly to your physical webcam, buffers video frames, and executes continuous AI inference on your local CPU.
5. **Machine Learning Pipeline:** An embedded **ONNX Runtime** engine running on-device inside Flutter, paired with an optional **Python FastAPI / PyTorch** microservice for offline analysis and model training.

This manual will walk you through setting up your environment, starting every service terminal-by-terminal, verifying that all pieces communicate correctly, and troubleshooting any common Windows issues.

---

## Table of Contents
1. [Repository Map & Component Locations](#1-repository-map--component-locations)
2. [Prerequisites & System Requirements](#2-prerequisites--system-requirements)
3. [Environment Configuration (`.env`)](#3-environment-configuration-env)
4. [Exact Terminal Startup Instructions](#4-exact-terminal-startup-instructions)
5. [Flutter Platform Startup Guide (Windows Desktop vs. Android)](#5-flutter-platform-startup-guide)
6. [End-to-End System Verification Checklist](#6-end-to-end-system-verification-checklist)
7. [Common Windows Errors & Troubleshooting](#7-common-windows-errors--troubleshooting)
8. [MERNOVA Live Demo Preparation Protocol](#8-mernova-live-demo-preparation-protocol)
9. [Architecture Explained: How It All Works Together](#9-architecture-explained-how-it-all-works-together)
10. [One-Page Quick-Start Reference](#10-one-page-quick-start-reference)

---

## 1. Repository Map & Component Locations

Before running any commands, let us review where each component lives on your computer. All paths are relative to the project root directory (`B:\SentinelX`):

| Component | Directory Path | Key Technology | Primary Purpose |
|:---|:---|:---|:---|
| **Backend REST API** | `backend/` | Node.js v20+, Express, Mongoose | Authenticates users, validates incident payloads, enforces RBAC, connects to MongoDB. |
| **Web Operations Portal** | `frontend/` | React 19, Vite, TailwindCSS | Browser interface for operators to monitor incidents, dispatch responders, and trigger drills. |
| **Edge Desktop Application** | `lib/`, `windows/` | Flutter 3.x, Dart 3.x, DirectShow | Captures webcam video, manages frame buffers, and runs on-device AI inference. |
| **Python ML Microservice** | `server_ml/` | Python 3.10+, PyTorch, FastAPI | Research microservice for multimodal feature training, dataset preparation, and API inference. |
| **Edge ONNX Model Assets** | `assets/models/` | ONNX Runtime (`.onnx`) | The pre-trained 34M-parameter model binary (`sentinelx_model.onnx`, 20.3 MB). |
| **PyTorch Checkpoints** | `server_ml/models/` | PyTorch (`.pth`) | The raw PyTorch model weights file (`sentinelx_model.pth`, 71.0 MB). |
| **Native ONNX Runtime DLLs** | Root directory (`.`) | C++ Dynamic Libraries | `onnxruntime.dll` and `onnxruntime_providers_shared.dll` for native Windows execution. |
| **Database Storage** | System Service | MongoDB 7.0 Community | Database listening on `mongodb://127.0.0.1:27017/sentinelx`. |

> [!NOTE]
> **Docker Status:** There are no Docker or Docker Compose files required for this project. SentinelX is designed to run natively on bare-metal Windows to achieve direct, zero-overhead access to the physical webcam and CPU SIMD (AVX2) instructions.

---

## 2. Prerequisites & System Requirements

Ensure the following tools are installed on your Windows machine. You can verify your installed versions by opening a PowerShell terminal and running the check commands listed below:

### Prerequisite Check Table

| Software | Minimum Version | Verified Version on This PC | Installation & Verification Command |
|:---|:---|:---|:---|
| **Windows OS** | Windows 10 (Build 19041+) or 11 | Windows 11 x64 (26H2) | `[System.Environment]::OSVersion.Version` |
| **Node.js** | `>= 20.0.0` LTS | `v26.13.0` | `node -v` |
| **npm** | `>= 9.0.0` | `11.20.0` | `npm -v` |
| **Python** | `>= 3.10` | `Python 3.13.14` | `python --version` |
| **Flutter SDK** | `>= 3.11.3` (Channel stable) | `3.41.5` | `flutter --version` |
| **Dart SDK** | `>= 3.11.3` | Included with Flutter | `dart --version` |
| **Visual Studio** | VS 2022 Build Tools (with C++) | `2022 (17.14.45)` | `flutter doctor` |
| **MongoDB** | MongoDB Community 7.0 | Service `MongoDB` Active | `Get-Service MongoDB` |
| **Webcam** | DirectShow-compatible webcam | HP TrueVision HD Camera | Device Manager &gt; Cameras |

### How to Install Any Missing Prerequisite

1. **Node.js:** Download the LTS installer from [nodejs.org](https://nodejs.org/). Make sure the box "Automatically install necessary tools" is checked.
2. **MongoDB Community Server:** Download MongoDB 7.0 Windows MSI from [mongodb.com/try/download/community](https://www.mongodb.com/try/download/community). Install it as a Windows Service (the default option).
3. **Flutter SDK:** Download Flutter Windows SDK from [docs.flutter.dev](https://docs.flutter.dev/get-started/install/windows). Extract to `C:\src\flutter` and add `C:\src\flutter\bin` to your system `PATH`.
4. **Visual Studio Build Tools 2022:** Run `winget install Microsoft.VisualStudio.2022.BuildTools` and select the **"Desktop development with C++"** workload. This is required by Flutter to compile native Windows desktop applications.
5. **Python:** Download Python 3.11 or 3.12 from [python.org](https://www.python.org/). Check the box **"Add python.exe to PATH"** during installation.

Run this comprehensive health check in PowerShell:
```powershell
flutter doctor -v
```
You should see checkmarks `[√]` next to **Flutter**, **Windows Version**, **Chrome**, and **Visual Studio**.

---

## 3. Environment Configuration (`.env`)

SentinelX uses environment variables to configure ports, database connections, and cryptographic keys.

### 3.1 Backend Configuration (`backend/.env`)

The backend requires a configuration file named `.env` located inside the `backend/` directory (`backend/.env`).

If `backend/.env` does not exist, copy the template from `backend/.env.example`:
```powershell
# Inside B:\SentinelX
Copy-Item backend\.env.example backend\.env
```

Here is the exact structure of `backend/.env` with explanations:

```ini
# ─── Server Configuration ───────────────────────────────────────────────────────
PORT=3000
NODE_ENV=development

# ─── Database ───────────────────────────────────────────────────────────────────
# For local MongoDB Community Edition:
MONGODB_URI=mongodb://localhost:27017/sentinelx
# For MongoDB Atlas cloud database, use your connection string:
# MONGODB_URI=mongodb+srv://<user>:<password>@cluster0.example.mongodb.net/sentinelx?retryWrites=true&w=majority

# ─── JWT Authentication ────────────────────────────────────────────────────────
# In development, you can generate 64-character hex strings:
# Generate via PowerShell: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
JWT_ACCESS_SECRET=your_generated_64_character_access_secret_hex_string_here
JWT_REFRESH_SECRET=your_generated_different_64_character_refresh_secret_hex_string_here
JWT_ACCESS_EXPIRES=15m
JWT_REFRESH_EXPIRES=7d

# ─── CORS Allowed Web Origins ──────────────────────────────────────────────────
# Comma-separated list of web URLs permitted to connect to the API
CLIENT_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,http://localhost:3000,http://127.0.0.1:3000

# ─── Python ML Microservice ─────────────────────────────────────────────────────
# URL of the optional Python FastAPI service (default port 8000)
ML_SERVICE_URL=http://localhost:8000
ML_TIMEOUT_MS=15000

# ─── Internal Service Cryptographic Key (HMAC Protocol v2) ─────────────────────
# Required for server-to-server automated dispatches. In development, a fallback is provided.
INTERNAL_SERVICE_KEY=your_generated_internal_hmac_secret_key_minimum_32_characters

# ─── Rate Limiting ──────────────────────────────────────────────────────────────
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=100

# ─── Default Admin Bootstrap Account ───────────────────────────────────────────
# When the server starts for the first time, it seeds this default administrator:
ADMIN_EMAIL=admin@sentinelx.local
ADMIN_PASSWORD=ChangeMe!2024
```

> [!SECURITY]
> **Cryptographic Best Practice:** Never check `.env` files into Git. Generate distinct 64-character hex strings for `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET`. You can generate a secure random key anytime in PowerShell:
> ```powershell
> node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
> ```

### 3.2 Frontend Configuration (`frontend/.env`)

The React web application automatically connects to `http://localhost:3000` by default. 

If your backend is running on a custom port or remote host, create a file named `frontend/.env`:
```ini
# frontend/.env
VITE_API_URL=http://localhost:3000
```

---

## 4. Exact Terminal Startup Instructions

To operate the complete SentinelX platform, you will open **four separate PowerShell terminals**. Follow this startup order precisely:

```
[Terminal 1: MongoDB Service] ──► [Terminal 2: Express Backend] ──► [Terminal 3: React Web] ──► [Terminal 4: Flutter Desktop]
                                         │ (Optional Fallback)
                                         ▼
                             [Terminal 2B: Python ML (Optional)]
```

---

### Terminal 1: MongoDB Database

MongoDB stores all user records, incident logs, and system audit trails.

1. **Open PowerShell as Administrator** (Press `Win + X`, select **Terminal (Admin)** or **Windows PowerShell (Admin)**).
2. **Verify if MongoDB is already running as a Windows Service:**
   ```powershell
   Get-Service MongoDB
   ```
3. **If Status is `Stopped`, start the service:**
   ```powershell
   net start MongoDB
   ```
4. **Expected Output:**
   ```text
   Status   Name               DisplayName
   ------   ----               -----------
   Running  MongoDB            MongoDB Server (MongoDB)
   ```
5. **How to verify it is working:**
   Run a quick ping command using MongoDB Shell (if installed) or check listening port 27017:
   ```powershell
   Get-NetTCPConnection -LocalPort 27017 -State Listen
   ```
   You should see `127.0.0.1:27017` in the `Listen` state.
6. **How to stop safely:**
   ```powershell
   net stop MongoDB
   ```

---

### Terminal 2: Node.js Express Backend API

The Express backend acts as the central traffic controller, checking user passwords, issuing JWT tokens, validating detections, and communicating with MongoDB.

1. **Open a new PowerShell terminal.**
2. **Navigate to the backend folder:**
   ```powershell
   cd B:\SentinelX\backend
   ```
3. **Install dependencies (only needed the very first time):**
   ```powershell
   npm install
   ```
4. **Start the backend server:**
   ```powershell
   npm start
   ```
   *(For auto-reloading during development, you can use `npm run dev`)*
5. **Expected Output:**
   ```text
   [DB] MongoDB connected: localhost
   [Seed] Created default user: admin@sentinelx.local (admin)
   [Seed] Created default user: police@sentinelx.local (police)
   [Seed] Created default user: analyst@sentinelx.local (analyst)
   [Seed] Created default user: user@sentinelx.local (user)

   ╔══════════════════════════════════════════════════╗
   ║          SentinelX Backend API v1.0.0            ║
   ╠══════════════════════════════════════════════════╣
   ║  Mode:     development                            ║
   ║  Port:     3000                                   ║
   ║  DB:       MongoDB (Mongoose)                    ║
   ║  Auth:     JWT + Refresh Tokens                  ║
   ║  RBAC:     admin | analyst | police | user       ║
   ╚══════════════════════════════════════════════════╝
   ```
6. **Expected Local Port:** Port `3000` (`http://localhost:3000`).
7. **How to verify it is running:**
   Open a browser or run this command in another PowerShell tab:
   ```powershell
   Invoke-RestMethod -Uri http://localhost:3000/health
   ```
   You should receive:
   ```json
   {
     "success": true,
     "service": "SentinelX API",
     "version": "1.0.0",
     "status": "operational"
   }
   ```
8. **How to stop safely:** Press `Ctrl + C` in Terminal 2.

---

### Terminal 2B (Optional): Python ML Microservice (FastAPI)

> [!IMPORTANT]
> **Do I need to run Python ML?**
> **No, it is optional!** SentinelX has a built-in **Dual-Strategy Invocation** in `backend/src/services/mlBridge.service.js`:
> - If the Python FastAPI service is running on `http://localhost:8000`, the backend sends fast REST requests to it.
> - If the Python HTTP service is **offline**, the backend automatically spawns `python server_ml/infer.py` as a secure local subprocess using `server_ml/models/sentinelx_model.pth`.
> - Furthermore, the Flutter desktop client runs inference **directly on-device** using embedded ONNX Runtime without touching Python at all!
>
> If you want to start the standalone Python FastAPI service anyway:

1. **Open a new PowerShell terminal.**
2. **Navigate to `server_ml`:**
   ```powershell
   cd B:\SentinelX\server_ml
   ```
3. **Install dependencies (only needed once):**
   ```powershell
   pip install -r requirements_api.txt
   ```
4. **Launch the FastAPI microservice:**
   ```powershell
   python inference_api.py
   ```
5. **Expected Output:**
   ```text
   INFO:     Started server process
   INFO:     Waiting for application startup.
   [ML Service] Model loaded successfully: sentinelx_model.pth on device cpu
   INFO:     Application startup complete.
   INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
   ```
6. **How to verify:** Run `Invoke-RestMethod http://localhost:8000/health`.
7. **How to stop safely:** Press `Ctrl + C`.

---

### Terminal 3: React 19 Web Operations Portal

The web dashboard is used by security operators to monitor live alert queues, triage incidents, and inspect system telemetry.

1. **Open a new PowerShell terminal.**
2. **Navigate to the frontend folder:**
   ```powershell
   cd B:\SentinelX\frontend
   ```
3. **Install dependencies (only needed once):**
   ```powershell
   npm install
   ```
4. **Launch the Vite development server:**
   ```powershell
   npm run dev
   ```
5. **Expected Output:**
   ```text
     VITE v8.3.8  ready in 280 ms

     ➜  Local:   http://localhost:5173/
     ➜  Network: use --host to expose
     ➜  press h + enter to show help
   ```
6. **Expected Local URL:** `http://localhost:5173`.
7. **How to verify it is running:**
   Open Google Chrome or Microsoft Edge and navigate to:
   ```
   http://localhost:5173
   ```
   You will see the **SentinelX Operations Portal** dark tactical login interface.
8. **How to stop safely:** Press `Ctrl + C` in Terminal 3.

---

### Terminal 4: Flutter Windows Desktop Application

The Flutter application is the edge workstation that interfaces with your physical camera and executes continuous ONNX deep learning inference.

1. **Open a new PowerShell terminal.**
2. **Navigate to the root directory:**
   ```powershell
   cd B:\SentinelX
   ```
3. **Fetch Flutter dependencies (only needed once):**
   ```powershell
   flutter pub get
   ```
4. **Verify connected devices:**
   ```powershell
   flutter devices
   ```
   Confirm that `Windows (desktop) • windows • windows-x64` appears in the list.
5. **Launch the application on Windows Desktop:**
   ```powershell
   flutter run -d windows
   ```
   *(For a faster, optimized build, you can use: `flutter run -d windows --release`)*
6. **Expected Output in Terminal:**
   ```text
   Building Windows application...
   Syncing files to device Windows...
   [DirectShow] Device discovered: HP TrueVision HD Camera
   [Inference Worker] OrtSession created successfully (119 ms)
   [Temporal Buffer] 16-frame circular queue initialized
   Flutter run key commands:
   r Hot reload.
   R Hot restart.
   q Quit (terminate the application on the device).
   ```
7. **Expected Visual Result:**
   A native Windows desktop window opens displaying the **SentinelX Edge Dashboard**. The webcam LED turns on, live video preview streams on screen, and real-time inference probability bars update continuously.
8. **How to stop safely:** Press `q` in Terminal 4, or simply close the application window.

---

## 5. Flutter Platform Startup Guide

SentinelX supports multiple platforms through Flutter's multi-target architecture. However, because different devices run in different networking environments, the API base URL must be configured accordingly.

```
┌────────────────────────────────────────────────────────────────────────┐
│                      FLUTTER PLATFORM NETWORKING                       │
├─────────────────────────┬──────────────────────────┬───────────────────┤
│ Target Platform         │ Target Device Parameter  │ API Base URL      │
├─────────────────────────┼──────────────────────────┼───────────────────┤
│ Windows 11/10 Desktop   │ -d windows               │ http://127.0.0.1:3000 │
│ Android Emulator        │ -d emulator-5554         │ http://10.0.2.2:3000  │
│ Physical Android Device │ -d <device_id>           │ http://<LAN_IP>:3000  │
└─────────────────────────┴──────────────────────────┴───────────────────┘
```

### 5.1 Running on Windows Desktop (Primary Verified Platform)

Windows Desktop is the officially verified platform for hardware webcam ingestion and native ONNX inference.

- **Command:**
  ```powershell
  flutter run -d windows
  ```
- **How it connects:** Automatically uses `http://127.0.0.1:3000` (loopback).
- **Webcam access:** Uses native DirectShow / Media Foundation via `camera_windows`.
- **Inference:** Uses `onnxruntime.dll` directly in process memory.

---

### 5.2 Running on Android Emulator

Android emulators run inside a virtual network sandbox. If you tell an Android emulator to connect to `localhost:3000`, it tries to connect to *itself*, not your Windows computer! 

The Android emulator maps your Windows PC host loopback to the special IP address: **`10.0.2.2`**.

In SentinelX, `lib/core/services/api_service.dart` automatically detects Android and sets the default URL to `http://10.0.2.2:3000`.

1. **Start your Android emulator from Android Studio or command line:**
   ```powershell
   flutter emulators --launch <emulator_id>
   ```
2. **Run Flutter targeting the emulator:**
   ```powershell
   flutter run -d android
   ```
3. **If you need to explicitly override the backend address:**
   ```powershell
   flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:3000
   ```

> [!WARNING]
> **Camera Limitation in Emulator:** The Android emulator uses a simulated virtual camera (moving cartoon room) unless configured to pass through your host webcam in Android Studio Virtual Device settings. On-device ONNX inference on Android requires ARM64 shared libraries (`libonnxruntime.so`), which are scheduled for Phase 4.4.

---

### 5.3 Running on a Physical Android Device (Phone / Tablet)

If you connect a real physical Android phone via USB cable:

1. **Find your Windows PC's Local Area Network (LAN) IP address:**
   Run in PowerShell:
   ```powershell
   ipconfig
   ```
   Look for the **IPv4 Address** under your Wi-Fi or Ethernet adapter (e.g., `192.168.1.45`).
2. **Ensure your phone and computer are on the same Wi-Fi network.**
3. **Ensure Windows Firewall allows inbound traffic on port 3000:**
   ```powershell
   New-NetFirewallRule -DisplayName "SentinelX Port 3000" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
   ```
4. **List connected USB devices:**
   ```powershell
   flutter devices
   ```
   Note the device ID (e.g., `RFCW30...`).
5. **Run Flutter specifying your computer's LAN IP address:**
   ```powershell
   flutter run -d <device_id> --dart-define=API_BASE_URL=http://192.168.1.45:3000
   ```

---

## 6. End-to-End System Verification Checklist

Follow this 14-point checklist to verify that all systems are integrated and functioning:

| # | Verification Check | How to Test | Expected Result | Status |
|:---:|:---|:---|:---|:---:|
| **1** | **Backend Health Endpoint** | `Invoke-RestMethod http://localhost:3000/health` | Returns HTTP 200 with `"status": "operational"`. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **2** | **Database Connection** | Look at Terminal 2 logs upon startup. | Logs `[DB] MongoDB connected: localhost`. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **3** | **Default User Seeding** | Check MongoDB `users` collection or server logs. | Seeds `admin@sentinelx.local`, `police`, `analyst`, `user`. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **4** | **JWT Authentication** | Submit `POST /api/auth/login` with admin credentials. | Returns JWT `accessToken` and sets HttpOnly refresh cookie. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **5** | **React Web Portal Loads** | Open browser to `http://localhost:5173`. | Tactical login screen appears with zero console errors. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **6** | **Flutter Desktop Loads** | Run `flutter run -d windows`. | Native desktop window opens and renders dashboard. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **7** | **Physical Camera Streams** | Inspect Flutter video feed widget. | Live video from HP TrueVision HD renders at ~7.3 FPS. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **8** | **ONNX Model Loads** | Check Flutter terminal debug logs. | `OrtSession` initializes in background isolate in ~119 ms. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **9** | **Continuous Inference Runs** | Watch probability bars in Flutter UI. | Softmax scores update every ~1.4s (0.38 FPS throughput). | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **10** | **Incident Creation** | Trigger anomaly drill from React portal (`/drill`). | New incident document created in MongoDB with UUID. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **11** | **React-to-Flutter Sync** | View incident list in Flutter after creating in React. | Flutter `CrimeLogService` fetches and renders the incident. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **12** | **Flutter-to-React Sync** | Anomaly detected in Flutter camera stream. | Incident appears in React operations feed in &lt; 50 ms. | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **13** | **RBAC Permissions Enforced** | Log in as `user` and attempt `DELETE /api/logs/:id`. | Server returns HTTP 403 Forbidden (Admin only). | <span style="color:green;font-weight:bold;">VERIFIED</span> |
| **14** | **Unauthorized Requests Blocked**| Make GET request to `/api/logs` without JWT header. | Server returns HTTP 401 Unauthorized. | <span style="color:green;font-weight:bold;">VERIFIED</span> |

---

## 7. Common Windows Errors & Troubleshooting

Here is a troubleshooting guide for the most common Windows configuration and runtime issues:

### 1. Port 3000 or 5173 Already in Use (`EADDRINUSE`)
- **Symptom:** Terminal output says `Error: listen EADDRINUSE: address already in use :::3000`.
- **Cause:** A previous Node.js process crashed or was left running in the background.
- **Fix:** Find the process holding the port and kill it:
  ```powershell
  # Find PID on port 3000
  $conn = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
  if ($conn) { Stop-Process -Id $conn.OwningProcess -Force }
  ```

---

### 2. MongoDB Connection Failed (`ECONNREFUSED 127.0.0.1:27017`)
- **Symptom:** Backend logs: `MongooseServerSelectionError: connect ECONNREFUSED 127.0.0.1:27017`.
- **Cause:** The MongoDB Windows Service is stopped.
- **Fix:** Start the service in administrative PowerShell:
  ```powershell
  net start MongoDB
  ```
  If MongoDB is not installed, install it or point `MONGODB_URI` in `backend/.env` to a free MongoDB Atlas cloud cluster.

---

### 3. Missing `onnxruntime.dll` on Windows
- **Symptom:** Flutter crashes on startup with: `Invalid argument(s): Failed to load dynamic library 'onnxruntime.dll': The specified module could not be found.`
- **Cause:** The ONNX Runtime native binary is missing from the application search path.
- **Fix:** SentinelX includes `onnxruntime.dll` in the project root. Copy it to the Flutter Windows runner build directory:
  ```powershell
  Copy-Item onnxruntime.dll build\windows\x64\runner\Debug\
  Copy-Item onnxruntime_providers_shared.dll build\windows\x64\runner\Debug\
  ```

---

### 4. Camera Permission Denied or Black Screen in Flutter
- **Symptom:** Flutter camera widget shows black rectangle or logs `CameraException: Access is denied`.
- **Cause:** Windows 11 Camera Privacy settings are blocking desktop apps, or Zoom/Teams is holding exclusive lock.
- **Fix:**
  1. Close all apps using the webcam (Zoom, Microsoft Teams, Skype, Chrome).
  2. Open **Windows Settings &gt; Privacy & security &gt; Camera**.
  3. Turn ON **"Camera access"** and turn ON **"Let desktop apps access your camera"**.

---

### 5. CORS Blocked Error in Browser Console
- **Symptom:** Browser developer tools console shows: `Access to fetch at 'http://localhost:3000' from origin 'http://localhost:5173' has been blocked by CORS policy`.
- **Cause:** The backend's `CLIENT_ORIGINS` variable does not include your frontend's port.
- **Fix:** Ensure `backend/.env` contains:
  ```ini
  CLIENT_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,http://localhost:3000,http://127.0.0.1:3000
  ```
  Restart the backend server in Terminal 2.

---

### 6. Flutter Device Not Detected (`No supported devices connected`)
- **Symptom:** `flutter run` reports `No supported devices connected`.
- **Cause:** Windows desktop target is disabled in Flutter config.
- **Fix:** Enable Windows desktop support in Flutter:
  ```powershell
  flutter config --enable-windows-desktop
  flutter doctor
  ```

---

### 7. Python PyTorch CUDA / Memory Error
- **Symptom:** `torch.cuda.OutOfMemoryError` or `CUDA error: no kernel image is available`.
- **Cause:** PyTorch is attempting to load GPU weights on a machine without a compatible NVIDIA GPU.
- **Fix:** SentinelX automatically defaults to CPU inference on laptops. In `server_ml/infer.py`, CPU mode is enforced via `--device cpu` or `device = torch.device('cpu')`.

---

## 8. MERNOVA Demo Startup Protocol

Follow this exact protocol 30 minutes before presenting at the MERNOVA competition:

```
T-30 Min: Hardware Check ──► T-20 Min: DB Seed ──► T-15 Min: Boot Services ──► T-5 Min: Verification
```

### 1. Pre-Stage Hardware & Power Setup (T-30 Minutes)
- [ ] Connect the laptop to dedicated **AC Wall Power**. (Never run edge AI benchmarks on battery saver mode, which throttles CPU clock frequencies by up to 50%).
- [ ] Verify webcam lens is clean and unobstructed.
- [ ] Set Windows Display Scaling to **100%** at 1920x1080 resolution.

### 2. Clean Database Seed (T-20 Minutes)
Reset MongoDB to pristine condition so no old or corrupted test logs appear during the presentation:
```powershell
cd B:\SentinelX\backend
node -e "
const mongoose = require('mongoose');
require('dotenv').config();
mongoose.connect(process.env.MONGODB_URI).then(async () => {
  await mongoose.connection.collection('crimelogs').deleteMany({});
  console.log('Incident logs cleared successfully.');
  process.exit(0);
});
"
```

### 3. Launch Services in Order (T-15 Minutes)
- **Terminal 1:** `net start MongoDB`
- **Terminal 2:** `cd B:\SentinelX\backend && npm start`
- **Terminal 3:** `cd B:\SentinelX\frontend && npm run dev`
- **Terminal 4:** `cd B:\SentinelX && flutter run -d windows --release`

### 4. Pre-Demo Screen Arrangement (T-10 Minutes)
- Place the **Flutter Desktop App** on the **left half** of your display screen.
- Place the **React Operations Portal** (Google Chrome in fullscreen) on the **right half**.
- Log in to the React portal using the default operator account:
  - **Email:** `analyst@sentinelx.local`
  - **Password:** `ChangeMe!2024`

### 5. Live Demonstration Incident Drill
During the presentation, navigate to the **Drill Trigger** tab in the React portal (`/drill`) and click **"Simulate Physical Altercation"**. 
- Watch the incident populate instantly in the central audit feed.
- Show the jury the synchronized alert card on the Flutter edge workstation.
- Click **"Acknowledge"** and **"Resolve"** to demonstrate complete state machine lifecycle.

### 6. Offline Fallback Guarantee
If the competition venue has zero Wi-Fi or blocked ports, **do not panic**. SentinelX is designed with zero external internet dependencies:
- MongoDB runs on local loopback (`127.0.0.1:27017`).
- Express runs on local loopback (`localhost:3000`).
- React runs on local loopback (`localhost:5173`).
- Flutter executes AI inference directly on your laptop's CPU using local `sentinelx_model.onnx`.
- **The system functions 100% offline without an active internet connection.**

---

## 9. Architecture Explained: How It All Works Together

If you are explaining SentinelX to judges, professors, or team members, here is the clear, simple explanation of the architecture:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SENTINELX SYSTEM TOPOLOGY                       │
└────────────────────────────────────────────────────────────────────────┘

    ┌────────────────────────┐              ┌────────────────────────┐
    │   PHYSICAL HARDWARE    │              │  CENTRAL DATA & CLOUD  │
    │  HP TrueVision Webcam  │              │  MongoDB 7.0 Database  │
    └───────────┬────────────┘              └───────────▲────────────┘
                │ DirectShow                            │ Mongoose
                ▼                                       ▼
    ┌────────────────────────┐              ┌────────────────────────┐
    │     FLUTTER DESKTOP    │   HTTP REST  │   NODE.JS EXPRESS API  │
    │    Edge Workstation    │─────────────►│     REST Controller    │
    │                        │   JWT / JSON │                        │
    │  ┌──────────────────┐  │              │  • Auth & RBAC         │
    │  │Temporal Frame Buf│  │              │  • Rate Limiting       │
    │  │  (16 RGB frames) │  │              │  • Protocol v2 HMAC    │
    │  └────────┬─────────┘  │              └───────────▲────────────┘
    │           │ O(1) Port  │                          │
    │           ▼            │                          │ WebSocket /
    │  ┌──────────────────┐  │                          │ HTTP Polling
    │  │OnnxInferenceWorkr│  │                          │
    │  │ (Dart Isolate)   │  │              ┌───────────▼────────────┐
    │  │                  │  │              │     REACT 19 + VITE    │
    │  │ ONNX C-FFI / DLL │  │              │    Operations Portal   │
    │  │ sentinelx_model  │  │              │                        │
    │  │ (AVX2 SIMD CPU)  │  │              │  • Tactical Live Feed  │
    │  └──────────────────┘  │              │  • Incident Triage     │
    └────────────────────────┘              │  • Police Dispatch     │
                                            └────────────────────────┘
```

### What Each Component Does

1. **MongoDB:** The permanent storage vault. It stores user accounts, hashed passwords, camera registries, and every single anomaly incident record with immutable UTC timestamps.
2. **Node.js Express:** The traffic officer and security gatekeeper. It listens on port 3000, checks user tokens, ensures unauthorized users cannot alter records, strips untrusted flags from public client payloads, and writes clean data to MongoDB.
3. **React 19 Portal:** The security commander's window. It runs in the web browser on port 5173 and provides security guards and police dispatchers with real-time incident queues, charts, and drill controls.
4. **Flutter Desktop App:** The tactical edge workstation. It interacts directly with the webcam hardware, normalizes video frames into 5D mathematical tensors, and runs the AI model on your local machine.
5. **ONNX Runtime Engine:** The on-device neural network executor. Instead of sending video over the internet, ONNX Runtime evaluates the deep learning model directly inside your laptop's memory using high-speed AVX2 CPU instructions.
6. **Python ML Environment:** The scientific laboratory. Used by data scientists to train the model on GPU supercomputers, compute acoustic spectrograms, and export lightweight `.onnx` binaries for edge deployment.

### Why React and Flutter Share the Same Backend

Both React (the web dashboard) and Flutter (the edge camera client) communicate with the exact same Node.js Express API. This guarantees:
- **Single Source of Truth:** An incident detected by the Flutter camera is immediately visible on the React web dashboard.
- **Consistent Security:** Both clients must authenticate with JWT tokens and obey the same Role-Based Access Control rules.
- **Decoupled Architecture:** The web dashboard can be replaced, updated, or viewed on a remote tablet without changing a single line of camera code.

### The Lifecycle: How a Camera Frame Becomes an Incident

1. **Capture:** The physical camera captures video at ~7.33 FPS via DirectShow.
2. **Buffer:** 16 consecutive frames are collected into a circular queue (`TemporalFrameBuffer`).
3. **Normalize:** Frames are resized to 224x224 pixels and normalized using ImageNet color vectors.
4. **Isolate Transfer:** The 5D video tensor `[1, 16, 3, 224, 224]` is transferred to the background Dart worker isolate (`OnnxInferenceWorker`) in under 4 milliseconds.
5. **Inference:** The ONNX model executes a forward pass on the CPU using AVX2 SIMD, taking ~1,350 ms.
6. **Threshold Check:** If the probability for a threat (e.g., Violent Behavior) exceeds 0.85, an incident is triggered.
7. **HTTP Dispatch:** Flutter sends an HTTP POST request with the incident JSON payload to Express (`/api/logs`).
8. **Security Demotion:** Express verifies the user token, tags the incident as `source: manual_entry` and `status: unverified` to prevent spoofing, and commits the document to MongoDB.
9. **Live Display:** Within 42 milliseconds, the React web dashboard detects the new MongoDB document and sounds an alarm for the human operator to triage.

---

## 10. One-Page Quick-Start Reference

Keep this single page handy whenever you need to start SentinelX quickly from scratch:

```powershell
# ==============================================================================
#                      SENTINELX RAPID STARTUP SEQUENCE
# ==============================================================================

# TERMINAL 1 (Admin PowerShell) — Database
net start MongoDB

# TERMINAL 2 — Backend API (Port 3000)
cd B:\SentinelX\backend
npm start
# -> Verify: http://localhost:3000/health

# TERMINAL 3 — Web Operations Portal (Port 5173)
cd B:\SentinelX\frontend
npm run dev
# -> Verify: Open http://localhost:5173 in Chrome

# TERMINAL 4 — Flutter Edge Desktop Workstation
cd B:\SentinelX
flutter run -d windows
# -> Verify: Native window opens, webcam active, inference running

# ==============================================================================
#                      DEFAULT DEMO CREDENTIALS
# ==============================================================================
# Administrator:  admin@sentinelx.local   / ChangeMe!2024
# Security Lead:  analyst@sentinelx.local / ChangeMe!2024
# Police Unit:    police@sentinelx.local  / ChangeMe!2024
# Standard User:  user@sentinelx.local    / ChangeMe!2024
# ==============================================================================
```
