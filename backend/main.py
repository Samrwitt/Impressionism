import io
import base64
import torch
import torch.nn.functional as F
from PIL import Image
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
from transformers import AutoImageProcessor, AutoModelForImageClassification

MODEL_ID = "prithivMLmods/WikiArt-Style"

print(f"Loading model '{MODEL_ID}'...")
try:
    processor = AutoImageProcessor.from_pretrained(MODEL_ID)
    model = AutoModelForImageClassification.from_pretrained(MODEL_ID)
    model.eval()
    print("Model loaded successfully!")

except Exception as e:
    import traceback
    print(f"Error loading model: {e}")
    traceback.print_exc()
    processor = None
    model = None


app = FastAPI(
    title="Impressionism Art Style Classifier API",
    description="Backend service for classifying artwork style using prithivMLmods/WikiArt-Style model",
    version="1.0.0"
)

# Enable CORS for Flutter web / app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class Base64PredictRequest(BaseModel):
    image_base64: str

# Impressionism-related style descriptors for art analysis
IMPRESSIONISM_ANALYSIS = {
    "verdict_true": "Impressionist Artwork Detected",
    "verdict_false": "Non-Impressionist Style Detected",
    "impressionism_traits": [
        "Visible, rapid, textured brushstrokes capturing movement and atmosphere",
        "Focus on realistic depiction of light and its changing qualities",
        "Vibrant, unmixed color palette applied side-by-side (en plein air visual blending)",
        "Candid, ordinary subject matter with dynamic framing and open compositions"
    ],
    "post_impressionism_traits": [
        "Geometric forms, bold emotional colors, and structured expressionism",
        "Artistic evolution extending beyond natural light into personal expression"
    ]
}

def analyze_image(img: Image.Image):
    if model is None or processor is None:
        raise HTTPException(status_code=500, detail="Model is not loaded on server")

    # Convert RGBA to RGB if needed
    if img.mode != "RGB":
        img = img.convert("RGB")

    inputs = processor(images=img, return_tensors="pt")
    with torch.no_grad():
        outputs = model(**inputs)
        logits = outputs.logits
        probs = F.softmax(logits, dim=-1)[0]

    # Get id2label mapping
    id2label = model.config.id2label
    
    # Sort predictions by probability descending
    topk_probs, topk_indices = torch.topk(probs, k=min(10, len(id2label)))
    
    top_styles = []
    for score, idx in zip(topk_probs.tolist(), topk_indices.tolist()):
        style_name = id2label[idx]
        top_styles.append({
            "style": style_name,
            "score": round(score, 4),
            "percentage": round(score * 100, 2)
        })

    top_style = top_styles[0]["style"]
    top_score = top_styles[0]["score"]

    # Check Impressionism & Post-Impressionism scores
    impressionism_idx = model.config.label2id.get("Impressionism", 44)
    post_impressionism_idx = model.config.label2id.get("Post-Impressionism", 98)
    
    imp_score = probs[impressionism_idx].item()
    post_imp_score = probs[post_impressionism_idx].item()

    # Is Impressionist criteria: top style is Impressionism OR Impressionism score >= 0.25 (or combined with Post-Impressionism)
    is_impressionism = (top_style == "Impressionism") or (imp_score >= 0.25)
    
    # Combined impressionist score for confidence display
    primary_confidence = imp_score if imp_score > 0.1 else top_score

    verdict = "Authentic Impressionism" if is_impressionism else f"Not Impressionism ({top_style})"
    
    description = (
        f"This image strongly exhibits characteristics of {top_style} (Confidence: {round(top_score * 100, 1)}%). "
    )
    if is_impressionism:
        description += "The model identified classic Impressionist visual traits including vibrant light play, atmospheric depth, and expressive brushwork."
    else:
        description += f"While Impressionism accounted for {round(imp_score * 100, 1)}% of the visual features, the primary artistic classification is {top_style}."

    return {
        "is_impressionism": is_impressionism,
        "impressionism_score": round(imp_score, 4),
        "impressionism_percentage": round(imp_score * 100, 2),
        "post_impressionism_score": round(post_imp_score, 4),
        "top_style": top_style,
        "top_score": round(top_score, 4),
        "top_percentage": round(top_score * 100, 2),
        "top_styles": top_styles,
        "analysis": {
            "verdict": verdict,
            "description": description,
            "traits": IMPRESSIONISM_ANALYSIS["impressionism_traits"] if is_impressionism else [
                f"Primary style matched: {top_style}",
                f"Confidence level: {round(top_score * 100, 1)}%",
                "Lacks signature en-plein-air light diffusion of Impressionism"
            ]
        }
    }

@app.get("/api/health")
def health_check():
    return {
        "status": "online" if model is not None else "degraded",
        "model_id": MODEL_ID,
        "classes_count": len(model.config.id2label) if model else 0,
        "device": "cpu"
    }

@app.post("/api/predict")
async def predict_file(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        img = Image.open(io.BytesIO(contents))
        return analyze_image(img)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to process image: {str(e)}")

@app.post("/api/predict-base64")
async def predict_base64(req: Base64PredictRequest):
    try:
        # Strip header if present e.g. data:image/jpeg;base64,
        b64_data = req.image_base64
        if "," in b64_data:
            b64_data = b64_data.split(",", 1)[1]
        img_bytes = base64.b64decode(b64_data)
        img = Image.open(io.BytesIO(img_bytes))
        return analyze_image(img)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to decode base64 image: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8008)

