#!/usr/bin/env python3
"""Politely top up weak era caches from Commons."""
from __future__ import annotations

import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
os.chdir(ROOT)
os.environ.setdefault("SKIP_WIKIART", "1")

import train_era_model as t  # noqa: E402

TARGET = 40
WEAK_MIN = 25


def main() -> None:
    buckets = t.load_cache()
    print("before", {k: len(buckets[k]) for k in t.ERAS}, flush=True)
    weak = [e for e in t.ERAS if len(buckets[e]) < WEAK_MIN]
    for era in weak:
        for name in t.FILES.get(era, []):
            if len(buckets[era]) >= TARGET:
                break
            raw = t.http_get(t.commons_url(name))
            if not raw:
                continue
            arr = t.decode(raw)
            if arr is None:
                continue
            buckets[era].append(arr)
            t.save_cache(era, arr)
            print(f"  {era}: {len(buckets[era])} named", flush=True)
        for cat in t.ERA_CATEGORIES.get(era, []):
            if len(buckets[era]) >= TARGET:
                break
            urls = t.commons_category_titles(cat, TARGET - len(buckets[era]))
            print(f"  {era}/{cat}: {len(urls)} urls", flush=True)
            for u in urls:
                if len(buckets[era]) >= TARGET:
                    break
                raw = t.http_get(u)
                if not raw:
                    time.sleep(3)
                    continue
                arr = t.decode(raw)
                if arr is None:
                    continue
                buckets[era].append(arr)
                t.save_cache(era, arr)
            print(f"  {era} now {len(buckets[era])}", flush=True)
            time.sleep(2)
    print("after", {k: len(buckets[k]) for k in t.ERAS}, flush=True)


if __name__ == "__main__":
    main()
