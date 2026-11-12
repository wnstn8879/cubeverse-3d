#!/usr/bin/env python3
"""Create CubeVerse's original, deterministic prototype sound library.

No recordings, external samples, or third-party dependencies are used.
Run with --check to validate the 108 committed mono PCM WAVs.
"""

from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "audio"
RATE = 22050
PRESETS = ("bubble", "magnetic", "mechanical", "arcade", "soft", "plastic")
EVENTS = ("touch", "start", "rotate", "snap", "rapid", "complete")
DURATIONS = {"touch": .042, "start": .075, "rotate": .09, "snap": .1, "rapid": .13, "complete": .72}


def voice(preset: str, t: float, pitch: float, noise: float, smooth_noise: float) -> float:
    """Different physical metaphors, generated rather than sampled."""
    if preset == "bubble":
        phase = 2 * math.pi * (440 * pitch * t - 1080 * pitch * t * t)
        return .75 * math.sin(phase) * math.exp(-43 * t) + .22 * noise * math.exp(-100 * t)
    if preset == "magnetic":
        return (.5 * math.sin(2 * math.pi * 1250 * pitch * t) * math.exp(-65 * t)
                + .34 * math.sin(2 * math.pi * 320 * pitch * t) * math.exp(-45 * t)
                + .2 * noise * math.exp(-140 * t))
    if preset == "mechanical":
        latch = max(0.0, t - .018)
        return (.32 * noise * math.exp(-85 * t) + .3 * math.sin(2 * math.pi * 2200 * pitch * t) * math.exp(-110 * t)
                + (.34 * math.sin(2 * math.pi * 570 * pitch * latch) * math.exp(-90 * latch) if t > .018 else 0))
    if preset == "arcade":
        frequency = 720 * pitch if t < .022 else 1080 * pitch
        return .4 * (1 if math.sin(2 * math.pi * frequency * t) > 0 else -1) * math.exp(-39 * t)
    if preset == "soft":
        return .42 * smooth_noise * math.exp(-44 * t) + .46 * math.sin(2 * math.pi * 230 * pitch * t) * math.exp(-58 * t)
    return (.34 * noise * math.exp(-55 * t) + .37 * math.sin(2 * math.pi * 690 * pitch * t) * math.exp(-72 * t)
            + .18 * math.sin(2 * math.pi * 1650 * pitch * t) * math.exp(-80 * t))


def generate(preset: str, event: str, variant: int) -> list[int]:
    rng = random.Random(f"cubeverse-original-v1/{preset}/{event}/{variant}")
    pitch = (.94, 1.0, 1.07)[variant]
    event_pitch = {"touch": 1.23, "start": .88, "rotate": .69, "snap": 1, "rapid": 1.08, "complete": 1}[event]
    duration = DURATIONS[event]
    smooth = 0.0
    samples = []
    for frame in range(int(RATE * duration)):
        t = frame / RATE
        noise = rng.uniform(-1, 1)
        smooth = .8 * smooth + .2 * noise
        if event == "complete":
            # C-major rising arpeggio, with preset-specific transient under each note.
            value = 0.0
            for note_index, frequency in enumerate((523.25, 659.25, 783.99, 1046.5)):
                note_t = t - note_index * .125
                if note_t >= 0:
                    value += .24 * math.sin(2 * math.pi * frequency * pitch * note_t) * math.exp(-7.3 * note_t)
                    value += .16 * voice(preset, note_t, pitch, noise, smooth)
        elif event == "rapid":
            value = voice(preset, t, pitch * event_pitch, noise, smooth)
            if t >= .042:
                value += .72 * voice(preset, t - .042, pitch * 1.12, noise, smooth)
        elif event == "rotate":
            # A short textured brush sound; playback is rate-limited by the manager.
            value = .38 * voice(preset, t, pitch * event_pitch, noise, smooth)
            value += .11 * smooth * math.sin(math.pi * t / duration) * math.exp(-15 * t)
        else:
            value = voice(preset, t, pitch * event_pitch, noise, smooth)
        # Sample boundary fades avoid clicks introduced by cutting off the waveform.
        fade_in = min(1, frame / max(1, RATE * .0005))
        fade_out = min(1, (duration - t) / .006)
        samples.append(value * fade_in * fade_out)
    peak = max(abs(sample) for sample in samples)
    gain = {"touch": .32, "start": .48, "rotate": .24, "snap": .68, "rapid": .62, "complete": .68}[event] / max(peak, 1e-9)
    if preset == "soft":
        gain *= .68
    return [round(sample * gain * 32767) for sample in samples]


def write_library() -> None:
    for preset in PRESETS:
        directory = DEST / preset
        directory.mkdir(parents=True, exist_ok=True)
        for event in EVENTS:
            for variant in range(3):
                samples = generate(preset, event, variant)
                with wave.open(str(directory / f"{event}_{variant}.wav"), "wb") as output:
                    output.setnchannels(1)
                    output.setsampwidth(2)
                    output.setframerate(RATE)
                    output.writeframes(struct.pack(f"<{len(samples)}h", *samples))


def check_library() -> None:
    seen = set()
    count = 0
    maximum = 0
    total_bytes = 0
    for preset in PRESETS:
        for event in EVENTS:
            for variant in range(3):
                path = DEST / preset / f"{event}_{variant}.wav"
                with wave.open(str(path), "rb") as source:
                    assert source.getnchannels() == 1, path
                    assert source.getsampwidth() == 2, path
                    assert source.getframerate() == RATE, path
                    raw = source.readframes(source.getnframes())
                    frames = struct.unpack(f"<{len(raw)//2}h", raw)
                    assert len(frames) == int(RATE * DURATIONS[event]), path
                    assert any(abs(value) > 100 for value in frames), path
                    assert max(abs(value) for value in frames) < 32767, path
                    digest = hashlib.sha256(raw).hexdigest()
                    assert digest not in seen, f"Duplicate waveform: {path}"
                    seen.add(digest)
                    maximum = max(maximum, max(abs(value) for value in frames))
                    total_bytes += len(raw)
                    count += 1
    assert count == 108
    print(f"PASS: {count} distinct WAVs, mono PCM16 {RATE} Hz; peak {maximum}/32767; {total_bytes} PCM bytes; no clipped or silent samples.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate existing assets without regenerating")
    args = parser.parse_args()
    if not args.check:
        write_library()
    check_library()
