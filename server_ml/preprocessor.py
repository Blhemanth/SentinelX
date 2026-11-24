#!/usr/bin/env python3
"""
SentinelX - High-Performance Audio-Visual Preprocessor
Extracts and normalizes multi-modal inputs for SentinelXNet:
1. Video: Decodes 16 frames via OpenCV, resizes to 224x224, converts BGR->RGB,
   normalizes with ImageNet statistics, outputs [1, 16, 3, 224, 224].
2. Audio: Decodes WAV/PCM waveform, downmixes to mono, resamples to 16kHz,
   computes 128-band Mel-spectrogram, log-decibel scaling, outputs [1, 1, 128, 128].
"""

import os
import io
import time
import tempfile
from pathlib import Path
from typing import Tuple, Optional, Union

import cv2
import numpy as np
import scipy.io.wavfile as wav
import scipy.signal
import torch
import torch.nn.functional as F
import torchaudio

# ImageNet normalization statistics
IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32).reshape(1, 3, 1, 1)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32).reshape(1, 3, 1, 1)


# ─────────────────────────────────────────────────────────────────────────────
# 1. VIDEO PREPROCESSING PIPELINE
# ─────────────────────────────────────────────────────────────────────────────

def preprocess_video(
    source: Union[str, Path, bytes, io.BytesIO],
    num_frames: int = 16,
    target_size: Tuple[int, int] = (224, 224),
) -> Tuple[torch.Tensor, float]:
    """
    Decodes real video input and prepares a normalized 5D spatio-temporal tensor.
    
    Args:
        source: File path, Path object, or raw video bytes (MP4, AVI, WebM).
        num_frames: Number of temporal frames to extract (default: 16).
        target_size: Spatial dimensions (height, width) (default: 224, 224).
        
    Returns:
        (video_tensor, elapsed_ms):
            video_tensor: FloatTensor of shape [1, 16, 3, 224, 224]
            elapsed_ms: Preprocessing latency in milliseconds
            
    Raises:
        ValueError: If video is corrupt, empty, or cannot be decoded.
    """
    t0 = time.perf_counter()
    temp_path = None

    try:
        # If source is bytes or BytesIO, write to a temporary file for OpenCV decoding
        if isinstance(source, (bytes, bytearray)):
            if len(source) == 0:
                raise ValueError("Video input byte stream is empty (0 bytes).")
            with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tf:
                tf.write(source)
                temp_path = tf.name
            video_path = temp_path
        elif isinstance(source, io.BytesIO):
            source.seek(0)
            data = source.read()
            if len(data) == 0:
                raise ValueError("Video BytesIO stream is empty.")
            with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tf:
                tf.write(data)
                temp_path = tf.name
            video_path = temp_path
        else:
            video_path = str(source)
            if not os.path.exists(video_path):
                raise FileNotFoundError(f"Video file not found: {video_path}")
            if os.path.getsize(video_path) == 0:
                raise ValueError(f"Video file is empty (0 bytes): {video_path}")

        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            raise ValueError(f"OpenCV could not open video stream or codec is unsupported: {video_path}")

        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        raw_frames = []

        if total_frames > 0:
            # Uniform temporal sampling across video duration
            indices = np.linspace(0, max(0, total_frames - 1), num_frames, dtype=int)
            for idx in indices:
                cap.set(cv2.CAP_PROP_POS_FRAMES, int(idx))
                ret, frame = cap.read()
                if ret and frame is not None:
                    raw_frames.append(frame)
        else:
            # Stream or container without frame count; read sequentially
            while len(raw_frames) < num_frames * 2:
                ret, frame = cap.read()
                if not ret or frame is None:
                    break
                raw_frames.append(frame)

        cap.release()

        if len(raw_frames) == 0:
            raise ValueError(f"Failed to decode any valid video frames from input: {video_path}")

        # Handle clips with fewer than num_frames (pad by repeating last frame)
        if len(raw_frames) < num_frames:
            while len(raw_frames) < num_frames:
                raw_frames.append(raw_frames[-1].copy())
        elif len(raw_frames) > num_frames:
            # Resample to exactly num_frames
            step_indices = np.linspace(0, len(raw_frames) - 1, num_frames, dtype=int)
            raw_frames = [raw_frames[i] for i in step_indices]

        # Convert BGR -> RGB, resize to 224x224, and convert to CHW layout
        processed = []
        for frame in raw_frames:
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            resized = cv2.resize(rgb, target_size, interpolation=cv2.INTER_LINEAR)
            chw = np.transpose(resized, (2, 0, 1))  # [3, 224, 224]
            processed.append(chw)

        # Shape: [16, 3, 224, 224] normalized to [0..1]
        clip_np = np.stack(processed, axis=0).astype(np.float32) / 255.0

        # Apply ImageNet standardization: (x - mean) / std
        normalized = (clip_np - IMAGENET_MEAN) / IMAGENET_STD

        # Shape: [1, 16, 3, 224, 224]
        video_tensor = torch.from_numpy(normalized).float().unsqueeze(0)

        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        return video_tensor, elapsed_ms

    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                pass


# ─────────────────────────────────────────────────────────────────────────────
# 2. AUDIO PREPROCESSING PIPELINE
# ─────────────────────────────────────────────────────────────────────────────

def preprocess_audio(
    source: Union[str, Path, bytes, io.BytesIO, np.ndarray],
    sample_rate: int = 16000,
    n_mels: int = 128,
    target_time_steps: int = 128,
) -> Tuple[torch.Tensor, float]:
    """
    Decodes real audio input and prepares a normalized 128x128 Mel-spectrogram tensor.
    
    Args:
        source: Audio file path, bytes, BytesIO, or numpy waveform array.
        sample_rate: Target sample rate in Hz (default: 16000).
        n_mels: Number of Mel frequency bands (default: 128).
        target_time_steps: Number of temporal slices (default: 128).
        
    Returns:
        (audio_tensor, elapsed_ms):
            audio_tensor: FloatTensor of shape [1, 1, 128, 128]
            elapsed_ms: Preprocessing latency in milliseconds
            
    Raises:
        ValueError: If audio is corrupt, empty, or cannot be decoded.
    """
    t0 = time.perf_counter()
    temp_path = None

    try:
        in_sr = sample_rate
        waveform = None

        if isinstance(source, np.ndarray):
            waveform = source.astype(np.float32)
        else:
            # Handle bytes / file input
            if isinstance(source, (bytes, bytearray)):
                if len(source) == 0:
                    raise ValueError("Audio input byte stream is empty (0 bytes).")
                with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
                    tf.write(source)
                    temp_path = tf.name
                audio_path = temp_path
            elif isinstance(source, io.BytesIO):
                source.seek(0)
                data = source.read()
                if len(data) == 0:
                    raise ValueError("Audio BytesIO stream is empty.")
                with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
                    tf.write(data)
                    temp_path = tf.name
                audio_path = temp_path
            else:
                audio_path = str(source)
                if not os.path.exists(audio_path):
                    raise FileNotFoundError(f"Audio file not found: {audio_path}")
                if os.path.getsize(audio_path) == 0:
                    raise ValueError(f"Audio file is empty (0 bytes): {audio_path}")

            # Read PCM WAV using scipy.io.wavfile (standard, fast, zero C++ codec dependency)
            try:
                in_sr, raw_audio = wav.read(audio_path)
            except Exception as read_err:
                raise ValueError(f"Failed to read WAV audio header/samples from {audio_path}: {read_err}")

            if raw_audio.size == 0:
                raise ValueError("Decoded audio contains 0 samples.")

            # Normalize integer formats to [-1.0, 1.0] float32
            if raw_audio.dtype == np.int16:
                waveform = raw_audio.astype(np.float32) / 32768.0
            elif raw_audio.dtype == np.int32:
                waveform = raw_audio.astype(np.float32) / 2147483648.0
            elif raw_audio.dtype == np.uint8:
                waveform = (raw_audio.astype(np.float32) - 128.0) / 128.0
            else:
                waveform = raw_audio.astype(np.float32)

        # Downmix multi-channel audio to mono
        if waveform.ndim > 1:
            waveform = np.mean(waveform, axis=-1)

        # Resample to 16,000 Hz if necessary
        if in_sr != sample_rate and len(waveform) > 0:
            num_resampled = int(len(waveform) * sample_rate / in_sr)
            waveform = scipy.signal.resample(waveform, max(1, num_resampled)).astype(np.float32)

        # Convert to torch.FloatTensor [1, N_samples]
        wf_tensor = torch.from_numpy(waveform).float().unsqueeze(0)

        # Compute Mel-spectrogram: n_fft=1024, hop_length=512, n_mels=128
        mel_transform = torchaudio.transforms.MelSpectrogram(
            sample_rate=sample_rate,
            n_fft=1024,
            hop_length=512,
            n_mels=n_mels,
            power=2.0,
        )
        mel_spec = mel_transform(wf_tensor)  # [1, 128, T]

        # Convert power to decibels (log scale)
        mel_db = torchaudio.transforms.AmplitudeToDB(top_db=80.0)(mel_spec)

        # Normalize time dimension to exactly target_time_steps (128)
        cur_time = mel_db.shape[-1]
        if cur_time < target_time_steps:
            pad_len = target_time_steps - cur_time
            # Pad with minimum dB value to represent silence
            min_val = float(mel_db.min().item()) if mel_db.numel() > 0 else -80.0
            mel_db = F.pad(mel_db, (0, pad_len), mode="constant", value=min_val)
        else:
            mel_db = mel_db[:, :, :target_time_steps]

        # Final audio tensor shape: [1, 1, 128, 128]
        audio_tensor = mel_db.unsqueeze(0)

        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        return audio_tensor, elapsed_ms

    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                pass


def get_acoustic_silence(
    sample_rate: int = 16000,
    n_mels: int = 128,
    target_time_steps: int = 128,
) -> Tuple[torch.Tensor, float]:
    """
    Produces a standard calibrated acoustic silence baseline tensor [1, 1, 128, 128].
    Used when evaluating video-only feeds without active microphone audio.
    """
    t0 = time.perf_counter()
    # Baseline acoustic silence at -80 dB
    silence = torch.full((1, 1, n_mels, target_time_steps), -80.0, dtype=torch.float32)
    elapsed_ms = (time.perf_counter() - t0) * 1000.0
    return silence, elapsed_ms
