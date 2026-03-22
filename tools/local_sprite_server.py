#!/usr/bin/env python3
"""Local sprite generation server — AUTOMATIC1111-compatible endpoint.

Endpoint:
  POST /sdapi/v1/txt2img
  Body: {"prompt": "...", "width": 256, "height": 256, "steps": 10, "cfg_scale": 7.0}
  Response: {"images": ["<base64 PNG>"]}

Dependencies are installed on first run (torch CPU, diffusers, transformers,
accelerate, safetensors).  The model is downloaded from HuggingFace on first
request and cached in ~/.cache/huggingface/.

Model: runwayml/stable-diffusion-v1-5 (~4 GB download, one-time).
WARNING: CPU-only — expect 5–20 min per image.
"""

import base64
import http.server
import importlib
import io
import json
import os
import subprocess
import sys
from typing import Optional

HOST = "127.0.0.1"
PORT = 7860
MODEL_ID = "runwayml/stable-diffusion-v1-5"

REQUIRED_PACKAGES = [
    "torch",
    "diffusers",
    "transformers",
    "accelerate",
    "safetensors",
]


def _ensure_packages() -> None:
    missing = []
    for pkg in REQUIRED_PACKAGES:
        spec = importlib.util.find_spec(pkg.replace("-", "_"))
        if spec is None:
            missing.append(pkg)
    if not missing:
        return
    print(f"[sprite] Installing missing packages: {missing}", flush=True)
    # Install torch CPU-only first (smaller download)
    if "torch" in missing:
        subprocess.check_call([
            sys.executable, "-m", "pip", "install", "--quiet",
            "torch", "torchvision",
            "--index-url", "https://download.pytorch.org/whl/cpu",
        ])
        missing.remove("torch")
        if "torchvision" in missing:
            missing.remove("torchvision")
    if missing:
        subprocess.check_call([
            sys.executable, "-m", "pip", "install", "--quiet",
        ] + missing)
    print("[sprite] Packages ready.", flush=True)


# Pipeline is loaded lazily on first request
_pipeline = None


def _load_pipeline():
    global _pipeline
    if _pipeline is not None:
        return _pipeline

    import torch
    from diffusers import StableDiffusionPipeline

    print(f"[sprite] Loading model {MODEL_ID} (CPU) — may take a few minutes...", flush=True)
    pipe = StableDiffusionPipeline.from_pretrained(
        MODEL_ID,
        torch_dtype=torch.float32,
        safety_checker=None,
        requires_safety_checker=False,
    )
    pipe = pipe.to("cpu")
    pipe.enable_attention_slicing()
    _pipeline = pipe
    print("[sprite] Model ready.", flush=True)
    return _pipeline


def _generate(prompt: str, width: int, height: int, steps: int, cfg_scale: float) -> str:
    """Generate image and return base64-encoded PNG."""
    pipe = _load_pipeline()
    result = pipe(
        prompt=prompt,
        width=width,
        height=height,
        num_inference_steps=steps,
        guidance_scale=cfg_scale,
    )
    img = result.images[0]
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


class SpriteHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        print(f"[sprite:{PORT}] {fmt % args}", flush=True)

    def do_GET(self) -> None:
        # Health-check probe
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", 0))
        body_raw = self.rfile.read(length)
        try:
            body = json.loads(body_raw)
        except json.JSONDecodeError:
            body = {}

        prompt: str = body.get("prompt", "pixel art sprite")
        width: int = int(body.get("width", 256))
        height: int = int(body.get("height", 256))
        steps: int = int(body.get("steps", 10))
        cfg_scale: float = float(body.get("cfg_scale", 7.0))

        print(f"[sprite] Generating: {prompt!r} ({width}x{height}, {steps} steps)", flush=True)
        try:
            b64 = _generate(prompt, width, height, steps, cfg_scale)
            response = json.dumps({"images": [b64]}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(response)))
            self.end_headers()
            self.wfile.write(response)
        except Exception as exc:
            print(f"[sprite] ERROR: {exc}", flush=True)
            error_body = json.dumps({"error": str(exc)}).encode()
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(error_body)))
            self.end_headers()
            self.wfile.write(error_body)


if __name__ == "__main__":
    _ensure_packages()
    server = http.server.HTTPServer((HOST, PORT), SpriteHandler)
    print(f"[sprite] Server listening on http://{HOST}:{PORT}", flush=True)
    print(f"[sprite] Model will be downloaded (~4 GB) on first request.", flush=True)
    print("[sprite] Ctrl-C to stop.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()
