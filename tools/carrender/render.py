"""Car picture library generator — Google Nano Banana on Vertex AI, paid from Biolynk GCP credits.

No extra packages: uses Python's standard library + your gcloud login (founder@biolynktech.com).
Project biolynk-studio-2610, global endpoint.

    python tools/carrender/render.py --test                 # 5 cars, both models -> <out>/test/<model>/
    python tools/carrender/render.py --model pro --all      # every model x every manufacturer colour
    python tools/carrender/render.py --model pro --car jeep-meridian

Output (default D:/Projects/mydrive-assets/cars) is outside Git: full-size 2K JPEGs.
Already-rendered files are skipped, so the run can be stopped and resumed.
"""
import argparse, base64, json, pathlib, subprocess, sys, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

PROJECT = "biolynk-studio-2610"
MODELS = {"pro": "gemini-3-pro-image", "nb21": "gemini-nano-banana-2.1"}
ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG = json.loads((ROOT / "shared" / "car-catalog.json").read_text(encoding="utf-8"))
PACE = 8  # seconds between successful calls, keeps under the per-minute quota
TEST_SET = ["jeep-meridian", "mahindra-xuv700", "tata-safari", "hyundai-creta", "toyota-fortuner"]

PROMPT = (
    "Photorealistic studio photograph of a {make} {model} ({note}), the current Indian-market version, "
    "painted in the manufacturer colour \"{colour}\" (approximately {hex}), {roof}, factory alloy wheels. "
    "Three-quarter front view facing left. Glossy jet-black floor with a soft reflection, pure black seamless "
    "background, low-key lighting with a warm golden rim light along the roofline and a soft cool key light on the "
    "body panels. Premium car-launch look. 16:9 frame, car in the right two-thirds, empty dark space on the left. "
    "Accurate body shape, grille, lights and proportions for this exact model. "
    "No number plate, no text, no people, no watermark."
)

_token = {"v": None, "t": 0}


def token():
    if not _token["v"] or time.time() - _token["t"] > 2400:
        gcloud = "gcloud.cmd" if sys.platform == "win32" else "gcloud"
        _token["v"] = subprocess.check_output([gcloud, "auth", "print-access-token"], text=True).strip()
        _token["t"] = time.time()
    return _token["v"]


def roof_text(roof):
    if roof == "body":
        return "body-coloured roof"
    if roof.lower() == "black":
        return "contrasting gloss black roof (dual-tone)"
    return f"contrasting {roof} roof (dual-tone)"


def render(model_key, car, colour, out_dir, retries=8):
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{car['slug']}--{colour['id']}.jpg"
    if path.exists():
        return "skip"
    prompt = PROMPT.format(make=car["make"], model=car["model"], note=car["note"], colour=colour["name"],
                           hex=colour["hex"], roof=roof_text(colour["roof"]))
    url = (f"https://aiplatform.googleapis.com/v1/projects/{PROJECT}/locations/global/"
           f"publishers/google/models/{MODELS[model_key]}:generateContent")
    body = {"contents": [{"role": "user", "parts": [{"text": prompt}]}],
            "generationConfig": {"responseModalities": ["IMAGE"],
                                 "imageConfig": {"aspectRatio": "16:9", "imageSize": "2K"}}}
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
                                         headers={"Authorization": f"Bearer {token()}",
                                                  "Content-Type": "application/json"})
            t0 = time.time()
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.loads(r.read())
            for part in data["candidates"][0]["content"]["parts"]:
                inline = part.get("inlineData")
                if inline:
                    path.write_bytes(base64.b64decode(inline["data"]))
                    log(out_dir, f"ok {path.name} {time.time() - t0:.1f}s")
                    time.sleep(PACE)
                    return "ok"
            log(out_dir, f"noimage {path.name} {json.dumps(data)[:300]}")
        except urllib.error.HTTPError as e:
            msg = e.read().decode()[:300]
            log(out_dir, f"http{e.code} {path.name} {msg}")
            if e.code in (429, 500, 503):
                time.sleep(min(30 * 2 ** attempt, 600)); continue
            return "fail"
        except Exception as e:  # network hiccup
            log(out_dir, f"err {path.name} {e}"); time.sleep(10)
    return "fail"


def log(out_dir, line):
    print(line, flush=True)
    with open(out_dir.parent / "render.log", "a", encoding="utf-8") as f:
        f.write(time.strftime("%H:%M:%S ") + line + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", choices=MODELS, default="nb21")
    ap.add_argument("--test", action="store_true")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--car", help="one model slug, e.g. jeep-meridian")
    ap.add_argument("--out", default="D:/Projects/mydrive-assets/cars")
    ap.add_argument("--workers", type=int, default=1)
    a = ap.parse_args()
    out = pathlib.Path(a.out)
    cars = {c["slug"]: c for c in CATALOG["models"]}
    jobs = []
    if a.test:
        for key in MODELS:
            for slug in TEST_SET:
                car = cars[slug]
                white = next((c for c in car["colours"] if "white" in c["name"].lower() and c["roof"] == "body"),
                             car["colours"][0])
                jobs.append((key, car, white, out / "test" / key))
    elif a.all or a.car:
        chosen = [cars[a.car]] if a.car else CATALOG["models"]
        for car in chosen:
            for colour in car["colours"]:
                jobs.append((a.model, car, colour, out / a.model / car["slug"]))
    else:
        ap.print_help(); return
    print(f"{len(jobs)} images queued")
    with ThreadPoolExecutor(a.workers) as ex:
        results = list(ex.map(lambda j: render(*j), jobs))
    print({k: results.count(k) for k in set(results)})


if __name__ == "__main__":
    main()
