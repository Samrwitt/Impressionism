#!/usr/bin/env python3
"""Train a tiny MLP art-era classifier and export weights for on-device Dart inference."""

from __future__ import annotations

import io
import json
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "models"
IMG_SIZE = 160
PER_ERA = 24
SEED = 42
BINS = 8

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


def histogram(channel: np.ndarray) -> list[float]:
    hist, _ = np.histogram(channel, bins=BINS, range=(0.0, 255.0), density=True)
    return hist.astype(np.float64).tolist()


def extract_features(rgb: np.ndarray) -> list[float]:
    r = rgb[:, :, 0].astype(np.float64)
    g = rgb[:, :, 1].astype(np.float64)
    b = rgb[:, :, 2].astype(np.float64)
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    sat = np.where(mx > 1e-6, (mx - mn) / mx, 0.0)
    gx = np.abs(lum[:, 1:] - lum[:, :-1]).mean()
    gy = np.abs(lum[1:, :] - lum[:-1, :]).mean()
    warm = np.clip(r - b, 0.0, 255.0).mean() / 255.0
    feats = []
    feats.extend(histogram(r))
    feats.extend(histogram(g))
    feats.extend(histogram(b))
    feats.extend(histogram(lum))
    feats.extend(
        [
            lum.mean() / 255.0,
            lum.std() / 255.0,
            sat.mean(),
            sat.std(),
            gx / 255.0,
            gy / 255.0,
            warm,
            (r.mean() - g.mean()) / 255.0,
            (g.mean() - b.mean()) / 255.0,
        ]
    )
    return feats


def decode(raw: bytes) -> np.ndarray | None:
    try:
        img = Image.open(io.BytesIO(raw)).convert("RGB")
        img = img.resize((IMG_SIZE, IMG_SIZE), Image.Resampling.BILINEAR)
        return np.asarray(img, dtype=np.uint8)
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


def load_wikiart() -> dict[str, list[np.ndarray]]:
    buckets: dict[str, list[np.ndarray]] = defaultdict(list)
    try:
        from datasets import load_dataset
    except ImportError:
        return buckets
    print("Streaming WikiArt samples...")
    try:
        ds = load_dataset("huggan/wikiart", split="train", streaming=True)
        names = ds.features["style"].names
    except Exception as exc:
        print(f"WikiArt unavailable ({exc})")
        return buckets
    seen = 0
    for row in ds:
        seen += 1
        if all(len(buckets[e]) >= PER_ERA for e in ERAS) or seen > 6000:
            break
        try:
            era = STYLE_TO_ERA.get(names[int(row["style"])])
        except Exception:
            continue
        if era is None or len(buckets[era]) >= PER_ERA:
            continue
        try:
            rgb = row["image"].convert("RGB").resize((IMG_SIZE, IMG_SIZE), Image.Resampling.BILINEAR)
            buckets[era].append(np.asarray(rgb, dtype=np.uint8))
        except Exception:
            continue
    return buckets


def load_wikimedia(buckets: dict[str, list[np.ndarray]]) -> dict[str, list[np.ndarray]]:
    print("Downloading public-domain examples...")
    for era, names in FILES.items():
        for name in names:
            if len(buckets[era]) >= PER_ERA:
                break
            raw = http_get(commons_url(name))
            if not raw:
                continue
            arr = decode(raw)
            if arr is not None:
                buckets[era].append(arr)
                print(f"  {era}: {len(buckets[era])} ({name})")
    return buckets


def augment(img: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    out = img.astype(np.float64)
    if rng.random() < 0.5:
        out = np.fliplr(out)
    out = np.clip(out * rng.uniform(0.82, 1.18) + rng.uniform(-12, 12), 0, 255)
    if rng.random() < 0.35:
        out = np.rot90(out, int(rng.integers(0, 4)))
    return out.astype(np.uint8)


def main() -> None:
    rng = np.random.default_rng(SEED)
    buckets = load_wikiart()
    buckets = load_wikimedia(buckets)

    xs: list[list[float]] = []
    ys: list[int] = []
    for idx, era in enumerate(ERAS):
        samples = buckets[era]
        if not samples:
            raise RuntimeError(f"No images for {era}")
        while len(samples) < PER_ERA:
            samples.append(augment(samples[int(rng.integers(0, len(samples)))], rng))
        print(f"{era}: {len(samples[:PER_ERA])} samples")
        for img in samples[:PER_ERA]:
            xs.append(extract_features(img))
            ys.append(idx)

    x = np.array(xs, dtype=np.float64)
    y = np.array(ys, dtype=np.int32)
    scaler = StandardScaler()
    x_s = scaler.fit_transform(x)

    clf = MLPClassifier(
        hidden_layer_sizes=(32,),
        activation="relu",
        solver="adam",
        max_iter=600,
        random_state=SEED,
        alpha=0.02,
    )
    clf.fit(x_s, y)
    acc = float((clf.predict(x_s) == y).mean())
    print(f"train accuracy: {acc:.3f}")

    payload = {
        "labels": [{"era": era, "years": ERA_YEARS[era]} for era in ERAS],
        "mean": scaler.mean_.tolist(),
        "scale": scaler.scale_.tolist(),
        "w1": clf.coefs_[0].tolist(),
        "b1": clf.intercepts_[0].tolist(),
        "w2": clf.coefs_[1].tolist(),
        "b2": clf.intercepts_[1].tolist(),
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / "era_mlp.json"
    out.write_text(json.dumps(payload), encoding="utf-8")
    (OUT_DIR / "labels.txt").write_text(
        "\n".join(f"{era}|{ERA_YEARS[era]}" for era in ERAS) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
