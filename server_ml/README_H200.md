# SentinelX — NVIDIA H200 Execution Runbook & Operational Guide

This document is the definitive operational runbook for executing the SentinelX multi-modal training pipeline on an **NVIDIA H200 GPU (141GB HBM3e VRAM, 4.8 TB/s Memory Bandwidth)** and deploying the compressed INT8 ONNX model to the cross-platform Flutter application.

---

## 1. Remote H200 Pod Verification & Connection

### Step 1.1: SSH into H200 GPU Instance
```bash
# Connect to your GPU pod / cloud instance (RunPod, Lambda, Vast.ai, CoreWeave, or Slurm cluster)
ssh -i ~/.ssh/id_rsa root@<H200_SERVER_IP> -p <PORT>

# If using tmux/screen to prevent disconnect interruption (CRITICAL for long training sessions):
tmux new -s sentinelx_training
```

### Step 1.2: Verify CUDA & GPU Hardware Acceleration
```bash
# Check GPU hardware and driver version (Expected: NVIDIA H200 PCIe / SXM5)
nvidia-smi

# Expected output highlights:
# +-----------------------------------------------------------------------------------------+
# | NVIDIA-SMI 550.54.14              Driver Version: 550.54.14      CUDA Version: 12.4     |
# | GPU  Name                     Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp   Perf          Pwr:Usage/Cap |            Memory-Usage | GPU-Util  Compute M. |
# |                                         |                         |               MIG M. |
# |=========================================+=========================+======================|
# |   0  NVIDIA H200                    On  |   00000000:01:00.0  Off |                    0 |
# | N/A   32C    P0             140W / 700W |       0MiB / 141312MiB |      0%      Default |
# +-----------------------------------------------------------------------------------------+
```

---

## 2. Environment Setup & Dependency Installation

### Step 2.1: Python Environment Creation
```bash
# Create and activate an isolated Python 3.10 environment
conda create -n sentinelx python=3.10 -y
conda activate sentinelx

# Upgrade core packaging tools
pip install --upgrade pip setuptools wheel
```

### Step 2.2: Install PyTorch 2.4+ with CUDA 12.4
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# Verify PyTorch CUDA & BFloat16 compatibility
python -c "import torch; print(f'PyTorch {torch.__version__} | CUDA Available: {torch.cuda.is_available()} | Device: {torch.cuda.get_device_name(0)} | BFloat16 Supported: {torch.cuda.is_bf16_supported()}')"
```

### Step 2.3: Install SentinelX Server ML Requirements
```bash
cd /workspace/SentinelX/server_ml
pip install -r requirements.txt
```

### Step 2.4: Authenticate Hugging Face / Kaggle API (Optional for automated download)
```bash
# For XD-Violence and UCF-Crime raw asset downloads
export HF_TOKEN="hf_your_token_here"
pip install huggingface_hub kaggle
```

---

## 3. Dataset Preprocessing Execution Sequence

Run the automated data preparation script to extract 16-frame spatio-temporal video clips and matching 128×128 Mel-spectrogram tensors:

```bash
# Full dataset preprocessing (extracts clips and Mel-spectrograms into ./data):
python prepare_dataset.py \
    --data_root ./data \
    --dataset all \
    --samples 1000

# Verification: inspect created tensor directory structure
ls -lh data/processed/video_clips/
ls -lh data/processed/mel_specs/
cat data/manifests/train_manifest.json | head -n 30
```

---

## 4. Launching High-Performance H200 Training

Leverage the 141GB HBM3e VRAM with large batch sizes, `torch.compile(mode="max-autotune")`, and BFloat16 Automatic Mixed Precision:

### Direct Shell Execution:
```bash
python train_h200.py \
    --data_root ./data \
    --output_dir ./checkpoints \
    --epochs 35 \
    --batch_size 32 \
    --lr 0.0003 \
    --weight_decay 0.0001 \
    --workers 16 \
    --compile
```

### Slurm Batch Job Execution (for multi-tenant clusters):
```bash
cat << 'EOF' > run_h200.slurm
#!/bin/bash
#SBATCH --job-name=sentinelx_h200
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --gpus=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=12:00:00
#SBATCH --output=logs/sentinelx_%j.log

source activate sentinelx
python train_h200.py \
    --data_root ./data \
    --output_dir ./checkpoints \
    --epochs 40 \
    --batch_size 64 \
    --lr 0.0003 \
    --workers 16 \
    --compile
EOF

sbatch run_h200.slurm
```

---

## 5. Exporting & INT8 Quantizing for Edge Deployment

After training converges and `checkpoints/sentinelx_best.pt` is saved, run the quantization and export script:

```bash
python export_onnx.py \
    --checkpoint ./checkpoints/sentinelx_best.pt \
    --output_dir ./onnx_export \
    --flutter_assets ../assets/models \
    --opset 17
```

### Verification Checklist:
- **Baseline FP32 Model Size:** `onnx_export/sentinelx_fp32.onnx` (~1.2 GB)
- **Quantized INT8 Model Size:** `onnx_export/sentinelx_model.onnx` (~200MB – 300MB)
- **Automatic Deployment:** Automatically copies `sentinelx_model.onnx` into `assets/models/sentinelx_model.onnx` in the Flutter workspace.

---

## 6. Downloading Quantized Weights to Client Machine

From your local development machine (Windows Desktop / Laptop terminal):

```powershell
# Using SCP to copy model weights directly to the Flutter assets directory:
scp -P <PORT> root@<H200_SERVER_IP>:/workspace/SentinelX/server_ml/onnx_export/sentinelx_model.onnx b:\SentinelX\assets\models\sentinelx_model.onnx

# Verify file presence on Windows:
Get-Item b:\SentinelX\assets\models\sentinelx_model.onnx
```

---

## 7. Client Execution Verification

Once `sentinelx_model.onnx` is placed in `assets/models/`:
1. Launch the Windows desktop app:
   ```powershell
   flutter run -d windows
   ```
2. Navigate to **Settings → ONNX Model Weights & Hardware EP**.
3. Verify that the simulation banner disappears and the status reads:
   `ACTIVE (READY) • DirectML (Windows GPU Acceleration)`.
4. Click **Run Latency Benchmark** to verify local execution latency (~12–16 ms at ~65–75 FPS).
