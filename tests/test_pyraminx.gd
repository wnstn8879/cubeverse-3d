extends SceneTree
## Geometric/group-state tests for the separate tetrahedral puzzle definition.
## Headless geometry and synthetic gestures do not establish physical-device UX.

const State = preload("res://scripts/puzzles/pyraminx_state.gd")
const View = preload("res://scripts/view/pyraminx_view.gd")
const Course = preload("res://scripts/puzzles/pyraminx_course.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("PYRAMINX_CHECK_FAILED: " + message)


func _run() -> void:
	_test_geometry()
	_test_move_group()
	_test_scramble_history()
	_test_serialization()
	_test_course()
	await _test_view()
	print("PYRAMINX_TEST_RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _vector_key(value: Vector3) -> String:
	return "%d,%d,%d" % [roundi(value.x * 10000), roundi(value.y * 10000), roundi(value.z * 10000)]


func _slots(state) -> Array:
	var result: Array = []
	for sticker in state.stickers:
		result.append(_vector_key(sticker.center) + ":" + _vector_key(sticker.normal))
	result.sort()
	return result


func _changed_slots(before: Array, state) -> int:
	var count := 0
	for i in range(before.size()):
		if before[i] != int(state.stickers[i].slot): count += 1
	return count


func _sticker_slots(state) -> Array:
	var result: Array = []
	for sticker in state.stickers: result.append(int(sticker.slot))
	return result


func _piece_key(slot: Dictionary) -> String:
	var weights: Array = slot.b
	var largest: int = weights.max()
	if largest in [7, 5]:
		return ("tip:" if largest == 7 else "center:") + str(weights.find(largest))
	var axes: Array = []
	for axis in range(4):
		if int(weights[axis]) == 4: axes.append(axis)
	return "edge:" + str(axes)


func _check_piece_integrity(state) -> void:
	var slots: Array = state.get_slots()
	var destinations: Dictionary = {}
	for index in range(state.stickers.size()):
		var origin: String = _piece_key(slots[index])
		var destination: String = _piece_key(slots[int(state.stickers[index].slot)])
		if destinations.has(origin):
			_check(destinations[origin] == destination, "multi-sticker physical piece remains intact")
		else:
			destinations[origin] = destination
			_check(origin.get_slice(":", 0) == destination.get_slice(":", 0), "piece type remains tip, center or edge")


func _test_geometry() -> void:
	var state = State.new()
	_check(state.puzzle_id == "pyraminx", "independent puzzle identifier")
	_check(state.stickers.size() == 36, "tetrahedron has 36 triangular stickers")
	_check(state.is_solved(), "fresh tetrahedron is solved")
	var faces: Dictionary = {}
	var slots: Dictionary = {}
	for sticker in state.stickers:
		var normal: Vector3 = sticker.normal
		var vertices: Array = sticker.vertices
		_check(vertices.size() == 3, "sticker is triangular")
		_check(absf(normal.length() - 1.0) < 0.0001, "unit face normal")
		_check(normal.dot(sticker.center) > 0, "face normal points outward")
		var cross: Vector3 = (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0])
		_check(cross.length() > 0.001, "triangle is non-degenerate")
		_check(absf(cross.normalized().dot(normal)) > 0.999, "triangle lies on sticker plane")
		var key = _vector_key(normal)
		faces[key] = int(faces.get(key, 0)) + 1
		slots[sticker.slot] = true
	_check(faces.size() == 4, "exactly four face planes")
	for count in faces.values(): _check(count == 9, "nine triangular stickers per face")
	_check(slots.size() == 36, "every geometric slot is unique")
	_check(not state.apply_move(-1, 1, 1), "negative vertex axis rejected")
	_check(not state.apply_move(4, 1, 1), "non-tetrahedral axis rejected")
	_check(not state.apply_move(0, -1, 1), "negative layer rejected")
	_check(not state.apply_move(0, 2, 1), "unsupported layer rejected")
	_check(not state.apply_move(0, 1, 0), "zero turn rejected")
	_check(state.is_solved(), "invalid moves preserve solved puzzle")


func _test_move_group() -> void:
	for axis in range(4):
		for layer in range(2):
			var state = State.new()
			var initial: String = state.state_key()
			var geometric_slots: Array = _slots(state)
			var sticker_slots: Array = _sticker_slots(state)
			_check(state.apply_move(axis, layer, 1), "120-degree turn accepted")
			_check(not state.is_solved(), "one tip or main turn is unsolved")
			_check(_changed_slots(sticker_slots, state) == (3 if layer == 0 else 12), "physical selection size matches tip/main layer")
			_check(_slots(state) == geometric_slots, "turn permutes exact tetrahedral slots")
			_check(state.apply_move(axis, layer, -1), "inverse turn accepted")
			_check(state.state_key() == initial, "move plus inverse restores exact state")
			for repeat in range(3):
				state.apply_move(axis, layer, 1)
				_check(_slots(state) == geometric_slots, "all successive turns preserve geometry slots")
			_check(state.state_key() == initial, "three 120-degree turns restore exact state")
			state.apply_move(axis, layer, 1)
			state.apply_move(axis, layer, 2)
			_check(state.state_key() == initial, "one plus two turns form a full cycle")
	# A tip is a separate physical part. Its independent axial rotation commutes
	# with all main moves, including the move around its own shared vertex axis.
	for tip_axis in range(4):
		for main_axis in range(4):
			var first = State.new()
			var second = State.new()
			first.apply_move(tip_axis, 0, 1)
			first.apply_move(main_axis, 1, 1)
			second.apply_move(main_axis, 1, 1)
			second.apply_move(tip_axis, 0, 1)
			_check(first.state_key() == second.state_key(), "independent tips commute with main turns")
	for a in range(4):
		for b in range(a + 1, 4):
			var first = State.new()
			var second = State.new()
			first.apply_move(a, 1, 1)
			first.apply_move(b, 1, 1)
			second.apply_move(b, 1, 1)
			second.apply_move(a, 1, 1)
			_check(first.state_key() != second.state_key(), "different main axes do not commute")


func _test_scramble_history() -> void:
	for seed_value in range(12):
		var state = State.new()
		var initial: String = state.state_key()
		var original_slots = _slots(state)
		var moves: Array = state.scramble(40, seed_value)
		# Standard Pyraminx scrambles randomize main turns then append up to
		# four independent tip adjustments. Undo every returned move.
		_check(moves.size() >= 40 and moves.size() <= 44, "scramble returns main moves and optional tips")
		_check(not state.is_solved(), "deterministic scramble is not solved")
		_check(state.history.size() == moves.size(), "scramble history is complete")
		for index in range(40): _check(moves[index].layer == 1, "standard scramble main sequence uses main layers")
		var tip_axes: Dictionary = {}
		for index in range(40, moves.size()):
			_check(moves[index].layer == 0 and not tip_axes.has(moves[index].axis), "appended tip adjustments are independent and unique")
			tip_axes[moves[index].axis] = true
		_check(_slots(state) == original_slots, "scramble preserves tetrahedral geometric slots")
		_check_piece_integrity(state)
		var scrambled: String = state.state_key()
		for index in range(moves.size()): _check(state.undo(), "scramble move is undoable")
		_check(state.state_key() == initial, "undoing entire scramble restores exact state")
		_check(not state.undo(), "undo at history start is safely refused")
		for index in range(moves.size()): _check(state.redo(), "scramble move is redoable")
		_check(state.state_key() == scrambled, "redo restores exact scramble")
		_check(not state.redo(), "redo at future end is safely refused")
		state.undo()
		state.apply_move(0, 1, 1)
		_check(state.future.is_empty(), "new branch clears redo history")
		state.reset()
		_check(state.is_solved() and state.history.is_empty() and state.future.is_empty(), "reset clears puzzle and histories")


func _test_serialization() -> void:
	var state = State.new()
	state.scramble(31, 871)
	state.undo()
	state.undo()
	var encoded: Dictionary = state.to_dict()
	var parser = JSON.new()
	_check(parser.parse(JSON.stringify(encoded)) == OK, "save is valid JSON")
	var restored = State.new()
	_check(restored.from_dict(parser.data), "JSON roundtrip imports")
	_check(restored.state_key() == state.state_key(), "JSON roundtrip preserves exact state")
	_check(restored.history == state.history and restored.future == state.future, "JSON roundtrip preserves undo and redo")
	state.redo()
	restored.redo()
	_check(restored.state_key() == state.state_key(), "restored redo matches original")
	var preserved: String = restored.state_key()
	var malformed = encoded.duplicate(true)
	malformed["checksum"] = "not-a-valid-checksum"
	_check(not restored.from_dict(malformed), "bad checksum rejected")
	_check(restored.state_key() == preserved, "bad import is transactional")
	malformed = encoded.duplicate(true)
	malformed["version"] = 999
	_check(not restored.from_dict(malformed), "future schema rejected")
	malformed = encoded.duplicate(true)
	malformed["history"] = [{"axis": 4, "layer": 1, "turns": 1}]
	_check(not restored.from_dict(malformed), "impossible move history rejected")
	malformed = encoded.duplicate(true)
	malformed["history"] = []
	_check(not restored.from_dict(malformed), "unreachable state/history combination rejected")
	malformed = encoded.duplicate(true)
	malformed["future"] = [{"axis": 0, "layer": 1, "turns": 0}]
	_check(not restored.from_dict(malformed), "zero future turn rejected")
	_check(restored.state_key() == preserved, "all malformed imports preserve live state")


func _test_course() -> void:
	var academy = Course.new()
	var course: Dictionary = academy.make_course()
	_check(course.verified, "prepared beginner course verifies physical stage goals")
	_check(course.scope == "prepared_beginner_course", "course explicitly limits itself to prepared example")
	_check(course.stages.size() == 5, "course includes introduction, notation, tips, centers and completion")
	var puzzle = course.state
	_check(not puzzle.is_solved(), "course starts with a real unsolved tetrahedron")
	_check(not academy.tips_aligned(puzzle), "prepared tips require actual turns")
	_check(not academy.centers_aligned(puzzle), "prepared centers require actual main turn")
	for index in range(course.stages.size()):
		var stage: Dictionary = course.stages[index]
		_check(not str(stage.explanation).is_empty() and not str(stage.goal).is_empty(), "each stage has beginner goal and explanation")
		_check(stage.move_notes.size() == stage.moves.size(), "every executable move has its own explanation")
		for move in stage.moves:
			_check(puzzle.apply_move(move.axis, move.layer, move.turns), "course uses legal 120-degree moves")
			_check(not academy.notation(move).is_empty(), "move has readable notation")
		_check(academy.stage_complete(puzzle, index), "each stage satisfies actual piece/color predicate")
		_check(puzzle.state_key() == stage.checkpoint_key, "course checkpoint matches executable hint sequence")
	_check(puzzle.is_solved(), "prepared course ends with all four faces solved")
	_check(academy.tips_aligned(puzzle) and academy.centers_aligned(puzzle), "final solved face also satisfies tip and center goals")
	puzzle.apply_move(0, 0, 1)
	_check(not academy.tips_aligned(puzzle), "tip predicate rejects a wrong tip")
	_check(academy.centers_aligned(puzzle), "independent tip does not disturb center predicate")
	puzzle.undo()
	puzzle.apply_move(1, 1, 1)
	_check(academy.tips_aligned(puzzle), "main turns preserve relative tip-center match")
	_check(not academy.centers_aligned(puzzle), "center predicate rejects a wrong axial center")


func _wait_idle(view) -> bool:
	var deadline = Time.get_ticks_msec() + 2000
	while view.is_busy() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not view.is_busy(), "animation completes within timeout")
	return not view.is_busy()


func _test_view() -> void:
	var view = View.new()
	root.add_child(view)
	var state = State.new()
	view.setup(state)
	view.set_interaction_rect(Rect2(0, 190, 540, 460))
	await process_frame
	var initial: String = state.state_key()
	_check(view.animate_move(0, 1, 1), "animated main rotation accepted")
	_check(view.is_busy(), "main rotation locks input during animation")
	_check(state.state_key() == initial, "animation preview leaves logical state unchanged")
	_check(not view.animate_move(1, 1, 1), "overlapping rotation rejected")
	if not await _wait_idle(view):
		view.queue_free()
		return
	_check(not state.is_solved(), "animation commits actual state")
	_check(view.request_undo(), "animated undo accepted")
	if not await _wait_idle(view):
		view.queue_free()
		return
	_check(state.state_key() == initial, "animated undo restores solved tetrahedron")
	_check(view.request_redo(), "animated redo accepted")
	if not await _wait_idle(view):
		view.queue_free()
		return
	_check(not state.is_solved(), "animated redo restores prior move")
	view.setup(State.new())
	_check(not view.is_busy(), "setup leaves animation idle")
	state = view.state
	initial = state.state_key()
	for face in range(4):
		_check(view.set_face_camera(face), "all four face camera presets accepted")
		var center := Vector3.ZERO
		for sticker in state.stickers:
			if int(sticker.face) == face: center += sticker.center / 9.0
		var hit: Dictionary = view._pick(view.camera.unproject_position(center))
		_check(not hit.is_empty() and int(hit.get("face", -1)) == face, "face camera really exposes requested triangular face")
	_check(not view.set_face_camera(4), "non-tetrahedral face camera refused")
	view.reset_camera()
	# A projected sticker center exercises the view's real ray picker and drag
	# selection rather than calling a state mutation in place of an interaction.
	var picked_point := Vector2.ZERO
	var did_pick := false
	for sticker in state.stickers:
		var point: Vector2 = view.camera.unproject_position(sticker.center)
		if view.has_method("_pick") and not view._pick(point).is_empty():
			picked_point = point
			did_pick = true
			break
	_check(did_pick, "triangle ray picker finds the tetrahedron")
	if did_pick and view.has_method("_pointer_down"):
		view._pointer_down(0, picked_point)
		view._pointer_move(0, picked_point + Vector2(130, 15))
		_check(state.state_key() == initial, "drag preview does not mutate logical state")
		view._pointer_up(0, picked_point + Vector2(130, 15), true)
		view.cancel_drag()
		_check(state.state_key() == initial and not view.is_busy(), "canceled touch restores tetrahedron")
	view.set_input_enabled(false)
	_check(not view.is_busy(), "disabling input leaves no uncommitted selection")
	view.queue_free()
	await process_frame
	await create_timer(0.15).timeout
