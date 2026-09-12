#!/usr/bin/env python3
"""Resiliently download huggan/wikiart parquet shards into tools/data/wikiart_shards."""

from __future__ import annotations

import os
import shutil
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tools" / "data" / "wikiart_shards"
ENV = ROOT / ".env"


def load_dotenv() -> None:
    if not ENV.exists():
        return
    for raw in ENV.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def main() -> None:
    load_dotenv()
    token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
    start = int(os.environ.get("SHARD_START", "2"))
    end = int(os.environ.get("SHARD_END", "20"))  # exclusive
    min_bytes = 80_000_000
    OUT.mkdir(parents=True, exist_ok=True)

    from huggingface_hub import hf_hub_download

    print(f"Downloading shards {start}..{end - 1} → {OUT} (token={'yes' if token else 'no'})", flush=True)
    for i in range(start, end):
        fname = f"train-{i:05d}-of-00072.parquet"
        dest = OUT / fname
        if dest.exists() and dest.stat().st_size >= min_bytes:
            print(f"  have {fname} ({dest.stat().st_size / 1e6:.0f} MB)", flush=True)
            continue
        for attempt in range(1, 6):
            print(f"  download {fname} attempt {attempt}/5 …", flush=True)
            try:
                path = hf_hub_download(
                    "huggan/wikiart",
                    f"data/{fname}",
                    repo_type="dataset",
                    token=token,
                )
                shutil.copy2(path, dest)
                size = dest.stat().st_size
                if size < min_bytes:
                    print(f"  too small ({size}); retry", flush=True)
                    dest.unlink(missing_ok=True)
                    time.sleep(5 * attempt)
                    continue
                print(f"  ok {fname} ({size / 1e6:.0f} MB)", flush=True)
                break
            except Exception as exc:
                print(f"  fail: {exc}", flush=True)
                dest.unlink(missing_ok=True)
                time.sleep(8 * attempt)
        else:
            print(f"  SKIP {fname} after retries", flush=True)

    shards = sorted(OUT.glob("train-*-of-00072.parquet"))
    print("done:", [(p.name, f"{p.stat().st_size / 1e6:.0f}MB") for p in shards], flush=True)


if __name__ == "__main__":
    main()
