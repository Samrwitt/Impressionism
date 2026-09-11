#!/usr/bin/env python3
"""Train a dedicated Impressionism vs Post-Impressionism binary TFLite model.

Memory-safe: keeps uint8 uniques in RAM and augments on the fly.
Used by the app as a tiebreaker when the 8-era model is unsure between those two.
"""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
# Cap TF CPU thread pools a bit so we leave headroom on 8GB machines.
os.environ.setdefault("TF_NUM_INTEROP_THREADS", "2")
os.environ.setdefault("TF_NUM_INTRAOP_THREADS", "4")

import numpy as np
from PIL import Image
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "models"
CACHE = ROOT / "tools" / "data" / "era_cache"
IMG_SIZE = 192
SEED = 42
MOBILENET_ALPHA = 1.0
AUG_PER = 6
BATCH = 12

LABELS = ["Impressionism", "Post-Impressionism"]


def load_era(era: str) -> list[np.ndarray]:
    folder = CACHE / era
    out: list[np.ndarray] = []
    if not folder.exists():
        return out
    for path in sorted(folder.glob("*.jpg")):
        try:
            rgb = Image.open(path).convert("RGB").resize(
                (IMG_SIZE, IMG_SIZE), Image.Resampling.BILINEAR
            )
            out.append(np.asarray(rgb, dtype=np.uint8))
        except Exception:
            continue
    return out


def augment(img: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    out = img.astype(np.float32)
    if rng.random() < 0.5:
        out = np.fliplr(out)
    if rng.random() < 0.25:
        out = np.rot90(out, int(rng.integers(1, 4)))
    out = np.clip(out * rng.uniform(0.7, 1.3) + rng.uniform(-25, 25), 0, 255)
    if rng.random() < 0.45:
        out = np.roll(out, int(rng.integers(-14, 15)), axis=1)
    if rng.random() < 0.45:
        out = np.roll(out, int(rng.integers(-14, 15)), axis=0)
    if rng.random() < 0.55:
        m = int(rng.integers(4, 22))
        cropped = out[m : IMG_SIZE - m, m : IMG_SIZE - m]
        cropped = np.array(
            Image.fromarray(cropped.astype(np.uint8)).resize(
                (IMG_SIZE, IMG_SIZE), Image.Resampling.BILINEAR
            )
        )
        out = cropped.astype(np.float32)
    if rng.random() < 0.35:
        out = np.clip(out + rng.uniform(-18, 18, size=(1, 1, 3)), 0, 255)
    return out.astype(np.uint8)


class ImageSeq(keras.utils.Sequence):
    """Yield float32 batches from uint8 uniques + on-the-fly augs."""

    def __init__(
        self,
        imgs: list[np.ndarray],
        labels: list[int],
        batch_size: int,
        aug_per: int,
        shuffle: bool,
        seed: int,
    ):
        self.imgs = imgs
        self.labels = np.asarray(labels, dtype=np.int32)
        self.batch_size = batch_size
        self.aug_per = aug_per
        self.shuffle = shuffle
        self.rng = np.random.default_rng(seed)
        # index into (unique_i, aug_k) where aug_k=0 is original
        self.pairs = [(i, k) for i in range(len(imgs)) for k in range(aug_per + 1)]
        self.on_epoch_end()

    def __len__(self) -> int:
        return max(1, int(np.ceil(len(self.pairs) / self.batch_size)))

    def on_epoch_end(self) -> None:
        if self.shuffle:
            self.rng.shuffle(self.pairs)

    def __getitem__(self, idx: int):
        chunk = self.pairs[idx * self.batch_size : (idx + 1) * self.batch_size]
        xs = np.empty((len(chunk), IMG_SIZE, IMG_SIZE, 3), dtype=np.float32)
        ys = np.empty((len(chunk),), dtype=np.int32)
        for j, (i, k) in enumerate(chunk):
            im = self.imgs[i]
            if k == 0:
                arr = im
            else:
                arr = augment(im, self.rng)
            xs[j] = arr.astype(np.float32) / 255.0
            ys[j] = self.labels[i]
        return xs, ys


def build_model() -> tuple[keras.Model, keras.Model]:
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
    x = layers.Dropout(0.45)(x)
    x = layers.Dense(128, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    outputs = layers.Dense(2, name="logits")(x)
    return keras.Model(inputs, outputs, name="imp_post"), base


def export_tflite(model: keras.Model, calib_imgs: list[np.ndarray]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "imp_post_labels.txt").write_text(
        "\n".join(LABELS) + "\n", encoding="utf-8"
    )

    def rep_data():
        n = min(48, len(calib_imgs))
        for i in range(n):
            x = calib_imgs[i].astype(np.float32)[None, ...] / 255.0
            yield [x]

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = rep_data
    out = OUT_DIR / "imp_post_model.tflite"
    out.write_bytes(converter.convert())
    print(f"wrote {out} ({out.stat().st_size / 1024:.0f} KB)", flush=True)


def main() -> None:
    tf.random.set_seed(SEED)
    rng = np.random.default_rng(SEED)

    imp = load_era("Impressionism")
    post = load_era("Post-Impressionism")
    print(f"loaded Imp={len(imp)} Post={len(post)}", flush=True)
    if len(imp) < 20 or len(post) < 20:
        raise RuntimeError("Need more Imp/Post cache images before training.")

    n = min(len(imp), len(post))
    n_imp = min(len(imp), max(n, int(n * 1.15)))
    n_post = min(len(post), n)
    imp = [imp[i] for i in rng.permutation(len(imp))[:n_imp]]
    post = [post[i] for i in rng.permutation(len(post))[:n_post]]
    print(f"balanced uniques Imp={len(imp)} Post={len(post)}", flush=True)

    def split(samples: list[np.ndarray]):
        order = rng.permutation(len(samples))
        samples = [samples[i] for i in order]
        n_val = max(4, int(round(len(samples) * 0.2)))
        return samples[n_val:], samples[:n_val]

    imp_tr, imp_va = split(imp)
    post_tr, post_va = split(post)

    train_imgs = imp_tr + post_tr
    train_y = [0] * len(imp_tr) + [1] * len(post_tr)
    val_imgs = imp_va + post_va
    val_y = [0] * len(imp_va) + [1] * len(post_va)

    # Slightly more augs for scarcer Post class via oversampling uniques in list.
    # (Post already balanced by unique count; keep equal AUG_PER.)
    train_seq = ImageSeq(train_imgs, train_y, BATCH, AUG_PER, True, SEED)
    val_seq = ImageSeq(val_imgs, val_y, BATCH, 0, False, SEED + 1)

    counts = np.bincount(np.asarray(train_y), minlength=2).astype(np.float32)
    inv = counts.sum() / np.maximum(counts, 1.0)
    class_weight = {i: float(inv[i] / inv.mean()) for i in range(2)}
    class_weight[1] *= 1.25
    print(
        f"train_steps={len(train_seq)} val_steps={len(val_seq)} "
        f"class_weight={class_weight}",
        flush=True,
    )

    model, base = build_model()
    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=4, restore_best_weights=True
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=2, min_lr=1e-7
        ),
    ]
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=["accuracy"],
    )
    print("Training Imp↔Post head…", flush=True)
    model.fit(
        train_seq,
        validation_data=val_seq,
        epochs=16,
        class_weight=class_weight,
        callbacks=callbacks,
        verbose=2,
    )

    base.trainable = True
    for layer in base.layers[:-80]:
        layer.trainable = False
    model.compile(
        optimizer=keras.optimizers.Adam(5e-6),
        loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=["accuracy"],
    )
    print("Fine-tuning Imp↔Post…", flush=True)
    model.fit(
        train_seq,
        validation_data=val_seq,
        epochs=10,
        class_weight=class_weight,
        callbacks=callbacks,
        verbose=2,
    )

    # Evaluate on unique val images only (no aug).
    x_val = np.stack([im.astype(np.float32) / 255.0 for im in val_imgs])
    y_val = np.asarray(val_y, dtype=np.int32)
    _, acc = model.evaluate(x_val, y_val, verbose=0)
    preds = np.argmax(model.predict(x_val, verbose=0), axis=1)
    tp_imp = int(np.sum((y_val == 0) & (preds == 0)))
    fn_imp = int(np.sum((y_val == 0) & (preds == 1)))
    tp_post = int(np.sum((y_val == 1) & (preds == 1)))
    fn_post = int(np.sum((y_val == 1) & (preds == 0)))
    print(f"held-out binary accuracy: {acc:.3f}", flush=True)
    print(
        f"confusion Imp→Imp={tp_imp} Imp→Post={fn_imp} "
        f"Post→Post={tp_post} Post→Imp={fn_post}",
        flush=True,
    )
    export_tflite(model, val_imgs)
    del x_val


if __name__ == "__main__":
    main()
