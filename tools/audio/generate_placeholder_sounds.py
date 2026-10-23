"""Placeholder sound effects for Race to the Moon: simple synth bleeps so the sound hooks can be heard.

Run from the repo root:  python tools/audio/generate_placeholder_sounds.py
Writes .wav files to assets/audio/sfx/ and assets/audio/loops/. No dependencies beyond Python.
These are meant to be replaced by real sounds: drop a file with the same name (.wav or .ogg) in its place
and delete the placeholder. Don't re-run this script after that, or it will overwrite the real sounds.
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "assets" / "audio"
RATE = 44100


def write(rel: str, samples: list[float]) -> None:
    path = AUDIO / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.5 / peak  # normalise every placeholder to the same peak level
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print(f"wrote {path.relative_to(ROOT)}")


def envelope(i: int, n: int, attack: float = 0.005, release: float = 0.05) -> float:
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (n - i) / RATE / release) if release > 0 else 1.0
    return a * r


def tone(freq_at, seconds: float, shape: str = "sine", release: float = 0.05) -> list[float]:
    n = int(seconds * RATE)
    out, phase = [], 0.0
    for i in range(n):
        phase += freq_at(i / n) / RATE
        p = phase % 1.0
        v = math.sin(phase * math.tau) if shape == "sine" else (1.0 if p < 0.5 else -1.0) * 0.6
        out.append(v * envelope(i, n, release=release))
    return out


def noise(seconds: float, rnd: random.Random, smooth: float) -> list[float]:
    """Low-passed noise; smaller `smooth` = deeper rumble."""
    out, v = [], 0.0
    for _ in range(int(seconds * RATE)):
        v += (rnd.uniform(-1, 1) - v) * smooth
        out.append(v)
    return out


def main() -> None:
    rnd = random.Random(1)
    write("sfx/jump.wav", tone(lambda t: 300 + 500 * t, 0.12, "square"))
    write("sfx/land.wav", [s * envelope(i, 3500, release=0.06) for i, s in enumerate(noise(0.08, rnd, 0.05))])
    write("sfx/countdown_beep.wav", tone(lambda t: 880, 0.15))
    rumble = noise(1.4, rnd, 0.02)
    write("sfx/liftoff.wav", [s * min(1.0, i / (RATE * 0.3)) * envelope(i, len(rumble), release=0.5)
                              for i, s in enumerate(rumble)])
    write("sfx/warning.wav", tone(lambda t: 660 if t < 0.5 else 880, 0.4, "square"))
    notes = [523.25, 659.25, 783.99, 1046.5]
    write("sfx/win.wav", sum((tone(lambda t, f=f: f, 0.15) for f in notes), []))
    write("sfx/lose.wav", sum((tone(lambda t, f=f: f * (1 - 0.1 * t), 0.25) for f in (392.0, 349.23, 293.66)), []))

    # Loops: whole number of cycles and no fade, so they repeat without a click.
    engine = noise(2.0, rnd, 0.03)
    fade = int(0.2 * RATE)  # crossfade the end into the start for a seamless loop
    for i in range(fade):
        t = i / fade
        engine[i] = engine[i] * t + engine[len(engine) - fade + i] * (1 - t)
    write("loops/rocket_engine.wav", engine[: len(engine) - fade])
    siren, phase = [], 0.0
    for i in range(RATE):  # 1 second: 600 -> 900 -> 600 Hz
        freq = 750 - 150 * math.cos(i / RATE * math.tau)
        phase += freq / RATE
        siren.append(math.sin(phase * math.tau))
    write("loops/warning_alarm.wav", siren)


if __name__ == "__main__":
    main()
