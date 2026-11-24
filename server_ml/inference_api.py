#!/usr/bin/env python3
"""
SentinelX - Python ML Inference Microservice (FastAPI)
Exposes high-throughput REST inference endpoints for multimodal urban anomaly detection.
Features:
- Genuine video decoding via OpenCV and audio Mel-spectrogram generation
- Strict PyTorch checkpoint loading (sentinelx_model.pth)
- Asynchronous CPU execution offloading to prevent blocking event loop
- UploadFile multipart and JSON base64 input ingestion
- Input size validation & temporary resource cleanup
- Origin-restricted CORS policy
"""

import os
import sys
import time
import base64
import asyncio
import logging
from pathlib import Path
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

# Add server_ml to path so imports resolve
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from fastapi import FastAPI, HTTPException, UploadFile, File, Form, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from infer import load_model, run_inference, THREAT_CLASSES, MODEL_VERSION, DEFAULT_WEIGHTS

# ─── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("sentinelx.inference_api")

# Maximum input payload size constraints (50 MB video clip, 15 MB audio)
MAX_VIDEO_BYTES = 50 * 1024 * 1024
MAX_AUDIO_BYTES = 15 * 1024 * 1024

_model_loaded = False
_active_device = "cpu"


def _ensure_model():
    """Ensure SentinelXNet model weights are loaded and verified."""
    global _model_loaded, _active_device
    if not _model_loaded:
        try:
            model = load_model(DEFAULT_WEIGHTS)
            _active_device = next(model.parameters()).device.type
            _model_loaded = True
            logger.info(f"✓ SentinelXNet loaded with strict verification on device: {_active_device}")
        except Exception as e:
            logger.error(f"Critical error loading model checkpoint: {e}")
            _model_loaded = False
    return _model_loaded


# ─── Lifespan (Startup / Shutdown) ────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing SentinelX ML Inference Microservice...")
    _ensure_model()
    yield
    logger.info("Shutting down SentinelX ML Inference Microservice...")


# ─── FastAPI Application ──────────────────────────────────────────────────────
app = FastAPI(
    title="SentinelX Multimodal ML Inference Service",
    description="Real-time spatio-temporal video and acoustic Mel-spectrogram anomaly detection",
    version=MODEL_VERSION,
    lifespan=lifespan,
)

# Enforce restricted trusted origins
allowed_origins_env = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173",
)
allowed_origins = [origin.strip() for origin in allowed_origins_env.split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


# ─── Schemas ──────────────────────────────────────────────────────────────────
class DetectRequest(BaseModel):
    camera_id: str = Field(default="CAM-001", description="Camera identifier")
    video_frames: Optional[str] = Field(
        default=None,
        description="Base64-encoded video file or video clip bytes",
    )
    audio_data: Optional[str] = Field(
        default=None,
        description="Base64-encoded WAV/PCM audio bytes",
    )
    video_path: Optional[str] = Field(
        default=None,
        description="Local path to video clip",
    )
    audio_path: Optional[str] = Field(
        default=None,
        description="Local path to audio clip",
    )


class LatencyMetrics(BaseModel):
    video_preprocess_ms: float
    audio_preprocess_ms: float
    model_inference_ms: float
    total_latency_ms: float


class DetectResponse(BaseModel):
    camera_id: str
    threat_class: str
    confidence: float
    raw_logits: List[float]
    bbox: List[float]
    class_probabilities: Dict[str, float]
    detection_status: str
    audio_present: bool
    metrics: LatencyMetrics
    device: str
    model_loaded: bool
    model_version: str


# ─── Endpoints ────────────────────────────────────────────────────────────────
@app.get("/health")
def health():
    _ensure_model()
    return {
        "status": "online",
        "model_loaded": _model_loaded,
        "device": _active_device,
        "model_version": MODEL_VERSION,
        "weights_path": str(DEFAULT_WEIGHTS),
        "weights_exist": DEFAULT_WEIGHTS.exists(),
    }


@app.get("/model/info")
def model_info():
    _ensure_model()
    return {
        "model_name": "SentinelXNet",
        "model_version": MODEL_VERSION,
        "model_loaded": _model_loaded,
        "device": _active_device,
        "num_classes": len(THREAT_CLASSES),
        "threat_classes": THREAT_CLASSES,
        "input_contracts": {
            "video": "[1, 16, 3, 224, 224] (ImageNet normalized)",
            "audio": "[1, 1, 128, 128] (16kHz 128-band Mel-spectrogram in dB)",
        },
        "output_contracts": {
            "threat_classification": "[1, 5] logits",
            "spatial_bounding_box": "[1, 4] normalized [x, y, w, h] in [0, 1]",
        },
    }


@app.post("/detect", response_model=DetectResponse)
async def detect(payload: DetectRequest):
    if not _ensure_model():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model weights not loaded or failed strict checkpoint verification.",
        )

    # 1. Resolve video source
    video_bytes: Optional[bytes] = None
    if payload.video_frames:
        try:
            video_bytes = base64.b64decode(payload.video_frames)
        except Exception as e:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid base64 video_frames: {e}")
    elif payload.video_path:
        if not os.path.exists(payload.video_path):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"video_path not found: {payload.video_path}")
        video_bytes = payload.video_path
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing required video input. Provide video_frames (base64) or video_path.",
        )

    if isinstance(video_bytes, (bytes, bytearray)) and len(video_bytes) > MAX_VIDEO_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Video payload exceeds maximum permitted size of {MAX_VIDEO_BYTES / (1024*1024):.0f} MB.",
        )

    # 2. Resolve audio source
    audio_bytes: Optional[Any] = None
    if payload.audio_data:
        try:
            audio_bytes = base64.b64decode(payload.audio_data)
        except Exception as e:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid base64 audio_data: {e}")
    elif payload.audio_path:
        if not os.path.exists(payload.audio_path):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"audio_path not found: {payload.audio_path}")
        audio_bytes = payload.audio_path

    if isinstance(audio_bytes, (bytes, bytearray)) and len(audio_bytes) > MAX_AUDIO_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Audio payload exceeds maximum permitted size of {MAX_AUDIO_BYTES / (1024*1024):.0f} MB.",
        )

    # 3. Execute inference in thread pool to prevent blocking event loop
    try:
        result = await asyncio.to_thread(
            run_inference,
            video_source=video_bytes,
            audio_source=audio_bytes,
            camera_id=payload.camera_id,
            weights_path=DEFAULT_WEIGHTS,
        )
        return result
    except ValueError as val_err:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(val_err))
    except Exception as inf_err:
        logger.error(f"Inference execution failure: {inf_err}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Inference failed: {str(inf_err)}",
        )


@app.post("/detect/upload", response_model=DetectResponse)
async def detect_upload(
    video_file: UploadFile = File(..., description="Video clip file (MP4, AVI, WebM)"),
    audio_file: Optional[UploadFile] = File(None, description="Audio file (WAV, PCM)"),
    camera_id: str = Form("CAM-001"),
):
    """Multipart form endpoint supporting direct file uploads from cameras and dashboard clients."""
    if not _ensure_model():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model weights not loaded.",
        )

    # Read and validate video file
    video_content = await video_file.read()
    if len(video_content) == 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded video file is empty.")
    if len(video_content) > MAX_VIDEO_BYTES:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Video file exceeds 50 MB limit.")

    # Read audio file if provided
    audio_content = None
    if audio_file is not None:
        audio_content = await audio_file.read()
        if len(audio_content) > MAX_AUDIO_BYTES:
            raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Audio file exceeds 15 MB limit.")

    try:
        result = await asyncio.to_thread(
            run_inference,
            video_source=video_content,
            audio_source=audio_content,
            camera_id=camera_id,
            weights_path=DEFAULT_WEIGHTS,
        )
        return result
    except ValueError as val_err:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(val_err))
    except Exception as inf_err:
        logger.error(f"Upload inference execution failure: {inf_err}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Inference failed: {str(inf_err)}",
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("inference_api:app", host="0.0.0.0", port=8000, reload=False, log_level="info")
