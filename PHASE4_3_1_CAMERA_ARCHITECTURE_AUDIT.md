# SentinelX — Phase 4.3.1: Hardware Camera Ingestion Architecture Audit

**Document Version:** 1.0.0  
**Date:** 2026-11-22  
**Author:** Senior Flutter Desktop Engineer, Computer Vision Engineer & Edge AI Architect  
**Classification:** Pre-Implementation Architectural Audit  
**Scope:** Flutter Desktop (Windows x64), Camera Service, Temporal Frame Buffer, UI Viewports  

---

## 1. Executive Summary

Phase 4.2.6 verified the native C-FFI execution of the multimodal ONNX model (`sentinelx_model.onnx`, 19.44 MB) and reconciled all platform test suites to 175 passing tests.

Phase 4.3.1 transitions SentinelX from simulated video frame generation to genuine physical hardware camera ingestion. Before modifying code, a comprehensive read-only audit of the existing camera implementation was conducted to identify reusable components, structural gaps, and platform-specific constraints.

### Key Audit Findings
1. **Existing Preview Widget ([hardware_camera_view.dart](file:///b:/SentinelX/lib/features/camera/widgets/hardware_camera_view.dart)):**
   - Successfully binds to the primary laptop webcam (`HP TrueVision HD Camera`) using Flutter's official `camera: ^0.12.0+2` and `camera_windows: ^0.3.0+1` packages.
   - Renders the live video texture preview via `CameraPreview(_controller!)` with a fallback UI when offline.
   - **Architectural Gap:** It functions solely as a presentation widget; it does not extract or expose captured image bytes, does not feed an ingestion controller, and lacks a temporal frame buffer.
2. **Existing Frame Controller ([video_feed_controller.dart](file:///b:/SentinelX/lib/features/camera/controllers/video_feed_controller.dart)):**
   - Implements `VideoFrameMetadata` and `VideoFeedState` abstractions.
   - **Critical Vulnerability / Prototype Flaw:** Lines 260–273 use a synthetic mock timer generating fake pseudo-random bytes (`(_frameIndex * 2 + i) % 255`) on a 33ms interval. This fake frame generator must be completely replaced with genuine hardware camera ingestion.
3. **Model Input Contract Discrepancy ([onnx_inference_engine.dart](file:///b:/SentinelX/lib/services/onnx_inference_engine.dart)):**
   - `ImageToTensorPreprocessor.preprocessRgb` was hardcoded to an earlier prototype shape of `[1, 3, 640, 640]`.
   - The authoritative multimodal ONNX model (`sentinelx_model.onnx`) and PyTorch preprocessor (`server_ml/preprocessor.py`) require **16 uniform video frames** resized to $224 \times 224$ RGB:
     $$\text{Shape: } [1, 16, 3, 224, 224] \quad (\text{ImageNet normalized Float32List})$$
4. **Platform-Specific Windows Plugin Capability:**
   - In `camera_windows-0.3.0+1`, `startImageStream` is **unimplemented** (`UnimplementedError: Streaming is not currently supported on Windows`).
   - Windows Media Foundation capture operates via `takePicture()`, which returns captured JPEG frames via `XFile`.
   - Android (`camera_android_camerax`) supports continuous image streaming via `startImageStream`.
   - The ingestion architecture must support both periodic polling capture (for Windows Desktop) and streaming callbacks (for Android/Linux).

---

## 2. Inventory of Existing Camera Components

| Component / File | Purpose & Current Implementation | Reusability Assessment |
| :--- | :--- | :--- |
| [hardware_camera_view.dart](file:///b:/SentinelX/lib/features/camera/widgets/hardware_camera_view.dart) | Connects to `availableCameras().first`, initializes `CameraController`, renders `CameraPreview`. | **REUSABLE & EXTENSIBLE:** Preserve the preview rendering; connect it to a centralized `CameraIngestionService`. |
| [video_feed_controller.dart](file:///b:/SentinelX/lib/features/camera/controllers/video_feed_controller.dart) | Manages streaming state, FPS metrics, and frame metadata stream. | **REFACTOR:** Replace synthetic timer in `_extractNextFrame()` with genuine camera frame ingestion. |
| [onnx_inference_engine.dart](file:///b:/SentinelX/lib/services/onnx_inference_engine.dart) | Contains `ImageToTensorPreprocessor` ($640 \times 640$). | **UPDATE:** Add 16-frame temporal sequence preprocessor producing `[1, 16, 3, 224, 224]`. |
| [dashboard_screen.dart](file:///b:/SentinelX/lib/features/dashboard/screens/dashboard_screen.dart) | Embeds `HardwareCameraView` in Command Center viewport. | **PRESERVE:** Keep UI layout, camera ID (`CAM-001`), and bounding box overlays intact. |
| [cameras_page.dart](file:///b:/SentinelX/lib/features/cameras/cameras_page.dart) | Embeds `HardwareCameraView` in multi-camera surveillance grid. | **PRESERVE:** Maintain grid layout and selection logic. |
| [providers.dart](file:///b:/SentinelX/lib/core/providers/providers.dart) | Riverpod providers for camera feeds, detections, and metrics. | **EXTEND:** Expose `cameraIngestionServiceProvider` and `temporalFrameBufferProvider`. |

---

## 3. Physical Hardware Environment Verification

Inspection of the host system's hardware configuration confirmed:
- **Device Class:** Plug-and-Play Camera (`Get-PnpDevice -Class Camera`).
- **Device Name:** `HP TrueVision HD Camera`.
- **Status:** `OK` (Instance ID: `USB\VID_04F2&PID_B6F1&MI_00\7&AEA999A&0&0000`).
- **Physical Capture Test:** Direct test via OpenCV (`cv2.VideoCapture(0).read()`) successfully captured genuine frames:
  - Resolution: $640 \times 480 \times 3$ BGR.
  - Native aspect ratio: 4:3.

---

## 4. Architectural Design for Phase 4.3.1

### 4.1 Ingestion Service Architecture (`CameraIngestionService`)
To avoid coupling frame capture directly to UI widget lifecycles, frame acquisition is managed by a dedicated service:
1. **Device Discovery & Selection:** Enumerates `availableCameras()`, binds to `'CAM-001'` (laptop webcam), and records true hardware name.
2. **Lifecycle Management:** Handles `initialize()`, `startIngestion()`, `pause()`, and `dispose()`.
3. **Error & Reconnection Handling:**
   - Detects permission denials (`CameraException: permissionDenied`).
   - Detects device disconnects via `onCameraClosing` / `onCameraError` streams.
   - Implements exponential-backoff automatic reconnection (1s, 2s, 4s, up to 10s max).
4. **Acquisition Engine:**
   - Captures frames from the hardware camera.
   - Uses `dart:ui.instantiateImageCodec` to decode JPEG bytes into $224 \times 224$ RGB raw pixels asynchronously off the UI thread.
   - Cleans up temporary capture files immediately to prevent storage bloat.

### 4.2 Temporal Rolling Frame Buffer (`TemporalFrameBuffer`)
The ONNX model requires a sliding temporal window of 16 frames:
1. **Capacity:** Fixed bound of exactly 16 frames (`ListQueue<VideoFrame>` with `maxCapacity = 16`).
2. **FIFO Ingestion:** When a new frame arrives:
   - If buffer length exceeds 16, the oldest frame is evicted.
   - Timestamp ordering ($t_0 < t_1 < \dots < t_{15}$) is strictly maintained.
3. **Pre-16 Frame Readiness (Warming Up):**
   - `isBufferReady` returns `false` when `frameCount < 16`.
   - When requested before 16 frames exist, the buffer returns a padded sequence (repeating the oldest available frame or initial frame to yield 16 frames, matching `server_ml/preprocessor.py` behavior).
4. **Memory Footprint:**
   - 1 frame ($224 \times 224 \times 3$ uint8) = $150{,}528\text{ bytes} \approx 147\text{ KB}$.
   - 16 frames in memory = $16 \times 150{,}528 = 2{,}408{,}448\text{ bytes} \approx 2.30\text{ MB}$.
   - Strict bounded ring buffer guarantees zero memory leakage over hours of continuous capture.

### 4.3 Hardware Telemetry & Metadata
Every captured frame retains:
- `cameraId`: e.g. `'CAM-001'`.
- `deviceName`: e.g. `'HP TrueVision HD Camera'`.
- `timestamp`: UTC DateTime of acquisition.
- `width`: 224.
- `height`: 224.
- `pixelFormat`: `'RGB888'`.
- `status`: `'valid'` / `'padded'` / `'corrupt'`.
- `acquisitionLatencyMs`: Time taken from camera trigger to decoded RGB buffer.

---

## 5. Implementation Action Plan

1. **Step 1:** Implement [lib/core/camera/camera_frame.dart](file:///b:/SentinelX/lib/core/camera/camera_frame.dart) (Data model with metadata and tensor extraction).
2. **Step 2:** Implement [lib/core/camera/temporal_frame_buffer.dart](file:///b:/SentinelX/lib/core/camera/temporal_frame_buffer.dart) (16-frame bounded ring buffer with timestamp sorting and pre-16 padding).
3. **Step 3:** Implement [lib/core/camera/camera_ingestion_service.dart](file:///b:/SentinelX/lib/core/camera/camera_ingestion_service.dart) (Hardware webcam capture, acquisition loop, disconnect/reconnect handling, telemetry).
4. **Step 4:** Integrate with [lib/features/camera/widgets/hardware_camera_view.dart](file:///b:/SentinelX/lib/features/camera/widgets/hardware_camera_view.dart) and [lib/core/providers/providers.dart](file:///b:/SentinelX/lib/core/providers/providers.dart).
5. **Step 5:** Author comprehensive automated tests in `test/unit/camera_ingestion_test.dart` testing initialization, rolling capacity, timestamps, disposal, disconnect, and memory stability.
6. **Step 6:** Execute physical hardware verification script measuring actual FPS, acquisition latency, memory usage, and initialization timing.
