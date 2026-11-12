class_name CubeAudio
extends Node
## Original synthesized presets. All streams are loaded once before interaction.
## Root owns persistence: settings are intentionally independent from save files.

const PRESETS := {
	"bubble": "뽁뽁이",
	"magnetic": "마그네틱",
	"mechanical": "기계식",
	"arcade": "아케이드",
	"soft": "소프트 클릭",
	"plastic": "플라스틱 큐브",
}
const EVENTS := ["touch", "start", "rotate", "snap", "rapid", "complete"]
const VOICE_COUNT := 10
const ROTATE_INTERVAL_MS := 85
const HAPTIC_MS := {"bubble": 14, "magnetic": 9, "mechanical": 18, "arcade": 12, "soft": 5, "plastic": 11}

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
var _haptic_generation: int = 0


func _ready() -> void:
	_rng.randomize()
	for preset_id in PRESETS:
		var event_samples: Dictionary = {}
		for event in EVENTS:
			var variants: Array[AudioStream] = []
			for variant in range(3):
				var path := "res://assets/audio/%s/%s_%d.wav" % [preset_id, event, variant]
				var stream := load(path) as AudioStream
				if stream != null:
					variants.append(stream)
			event_samples[event] = variants
		_streams[preset_id] = event_samples
	for index in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		player.bus = "Master"
		add_child(player)
		_voices.append(player)
	haptics_supported = OS.get_name() == "Android"
	if OS.has_feature("web"):
		haptics_supported = bool(JavaScriptBridge.eval("typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function'", true))
	ready_for_audio = true


func _exit_tree() -> void:
	_haptic_generation += 1
	ready_for_audio = false
	for voice in _voices:
		voice.stop()
		voice.stream = null
	_streams.clear()


func set_preset(preset_id: String) -> void:
	if PRESETS.has(preset_id):
		preset = preset_id


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)


func set_haptics(enabled: bool, strength: float = 0.5) -> void:
	haptics_enabled = enabled
	haptic_strength = clampf(strength, 0.0, 1.0)
	_haptic_generation += 1
	if not enabled and OS.has_feature("web") and haptics_supported:
		JavaScriptBridge.eval("navigator.vibrate(0)", true)


func preview(preset_id: String) -> void:
	if not PRESETS.has(preset_id):
		return
	_play("snap", 1.0, preset_id)


func play_event(event: String, speed: float = 1.0) -> void:
	if not EVENTS.has(event):
		return
	var now := Time.get_ticks_msec()
	if event == "rotate":
		if now - _last_rotate_ms < ROTATE_INTERVAL_MS:
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


func _play(event: String, speed: float, preset_id: String) -> void:
	if not ready_for_audio or volume <= 0.0:
		return
	var event_samples: Dictionary = _streams.get(preset_id, {})
	var samples: Array = event_samples.get(event, [])
	if samples.is_empty():
		return
	var voice: AudioStreamPlayer = null
	for candidate in _voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		# Prefer replacing a transient; do not cut off a completion melody.
		for candidate in _voices:
			if candidate.get_meta("event", "") != "complete":
				voice = candidate
				break
	if voice == null:
		return
	voice.stop()
	voice.stream = samples[_rng.randi_range(0, samples.size() - 1)]
	voice.set_meta("event", event)
	var speed_amount := clampf(speed, 0.2, 3.0)
	voice.pitch_scale = _rng.randf_range(0.965, 1.035) * lerpf(0.94, 1.1, (speed_amount - 0.2) / 2.8)
	voice.volume_db = linear_to_db(maxf(0.0001, volume * lerpf(0.76, 1.0, speed_amount / 3.0))) - 8.0
	voice.play()


func _haptic_snap() -> void:
	if not _can_haptic():
		return
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
	_haptic_generation += 1
	var generation := _haptic_generation
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate([18,45,18,45,35])", true)
	elif OS.get_name() == "Android":
		Input.vibrate_handheld(18, haptic_strength)
		await get_tree().create_timer(0.063).timeout
		if generation != _haptic_generation or not _can_haptic():
			return
		Input.vibrate_handheld(18, haptic_strength)
		await get_tree().create_timer(0.063).timeout
		if generation == _haptic_generation and _can_haptic():
			Input.vibrate_handheld(35, haptic_strength)


func _can_haptic() -> bool:
	return haptics_supported and haptics_enabled and haptic_strength > 0.0
