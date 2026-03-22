#!/usr/bin/env python3
"""Mock local AI server for generate_asset.sh testing.

Serves valid responses at:
  POST http://localhost:7860/sdapi/v1/txt2img  → {"images": ["<base64 1x1 PNG>"]}
  POST http://localhost:8080/generate/sfx      → minimal MP3 bytes
  POST http://localhost:8080/generate/music    → minimal MP3 bytes
"""
import base64
import http.server
import json
import sys
import threading

# 1×1 red pixel PNG (base64)
PNG_B64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADklEQVQI12P4z8BQ"
    "DwADhQGAWjR9awAAAABJRU5ErkJggg=="
)

# Minimal silent MP3 frame (ID3v2 header + one silent MPEG frame)
# ID3v2 tag: "ID3" + version + flags + size (0 = no tags)
# Then a silent 128kbps MPEG1 Layer3 frame (FF FB 90 00 + 416 zero bytes)
MP3_BYTES = (
    b"ID3\x03\x00\x00\x00\x00\x00\x00"   # ID3v2.3, no frames, size=0
    b"\xff\xfb\x90\x00"                   # MPEG1 Layer3 128kbps 44100Hz sync word
    + b"\x00" * 413                        # silent frame body
)


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
        self.rfile.read(length)
        self.send_response(200)
        self.send_header("Content-Type", "audio/mpeg")
        self.send_header("Content-Length", len(MP3_BYTES))
        self.end_headers()
        self.wfile.write(MP3_BYTES)


def start(host, port, handler):
    srv = http.server.HTTPServer((host, port), handler)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    return srv


if __name__ == "__main__":
    sprite_srv = start("127.0.0.1", 7860, SpriteHandler)
    audio_srv  = start("127.0.0.1", 8080, AudioHandler)
    print("Mock servers started: sprite=7860  audio=8080", flush=True)
    print("Ctrl-C to stop.", flush=True)
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        sprite_srv.shutdown()
        audio_srv.shutdown()
