#!/usr/bin/env python3
"""
SentinelX - Python CLI Multimodal Inference Engine
Loads PyTorch weights from server_ml/models/sentinelx_model.pth with strict validation,
decodes genuine video and audio inputs via preprocessor.py, and executes
the SentinelXNet forward pass. Emits structured JSON on stdout.
"""

import os
import sys
import json
import time
import base64
import argparse
from pathlib import Path
from typing import Dict, Any, Optional

import torch
import torch.nn.functional as F
import numpy as np

# Add server_ml to sys.path so relative imports work regardless of working directory
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from model import SentinelXNet, create_model
from preprocessor import preprocess_video, preprocess_audio, get_acoustic_silence

DEFAULT_WEIGHTS = BASE_DIR / "models" / "sentinelx_model.pth"
THREAT_CLASSES = ["Explosion", "Gunshot", "Fighting", "Accident", "Normal"]
MODEL_VERSION = "1.0.0"

_CACHED_MODEL: Optional[SentinelXNet] = None
_CACHED_DEVICE: Optional[str] = None


def get_device() -> str:
    return "cuda" if torch.cuda.is_available() else "cpu"


def load_model(weights_path: Optional[Path] = None, device: Optional[str] = None) -> SentinelXNet:
    """
    Load SentinelXNet with strict checkpoint verification.
    Preserves existing trained weights without random fallback.
    """
    global _CACHED_MODEL, _CACHED_DEVICE

    if device is None:
        device = get_device()

    if _CACHED_MODEL is not None and _CACHED_DEVICE == device:
        return _CACHED_MODEL

    weights = weights_path or DEFAULT_WEIGHTS
    if not weights.exists():
        raise FileNotFoundError(
            f"Required PyTorch checkpoint not found at: {weights}. "
            f"Strict checkpoint loading requires valid .pth weights."
        )

    model = create_model(num_classes=5)
    checkpoint = torch.load(str(weights), map_location=device, weights_only=False)

    if isinstance(checkpoint, dict):
        state_dict = checkpoint.get("model_state_dict", checkpoint.get("state_dict", checkpoint))
    else:
        state_dict = checkpoint

    # Strict state_dict verification
    model.load_state_dict(state_dict, strict=True)
    model.to(device)
    model.eval()

    _CACHED_MODEL = model
    _CACHED_DEVICE = device
    return model


def run_inference(
    video_source: Any,
    audio_source: Optional[Any] = None,
    camera_id: str = "CAM-001",
    weights_path: Optional[Path] = None,
) -> Dict[str, Any]:
    """
    Execute end-to-end multimodal inference on genuine video and audio inputs.
    
    Returns structured results with separate video, audio, model, and total latencies.
    No simulated fallbacks or artificial Normal overwrites.
    """
    t_start = time.perf_counter()
    device = get_device()
    model = load_model(weights_path=weights_path, device=device)

    # 1. Preprocess Video
    video_tensor, video_prep_ms = preprocess_video(video_source, num_frames=16, target_size=(224, 224))
    video_tensor = video_tensor.to(device)

    # 2. Preprocess Audio (or calibrated acoustic silence baseline)
    if audio_source is not None:
        audio_tensor, audio_prep_ms = preprocess_audio(audio_source, sample_rate=16000, n_mels=128, target_time_steps=128)
        audio_present = True
    else:
        audio_tensor, audio_prep_ms = get_acoustic_silence(sample_rate=16000, n_mels=128, target_time_steps=128)
        audio_present = False

    audio_tensor = audio_tensor.to(device)

    # 3. Model Forward Pass
    t_inf_start = time.perf_counter()
    with torch.no_grad():
        logits, bbox = model(video_tensor, audio_tensor)
    inference_ms = (time.perf_counter() - t_inf_start) * 1000.0

    # 4. Probabilities & Outputs
    raw_logits_list = [round(float(v), 4) for v in logits[0].cpu().numpy()]
    probs = F.softmax(logits[0], dim=-1).cpu().numpy()
    pred_idx = int(probs.argmax())
    pred_class = THREAT_CLASSES[pred_idx]
    confidence = float(probs[pred_idx])

    # Normalized Bounding Box Coordinates [x, y, w, h] strictly in [0.0, 1.0]
    bbox_coords = [round(float(np.clip(v, 0.0, 1.0)), 4) for v in bbox[0].cpu().numpy()]

    class_probs = {cls: round(float(p), 4) for cls, p in zip(THREAT_CLASSES, probs)}

    # Detection status classification (no fabricated Normal overrides)
    if pred_class != "Normal" and confidence >= 0.50:
        detection_status = "anomaly_detected"
    elif pred_class == "Normal":
        detection_status = "normal"
    else:
        detection_status = "low_confidence_review"

    total_latency_ms = (time.perf_counter() - t_start) * 1000.0

    return {
        "camera_id": camera_id,
        "threat_class": pred_class,
        "confidence": round(confidence, 4),
        "raw_logits": raw_logits_list,
        "bbox": bbox_coords,
        "class_probabilities": class_probs,
        "detection_status": detection_status,
        "audio_present": audio_present,
        "metrics": {
            "video_preprocess_ms": round(video_prep_ms, 2),
            "audio_preprocess_ms": round(audio_prep_ms, 2),
            "model_inference_ms": round(inference_ms, 2),
            "total_latency_ms": round(total_latency_ms, 2),
        },
        "device": device,
        "model_loaded": True,
        "model_version": MODEL_VERSION,
        "weights_path": str(weights_path or DEFAULT_WEIGHTS),
    }


def main():
    parser = argparse.ArgumentParser(description="SentinelX CLI Multimodal ML Inference")
    parser.add_argument("--video", type=str, default=None, help="Path to input video file")
    parser.add_argument("--audio", type=str, default=None, help="Path to input audio file")
    parser.add_argument("--camera_id", type=str, default="CAM-001", help="Camera identifier")
    parser.add_argument("--weights", type=str, default=str(DEFAULT_WEIGHTS), help="Path to .pth model weights")
    parser.add_argument("--json_input", type=str, default=None, help="JSON input string (supports base64 frames/audio)")
    args = parser.parse_args()

    video_input = args.video
    audio_input = args.audio
    camera_id = args.camera_id
    weights_path = Path(args.weights)

    raw_json = None
    if args.json_input:
        if args.json_input == "-":
            raw_json = sys.stdin.read()
        else:
            raw_json = args.json_input
    elif not sys.stdin.isatty():
        piped = sys.stdin.read().strip()
        if piped:
            raw_json = piped

    if raw_json:
        try:
            payload = json.loads(raw_json)
            camera_id = payload.get("camera_id", camera_id)
            if "video_frames" in payload and payload["video_frames"]:
                # Decode base64 video payload
                video_input = base64.b64decode(payload["video_frames"])
            elif "video_path" in payload:
                video_input = payload["video_path"]

            if "audio_data" in payload and payload["audio_data"]:
                audio_input = base64.b64decode(payload["audio_data"])
            elif "audio_path" in payload:
                audio_input = payload["audio_path"]
        except Exception as e:
            error_res = {
                "error": f"Failed to parse JSON input payload: {e}",
                "model_loaded": False,
            }
            print(json.dumps(error_res))
            sys.exit(1)

    if not video_input:
        error_res = {
            "error": "Missing required video input (--video or --json_input with video_frames)",
            "model_loaded": False,
        }
        print(json.dumps(error_res))
        sys.exit(1)

    try:
        result = run_inference(
            video_source=video_input,
            audio_source=audio_input,
            camera_id=camera_id,
            weights_path=weights_path,
        )
        print(json.dumps(result))
    except Exception as e:
        error_res = {
            "error": f"Inference pipeline execution error: {e}",
            "model_loaded": False,
        }
        print(json.dumps(error_res))
        sys.exit(1)


if __name__ == "__main__":
    main()
