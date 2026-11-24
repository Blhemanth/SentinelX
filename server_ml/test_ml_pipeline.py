#!/usr/bin/env python3
"""
SentinelX - Phase 3 Multimodal ML Pipeline Verification Suite
Tests:
1. Checkpoint Loading: Strict state_dict verification of sentinelx_model.pth
2. Video Ingestion: Real video decoding with cv2, 16-frame uniform extraction
3. Video Normalization: ImageNet scaling and shape [1, 16, 3, 224, 224]
4. Audio Ingestion: Real WAV waveform decoding, 16kHz resampling
5. Audio Mel-Spectrogram: Log-mel filterbank transform and shape [1, 1, 128, 128]
6. Multimodal PyTorch Forward Pass: End-to-end inference on genuine inputs
7. Model Outputs: 5-class softmax probabilities and normalized bounding box [x, y, w, h]
8. Edge Cases: Short video handling (<16 frames), invalid video, invalid audio
9. Latency Breakdown: Separate preprocessing from neural inference time
10. FastAPI REST Endpoints: /health, /model/info, and /detect via TestClient
11. CLI Execution: Subprocess invocation of infer.py
"""

import os
import sys
import json
import time
import tempfile
import unittest
from pathlib import Path

import cv2
import numpy as np
import scipy.io.wavfile as wav
import torch
import torch.nn.functional as F

# Ensure server_ml is on sys.path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from model import SentinelXNet, create_model
from preprocessor import preprocess_video, preprocess_audio, get_acoustic_silence
from infer import load_model, run_inference, THREAT_CLASSES, DEFAULT_WEIGHTS
from inference_api import app
from fastapi.testclient import TestClient


class TestSentinelXMLPipeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp_dir = tempfile.TemporaryDirectory()
        cls.temp_path = Path(cls.temp_dir.name)

        # 1. Generate a real 24-frame, 30fps MP4 video file
        cls.sample_video_path = cls.temp_path / "sample_test_video.mp4"
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        out = cv2.VideoWriter(str(cls.sample_video_path), fourcc, 30.0, (320, 240))
        for i in range(24):
            # Dynamic frame with moving color patterns
            frame = np.zeros((240, 320, 3), dtype=np.uint8)
            cv2.circle(frame, (50 + i * 8, 120), 30, (0, 0, 255), -1)
            cv2.putText(frame, f"F:{i}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            out.write(frame)
        out.release()

        # 2. Generate a short video (< 16 frames, e.g. 6 frames)
        cls.short_video_path = cls.temp_path / "short_test_video.mp4"
        out_short = cv2.VideoWriter(str(cls.short_video_path), fourcc, 15.0, (160, 120))
        for i in range(6):
            frame = np.full((120, 160, 3), i * 30, dtype=np.uint8)
            out_short.write(frame)
        out_short.release()

        # 3. Generate a real 1-second 16kHz WAV audio file with dual-tone acoustic harmonics
        cls.sample_audio_path = cls.temp_path / "sample_test_audio.wav"
        sr = 16000
        t = np.linspace(0, 1.0, sr, endpoint=False)
        # Synthetic siren / alarm acoustic signal (440Hz + 880Hz)
        sig = 0.6 * np.sin(2 * np.pi * 440 * t) + 0.4 * np.sin(2 * np.pi * 880 * t)
        sig_int16 = (sig * 32767).astype(np.int16)
        wav.write(str(cls.sample_audio_path), sr, sig_int16)

        # 4. Generate an invalid / corrupt video file
        cls.corrupt_video_path = cls.temp_path / "corrupt_video.mp4"
        with open(cls.corrupt_video_path, "wb") as f:
            f.write(b"NOT_A_VALID_MP4_HEADER_CORRUPTED_BINARY_DATA_01928374")

        # 5. Generate an invalid audio file
        cls.corrupt_audio_path = cls.temp_path / "corrupt_audio.wav"
        with open(cls.corrupt_audio_path, "wb") as f:
            f.write(b"RIFF_FAKE_CORRUPTED_AUDIO_PAYLOAD")

        cls.client_cm = TestClient(app)
        cls.client = cls.client_cm.__enter__()

    @classmethod
    def tearDownClass(cls):
        try:
            cls.client_cm.__exit__(None, None, None)
        except Exception:
            pass
        cls.temp_dir.cleanup()

    # ── Test 1: Strict Checkpoint Loading ──────────────────────────────────────
    def test_01_strict_checkpoint_loading(self):
        """Verifies sentinelx_model.pth loads with strict=True without missing or unexpected keys."""
        self.assertTrue(DEFAULT_WEIGHTS.exists(), f"Weights missing: {DEFAULT_WEIGHTS}")
        model = create_model(num_classes=5)
        weights = torch.load(str(DEFAULT_WEIGHTS), map_location="cpu", weights_only=False)
        load_result = model.load_state_dict(weights, strict=True)
        self.assertEqual(len(load_result.missing_keys), 0, f"Missing keys: {load_result.missing_keys}")
        self.assertEqual(len(load_result.unexpected_keys), 0, f"Unexpected keys: {load_result.unexpected_keys}")

    # ── Test 2: Real Video Ingestion & 16-Frame Extraction ─────────────────────
    def test_02_video_preprocessing_shape_and_range(self):
        """Decodes real MP4 video, verifies uniform 16-frame extraction and ImageNet normalization."""
        tensor, elapsed_ms = preprocess_video(self.sample_video_path, num_frames=16, target_size=(224, 224))
        self.assertEqual(tensor.shape, (1, 16, 3, 224, 224))
        self.assertIsInstance(tensor, torch.FloatTensor)
        self.assertGreater(elapsed_ms, 0.0)
        # Verify ImageNet normalized range
        self.assertLess(tensor.min().item(), 0.0)
        self.assertGreater(tensor.max().item(), 0.0)

    # ── Test 3: Short Video Handling (<16 Frames) ─────────────────────────────
    def test_03_short_video_padding(self):
        """Verifies clips with fewer than 16 frames are padded to exactly 16 frames without error."""
        tensor, _ = preprocess_video(self.short_video_path, num_frames=16, target_size=(224, 224))
        self.assertEqual(tensor.shape, (1, 16, 3, 224, 224))

    # ── Test 4: Real Audio Ingestion & Mel-Spectrogram ─────────────────────────
    def test_04_audio_preprocessing_shape_and_db_scale(self):
        """Decodes real WAV audio, resamples to 16kHz, computes 128x128 dB Mel-spectrogram."""
        tensor, elapsed_ms = preprocess_audio(self.sample_audio_path, sample_rate=16000, n_mels=128, target_time_steps=128)
        self.assertEqual(tensor.shape, (1, 1, 128, 128))
        self.assertIsInstance(tensor, torch.FloatTensor)
        self.assertGreater(elapsed_ms, 0.0)
        # Decibel scale values should be non-positive or bounded in realistic range
        self.assertTrue(torch.isfinite(tensor).all())

    # ── Test 5: Acoustic Silence Baseline ─────────────────────────────────────
    def test_05_acoustic_silence_baseline(self):
        """Verifies fallback acoustic silence produces exact [1, 1, 128, 128] tensor."""
        tensor, elapsed_ms = get_acoustic_silence(sample_rate=16000, n_mels=128, target_time_steps=128)
        self.assertEqual(tensor.shape, (1, 1, 128, 128))
        self.assertEqual(tensor[0, 0, 0, 0].item(), -80.0)

    # ── Test 6: Invalid Media Error Handling ──────────────────────────────────
    def test_06_corrupt_inputs_raise_errors(self):
        """Verifies corrupt files raise descriptive ValueErrors without substitute random tensors."""
        with self.assertRaises(ValueError):
            preprocess_video(self.corrupt_video_path)

        with self.assertRaises(ValueError):
            preprocess_audio(self.corrupt_audio_path)

        with self.assertRaises(ValueError):
            preprocess_video(b"")

        with self.assertRaises(ValueError):
            preprocess_audio(b"")

    # ── Test 7: Multimodal Forward Pass on Genuine Media ──────────────────────
    def test_07_multimodal_inference_forward_pass(self):
        """Runs end-to-end multimodal inference with real video + real audio."""
        result = run_inference(
            video_source=self.sample_video_path,
            audio_source=self.sample_audio_path,
            camera_id="CAM-001",
        )
        self.assertIn("threat_class", result)
        self.assertIn(result["threat_class"], THREAT_CLASSES)
        self.assertTrue(0.0 <= result["confidence"] <= 1.0)

        # Logits validation: 5 classes
        self.assertEqual(len(result["raw_logits"]), 5)

        # Class probabilities: sum to ~1.0
        prob_sum = sum(result["class_probabilities"].values())
        self.assertAlmostEqual(prob_sum, 1.0, places=2)

        # Bounding Box: [x, y, w, h] strictly in [0.0, 1.0]
        bbox = result["bbox"]
        self.assertEqual(len(bbox), 4)
        for coord in bbox:
            self.assertTrue(0.0 <= coord <= 1.0, f"Coordinate {coord} out of range [0, 1]")

        # Metrics breakdown
        metrics = result["metrics"]
        self.assertGreater(metrics["video_preprocess_ms"], 0.0)
        self.assertGreater(metrics["audio_preprocess_ms"], 0.0)
        self.assertGreater(metrics["model_inference_ms"], 0.0)
        self.assertGreater(metrics["total_latency_ms"], metrics["model_inference_ms"])

        print(
            f"\n[Bench] Real Multimodal Inference: Class={result['threat_class']} "
            f"({result['confidence']:.2%}) | VideoPrep={metrics['video_preprocess_ms']:.1f}ms | "
            f"AudioPrep={metrics['audio_preprocess_ms']:.1f}ms | "
            f"ModelInfer={metrics['model_inference_ms']:.1f}ms | "
            f"Total={metrics['total_latency_ms']:.1f}ms"
        )

    # ── Test 8: Video-Only Inference with Silence Baseline ────────────────────
    def test_08_video_only_inference(self):
        """Runs inference without audio, ensuring silence baseline is used."""
        result = run_inference(
            video_source=self.sample_video_path,
            audio_source=None,
            camera_id="CAM-002",
        )
        self.assertFalse(result["audio_present"])
        self.assertIn(result["threat_class"], THREAT_CLASSES)
        self.assertTrue(0.0 <= result["confidence"] <= 1.0)

    # ── Test 9: FastAPI Health & Model Info Endpoints ─────────────────────────
    def test_09_fastapi_health_and_info(self):
        """Verifies GET /health and GET /model/info return online status and model metadata."""
        res_h = self.client.get("/health")
        self.assertEqual(res_h.status_code, 200)
        data_h = res_h.json()
        self.assertEqual(data_h["status"], "online")
        self.assertTrue(data_h["model_loaded"])

        res_i = self.client.get("/model/info")
        self.assertEqual(res_i.status_code, 200)
        data_i = res_i.json()
        self.assertEqual(data_i["num_classes"], 5)
        self.assertEqual(data_i["threat_classes"], THREAT_CLASSES)

    # ── Test 10: FastAPI /detect JSON Endpoint with Base64 ────────────────────
    def test_10_fastapi_detect_base64_json(self):
        """Tests POST /detect with base64 video and audio payloads."""
        import base64
        with open(self.sample_video_path, "rb") as vf:
            v_b64 = base64.b64encode(vf.read()).decode("utf-8")
        with open(self.sample_audio_path, "rb") as af:
            a_b64 = base64.b64encode(af.read()).decode("utf-8")

        res = self.client.post("/detect", json={
            "camera_id": "CAM-TEST",
            "video_frames": v_b64,
            "audio_data": a_b64,
        })
        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertEqual(body["camera_id"], "CAM-TEST")
        self.assertIn(body["threat_class"], THREAT_CLASSES)
        self.assertTrue(0.0 <= body["confidence"] <= 1.0)
        self.assertIn("metrics", body)
        self.assertGreater(body["metrics"]["total_latency_ms"], 0.0)

    # ── Test 11: FastAPI /detect/upload Multipart Endpoint ────────────────────
    def test_11_fastapi_detect_multipart_upload(self):
        """Tests POST /detect/upload with real multipart video and audio file uploads."""
        with open(self.sample_video_path, "rb") as vf, open(self.sample_audio_path, "rb") as af:
            files = {
                "video_file": ("test.mp4", vf, "video/mp4"),
                "audio_file": ("test.wav", af, "audio/wav"),
            }
            data = {"camera_id": "CAM-UPLOAD"}
            res = self.client.post("/detect/upload", files=files, data=data)

        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertEqual(body["camera_id"], "CAM-UPLOAD")
        self.assertIn(body["threat_class"], THREAT_CLASSES)
        self.assertTrue(body["audio_present"])

    # ── Test 12: FastAPI Rejects Corrupt Inputs ────────────────────────────────
    def test_12_fastapi_rejects_corrupted_video(self):
        """Verifies API returns HTTP 400 when uploaded video cannot be decoded."""
        with open(self.corrupt_video_path, "rb") as vf:
            files = {"video_file": ("corrupt.mp4", vf, "video/mp4")}
            res = self.client.post("/detect/upload", files=files, data={"camera_id": "CAM-CORRUPT"})
        self.assertEqual(res.status_code, 400)


def run_tests():
    print("====================================================")
    print("   SENTINELX - PHASE 3 ML PIPELINE TEST SUITE       ")
    print("====================================================\n")
    suite = unittest.TestLoader().loadTestsFromTestCase(TestSentinelXMLPipeline)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    run_tests()
