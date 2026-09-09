#!/usr/bin/env python3
"""Art Era backend — heavy vision models over HTTP."""

from __future__ import annotations

import base64
import io
import os
import threading
from typing import Any

import torch
import torch.nn.functional as F
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
from pydantic import BaseModel

STYLE_MODEL_ID = os.environ.get("STYLE_MODEL_ID", "prithivMLmods/WikiArt-Style")
CLIP_MODEL_ID = os.environ.get("CLIP_MODEL_ID", "openai/clip-vit-base-patch32")
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

ERA_YEARS = {
    "Renaissance": "c. 1400–1600",
    "Baroque": "c. 1600–1750",
    "Romanticism": "c. 1800–1850",
    "Realism": "c. 1840–1880",
    "Impressionism": "c. 1860–1890",
    "Post-Impressionism": "c. 1886–1905",
    "Modern": "c. 1900–1945",
    "Contemporary": "c. 1945–today",
}
ERAS = list(ERA_YEARS.keys())

STYLE_TO_ERA: dict[str, str] = {
    # Renaissance
    "early_renaissance": "Renaissance",
    "high_renaissance": "Renaissance",
    "northern_renaissance": "Renaissance",
    "mannerism_(late_renaissance)": "Renaissance",
    "proto_renaissance": "Renaissance",
    "renaissance": "Renaissance",
    "byzantine": "Renaissance",
    "gothic": "Renaissance",
    "international_gothic": "Renaissance",
    "mosan_art": "Renaissance",
    "romanesque": "Renaissance",
    # Baroque
    "baroque": "Baroque",
    "rococo": "Baroque",
    "neo_baroque": "Baroque",
    "neo_rococo": "Baroque",
    "tenebrism": "Baroque",
    "biedermeier": "Baroque",
    "classicism": "Baroque",
    "neoclassicism": "Baroque",
    # Romanticism
    "romanticism": "Romanticism",
    "neo_romanticism": "Romanticism",
    "orientalism": "Romanticism",
    # Realism
    "realism": "Realism",
    "naturalism": "Realism",
    "academicism": "Realism",
    "american_realism": "Realism",
    "social_realism": "Realism",
    "socialist_realism": "Realism",
    "regionalism": "Realism",
    "costumbrismo": "Realism",
    "luminism": "Realism",
    "tonalism": "Realism",
    "verism": "Realism",
    # Impressionism
    "impressionism": "Impressionism",
    "intimism": "Impressionism",
    "japonism": "Impressionism",
    # Post-Impressionism
    "post_impressionism": "Post-Impressionism",
    "pointillism": "Post-Impressionism",
    "divisionism": "Post-Impressionism",
    "symbolism": "Post-Impressionism",
    "cloisonnism": "Post-Impressionism",
    "synthetism": "Post-Impressionism",
    "nabis": "Post-Impressionism",
    # Modern
    "art_nouveau_(modern)": "Modern",
    "art_nouveau": "Modern",
    "modernismo": "Modern",
    "cubism": "Modern",
    "analytical_cubism": "Modern",
    "synthetic_cubism": "Modern",
    "mechanistic_cubism": "Modern",
    "expressionism": "Modern",
    "fauvism": "Modern",
    "futurism": "Modern",
    "dada": "Modern",
    "surrealism": "Modern",
    "suprematism": "Modern",
    "constructivism": "Modern",
    "neoplasticism": "Modern",
    "orphism": "Modern",
    "purism": "Modern",
    "metaphysical_art": "Modern",
    "precisionism": "Modern",
    "art_deco": "Modern",
    "ukiyo_e": "Modern",
    "naïve_art_(primitivism)": "Modern",
    "primitivism": "Modern",
    # Contemporary
    "abstract_art": "Contemporary",
    "abstract_expressionism": "Contemporary",
    "action_painting": "Contemporary",
    "color_field_painting": "Contemporary",
    "contemporary_realism": "Contemporary",
    "minimalism": "Contemporary",
    "pop_art": "Contemporary",
    "new_realism": "Contemporary",
    "conceptual_art": "Contemporary",
    "op_art": "Contemporary",
    "street_art": "Contemporary",
    "photorealism": "Contemporary",
    "hyper_realism": "Contemporary",
    "neo_expressionism": "Contemporary",
    "lyrical_abstraction": "Contemporary",
    "art_informel": "Contemporary",
    "tachisme": "Contemporary",
    "hard_edge_painting": "Contemporary",
    "post_minimalism": "Contemporary",
    "kinetic_art": "Contemporary",
    "environmental_(land)_art": "Contemporary",
}

ARTISTS = [
    "Claude Monet",
    "Pierre-Auguste Renoir",
    "Edgar Degas",
    "Camille Pissarro",
]

style_processor = None
style_model = None
clip_processor = None
clip_model = None
_clip_error: str | None = None
_lock = threading.Lock()

app = FastAPI(
    title="Art Era API",
    description="Server-side era + Impressionist artist classification",
    version="2.0.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Base64PredictRequest(BaseModel):
    image_base64: str


def _norm(label: str) -> str:
    return (
        label.strip()
        .lower()
        .replace("-", "_")
        .replace(" ", "_")
        .replace("/", "_")
    )


def style_to_era(style: str) -> str | None:
    key = _norm(style)
    if key in STYLE_TO_ERA:
        return STYLE_TO_ERA[key]
    for needle, era in STYLE_TO_ERA.items():
        if needle in key or key in needle:
            return era
    return None


def load_style_model() -> None:
    global style_processor, style_model
    from transformers import AutoImageProcessor, AutoModelForImageClassification

    print(f"Loading style model {STYLE_MODEL_ID}…", flush=True)
    style_processor = AutoImageProcessor.from_pretrained(STYLE_MODEL_ID)
    style_model = AutoModelForImageClassification.from_pretrained(STYLE_MODEL_ID)
    style_model.to(DEVICE).eval()
    print(f"Style model ready ({len(style_model.config.id2label)} classes)", flush=True)


def load_clip_model() -> None:
    global clip_processor, clip_model, _clip_error
    from transformers import CLIPModel, CLIPProcessor

    try:
        print(f"Loading CLIP {CLIP_MODEL_ID}…", flush=True)
        clip_processor = CLIPProcessor.from_pretrained(CLIP_MODEL_ID)
        clip_model = CLIPModel.from_pretrained(CLIP_MODEL_ID)
        clip_model.to(DEVICE).eval()
        _clip_error = None
        print("CLIP ready", flush=True)
    except Exception as exc:
        _clip_error = str(exc)
        clip_processor = None
        clip_model = None
        print(f"CLIP failed: {exc}", flush=True)


def predict_eras(img: Image.Image) -> list[dict[str, Any]]:
    if style_model is None or style_processor is None:
        raise HTTPException(status_code=503, detail="Style model not loaded")

    inputs = style_processor(images=img, return_tensors="pt")
    inputs = {k: v.to(DEVICE) for k, v in inputs.items()}
    with torch.no_grad():
        logits = style_model(**inputs).logits[0]
        probs = F.softmax(logits, dim=-1)

    id2label = style_model.config.id2label
    # Use only top styles — summing all 137 classes over-weights Contemporary.
    topk = torch.topk(probs, k=min(12, probs.numel()))
    era_scores = {era: 0.0 for era in ERAS}
    for score, idx in zip(topk.values.tolist(), topk.indices.tolist()):
        label = id2label[idx] if isinstance(id2label, dict) else id2label[idx]
        era = style_to_era(str(label))
        if era is None:
            continue
        era_scores[era] += float(score)

    # Strong bonus for the single top style's era.
    top_label = id2label[int(topk.indices[0])] if isinstance(id2label, dict) else id2label[int(topk.indices[0])]
    top_era = style_to_era(str(top_label))
    if top_era is not None:
        era_scores[top_era] += float(topk.values[0]) * 0.75

    total = sum(era_scores.values()) or 1.0
    return sorted(
        (
            {
                "era": era,
                "years": ERA_YEARS[era],
                "score": score / total,
                "percentage": round(100.0 * score / total, 1),
            }
            for era, score in era_scores.items()
        ),
        key=lambda x: x["score"],
        reverse=True,
    )


def predict_artist(img: Image.Image) -> list[dict[str, Any]]:
    if clip_model is None or clip_processor is None:
        raise HTTPException(
            status_code=503,
            detail=f"CLIP not ready yet ({_clip_error or 'still loading'})",
        )

    prompts = [f"a painting by {name}, fine art oil painting" for name in ARTISTS]
    inputs = clip_processor(
        text=prompts,
        images=img,
        return_tensors="pt",
        padding=True,
    )
    inputs = {k: v.to(DEVICE) for k, v in inputs.items()}
    with torch.no_grad():
        out = clip_model(**inputs)
        probs = out.logits_per_image.softmax(dim=1)[0]

    return sorted(
        (
            {
                "artist": ARTISTS[i],
                "score": float(probs[i]),
                "percentage": round(100.0 * float(probs[i]), 1),
            }
            for i in range(len(ARTISTS))
        ),
        key=lambda x: x["score"],
        reverse=True,
    )


def classify(img: Image.Image) -> dict[str, Any]:
    if img.mode != "RGB":
        img = img.convert("RGB")
    img.thumbnail((768, 768), Image.Resampling.LANCZOS)

    eras = predict_eras(img)
    artists: list[dict[str, Any]] = []
    top_artist: dict[str, Any] | None = None
    try:
        artists = predict_artist(img)
        top_artist = artists[0]
    except HTTPException:
        artists = []
        top_artist = None

    top_era = eras[0]
    if (
        top_artist is not None
        and top_era["era"] == "Post-Impressionism"
        and top_artist["score"] >= 0.35
    ):
        imp = next(e for e in eras if e["era"] == "Impressionism")
        post = top_era
        if post["score"] - imp["score"] < 0.25:
            eras = [imp] + [e for e in eras if e["era"] != "Impressionism"]
            top_era = eras[0]

    return {
        "era": top_era["era"],
        "years": top_era["years"],
        "confidence": round(top_era["score"], 4),
        "confidence_percent": round(top_era["percentage"]),
        "top_eras": eras[:3],
        "artist": top_artist["artist"] if top_artist else None,
        "artist_confidence": round(top_artist["score"], 4) if top_artist else None,
        "artist_confidence_percent": round(top_artist["percentage"]) if top_artist else None,
        "top_artists": artists[:3],
        "backend": {
            "style_model": STYLE_MODEL_ID,
            "artist_model": CLIP_MODEL_ID if clip_model else None,
            "device": DEVICE,
            "clip_ready": clip_model is not None,
        },
    }


def _load_image_bytes(data: bytes) -> Image.Image:
    try:
        return Image.open(io.BytesIO(data))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid image: {exc}") from exc


@app.on_event("startup")
def _startup() -> None:
    print(f"Device: {DEVICE}", flush=True)
    load_style_model()

    def _bg() -> None:
        with _lock:
            load_clip_model()

    threading.Thread(target=_bg, daemon=True).start()


@app.get("/api/health")
def health() -> dict[str, Any]:
    return {
        "status": "online" if style_model is not None else "degraded",
        "style_model": STYLE_MODEL_ID,
        "artist_model": CLIP_MODEL_ID,
        "clip_ready": clip_model is not None,
        "clip_error": _clip_error,
        "device": DEVICE,
        "eras": ERAS,
        "artists": ARTISTS,
    }


@app.post("/api/classify")
async def classify_file(file: UploadFile = File(...)) -> dict[str, Any]:
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty upload")
    return classify(_load_image_bytes(data))


@app.post("/api/classify-base64")
async def classify_base64(req: Base64PredictRequest) -> dict[str, Any]:
    b64 = req.image_base64
    if "," in b64:
        b64 = b64.split(",", 1)[1]
    try:
        data = base64.b64decode(b64)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Bad base64: {exc}") from exc
    return classify(_load_image_bytes(data))


@app.post("/api/predict")
async def predict_file(file: UploadFile = File(...)) -> dict[str, Any]:
    return await classify_file(file)


@app.post("/api/predict-base64")
async def predict_base64(req: Base64PredictRequest) -> dict[str, Any]:
    return await classify_base64(req)


if __name__ == "__main__":
    import uvicorn

    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", "8008"))
    uvicorn.run(app, host=host, port=port)
