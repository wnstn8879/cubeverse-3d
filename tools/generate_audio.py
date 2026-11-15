#!/usr/bin/env python3
"""Create CubeVerse's original, deterministic prototype sound library.

No recordings, external samples, or third-party dependencies are used.
Run with --check to validate the 240 committed original PCM WAVs.
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
CLASSIC_PRESETS = ("bubble", "magnetic", "mechanical", "arcade", "soft", "plastic")
ASMR_PRESETS = ("squishy", "slime", "foam", "water")
PRESETS = CLASSIC_PRESETS + ASMR_PRESETS
EVENTS = ("touch", "start", "rotate", "snap", "rapid", "complete")
VARIATIONS = 4
DURATIONS = {"touch": .042, "start": .075, "rotate": .09, "snap": .1, "rapid": .13, "complete": .72}
ASMR_RATE = 32000
ASMR_DURATIONS = {"touch": .12, "start": .28, "rotate": .4, "snap": .38, "rapid": .52, "complete": 1.08}


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
    pitch = (.94, 1.0, 1.07, 1.13)[variant]
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


def generate_asmr(preset: str, event: str, variant: int) -> list[int]:
    """Layer pressure, friction, grains, and chirped bubbles with rounded tails.

    The four variants change source brightness, friction rhythm, resonances,
    grain positions, and release envelopes. They are not pitch-shifted copies.
    Stereo width is intentionally small so the mono downmix remains useful.
    """
    rng = random.Random(f"cubeverse-original-asmr-v2/{preset}/{event}/{variant}")
    rate = ASMR_RATE
    duration = ASMR_DURATIONS[event]
    count = int(rate * duration)
    brightness = (.78, .92, 1.08, 1.24)[variant]
    body_frequency = {"squishy": 113, "slime": 86, "foam": 145, "water": 174}[preset] * rng.uniform(.88, 1.12)
    attack = .005 if event == "touch" else .009
    final_cutoff = {"squishy": 1650, "slime": 2100, "foam": 3500, "water": 2700}[preset] * brightness
    low = warm = air = side = phase = 0.0
    a_low = 1 - math.exp(-2 * math.pi * 170 / rate)
    a_warm = 1 - math.exp(-2 * math.pi * 1450 * brightness / rate)
    a_air = 1 - math.exp(-2 * math.pi * 4300 * brightness / rate)
    a_side = 1 - math.exp(-2 * math.pi * 1800 / rate)
    flutter_hz = rng.uniform(10, 20)
    left, right = [], []
    for frame in range(count):
        t = frame / rate
        u = t / duration
        noise = rng.uniform(-1, 1)
        low += a_low * (noise - low)
        warm += a_warm * (noise - warm)
        air += a_air * (noise - air)
        side += a_side * (rng.uniform(-1, 1) - side)
        envelope = math.sin(math.pi * u) ** (.75 if event == "rotate" else 1.05)
        # A soft initial contact keeps feedback immediate despite the long tail.
        envelope += .18 * math.exp(-t * 22)
        if event == "rapid":
            envelope *= .55 + .45 * math.sin(math.pi * u * 2.1) ** 2
        if event == "complete":
            envelope *= .5 + .5 * math.sin(math.pi * u * 3.2) ** 2
        phase += 2 * math.pi * body_frequency * (1 + .47 * (1 - u) ** 2) / rate
        pressure = math.sin(phase + .14 * math.sin(2 * math.pi * 7 * t))
        wet = warm - low
        airy = air - warm
        if preset == "squishy":
            value = envelope * (.20 * pressure + .54 * low + .24 * wet * (.65 + .35 * math.sin(2 * math.pi * flutter_hz * t)))
            width = .075
        elif preset == "slime":
            stretch = .56 + .44 * math.sin(2 * math.pi * (flutter_hz * t + 4 * t * t)) ** 2
            value = envelope * (.065 * pressure + .27 * low + .58 * wet * stretch)
            width = .12
        elif preset == "foam":
            fizz = .68 + .32 * math.sin(2 * math.pi * (31 + variant * 4) * t) ** 2
            value = envelope * (.76 * airy * fizz + .19 * warm + .018 * pressure)
            width = .14
        else:
            value = envelope * (.12 * warm + .09 * low + .025 * pressure)
            width = .065
        left.append(value + width * side * envelope)
        right.append(value - width * side * envelope)

    # Independently placed pressure releases, sticky bubbles, foam grains, or drops.
    pulse_count = {"touch": 2, "start": 4, "rotate": 6, "snap": 4, "rapid": 8, "complete": 10}[event]
    if preset == "foam":
        pulse_count *= 2
    for pulse in range(pulse_count):
        onset = .002 if pulse == 0 else duration * rng.uniform(.1, .86)
        if event == "snap" and pulse == 1:
            onset = duration * rng.uniform(.25, .43)
        pan = rng.uniform(-.28, .28)
        if preset == "squishy":
            frequency = rng.uniform(105, 205) * brightness
            sweep = frequency * rng.uniform(.7, 1.2)
            decay, level = rng.uniform(.03, .06), rng.uniform(.10, .19)
        elif preset == "slime":
            frequency = rng.uniform(200, 510) * brightness
            sweep = frequency * rng.uniform(.8, 1.7)
            decay, level = rng.uniform(.018, .042), rng.uniform(.065, .14)
        elif preset == "foam":
            frequency = rng.uniform(700, 1800) * brightness
            sweep = frequency * .15
            decay, level = rng.uniform(.008, .023), rng.uniform(.035, .08)
        else:
            frequency = rng.uniform(310, 690) * brightness
            sweep = frequency * rng.uniform(.7, 1.6)
            decay, level = rng.uniform(.035, .065), rng.uniform(.13, .23)
        if event == "complete":
            # A material-specific rising release rather than a shared arcade tune.
            frequency *= 1 + .28 * pulse / pulse_count
        start = int(onset * rate)
        tail = min(count - start, int(rate * decay * 6))
        grain_low = grain_high = 0.0
        for offset in range(max(0, tail)):
            t = offset / rate
            pulse_envelope = (1 - math.exp(-t / .0035)) * math.exp(-t / decay)
            chirp = 2 * math.pi * (frequency * t + sweep * .013 * (1 - math.exp(-t / .013)))
            if preset == "foam":
                noise = rng.uniform(-1, 1)
                grain_low += .10 * (noise - grain_low)
                grain_high += .48 * (noise - grain_high)
                modal = grain_high - grain_low
            elif preset == "water":
                modal = .70 * math.sin(chirp) + .19 * math.sin(chirp * 1.48) + .11 * math.sin(chirp * 2.09)
            else:
                modal = .86 * math.sin(chirp) + .14 * math.sin(chirp * 1.71)
            value = level * modal * pulse_envelope
            left[start + offset] += value * (1 - pan)
            right[start + offset] += value * (1 + pan)

    # Remove DC, roll off hard edges, and fade both boundaries before PCM encoding.
    alpha = 1 - math.exp(-2 * math.pi * final_cutoff / rate)
    for channel in (left, right):
        average = sum(channel) / len(channel)
        filtered = 0.0
        for frame, value in enumerate(channel):
            filtered += alpha * (value - average - filtered)
            t = frame / rate
            fade = min(1, t / attack) * min(1, (duration - t) / .025)
            channel[frame] = math.tanh(filtered * 1.3) * fade
    peak = max(max(abs(value) for value in left), max(abs(value) for value in right))
    target = {"touch": .46, "start": .62, "rotate": .34, "snap": .70, "rapid": .65, "complete": .68}[event]
    gain = target * 32767 / max(peak, 1e-9)
    return [sample for pair in zip(left, right) for sample in (round(pair[0] * gain), round(pair[1] * gain))]


def write_library() -> None:
    for preset in PRESETS:
        directory = DEST / preset
        directory.mkdir(parents=True, exist_ok=True)
        for event in EVENTS:
            for variant in range(VARIATIONS):
                textured = preset in ASMR_PRESETS
                samples = generate_asmr(preset, event, variant) if textured else generate(preset, event, variant)
                with wave.open(str(directory / f"{event}_{variant}.wav"), "wb") as output:
                    output.setnchannels(2 if textured else 1)
                    output.setsampwidth(2)
                    output.setframerate(ASMR_RATE if textured else RATE)
                    output.writeframes(struct.pack(f"<{len(samples)}h", *samples))


def check_library() -> None:
    seen = set()
    count = 0
    maximum = 0
    total_bytes = 0
    asmr_metrics = {preset: {"rms": [], "brightness": [], "correlation": []} for preset in ASMR_PRESETS}
    for preset in PRESETS:
        for event in EVENTS:
            waveforms = []
            for variant in range(VARIATIONS):
                path = DEST / preset / f"{event}_{variant}.wav"
                with wave.open(str(path), "rb") as source:
                    textured = preset in ASMR_PRESETS
                    channels = 2 if textured else 1
                    rate = ASMR_RATE if textured else RATE
                    durations = ASMR_DURATIONS if textured else DURATIONS
                    assert source.getnchannels() == channels, path
                    assert source.getsampwidth() == 2, path
                    assert source.getframerate() == rate, path
                    raw = source.readframes(source.getnframes())
                    frames = struct.unpack(f"<{len(raw)//2}h", raw)
                    assert len(frames) == int(rate * durations[event]) * channels, path
                    assert any(abs(value) > 100 for value in frames), path
                    assert max(abs(value) for value in frames) < 32767, path
                    if textured:
                        left, right = frames[0::2], frames[1::2]
                        mono = [(l + r) / 65534 for l, r in zip(left, right)]
                        rms = math.sqrt(sum(value * value for value in mono) / len(mono))
                        difference = math.sqrt(sum(((l - r) / 65534) ** 2 for l, r in zip(left, right)) / len(left))
                        brightness = math.sqrt(sum((mono[i] - mono[i-1]) ** 2 for i in range(1, len(mono))) / len(mono)) / max(rms, 1e-9)
                        assert abs(sum(mono) / len(mono)) < .005, f"DC offset: {path}"
                        assert .006 < rms < .45, f"Invalid mono downmix RMS: {path}"
                        assert difference > .001, f"Missing stereo variation: {path}"
                        assert max(abs(left[0]), abs(right[0]), abs(left[-1]), abs(right[-1])) < 64, f"Unfaded boundary: {path}"
                        asmr_metrics[preset]["rms"].append(rms)
                        asmr_metrics[preset]["brightness"].append(brightness)
                        for previous in waveforms:
                            numerator = sum(a * b for a, b in zip(mono, previous))
                            denominator = math.sqrt(sum(a * a for a in mono) * sum(b * b for b in previous))
                            correlation = abs(numerator / max(denominator, 1e-9))
                            assert correlation < .97, f"Nearly identical variants: {path}"
                            asmr_metrics[preset]["correlation"].append(correlation)
                        waveforms.append(mono)
                    digest = hashlib.sha256(raw).hexdigest()
                    assert digest not in seen, f"Duplicate waveform: {path}"
                    seen.add(digest)
                    maximum = max(maximum, max(abs(value) for value in frames))
                    total_bytes += len(raw)
                    count += 1
    assert count == len(PRESETS) * len(EVENTS) * VARIATIONS == 240
    print(f"PASS: {count} distinct PCM16 WAVs, {len(PRESETS)} presets × {len(EVENTS)} events × {VARIATIONS} variants; peak {maximum}/32767; {total_bytes} PCM bytes; no clipped or silent samples.")
    for preset, metrics in asmr_metrics.items():
        print(f"ASMR {preset}: stereo {ASMR_RATE}Hz; RMS {min(metrics['rms']):.3f}–{max(metrics['rms']):.3f}; brightness {min(metrics['brightness']):.3f}–{max(metrics['brightness']):.3f}; maximum variant correlation {max(metrics['correlation']):.3f}; fades/DC/mono downmix passed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate existing assets without regenerating")
    args = parser.parse_args()
    if not args.check:
        write_library()
    check_library()
