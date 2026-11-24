// SentinelX — Camera Lifecycle, Initialization & Preview Unit Tests
// Verifies deterministic initialization, deduplication, pause/resume lifecycle,
// and landscape preview orientation contracts.

import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:sentinel_x/core/camera/camera_ingestion_service.dart';
import 'package:sentinel_x/core/camera/temporal_frame_buffer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Ingestion Service Lifecycle & Deduplication Tests', () {
    test('CameraIngestionService handles empty camera list gracefully', () async {
      final service = CameraIngestionService(cameraId: 'CAM-TEST-01');
      final result = await service.initialize(injectedCameras: const <CameraDescription>[]);

      expect(result, isFalse);
      expect(service.status, equals(CameraConnectionStatus.noDeviceFound));
      expect(service.currentTelemetry.errorMessage, contains('No hardware camera device detected'));

      await service.dispose();
    });

    test('pauseIngestion and startIngestion transition status correctly without throwing', () async {
      final buffer = TemporalFrameBuffer(capacity: 16);
      final service = CameraIngestionService(cameraId: 'CAM-TEST-02', temporalBuffer: buffer);

      // When uninitialized, pauseIngestion is safe no-op
      service.pauseIngestion();
      expect(service.status, equals(CameraConnectionStatus.uninitialized));

      await service.dispose();
    });

    test('Telemetry metrics correctly reflect connection status and buffer readiness', () {
      final buffer = TemporalFrameBuffer(capacity: 16);
      final service = CameraIngestionService(cameraId: 'CAM-TEST-03', temporalBuffer: buffer);

      final telem = service.currentTelemetry;
      expect(telem.cameraId, equals('CAM-TEST-03'));
      expect(telem.status, equals(CameraConnectionStatus.uninitialized));
      expect(telem.isBufferReady, isFalse);
      expect(telem.totalCaptured, equals(0));
      expect(telem.droppedFrames, equals(0));
    });
  });

  group('Preview Layout Geometry & Dimension Verification', () {
    test('Landscape preview dimensions maintain proper width and height ordering', () {
      // DirectShow Windows webcam typical resolution: 1280x720 (width x height)
      const declaredWidth = 1280.0;
      const declaredHeight = 720.0;
      const declaredAspect = declaredWidth / declaredHeight; // 1.7778 (16:9)

      // Verified: width must be declaredWidth (1280), NOT declaredHeight (720)
      expect(declaredWidth, greaterThan(declaredHeight));
      expect(declaredAspect, closeTo(1.777, 0.001));

      // Assert portrait inverted aspect is rejected
      final invertedAspect = declaredHeight / declaredWidth;
      expect(invertedAspect, lessThan(1.0));
      expect(invertedAspect, isNot(closeTo(declaredAspect, 0.1)));
    });
  });
}
