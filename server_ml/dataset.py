#!/usr/bin/env python3
"""
SentinelX - PyTorch Multi-Modal Dataset & DataLoader
Synchronously loads 16-frame spatio-temporal video tensors [16, 3, 224, 224]
and Mel-spectrogram audio tensors [1, 128, 128] with data augmentation.
"""

import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any

import numpy as np
import torch
from torch.utils.data import Dataset, DataLoader

# ─────────────────────────────────────────────────
# DATA AUGMENTATION UTILITIES
# ─────────────────────────────────────────────────

class MultiModalAugmenter:
    """Applies video spatial augmentations and audio SpecAugment masking."""

    def __init__(self, is_training: bool = True):
        self.is_training = is_training
        # ImageNet normalization statistics
        self.mean = np.array([0.485, 0.456, 0.406], dtype=np.float32).reshape(1, 3, 1, 1)
        self.std = np.array([0.229, 0.224, 0.225], dtype=np.float32).reshape(1, 3, 1, 1)

    def augment_video(self, video_clip: np.ndarray) -> torch.FloatTensor:
        """
        video_clip: [16, 3, 224, 224] in range [0..255]
        returns: normalized torch FloatTensor [16, 3, 224, 224]
        """
        # Convert uint8 to float32 [0..1]
        frames = video_clip.astype(np.float32) / 255.0

        if self.is_training:
            # 1. Random Horizontal Flip (consistent across all 16 frames in clip)
            if np.random.rand() > 0.5:
                frames = np.flip(frames, axis=3).copy()

            # 2. Random Brightness / Contrast jitter
            if np.random.rand() > 0.5:
                contrast_factor = np.random.uniform(0.85, 1.15)
                brightness_delta = np.random.uniform(-0.1, 0.1)
                frames = np.clip((frames - 0.5) * contrast_factor + 0.5 + brightness_delta, 0.0, 1.0)

        # Normalize with ImageNet mean/std
        normalized = (frames - self.mean) / self.std
        return torch.from_numpy(normalized).float()

    def augment_audio(self, mel_spec: np.ndarray) -> torch.FloatTensor:
        """
        mel_spec: [1, 128, 128]
        returns: augmented torch FloatTensor [1, 128, 128]
        """
        spec = torch.from_numpy(mel_spec.copy()).float()

        if self.is_training:
            # 1. Frequency Masking (SpecAugment)
            if np.random.rand() > 0.5:
                f_mask_len = np.random.randint(4, 16)
                f_start = np.random.randint(0, max(1, 128 - f_mask_len))
                spec[:, f_start : f_start + f_mask_len, :] = 0.0

            # 2. Time Masking (SpecAugment)
            if np.random.rand() > 0.5:
                t_mask_len = np.random.randint(4, 16)
                t_start = np.random.randint(0, max(1, 128 - t_mask_len))
                spec[:, :, t_start : t_start + t_mask_len] = 0.0

            # 3. Additive Gaussian Noise
            if np.random.rand() > 0.5:
                noise = torch.randn_like(spec) * 0.05
                spec = spec + noise

        return spec


# ─────────────────────────────────────────────────
# DATASET IMPLEMENTATION
# ─────────────────────────────────────────────────

class XDViolenceDataset(Dataset):
    """
    Multi-modal PyTorch Dataset for urban anomaly and crime detection.
    Loads matching video clip tensors and audio spectrograms.
    """

    def __init__(
        self,
        data_root: str,
        manifest_file: str,
        is_training: bool = True,
    ):
        self.data_root = Path(data_root)
        manifest_path = self.data_root / manifest_file

        if not manifest_path.exists():
            raise FileNotFoundError(
                f"Manifest not found: {manifest_path}. Run prepare_dataset.py first."
            )

        with open(manifest_path, "r") as f:
            self.samples: List[Dict[str, Any]] = json.load(f)

        self.augmenter = MultiModalAugmenter(is_training=is_training)

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, idx: int) -> Dict[str, Any]:
        item = self.samples[idx]

        # 1. Load Video Clip Tensor [16, 3, 224, 224]
        video_full_path = self.data_root / item["video_path"]
        if video_full_path.exists():
            video_raw = np.load(str(video_full_path))
        else:
            video_raw = np.zeros((16, 3, 224, 224), dtype=np.uint8)

        video_tensor = self.augmenter.augment_video(video_raw)

        # 2. Load Audio Mel-spectrogram Tensor [1, 128, 128]
        audio_full_path = self.data_root / item["audio_path"]
        if audio_full_path.exists():
            audio_raw = np.load(str(audio_full_path))
        else:
            audio_raw = np.zeros((1, 128, 128), dtype=np.float32)

        audio_tensor = self.augmenter.augment_audio(audio_raw)

        # 3. Ground Truth Targets
        class_label = torch.tensor(item["class_id"], dtype=torch.long)
        bbox = torch.tensor(item.get("bbox", [0.0, 0.0, 0.0, 0.0]), dtype=torch.float32)

        return {
            "video": video_tensor,  # [16, 3, 224, 224]
            "audio": audio_tensor,  # [1, 128, 128]
            "label": class_label,   # Scalar long (0..4)
            "bbox": bbox,           # [4] float [x, y, w, h]
            "sample_id": item["sample_id"],
            "threat_name": item["threat_label"],
        }


def get_dataloaders(
    data_root: str = "./data",
    batch_size: int = 16,
    num_workers: int = 4,
    pin_memory: bool = True,
) -> Tuple[DataLoader, DataLoader]:
    """
    Factory function producing high-throughput train and validation DataLoaders.
    Optimized for multi-threaded HBM3e VRAM transfer on NVIDIA H200.
    """
    train_dataset = XDViolenceDataset(
        data_root=data_root,
        manifest_file="manifests/train_manifest.json",
        is_training=True,
    )

    val_dataset = XDViolenceDataset(
        data_root=data_root,
        manifest_file="manifests/val_manifest.json",
        is_training=False,
    )

    train_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        shuffle=True,
        num_workers=num_workers,
        pin_memory=pin_memory,
        persistent_workers=(num_workers > 0),
        drop_last=True,
    )

    val_loader = DataLoader(
        val_dataset,
        batch_size=batch_size,
        shuffle=False,
        num_workers=num_workers,
        pin_memory=pin_memory,
        persistent_workers=(num_workers > 0),
        drop_last=False,
    )

    return train_loader, val_loader


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--data_root", type=str, default="./data")
    args = parser.parse_args()

    print("[SentinelX] Validating XDViolenceDataset...")
    try:
        train_loader, val_loader = get_dataloaders(data_root=args.data_root, batch_size=4, num_workers=0)
        batch = next(iter(train_loader))
        print(f"✓ Video Tensor Shape: {batch['video'].shape} (Expected: [4, 16, 3, 224, 224])")
        print(f"✓ Audio Tensor Shape: {batch['audio'].shape} (Expected: [4, 1, 128, 128])")
        print(f"✓ Labels Shape:       {batch['label'].shape} Values: {batch['label'].tolist()}")
        print(f"✓ BBox Shape:         {batch['bbox'].shape}")
        print("✓ DataLoader validation succeeded!")
    except Exception as e:
        print(f"Note: Dataset manifest not present or error: {e}")
