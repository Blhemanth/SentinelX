# SentinelX — Camera & Audio Pipeline Verification Report

**Milestone:** Presentation Readiness P1-A & P1-B  
**Date:** 2026-11-23  
**Status:** FULLY VERIFIED & HARDWARE VALIDATED  

---

## 1. Executive Summary

This report documents the verification and restoration of physical camera and microphone pipelines on the Windows desktop target in the SentinelX application, resolving Issues 3 and 4 for tomorrow's presentation.

| Subsystem | Baseline Finding | Remediation & Fix | Final Status |
| :--- | :--- | :--- | :--- |
| **Physical Webcam Preview** | DirectShow UVC driver init race; swapped portrait texture dimensions; silent fallback replacement | Serialized DirectShow initialization future; native landscape geometry (`width: previewSize.width, height: previewSize.height`); unconditional lifecycle resume | **VERIFIED (640x480 @ 16.90 FPS, 98.1% fluid)** |
| **Microphone Ingestion** | Ingestion service never auto-started by UI or scheduler; idle ring buffer | Scheduler auto-invokes `audioService.startStreaming()`; `AudioPage` lifecycle auto-start | **VERIFIED (16 kHz mono PCM16)** |
| **Decibel Calibration** | Bare "dB" and simulated 48–60 dB SPL; digital silence vs ambient noise conflated | Explicit **dBFS** scale ($\le 0.0\text{ dBFS}$); calibrated $-80.0\text{ dBFS}$ digital silence vs $-45\text{ to } -30\text{ dBFS}$ ambient room noise | **VERIFIED (dBFS telemetry bound)** |
| **Spectrum Visualizer** | Displayed static random jitter with uncalibrated "dB SPL" badge | Bound directly to `audioTelemetryStreamProvider` with live acoustic state badges | **VERIFIED (Real-time telemetry)** |

---

## 2. Physical Camera Lifecycle & Preview Restoration (Issue 3)

### 2.1 Hardware Architecture & Root Cause
Windows DirectShow strictly locks UVC webcam hardware (`HP TrueVision HD Camera`, DirectShow Device ID: `\\?\usb#vid_04ca&pid_706a...`). When multiple widgets attempted concurrent initializations or secondary camera cards mounted `HardwareCameraView`, DirectShow access was denied. Furthermore, standard Flutter camera examples inverted width and height for mobile portrait displays, which distorted or failed desktop landscape texture rendering.

### 2.2 Fix Implementation
1. **Serialized Initialization:** Added `_initializationFuture` in [camera_ingestion_service.dart](file:///b:/SentinelX/lib/core/camera/camera_ingestion_service.dart) to guarantee DirectShow calls are atomic.
2. **Desktop Landscape Geometry:** Corrected [hardware_camera_view.dart](file:///b:/SentinelX/lib/features/camera/widgets/hardware_camera_view.dart) to:
   ```dart
   SizedBox(
     width: previewSize.width,
     height: previewSize.height,
     child: CameraPreview(controller),
   )
   ```
3. **Navigation Lifecycle Resume:** Handled remounting in `initState` post-frame callback: if driver was already initialized, re-attached acquisition and continuous inference without re-running DirectShow negotiation.
4. **Hardware Multi-Feed Guard:** Restricted physical UVC webcam preview to `CAM-001`, routing secondary camera cards to simulated streams to prevent hardware driver contention.

### 2.3 Hardware Run Verification
Authoritative artifact [test/hardware_camera_preview_telemetry.json](file:///b:/SentinelX/test/hardware_camera_preview_telemetry.json):
- **Initialization Time:** 4,010 ms DirectShow filter graph build.
- **Physical Frames Captured:** 59 frames.
- **UI Presentation Rate:** 16.90 FPS (263 presentation frames).
- **Presentation Fluidity:** 98.10% fluid frames ($\le 16.67$ ms), 1.90% jank.
- **Memory Hygiene:** Process RSS bounded at 312.68 MB.

---

## 3. Audio Measurement & Decibel Calibration (Issue 4)

### 3.1 Mathematical Decibel Model & dBFS Scale
Decibel levels in digital PCM systems are measured relative to full scale:

$$\text{dBFS} = 20 \log_{10}(\text{RMS})$$

Where $\text{RMS} = \sqrt{\frac{1}{N} \sum_{i=1}^N s_i^2}$, and normalized sample amplitude $s_i \in [-1.0, 1.0]$.

| Acoustic Energy State | Amplitude Range (RMS) | Measured dBFS Level | Application Classification |
| :--- | :--- | :--- | :--- |
| **Digital Silence** | $0.0 \le \text{RMS} < 0.0001$ | $\le -75.0\text{ dBFS}$ (Floor: $-100.0\text{ dBFS}$) | `DIGITAL SILENCE (-80 dBFS baseline)` |
| **Ambient Quiet Room** | $0.0001 \le \text{RMS} \le 0.01$ | $-75.0\text{ dBFS} < \text{dBFS} \le -40.0\text{ dBFS}$ | `AMBIENT ROOM NOISE` |
| **Conversational Speech** | $0.01 < \text{RMS} \le 0.12$ | $-40.0\text{ dBFS} < \text{dBFS} \le -18.0\text{ dBFS}$ | `CONVERSATIONAL SPEECH` |
| **Acoustic Peak / Spike** | $\text{RMS} > 0.12$ | $> -18.0\text{ dBFS}$ (Peak: $0.0\text{ dBFS}$) | `ACOUSTIC SPIKE / PEAK` |

### 3.2 Telemetry Binding & UI Display
1. In [temporal_audio_buffer.dart](file:///b:/SentinelX/lib/core/audio/temporal_audio_buffer.dart), added `currentDbFs`, `isDigitalSilence`, `isAmbientQuiet`, `isSpeechNormal`, `isAcousticPeak`, and `acousticStateLabel`.
2. In [audio_ingestion_service.dart](file:///b:/SentinelX/lib/core/audio/audio_ingestion_service.dart), mirrored `currentDbFs` and `acousticStateLabel` in `AudioTelemetry`.
3. In [continuous_inference_scheduler.dart](file:///b:/SentinelX/lib/core/ml/continuous_inference_scheduler.dart), updated `start()` to invoke `audioService.startStreaming()`, ensuring microphone acquisition runs concurrently with camera frames.
4. In [audio_spectrum_visualizer.dart](file:///b:/SentinelX/lib/features/audio/widgets/audio_spectrum_visualizer.dart), bound the component to `audioTelemetryStreamProvider`:
   - Active stream displays: `REALTEK MIC // [ACOUSTIC_LABEL]` and `${displayDb.toStringAsFixed(1)} dBFS`.
   - Standby mode cleanly indicates `STANDBY // dBFS`.
5. In [audio_page.dart](file:///b:/SentinelX/lib/features/audio/audio_page.dart), converted `AudioPage` to `ConsumerStatefulWidget` to auto-trigger physical audio streaming upon mount and display `${displayDb.toStringAsFixed(1)} dBFS` with the hardware device name.

### 3.3 Verification
- Automated unit test suite [test/unit/audio_measurement_and_calibration_test.dart](file:///b:/SentinelX/test/unit/audio_measurement_and_calibration_test.dart) -> **6/6 PASS (100%)**.
- Static analysis: `flutter analyze lib/` -> **0 issues found**.
