# SentinelX — Phase P1-A: Physical Camera Implementation Report

**Milestone:** P1-A Physical Windows Webcam Preview Restoration  
**Date:** 2026-11-23  
**Status:** IMPLEMENTED & AUDITED  
**Auditor / Engineer:** Principal Multimodal Systems Architect & Senior Flutter Desktop Engineer  

---

## 1. Architectural Overview

Phase P1-A establishes a deterministic, race-condition-free lifecycle for the physical Windows webcam (`HP TrueVision HD Camera` via DirectShow / MediaFoundation) across the SentinelX Flutter desktop application.

```
+-----------------------------------------------------------------------------------------+
|                                    HARDWARE LAYER                                       |
|  Physical Laptop Webcam (DirectShow / MediaFoundation Drivers on Windows 11)            |
+-----------------------------------------------------------------------------------------+
                                             │
                                             ▼
+-----------------------------------------------------------------------------------------+
|                             CameraIngestionService (Singleton)                          |
|  - _initializationFuture: In-flight deduplication guard (prevents concurrent DirectShow init)   |
|  - Primary physical camera discovery with front / webcam heuristic                     |
|  - startIngestion(): Auto-awaits initialize() if controller is uninitialized            |
|  - pauseIngestion() / resume: Cancels/restarts Timer without destroying CameraController |
|  - TemporalFrameBuffer: 16-frame bounded rolling buffer (224x224 RGB, ~2.30 MB)         |
+-----------------------------------------------------------------------------------------+
                      │                                                   │
                      ▼                                                   ▼
+-----------------------------------------------+       +---------------------------------+
|         HardwareCameraView (Widget)           |       |   ContinuousInferenceScheduler  |
| - addPostFrameCallback init & resume guard    |       | - Listens to frameStream        |
| - DirectShow Texture rendering:               |       | - Non-blocking concurrency      |
|     width: previewSize.width (1280)           |       | - Ingestion-time timestamping   |
|     height: previewSize.height (720)          |       | - Native ONNX Worker Isolate    |
| - Aspect ratio: Native landscape 16:9         |       +---------------------------------+
| - States: INITIALIZING -> READY -> STREAMING  |
| - Fallback: Explicit error view + user toggle |
+-----------------------------------------------+
```

---

## 2. Source Code Changes

### 1. `lib/core/camera/camera_ingestion_service.dart`
- **Deduplicated Initialization:** Added `Future<bool>? _initializationFuture`. If `initialize()` is called while an initialization is already in progress, the caller joins the existing future rather than spawning a competing DirectShow session. If `_controller` is already initialized, it immediately returns `true`.
- **Auto-Initialization on Ingestion:** Modified `Future<bool> startIngestion() async`. If invoked before `initialize()` has been called, it automatically awaits `initialize()` and transitions the state to `CameraConnectionStatus.streaming`, completely eliminating the premature start race condition.
- **Physical Device Heuristic:** Evaluates lens direction and device naming (`HP`, `Webcam`, `Camera`) to deterministically select the physical hardware webcam.

### 2. `lib/features/camera/controllers/video_feed_controller.dart`
- **Asynchronous Safe Start:** Updated `startStream()` and `initializeSource()` to be asynchronous, properly awaiting `ingestionService.initialize()` before initiating stream consumption.

### 3. `lib/features/camera/widgets/hardware_camera_view.dart`
- **Lifecycle Resumption:** Replaced conditional initialization skip with an unconditional post-frame check. If `ingestion.controller` is already initialized (e.g. on navigation return), it resumes frame acquisition via `ingestion.startIngestion()` and restarts inference via `scheduler.start()`.
- **Landscape Dimension Correction:** Replaced inverted portrait dimensions (`width: height, height: width`) with native landscape dimensions:
  ```dart
  width: controller.value.previewSize?.width ?? 1280.0,
  height: controller.value.previewSize?.height ?? 720.0,
  ```
  Wrapped inside `ClipRect` and `FittedBox(fit: BoxFit.cover)` to preserve exact 16:9 texture scaling without distortion.
- **Honest Status & Error Reporting:** Replaced silent `fallbackPainter` substitution with explicit states:
  - **Initializing:** Sleek loading card with `INITIALIZING HARDWARE WEBCAM` badge and spinner.
  - **Streaming:** HUD reports `CAM-001 // STREAMING (X.X FPS) [device]` only when frames are arriving (`camFps > 0`).
  - **Ready:** Reports `CAM-001 // READY [device]` when connected but paused.
  - **Error:** Displays error details with a `RETRY WEBCAM` button and an optional user toggle to view simulation.

### 4. `lib/features/cameras/cameras_page.dart`
- **Single-Hardware Exclusivity:** In `_CameraCard`, restricted `HardwareCameraView` exclusively to `widget.camera.id == 'CAM-001'`. Secondary feeds (CAM-002, CAM-003, CAM-004) use `_SimulatedVideoCanvas`, eliminating multi-instance DirectShow hardware locking conflicts.

---

## 3. Verification Summary

- **Unit Test Suite:** `test/unit/camera_lifecycle_and_preview_test.dart` and `test/unit/camera_ingestion_test.dart` verify empty camera handling, pause/resume transitions, telemetry reporting, and landscape aspect ratio constraints.
- **Hardware Runner:** `test/flutter_hardware_camera_lifecycle_runner.dart` exercises the physical webcam through all 7 lifecycle stages.
