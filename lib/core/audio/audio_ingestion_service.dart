// SentinelX - Microphone Audio Ingestion Service
// Real-time hardware microphone acquisition, PCM16 stream ingestion, and temporal ring buffer integration.
// Features: hardware discovery, permission checks, pause/resume, bounded memory, and live telemetry.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'temporal_audio_buffer.dart';
import 'package:sentinel_x/core/utils/monotonic_clock.dart';

enum AudioConnectionStatus {
  uninitialized,
  initializing,
  connected,
  streaming,
  paused,
  disconnected,
  permissionDenied,
  noDeviceFound,
  error,
  disposed,
}

@immutable
class AudioTelemetry {
  final AudioConnectionStatus status;
  final String deviceName;
  final String deviceId;
  final int sampleRate;
  final int channels;
  final double currentDbLevel;
  final double currentRmsVolume;
  final int totalSamplesIngested;
  final int bufferCount;
  final int bufferCapacity;
  final double bufferFillPercentage;
  final bool isBufferReady;
  final int initializationTimeMs;
  final String? errorMessage;
  final DateTime timestamp;

  const AudioTelemetry({
    required this.status,
    required this.deviceName,
    required this.deviceId,
    required this.sampleRate,
    required this.channels,
    required this.currentDbLevel,
    required this.currentRmsVolume,
    required this.totalSamplesIngested,
    required this.bufferCount,
    required this.bufferCapacity,
    required this.bufferFillPercentage,
    required this.isBufferReady,
    required this.initializationTimeMs,
    this.errorMessage,
    required this.timestamp,
  });

  /// Explicit alias for decibels relative to full scale (dBFS <= 0.0)
  double get currentDbFs => currentDbLevel;

  /// Digital silence threshold (-75.0 dBFS or lower)
  bool get isDigitalSilence => currentDbLevel <= -75.0;

  /// Ambient quiet background noise (-75.0 to -40.0 dBFS)
  bool get isAmbientQuiet => currentDbLevel > -75.0 && currentDbLevel <= -40.0;

  /// Conversational speech (-40.0 to -18.0 dBFS)
  bool get isSpeechNormal => currentDbLevel > -40.0 && currentDbLevel <= -18.0;

  /// Acoustic peak (> -18.0 dBFS)
  bool get isAcousticPeak => currentDbLevel > -18.0;

  /// Human-readable acoustic categorization
  String get acousticStateLabel {
    if (isDigitalSilence) return 'DIGITAL SILENCE (-80 dBFS baseline)';
    if (isAmbientQuiet) return 'AMBIENT ROOM NOISE';
    if (isSpeechNormal) return 'CONVERSATIONAL SPEECH';
    return 'ACOUSTIC SPIKE / PEAK';
  }

  factory AudioTelemetry.initial({String deviceId = 'default'}) {
    return AudioTelemetry(
      status: AudioConnectionStatus.uninitialized,
      deviceName: 'Unknown Audio Device',
      deviceId: deviceId,
      sampleRate: 16000,
      channels: 1,
      currentDbLevel: -100.0,
      currentRmsVolume: 0.0,
      totalSamplesIngested: 0,
      bufferCount: 0,
      bufferCapacity: TemporalAudioBuffer.defaultCapacity,
      bufferFillPercentage: 0.0,
      isBufferReady: false,
      initializationTimeMs: 0,
      timestamp: DateTime.now().toUtc(),
    );
  }

  @override
  String toString() =>
      'AudioTelemetry(status: $status, device: $deviceName, ready: $isBufferReady, dB: ${currentDbLevel.toStringAsFixed(1)})';
}

class AudioIngestionService {
  AudioRecorder? _injectedRecorder;
  AudioRecorder get _recorder => _injectedRecorder ??= AudioRecorder();
  final TemporalAudioBuffer temporalBuffer;
  final int targetSampleRate;

  AudioConnectionStatus _status = AudioConnectionStatus.uninitialized;
  AudioConnectionStatus get status => _status;

  String _deviceName = 'Unknown Audio Device';
  String get deviceName => _deviceName;

  String _deviceId = 'default';
  String get deviceId => _deviceId;

  int _initializationTimeMs = 0;
  StreamSubscription<Uint8List>? _streamSubscription;

  final StreamController<AudioTelemetry> _telemetryStreamController =
      StreamController<AudioTelemetry>.broadcast();
  Stream<AudioTelemetry> get telemetryStream => _telemetryStreamController.stream;

  final StreamController<Uint8List> _rawByteStreamController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get rawByteStream => _rawByteStreamController.stream;

  AudioTelemetry _currentTelemetry;
  AudioTelemetry get currentTelemetry => _currentTelemetry;

  bool get isBufferReady => temporalBuffer.isReady;
  int get totalSamplesIngested => temporalBuffer.totalIngested;
  AudioWindowMetadata get windowMetadata => temporalBuffer.getWindowMetadata();

  AudioIngestionService({
    AudioRecorder? recorder,
    TemporalAudioBuffer? temporalBuffer,
    this.targetSampleRate = 16000,
  })  : _injectedRecorder = recorder,
        temporalBuffer = temporalBuffer ?? TemporalAudioBuffer(),
        _currentTelemetry = AudioTelemetry.initial();

  /// Discovers audio input devices and initializes microphone access.
  Future<bool> initialize({
    String? targetDeviceId,
    List<InputDevice>? injectedDevices,
    bool? injectedHasPermission,
  }) async {
    _status = AudioConnectionStatus.initializing;
    _emitTelemetry();

    final initSw = Stopwatch()..start();

    try {
      final hasPerm = injectedHasPermission ?? await _recorder.hasPermission();
      if (!hasPerm) {
        _status = AudioConnectionStatus.permissionDenied;
        initSw.stop();
        _initializationTimeMs = initSw.elapsedMilliseconds;
        _emitTelemetry(error: 'Microphone permission denied by operating system.');
        return false;
      }

      final devices = injectedDevices ?? await _recorder.listInputDevices();
      if (devices.isEmpty) {
        _status = AudioConnectionStatus.noDeviceFound;
        initSw.stop();
        _initializationTimeMs = initSw.elapsedMilliseconds;
        _emitTelemetry(error: 'No hardware microphone device detected.');
        return false;
      }

      InputDevice selectedDevice = devices.first;
      if (targetDeviceId != null) {
        final match = devices.where((d) => d.id == targetDeviceId);
        if (match.isNotEmpty) {
          selectedDevice = match.first;
        }
      }

      _deviceId = selectedDevice.id;
      _deviceName = selectedDevice.label.isNotEmpty
          ? selectedDevice.label
          : 'Default Microphone (${selectedDevice.id})';

      initSw.stop();
      _initializationTimeMs = initSw.elapsedMilliseconds;
      _status = AudioConnectionStatus.connected;
      _emitTelemetry();
      return true;
    } catch (e) {
      initSw.stop();
      _initializationTimeMs = initSw.elapsedMilliseconds;
      _status = AudioConnectionStatus.error;
      _emitTelemetry(error: 'Microphone initialization exception: $e');
      return false;
    }
  }

  /// Begins real-time streaming of PCM16 audio at 16,000 Hz mono.
  Future<bool> startStreaming({RecordConfig? config}) async {
    if (_status == AudioConnectionStatus.streaming) return true;

    if (_status == AudioConnectionStatus.uninitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    if (_status != AudioConnectionStatus.connected &&
        _status != AudioConnectionStatus.paused) {
      debugPrint('[AudioIngestionService] Cannot start streaming in status $_status');
      return false;
    }

    try {
      final recordConfig = config ??
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          );

      final stream = await _recorder.startStream(recordConfig);

      await _streamSubscription?.cancel();
      _streamSubscription = stream.listen(
        (Uint8List chunk) {
          final monoNow = MonotonicClock.now();
          temporalBuffer.pushPcm16Bytes(
            chunk,
            captureTime: monoNow.utc,
            monotonicUs: monoNow.monotonicUs,
          );
          if (!_rawByteStreamController.isClosed) {
            _rawByteStreamController.add(chunk);
          }
          _emitTelemetry();
        },
        onError: (Object err) {
          _status = AudioConnectionStatus.error;
          _emitTelemetry(error: 'Audio stream listener error: $err');
        },
        onDone: () {
          if (_status == AudioConnectionStatus.streaming) {
            _status = AudioConnectionStatus.disconnected;
            _emitTelemetry();
          }
        },
      );

      _status = AudioConnectionStatus.streaming;
      _emitTelemetry();
      return true;
    } catch (e) {
      _status = AudioConnectionStatus.error;
      _emitTelemetry(error: 'Failed to start microphone stream: $e');
      return false;
    }
  }

  /// Pauses audio streaming while retaining device connection and buffer contents.
  Future<void> pause() async {
    if (_status == AudioConnectionStatus.streaming) {
      try {
        await _recorder.pause();
        _status = AudioConnectionStatus.paused;
        _emitTelemetry();
      } catch (e) {
        _status = AudioConnectionStatus.error;
        _emitTelemetry(error: 'Failed to pause audio recording: $e');
      }
    }
  }

  /// Resumes audio streaming from paused state.
  Future<void> resume() async {
    if (_status == AudioConnectionStatus.paused) {
      try {
        await _recorder.resume();
        _status = AudioConnectionStatus.streaming;
        _emitTelemetry();
      } catch (e) {
        _status = AudioConnectionStatus.error;
        _emitTelemetry(error: 'Failed to resume audio recording: $e');
      }
    }
  }

  /// Stops audio streaming and releases the microphone hardware stream.
  Future<void> stopStreaming() async {
    if (_status == AudioConnectionStatus.streaming ||
        _status == AudioConnectionStatus.paused) {
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      try {
        await _recorder.stop();
      } catch (e) {
        debugPrint('[AudioIngestionService] Stop error: $e');
      }
      _status = AudioConnectionStatus.connected;
      _emitTelemetry();
    }
  }

  /// Extracts the most recent [numSamples] (default: 64,000 / 4.0s) in chronological order.
  Float32List extractSnapshot([int? numSamples]) {
    return temporalBuffer.extractSnapshot(numSamples);
  }

  /// Wipes all samples and resets the ring buffer.
  void clearBuffer() {
    temporalBuffer.clear();
    _emitTelemetry();
  }

  void _emitTelemetry({String? error}) {
    final bufferTelem = temporalBuffer.getTelemetry();

    final telem = AudioTelemetry(
      status: _status,
      deviceName: _deviceName,
      deviceId: _deviceId,
      sampleRate: targetSampleRate,
      channels: 1,
      currentDbLevel: bufferTelem.currentDbLevel,
      currentRmsVolume: bufferTelem.currentRmsVolume,
      totalSamplesIngested: bufferTelem.totalSamplesIngested,
      bufferCount: bufferTelem.currentBufferLength,
      bufferCapacity: bufferTelem.bufferCapacity,
      bufferFillPercentage: bufferTelem.bufferFillPercentage,
      isBufferReady: bufferTelem.isReady,
      initializationTimeMs: _initializationTimeMs,
      errorMessage: error,
      timestamp: DateTime.now().toUtc(),
    );

    _currentTelemetry = telem;
    if (!_telemetryStreamController.isClosed) {
      _telemetryStreamController.add(telem);
    }
  }

  /// Disposes microphone hardware resources, streams, and timers.
  Future<void> dispose() async {
    if (_status == AudioConnectionStatus.disposed) return;

    await _streamSubscription?.cancel();
    _streamSubscription = null;

    try {
      await _injectedRecorder?.stop();
    } catch (_) {}

    try {
      await _injectedRecorder?.dispose();
    } catch (_) {}

    _status = AudioConnectionStatus.disposed;
    _emitTelemetry();

    await _telemetryStreamController.close();
    await _rawByteStreamController.close();
  }
}
