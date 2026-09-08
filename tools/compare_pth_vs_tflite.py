#!/usr/bin/env python3
"""Compare binary .pth Impressionism classifier vs current 8-era TFLite model."""

from __future__ import annotations

import random
from collections import defaultdict
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from torchvision import models, transforms
import tensorflow as tf

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "tools" / "data" / "era_cache"
PTH = ROOT / "4_5821238943164669674.pth"
TFLITE = ROOT / "assets" / "models" / "era_model.tflite"
LABELS = ROOT / "assets" / "models" / "labels.txt"
SEED = 42
VAL_FRAC = 0.2


class ImpressionismNN(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.fc1 = nn.Linear(2048, 256)
        self.batchnorm1 = nn.BatchNorm1d(256)
        self.fc2 = nn.Linear(256, 128)
        self.batchnorm2 = nn.BatchNorm1d(128)
        self.fc3 = nn.Linear(128, 64)
        self.batchnorm3 = nn.BatchNorm1d(64)
        self.fc4 = nn.Linear(64, 2)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = F.relu(self.batchnorm1(self.fc1(x)))
        x = F.relu(self.batchnorm2(self.fc2(x)))
        x = F.relu(self.batchnorm3(self.fc3(x)))
        return self.fc4(x)


def load_era_images() -> dict[str, list[Path]]:
    buckets: dict[str, list[Path]] = defaultdict(list)
    for era_dir in sorted(CACHE.iterdir()):
        if not era_dir.is_dir():
            continue
        for p in sorted(era_dir.glob("*.jpg")):
            buckets[era_dir.name].append(p)
    return buckets


def split_paths(buckets: dict[str, list[Path]]) -> tuple[list[tuple[Path, int]], list[tuple[Path, int]]]:
    """Binary labels: 1=Impressionism, 0=other. Hold out unique images per era."""
    rng = random.Random(SEED)
    train, val = [], []
    for era, paths in buckets.items():
        paths = list(paths)
        rng.shuffle(paths)
        label = 1 if era == "Impressionism" else 0
        n_val = max(1, int(round(len(paths) * VAL_FRAC)))
        for p in paths[:n_val]:
            val.append((p, label))
        for p in paths[n_val:]:
            train.append((p, label))
    return train, val


def build_backbone() -> tuple[nn.Module, transforms.Compose]:
    # Checkpoint was trained on classic ResNet50 (V1) features, not V2.
    weights = models.ResNet50_Weights.IMAGENET1K_V1
    backbone = models.resnet50(weights=weights)
    backbone.fc = nn.Identity()
    backbone.eval()
    return backbone, weights.transforms()


def load_pth_head(path: Path) -> tuple[ImpressionismNN, dict]:
    ckpt = torch.load(path, map_location="cpu", weights_only=False)
    model = ImpressionismNN()
    model.load_state_dict(ckpt["model_state_dict"])
    model.eval()
    return model, ckpt


def predict_pth(
    paths: list[tuple[Path, int]],
    backbone: nn.Module,
    prep: transforms.Compose,
    head: ImpressionismNN,
) -> list[int]:
    preds = []
    with torch.no_grad():
        for path, _ in paths:
            img = Image.open(path).convert("RGB")
            x = prep(img).unsqueeze(0)
            feat = backbone(x)
            logits = head(feat)
            preds.append(int(logits.argmax(dim=1).item()))
    return preds


def predict_tflite(paths: list[tuple[Path, int]]) -> list[int]:
    eras = [
        line.split("|", 1)[0].strip()
        for line in LABELS.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    imp_idx = eras.index("Impressionism")
    interpreter = tf.lite.Interpreter(model_path=str(TFLITE))
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    h, w = int(inp["shape"][1]), int(inp["shape"][2])
    preds = []
    for path, _ in paths:
        arr = np.asarray(
            Image.open(path).convert("RGB").resize((w, h), Image.Resampling.BILINEAR),
            dtype=np.float32,
        )[None, ...] / 255.0
        interpreter.set_tensor(inp["index"], arr)
        interpreter.invoke()
        logits = interpreter.get_tensor(out["index"])[0]
        # Softmax if logits
        if logits.min() < 0 or abs(float(logits.sum()) - 1.0) > 0.05:
            e = np.exp(logits - logits.max())
            probs = e / e.sum()
        else:
            probs = logits
        pred_era = int(np.argmax(probs))
        preds.append(1 if pred_era == imp_idx else 0)
    return preds


def metrics(y_true: list[int], y_pred: list[int]) -> dict[str, float]:
    y_true_a = np.array(y_true)
    y_pred_a = np.array(y_pred)
    acc = float((y_true_a == y_pred_a).mean())
    # Impressionism recall/precision
    tp = int(((y_true_a == 1) & (y_pred_a == 1)).sum())
    fp = int(((y_true_a == 0) & (y_pred_a == 1)).sum())
    fn = int(((y_true_a == 1) & (y_pred_a == 0)).sum())
    prec = tp / (tp + fp) if (tp + fp) else 0.0
    rec = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = 2 * prec * rec / (prec + rec) if (prec + rec) else 0.0
    return {
        "accuracy": acc,
        "impressionism_precision": prec,
        "impressionism_recall": rec,
        "impressionism_f1": f1,
        "n": float(len(y_true)),
        "n_impressionism": float(int(y_true_a.sum())),
    }


def main() -> None:
    buckets = load_era_images()
    if not buckets:
        raise SystemExit(f"No cache at {CACHE}")
    _, val = split_paths(buckets)
    y_true = [y for _, y in val]
    print(f"val images={len(val)} impressionism={sum(y_true)} other={len(val)-sum(y_true)}")
    print("cache", {k: len(v) for k, v in buckets.items()})

    head, ckpt = load_pth_head(PTH)
    print(
        f"pth claimed_acc={ckpt.get('accuracy')} classes={ckpt.get('classes')} "
        f"arch={ckpt.get('model_architecture')} input={ckpt.get('input_size')}"
    )
    print("Loading ResNet50 backbone for .pth features…")
    backbone, prep = build_backbone()
    pth_preds = predict_pth(val, backbone, prep, head)
    pth_m = metrics(y_true, pth_preds)
    print("PTH binary metrics:", pth_m)

    print("Evaluating current TFLite era model as binary Impressionism detector…")
    tflite_preds = predict_tflite(val)
    tflite_m = metrics(y_true, tflite_preds)
    print("TFLITE binary metrics:", tflite_m)

    # Also report 8-era accuracy for TFLite only
    eras = [
        line.split("|", 1)[0].strip()
        for line in LABELS.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    interpreter = tf.lite.Interpreter(model_path=str(TFLITE))
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    h, w = int(inp["shape"][1]), int(inp["shape"][2])
    correct = 0
    total = 0
    for era, paths in buckets.items():
        rng = random.Random(SEED)
        paths = list(paths)
        rng.shuffle(paths)
        n_val = max(1, int(round(len(paths) * VAL_FRAC)))
        for path in paths[:n_val]:
            arr = np.asarray(
                Image.open(path).convert("RGB").resize((w, h), Image.Resampling.BILINEAR),
                dtype=np.float32,
            )[None, ...] / 255.0
            interpreter.set_tensor(inp["index"], arr)
            interpreter.invoke()
            logits = interpreter.get_tensor(out["index"])[0]
            pred = eras[int(np.argmax(logits))]
            correct += int(pred == era)
            total += 1
    print(f"TFLITE 8-era held-out accuracy: {correct/total:.3f} ({correct}/{total})")

    better = "pth" if pth_m["accuracy"] > tflite_m["accuracy"] else "tflite"
    if abs(pth_m["accuracy"] - tflite_m["accuracy"]) < 1e-9:
        better = "tie"
    print(f"binary_winner={better}")
    print(
        "NOTE: .pth is binary Impressionism-only; app model is 8-era. "
        "Cannot drop-in replace without changing app labels/UX."
    )


if __name__ == "__main__":
    main()
