"""Generate the two notification sounds (public domain, synthesized here).

motion: soft two-note chime, easy to ignore.
person: urgent rising triple pulse played twice, unmistakably different.
Run: python tools/make_sounds.py
"""
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(__file__).parents[1] / "app/android/app/src/main/res/raw"


def tone(freq, dur, shape="sine", vol=0.6):
    t = np.arange(int(RATE * dur)) / RATE
    wave_ = np.sin(2 * np.pi * freq * t)
    if shape == "square":  # soft square: odd harmonics, less harsh than a true square
        wave_ = sum(np.sin(2 * np.pi * freq * k * t) / k for k in (1, 3, 5, 7))
    env = np.minimum(1, t / 0.01) * np.exp(-t * (3 if shape == "sine" else 6))
    return vol * wave_ * env


def silence(dur):
    return np.zeros(int(RATE * dur))


def save(name, samples):
    samples = np.clip(samples / max(1e-9, np.abs(samples).max()) * 0.8, -1, 1)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((samples * 32767).astype(np.int16).tobytes())


motion = np.concatenate([tone(880, 0.25), tone(1318.5, 0.45)])
pulse = np.concatenate([tone(f, 0.11, "square") for f in (740, 988, 1318)] + [silence(0.02)])
person = np.concatenate([pulse, silence(0.12), pulse, silence(0.12), tone(1760, 0.35, "square")])

OUT.mkdir(parents=True, exist_ok=True)
save("obscura_motion", motion)
save("obscura_person", person)
print("written to", OUT)
