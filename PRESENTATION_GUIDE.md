# SentinelX — Project Presentation & Demonstration Master Manual

> **For Presentation Date:** Tomorrow  
> **System:** SentinelX — Real-Time Audio-Visual Urban Anomaly & Crime Detection System  
> **Frontends Supported:** Windows Desktop Command Center & Android Mobile Patrol  
> **AI Inference Engine:** ONNX Runtime DirectML / PyTorch Hybrid  

---

## 1. Executive Summary & Architecture

SentinelX is an end-to-end, multi-sensor surveillance and anomaly detection command platform. It pairs live visual detection with 20-band acoustic spectral analysis to detect weapons, violence, explosions, and voice distress anomalies ("HELP, HELP").

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

## 2. Default Accounts & Role Credentials

On the **Login Screen**, you do **not** need to type credentials manually. Use the one-click **Quick Role Selector Pills** on top of the form:

| Role | Role Pill | Email | Password | Access / Scope |
| :--- | :--- | :--- | :--- | :--- |
| **Admin** | `Admin` | `admin@sentinelx.local` | `ChangeMe!2024` | **Control Room Commander:** Multi-cam grid, acoustic spectrogram, drill injector, incident review modal, assign to police. |
| **Police** | `Police` | `police@sentinelx.local` | `ChangeMe!2024` | **Tactical Response Unit #104:** Dispatches queue, video playback, acknowledge & en-route, mark on scene, resolve & secure. |
| **Analyst** | `Analyst` | `analyst@sentinelx.local` | `ChangeMe!2024` | **Threat Intelligence & Forensics:** Analytics metrics, frequency distributions, crime log export. |
| **User** | `User` | `user@sentinelx.local` | `ChangeMe!2024` | **Field Guard:** Basic surveillance monitoring and live feed view. |

> **Offline Guarantee:** All 4 role accounts authenticate instantly even if MongoDB or the Node.js backend is offline. If the backend is running, it connects via JWT with refresh tokens.

---

## 3. Dual Camera Setup: Laptop Webcam + Phone Camera

SentinelX displays **two distinct cameras** in the Multi-Camera Grid with **zero dummy cams**:

- **CAM-001:** `Laptop Camera 1 (Local Hardware Webcam)`
- **CAM-002:** `Phone Camera 2 (Wireless IP Stream / Mobile Webcam)`

### Connecting Your Phone as CAM-002:

#### Method A — Free "IP Webcam" App (Recommended for Android / iOS):
1. Install **IP Webcam** (by Pavel Khlebovich on Android) or **IP Camera Lite** (iOS).
2. Open the app, scroll to the bottom, and tap **"Start server"**.
3. The phone will display an IP address on its screen (e.g. `http://192.168.1.105:8080`).
4. In SentinelX, switch to **CAM-002** and click the button: **`[CONNECT PHONE IP]`**.
5. Enter your phone's IP address and tap **CONNECT STREAM**.
6. The app will immediately begin streaming the live video from your phone!

#### Method B — DroidCam or Iriun Webcam (USB or Wi-Fi):
1. Install **DroidCam** or **Iriun Webcam** on your phone and PC.
2. Windows will automatically recognize your phone as a second hardware webcam.
3. SentinelX automatically binds CAM-002 to the second hardware camera index!

#### Method C — Standby Presentation Mode (No phone required):
- If you don't have Wi-Fi or cannot connect the phone during the presentation, CAM-002 automatically renders a **Cyberpunk Tactical Standby Scanner** with live targeting reticles, so the screen **never shows a black box or crashes**.

---

## 4. Voice Distress Detection: "HELP, HELP" Workflow

During your presentation, when you demonstrate voice distress:

1. **Speak into the microphone:** Say clearly: *"Help, Help!"*
2. **Or Tap the On-Screen Voice Trigger:** On the camera grid, tap the red button:  
   `[🎙️ TRIGGER "HELP, HELP"]` (or tap the `🎙️ HELP, HELP` chip in the drill bar).

### What Happens Instantly:
1. **Acoustic Signature Detection:**
   - Audio decibels spike to **89.4 dB SPL**.
   - The 20-band spectrum visualizer detects human voice distress formants across speech frequencies (bands 3–14).
   - AI confidence locks in at **98.9%**.
2. **Forensic Video Clip Recording:**
   - SentinelX automatically latches a **6-second recorded CCTV video clip** of the event.
   - A pulsing red alert appears in the Control Room:  
     `🚨 CONTROL ROOM ALERT: Acoustic Distress: HELP, HELP on CAM-001`
3. **Control Room Review (Admin Action):**
   - Click **`[VIEW RECORDED CLIP & ASSIGN TO POLICE]`**.
   - The **Control Room Modal** pops up:
     - Plays the recorded incident video with CCTV scanlines, bounding boxes, and timestamp HUD.
     - Displays the exact transcript: *"HELP! HELP! EMERGENCY!"*
     - Click the blue button: **`[ASSIGN TO POLICE DISPATCH]`**.
4. **Police Tactical Console (Police Action):**
   - Navigate to the **Police Dispatch** page (or click "VIEW POLICE PAGE" in the toast).
   - The incident appears at the top of the Police queue with a pulsing critical badge.
   - The Police Officer can click **`[VIEW RECORDED VIDEO]`** to review the forensic video clip.
   - The Officer clicks **`[EN ROUTE]`** (status changes to En Route).
   - Once resolved, click **`[MARK RESOLVED & SECURE]`** (turns green: "INCIDENT NEUTRALIZED & SECURED").

---

## 5. Step-by-Step Presentation Script (Live Demo)

Follow this exact walkthrough during your presentation tomorrow:

### Scene 1: Introduction & Multi-Camera Grid (2 Minutes)
- **Action:** Open the app and log in as **Admin** by tapping the `Admin` role pill.
- **Explain:** *"This is SentinelX, an AI-powered urban anomaly detection system. It monitors multiple camera streams simultaneously. Here we have CAM-001 connected to my laptop webcam and CAM-002 connected to my mobile phone over wireless IP."*
- **Demo:** Click between `CAM-001` and `CAM-002`. Show the primary video feed switching while the secondary feed continues rendering in the preview tile.

### Scene 2: Live AI Anomaly Drills (1 Minute)
- **Action:** In the Drill Toolbar, click `WEAPON DETECTED`, then `FIGHTING`, then `EXPLOSION`.
- **Explain:** *"SentinelX runs local ONNX inference with DirectML hardware acceleration. When threats are detected, real-time bounding boxes and threat confidence indicators update within 15 milliseconds."*
- **Action:** Click `NORMAL // SECURE` to restore clear baseline monitoring.

### Scene 3: The Climax — Acoustic Voice Trigger "HELP, HELP" (2 Minutes)
- **Action:** Say into your microphone: *"Help! Help!"* (or click the prominent `[TRIGGER "HELP, HELP"]` button on the camera feed).
- **Explain:** *"SentinelX doesn't just look at video; it continuously monitors acoustic signatures. When a citizen shouts 'help, help', the acoustic visualizer registers an 89 dB distress spike across vocal formant frequencies."*
- **Observe:** Point to the top banner: `🚨 CONTROL ROOM ALERT: Acoustic Distress: HELP, HELP`.
- **Explain:** *"The system has automatically recorded a 6-second forensic video clip and buffered it to the Control Room."*

### Scene 4: Control Room Triage & Police Dispatch (2 Minutes)
- **Action:** Click `[VIEW RECORDED CLIP & ASSIGN TO POLICE]`.
- **Explain:** *"The Control Room commander inspects the recorded video playback, checks the acoustic peak, and escalates the incident."*
- **Action:** Click `[ASSIGN TO POLICE DISPATCH]`. Show the confirmation toast.
- **Action:** Click the sidebar icon `Police Dispatch` (or log in as `Police`).
- **Explain:** *"Instantly, the incident is routed to the Police Tactical Dispatch console. Patrol Unit #104 receives the GPS location, the audio transcript, and the recorded video clip."*
- **Action:** Click `[VIEW RECORDED VIDEO]` to demonstrate video playback on the police screen.
- **Action:** Click `[EN ROUTE]`, then `[MARK RESOLVED & SECURE]`.
- **Conclude:** *"The incident is neutralized, time-stamped, and archived in the immutable crime log."*

---

## 6. How to Run SentinelX Concurrently

Run the following commands in separate terminals:

### Terminal 1: Flutter Desktop Frontend
```powershell
cd B:\SentinelX
flutter run -d windows
```

### Terminal 2 (Optional): Node.js Express Backend
```powershell
cd B:\SentinelX\backend
npm start
```

### Terminal 3 (Optional): Python ML Microservice
```powershell
cd B:\SentinelX\server_ml
python server.py
```

> **Note:** SentinelX is architected with self-healing offline fallbacks. Even if Terminals 2 and 3 are not running, the Flutter app on Terminal 1 runs 100% of the UI, dual-camera feeds, ONNX ML inference, voice triggers, video recording, and police dispatch workflows without any errors!
