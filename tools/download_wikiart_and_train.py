#!/usr/bin/env python3
"""Download huggan/wikiart parquet shards with curl (resumable), then train."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

SHARD_DIR = ROOT / "tools" / "data" / "wikiart_shards"
REPO = "https://huggingface.co/datasets/huggan/wikiart/resolve/main"


def load_token() -> str:
    env_path = ROOT / ".env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            if line.startswith("HF_TOKEN="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN") or ""


def download_shard(index: int, token: str) -> Path:
    SHARD_DIR.mkdir(parents=True, exist_ok=True)
    name = f"train-{index:05d}-of-00072.parquet"
    dest = SHARD_DIR / name
    if dest.exists() and dest.stat().st_size > 100_000_000:
        print(f"already have {dest} ({dest.stat().st_size / 1e6:.0f} MB)", flush=True)
        return dest
    url = f"{REPO}/data/{name}"
    print(f"curl {name} …", flush=True)
    # Keep the token out of process argv (use a private curl config).
    with tempfile.NamedTemporaryFile("w", delete=False, prefix="hfcurl_", suffix=".cfg") as cfg:
        cfg.write(f'header = "Authorization: Bearer {token}"\n')
        cfg_path = Path(cfg.name)
    try:
        os.chmod(cfg_path, 0o600)
        cmd = [
            "curl",
            "-L",
            "--http1.1",
            "--retry",
            "8",
            "--retry-delay",
            "5",
            "-C",
            "-",
            "-K",
            str(cfg_path),
            "-o",
            str(dest),
            "--progress-bar",
            url,
        ]
        subprocess.check_call(cmd)
    finally:
        try:
            cfg_path.unlink(missing_ok=True)
        except Exception:
            pass
    print(f"saved {dest} ({dest.stat().st_size / 1e6:.0f} MB)", flush=True)
    return dest


def main() -> None:
    token = load_token()
    if not token:
        raise SystemExit("HF_TOKEN missing in .env")
    n = int(os.environ.get("WIKIART_MAX_SHARDS", "3"))
    for i in range(n):
        download_shard(i, token)

    # Train using local shards only (skip Commons rate limits).
    os.environ["HF_TOKEN"] = token
    os.environ["HUGGING_FACE_HUB_TOKEN"] = token
    os.environ["CACHE_ONLY"] = "1"
    os.environ["WIKIART_LOCAL_DIR"] = str(SHARD_DIR)
    os.environ["WIKIART_MAX_SHARDS"] = str(n)
    os.environ.pop("SKIP_WIKIART", None)
    import train_era_model as t

    t.main()


if __name__ == "__main__":
    main()
