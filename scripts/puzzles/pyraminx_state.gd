class_name PyraminxState
extends RefCounted
## A real tetrahedral Pyraminx, independent from the NxN cube engine.
## Face triangles use integer barycentric coordinates. A 120-degree vertex
## turn is an exact permutation of those coordinates, never a floating rotation.
## Layer 0 turns a tip; layer 1 turns the whole adjacent layer, including its tip.

const PUZZLE_ID := "pyraminx"
const SAVE_VERSION := 1
const MAX_SAVED_MOVES := 100000
const AXIS_NAMES := ["U", "L", "R", "B"]
const RADIUS := 1.8
const VERTICES := [
	Vector3(0.0, 1.0, 0.0) * RADIUS,
	Vector3(-0.816496580927726, -0.3333333333333333, 0.4714045207910317) * RADIUS,
	Vector3(0.816496580927726, -0.3333333333333333, 0.4714045207910317) * RADIUS,
	Vector3(0.0, -0.3333333333333333, -0.9428090415820634) * RADIUS,
]

var puzzle_id := PUZZLE_ID
var size := 3
var stickers: Array = []
var history: Array = []
var future: Array = []
var _slots: Array = []
var _positions: Array = []
var _permutations: Array = []


func _init(_n: int = 3) -> void:
	_build_slots()
	_build_permutations()
	reset()


func reset(_n: int = -1) -> void:
	_positions.clear()
	for index in range(_slots.size()):
		_positions.append(index)
	history.clear()
	future.clear()
	_sync_stickers()


func apply_move(axis: int, layer: int, turns: int = 1, record: bool = true) -> bool:
	if axis < 0 or axis > 3 or layer < 0 or layer > 1:
		return false
	var count := posmod(turns, 3)
	if count == 0:
		return false
	for index in range(_positions.size()):
		var slot: int = _positions[index]
		# Centroid numerators have denominator 9. Boundaries themselves have
		# no sticker center, so these exact integer comparisons are unambiguous.
		if not slot_in_layer(slot, axis, layer):
			continue
		for _step in range(count):
			slot = _permutations[axis][slot]
		_positions[index] = slot
	if record:
		history.append({"axis": axis, "layer": layer, "turns": -1 if count == 2 else 1})
		future.clear()
	_sync_stickers()
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


func scramble(count: int = 20, seed_value: int = -1) -> Array:
	var rng := RandomNumberGenerator.new()
	if seed_value == -1:
		rng.randomize()
	else:
		rng.seed = seed_value
	var moves: Array = []
	var previous_axis := -1
	for _index in range(clampi(count, 0, 1000)):
		var axis := rng.randi_range(0, 3)
		while axis == previous_axis:
			axis = rng.randi_range(0, 3)
		previous_axis = axis
		var move := {"axis": axis, "layer": 1, "turns": 1 if rng.randf() > 0.5 else -1}
		apply_move(move.axis, move.layer, move.turns)
		moves.append(move)
	# A normal scramble also gives each independently movable tip a random turn.
	for axis in range(4):
		var turns := rng.randi_range(0, 2)
		if turns == 0:
			continue
		var move := {"axis": axis, "layer": 0, "turns": -1 if turns == 2 else 1}
		apply_move(move.axis, move.layer, move.turns)
		moves.append(move)
	return moves


func is_solved() -> bool:
	var face_colors := {}
	for sticker in stickers:
		var face: int = sticker.face
		if face_colors.has(face) and face_colors[face] != sticker.c:
			return false
		face_colors[face] = sticker.c
	return face_colors.size() == 4


func state_key() -> String:
	var parts := PackedStringArray()
	for slot in _positions:
		parts.append(str(slot))
	return PUZZLE_ID + "|" + ",".join(parts)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"puzzle": PUZZLE_ID,
		"positions": _positions.duplicate(),
		"history": history.duplicate(true),
		"future": future.duplicate(true),
		"checksum": state_key().sha256_text(),
	}


func from_dict(data: Dictionary) -> bool:
	# A bad save must never partially replace the current live puzzle.
	if not _is_integer(data.get("version")) or int(data.version) != SAVE_VERSION or data.get("puzzle") != PUZZLE_ID:
		return false
	if not data.get("positions") is Array or data.positions.size() != 36:
		return false
	var positions: Array = []
	var used := {}
	for slot in data.positions:
		if not _is_integer(slot) or int(slot) < 0 or int(slot) >= 36 or used.has(int(slot)):
			return false
		used[int(slot)] = true
		positions.append(int(slot))
	if not _valid_moves(data.get("history")) or not _valid_moves(data.get("future")):
		return false
	var candidate = get_script().new()
	for move in data.history:
		candidate.apply_move(int(move.axis), int(move.layer), int(move.turns))
	if candidate._positions != positions:
		return false
	if not data.get("checksum") is String or data.checksum != candidate.state_key().sha256_text():
		return false
	_positions = positions
	history = _normalized_moves(data.history)
	future = _normalized_moves(data.future)
	_sync_stickers()
	return true


func slot_in_layer(slot: int, axis: int, layer: int) -> bool:
	return int(_slots[slot].b[axis]) > (6 if layer == 0 else 3)


func selected_sticker(sticker: Dictionary, axis: int, layer: int) -> bool:
	return axis >= 0 and axis < 4 and layer in [0, 1] and slot_in_layer(int(sticker.slot), axis, layer)


func face_color_at_slot(slot: int) -> int:
	if slot < 0 or slot >= 36:
		return -1
	var index := _positions.find(slot)
	return int(_slots[index].face) if index >= 0 else -1


func get_slots() -> Array:
	return _slots.duplicate(true)


static func axis_direction(axis: int) -> Vector3:
	return VERTICES[clampi(axis, 0, 3)].normalized()


static func barycentric_point(weights: Array, denominator: float) -> Vector3:
	var point := Vector3.ZERO
	for axis in range(4):
		point += VERTICES[axis] * float(weights[axis]) / denominator
	return point


func _build_slots() -> void:
	_slots.clear()
	for face in range(4):
		var corners: Array = []
		for axis in range(4):
			if axis != face:
				corners.append(axis)
		for a in range(3):
			for b in range(3 - a):
				var c := 2 - a - b
				_add_slot(face, corners, [[a + 1, b, c], [a, b + 1, c], [a, b, c + 1]])
		for a in range(2):
			for b in range(2 - a):
				var c := 1 - a - b
				_add_slot(face, corners, [[a + 1, b + 1, c], [a + 1, b, c + 1], [a, b + 1, c + 1]])


func _add_slot(face: int, corners: Array, triangle: Array) -> void:
	var coords: Array = []
	var sum := [0, 0, 0, 0]
	for point in triangle:
		var weights := [0, 0, 0, 0]
		for index in range(3):
			weights[corners[index]] = point[index]
		for axis in range(4):
			sum[axis] += weights[axis]
		coords.append(weights)
	var vertices: Array = []
	for point in coords:
		vertices.append(barycentric_point(point, 3.0))
	_slots.append({"face": face, "b": sum, "vertices": vertices, "center": barycentric_point(sum, 9.0), "normal": -VERTICES[face].normalized()})


func _build_permutations() -> void:
	_permutations.clear()
	var lookup := {}
	for slot in range(_slots.size()):
		lookup[_coordinate_key(_slots[slot].b)] = slot
	for axis in range(4):
		var vertex_mapping: Array = []
		var rotation := Basis(axis_direction(axis), TAU / 3.0)
		for vertex in VERTICES:
			var rotated: Vector3 = rotation * vertex
			var closest := 0
			for index in range(1, 4):
				if rotated.distance_squared_to(VERTICES[index]) < rotated.distance_squared_to(VERTICES[closest]):
					closest = index
			vertex_mapping.append(closest)
		var mapping: Array = []
		for slot in _slots:
			var rotated := [0, 0, 0, 0]
			for index in range(4):
				rotated[vertex_mapping[index]] = slot.b[index]
			mapping.append(lookup[_coordinate_key(rotated)])
		_permutations.append(mapping)


func _sync_stickers() -> void:
	stickers.clear()
	for index in range(_positions.size()):
		var slot: Dictionary = _slots[_positions[index]]
		stickers.append({"id": index, "slot": _positions[index], "vertices": slot.vertices, "center": slot.center, "normal": slot.normal, "face": slot.face, "c": int(_slots[index].face)})


static func _coordinate_key(weights: Array) -> String:
	return "%d,%d,%d,%d" % weights


static func _is_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


static func _valid_moves(moves: Variant) -> bool:
	if not moves is Array or moves.size() > MAX_SAVED_MOVES:
		return false
	for move in moves:
		if not move is Dictionary or not move.has_all(["axis", "layer", "turns"]):
			return false
		if not _is_integer(move.axis) or not _is_integer(move.layer) or not _is_integer(move.turns):
			return false
		if int(move.axis) < 0 or int(move.axis) > 3 or int(move.layer) < 0 or int(move.layer) > 1 or not int(move.turns) in [-1, 1]:
			return false
	return true


static func _normalized_moves(moves: Array) -> Array:
	var result: Array = []
	for move in moves:
		result.append({"axis": int(move.axis), "layer": int(move.layer), "turns": int(move.turns)})
	return result
