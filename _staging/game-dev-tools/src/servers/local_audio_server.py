#!/usr/bin/env python3
"""Local audio generation server — AudioCraft (MusicGen-small) backend.

Endpoints:
  POST /generate/sfx    Body: {"text": "...", "duration": 5}   → WAV bytes
  POST /generate/music  Body: {"text": "...", "duration": 30}  → WAV bytes

Dependencies are installed on first run (torch CPU, audiocraft).
The model is downloaded from HuggingFace on first request and cached in
~/.cache/huggingface/.

Model: facebook/musicgen-small (~300 MB download, one-time).
WARNING: CPU-only — expect 2–5 min per clip.
"""

import http.server
import importlib
import io
import json
import subprocess
import sys
import wave

HOST = "127.0.0.1"
PORT = 8080

REQUIRED_PACKAGES = ["torch", "audiocraft"]

DEFAULT_SFX_DURATION: float = 5.0
DEFAULT_MUSIC_DURATION: float = 30.0
MAX_DURATION: float = 30.0


def _ensure_packages() -> None:
    missing = []
    for pkg in REQUIRED_PACKAGES:
        spec = importlib.util.find_spec(pkg)
        if spec is None:
            missing.append(pkg)
    if not missing:
        return
    print(f"[audio] Installing missing packages: {missing}", flush=True)
    if "torch" in missing:
        subprocess.check_call([
            sys.executable, "-m", "pip", "install", "--quiet",
            "torch",
            "--index-url", "https://download.pytorch.org/whl/cpu",
        ])
        missing.remove("torch")
    if "audiocraft" in missing:
        subprocess.check_call([
            sys.executable, "-m", "pip", "install", "--quiet",
            "audiocraft",
        ])
        missing.remove("audiocraft")
    if missing:
        subprocess.check_call([
            sys.executable, "-m", "pip", "install", "--quiet",
        ] + missing)
    print("[audio] Packages ready.", flush=True)


_model = None


def _load_model():
    global _model
    if _model is not None:
        return _model
    from audiocraft.models import MusicGen
    print("[audio] Loading facebook/musicgen-small (CPU) — first use may take a few minutes...", flush=True)
    model = MusicGen.get_pretrained("facebook/musicgen-small")
    _model = model
    print("[audio] Model ready.", flush=True)
    return _model


def _generate_audio(text: str, duration: float) -> bytes:
    """Generate audio and return raw WAV bytes."""
    import torch
    model = _load_model()
    duration = min(duration, MAX_DURATION)
    model.set_generation_params(duration=duration)
    with torch.no_grad():
        wav = model.generate([text])
    # wav shape: (batch, channels, samples)
    samples = wav[0].squeeze(0).cpu().numpy()
    sample_rate: int = model.sample_rate
    # Normalise to int16
    import numpy as np
    samples_int16 = (samples * 32767).clip(-32768, 32767).astype(np.int16)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(samples_int16.tobytes())
    return buf.getvalue()


class AudioHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        print(f"[audio:{PORT}] {fmt % args}", flush=True)

    def do_GET(self) -> None:
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

        text: str = body.get("text", "ambient sound")
        is_music = "/music" in self.path
        default_dur = DEFAULT_MUSIC_DURATION if is_music else DEFAULT_SFX_DURATION
        duration: float = float(body.get("duration", default_dur))

        asset_type = "music" if is_music else "sfx"
        print(f"[audio] Generating {asset_type}: {text!r} ({duration}s)", flush=True)
        try:
            wav_bytes = _generate_audio(text, duration)
            self.send_response(200)
            self.send_header("Content-Type", "audio/wav")
            self.send_header("Content-Length", str(len(wav_bytes)))
            self.end_headers()
            self.wfile.write(wav_bytes)
        except Exception as exc:
            print(f"[audio] ERROR: {exc}", flush=True)
            error_body = json.dumps({"error": str(exc)}).encode()
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(error_body)))
            self.end_headers()
            self.wfile.write(error_body)


if __name__ == "__main__":
    _ensure_packages()
    server = http.server.HTTPServer((HOST, PORT), AudioHandler)
    print(f"[audio] Server listening on http://{HOST}:{PORT}", flush=True)
    print("[audio] Model will be downloaded (~300 MB) on first request.", flush=True)
    print("[audio] Ctrl-C to stop.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()
