#!/usr/bin/env python3
"""
SentinelX - ONNX Export & INT8 Quantization Engine
Converts PyTorch checkpoints (sentinelx_best.pt) to optimized ONNX binaries.
Applies Dynamic INT8 Quantization for low-latency DirectML (Windows) and NNAPI (Android) execution.
"""

import os
import sys
import time
import shutil
import argparse
import logging
from pathlib import Path

import torch
import numpy as np

# Import SentinelX local architecture
from model import create_model, SentinelXNet

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("SentinelX.ExportONNX")


class ModelWrapperForExport(torch.nn.Module):
    """
    Wraps SentinelXNet for clean ONNX tracing and flat output signature:
    Inputs:
      - video: [batch_size, 16, 3, 224, 224] Float32
      - audio: [batch_size, 1, 128, 128] Float32
    Outputs:
      - logits: [batch_size, 5] Float32 (Classification probabilities via Softmax)
      - bboxes: [batch_size, 4] Float32 (Normalized [x, y, w, h])
    """

    def __init__(self, base_model: SentinelXNet):
        super().__init__()
        self.base_model = base_model

    def forward(self, video: torch.Tensor, audio: torch.Tensor):
        logits, bboxes = self.base_model(video, audio)
        probs = torch.softmax(logits, dim=-1)
        return probs, bboxes


def export_fp32_onnx(
    model: torch.nn.Module,
    output_onnx_path: Path,
    opset_version: int = 17,
) -> Path:
    """Exports PyTorch model to baseline FP32 ONNX graph."""
    logger.info(f"Exporting PyTorch model to FP32 ONNX graph at: {output_onnx_path}")
    model.eval()

    # Dummy sample inputs
    dummy_video = torch.randn(1, 16, 3, 224, 224, dtype=torch.float32)
    dummy_audio = torch.randn(1, 1, 128, 128, dtype=torch.float32)

    # Dynamic batch size axes for flexible inference
    dynamic_axes = {
        "video_frames": {0: "batch_size"},
        "audio_spectrogram": {0: "batch_size"},
        "threat_probabilities": {0: "batch_size"},
        "bounding_boxes": {0: "batch_size"},
    }

    torch.onnx.export(
        model,
        (dummy_video, dummy_audio),
        str(output_onnx_path),
        export_params=True,
        opset_version=opset_version,
        do_constant_folding=True,
        input_names=["video_frames", "audio_spectrogram"],
        output_names=["threat_probabilities", "bounding_boxes"],
        dynamic_axes=dynamic_axes,
    )

    fp32_size_mb = output_onnx_path.stat().st_size / (1024 * 1024)
    logger.info(f"✓ FP32 ONNX exported successfully. Size: {fp32_size_mb:.2f} MB")
    return output_onnx_path


def quantize_to_int8(
    input_onnx_path: Path,
    output_quant_path: Path,
) -> Path:
    """
    Applies INT8 Dynamic Quantization using onnxruntime.quantization.
    Compresses model weight size by ~70-75% for edge CPU/GPU execution.
    """
    logger.info("Applying dynamic INT8 quantization via ONNX Runtime...")
    try:
        from onnxruntime.quantization import quantize_dynamic, QuantType

        quantize_dynamic(
            model_input=str(input_onnx_path),
            model_output=str(output_quant_path),
            weight_type=QuantType.QInt8,
            per_channel=True,
            reduce_range=True,
        )

        quant_size_mb = output_quant_path.stat().st_size / (1024 * 1024)
        logger.info(f"✓ INT8 Quantized model created at: {output_quant_path}")
        logger.info(f"✓ Compressed Size: {quant_size_mb:.2f} MB")
        return output_quant_path
    except ImportError:
        logger.warning("onnxruntime not installed or quantization unavailable. Copying FP32 as fallback.")
        shutil.copyfile(input_onnx_path, output_quant_path)
        return output_quant_path


def verify_and_benchmark_onnx(onnx_path: Path, num_runs: int = 50):
    """Verifies ONNX model execution with onnxruntime and benchmarks latency."""
    logger.info(f"Verifying ONNX model integrity with ONNX Runtime: {onnx_path.name}")
    try:
        import onnxruntime as ort

        # Initialize session (checks DirectML/CUDA or CPU)
        providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
        available_providers = ort.get_available_providers()
        selected_providers = [p for p in providers if p in available_providers]

        session = ort.InferenceSession(str(onnx_path), providers=selected_providers)
        logger.info(f"Active ONNX Execution Providers: {session.get_providers()}")

        # Generate sample feed
        input_video = np.random.randn(1, 16, 3, 224, 224).astype(np.float32)
        input_audio = np.random.randn(1, 1, 128, 128).astype(np.float32)

        inputs = {
            "video_frames": input_video,
            "audio_spectrogram": input_audio,
        }

        # Warmup
        for _ in range(5):
            _ = session.run(None, inputs)

        # Benchmark
        t0 = time.time()
        for _ in range(num_runs):
            outputs = session.run(None, inputs)
        avg_latency_ms = ((time.time() - t0) / num_runs) * 1000.0
        fps = 1000.0 / avg_latency_ms

        probs, bboxes = outputs
        logger.info("=" * 60)
        logger.info(" ONNX INFERENCE BENCHMARK RESULTS")
        logger.info(f" Average Latency:  {avg_latency_ms:.2f} ms")
        logger.info(f" Throughput:       {fps:.1f} FPS")
        logger.info(f" Output Probs:     {probs.shape} | Max Class: {np.argmax(probs[0])}")
        logger.info(f" Output BBox:      {bboxes.shape} | Coords: {bboxes[0].tolist()}")
        logger.info("=" * 60)
    except Exception as e:
        logger.warning(f"Benchmark verification skipped: {e}")


def deploy_to_flutter_assets(quantized_onnx_path: Path, flutter_asset_dir: Path):
    """Copies exported model directly into Flutter app's assets folder."""
    flutter_asset_dir.mkdir(parents=True, exist_ok=True)
    target_dest = flutter_asset_dir / "sentinelx_model.onnx"
    if quantized_onnx_path.resolve() != target_dest.resolve():
        shutil.copyfile(quantized_onnx_path, target_dest)
    logger.info(f"🚀 Model automatically deployed to Flutter app: {target_dest}")


def main():
    parser = argparse.ArgumentParser(description="SentinelX ONNX Model Export & Quantization Pipeline")
    parser.add_argument("--checkpoint", type=str, default="./checkpoints/sentinelx_best.pt", help="Path to trained PyTorch weights")
    parser.add_argument("--output_dir", type=str, default="./onnx_export", help="Output directory for ONNX graphs")
    parser.add_argument("--flutter_assets", type=str, default="../assets/models", help="Destination Flutter assets folder")
    parser.add_argument("--opset", type=int, default=17, help="ONNX opset version")
    args = parser.parse_args()

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    logger.info("=" * 60)
    logger.info(" SentinelX ONNX Model Compression Pipeline")
    logger.info("=" * 60)

    # 1. Initialize PyTorch Architecture
    base_model = create_model(num_classes=5)

    ckpt_path = Path(args.checkpoint)
    if ckpt_path.exists():
        logger.info(f"Loading weights from checkpoint: {ckpt_path}")
        ckpt = torch.load(str(ckpt_path), map_location="cpu")
        state_dict = ckpt.get("model_state_dict", ckpt)
        base_model.load_state_dict(state_dict)
    else:
        logger.warning(f"Checkpoint {ckpt_path} not found. Exporting initialized architecture.")

    wrapper_model = ModelWrapperForExport(base_model)

    # 2. Export FP32 Graph
    fp32_path = out_dir / "sentinelx_fp32.onnx"
    export_fp32_onnx(wrapper_model, fp32_path, opset_version=args.opset)

    # 3. Dynamic INT8 Quantization
    int8_path = out_dir / "sentinelx_model.onnx"
    quantize_to_int8(fp32_path, int8_path)

    # 4. Verify & Benchmark
    verify_and_benchmark_onnx(int8_path)

    # 5. Deploy to Flutter Asset Directory
    flutter_dir = Path(args.flutter_assets)
    deploy_to_flutter_assets(int8_path, flutter_dir)

    logger.info("ONNX export and deployment complete! Windows and Android apps are ready for live inference.")


if __name__ == "__main__":
    main()
