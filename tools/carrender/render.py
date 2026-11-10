"""Generate the car picture library with Google's Nano Banana models on Vertex AI.

Uses Biolynk's GCP credits (project biolynk-studio-2610, account founder@biolynktech.com).
Never run the full library without Mohit's OK.

Setup (once):
    pip install google-genai pillow
    gcloud auth application-default login   # as founder@biolynktech.com

Examples:
    python render.py --test                  # 5 cars x 1 colour, both models -> out/test/
    python render.py --model pro --all       # full catalogue x colours -> out/pro/
"""
import argparse, json, pathlib, sys, time
from google import genai
from google.genai import types

PROJECT = "biolynk-studio-2610"
LOCATION = "global"
MODELS = {"pro": "gemini-3-pro-image", "nb21": "gemini-nano-banana-2.1"}
ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG = json.loads((ROOT / "shared" / "car-catalog.json").read_text())

PROMPT = (
    "Photorealistic studio photograph of a {colour} {make} {model} ({note}), current Indian-market version, "
    "{roof_text}, {wheel_text}, three-quarter front view facing left, on a glossy jet-black floor with a soft "
    "reflection, pure black seamless background, low-key lighting with a warm golden rim light along the roofline "
    "and a soft cool key light on the body, premium car-launch look, 16:9, car in the right two-thirds of the frame "
    "with empty dark space on the left. No text, no people, no number plate text, no watermarks."
)

TEST_SET = ["jeep-meridian", "mahindra-xuv700", "tata-safari", "hyundai-creta", "toyota-fortuner"]


def render(client, model_id, car, colour, roof="black", wheels="black", out_dir=pathlib.Path("out")):
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{car['slug']}-{colour.lower()}.jpg"
    if path.exists():
        return path
    prompt = PROMPT.format(colour=colour.lower(), make=car["make"], model=car["model"], note=car["note"],
                           roof_text="gloss black roof" if roof == "black" else "body-colour roof",
                           wheel_text="black alloy wheels" if wheels == "black" else "silver alloy wheels")
    t0 = time.time()
    resp = client.models.generate_content(
        model=model_id, contents=prompt,
        config=types.GenerateContentConfig(response_modalities=["IMAGE"],
                                           image_config=types.ImageConfig(aspect_ratio="16:9")))
    for part in resp.candidates[0].content.parts:
        if part.inline_data:
            path.write_bytes(part.inline_data.data)
            print(f"ok {path.name} {time.time() - t0:.1f}s")
            return path
    print(f"no image for {path.name}", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", choices=MODELS, default="pro")
    ap.add_argument("--test", action="store_true")
    ap.add_argument("--all", action="store_true")
    a = ap.parse_args()
    client = genai.Client(vertexai=True, project=PROJECT, location=LOCATION)
    cars = {c["slug"]: c for c in CATALOG["models"]}
    if a.test:
        for key in MODELS:
            for slug in TEST_SET:
                render(client, MODELS[key], cars[slug], "White", out_dir=pathlib.Path("out/test") / key)
    elif a.all:
        for car in CATALOG["models"]:
            for colour in CATALOG["colours"]:
                render(client, MODELS[a.model], car, colour, out_dir=pathlib.Path("out") / a.model)
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
