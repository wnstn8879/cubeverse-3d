# CubeVerse original prototype audio

All WAV files in `assets/audio/` were synthesized specifically for CubeVerse by
`tools/generate_audio.py`. No existing game, keyboard recording, or commercial
sample was copied or used as an input. The generator uses only Python's standard
library and deterministic mathematical oscillators plus seeded noise.

The generated WAV assets are dedicated to the public domain under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
The generator and playback code follow the project's source-code license.

## Library

- Six free presets: bubble, magnetic, mechanical, arcade, soft, and plastic.
- Six events per preset: touch, start, rotate, snap, rapid, and complete.
- Three distinct waveforms per event: 108 WAV files in total.
- Mono, 22,050 Hz, 16-bit PCM; every file is shorter than one second.
- All sounds are preloaded; ten reusable voices cap simultaneous playback.
- Rotation texture is limited to one playback per 85 ms. Rapid successive snaps
  select their own transient. Pitch and gain vary with speed.
- There are no premium recordings or purchase claims in this library.

## Quality and device verification

These are **functional synthesized prototype sounds**, not final studio-recorded
ASMR assets. Their timbres are interpretations of the labels. Final perceptual
quality, headphone comfort, and mobile speaker balance require human listening
on target devices. Do not describe them as recorded real cube/keyboard sounds.

`python3 tools/generate_audio.py --check` verifies all 108 files are distinct,
non-silent, correctly formatted, and free from sample clipping. This validates
asset integrity only; it does not establish 60 FPS or mobile audio latency.

Android uses Godot's native `Input.vibrate_handheld` API. Duration differs by
preset; completion uses a three-pulse pattern. Amplitude requires device/Android
support and may be ignored by the hardware. Web checks `navigator.vibrate`
before enabling support; browsers may still reject vibration without an active
user gesture, and standard web vibration has no amplitude control. Unsupported
platforms perform no vibration. Actual Android actuator behavior, device latency,
and mobile audio performance remain unverified until a physical-device test.
