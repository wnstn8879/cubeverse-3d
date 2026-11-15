extends SceneTree
## Real stream/playback checks. Dummy audio verifies scheduling and resources,
## not human preference, target-device latency or physical actuator behavior.

const Audio = preload("res://scripts/audio/cube_audio.gd")
var checks := 0
var failures: Array[String] = []
var sound


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("AUDIO_CHECK_FAILED: " + message)


func _clear_voices() -> void:
	for voice in sound._voices:
		voice.stop()
		voice.set_meta("event", "")
		voice.set_meta("preview", false)


func _voice_for(event: String, preset_id: String):
	for voice in sound._voices:
		if voice.get_meta("event", "") == event and voice.get_meta("preset", "") == preset_id:
			return voice
	return null


func _count_active(event: String = "", preview_only := false) -> int:
	var active := 0
	for voice in sound._voices:
		if not voice.playing: continue
		if not event.is_empty() and voice.get_meta("event", "") != event: continue
		if preview_only and not voice.get_meta("preview", false): continue
		active += 1
	return active


func _run() -> void:
	var initial_buses := AudioServer.bus_count
	sound = Audio.new()
	root.add_child(sound)
	await process_frame
	_check(sound.ready_for_audio, "all sounds preload before interaction")
	_check(Audio.PRESETS.size() == 10, "ten real presets")
	_check(sound._voices.size() == 10, "voice pool is bounded at ten")
	var bus_index := AudioServer.get_bus_index(sound._bus_name)
	_check(bus_index > 0, "SFX owns its own bus")
	_check(AudioServer.get_bus_effect(bus_index, 0) is AudioEffectLimiter, "mixed transient peaks have a limiter")
	for preset_id in Audio.PRESETS:
		_check(sound._streams.has(preset_id), "preset bank exists: " + preset_id)
		for event in Audio.EVENTS:
			var samples: Array = sound._streams[preset_id][event]
			_check(samples.size() == 4, "%s/%s has four real variants" % [preset_id, event])
			for sample in samples:
				_check(sample is AudioStreamWAV and sample.get_length() > 0.01, "nonempty WAV: " + sample.resource_path)
				if preset_id in Audio.ASMR_PRESETS:
					_check(sample.stereo and sample.mix_rate == 32000, "textured ASMR retains stereo32k")
			sound.set_preset(preset_id)
			_clear_voices()
			sound.play_event(event, 1.2)
			var voice = _voice_for(event, preset_id)
			_check(voice != null and voice.playing, "%s/%s actually starts pooled playback" % [preset_id, event])
			if voice != null:
				_check(voice.stream in samples, "playback uses the selected preset's event bank")
				_check(voice.pitch_scale > 0.90 and voice.pitch_scale < 1.13, "pitch variation stays gentle")
			# Check startup before yielding: the shortest contact can legitimately end
			# during a busy headless frame. The audio server then gets a frame to mix.
			await process_frame
	await _test_material_variation()
	await _test_limits_and_preview()
	var selected: String = sound.preset
	sound.set_preset("unknown")
	_check(sound.preset == selected, "invalid preset never replaces selection")
	sound.set_volume(9)
	_check(is_equal_approx(sound.volume, 1.0), "volume upper bound")
	sound.set_volume(-1)
	_check(is_zero_approx(sound.volume), "volume lower bound")
	_clear_voices()
	sound.play_event("snap")
	_check(_count_active() == 0, "muted sound never starts playback")
	sound.set_haptics(false, 0.8)
	_check(not sound.haptics_enabled and not sound._can_haptic(), "haptic switch disables events")
	_check(not sound.haptics_supported, "desktop falls back without a physical actuator")
	var owned_bus: String = sound._bus_name
	sound.set_volume(0.65)
	sound.preview("squishy")
	sound.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	_check(AudioServer.get_bus_index(owned_bus) == -1 and AudioServer.bus_count == initial_buses, "pending preview cancels and manager removes only its own audio bus")
	for failure in failures: printerr(failure)
	print("AUDIO_TEST_RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_material_variation() -> void:
	sound._rng.seed = 62026
	for preset_id in Audio.PRESETS:
		var previous := -1
		for _index in range(24):
			_clear_voices()
			sound.set_preset(preset_id)
			sound.play_event("touch", 1)
			var voice = _voice_for("touch", preset_id)
			var variant := int(voice.get_meta("variant", -1))
			_check(variant != previous, "consecutive contact samples differ: " + preset_id)
			previous = variant
	var slow_variant := 0.0
	var fast_variant := 0.0
	var slow_pitch := 0.0
	var fast_pitch := 0.0
	for speed in [0.2, 3.0]:
		for _index in range(120):
			_clear_voices()
			sound._play("start", speed, "squishy")
			var voice = _voice_for("start", "squishy")
			if speed < 1:
				slow_variant += int(voice.get_meta("variant"))
				slow_pitch += voice.pitch_scale
			else:
				fast_variant += int(voice.get_meta("variant"))
				fast_pitch += voice.pitch_scale
	_check(fast_variant / 120 > slow_variant / 120 + 0.4, "fast movement selects brighter source textures")
	_check(fast_pitch / 120 > slow_pitch / 120 + 0.1, "movement speed changes pitch as well as source sample")


func _test_limits_and_preview() -> void:
	_clear_voices()
	sound.set_preset("squishy")
	sound.play_event("rotate", 1)
	sound.play_event("rotate", 1)
	_check(_count_active("rotate") == 1, "per-frame rotation events are rate limited")
	_clear_voices()
	for _index in range(12): sound._play("rotate", 1, "slime")
	_check(_count_active("rotate") == 2, "long textures never exceed two concurrent voices")
	_clear_voices()
	for _index in range(18): sound._play("touch", 1, "foam")
	_check(_count_active() <= 10, "fast input cannot grow the voice pool")
	_clear_voices()
	for _index in range(10): sound._play("complete", 1, "water")
	sound._play("touch", 1, "water")
	_check(_count_active("complete") == 10 and _count_active("touch") == 0, "completion tails are protected under saturation")
	_clear_voices()
	sound.set_preset("magnetic")
	sound.preview("slime")
	_check(sound.preset == "magnetic", "preview preserves selected sound")
	await create_timer(0.13).timeout
	_check(_count_active("start", true) > 0, "preview includes squeeze pressure")
	await create_timer(0.23).timeout
	_check(_count_active("rotate", true) > 0, "preview includes sustained friction texture")
	await create_timer(0.26).timeout
	_check(_count_active("snap", true) > 0, "preview includes material release")
	sound.preview("water")
	await create_timer(0.13).timeout
	_check(_voice_for("start", "water") != null, "new preview replaces old material")
	sound.play_event("touch")
	await create_timer(0.55).timeout
	_check(_count_active("", true) == 0, "gameplay cancels stale preview scheduling")
	_check(sound.preset == "magnetic", "preview sequence never overwrites selection")
