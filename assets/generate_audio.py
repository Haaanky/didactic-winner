#!/usr/bin/env python3
"""
Procedural audio asset generator for Dudes in Alaska.
Produces WAV placeholder files for all music tracks and SFX.

All output is mono, 22050 Hz, 16-bit PCM.

Outputs (music — looping ambient, ~10 s each):
  assets/audio/spring_day.wav
  assets/audio/summer_day.wav
  assets/audio/autumn_day.wav
  assets/audio/winter_outdoor.wav
  assets/audio/cabin_interior.wav
  assets/audio/blizzard.wav

Outputs (SFX — short one-shot clips):
  assets/audio/menu_click.wav
  assets/audio/footstep_snow.wav
  assets/audio/footstep_grass.wav
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE: int = 22050
CHANNELS: int = 1
SAMPLE_WIDTH: int = 2  # 16-bit

OUT = os.path.join(os.path.dirname(__file__), "audio")
os.makedirs(OUT, exist_ok=True)


# ---------------------------------------------------------------------------
# Low-level helpers
# ---------------------------------------------------------------------------

def _to_int16(value: float) -> int:
    """Clamp [-1.0, 1.0] float to int16 range."""
    clamped = max(-1.0, min(1.0, value))
    return int(clamped * 32767)


def _write_wav(filename: str, samples: list) -> None:
    path = os.path.join(OUT, filename)
    packed = struct.pack(f"<{len(samples)}h", *[_to_int16(s) for s in samples])
    with wave.open(path, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(SAMPLE_WIDTH)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(packed)
    print(f"  Saved {path}")


def _sine(freq: float, t: float, phase: float = 0.0) -> float:
    return math.sin(2.0 * math.pi * freq * t + phase)


def _envelope(t: float, duration: float, attack: float = 0.05, release: float = 0.1) -> float:
    """Linear attack/release envelope; flat sustain in between."""
    if t < attack:
        return t / attack
    if t > duration - release:
        return (duration - t) / release
    return 1.0


def _white_noise(rng: random.Random) -> float:
    return rng.uniform(-1.0, 1.0)


def _fade_loop(samples: list, fade_samples: int) -> list:
    """Cross-fade the end of a list into the beginning so it loops smoothly."""
    n = len(samples)
    fade = min(fade_samples, n // 2)
    result = list(samples)
    for i in range(fade):
        alpha = i / fade
        result[i] = result[i] * alpha + samples[n - fade + i] * (1.0 - alpha)
    return result


# ---------------------------------------------------------------------------
# Music track generators
# ---------------------------------------------------------------------------

def _ambient_chord(
    freqs: list,
    duration: float,
    amplitude: float,
    lfo_rate: float = 0.25,
    lfo_depth: float = 0.06,
    noise_level: float = 0.0,
    rng: random.Random = None,
) -> list:
    """
    Generate a looping ambient chord from a list of sine-wave frequencies.
    A slow LFO modulates amplitude for gentle movement.
    """
    if rng is None:
        rng = random.Random(42)
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        lfo = 1.0 + lfo_depth * math.sin(2.0 * math.pi * lfo_rate * t)
        s = sum(_sine(f, t) for f in freqs) / len(freqs)
        if noise_level > 0.0:
            s = s * (1.0 - noise_level) + _white_noise(rng) * noise_level
        s *= amplitude * lfo
        samples.append(s)
    return _fade_loop(samples, int(0.5 * SAMPLE_RATE))


def _wind_noise(
    duration: float,
    amplitude: float,
    low_cut_hz: float,
    rng: random.Random,
) -> list:
    """
    Filtered wind noise: white noise shaped by a simple one-pole low-pass filter
    plus a slow amplitude-modulating LFO.
    """
    n = int(duration * SAMPLE_RATE)
    # Low-pass coefficient: higher value = more bass, rougher wind
    alpha = 1.0 - math.exp(-2.0 * math.pi * low_cut_hz / SAMPLE_RATE)
    prev = 0.0
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        noise = _white_noise(rng)
        filtered = prev + alpha * (noise - prev)
        prev = filtered
        # Slow gust envelope
        gust = 0.7 + 0.3 * math.sin(2.0 * math.pi * 0.07 * t + 1.2)
        samples.append(filtered * amplitude * gust)
    return _fade_loop(samples, int(0.5 * SAMPLE_RATE))


def build_spring_day() -> None:
    # Bright major chord: C4, E4, G4, C5 — gentle and hopeful
    freqs = [261.63, 329.63, 392.00, 523.25]
    samples = _ambient_chord(
        freqs,
        duration=10.0,
        amplitude=0.22,
        lfo_rate=0.18,
        lfo_depth=0.08,
        rng=random.Random(1),
    )
    _write_wav("spring_day.wav", samples)


def build_summer_day() -> None:
    # Warm, slightly brighter chord: D4, F#4, A4, D5 — energetic
    freqs = [293.66, 369.99, 440.00, 587.33]
    samples = _ambient_chord(
        freqs,
        duration=10.0,
        amplitude=0.20,
        lfo_rate=0.22,
        lfo_depth=0.10,
        rng=random.Random(2),
    )
    _write_wav("summer_day.wav", samples)


def build_autumn_day() -> None:
    # A minor chord: A3, C4, E4, A4 — melancholy and wistful
    freqs = [220.00, 261.63, 329.63, 440.00]
    samples = _ambient_chord(
        freqs,
        duration=10.0,
        amplitude=0.20,
        lfo_rate=0.14,
        lfo_depth=0.06,
        rng=random.Random(3),
    )
    _write_wav("autumn_day.wav", samples)


def build_winter_outdoor() -> None:
    # Sparse, cold: high sparse tones (E5, B5) over low wind rumble
    rng = random.Random(4)
    n = int(10.0 * SAMPLE_RATE)
    # Low wind rumble
    wind = _wind_noise(10.0, amplitude=0.08, low_cut_hz=120.0, rng=rng)
    # Sparse sparse high tones
    tones = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        # Sparse bell-like tones that fade in/out slowly
        tone = (_sine(659.25, t) * 0.06 * max(0.0, math.sin(math.pi * t / 10.0)))
        tone += (_sine(987.77, t) * 0.04 * max(0.0, math.sin(math.pi * (t - 3.0) / 7.0) if t > 3.0 else 0.0))
        tones[i] = tone
    samples = [w + t for w, t in zip(wind, tones)]
    samples = _fade_loop(samples, int(0.5 * SAMPLE_RATE))
    _write_wav("winter_outdoor.wav", samples)


def build_cabin_interior() -> None:
    # Warm, cozy: low warm tones (C2, G2) + subtle crackling noise
    rng = random.Random(5)
    n = int(10.0 * SAMPLE_RATE)
    # Low warm drone
    freqs = [65.41, 98.00, 130.81]  # C2, G2, C3
    drone = _ambient_chord(
        freqs,
        duration=10.0,
        amplitude=0.15,
        lfo_rate=0.10,
        lfo_depth=0.05,
        rng=rng,
    )
    # Subtle crackling (sporadic noise bursts)
    crackle = []
    for i in range(n):
        t = i / SAMPLE_RATE
        if rng.random() < 0.001:
            c = _white_noise(rng) * 0.12
        else:
            c = 0.0
        crackle.append(c)
    samples = [d + c for d, c in zip(drone, crackle)]
    samples = _fade_loop(samples, int(0.5 * SAMPLE_RATE))
    _write_wav("cabin_interior.wav", samples)


def build_blizzard() -> None:
    # Heavy wind noise, harsh and continuous
    rng = random.Random(6)
    n = int(10.0 * SAMPLE_RATE)
    # Dense wind
    wind = _wind_noise(10.0, amplitude=0.30, low_cut_hz=400.0, rng=rng)
    # High-pitched howl overlay
    howl = []
    for i in range(n):
        t = i / SAMPLE_RATE
        h = _sine(220.0 + 60.0 * math.sin(2.0 * math.pi * 0.04 * t), t) * 0.06
        h += _sine(440.0 + 80.0 * math.sin(2.0 * math.pi * 0.07 * t + 1.0), t) * 0.04
        howl.append(h)
    samples = [w + h for w, h in zip(wind, howl)]
    samples = _fade_loop(samples, int(0.5 * SAMPLE_RATE))
    _write_wav("blizzard.wav", samples)


# ---------------------------------------------------------------------------
# SFX generators
# ---------------------------------------------------------------------------

def build_menu_click() -> None:
    # Short 55 ms beep: quick frequency sweep from 900 Hz down to 600 Hz
    duration = 0.055
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = t / duration
        freq = 900.0 - 300.0 * progress
        env = _envelope(t, duration, attack=0.005, release=0.02)
        samples.append(_sine(freq, t) * 0.45 * env)
    _write_wav("menu_click.wav", samples)


def build_footstep_snow() -> None:
    # Crunchy snow: white noise burst with slow high-pass shaping
    duration = 0.12
    n = int(duration * SAMPLE_RATE)
    rng = random.Random(10)
    # High-pass: difference of one-pole low-pass from signal
    alpha = 1.0 - math.exp(-2.0 * math.pi * 800.0 / SAMPLE_RATE)
    prev = 0.0
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        noise = _white_noise(rng)
        lp = prev + alpha * (noise - prev)
        prev = lp
        hp = noise - lp  # high-pass
        env = _envelope(t, duration, attack=0.005, release=0.06)
        samples.append(hp * 0.55 * env)
    _write_wav("footstep_snow.wav", samples)


def build_footstep_grass() -> None:
    # Soft grass rustle: lower noise burst, shorter
    duration = 0.09
    n = int(duration * SAMPLE_RATE)
    rng = random.Random(11)
    alpha = 1.0 - math.exp(-2.0 * math.pi * 400.0 / SAMPLE_RATE)
    prev = 0.0
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        noise = _white_noise(rng)
        lp = prev + alpha * (noise - prev)
        prev = lp
        hp = noise - lp
        env = _envelope(t, duration, attack=0.005, release=0.045)
        samples.append(hp * 0.40 * env)
    _write_wav("footstep_grass.wav", samples)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("Generating audio assets for Dudes in Alaska…")
    build_spring_day()
    build_summer_day()
    build_autumn_day()
    build_winter_outdoor()
    build_cabin_interior()
    build_blizzard()
    build_menu_click()
    build_footstep_snow()
    build_footstep_grass()
    print("Done.")
