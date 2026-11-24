// SentinelX - Camera Ingestion Service
// Real-time hardware webcam frame acquisition, format conversion, and temporal buffer ingestion.
// Supports device initialization, error handling, permission checks, and automatic reconnection.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:sentinel_x/core/camera/camera_frame.dart';
import 'package:sentinel_x/core/camera/temporal_frame_buffer.dart';
import 'package:sentinel_x/core/utils/monotonic_clock.dart';

enum CameraConnectionStatus {
  uninitialized,
  initializing,
  connected,
  streaming,
  disconnected,
  permissionDenied,
  noDeviceFound,
  error,
}

@immutable
class CameraTelemetry {
  final CameraConnectionStatus status;
  final String deviceName;
  final String cameraId;
  final double measuredFps;
  final int lastAcquisitionLatencyMs;
  final int bufferCount;
  final bool isBufferReady;
  final int totalCaptured;
  final int droppedFrames;
  final int initializationTimeMs;
  final int reconnectCount;
  final int memoryUsageBytes;
  final String? errorMessage;

  const CameraTelemetry({
    required this.status,
    required this.deviceName,
    required this.cameraId,
    required this.measuredFps,
    required this.lastAcquisitionLatencyMs,
    required this.bufferCount,
    required this.isBufferReady,
    required this.totalCaptured,
    required this.droppedFrames,
    required this.initializationTimeMs,
    required this.reconnectCount,
    required this.memoryUsageBytes,
    this.errorMessage,
  });

  factory CameraTelemetry.initial({String cameraId = 'CAM-001'}) {
    return CameraTelemetry(
      status: CameraConnectionStatus.uninitialized,
      deviceName: 'Unknown Camera',
      cameraId: cameraId,
      measuredFps: 0.0,
      lastAcquisitionLatencyMs: 0,
      bufferCount: 0,
      isBufferReady: false,
      totalCaptured: 0,
      droppedFrames: 0,
      initializationTimeMs: 0,
      reconnectCount: 0,
      memoryUsageBytes: 0,
    );
  }
}

class CameraIngestionService {
  final String cameraId;
  final TemporalFrameBuffer temporalBuffer;
  final ResolutionPreset resolutionPreset;
  final int targetFps;

  CameraController? _controller;
  CameraController? get controller => _controller;

  CameraConnectionStatus _status = CameraConnectionStatus.uninitialized;
  CameraConnectionStatus get status => _status;

  String _deviceName = 'Unknown Camera';
  String get deviceName => _deviceName;

  int _initializationTimeMs = 0;
  int _reconnectCount = 0;
  int _frameIndex = 0;
  bool _isAcquiring = false;
  Timer? _acquisitionTimer;
  Future<bool>? _initializationFuture;

  // FPS tracking window (last 10 frame timestamps)
  final List<DateTime> _recentTimestamps = <DateTime>[];

  final StreamController<CameraFrame> _frameStreamController =
      StreamController<CameraFrame>.broadcast();
  Stream<CameraFrame> get frameStream => _frameStreamController.stream;

  final StreamController<CameraTelemetry> _telemetryStreamController =
      StreamController<CameraTelemetry>.broadcast();
  Stream<CameraTelemetry> get telemetryStream => _telemetryStreamController.stream;

  CameraTelemetry _currentTelemetry;
  CameraTelemetry get currentTelemetry => _currentTelemetry;

  CameraIngestionService({
    this.cameraId = 'CAM-001',
    TemporalFrameBuffer? temporalBuffer,
    this.resolutionPreset = ResolutionPreset.medium,
    this.targetFps = 10,
  })  : temporalBuffer = temporalBuffer ?? TemporalFrameBuffer(),
        _currentTelemetry = CameraTelemetry.initial(cameraId: cameraId);

  /// Discovers available video capture hardware and initializes the primary webcam.
  /// Deduplicates concurrent calls and avoids re-initializing an active controller.
  Future<bool> initialize({List<CameraDescription>? injectedCameras}) async {
    if (_controller != null && _controller!.value.isInitialized) {
      _status = _isAcquiring ? CameraConnectionStatus.streaming : CameraConnectionStatus.connected;
      _emitTelemetry();
      return true;
    }

    if (_initializationFuture != null) {
      return _initializationFuture!;
    }

    _initializationFuture = _performInitialize(injectedCameras: injectedCameras);
    try {
      return await _initializationFuture!;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<bool> _performInitialize({List<CameraDescription>? injectedCameras}) async {
    _status = CameraConnectionStatus.initializing;
    _emitTelemetry();

    final initStopwatch = Stopwatch()..start();

    try {
      final cameras = injectedCameras ?? await availableCameras();
      if (cameras.isEmpty) {
        _status = CameraConnectionStatus.noDeviceFound;
        _emitTelemetry(error: 'No hardware camera device detected.');
        return false;
      }

      // Enumerate and select physical webcam (prefer front / HP / webcam)
      final primaryCamera = cameras.firstWhere(
        (cam) =>
            cam.lensDirection == CameraLensDirection.front ||
            cam.name.toLowerCase().contains('hp') ||
            cam.name.toLowerCase().contains('webcam') ||
            cam.name.toLowerCase().contains('camera'),
        orElse: () => cameras.first,
      );
      _deviceName = primaryCamera.name.isNotEmpty ? primaryCamera.name : 'Physical Webcam';

      // Clean up previous controller if any was dangling
      if (_controller != null) {
        try {
          await _controller!.dispose();
        } catch (_) {}
        _controller = null;
      }

      final controller = CameraController(
        primaryCamera,
        resolutionPreset,
        enableAudio: false,
      );

      _controller = controller;
      await controller.initialize();

      initStopwatch.stop();
      _initializationTimeMs = initStopwatch.elapsedMilliseconds;
      _status = CameraConnectionStatus.connected;

      _emitTelemetry();
      debugPrint('[CameraIngestionService] Camera initialized: $_deviceName in ${_initializationTimeMs}ms (Resolution: ${controller.value.previewSize})');
      return true;
    } on CameraException catch (e) {
      initStopwatch.stop();
      if (e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt') {
        _status = CameraConnectionStatus.permissionDenied;
      } else {
        _status = CameraConnectionStatus.error;
      }
      _emitTelemetry(error: 'Camera initialization error: [${e.code}] ${e.description}');
      return false;
    } catch (e) {
      initStopwatch.stop();
      _status = CameraConnectionStatus.error;
      _emitTelemetry(error: 'Unexpected error during camera initialization: $e');
      return false;
    }
  }

  /// Begins real-time frame acquisition from the camera into the temporal buffer.
  /// Automatically awaits initialization if controller is not yet ready.
  Future<bool> startIngestion() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint('[CameraIngestionService] CameraController not initialized. Initializing now...');
      final ok = await initialize();
      if (!ok) {
        debugPrint('[CameraIngestionService] Cannot start ingestion: CameraController initialization failed.');
        return false;
      }
    }

    if (_status == CameraConnectionStatus.streaming && _acquisitionTimer != null && _acquisitionTimer!.isActive) {
      return true;
    }

    _status = CameraConnectionStatus.streaming;
    _emitTelemetry();

    final intervalMs = (1000 / targetFps.clamp(1, 30)).round();

    _acquisitionTimer?.cancel();
    _acquisitionTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _acquireNextFrame(),
    );
    return true;
  }

  /// Stops the acquisition loop while keeping the camera preview active.
  void pauseIngestion() {
    _acquisitionTimer?.cancel();
    _acquisitionTimer = null;
    if (_status == CameraConnectionStatus.streaming) {
      _status = CameraConnectionStatus.connected;
      _emitTelemetry();
    }
  }

  /// Single-frame acquisition step: triggers hardware capture, decodes RGB, and updates buffer.
  Future<void> _acquireNextFrame() async {
    if (_isAcquiring || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    _isAcquiring = true;
    final stopwatch = Stopwatch()..start();

    try {
      // 1. Hardware capture via CameraController
      final xFile = await _controller!.takePicture();
      final jpegBytes = await xFile.readAsBytes();

      // Clean up temporary image file immediately to prevent disk accumulation
      try {
        final tempFile = File(xFile.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {
        // Ignored: Best-effort temp file cleanup
      }

      // 2. High-performance Skia C++ decode & resize to 224x224 RGB
      final rgbBytes = await _decodeAndResizeRgb(jpegBytes, 224, 224);

      stopwatch.stop();
      final latencyMs = stopwatch.elapsedMilliseconds;

      _frameIndex++;
      final captureTime = MonotonicClock.now();
      _updateFpsCalculation(captureTime.utc);

      final frame = CameraFrame(
        cameraId: cameraId,
        deviceName: _deviceName,
        frameIndex: _frameIndex,
        timestamp: captureTime.utc,
        monotonicUs: captureTime.monotonicUs,
        width: 224,
        height: 224,
        pixelFormat: 'RGB888',
        rgbBytes: rgbBytes,
        acquisitionLatencyMs: latencyMs,
        status: CameraFrameStatus.valid,
      );

      // 3. Ingest into temporal 16-frame ring buffer
      temporalBuffer.addFrame(frame);

      // 4. Emit to stream subscribers
      if (!_frameStreamController.isClosed) {
        _frameStreamController.add(frame);
      }

      _emitTelemetry(lastLatency: latencyMs);
    } catch (e) {
      stopwatch.stop();
      debugPrint('[CameraIngestionService] Frame capture failed: $e');
      _handleCaptureFailure(e);
    } finally {
      _isAcquiring = false;
    }
  }

  /// Decodes JPEG bytes directly to 224x224 RGB planar-packed bytes via Flutter's Skia engine.
  Future<Uint8List> _decodeAndResizeRgb(Uint8List imageBytes, int targetW, int targetH) async {
    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: targetW,
      targetHeight: targetH,
    );
    final frameInfo = await codec.getNextFrame();
    final image = frameInfo.image;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (byteData == null) {
      throw StateError('Failed to convert decoded frame to RGBA ByteData.');
    }

    final rgba = byteData.buffer.asUint8List();
    final rgb = Uint8List(targetW * targetH * 3);

    // Convert RGBA [4-byte] to RGB [3-byte]
    for (int i = 0, j = 0; i < rgba.length && j + 2 < rgb.length; i += 4, j += 3) {
      rgb[j] = rgba[i];
      rgb[j + 1] = rgba[i + 1];
      rgb[j + 2] = rgba[i + 2];
    }

    return rgb;
  }

  void _updateFpsCalculation(DateTime captureTime) {
    _recentTimestamps.add(captureTime);
    if (_recentTimestamps.length > 10) {
      _recentTimestamps.removeAt(0);
    }
  }

  double _calculateCurrentFps() {
    if (_recentTimestamps.length < 2) return 0.0;
    final durationMs = _recentTimestamps.last.difference(_recentTimestamps.first).inMilliseconds;
    if (durationMs <= 0) return 0.0;
    return ((_recentTimestamps.length - 1) / (durationMs / 1000.0));
  }

  void _handleCaptureFailure(dynamic error) {
    if (_status != CameraConnectionStatus.disconnected) {
      _status = CameraConnectionStatus.disconnected;
      temporalBuffer.clear(); // Flush pre-disconnect stale frames
      _emitTelemetry(error: 'Camera stream disconnected: $error');
      _scheduleReconnection();
    }
  }

  /// Implements automatic reconnection with exponential backoff (1s, 2s, 4s, up to 10s).
  void _scheduleReconnection() {
    _acquisitionTimer?.cancel();
    _reconnectCount++;

    final backoffSeconds = min(pow(2, _reconnectCount).toInt(), 10);
    debugPrint('[CameraIngestionService] Camera disconnected. Attempting reconnect #$_reconnectCount in ${backoffSeconds}s...');

    Timer(Duration(seconds: backoffSeconds), () async {
      if (_status == CameraConnectionStatus.disconnected) {
        final restored = await initialize();
        if (restored) {
          temporalBuffer.clear(); // Ensure buffer warms up fresh post-reconnection
          debugPrint('[CameraIngestionService] Camera reconnected successfully.');
          startIngestion();
        } else {
          _scheduleReconnection();
        }
      }
    });
  }

  void _emitTelemetry({int? lastLatency, String? error}) {
    _currentTelemetry = CameraTelemetry(
      status: _status,
      deviceName: _deviceName,
      cameraId: cameraId,
      measuredFps: _calculateCurrentFps(),
      lastAcquisitionLatencyMs: lastLatency ?? _currentTelemetry.lastAcquisitionLatencyMs,
      bufferCount: temporalBuffer.currentCount,
      isBufferReady: temporalBuffer.isReady,
      totalCaptured: _frameIndex,
      droppedFrames: temporalBuffer.droppedFramesCount,
      initializationTimeMs: _initializationTimeMs,
      reconnectCount: _reconnectCount,
      memoryUsageBytes: temporalBuffer.memoryUsageBytes,
      errorMessage: error,
    );

    if (!_telemetryStreamController.isClosed) {
      _telemetryStreamController.add(_currentTelemetry);
    }
  }

  /// Releases hardware webcam resources cleanly
  Future<void> dispose() async {
    pauseIngestion();
    await _controller?.dispose();
    _controller = null;
    _status = CameraConnectionStatus.uninitialized;
    _emitTelemetry();

    await _frameStreamController.close();
    await _telemetryStreamController.close();
    temporalBuffer.clear();
  }
}
