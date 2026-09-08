#!/usr/bin/env python3
"""Simple local UI to try the .pth Impressionism model vs the app TFLite era model."""

from __future__ import annotations

from pathlib import Path

import gradio as gr
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from torchvision import models, transforms
import tensorflow as tf

ROOT = Path(__file__).resolve().parents[1]
PTH = ROOT / "4_5821238943164669674.pth"
TFLITE = ROOT / "assets" / "models" / "era_model.tflite"
LABELS = ROOT / "assets" / "models" / "labels.txt"

_pth_head = None
_backbone = None
_prep = None
_tflite = None
_eras: list[str] = []


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


def load_models() -> str:
    global _pth_head, _backbone, _prep, _tflite, _eras
    if _pth_head is None:
        ckpt = torch.load(PTH, map_location="cpu", weights_only=False)
        _pth_head = ImpressionismNN()
        _pth_head.load_state_dict(ckpt["model_state_dict"])
        _pth_head.eval()
        weights = models.ResNet50_Weights.IMAGENET1K_V1
        _backbone = models.resnet50(weights=weights)
        _backbone.fc = nn.Identity()
        _backbone.eval()
        _prep = weights.transforms()

    if _tflite is None:
        _eras = [
            line.split("|", 1)[0].strip()
            for line in LABELS.read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
        _tflite = tf.lite.Interpreter(model_path=str(TFLITE))
        _tflite.allocate_tensors()

    return "Models ready."


def predict_pth(img: Image.Image) -> tuple[str, dict[str, float]]:
    assert _pth_head is not None and _backbone is not None and _prep is not None
    rgb = img.convert("RGB")
    with torch.no_grad():
        feat = _backbone(_prep(rgb).unsqueeze(0))
        logits = _pth_head(feat)[0]
        probs = F.softmax(logits, dim=0).tolist()
    labels = ["Not Impressionism", "Impressionism"]
    scores = {labels[i]: float(probs[i]) for i in range(2)}
    top = max(scores, key=scores.get)
    return f"{top} ({scores[top]*100:.1f}%)", scores


def predict_tflite(img: Image.Image) -> tuple[str, dict[str, float]]:
    assert _tflite is not None and _eras
    inp = _tflite.get_input_details()[0]
    out = _tflite.get_output_details()[0]
    h, w = int(inp["shape"][1]), int(inp["shape"][2])
    arr = np.asarray(
        img.convert("RGB").resize((w, h), Image.Resampling.BILINEAR),
        dtype=np.float32,
    )[None, ...] / 255.0
    _tflite.set_tensor(inp["index"], arr)
    _tflite.invoke()
    logits = _tflite.get_tensor(out["index"])[0].astype(np.float32)
    if logits.min() < 0 or abs(float(logits.sum()) - 1.0) > 0.05:
        e = np.exp(logits - logits.max())
        probs = e / e.sum()
    else:
        probs = logits
    scores = {_eras[i]: float(probs[i]) for i in range(len(_eras))}
    top = max(scores, key=scores.get)
    return f"{top} ({scores[top]*100:.1f}%)", scores


def run(img: Image.Image | None):
    if img is None:
        return "Upload an image first.", {}, "Upload an image first.", {}
    load_models()
    pth_text, pth_scores = predict_pth(img)
    era_text, era_scores = predict_tflite(img)
    return pth_text, pth_scores, era_text, era_scores


def main() -> None:
    load_models()
    with gr.Blocks(title="Art Era — model tryout") as demo:
        gr.Markdown(
            "## Try both models\n"
            "**Left:** your `.pth` binary Impressionism detector (ResNet50 + MLP)\n\n"
            "**Right:** current app TFLite 8-era classifier\n\n"
            "This does not change the APK — it’s a local sandbox."
        )
        with gr.Row():
            image = gr.Image(type="pil", label="Painting photo")
        with gr.Row():
            btn = gr.Button("Classify", variant="primary")
        with gr.Row():
            with gr.Column():
                gr.Markdown("### .pth (Impressionism?)")
                pth_label = gr.Textbox(label="Prediction", interactive=False)
                pth_bar = gr.Label(label="Scores", num_top_classes=2)
            with gr.Column():
                gr.Markdown("### TFLite (art era)")
                era_label = gr.Textbox(label="Prediction", interactive=False)
                era_bar = gr.Label(label="Scores", num_top_classes=8)
        btn.click(run, inputs=[image], outputs=[pth_label, pth_bar, era_label, era_bar])
        image.change(run, inputs=[image], outputs=[pth_label, pth_bar, era_label, era_bar])

    demo.launch(server_name="127.0.0.1", server_port=7860, share=False)


if __name__ == "__main__":
    main()
