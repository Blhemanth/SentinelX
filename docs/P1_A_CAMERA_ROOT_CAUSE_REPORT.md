# SentinelX — Phase P1-A: Physical Windows Webcam Preview Root-Cause Report

**Milestone:** P1-A Physical Windows Webcam Preview Restoration  
**Date:** 2026-11-23  
**Auditor:** Principal Multimodal Systems Architect & Senior Flutter Desktop Engineer  
**Hardware Target:** HP TrueVision HD Camera (DirectShow / MediaFoundation on Windows 11)  

---

## 1. Executive Summary

During initial testing of the SentinelX Windows desktop application (`flutter run -d windows`), the laptop webcam indicator LED illuminates, confirming that the underlying OS driver (`DirectShow` / `MediaFoundation`) successfully opened a hardware capture session. However, the graphical user interface fails to display the live physical camera footage, instead remaining blank or presenting a synthetic simulated canvas.

A forensic source-code trace across `lib/features/camera/controllers/video_feed_controller.dart`, `lib/features/camera/widgets/hardware_camera_view.dart`, `lib/core/camera/camera_ingestion_service.dart`, and `lib/features/cameras/cameras_page.dart` reveals **five compounding root causes** that break preview rendering, cause race conditions, and lock camera streams.

---

## 2. Root Cause Analysis

### Root Cause 1: Premature Ingestion Ingestion Call on Uninitialized Controller
- **Location:** [video_feed_controller.dart](file:///b:/SentinelX/lib/features/camera/controllers/video_feed_controller.dart#L247-L250) and [providers.dart](file:///b:/SentinelX/lib/core/providers/providers.dart#L53-L59)
- **Mechanism:**
  In `providers.dart`, `cameraIngestionServiceProvider` instantiates `CameraIngestionService(cameraId: 'CAM-001')`. Its asynchronous `initialize()` method is NOT executed upon instantiation.
  When `videoFeedControllerProvider` is read, its constructor calls `controller.initializeSource(type: VideoSourceType.localCamera)`, which synchronously invokes `startStream()`.
  Inside `startStream()`, it calls:
  ```dart
  if (_state.sourceType == VideoSourceType.localCamera && ingestionService != null) {
    ingestionService!.startIngestion();
  ...
  ```
  `CameraIngestionService.startIngestion()` evaluates:
  ```dart
  if (_controller == null || !_controller!.value.isInitialized) {
    debugPrint('[CameraIngestionService] Cannot start ingestion: CameraController not initialized.');
    return;
  }
  ```
  Because `initialize()` was never awaited, `_controller` is null. The method logs `Cannot start ingestion: CameraController not initialized` and returns early. The ingestion timer is never scheduled.

---

### Root Cause 2: Ingestion & Inference Resumption Failure on Widget Remounting
- **Location:** [hardware_camera_view.dart](file:///b:/SentinelX/lib/features/camera/widgets/hardware_camera_view.dart#L54-L60) and [L114-L119](file:///b:/SentinelX/lib/features/camera/widgets/hardware_camera_view.dart#L114-L119)
- **Mechanism:**
  When a user navigates between pages (e.g. from Dashboard to Camera Feeds or Alerts), the `HardwareCameraView` widget is disposed. Its `dispose()` method correctly calls:
  ```dart
  _effectiveIngestionService?.pauseIngestion();
  _effectiveScheduler?.pause();
  ```
  When the user returns to Dashboard or opens Camera Feeds, a new `HardwareCameraView` is mounted. In `initState()`:
  ```dart
  if (_activeController != null && _activeController!.value.isInitialized) {
    _isInitialized = true;
  } else {
    _initHardwareCamera();
  }
  ```
  Because the underlying singleton `CameraIngestionService` already holds an initialized `CameraController`, `_activeController!.value.isInitialized` evaluates to `true`.
  Consequently, `_initHardwareCamera()` is **completely skipped**.
  Because `_initHardwareCamera()` is skipped, `ingestion.startIngestion()` and `scheduler.start()` are **never called again**.
  The ingestion loop and continuous ONNX inference scheduler remain permanently paused (`[ContinuousInferenceScheduler] Continuous inference paused`), leaving the UI preview frozen with 0 FPS.

---

### Root Cause 3: Width / Height Dimension Inversion on Windows Landscape Layout
- **Location:** [hardware_camera_view.dart](file:///b:/SentinelX/lib/features/camera/widgets/hardware_camera_view.dart#L147-L151)
- **Mechanism:**
  Lines 148–149 contain an inversion intended for portrait mobile phone orientations:
  ```dart
  FittedBox(
    fit: BoxFit.cover,
    child: SizedBox(
      width: controller.value.previewSize?.height ?? 1280, // SWAPPED: 720
      height: controller.value.previewSize?.width ?? 720,  // SWAPPED: 1280
      child: CameraPreview(controller),
    ),
  )
  ```
  On Windows Desktop, webcams are physical landscape devices (1280x720 or 1920x1080).
  Swapping width and height forces `CameraPreview` into a 720x1280 (9:16 portrait) box. The native Windows DirectShow texture buffer (16:9 landscape) is subjected to an inverted aspect ratio inside `FittedBox(fit: BoxFit.cover)`, resulting in extreme vertical stretching, severe clipping, or complete rasterization failure.

---

### Root Cause 4: CustomPaint Fallback Masking Real Camera Loading and Failures
- **Location:** [hardware_camera_view.dart](file:///b:/SentinelX/lib/features/camera/widgets/hardware_camera_view.dart#L346-L354)
- **Mechanism:**
  `HardwareCameraView.build()` previously checked:
  ```dart
  if (_isInitialized && controller != null && controller.value.isInitialized) {
    return Stack(...); // CameraPreview
  }

  // Fallback while loading or if hardware webcam is unavailable
  if (widget.fallbackPainter != null) {
    return CustomPaint(painter: widget.fallbackPainter);
  }
  ```
  In [dashboard_screen.dart](file:///b:/SentinelX/lib/features/dashboard/screens/dashboard_screen.dart#L811), `HardwareCameraView` is instantiated with:
  `fallbackPainter: _CameraCanvasPainter(...)`.
  While the webcam is initializing (which takes 500–1,200 ms in DirectShow), or whenever `_isInitialized` was false due to the remounting bug (Root Cause 2), the widget immediately rendered the `fallbackPainter` (an animated synthetic CCTV simulation).
  The user never saw a loading state or connection error; the app silently masked the real camera with a fake simulation, while the webcam hardware LED illuminated in the background.

---

### Root Cause 5: Multi-Instance Hardware Contention Across Camera Grid
- **Location:** [cameras_page.dart](file:///b:/SentinelX/lib/features/cameras/cameras_page.dart#L179-L237)
- **Mechanism:**
  In `_CameraGrid`, `_CameraCard` was rendered for every camera feed in `cameras.length`.
  Inside `_CameraCard`:
  ```dart
  if (!isOffline)
    HardwareCameraView(
      fallback: _SimulatedVideoCanvas(cameraId: widget.camera.id),
    )
  ```
  When the grid contains multiple camera definitions (e.g. CAM-001, CAM-002, CAM-003, CAM-004), multiple `HardwareCameraView` widgets simultaneously attempted to connect to the single physical webcam (`HP TrueVision HD Camera`).
  Under Windows DirectShow, video capture devices have exclusive hardware locking. Attempting to open a second stream on an already-open capture filter results in `CameraException: CameraAccessDenied` or driver lockup.

---

## 3. Targeted Fix Strategy

| Component | Planned Remediation |
| :--- | :--- |
| **CameraIngestionService** | 1. Implement `Future<bool>? _initializationFuture` to serialize and deduplicate simultaneous initialization requests.<br>2. Make `startIngestion()` auto-await `initialize()` if `controller == null`.<br>3. Enforce deterministic physical camera enumeration. |
| **HardwareCameraView** | 1. Ensure `initState()` / `addPostFrameCallback` always resumes ingestion and inference, even if `controller.value.isInitialized` is already true.<br>2. Correct preview dimensions to landscape (`width: previewSize.width`, `height: previewSize.height`) using clean `AspectRatio(aspectRatio: controller.value.aspectRatio, child: CameraPreview(controller))`.<br>3. Replace silent fallback masking with explicit `INITIALIZING` and `ERROR` cards with retry buttons.<br>4. Accurately report camera status (`INITIALIZING`, `READY`, `STREAMING`, `PAUSED`, `ERROR`), showing `LIVE` only when measured FPS > 0. |
| **VideoFeedController** | Ensure `startStream()` awaits `ingestionService.initialize()` before initiating ingestion. |
| **Cameras Page** | Restrict `HardwareCameraView` exclusively to `CAM-001` (physical laptop webcam); render `_SimulatedVideoCanvas` for CAM-002 through CAM-004. |
