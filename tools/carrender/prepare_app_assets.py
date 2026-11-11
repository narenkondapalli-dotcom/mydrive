"""Shrink the rendered library into app-ready JPEGs in shared/cars/ (used by iOS + Android builds).

    pip install pillow
    python tools/carrender/prepare_app_assets.py            # from D:/Projects/mydrive-assets/cars/nb21
Each output: 1280x720, JPEG q78 (~100 KB). Re-run after new renders.
"""
import argparse, pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]

ap = argparse.ArgumentParser()
ap.add_argument("--src", default="D:/Projects/mydrive-assets/cars/nb21")
a = ap.parse_args()
out = ROOT / "shared" / "cars"
out.mkdir(parents=True, exist_ok=True)
n = 0
for f in sorted(pathlib.Path(a.src).rglob("*.jpg")):
    im = Image.open(f).convert("RGB")
    im.thumbnail((1280, 720), Image.LANCZOS)
    im.save(out / f.name, "JPEG", quality=78, optimize=True, progressive=True)
    n += 1
print(f"{n} images -> {out}")
