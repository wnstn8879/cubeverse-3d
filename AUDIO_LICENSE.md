# CubeVerse original audio and ASMR textures

All WAV files in `assets/audio/` were synthesized specifically for CubeVerse by
`tools/generate_audio.py`. No existing game, keyboard recording, or commercial
sample was copied or used as an input. The generator uses only Python's standard
library and deterministic mathematical oscillators plus seeded noise.

The generated WAV assets are dedicated to the public domain under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
CC0 applies to the generated WAV assets; source-code licensing is separate.

## Library

- Ten free presets. The original six remain: bubble, magnetic, mechanical,
  arcade, soft, and plastic. Four new original textures are included:
  - `squishy` / 말랑이 ASMR: soft pressure, a warm low body and rounded releases.
  - `slime` / 슬라임 스트레치: wet friction, stretching pulses and sticky bubbles.
  - `foam` / 크리미 폼: airy fine grains with a light, fizzing pressure texture.
  - `water` / 물방울 젤: multiple soft resonant drops with changing release tails.
- Six events per preset: touch, start, rotate, snap, rapid, and complete.
- Four distinct waveforms per event: 240 WAV files in total.
- Original six: mono, 22,050 Hz, 16-bit PCM. New ASMR four: stereo, 32,000 Hz,
  16-bit PCM. The new envelopes range from 120 ms contact to 1.08 s completion.
  All 240 WAVs together contain 6,917,920 bytes of PCM audio.
- ASMR variants change pressure resonance, noise filtering, grain timing,
  release envelopes and stereo position. They are not repeated copies with
  only a pitch change. Stereo width is narrow enough for a useful mono downmix.
- All sounds are preloaded; ten reusable voices cap simultaneous playback.
- Rotation texture is limited to one playback per 85 ms for the original six,
  or 165 ms for longer ASMR textures, with at most two rotation voices active.
  Ongoing textures cover movement instead of being repeatedly cut off.
- Consecutive playback of the same event avoids the last source variant.
  Faster motion favors brighter variants and slightly higher pitch/gain.
  Rapid successive snaps select their own release event.
- Preview plays contact → squeeze → friction → release, preserves the selected
  gameplay preset, and cancels stale preview events when gameplay resumes.
- Each manager owns a separate effect bus with a limiter. It protects combined
  transient peaks while leaving other application audio buses unchanged.
- There are no premium recordings or purchase claims in this library.

## Quality and device verification

These are **original synthesized textures**, not studio recordings of real
objects. Their timbres interpret the material labels. The four new ASMR banks
add layered pressure and friction rather than only short repeated clicks.
Subjective quality, headphone comfort, mobile speaker balance and whether users
find them satisfying still require human listening on target devices. No
listening panel or physical-device approval has been completed. Do not describe
them as recorded real squishies, slime, cubes or keyboards.

`python3 tools/generate_audio.py --check` verifies all 240 files are distinct,
non-silent, correctly formatted and free from sample clipping. For ASMR it also
checks boundary fades, DC offset, stereo variation, mono downmix and pairwise
variant correlation. Highest PCM peak is 22,937/32,767. ASMR maximum absolute
variant correlations are 0.761 (squishy), 0.275 (slime), 0.067 (foam), and 0.090
(water).

After importing the project, `python3 tools/test_audio.py` runs those asset
checks plus actual imported Godot stream/playback tests with the Dummy audio
driver. It checks all ten presets and six events, non-repeating material
variants, speed-dependent textures, bounded voices, preview cancellation,
selection preservation and cleanup. These checks do not establish perceived
sound quality, mobile latency, speaker output or a 60 FPS performance result.

The current test result is `AUDIO_TEST_RESULT checks=851 failures=0`.
Preview scheduling and native completion pulses use manager-owned Timer nodes,
so leaving the app while a preview is pending cancels the sequence without a
stranded SceneTreeTimer. The audio test treats resource-leak diagnostics as a
failure as well as script/runtime errors.

Android uses Godot's native `Input.vibrate_handheld` API. Duration differs by
preset; completion uses a three-pulse pattern. Amplitude requires device/Android
support and may be ignored by the hardware. Web checks `navigator.vibrate`
before enabling support; browsers may still reject vibration without an active
user gesture, and standard web vibration has no amplitude control. Unsupported
platforms perform no vibration. Actual Android actuator behavior, device latency,
and mobile audio performance remain unverified until a physical-device test.
