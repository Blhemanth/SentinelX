#!/usr/bin/env python3
"""
SentinelX - Multi-Modal Fusion Neural Network (SentinelXNet)
Combines 3D Spatio-Temporal Video Features with 2D Audio Spectrogram Embeddings
using Bidirectional Cross-Attention for Real-Time Urban Anomaly & Crime Detection.

Outputs:
1. Threat Classification Logits [B, 5] (Explosion, Gunshot, Fighting, Accident, Normal)
2. Spatial Bounding Box Coordinates [B, 4] (Normalized [x, y, w, h])
"""

import math
from typing import Tuple, Dict

import torch
import torch.nn as nn
import torch.nn.functional as F

# ─────────────────────────────────────────────────
# 1. 3D SPATIO-TEMPORAL VISION BACKBONE
# ─────────────────────────────────────────────────

class Conv3DBlock(nn.Module):
    """3D Convolution + BatchNorm + GELU + MaxPool"""

    def __init__(self, in_channels: int, out_channels: int, stride: Tuple[int, int, int] = (1, 1, 1)):
        super().__init__()
        self.conv = nn.Conv3d(
            in_channels,
            out_channels,
            kernel_size=(3, 3, 3),
            stride=stride,
            padding=(1, 1, 1),
            bias=False,
        )
        self.bn = nn.BatchNorm3d(out_channels)
        self.act = nn.GELU()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.act(self.bn(self.conv(x)))


class VideoSpatioTemporalBackbone(nn.Module):
    """
    Extracts deep spatio-temporal representations from a 16-frame video clip.
    Input: [B, C, T, H, W] -> Output: [B, 512]
    """

    def __init__(self, in_channels: int = 3, feature_dim: int = 512):
        super().__init__()
        # Initial stem
        self.stem = nn.Sequential(
            Conv3DBlock(in_channels, 64, stride=(1, 2, 2)),      # [B, 64, 16, 112, 112]
            nn.MaxPool3d(kernel_size=(1, 2, 2), stride=(1, 2, 2)), # [B, 64, 16, 56, 56]
        )

        # Stage 1
        self.stage1 = nn.Sequential(
            Conv3DBlock(64, 128, stride=(2, 2, 2)),               # [B, 128, 8, 28, 28]
            Conv3DBlock(128, 128),
        )

        # Stage 2
        self.stage2 = nn.Sequential(
            Conv3DBlock(128, 256, stride=(2, 2, 2)),              # [B, 256, 4, 14, 14]
            Conv3DBlock(256, 256),
        )

        # Stage 3
        self.stage3 = nn.Sequential(
            Conv3DBlock(256, feature_dim, stride=(2, 2, 2)),      # [B, 512, 2, 7, 7]
            Conv3DBlock(feature_dim, feature_dim),
        )

        self.global_pool = nn.AdaptiveAvgPool3d((1, 1, 1))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # Input shape: [B, 3, 16, 224, 224]
        feat = self.stem(x)
        feat = self.stage1(feat)
        feat = self.stage2(feat)
        feat = self.stage3(feat)
        pooled = self.global_pool(feat) # [B, 512, 1, 1, 1]
        return pooled.flatten(1)         # [B, 512]


# ─────────────────────────────────────────────────
# 2. AUDIO SPECTROGRAM BACKBONE
# ─────────────────────────────────────────────────

class Conv2DBlock(nn.Module):
    """2D Convolution + BatchNorm + GELU"""

    def __init__(self, in_channels: int, out_channels: int, stride: int = 1):
        super().__init__()
        self.conv = nn.Conv2d(
            in_channels,
            out_channels,
            kernel_size=3,
            stride=stride,
            padding=1,
            bias=False,
        )
        self.bn = nn.BatchNorm2d(out_channels)
        self.act = nn.GELU()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.act(self.bn(self.conv(x)))


class AudioSpectrogramBackbone(nn.Module):
    """
    Extracts acoustic frequency patterns from a 128x128 Mel-spectrogram.
    Input: [B, 1, 128, 128] -> Output: [B, 256]
    """

    def __init__(self, in_channels: int = 1, feature_dim: int = 256):
        super().__init__()
        self.layers = nn.Sequential(
            Conv2DBlock(in_channels, 64, stride=2),   # [B, 64, 64, 64]
            nn.MaxPool2d(2, 2),                       # [B, 64, 32, 32]
            Conv2DBlock(64, 128, stride=2),           # [B, 128, 16, 16]
            Conv2DBlock(128, 128),
            Conv2DBlock(128, feature_dim, stride=2),  # [B, 256, 8, 8]
            Conv2DBlock(feature_dim, feature_dim),
            nn.AdaptiveAvgPool2d((1, 1)),             # [B, 256, 1, 1]
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.layers(x).flatten(1) # [B, 256]


# ─────────────────────────────────────────────────
# 3. BIDIRECTIONAL CROSS-ATTENTION FUSION
# ─────────────────────────────────────────────────

class CrossAttentionFusion(nn.Module):
    """
    Fuses vision and audio modalities via Multi-Head Cross-Attention.
    Allows audio cues (e.g. gunshots) to guide visual anomaly localization.
    """

    def __init__(self, vision_dim: int = 512, audio_dim: int = 256, fusion_dim: int = 512, num_heads: int = 8):
        super().__init__()
        self.proj_vision = nn.Linear(vision_dim, fusion_dim)
        self.proj_audio = nn.Linear(audio_dim, fusion_dim)

        # Cross attention: Video queries attend to Audio keys/values
        self.cross_attn = nn.MultiheadAttention(
            embed_dim=fusion_dim,
            num_heads=num_heads,
            dropout=0.1,
            batch_first=True,
        )

        self.norm1 = nn.LayerNorm(fusion_dim)
        self.norm2 = nn.LayerNorm(fusion_dim)

        self.mlp = nn.Sequential(
            nn.Linear(fusion_dim, fusion_dim * 2),
            nn.GELU(),
            nn.Dropout(0.1),
            nn.Linear(fusion_dim * 2, fusion_dim),
        )

    def forward(self, vision_feat: torch.Tensor, audio_feat: torch.Tensor) -> torch.Tensor:
        # Shapes: vision_feat [B, 512], audio_feat [B, 256]
        v_proj = self.proj_vision(vision_feat).unsqueeze(1) # [B, 1, 512]
        a_proj = self.proj_audio(audio_feat).unsqueeze(1)   # [B, 1, 512]

        # Query: Vision, Key/Value: Audio
        attn_out, _ = self.cross_attn(query=v_proj, key=a_proj, value=a_proj)
        x = self.norm1(v_proj + attn_out)

        # Feed forward block
        fused = self.norm2(x + self.mlp(x))
        return fused.squeeze(1) # [B, 512]


# ─────────────────────────────────────────────────
# 4. SENTINELX FULL MULTI-MODAL MODEL
# ─────────────────────────────────────────────────

class SentinelXNet(nn.Module):
    """
    SentinelX Dual-Branch Multi-Modal Network.
    Accepts video [B, 16, 3, 224, 224] and audio [B, 1, 128, 128].
    Emits threat classification logits [B, 5] and bounding box coordinates [B, 4].
    """

    def __init__(self, num_classes: int = 5, vision_dim: int = 512, audio_dim: int = 256, fusion_dim: int = 512):
        super().__init__()
        self.num_classes = num_classes

        # Backbones
        self.vision_backbone = VideoSpatioTemporalBackbone(in_channels=3, feature_dim=vision_dim)
        self.audio_backbone = AudioSpectrogramBackbone(in_channels=1, feature_dim=audio_dim)

        # Cross-Modal Fusion
        self.fusion = CrossAttentionFusion(
            vision_dim=vision_dim,
            audio_dim=audio_dim,
            fusion_dim=fusion_dim,
            num_heads=8,
        )

        # Head 1: Threat Classification (5 classes)
        self.classifier = nn.Sequential(
            nn.Linear(fusion_dim, 256),
            nn.GELU(),
            nn.Dropout(0.3),
            nn.Linear(256, num_classes),
        )

        # Head 2: Spatial Bounding Box Regression [x, y, w, h] (normalized 0..1)
        self.bbox_regressor = nn.Sequential(
            nn.Linear(fusion_dim, 128),
            nn.GELU(),
            nn.Linear(128, 4),
            nn.Sigmoid(), # Bounding box coordinates strictly bounded in [0..1]
        )

    def forward(self, video: torch.Tensor, audio: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        """
        video: [B, 16, 3, 224, 224] or [B, 3, 16, 224, 224]
        audio: [B, 1, 128, 128]
        returns: (logits [B, 5], bbox [B, 4])
        """
        # Ensure video is [B, C, T, H, W] for 3D Conv
        if video.dim() == 5 and video.shape[1] == 16 and video.shape[2] == 3:
            # Transpose [B, T, C, H, W] -> [B, C, T, H, W]
            video = video.permute(0, 2, 1, 3, 4).contiguous()

        v_embed = self.vision_backbone(video)  # [B, 512]
        a_embed = self.audio_backbone(audio)   # [B, 256]

        joint_embed = self.fusion(v_embed, a_embed) # [B, 512]

        logits = self.classifier(joint_embed)       # [B, 5]
        bbox = self.bbox_regressor(joint_embed)     # [B, 4]

        return logits, bbox


def create_model(num_classes: int = 5, pretrained: bool = False) -> SentinelXNet:
    """Factory helper to construct SentinelXNet with optional weights."""
    model = SentinelXNet(num_classes=num_classes)
    return model


if __name__ == "__main__":
    print("[SentinelX] Validating SentinelXNet architecture...")
    model = create_model()
    model.eval()

    # Dummy inputs matching pipeline specification
    dummy_video = torch.randn(2, 16, 3, 224, 224) # [Batch=2, Frames=16, C=3, H=224, W=224]
    dummy_audio = torch.randn(2, 1, 128, 128)      # [Batch=2, C=1, Freq=128, Time=128]

    with torch.no_grad():
        logits, bbox = model(dummy_video, dummy_audio)

    print(f"✓ Video Input Shape:  {dummy_video.shape}")
    print(f"✓ Audio Input Shape:  {dummy_audio.shape}")
    print(f"✓ Output Logits:      {logits.shape} (Expected: [2, 5])")
    print(f"✓ Output BoundingBox: {bbox.shape} (Expected: [2, 4])")
    print(f"✓ Total Parameters:   {sum(p.numel() for p in model.parameters()):,}")
    print("✓ Model forward pass verified successfully!")
