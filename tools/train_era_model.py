#!/usr/bin/env python3
"""Train MobileNetV2 art-era classifier and export quantized TFLite."""

from __future__ import annotations

import io
import json
import os
import time
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
IMG_SIZE = 160
PER_ERA = 250
AUG_PER_UNIQUE = 3
SEED = 42
WIKIART_MAX_SCAN = 40000
WIKIART_TIMEOUT_SEC = 2400
COMMONS_PER_CATEGORY = 40


def load_dotenv(path: Path = ROOT / ".env") -> None:
    """Load KEY=VALUE pairs from .env without printing secrets."""
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


load_dotenv()
# Hugging Face Hub reads either name.
if os.environ.get("HF_TOKEN") and not os.environ.get("HUGGING_FACE_HUB_TOKEN"):
    os.environ["HUGGING_FACE_HUB_TOKEN"] = os.environ["HF_TOKEN"]

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
        "Leonardo da Vinci - Lady with an Ermine.jpg",
        "Titian - Bacchus and Ariadne - Google Art Project.jpg",
        "Sandro Botticelli - La Primavera - Google Art Project.jpg",
        "Raphael - Portrait of Baldassare Castiglione - Google Art Project.jpg",
    ],
    "Baroque": [
        "The Nightwatch by Rembrandt.jpg",
        "Girl with a Pearl Earring.jpg",
        "Caravaggio - The Calling of Saint Matthew.jpg",
        "Las Meninas, by Diego Velázquez, from Prado in Google Earth.jpg",
        "The Entombment of Christ-Caravaggio (c.1602-3).jpg",
        "Rembrandt - The Jewish Bride - Google Art Project.jpg",
        "Peter Paul Rubens - The Rape of the Daughters of Leucippus.jpg",
        "Diego Velázquez - Portrait of Pope Innocent X.jpg",
        "Judith Leyster - The Proposition.jpg",
        "Frans Hals - The Laughing Cavalier.jpg",
        "Caravaggio - Judith Beheading Holofernes.jpg",
        "Rembrandt - Self-Portrait with Two Circles.jpg",
    ],
    "Romanticism": [
        "Eugène Delacroix - Le 28 Juillet. La Liberté guidant le peuple.jpg",
        "Caspar David Friedrich - Wanderer above the sea of fog.jpg",
        "The Fighting Temeraire, JMW Turner, National Gallery.jpg",
        "John Constable The Hay Wain.jpg",
        "Caspar David Friedrich - The Abbey in the Oakwood.jpg",
        "Joseph Mallord William Turner - Fishermen at Sea - Google Art Project.jpg",
        "Théodore Géricault - The Raft of the Medusa - Louvre Museum.jpg",
        "Francisco de Goya - The Third of May 1808 - Google Art Project.jpg",
        "Eugène Delacroix - Death of Sardanapalus.jpg",
        "John Constable - Salisbury Cathedral from the Meadows.jpg",
        "Caspar David Friedrich - The Sea of Ice.jpg",
        "William Blake - The Ancient of Days.jpg",
    ],
    "Realism": [
        "Jean-François Millet - Gleaners - Google Art Project 2.jpg",
        "Edouard Manet - Luncheon on the Grass - Google Art Project.jpg",
        "Edouard Manet, A Bar at the Folies-Bergère.jpg",
        "Jean-François Millet Angelus.jpg",
        "Ilya Repin - Barge Haulers on the Volga - Google Art Project.jpg",
        "Winslow Homer - The Gulf Stream - Metropolitan Museum of Art.jpg",
        "Gustave Courbet - A Burial at Ornans - Musée d'Orsay.jpg",
        "Jean-François Millet - The Sower - Google Art Project.jpg",
        "Édouard Manet - Olympia - Google Art Project.jpg",
        "Gustave Courbet - The Stone Breakers.jpg",
        "Thomas Eakins - The Gross Clinic.jpg",
        "Winslow Homer - Snap the Whip.jpg",
    ],
    "Impressionism": [
        "Claude Monet, Impression, soleil levant.jpg",
        "Claude Monet - Water Lilies - 1906, Ryerson.jpg",
        "Claude Monet - The Magpie - Google Art Project.jpg",
        "Pierre-Auguste Renoir, Le Moulin de la Galette.jpg",
        "Pierre-Auguste Renoir - Luncheon of the Boating Party - Google Art Project.jpg",
        "Edgar Degas - The Ballet Class - Google Art Project.jpg",
        "Claude Monet - Woman with a Parasol - Madame Monet and Her Son.jpg",
        "Camille Pissarro - The Boulevard Montmartre on a Winter Morning.jpg",
        "Berthe Morisot - The Cradle.jpg",
        "Alfred Sisley - Flood at Port-Marly.jpg",
        "Claude Monet - Rouen Cathedral, Facade (Sunset).jpg",
        "Pierre-Auguste Renoir - Dance at Bougival.jpg",
    ],
    "Post-Impressionism": [
        "Van Gogh - Starry Night - Google Art Project.jpg",
        "Vincent van Gogh - Sunflowers - VGM F458.jpg",
        "A Sunday on La Grande Jatte, Georges Seurat, 1884.jpg",
        "Vincent van Gogh - The Bedroom - Google Art Project.jpg",
        "Paul Cézanne - The Card Players.jpg",
        "Vincent van Gogh - Café Terrace at Night.jpg",
        "Paul Gauguin - Vision After the Sermon.jpg",
        "Georges Seurat - Bathers at Asnières.jpg",
        "Vincent van Gogh - Irises - Google Art Project.jpg",
        "Paul Cézanne - Still Life with Apples.jpg",
        "Henri de Toulouse-Lautrec - At the Moulin Rouge.jpg",
        "Vincent van Gogh - Self-Portrait with Grey Felt Hat.jpg",
    ],
    "Modern": [
        "Vassily Kandinsky, 1913 - Composition 7.jpg",
        "Piet Mondriaan, 1930 - Mondrian Composition II in Red, Blue, and Yellow.jpg",
        "Kazimir Malevich, 1915, Black Suprematic Square, oil on linen canvas, 79.5 x 79.5 cm, Tretyakov Gallery, Moscow.jpg",
        "Theo van Doesburg Composition VII (the three graces).jpg",
        "Pablo Picasso, 1907, Les Demoiselles d'Avignon.jpg",
        "Henri Matisse - The Dance (II).jpg",
        "Umberto Boccioni - Unique Forms of Continuity in Space 1913.jpg",
        "Fernand Léger - The City.jpg",
        "Wassily Kandinsky - Yellow-Red-Blue.jpg",
        "Piet Mondrian - Composition with Red Blue and Yellow.jpg",
        "Marc Chagall - I and the Village.jpg",
        "Amedeo Modigliani - Jeanne Hébuterne.jpg",
    ],
    "Contemporary": [
        "Nighthawks by Edward Hopper 1942.jpg",
        "Grant Wood - American Gothic - Google Art Project.jpg",
        "Edward Hopper - Automat.jpg",
        "Jackson Pollock - Number 1A, 1948.jpg",
        "Mark Rothko - No. 61 (Rust and Blue).jpg",
        "Andy Warhol - Campbell's Soup Cans MOMA.jpg",
        "Roy Lichtenstein - Whaam!.jpg",
        "Edward Hopper - Early Sunday Morning.jpg",
        "Georgia O'Keeffe - Cow's Skull: Red, White, and Blue.jpg",
        "Frida Kahlo - The Two Fridas.jpg",
        "Francis Bacon - Three Studies for Figures at the Base of a Crucifixion.jpg",
        "David Hockney - A Bigger Splash.jpg",
        "Mark Rothko - Orange and Yellow.jpg",
        "Andy Warhol - Marilyn Diptych.jpg",
        "Roy Lichtenstein - Drowning Girl.jpg",
        "Helen Frankenthaler - Mountains and Sea.jpg",
        "Willem de Kooning - Woman I.jpg",
        "Jasper Johns - Flag.jpg",
        "Robert Rauschenberg - Canyon.jpg",
        "Yves Klein - IKB 191.jpg",
    ],
}

# Extra Commons categories (painting files) to grow unique coverage beyond named FILES.
ERA_CATEGORIES = {
    "Renaissance": [
        "Category:Italian Renaissance paintings",
        "Category:Northern Renaissance paintings",
        "Category:Renaissance portraits",
    ],
    "Baroque": [
        "Category:Baroque paintings",
        "Category:Dutch Golden Age paintings",
        "Category:Caravaggio",
    ],
    "Romanticism": [
        "Category:Romantic paintings",
        "Category:Paintings by Caspar David Friedrich",
        "Category:Paintings by Eugène Delacroix",
    ],
    "Realism": [
        "Category:Realist paintings",
        "Category:Paintings by Jean-François Millet",
        "Category:Paintings by Gustave Courbet",
    ],
    "Impressionism": [
        "Category:Impressionist paintings",
        "Category:Paintings by Claude Monet",
        "Category:Paintings by Pierre-Auguste Renoir",
    ],
    "Post-Impressionism": [
        "Category:Post-Impressionist paintings",
        "Category:Paintings by Vincent van Gogh",
        "Category:Paintings by Paul Cézanne",
    ],
    "Modern": [
        "Category:Cubist paintings",
        "Category:Expressionist paintings",
        "Category:Paintings by Pablo Picasso",
    ],
    "Contemporary": [
        "Category:Abstract expressionist paintings",
        "Category:Pop art",
        "Category:Paintings by Mark Rothko",
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


def http_get(url: str, retries: int = 4) -> bytes | None:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "ArtEraTrainer/2.1 (on-device art education; local research)",
            "Accept": "image/*,application/json;q=0.9,*/*;q=0.8",
        },
    )
    delay = 1.5
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
            time.sleep(0.35)  # be polite to Commons
            return data
        except Exception as exc:
            msg = str(exc)
            if "429" in msg or "503" in msg:
                time.sleep(delay)
                delay = min(delay * 2.0, 30.0)
                continue
            if attempt == 0:
                print(f"  skip: {exc}", flush=True)
            return None
    print(f"  skip: rate-limited {url[:80]}", flush=True)
    return None


def save_cache(era: str, arr: np.ndarray) -> None:
    folder = CACHE / era
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


def _style_names_from_dataset_card() -> list[str]:
    """Official huggan/wikiart ClassLabel order (from dataset_infos.json)."""
    return [
        "Abstract_Expressionism",
        "Action_painting",
        "Analytical_Cubism",
        "Art_Nouveau",
        "Baroque",
        "Color_Field_Painting",
        "Contemporary_Realism",
        "Cubism",
        "Early_Renaissance",
        "Expressionism",
        "Fauvism",
        "High_Renaissance",
        "Impressionism",
        "Mannerism_Late_Renaissance",
        "Minimalism",
        "Naive_Art_Primitivism",
        "New_Realism",
        "Northern_Renaissance",
        "Pointillism",
        "Pop_Art",
        "Post_Impressionism",
        "Realism",
        "Rococo",
        "Romanticism",
        "Symbolism",
        "Synthetic_Cubism",
        "Ukiyo_e",
    ]


def _image_from_parquet_cell(cell) -> np.ndarray | None:
    try:
        if isinstance(cell, dict):
            raw = cell.get("bytes")
            if raw:
                return decode(raw if isinstance(raw, (bytes, bytearray)) else bytes(raw))
            path = cell.get("path")
            if path and Path(path).exists():
                return to_array(Image.open(path))
            return None
        if hasattr(cell, "convert"):
            return to_array(cell)
        if isinstance(cell, (bytes, bytearray)):
            return decode(bytes(cell))
    except Exception:
        return None
    return None


def load_wikiart(buckets: dict[str, list[np.ndarray]]) -> dict[str, list[np.ndarray]]:
    # Default: use WikiArt when an HF token is present.
    default_skip = "0" if os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN") else "1"
    if os.environ.get("SKIP_WIKIART", default_skip) == "1":
        print("SKIP_WIKIART=1", flush=True)
        return buckets

    token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
    max_shards = int(os.environ.get("WIKIART_MAX_SHARDS", "12"))
    local_dir = os.environ.get("WIKIART_LOCAL_DIR", "").strip()
    print(
        f"Loading WikiArt parquet… (token={'yes' if token else 'no'}, "
        f"target={PER_ERA}/era, max_shards={max_shards}"
        + (f", local={local_dir}" if local_dir else "")
        + ")",
        flush=True,
    )

    try:
        import pyarrow.parquet as pq
    except ImportError as exc:
        print(f"WikiArt deps missing ({exc})", flush=True)
        return buckets

    hf_hub_download = None
    if not local_dir:
        try:
            from huggingface_hub import hf_hub_download as _dl

            hf_hub_download = _dl
        except ImportError as exc:
            print(f"huggingface_hub missing ({exc})", flush=True)
            return buckets

    names = _style_names_from_dataset_card()
    started = time.time()
    kept = 0

    for shard_i in range(max_shards):
        if all(len(buckets[e]) >= PER_ERA for e in ERAS):
            print("WikiArt targets filled", flush=True)
            break
        if (time.time() - started) > WIKIART_TIMEOUT_SEC:
            print("WikiArt timeout", flush=True)
            break

        fname = f"train-{shard_i:05d}-of-00072.parquet"
        if local_dir:
            path = str(Path(local_dir) / fname)
            if not Path(path).exists():
                print(f"  missing local shard {fname}", flush=True)
                continue
            print(f"  local shard {fname} …", flush=True)
        else:
            remote = f"data/{fname}"
            print(f"  shard {remote} …", flush=True)
            try:
                path = hf_hub_download(
                    "huggan/wikiart",
                    remote,
                    repo_type="dataset",
                    token=token,
                )
            except Exception as exc:
                print(f"  skip shard: {exc}", flush=True)
                continue

        try:
            table = pq.read_table(path, columns=["image", "style"])
        except Exception as exc:
            print(f"  read fail: {exc}", flush=True)
            continue

        styles = table.column("style").to_pylist()
        images = table.column("image")
        shard_kept = 0
        for idx, style_id in enumerate(styles):
            if all(len(buckets[e]) >= PER_ERA for e in ERAS):
                break
            try:
                style_name = names[int(style_id)]
            except Exception:
                continue
            era = STYLE_TO_ERA.get(style_name)
            if era is None or len(buckets[era]) >= PER_ERA:
                continue
            arr = _image_from_parquet_cell(images[idx].as_py())
            if arr is None:
                continue
            buckets[era].append(arr)
            save_cache(era, arr)
            kept += 1
            shard_kept += 1
            if kept % 50 == 0:
                print(
                    f"  kept={kept} { {k: len(buckets[k]) for k in ERAS} }",
                    flush=True,
                )

        print(
            f"  shard {shard_i} done (+{shard_kept}) "
            f"{ {k: len(buckets[k]) for k in ERAS} }",
            flush=True,
        )
        if os.environ.get("WIKIART_DELETE_SHARDS") == "1" and not local_dir:
            try:
                Path(path).unlink(missing_ok=True)
            except Exception:
                pass

    print(
        f"WikiArt done kept={kept} { {k: len(buckets[k]) for k in ERAS} }",
        flush=True,
    )
    return buckets


def load_wikimedia(buckets: dict[str, list[np.ndarray]]) -> dict[str, list[np.ndarray]]:
    if os.environ.get("CACHE_ONLY") == "1":
        print("CACHE_ONLY=1 — skip Commons named downloads", flush=True)
        return buckets
    print("Downloading Commons named examples…", flush=True)
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
            save_cache(era, arr)
            print(f"  {era}: {len(buckets[era])} ({name})", flush=True)
    return buckets


def commons_category_titles(category: str, limit: int) -> list[str]:
    titles: list[str] = []
    cont = None
    while len(titles) < limit:
        params = {
            "action": "query",
            "format": "json",
            "generator": "categorymembers",
            "gcmtitle": category,
            "gcmtype": "file",
            "gcmlimit": str(min(50, limit - len(titles))),
            "prop": "imageinfo",
            "iiprop": "url|mime",
            "iiurlwidth": "640",
        }
        if cont:
            params["gcmcontinue"] = cont
        url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
        raw = http_get(url)
        if not raw:
            break
        try:
            data = json.loads(raw.decode("utf-8", errors="ignore"))
        except Exception:
            break
        pages = (data.get("query") or {}).get("pages") or {}
        for page in pages.values():
            info = (page.get("imageinfo") or [{}])[0]
            mime = str(info.get("mime") or "")
            if not mime.startswith("image/"):
                continue
            thumb = info.get("thumburl") or info.get("url")
            title = page.get("title") or ""
            if not thumb or not title.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
                # still accept if thumb exists
                if not thumb:
                    continue
            titles.append(thumb)
            if len(titles) >= limit:
                break
        cont = (data.get("continue") or {}).get("gcmcontinue")
        if not cont:
            break
    return titles


def load_commons_categories(
    buckets: dict[str, list[np.ndarray]],
) -> dict[str, list[np.ndarray]]:
    if os.environ.get("CACHE_ONLY") == "1":
        print("CACHE_ONLY=1 — skip Commons categories", flush=True)
        return buckets
    print("Downloading Commons category samples…", flush=True)
    for era, cats in ERA_CATEGORIES.items():
        if len(buckets[era]) >= PER_ERA:
            continue
        for cat in cats:
            if len(buckets[era]) >= PER_ERA:
                break
            need = min(COMMONS_PER_CATEGORY, PER_ERA - len(buckets[era]))
            urls = commons_category_titles(cat, need)
            print(f"  {era}/{cat}: {len(urls)} urls", flush=True)
            for u in urls:
                if len(buckets[era]) >= PER_ERA:
                    break
                raw = http_get(u)
                if not raw:
                    continue
                arr = decode(raw)
                if arr is None:
                    continue
                buckets[era].append(arr)
                save_cache(era, arr)
            print(f"  {era} now {len(buckets[era])}", flush=True)
    return buckets


def augment(img: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    out = img.astype(np.float32)
    if rng.random() < 0.5:
        out = np.fliplr(out)
    if rng.random() < 0.25:
        out = np.rot90(out, int(rng.integers(1, 4)))
    out = np.clip(out * rng.uniform(0.75, 1.25) + rng.uniform(-20, 20), 0, 255)
    if rng.random() < 0.4:
        out = np.roll(out, int(rng.integers(-10, 11)), axis=1)
    if rng.random() < 0.4:
        out = np.roll(out, int(rng.integers(-10, 11)), axis=0)
    # mild crop-resize jitter
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


def build_model(num_classes: int) -> tuple[keras.Model, keras.Model]:
    inputs = keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3), name="image")
    # App sends RGB 0–1; MobileNetV2 expects [-1, 1].
    x = layers.Rescaling(2.0, offset=-1.0)(inputs)
    base = keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
        alpha=0.35,
        pooling="avg",
    )
    base.trainable = False
    x = base(x, training=False)
    x = layers.Dropout(0.35)(x)
    outputs = layers.Dense(num_classes, name="logits")(x)
    model = keras.Model(inputs, outputs, name="era_mobilenet")
    return model, base


def export_tflite(model: keras.Model) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "labels.txt").write_text(
        "\n".join(f"{era}|{ERA_YEARS[era]}" for era in ERAS) + "\n",
        encoding="utf-8",
    )

    def rep_data():
        for _ in range(40):
            yield [np.random.rand(1, IMG_SIZE, IMG_SIZE, 3).astype(np.float32)]

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = rep_data
    # Keep float I/O for simple Flutter preprocessing (0–1 RGB).
    tflite_model = converter.convert()
    out = OUT_DIR / "era_model.tflite"
    out.write_bytes(tflite_model)
    print(f"wrote {out} ({out.stat().st_size / 1024:.0f} KB)", flush=True)


def pack(imgs: list[np.ndarray], label: int, rng: np.random.Generator, n_aug: int):
    xs: list[np.ndarray] = []
    ys: list[int] = []
    for im in imgs:
        xs.append(im.astype(np.float32) / 255.0)
        ys.append(label)
        for _ in range(n_aug):
            xs.append(augment(im, rng).astype(np.float32) / 255.0)
            ys.append(label)
    return xs, ys


def main() -> None:
    tf.random.set_seed(SEED)
    rng = np.random.default_rng(SEED)

    buckets = load_cache()
    print("cache", {k: len(v) for k, v in buckets.items()}, flush=True)
    buckets = load_wikiart(buckets)
    buckets = load_wikimedia(buckets)
    buckets = load_commons_categories(buckets)

    x_train_list: list[np.ndarray] = []
    y_train_list: list[int] = []
    x_val_list: list[np.ndarray] = []
    y_val_list: list[int] = []

    for idx, era in enumerate(ERAS):
        samples = list(buckets[era])
        if len(samples) < 4:
            raise RuntimeError(f"Too few unique images for {era}: {len(samples)}")
        order = rng.permutation(len(samples))
        samples = [samples[i] for i in order]
        # Hold out unique paintings (not augmented copies) for validation.
        n_val = max(2, int(round(len(samples) * 0.2)))
        val_imgs = samples[:n_val]
        train_imgs = samples[n_val:]
        if not train_imgs:
            train_imgs, val_imgs = samples[:-1], samples[-1:]

        # Cap train uniques used for augmentation budget.
        if len(train_imgs) > PER_ERA:
            train_imgs = train_imgs[:PER_ERA]

        tx, ty = pack(train_imgs, idx, rng, AUG_PER_UNIQUE)
        vx, vy = pack(val_imgs, idx, rng, 0)  # no aug in val
        print(
            f"{era}: train_unique={len(train_imgs)} val_unique={len(val_imgs)} "
            f"train_aug={len(tx)}",
            flush=True,
        )
        x_train_list.extend(tx)
        y_train_list.extend(ty)
        x_val_list.extend(vx)
        y_val_list.extend(vy)

    x_train = np.stack(x_train_list, axis=0)
    y_train = np.array(y_train_list, dtype=np.int32)
    x_val = np.stack(x_val_list, axis=0)
    y_val = np.array(y_val_list, dtype=np.int32)
    perm = rng.permutation(len(x_train))
    x_train, y_train = x_train[perm], y_train[perm]

    model, base = build_model(len(ERAS))
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=["accuracy"],
    )
    print("Training classification head…", flush=True)
    model.fit(
        x_train,
        y_train,
        validation_data=(x_val, y_val),
        epochs=12,
        batch_size=24,
        verbose=2,
    )

    base.trainable = True
    for layer in base.layers[:-50]:
        layer.trainable = False
    model.compile(
        optimizer=keras.optimizers.Adam(1e-5),
        loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=["accuracy"],
    )
    print("Fine-tuning last MobileNet blocks…", flush=True)
    model.fit(
        x_train,
        y_train,
        validation_data=(x_val, y_val),
        epochs=10,
        batch_size=16,
        verbose=2,
    )
    _, val_acc = model.evaluate(x_val, y_val, verbose=0)
    print(f"held-out unique accuracy: {val_acc:.3f}", flush=True)
    export_tflite(model)


if __name__ == "__main__":
    main()
