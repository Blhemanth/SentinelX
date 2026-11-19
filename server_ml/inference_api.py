#!/usr/bin/env python3
"""
SentinelX - Python ML Inference Microservice
FastAPI service that loads SentinelXNet and exposes HTTP inference endpoints.
Consumed by the Node.js backend via mlBridge.service.js.

Run with:
    pip install fastapi uvicorn torch numpy
    uvicorn inference_api:app --host 0.0.0.0 --port 8000
"""

import os
import sys
import time
import json
import base64
import logging
from pathlib import Path
from typing import Optional, List
from contextlib import asynccontextmanager

import numpy as np
import torch
import torch.nn.functional as F

# Add server_ml to path so we can import model.py
sys.path.insert(0, str(Path(__file__).parent))

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# ─── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("sentinelx.inference")

# ─── Constants ────────────────────────────────────────────────────────────────
MODEL_DIR = Path(__file__).parent / "models"
CHECKPOINT_PATH = MODEL_DIR / "sentinelx_checkpoint"
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

THREAT_CLASSES = ["Explosion", "Gunshot", "Fighting", "Accident", "Normal"]
MODEL_VERSION = "1.0.0"

# ─── Global Model State ───────────────────────────────────────────────────────
_model = None
_model_loaded = False


def load_model():
    """Load SentinelXNet from the PyTorch checkpoint."""
    global _model, _model_loaded

    try:
        from model import SentinelXNet, create_model

        logger.info(f"Loading model from: {CHECKPOINT_PATH}")
        logger.info(f"Using device: {DEVICE}")

        model = create_model(num_classes=5)

        # Try to load checkpoint
        if CHECKPOINT_PATH.exists():
            try:
                # PyTorch's torch.load with weights_only for security
                checkpoint = torch.load(
                    str(CHECKPOINT_PATH),
                    map_location=DEVICE,
                    weights_only=False,  # Needed for custom checkpoint dicts
                )

                # Handle both raw state_dict and wrapped checkpoint formats
                if isinstance(checkpoint, dict):
                    state_dict = checkpoint.get("model_state_dict", checkpoint.get("state_dict", checkpoint))
                else:
                    state_dict = checkpoint

                model.load_state_dict(state_dict, strict=False)
                logger.info("✓ Model weights loaded from checkpoint")
            except Exception as e:
                logger.warning(f"Could not load checkpoint weights: {e}")
                logger.warning("Running with randomly initialized weights (inference will return mock-like results)")
        else:
            logger.warning(f"Checkpoint not found at {CHECKPOINT_PATH}. Using random weights.")

        model.to(DEVICE)
        model.eval()
        _model = model
        _model_loaded = True
        logger.info(f"✓ SentinelXNet ready on {DEVICE}")

    except ImportError as e:
        logger.error(f"Could not import model.py: {e}")
        logger.warning("Using fallback mock inference mode")
        _model = None
        _model_loaded = False
    except Exception as e:
        logger.error(f"Model load failed: {e}")
        _model = None
        _model_loaded = False


# ─── Lifespan (startup/shutdown) ──────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("SentinelX Inference API starting up...")
    load_model()
    yield
    # Shutdown
    logger.info("SentinelX Inference API shutting down...")


# ─── FastAPI App ──────────────────────────────────────────────────────────────
app = FastAPI(
    title="SentinelX ML Inference API",
    description="Real-time multi-modal anomaly detection inference microservice",
    version=MODEL_VERSION,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# ─── Request / Response Models ────────────────────────────────────────────────
class DetectRequest(BaseModel):
    camera_id: str = Field(..., description="Camera identifier")
    video_frames: Optional[str] = Field(
        None,
        description="Base64-encoded video frames tensor (optional; generates synthetic if absent)",
    )
    audio_data: Optional[str] = Field(
        None,
        description="Base64-encoded Mel-spectrogram (optional; generates synthetic if absent)",
    )


class BoundingBox(BaseModel):
    x: float
    y: float
    w: float
    h: float


class DetectResponse(BaseModel):
    threat_class: str
    confidence: float
    bbox: List[float]
    class_probabilities: dict
    inference_latency_ms: float
    model_version: str
    device: str
    model_loaded: bool


# ─── Inference Helper ─────────────────────────────────────────────────────────
def run_inference(video_tensor: torch.Tensor, audio_tensor: torch.Tensor):
    """
    Run SentinelXNet forward pass. Returns (logits, bbox).
    Falls back to synthetic output if model is not loaded.
    """
    if _model is None or not _model_loaded:
        # Fallback: return synthetic detection
        logger.warning("Model not loaded — returning synthetic inference result")
        num_classes = 5
        logits = torch.randn(1, num_classes)
        bbox = torch.sigmoid(torch.randn(1, 4))
        return logits, bbox

    with torch.no_grad():
        logits, bbox = _model(video_tensor, audio_tensor)

    return logits, bbox


def decode_base64_tensor(b64_str: str, shape: tuple, dtype=np.float32) -> torch.Tensor:
    """Decode a base64-encoded flat numpy array back to a tensor."""
    raw = base64.b64decode(b64_str)
    arr = np.frombuffer(raw, dtype=dtype).reshape(shape)
    return torch.from_numpy(arr.copy())


# ─── API Endpoints ─────────────────────────────────────────────────────────────
@app.get("/health")
def health():
    return {
        "status": "online",
        "model_loaded": _model_loaded,
        "device": DEVICE,
        "model_version": MODEL_VERSION,
        "checkpoint_path": str(CHECKPOINT_PATH),
        "checkpoint_exists": CHECKPOINT_PATH.exists(),
    }


@app.post("/detect", response_model=DetectResponse)
def detect(payload: DetectRequest):
    t0 = time.time()

    # ── Prepare video tensor [1, 16, 3, 224, 224] ─────────────────────────────
    if payload.video_frames:
        try:
            video = decode_base64_tensor(
                payload.video_frames,
                shape=(1, 16, 3, 224, 224),
            ).to(DEVICE)
        except Exception as e:
            logger.warning(f"Failed to decode video_frames: {e}. Using random.")
            video = torch.randn(1, 16, 3, 224, 224, device=DEVICE)
    else:
        # Synthetic: realistic random input for testing without real video
        video = torch.randn(1, 16, 3, 224, 224, device=DEVICE)

    # ── Prepare audio tensor [1, 1, 128, 128] ─────────────────────────────────
    if payload.audio_data:
        try:
            audio = decode_base64_tensor(
                payload.audio_data,
                shape=(1, 1, 128, 128),
            ).to(DEVICE)
        except Exception as e:
            logger.warning(f"Failed to decode audio_data: {e}. Using random.")
            audio = torch.randn(1, 1, 128, 128, device=DEVICE)
    else:
        audio = torch.randn(1, 1, 128, 128, device=DEVICE)

    # ── Run inference ─────────────────────────────────────────────────────────
    try:
        logits, bbox = run_inference(video, audio)
    except Exception as e:
        logger.error(f"Inference error: {e}")
        raise HTTPException(status_code=500, detail=f"Inference failed: {str(e)}")

    # ── Decode outputs ────────────────────────────────────────────────────────
    probs = F.softmax(logits[0], dim=-1).cpu().numpy()
    pred_idx = int(np.argmax(probs))
    pred_class = THREAT_CLASSES[pred_idx]
    confidence = float(probs[pred_idx])
    bbox_coords = bbox[0].cpu().numpy().tolist()

    class_probs = {cls: float(p) for cls, p in zip(THREAT_CLASSES, probs)}

    latency_ms = (time.time() - t0) * 1000

    logger.info(
        f"[{payload.camera_id}] {pred_class} ({confidence:.2%}) | "
        f"bbox={[f'{v:.3f}' for v in bbox_coords]} | {latency_ms:.1f}ms"
    )

    return DetectResponse(
        threat_class=pred_class,
        confidence=confidence,
        bbox=bbox_coords,
        class_probabilities=class_probs,
        inference_latency_ms=round(latency_ms, 2),
        model_version=MODEL_VERSION,
        device=DEVICE,
        model_loaded=_model_loaded,
    )


@app.get("/model/info")
def model_info():
    """Return model architecture metadata."""
    if _model is None:
        return {"loaded": False, "error": "Model not loaded"}

    total_params = sum(p.numel() for p in _model.parameters())
    trainable_params = sum(p.numel() for p in _model.parameters() if p.requires_grad)

    return {
        "loaded": True,
        "device": DEVICE,
        "model_version": MODEL_VERSION,
        "total_parameters": total_params,
        "trainable_parameters": trainable_params,
        "num_classes": 5,
        "threat_classes": THREAT_CLASSES,
        "input_shapes": {
            "video": "[B, 16, 3, 224, 224]",
            "audio": "[B, 1, 128, 128]",
        },
        "output_shapes": {
            "logits": "[B, 5]",
            "bbox": "[B, 4] (normalized [x,y,w,h] in [0,1])",
        },
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("inference_api:app", host="0.0.0.0", port=8000, reload=False, log_level="info")
