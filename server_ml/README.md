# SentinelX Server ML — NVIDIA H200 Training & ONNX Export Pipeline

This directory contains the production PyTorch training and ONNX quantization codebase designed to be executed on an **NVIDIA H200 GPU server (141GB HBM3e VRAM)**.

---

## 🚀 Quick Start on H200 Server

### 1. Environment Setup

```bash
# SSH into H200 GPU Instance
ssh user@h200-server-ip

# Create & activate conda environment
conda create -n sentinelx python=3.10 -y
conda activate sentinelx

# Install PyTorch with CUDA 12.4 support
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# Install required dependencies
pip install -r requirements.txt
```

---

### 2. Prepare Datasets (XD-Violence & UCF-Crime)

```bash
# Automated dataset download and 16-frame + Mel-spectrogram tensor preparation:
python prepare_dataset.py --data_root ./data --dataset all
```

This organizes the video clips and Mel-spectrograms into:
- `data/processed/video_clips/*.npy` (`[16, 3, 224, 224]`)
- `data/processed/mel_specs/*.npy` (`[1, 128, 128]`)
- `data/manifests/train_manifest.json`
- `data/manifests/val_manifest.json`

---

### 3. Launch H200 High-Performance Training

```bash
# Run multi-modal training leveraging H200 bfloat16 Tensor Cores and torch.compile:
python train_h200.py \
    --data_root ./data \
    --output_dir ./checkpoints \
    --epochs 30 \
    --batch_size 32 \
    --lr 0.0003 \
    --workers 16 \
    --compile
```

#### Multi-GPU Slurm Job Submission Script (`train_slurm.sh`):
```bash
#!/bin/bash
#SBATCH --job-name=sentinelx_train
#SBATCH --nodes=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=12:00:00

conda activate sentinelx
python train_h200.py --batch_size 64 --epochs 40 --compile
```

---

### 4. Export & INT8 Quantize ONNX Model

```bash
# Export trained PyTorch weights to INT8 compressed ONNX graph:
python export_onnx.py \
    --checkpoint ./checkpoints/sentinelx_best.pt \
    --output_dir ./onnx_export \
    --flutter_assets ../assets/models \
    --opset 17
```

- **Compression Result:** Compresses FP32 model (~1.2GB) down to **~200MB–300MB INT8**.
- **Auto-Deployment:** Copies `sentinelx_model.onnx` straight to `assets/models/sentinelx_model.onnx` in the Flutter workspace for immediate pickup by Windows DirectML and Android NNAPI.

---

## 🏗️ Architecture Overview

- **Vision Backbone:** 3D Spatio-Temporal Convolutional Network (`VideoSpatioTemporalBackbone`) extracting 16-frame clip dynamics -> `[B, 512]`.
- **Audio Backbone:** 2D Mel-Spectrogram Network (`AudioSpectrogramBackbone`) extracting frequency signatures -> `[B, 256]`.
- **Cross-Attention Fusion:** Multi-Head Attention query-key fusion bridging audio events and visual tracking -> `[B, 512]`.
- **Classification Head:** 5 Threat classes (`Explosion`, `Gunshot`, `Fighting`, `Accident`, `Normal`).
- **Localization Head:** Continuous `[x, y, w, h]` normalized bounding box coordinates.
