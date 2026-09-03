#!/usr/bin/env python3
"""Train a tiny conv net for art eras and export JSON weights for Dart."""

from __future__ import annotations

import io
import json
import os
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import numpy as np
from PIL import Image
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "models"
CACHE = ROOT / "tools" / "data" / "era_cache"
IMG_SIZE = 48
PER_ERA = 72
SEED = 42

ERAS = [
    "Renaissance",
    "Baroque",
    "Romanticism",
    "Realism",
    "Impressionism",
    "Post-Impressionism",
    "Modern",
    "Contemporary",
]

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

STYLE_TO_ERA = {
    "Early_Renaissance": "Renaissance",
    "High_Renaissance": "Renaissance",
    "Northern_Renaissance": "Renaissance",
    "Mannerism_Late_Renaissance": "Renaissance",
    "Baroque": "Baroque",
    "Rococo": "Baroque",
    "Romanticism": "Romanticism",
    "Realism": "Realism",
    "Impressionism": "Impressionism",
    "Post_Impressionism": "Post-Impressionism",
    "Pointillism": "Post-Impressionism",
    "Symbolism": "Post-Impressionism",
    "Art_Nouveau": "Modern",
    "Cubism": "Modern",
    "Analytical_Cubism": "Modern",
    "Synthetic_Cubism": "Modern",
    "Expressionism": "Modern",
    "Fauvism": "Modern",
    "Abstract_Expressionism": "Contemporary",
    "Action_painting": "Contemporary",
    "Color_Field_Painting": "Contemporary",
    "Contemporary_Realism": "Contemporary",
    "Minimalism": "Contemporary",
    "Pop_Art": "Contemporary",
    "New_Realism": "Contemporary",
}

FILES = {
    "Renaissance": [
        "Mona Lisa, by Leonardo da Vinci, from C2RMF retouched.jpg",
        "Sandro Botticelli - La nascita di Venere - Google Art Project - edited.jpg",
        "Michelangelo - Creation of Adam (cropped).jpg",
        "The School of Athens.jpg",
        "Jan van Eyck - The Arnolfini Portrait - National Gallery, London.jpg",
        "Raphael - The Sistine Madonna - Google Art Project.jpg",
        "Albrecht Dürer - Adam and Eve (Prado).jpg",
        "Pieter Bruegel the Elder - The Tower of Babel (Vienna) - Google Art Project.jpg",
    ],
    "Baroque": [
        "The Nightwatch by Rembrandt.jpg",
        "Girl with a Pearl Earring.jpg",
        "Caravaggio - The Calling of Saint Matthew.jpg",
        "Rembrandt Harmensz. van Rijn - The Anatomy Lesson of Dr Nicolaes Tulp.jpg",
        "The Swing (Fragonard).jpg",
        "Las Meninas, by Diego Velázquez, from Prado in Google Earth.jpg",
        "The Entombment of Christ-Caravaggio (c.1602-3).jpg",
        "Watteau, Antoine - The Embarkation for Cythera.jpg",
    ],
    "Romanticism": [
        "Eugène Delacroix - Le 28 Juillet. La Liberté guidant le peuple.jpg",
        "Caspar David Friedrich - Wanderer above the sea of fog.jpg",
        "Théodore Géricault - The Raft of the Medusa.jpg",
        "The Fighting Temeraire, JMW Turner, National Gallery.jpg",
        "John Constable The Hay Wain.jpg",
        "Saturn devouring his son.jpg",
        "Caspar David Friedrich - The Abbey in the Oakwood.jpg",
        "Joseph Mallord William Turner - Fishermen at Sea - Google Art Project.jpg",
    ],
    "Realism": [
        "Jean-François Millet - Gleaners - Google Art Project 2.jpg",
        "Edouard Manet - Luncheon on the Grass - Google Art Project.jpg",
        "Edouard Manet, A Bar at the Folies-Bergère.jpg",
        "Jean-François Millet Angelus.jpg",
        "Ilya Repin - Barge Haulers on the Volga - Google Art Project.jpg",
        "Winslow Homer - The Gulf Stream - Metropolitan Museum of Art.jpg",
        "Honoré Daumier - The Third-Class Carriage - Google Art Project.jpg",
        "Gustave Courbet - A Burial at Ornans - Musée d'Orsay.jpg",
    ],
    "Impressionism": [
        "Claude Monet, Impression, soleil levant.jpg",
        "Claude Monet - Water Lilies - 1906, Ryerson.jpg",
        "Claude Monet - Haystacks, end of Summer.jpg",
        "Claude Monet - The Magpie - Google Art Project.jpg",
        "Pierre-Auguste Renoir, Le Moulin de la Galette.jpg",
        "Pierre-Auguste Renoir - Luncheon of the Boating Party - Google Art Project.jpg",
        "Edgar Degas - The Ballet Class - Google Art Project.jpg",
        "Camille Pissarro - Boulevard Montmartre, Spring.jpg",
    ],
    "Post-Impressionism": [
        "Van Gogh - Starry Night - Google Art Project.jpg",
        "Vincent van Gogh - Sunflowers - VGM F458.jpg",
        "Paul Cézanne, The Card Players, 1892-93.jpg",
        "Mont Sainte-Victoire, by Paul Cézanne.jpg",
        "A Sunday on La Grande Jatte, Georges Seurat, 1884.jpg",
        "Vincent van Gogh - Wheatfield with Crows.jpg",
        "Paul Gauguin - When Will You Marry? - Google Art Project.jpg",
        "Vincent van Gogh - The Bedroom - Google Art Project.jpg",
    ],
    "Modern": [
        "Vassily Kandinsky, 1913 - Composition 7.jpg",
        "Franz Marc-The Dream-1912.jpg",
        "Robert Delaunay, 1912-13, Premier Disque.jpg",
        "Umberto Boccioni - Unique Forms of Continuity in Space.jpg",
        "Gino Severini, 1912, Dynamic Hieroglyphic of the Bal Tabarin.jpg",
        "Piet Mondriaan, 1930 - Mondrian Composition II in Red, Blue, and Yellow.jpg",
        "Kazimir Malevich, 1915, Black Suprematic Square, oil on linen canvas, 79.5 x 79.5 cm, Tretyakov Gallery, Moscow.jpg",
        "Theo van Doesburg Composition VII (the three graces).jpg",
    ],
    "Contemporary": [
        "Nighthawks by Edward Hopper 1942.jpg",
        "Grant Wood - American Gothic - Google Art Project.jpg",
        "Christina's World.jpg",
        "Edward Hopper - Automat.jpg",
        "Georgia O'Keeffe, Red Canna, 1924.jpg",
        "René Magritte - The Treachery of Images.jpg",
        "Andrew Wyeth Christina's World.jpg",
        "Edward Hopper, Cape Cod Morning, 1950.jpg",
    ],
}


def commons_url(filename: str) -> str:
    return (
        "https://commons.wikimedia.org/wiki/Special:FilePath/"
        + urllib.parse.quote(filename)
        + "?width=640"
    )


def to_array(img: Image.Image) -> np.ndarray:
    rgb = img.convert("RGB").resize((IMG_SIZE, IMG_SIZE), Image.Resampling.BILINEAR)
    return np.asarray(rgb, dtype=np.uint8)


def decode(raw: bytes) -> np.ndarray | None:
    try:
        return to_array(Image.open(io.BytesIO(raw)))
    except Exception:
        return None


def http_get(url: str) -> bytes | None:
    req = urllib.request.Request(url, headers={"User-Agent": "ArtEraTrainer/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            return resp.read()
    except Exception as exc:
        print(f"  skip: {exc}")
        return None


def save_cache(era: str, idx: int, arr: np.ndarray) -> None:
    folder = CACHE / era
    folder.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr).save(folder / f"{idx:04d}.jpg", quality=90)


def load_cache() -> dict[str, list[np.ndarray]]:
    buckets: dict[str, list[np.ndarray]] = defaultdict(list)
    if not CACHE.exists():
        return buckets
    for era in ERAS:
        folder = CACHE / era
        if not folder.exists():
            continue
        for path in sorted(folder.glob("*.jpg")):
            try:
                buckets[era].append(to_array(Image.open(path)))
            except Exception:
                continue
    return buckets


def load_wikiart(buckets: dict[str, list[np.ndarray]]) -> dict[str, list[np.ndarray]]:
    if os.environ.get("SKIP_WIKIART") == "1":
        print("SKIP_WIKIART=1 — using Commons + cache only")
        return buckets
    try:
        from datasets import load_dataset
    except ImportError:
        print("datasets not installed; skipping WikiArt stream")
        return buckets
    print("Streaming WikiArt…", flush=True)
    try:
        ds = load_dataset("huggan/wikiart", split="train", streaming=True)
        names = ds.features["style"].names
    except Exception as exc:
        print(f"WikiArt unavailable ({exc})")
        return buckets
    seen = 0
    for row in ds:
        seen += 1
        if all(len(buckets[e]) >= PER_ERA for e in ERAS) or seen > 12000:
            break
        try:
            era = STYLE_TO_ERA.get(names[int(row["style"])])
        except Exception:
            continue
        if era is None or len(buckets[era]) >= PER_ERA:
            continue
        try:
            arr = to_array(row["image"])
        except Exception:
            continue
        buckets[era].append(arr)
        save_cache(era, len(buckets[era]), arr)
        if seen % 400 == 0:
            print("  ", {k: len(v) for k, v in buckets.items()})
    return buckets


def load_wikimedia(buckets: dict[str, list[np.ndarray]]) -> dict[str, list[np.ndarray]]:
    print("Downloading Commons examples…")
    for era, names in FILES.items():
        for name in names:
            if len(buckets[era]) >= PER_ERA:
                break
            raw = http_get(commons_url(name))
            if not raw:
                continue
            arr = decode(raw)
            if arr is None:
                continue
            buckets[era].append(arr)
            save_cache(era, len(buckets[era]), arr)
            print(f"  {era}: {len(buckets[era])} ({name})")
    return buckets


def augment(img: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    out = img.astype(np.float32)
    if rng.random() < 0.5:
        out = np.fliplr(out)
    if rng.random() < 0.3:
        out = np.rot90(out, int(rng.integers(1, 4)))
    out = np.clip(out * rng.uniform(0.8, 1.2) + rng.uniform(-18, 18), 0, 255)
    if rng.random() < 0.35:
        shift = int(rng.integers(-6, 7))
        out = np.roll(out, shift, axis=1)
    return out.astype(np.uint8)


def build_model() -> keras.Model:
    inputs = keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3), name="image")
    x = layers.Conv2D(12, 3, padding="same", activation="relu", name="c1")(inputs)
    x = layers.MaxPool2D(2, name="p1")(x)
    x = layers.Conv2D(24, 3, padding="same", activation="relu", name="c2")(x)
    x = layers.MaxPool2D(2, name="p2")(x)
    x = layers.Flatten()(x)
    x = layers.Dropout(0.4)(x)
    x = layers.Dense(32, activation="relu", name="d1")(x)
    outputs = layers.Dense(len(ERAS), name="logits")(x)
    return keras.Model(inputs, outputs, name="era_cnn")


def export_json(model: keras.Model) -> None:
    c1 = model.get_layer("c1")
    c2 = model.get_layer("c2")
    d1 = model.get_layer("d1")
    logits = model.get_layer("logits")
    k1, b1 = c1.get_weights()
    k2, b2 = c2.get_weights()
    w3, b3 = d1.get_weights()
    w4, b4 = logits.get_weights()
    payload = {
        "type": "cnn",
        "size": IMG_SIZE,
        "labels": [{"era": era, "years": ERA_YEARS[era]} for era in ERAS],
        "k1": k1.tolist(),
        "b1": b1.tolist(),
        "k2": k2.tolist(),
        "b2": b2.tolist(),
        "w3": w3.tolist(),
        "b3": b3.tolist(),
        "w4": w4.tolist(),
        "b4": b4.tolist(),
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / "era_cnn.json"
    out.write_text(json.dumps(payload), encoding="utf-8")
    (OUT_DIR / "labels.txt").write_text(
        "\n".join(f"{era}|{ERA_YEARS[era]}" for era in ERAS) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {out} ({out.stat().st_size / 1024:.0f} KB)")


def main() -> None:
    tf.random.set_seed(SEED)
    rng = np.random.default_rng(SEED)
    buckets = load_cache()
    print("cache", {k: len(v) for k, v in buckets.items()})
    buckets = load_wikiart(buckets)
    buckets = load_wikimedia(buckets)

    xs: list[np.ndarray] = []
    ys: list[int] = []
    for idx, era in enumerate(ERAS):
        samples = buckets[era]
        if not samples:
            raise RuntimeError(f"No images for {era}")
        while len(samples) < PER_ERA:
            samples.append(augment(samples[int(rng.integers(0, len(samples)))], rng))
        print(f"{era}: {len(samples[:PER_ERA])}")
        for im in samples[:PER_ERA]:
            xs.append(im.astype(np.float32) / 255.0)
            ys.append(idx)

    x = np.stack(xs, axis=0)
    y = np.array(ys, dtype=np.int32)
    perm = rng.permutation(len(x))
    x, y = x[perm], y[perm]
    split = max(1, int(len(x) * 0.18))
    x_val, y_val = x[:split], y[:split]
    x_train, y_train = x[split:], y[split:]

    model = build_model()
    model.compile(
        optimizer=keras.optimizers.Adam(1.2e-3),
        loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=["accuracy"],
    )
    model.fit(
        x_train,
        y_train,
        validation_data=(x_val, y_val),
        epochs=18,
        batch_size=32,
        verbose=2,
    )
    val_loss, val_acc = model.evaluate(x_val, y_val, verbose=0)
    print(f"held-out accuracy: {val_acc:.3f}")
    export_json(model)


if __name__ == "__main__":
    main()
