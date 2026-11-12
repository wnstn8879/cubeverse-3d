class_name CubeState
extends RefCounted
## Integer-only sticker model shared by every NxN cube. Rendering never owns state.
## Positive turns obey the right-hand rule around +X / +Y / +Z.

const MIN_SIZE := 2
const MAX_SIZE := 10
const SAVE_VERSION := 1
const MAX_SAVED_MOVES := 100000
const FACE_NORMALS := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]

var size: int = 3
var stickers: Array = []
var history: Array = []
var future: Array = []

func _init(n: int = 3) -> void:
	reset(n)

func reset(n: int = -1) -> void:
	if n != -1:
		size = clampi(n, MIN_SIZE, MAX_SIZE)
	stickers.clear()
	history.clear()
	future.clear()
	for color in range(6):
		var normal: Vector3i = FACE_NORMALS[color]
		for u in range(size):
			for v in range(size):
				var p := Vector3i.ZERO
				if normal.x != 0:
					p = Vector3i(size - 1 if normal.x > 0 else 0, u, v)
				elif normal.y != 0:
					p = Vector3i(u, size - 1 if normal.y > 0 else 0, v)
				else:
					p = Vector3i(u, v, size - 1 if normal.z > 0 else 0)
				stickers.append({"p": p, "n": normal, "c": color})

func apply_move(axis: int, layer: int, turns: int = 1, record: bool = true) -> bool:
	if axis < 0 or axis > 2 or layer < 0 or layer >= size:
		return false
	var quarter_turns := posmod(turns, 4)
	if quarter_turns == 0:
		return false
	for sticker in stickers:
		if sticker.p[axis] != layer:
			continue
		for _quarter in range(quarter_turns):
			sticker.p = _rotate_position(sticker.p, axis)
			sticker.n = _rotate_normal(sticker.n, axis)
	if record:
		history.append({"axis": axis, "layer": layer, "turns": -1 if quarter_turns == 3 else quarter_turns})
		future.clear()
	return true

func undo() -> bool:
	if history.is_empty():
		return false
	var move: Dictionary = history.pop_back()
	apply_move(move.axis, move.layer, -move.turns, false)
	future.append(move)
	return true

func redo() -> bool:
	if future.is_empty():
		return false
	var move: Dictionary = future.pop_back()
	apply_move(move.axis, move.layer, move.turns, false)
	history.append(move)
	return true

func scramble(count: int = 25, seed_value: int = -1) -> Array:
	var rng := RandomNumberGenerator.new()
	if seed_value == -1:
		rng.randomize()
	else:
		rng.seed = seed_value
	var result: Array = []
	var last_axis := -1
	for _index in range(clampi(count, 0, 1000)):
		# Avoid neighboring turns around the same axis; every layer remains legal.
		var axis := rng.randi_range(0, 2)
		while axis == last_axis:
			axis = rng.randi_range(0, 2)
		var move := {"axis": axis, "layer": rng.randi_range(0, size - 1), "turns": [-1, 1, 2][rng.randi_range(0, 2)]}
		apply_move(move.axis, move.layer, move.turns)
		result.append(move)
		last_axis = axis
	return result

func is_solved() -> bool:
	var face_colors: Dictionary = {}
	for sticker in stickers:
		var face: Vector3i = sticker.n
		if face_colors.has(face) and face_colors[face] != sticker.c:
			return false
		face_colors[face] = sticker.c
	return face_colors.size() == 6

func state_key() -> String:
	# Sorting makes identity independent of sticker array iteration order.
	var entries: PackedStringArray = []
	for sticker in stickers:
		var p: Vector3i = sticker.p
		var normal: Vector3i = sticker.n
		entries.append("%d,%d,%d:%d,%d,%d:%d" % [p.x, p.y, p.z, normal.x, normal.y, normal.z, sticker.c])
	entries.sort()
	return "%d|%s" % [size, ";".join(entries)]

func to_dict() -> Dictionary:
	var data: Array = []
	for sticker in stickers:
		var p: Vector3i = sticker.p
		var normal: Vector3i = sticker.n
		data.append({"p": [p.x, p.y, p.z], "n": [normal.x, normal.y, normal.z], "c": sticker.c})
	return {
		"version": SAVE_VERSION, "size": size, "stickers": data,
		"history": history.duplicate(true), "future": future.duplicate(true),
		"checksum": state_key().sha256_text(),
	}

func from_dict(data: Dictionary) -> bool:
	# Transactional: reject an invalid import without touching the live puzzle.
	if not _is_integer(data.get("version")) or int(data.version) != SAVE_VERSION:
		return false
	if not _is_integer(data.get("size")) or int(data.size) < MIN_SIZE or int(data.size) > MAX_SIZE:
		return false
	var n := int(data.size)
	if not data.get("stickers") is Array or data.stickers.size() != 6 * n * n:
		return false
	var candidate: Array = []
	var occupied: Dictionary = {}
	var colors := [0, 0, 0, 0, 0, 0]
	for value in data.stickers:
		if not value is Dictionary or not _vector_array_valid(value.get("p")) or not _vector_array_valid(value.get("n")):
			return false
		if not _is_integer(value.get("c")) or int(value.c) < 0 or int(value.c) > 5:
			return false
		var p := Vector3i(int(value.p[0]), int(value.p[1]), int(value.p[2]))
		var normal := Vector3i(int(value.n[0]), int(value.n[1]), int(value.n[2]))
		if not normal in FACE_NORMALS:
			return false
		for axis in range(3):
			if p[axis] < 0 or p[axis] >= n:
				return false
			if normal[axis] != 0 and p[axis] != (n - 1 if normal[axis] > 0 else 0):
				return false
		var slot := "%s:%s" % [p, normal]
		if occupied.has(slot):
			return false
		occupied[slot] = true
		colors[int(value.c)] += 1
		candidate.append({"p": p, "n": normal, "c": int(value.c)})
	for count in colors:
		if count != n * n:
			return false
	var imported_history: Variant = data.get("history", [])
	var imported_future: Variant = data.get("future", [])
	if not _moves_valid(imported_history, n) or not _moves_valid(imported_future, n):
		return false
	# Every accepted persisted state must be reachable by its recorded legal moves.
	# This also catches impossible color swaps and a damaged undo stack.
	var replay = get_script().new(n)
	for move in imported_history:
		replay.apply_move(int(move.axis), int(move.layer), int(move.turns), false)
	var imported = get_script().new(n)
	imported.stickers = candidate
	var key: String = imported.state_key()
	if replay.state_key() != key:
		return false
	if not data.get("checksum") is String or data.checksum != key.sha256_text():
		return false
	size = n
	stickers = candidate
	history = _normalize_moves(imported_history)
	future = _normalize_moves(imported_future)
	return true

func _rotate_position(p: Vector3i, axis: int) -> Vector3i:
	match axis:
		0: return Vector3i(p.x, size - 1 - p.z, p.y)
		1: return Vector3i(p.z, p.y, size - 1 - p.x)
		_: return Vector3i(size - 1 - p.y, p.x, p.z)

func _rotate_normal(normal: Vector3i, axis: int) -> Vector3i:
	match axis:
		0: return Vector3i(normal.x, -normal.z, normal.y)
		1: return Vector3i(normal.z, normal.y, -normal.x)
		_: return Vector3i(-normal.y, normal.x, normal.z)

static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

static func _vector_array_valid(value: Variant) -> bool:
	return value is Array and value.size() == 3 and _is_integer(value[0]) and _is_integer(value[1]) and _is_integer(value[2])

static func _moves_valid(value: Variant, n: int) -> bool:
	if not value is Array or value.size() > MAX_SAVED_MOVES:
		return false
	for move in value:
		if not move is Dictionary:
			return false
		if not _is_integer(move.get("axis")) or int(move.axis) < 0 or int(move.axis) > 2:
			return false
		if not _is_integer(move.get("layer")) or int(move.layer) < 0 or int(move.layer) >= n:
			return false
		if not _is_integer(move.get("turns")) or not int(move.turns) in [-1, 1, 2]:
			return false
	return true

static func _normalize_moves(moves: Array) -> Array:
	var result: Array = []
	for move in moves:
		result.append({"axis": int(move.axis), "layer": int(move.layer), "turns": int(move.turns)})
	return result
