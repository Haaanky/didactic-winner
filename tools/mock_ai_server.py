#!/usr/bin/env python3
"""Mock local AI server for generate_asset.sh testing.

Serves responses at:
  POST http://localhost:7860/sdapi/v1/txt2img  → {"images": ["<base64 1x1 PNG>"]}
  POST http://localhost:8080/generate/sfx      → real WAV file (sine wave)
  POST http://localhost:8080/generate/music    → real WAV file (chord tone)

The audio files are synthesised with Python stdlib (wave + math) — no external
dependencies required.  They are short (2 s) but fully valid WAV files that any
media player or audio library will load without error.
"""
import base64
import http.server
import io
import json
import math
import struct
import threading
import wave

# 1×1 red pixel PNG (base64) — used by the sprite endpoint
PNG_B64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADklEQVQI12P4z8BQ"
    "DwADhQGAWjR9awAAAABJRU5ErkJggg=="
)


def _build_wav(frequency: float = 440.0, duration: float = 2.0,
               sample_rate: int = 22050) -> bytes:
    """Return bytes of a PCM WAV file containing a pure sine-wave tone."""
    num_samples = int(sample_rate * duration)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)       # mono
        wf.setsampwidth(2)       # 16-bit samples
        wf.setframerate(sample_rate)
        frames = bytearray()
        for i in range(num_samples):
            t = i / sample_rate
            amplitude = 0.3
            sample = int(32767 * amplitude * math.sin(2 * math.pi * frequency * t))
            frames += struct.pack("<h", sample)
        wf.writeframes(bytes(frames))
    return buf.getvalue()


# Pre-build the two audio responses once at start-up.
SFX_WAV   = _build_wav(frequency=220.0, duration=2.0)   # A3  — ambient rumble
MUSIC_WAV = _build_wav(frequency=329.6, duration=4.0)   # E4  — melodic tone


class SpriteHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[sprite:7860] {fmt % args}", flush=True)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        self.rfile.read(length)
        body = json.dumps({"images": [PNG_B64]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)


class AudioHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[audio:8080] {fmt % args}", flush=True)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        # Choose response based on path
        audio = MUSIC_WAV if b"music" in self.path.encode() else SFX_WAV
        self.send_response(200)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", len(audio))
        self.end_headers()
        self.wfile.write(audio)


def start(host: str, port: int, handler) -> http.server.HTTPServer:
    srv = http.server.HTTPServer((host, port), handler)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    return srv


if __name__ == "__main__":
    sprite_srv = start("127.0.0.1", 7860, SpriteHandler)
    audio_srv  = start("127.0.0.1", 8080, AudioHandler)
    print("Mock servers started: sprite=7860  audio=8080", flush=True)
    print(f"  SFX WAV:   {len(SFX_WAV):,} bytes  (220 Hz sine, 2 s)", flush=True)
    print(f"  Music WAV: {len(MUSIC_WAV):,} bytes (329.6 Hz sine, 4 s)", flush=True)
    print("Ctrl-C to stop.", flush=True)
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        sprite_srv.shutdown()
        audio_srv.shutdown()
