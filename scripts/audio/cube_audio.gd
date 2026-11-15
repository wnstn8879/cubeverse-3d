class_name CubeAudio
extends Node
## Original synthesized presets. All streams are loaded once before interaction.
## Root owns persistence: settings are intentionally independent from save files.

const PRESETS := {
	"squishy": "말랑이 ASMR",
	"slime": "슬라임 스트레치",
	"foam": "크리미 폼",
	"water": "물방울 젤",
	"bubble": "뽁뽁이",
	"magnetic": "마그네틱",
	"mechanical": "기계식",
	"arcade": "아케이드",
	"soft": "소프트 클릭",
	"plastic": "플라스틱 큐브",
}
const EVENTS := ["touch", "start", "rotate", "snap", "rapid", "complete"]
const ASMR_PRESETS := ["squishy", "slime", "foam", "water"]
const VARIANT_COUNT := 4
const VOICE_COUNT := 10
const ROTATE_INTERVAL_MS := 85
const ASMR_ROTATE_INTERVAL_MS := 165
const MAX_ROTATION_VOICES := 2
const HAPTIC_MS := {"squishy": 18, "slime": 15, "foam": 7, "water": 12, "bubble": 14, "magnetic": 9, "mechanical": 18, "arcade": 12, "soft": 5, "plastic": 11}

var preset: String = "magnetic"
var volume: float = 0.65
var haptics_enabled: bool = true
var haptic_strength: float = 0.5
var haptics_supported: bool = false
var ready_for_audio: bool = false
var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()
var _last_rotate_ms: int = -1000
var _last_snap_ms: int = -1000
var _preview_active := false
var _last_variants: Dictionary = {}
var _bus_name := ""
var _preview_timer: Timer
var _preview_steps: Array = []
var _preview_preset := ""
var _haptic_timer: Timer
var _haptic_pulse := 0


func _ready() -> void:
	_rng.randomize()
	for preset_id in PRESETS:
		var event_samples: Dictionary = {}
		for event in EVENTS:
			var variants: Array[AudioStream] = []
			for variant in range(VARIANT_COUNT):
				var path := "res://assets/audio/%s/%s_%d.wav" % [preset_id, event, variant]
				var stream := load(path) as AudioStream
				if stream != null:
					variants.append(stream)
			if variants.size() != VARIANT_COUNT:
				push_error("Incomplete CubeVerse sound bank: %s/%s" % [preset_id, event])
				return
			event_samples[event] = variants
		_streams[preset_id] = event_samples
	# This manager owns a separate bus; a limiter catches summed transient peaks
	# without changing any other app audio or adding a delay to input handling.
	_bus_name = "CubeVerseSFX_%d" % get_instance_id()
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, _bus_name)
	AudioServer.set_bus_send(bus_index, "Master")
	var limiter := AudioEffectLimiter.new()
	limiter.threshold_db = -1.5
	limiter.ceiling_db = -0.8
	AudioServer.add_bus_effect(bus_index, limiter)
	for index in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		player.bus = _bus_name
		add_child(player)
		_voices.append(player)
	_preview_timer = Timer.new()
	_preview_timer.name = "PreviewSequence"
	_preview_timer.one_shot = true
	_preview_timer.timeout.connect(_advance_preview)
	add_child(_preview_timer)
	_haptic_timer = Timer.new()
	_haptic_timer.name = "CompletionHaptic"
	_haptic_timer.one_shot = true
	_haptic_timer.timeout.connect(_advance_haptic)
	add_child(_haptic_timer)
	haptics_supported = OS.get_name() == "Android"
	if OS.has_feature("web"):
		haptics_supported = bool(JavaScriptBridge.eval("typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function'", true))
	ready_for_audio = true


func _exit_tree() -> void:
	if _preview_timer != null: _preview_timer.stop()
	if _haptic_timer != null: _haptic_timer.stop()
	_preview_steps.clear()
	_preview_active = false
	ready_for_audio = false
	for voice in _voices:
		voice.stop()
		voice.stream = null
		voice.bus = "Master"
	_streams.clear()
	var bus_index := AudioServer.get_bus_index(_bus_name)
	if bus_index > 0:
		AudioServer.remove_bus(bus_index)


func set_preset(preset_id: String) -> void:
	if PRESETS.has(preset_id):
		cancel_preview()
		preset = preset_id
		# A newly selected material must respond immediately on its first drag.
		_last_rotate_ms = -1000
		_last_snap_ms = -1000


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)


func set_haptics(enabled: bool, strength: float = 0.5) -> void:
	haptics_enabled = enabled
	haptic_strength = clampf(strength, 0.0, 1.0)
	if _haptic_timer != null: _haptic_timer.stop()
	_haptic_pulse = 0
	if not enabled and OS.has_feature("web") and haptics_supported:
		JavaScriptBridge.eval("navigator.vibrate(0)", true)


func preview(preset_id: String) -> void:
	if not PRESETS.has(preset_id) or not ready_for_audio:
		return
	cancel_preview()
	_preview_active = true
	_preview_preset = preset_id
	var textured := preset_id in ASMR_PRESETS
	_preview_steps = [
		{"event":"start", "speed":0.65, "delay":0.20 if textured else 0.12},
		{"event":"rotate", "speed":0.8, "delay":0.24 if textured else 0.12},
		{"event":"snap", "speed":0.7, "delay":0.45 if textured else 0.15},
	]
	# Let users hear contact, pressure/friction and release, rather than just a click.
	# The selected gameplay preset is not changed by listening to another material.
	_play("touch", 0.55, preset_id, true)
	_preview_timer.start(0.10)


func cancel_preview() -> void:
	if _preview_timer != null: _preview_timer.stop()
	_preview_active = false
	_preview_steps.clear()
	_preview_preset = ""
	for voice in _voices:
		if voice.get_meta("preview", false):
			voice.stop()
			voice.set_meta("preview", false)


func _advance_preview() -> void:
	if not _preview_active or not ready_for_audio or not is_inside_tree(): return
	if _preview_steps.is_empty():
		_preview_active = false
		_preview_preset = ""
		return
	var step: Dictionary = _preview_steps.pop_front()
	_play(step.event, step.speed, _preview_preset, true)
	_preview_timer.start(step.delay)


func play_event(event: String, speed: float = 1.0) -> void:
	if not EVENTS.has(event):
		return
	if _preview_active:
		cancel_preview()
	var now := Time.get_ticks_msec()
	if event == "rotate":
		var interval := ASMR_ROTATE_INTERVAL_MS if preset in ASMR_PRESETS else ROTATE_INTERVAL_MS
		if now - _last_rotate_ms < interval:
			return
		_last_rotate_ms = now
	if event == "snap":
		# A dedicated double transient accompanies fast successive quarter-turns.
		if now - _last_snap_ms < 165:
			_play("rapid", speed, preset)
		else:
			_play(event, speed, preset)
		_last_snap_ms = now
		_haptic_snap()
		return
	_play(event, speed, preset)
	if event == "complete":
		_haptic_complete()


func _play(event: String, speed: float, preset_id: String, is_preview := false) -> void:
	if not ready_for_audio or volume <= 0.0:
		return
	var event_samples: Dictionary = _streams.get(preset_id, {})
	var samples: Array = event_samples.get(event, [])
	if samples.is_empty():
		return
	if event == "rotate":
		var textures := 0
		for candidate in _voices:
			if candidate.playing and candidate.get_meta("event", "") == "rotate":
				textures += 1
		if textures >= MAX_ROTATION_VOICES:
			# The two existing textures already cover movement. Avoid chopping a long
			# pressure waveform mid-cycle or accumulating a wall of overlapping noise.
			return
	var voice: AudioStreamPlayer = null
	for candidate in _voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		if event == "rotate": return
		# Prefer the oldest low-priority voice; a solved cue keeps its full tail.
		var oldest := Time.get_ticks_msec() + 1
		for candidate in _voices:
			if candidate.get_meta("event", "") != "complete" and int(candidate.get_meta("started_ms", 0)) < oldest:
				voice = candidate
				oldest = int(candidate.get_meta("started_ms", 0))
	if voice == null:
		return
	voice.stop()
	var speed_amount := clampf(speed, 0.2, 3.0)
	var variant := _choose_variant(preset_id, event, speed_amount, samples.size())
	voice.stream = samples[variant]
	voice.set_meta("event", event)
	voice.set_meta("preset", preset_id)
	voice.set_meta("variant", variant)
	voice.set_meta("preview", is_preview)
	voice.set_meta("started_ms", Time.get_ticks_msec())
	voice.pitch_scale = _rng.randf_range(0.976, 1.024) * lerpf(0.94, 1.09, (speed_amount - 0.2) / 2.8)
	voice.volume_db = linear_to_db(maxf(0.0001, volume * lerpf(0.76, 1.0, speed_amount / 3.0))) - 8.0
	voice.play()


func _choose_variant(preset_id: String, event: String, speed: float, count: int) -> int:
	var key := preset_id + "/" + event
	var previous := int(_last_variants.get(key, -1))
	var desired := clampi(int((speed - 0.2) / 2.8 * count), 0, count - 1)
	var weights: Array[float] = []
	var total := 0.0
	for index in range(count):
		var distance := absf(float(index - desired))
		var weight := 0.0 if index == previous and count > 1 else 1.0 / (1.0 + distance * distance * 2.0)
		weights.append(weight)
		total += weight
	var pick := _rng.randf() * total
	var selected := count - 1
	for index in range(count):
		pick -= weights[index]
		if pick <= 0.0 and weights[index] > 0.0:
			selected = index
			break
	_last_variants[key] = selected
	return selected


func _haptic_snap() -> void:
	if not _can_haptic():
		return
	_haptic_timer.stop()
	_haptic_pulse = 0
	var duration: int = HAPTIC_MS.get(preset, 10)
	if OS.get_name() == "Android":
		Input.vibrate_handheld(duration, haptic_strength)
	elif OS.has_feature("web"):
		# Browser vibration has no standard amplitude control. Strength scales duration.
		var web_duration := maxi(1, roundi(duration * lerpf(0.4, 1.0, haptic_strength)))
		JavaScriptBridge.eval("navigator.vibrate(%d)" % web_duration, true)


func _haptic_complete() -> void:
	if not _can_haptic():
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate([18,45,18,45,35])", true)
	elif OS.get_name() == "Android":
		Input.vibrate_handheld(18, haptic_strength)
		_haptic_pulse = 1
		_haptic_timer.start(0.063)


func _advance_haptic() -> void:
	if not _can_haptic() or OS.get_name() != "Android": return
	if _haptic_pulse == 1:
		Input.vibrate_handheld(18, haptic_strength)
		_haptic_pulse = 2
		_haptic_timer.start(0.063)
	elif _haptic_pulse == 2:
		Input.vibrate_handheld(35, haptic_strength)
		_haptic_pulse = 0


func _can_haptic() -> bool:
	return haptics_supported and haptics_enabled and haptic_strength > 0.0
