#!/usr/bin/env python3
"""
SentinelX - High-Performance Training Engine for NVIDIA H200 (141GB HBM3e)
Optimized for PyTorch 2.x, CUDA 12, torch.compile(max-autotune), and BFloat16 AMP.
Trains multi-modal SentinelXNet on XD-Violence and UCF-Crime datasets.
"""

import os
import sys
import time
import json
import argparse
import logging
from pathlib import Path
from typing import Dict, Any, Tuple

import torch
import torch.nn as nn
from torch.optim import AdamW
from torch.optim.lr_scheduler import CosineAnnealingLR
from torch.cuda.amp import autocast, GradScaler

# Import SentinelX local modules
from model import create_model, SentinelXNet
from dataset import get_dataloaders

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("SentinelX.TrainH200")


class MultiTaskLoss(nn.Module):
    """
    Joint loss function combining classification loss (with label smoothing)
    and smooth L1 loss for anomaly bounding box spatial regression.
    """

    def __init__(self, label_smoothing: float = 0.1, bbox_weight: float = 2.0):
        super().__init__()
        self.cls_criterion = nn.CrossEntropyLoss(label_smoothing=label_smoothing)
        self.bbox_criterion = nn.SmoothL1Loss()
        self.bbox_weight = bbox_weight

    def forward(
        self,
        pred_logits: torch.Tensor,
        target_labels: torch.Tensor,
        pred_bboxes: torch.Tensor,
        target_bboxes: torch.Tensor,
    ) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        cls_loss = self.cls_criterion(pred_logits, target_labels)

        # Compute bbox loss only on anomaly samples (class != 0)
        anomaly_mask = target_labels > 0
        if anomaly_mask.sum() > 0:
            bbox_loss = self.bbox_criterion(pred_bboxes[anomaly_mask], target_bboxes[anomaly_mask])
        else:
            bbox_loss = torch.tensor(0.0, device=pred_logits.device)

        total_loss = cls_loss + (self.bbox_weight * bbox_loss)
        return total_loss, cls_loss, bbox_loss


def train_one_epoch(
    model: nn.Module,
    dataloader,
    optimizer: torch.optim.Optimizer,
    criterion: MultiTaskLoss,
    scaler: GradScaler,
    device: torch.device,
    use_bfloat16: bool = True,
) -> Dict[str, float]:
    """Runs a single training epoch across all multi-modal batches."""
    model.train()
    total_loss = 0.0
    total_cls_loss = 0.0
    total_bbox_loss = 0.0
    correct = 0
    total_samples = 0

    amp_dtype = torch.bfloat16 if use_bfloat16 and torch.cuda.is_available() else torch.float16

    for step, batch in enumerate(dataloader):
        video = batch["video"].to(device, non_blocking=True)
        audio = batch["audio"].to(device, non_blocking=True)
        labels = batch["label"].to(device, non_blocking=True)
        bboxes = batch["bbox"].to(device, non_blocking=True)

        optimizer.zero_grad(set_to_none=True)

        # Automatic Mixed Precision
        with autocast(dtype=amp_dtype, enabled=(device.type == "cuda")):
            pred_logits, pred_bboxes = model(video, audio)
            loss, cls_l, bbox_l = criterion(pred_logits, labels, pred_bboxes, bboxes)

        if device.type == "cuda" and not use_bfloat16:
            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
        else:
            loss.backward()
            # Gradient clipping to prevent exploding gradients
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            optimizer.step()

        # Metrics tracking
        bs = labels.size(0)
        total_loss += loss.item() * bs
        total_cls_loss += cls_l.item() * bs
        total_bbox_loss += (bbox_l.item() if isinstance(bbox_l, torch.Tensor) else bbox_l) * bs

        preds = torch.argmax(pred_logits, dim=-1)
        correct += (preds == labels).sum().item()
        total_samples += bs

    return {
        "loss": total_loss / max(1, total_samples),
        "cls_loss": total_cls_loss / max(1, total_samples),
        "bbox_loss": total_bbox_loss / max(1, total_samples),
        "accuracy": (correct / max(1, total_samples)) * 100.0,
    }


@torch.no_grad()
def evaluate(
    model: nn.Module,
    dataloader,
    criterion: MultiTaskLoss,
    device: torch.device,
) -> Dict[str, float]:
    """Evaluates model performance on the validation set."""
    model.eval()
    total_loss = 0.0
    correct = 0
    total_samples = 0

    for batch in dataloader:
        video = batch["video"].to(device, non_blocking=True)
        audio = batch["audio"].to(device, non_blocking=True)
        labels = batch["label"].to(device, non_blocking=True)
        bboxes = batch["bbox"].to(device, non_blocking=True)

        pred_logits, pred_bboxes = model(video, audio)
        loss, _, _ = criterion(pred_logits, labels, pred_bboxes, bboxes)

        bs = labels.size(0)
        total_loss += loss.item() * bs
        preds = torch.argmax(pred_logits, dim=-1)
        correct += (preds == labels).sum().item()
        total_samples += bs

    return {
        "val_loss": total_loss / max(1, total_samples),
        "val_accuracy": (correct / max(1, total_samples)) * 100.0,
    }


def main():
    parser = argparse.ArgumentParser(description="SentinelX H200 High-Performance Training Pipeline")
    parser.add_argument("--data_root", type=str, default="./data", help="Path to prepared dataset directory")
    parser.add_argument("--output_dir", type=str, default="./checkpoints", help="Path to store trained models")
    parser.add_argument("--epochs", type=int, default=30, help="Total training epochs")
    parser.add_argument("--batch_size", type=int, default=32, help="Per-GPU batch size (H200 can easily fit 32-64)")
    parser.add_argument("--lr", type=float, default=3e-4, help="Learning rate")
    parser.add_argument("--weight_decay", type=float, default=1e-4, help="AdamW weight decay")
    parser.add_argument("--workers", type=int, default=8, help="DataLoader num_workers")
    parser.add_argument("--compile", action="store_true", default=False, help="Enable PyTorch 2.x torch.compile")
    args = parser.parse_args()

    output_path = Path(args.output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    # 1. Device Setup & H200 Detection
    if torch.cuda.is_available():
        device = torch.device("cuda:0")
        gpu_name = torch.cuda.get_device_name(0)
        vram_gb = torch.cuda.get_device_properties(0).total_memory / (1024**3)
        logger.info(f"Using GPU Accelerator: {gpu_name} ({vram_gb:.1f} GB VRAM)")
        # Benchmark mode for deterministic cuDNN tensor convolutions
        torch.backends.cudnn.benchmark = True
    else:
        device = torch.device("cpu")
        logger.warning("CUDA not detected. Running training in CPU mode.")

    # 2. DataLoaders
    logger.info(f"Loading datasets from: {args.data_root}")
    train_loader, val_loader = get_dataloaders(
        data_root=args.data_root,
        batch_size=args.batch_size,
        num_workers=args.workers if torch.cuda.is_available() else 0,
        pin_memory=torch.cuda.is_available(),
    )
    logger.info(f"Train batches: {len(train_loader)} | Val batches: {len(val_loader)}")

    # 3. Model Architecture
    model = create_model(num_classes=5)
    model = model.to(device)

    # 4. Optional PyTorch 2.x Compiler
    if args.compile and hasattr(torch, "compile") and torch.cuda.is_available():
        logger.info("Enabling torch.compile(mode='max-autotune') for Triton kernel fusion...")
        try:
            model = torch.compile(model, mode="max-autotune")
        except Exception as e:
            logger.warning(f"torch.compile failed: {e}. Falling back to standard eager execution.")

    # 5. Optimizer, Loss & Scheduler
    criterion = MultiTaskLoss(label_smoothing=0.1, bbox_weight=2.0)
    optimizer = AdamW(model.parameters(), lr=args.lr, weight_decay=args.weight_decay)
    scheduler = CosineAnnealingLR(optimizer, T_max=args.epochs, eta_min=1e-6)
    scaler = GradScaler()

    # 6. Training Loop
    logger.info("=" * 65)
    logger.info(f" Starting SentinelX Training: {args.epochs} Epochs | Batch Size: {args.batch_size}")
    logger.info("=" * 65)

    best_val_acc = 0.0
    history = []

    for epoch in range(1, args.epochs + 1):
        t0 = time.time()

        train_metrics = train_one_epoch(
            model=model,
            dataloader=train_loader,
            optimizer=optimizer,
            criterion=criterion,
            scaler=scaler,
            device=device,
            use_bfloat16=True,
        )

        val_metrics = evaluate(
            model=model,
            dataloader=val_loader,
            criterion=criterion,
            device=device,
        )

        scheduler.step()
        elapsed = time.time() - t0

        logger.info(
            f"Epoch [{epoch:02d}/{args.epochs:02d}] ({elapsed:.1f}s) | "
            f"Train Loss: {train_metrics['loss']:.4f} | Train Acc: {train_metrics['accuracy']:.1f}% | "
            f"Val Loss: {val_metrics['val_loss']:.4f} | Val Acc: {val_metrics['val_accuracy']:.1f}% | "
            f"LR: {scheduler.get_last_lr()[0]:.6f}"
        )

        epoch_record = {
            "epoch": epoch,
            "elapsed_seconds": elapsed,
            **train_metrics,
            **val_metrics,
            "lr": scheduler.get_last_lr()[0],
        }
        history.append(epoch_record)

        # Save Best Checkpoint
        if val_metrics["val_accuracy"] >= best_val_acc:
            best_val_acc = val_metrics["val_accuracy"]
            best_ckpt_path = output_path / "sentinelx_best.pt"
            torch.save(
                {
                    "epoch": epoch,
                    "model_state_dict": model.state_dict(),
                    "optimizer_state_dict": optimizer.state_dict(),
                    "val_accuracy": best_val_acc,
                    "hyperparameters": vars(args),
                },
                str(best_ckpt_path),
            )
            logger.info(f" ⭐ New best checkpoint saved: {best_ckpt_path} (Val Acc: {best_val_acc:.2f}%)")

    # Save training curves log
    history_file = output_path / "training_history.json"
    with open(history_file, "w") as f:
        json.dump(history, f, indent=2)

    logger.info("=" * 65)
    logger.info(f" Training Completed! Best Val Accuracy: {best_val_acc:.2f}%")
    logger.info(f" Model Checkpoint: {output_path / 'sentinelx_best.pt'}")
    logger.info(" Next Step: Run export_onnx.py to quantize for Windows & Android.")
    logger.info("=" * 65)


if __name__ == "__main__":
    main()
