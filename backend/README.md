# Art Era backend

Heavy models run here; the Flutter app is a thin client.

## Models
- **Era:** `prithivMLmods/WikiArt-Style` → mapped to 8 eras
- **Artist:** OpenAI CLIP zero-shot among Monet / Renoir / Degas / Pissarro

## Run
```bash
cd /home/lenovo/Impressionism
# optional: export HF_TOKEN=...
python3 -m uvicorn backend.main:app --host 0.0.0.0 --port 8008
```

Health: `http://YOUR_LAN_IP:8008/api/health`  
Classify: `POST /api/classify` (multipart `file`)

## Point the app at this machine
```bash
flutter build apk --release --split-per-abi \
  --dart-define=API_BASE=http://192.168.1.112:8008
```

Phone and PC must be on the same Wi‑Fi. First CLIP download can take several minutes; era classification works as soon as the style model is loaded.
