// SentinelX - Camera Frame Model & Tensor Serialization
// Represents a single verified video frame captured from hardware with complete provenance metadata.
// Provides ImageNet standardization and planar tensor conversion for ONNX Runtime ingestion.

import 'package:flutter/foundation.dart';

enum CameraFrameStatus {
  valid,
  padded,
  dropped,
  corrupt,
}

@immutable
class CameraFrame {
  /// Unique identifier of the surveillance camera (e.g. 'CAM-001')
  final String cameraId;

  /// Hardware device name reported by the operating system (e.g. 'HP TrueVision HD Camera')
  final String deviceName;

  /// Monotonically increasing sequence index
  final int frameIndex;

  /// UTC Timestamp of acquisition
  final DateTime timestamp;

  /// Width in pixels (standardized to 224 for SentinelXNet)
  final int width;

  /// Height in pixels (standardized to 224 for SentinelXNet)
  final int height;

  /// Pixel format (e.g. 'RGB888')
  final String pixelFormat;

  /// Raw uncompressed RGB pixel bytes: length = width * height * 3 (150,528 bytes for 224x224)
  final Uint8List rgbBytes;

  /// Measured latency from hardware trigger to memory buffer availability
  final int acquisitionLatencyMs;

  /// High-resolution monotonic timestamp in microseconds
  final int monotonicUs;

  /// Ingestion validity status
  final CameraFrameStatus status;

  const CameraFrame({
    required this.cameraId,
    required this.deviceName,
    required this.frameIndex,
    required this.timestamp,
    required this.width,
    required this.height,
    required this.pixelFormat,
    required this.rgbBytes,
    required this.acquisitionLatencyMs,
    int? monotonicUs,
    this.status = CameraFrameStatus.valid,
  }) : monotonicUs = monotonicUs ?? 0;

  /// True size of raw byte payload in memory
  int get byteSize => rgbBytes.length;

  /// Converts RGB packed bytes [H, W, 3] into a planar Float32 tensor [3, H, W]
  /// standardized with ImageNet mean and standard deviation:
  /// mean = [0.485, 0.456, 0.406], std = [0.229, 0.224, 0.225]
  Float32List toPlanarNormalized({
    List<double> mean = const [0.485, 0.456, 0.406],
    List<double> std = const [0.229, 0.224, 0.225],
  }) {
    final channelSize = width * height;
    final tensor = Float32List(3 * channelSize);

    final rOffset = 0;
    final gOffset = channelSize;
    final bOffset = 2 * channelSize;

    final rMean = mean[0];
    final gMean = mean[1];
    final bMean = mean[2];

    final rStd = std[0];
    final gStd = std[1];
    final bStd = std[2];

    for (int i = 0; i < channelSize; i++) {
      final srcIndex = i * 3;
      if (srcIndex + 2 < rgbBytes.length) {
        final rNorm = (rgbBytes[srcIndex] / 255.0 - rMean) / rStd;
        final gNorm = (rgbBytes[srcIndex + 1] / 255.0 - gMean) / gStd;
        final bNorm = (rgbBytes[srcIndex + 2] / 255.0 - bMean) / bStd;

        tensor[rOffset + i] = rNorm;
        tensor[gOffset + i] = gNorm;
        tensor[bOffset + i] = bNorm;
      }
    }

    return tensor;
  }

  /// Creates a padded clone with an updated timestamp and frame index
  CameraFrame copyAsPadded({
    required int newIndex,
    required DateTime newTimestamp,
    int? newMonotonicUs,
  }) {
    return CameraFrame(
      cameraId: cameraId,
      deviceName: deviceName,
      frameIndex: newIndex,
      timestamp: newTimestamp,
      width: width,
      height: height,
      pixelFormat: pixelFormat,
      rgbBytes: rgbBytes,
      acquisitionLatencyMs: acquisitionLatencyMs,
      monotonicUs: newMonotonicUs ?? monotonicUs,
      status: CameraFrameStatus.padded,
    );
  }
}
