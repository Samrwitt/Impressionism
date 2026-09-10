#!/usr/bin/env python3
"""Train a 4-artist Impressionist classifier and export quantized TFLite."""

from __future__ import annotations

import io
import os
from collections import defaultdict
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import numpy as np
import pyarrow.parquet as pq
from PIL import Image
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "models"
CACHE = ROOT / "tools" / "data" / "artist_cache"
SHARD_DIR = ROOT / "tools" / "data" / "wikiart_shards"
IMG_SIZE = 224
PER_ARTIST = 220
AUG_PER_UNIQUE = 5
SEED = 42
MOBILENET_ALPHA = 1.0

# Display name -> WikiArt artist id (huggan/wikiart ClassLabel index)
ARTISTS = [
    ("Claude Monet", 4),
    ("Pierre-Auguste Renoir", 17),
    ("Edgar Degas", 5),
    ("Camille Pissarro", 2),
]


def to_array(img: Image.Image) -> np.ndarray:
    rgb = img.convert("RGB").resize((IMG_SIZE, IMG_SIZE), Image.Resampling.BILINEAR)
    return np.asarray(rgb, dtype=np.uint8)


def decode_cell(cell) -> np.ndarray | None:
    try:
        if isinstance(cell, dict):
            raw = cell.get("bytes")
            if raw:
                return to_array(Image.open(io.BytesIO(bytes(raw))))
            path = cell.get("path")
            if path and Path(path).exists():
                return to_array(Image.open(path))
            return None
        if hasattr(cell, "convert"):
            return to_array(cell)
    except Exception:
        return None
    return None


def save_cache(artist: str, arr: np.ndarray) -> None:
    folder = CACHE / artist
    folder.mkdir(parents=True, exist_ok=True)
    existing = list(folder.glob("*.jpg"))
    next_idx = 1
    if existing:
        nums = []
        for p in existing:
            try:
                nums.append(int(p.stem))
            except ValueError:
                continue
        if nums:
            next_idx = max(nums) + 1
    Image.fromarray(arr).save(folder / f"{next_idx:04d}.jpg", quality=90)


def load_cache() -> dict[str, list[np.ndarray]]:
    buckets: dict[str, list[np.ndarray]] = defaultdict(list)
    for name, _ in ARTISTS:
        folder = CACHE / name
        if not folder.exists():
            continue
        for path in sorted(folder.glob("*.jpg")):
            try:
                buckets[name].append(to_array(Image.open(path)))
            except Exception:
                continue
    return buckets


def load_from_shards(buckets: dict[str, list[np.ndarray]]) -> dict[str, list[np.ndarray]]:
    id_to_name = {aid: name for name, aid in ARTISTS}
    shards = sorted(SHARD_DIR.glob("train-*-of-00072.parquet"))
    if not shards:
        print(f"No shards in {SHARD_DIR}", flush=True)
        return buckets

    print(f"Reading {len(shards)} WikiArt shards for artists…", flush=True)
    for shard in shards:
        if all(len(buckets[n]) >= PER_ARTIST for n, _ in ARTISTS):
            break
        print(f"  {shard.name}", flush=True)
        try:
            table = pq.read_table(shard, columns=["image", "artist"])
        except Exception as exc:
            print(f"  skip bad shard {shard.name}: {exc}", flush=True)
            continue
        artists = table.column("artist").to_pylist()
        images = table.column("image")
        for i, aid in enumerate(artists):
            name = id_to_name.get(int(aid))
            if name is None or len(buckets[name]) >= PER_ARTIST:
                continue
            arr = decode_cell(images[i].as_py())
            if arr is None:
                continue
            buckets[name].append(arr)
            save_cache(name, arr)
        print(" ", {n: len(buckets[n]) for n, _ in ARTISTS}, flush=True)
    return buckets


def augment(img: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    out = img.astype(np.float32)
    if rng.random() < 0.5:
        out = np.fliplr(out)
    out = np.clip(out * rng.uniform(0.8, 1.2) + rng.uniform(-15, 15), 0, 255)
    if rng.random() < 0.35:
        m = int(rng.integers(2, 12))
        cropped = out[m : IMG_SIZE - m, m : IMG_SIZE - m]
        cropped = np.array(
            Image.fromarray(cropped.astype(np.uint8)).resize(
                (IMG_SIZE, IMG_SIZE), Image.Resampling.BILINEAR
            )
        )
        out = cropped.astype(np.float32)
    return out.astype(np.uint8)


def pack(imgs: list[np.ndarray], label: int, rng: np.random.Generator, n_aug: int):
    xs, ys = [], []
    for im in imgs:
        xs.append(im.astype(np.float32) / 255.0)
        ys.append(label)
        for _ in range(n_aug):
            xs.append(augment(im, rng).astype(np.float32) / 255.0)
            ys.append(label)
    return xs, ys


def build_model(num_classes: int) -> tuple[keras.Model, keras.Model]:
    inputs = keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3), name="image")
    x = layers.Rescaling(2.0, offset=-1.0)(inputs)
    base = keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
        alpha=MOBILENET_ALPHA,
        pooling="avg",
    )
    base.trainable = False
    x = base(x, training=False)
    x = layers.Dropout(0.35)(x)
    outputs = layers.Dense(num_classes, name="logits")(x)
    return keras.Model(inputs, outputs, name="artist_mobilenet"), base


def export_tflite(model: keras.Model) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "artist_labels.txt").write_text(
        "\n".join(name for name, _ in ARTISTS) + "\n",
        encoding="utf-8",
    )

    def rep_data():
        for _ in range(40):
            yield [np.random.rand(1, IMG_SIZE, IMG_SIZE, 3).astype(np.float32)]

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = rep_data
    out = OUT_DIR / "artist_model.tflite"
    out.write_bytes(converter.convert())
    print(f"wrote {out} ({out.stat().st_size / 1024:.0f} KB)", flush=True)


def main() -> None:
    tf.random.set_seed(SEED)
    rng = np.random.default_rng(SEED)

    buckets = load_cache()
    print("cache", {n: len(buckets[n]) for n, _ in ARTISTS}, flush=True)
    buckets = load_from_shards(buckets)

    x_train, y_train, x_val, y_val = [], [], [], []
    for idx, (name, _) in enumerate(ARTISTS):
        samples = list(buckets[name])
        if len(samples) < 8:
            raise RuntimeError(f"Too few images for {name}: {len(samples)}")
        order = rng.permutation(len(samples))
        samples = [samples[i] for i in order]
        n_val = max(2, int(round(len(samples) * 0.2)))
        val_imgs, train_imgs = samples[:n_val], samples[n_val:]
        if len(train_imgs) > PER_ARTIST:
            train_imgs = train_imgs[:PER_ARTIST]
        tx, ty = pack(train_imgs, idx, rng, AUG_PER_UNIQUE)
        vx, vy = pack(val_imgs, idx, rng, 0)
        print(
            f"{name}: train_unique={len(train_imgs)} val_unique={len(val_imgs)} "
            f"train_aug={len(tx)}",
            flush=True,
        )
        x_train.extend(tx)
        y_train.extend(ty)
        x_val.extend(vx)
        y_val.extend(vy)

    x_train = np.stack(x_train)
    y_train = np.array(y_train, dtype=np.int32)
    x_val = np.stack(x_val)
    y_val = np.array(y_val, dtype=np.int32)
    perm = rng.permutation(len(x_train))
    x_train, y_train = x_train[perm], y_train[perm]

    model, base = build_model(len(ARTISTS))
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=["accuracy"],
    )
    print("Training artist head…", flush=True)
    model.fit(
        x_train, y_train, validation_data=(x_val, y_val), epochs=14, batch_size=24, verbose=2
    )

    base.trainable = True
    for layer in base.layers[:-50]:
        layer.trainable = False
    model.compile(
        optimizer=keras.optimizers.Adam(8e-6),
        loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=["accuracy"],
    )
    print("Fine-tuning…", flush=True)
    model.fit(
        x_train, y_train, validation_data=(x_val, y_val), epochs=10, batch_size=16, verbose=2
    )
    _, acc = model.evaluate(x_val, y_val, verbose=0)
    print(f"held-out artist accuracy: {acc:.3f}", flush=True)
    export_tflite(model)


if __name__ == "__main__":
    main()
