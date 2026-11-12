extends SceneTree

const Cube = preload("res://scripts/core/cube_state.gd")
const Store = preload("res://scripts/core/save_store.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_rotations()
	_test_scramble()
	_test_history()
	_test_serialization()
	_test_invalid_states()
	_test_persistence()
	for failure in failures:
		push_error(failure)
	print("CUBE_TEST_RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _test_rotations() -> void:
	for n in range(2, 11):
		var cube = Cube.new(n)
		var original: String = cube.state_key()
		_check(cube.stickers.size() == 6 * n * n, "%dx%d surface sticker count" % [n, n])
		_check(cube.is_solved(), "%dx%d starts solved" % [n, n])
		for axis in range(3):
			for layer in range(n):
				_check(cube.apply_move(axis, layer, 1), "legal rotation accepted")
				_check(not cube.is_solved(), "%d axis %d layer %d is unsolved after quarter turn" % [n, axis, layer])
				cube.apply_move(axis, layer, -1)
				_check(cube.state_key() == original, "%d inverse restores axis %d layer %d" % [n, axis, layer])
				for _quarter in range(4):
					cube.apply_move(axis, layer, 1)
				_check(cube.state_key() == original, "%d four turns restore axis %d layer %d" % [n, axis, layer])
				cube.apply_move(axis, layer, 2)
				cube.apply_move(axis, layer, 2)
				_check(cube.state_key() == original, "%d double turns restore" % n)
			# Rotating every layer is a global orientation change and stays solved.
			for layer in range(n):
				cube.apply_move(axis, layer, 1)
			_check(cube.is_solved(), "%d globally rotated cube remains solved" % n)
			for layer in range(n):
				cube.apply_move(axis, layer, -1)
		_check(cube.state_key() == original, "%d all tests exact identity" % n)

func _test_scramble() -> void:
	for n in range(2, 11):
		var cube = Cube.new(n)
		var original: String = cube.state_key()
		var moves: Array = cube.scramble(80, 7391 + n)
		_check(moves.size() == 80, "%d shuffle length" % n)
		_check(not cube.is_solved(), "%d shuffle unsolved" % n)
		var restored = Cube.new()
		_check(restored.from_dict(cube.to_dict()), "%d shuffled state is valid and reachable" % n)
		_check(restored.state_key() == cube.state_key(), "%d shuffled save equality" % n)
		for i in range(moves.size() - 1, -1, -1):
			cube.apply_move(moves[i].axis, moves[i].layer, -moves[i].turns)
		_check(cube.state_key() == original, "%d inverse shuffle exact identity" % n)
		_check(cube.is_solved(), "%d inverse shuffle solved" % n)
		var first = Cube.new(n)
		var second = Cube.new(n)
		first.scramble(40, 123456)
		second.scramble(40, 123456)
		_check(first.state_key() == second.state_key(), "%d deterministic seeded shuffle" % n)

func _test_history() -> void:
	var cube = Cube.new(3)
	var original: String = cube.state_key()
	_check(not cube.undo(), "empty undo returns false")
	_check(not cube.redo(), "empty redo returns false")
	cube.apply_move(0, 2)
	var once: String = cube.state_key()
	cube.apply_move(1, 0, -1)
	var twice: String = cube.state_key()
	_check(cube.undo() and cube.state_key() == once, "undo restores preceding state")
	_check(cube.undo() and cube.state_key() == original, "undo restores origin")
	_check(cube.redo() and cube.state_key() == once, "redo restores first move")
	_check(cube.redo() and cube.state_key() == twice, "redo restores second move")
	cube.undo()
	cube.apply_move(2, 1)
	_check(not cube.redo(), "new move invalidates redo branch")
	cube.reset()
	_check(cube.is_solved() and cube.history.is_empty() and cube.future.is_empty(), "reset clears state and history")
	var key: String = cube.state_key()
	_check(not cube.apply_move(-1, 0), "reject negative axis")
	_check(not cube.apply_move(3, 0), "reject out of range axis")
	_check(not cube.apply_move(0, -1), "reject negative layer")
	_check(not cube.apply_move(0, 3), "reject out of range layer")
	_check(not cube.apply_move(0, 0, 4), "reject no-op turns")
	_check(cube.state_key() == key, "invalid moves preserve state")

func _test_serialization() -> void:
	for n in range(2, 11):
		var cube = Cube.new(n)
		cube.scramble(25, n * 444)
		cube.undo()
		cube.undo()
		var parsed: Dictionary = JSON.parse_string(JSON.stringify(cube.to_dict()))
		var restored = Cube.new(2)
		_check(restored.from_dict(parsed), "%d accepts JSON numeric representation" % n)
		_check(restored.state_key() == cube.state_key(), "%d save/load exact equality" % n)
		_check(restored.history == cube.history and restored.future == cube.future, "%d history persisted" % n)
		cube.redo()
		restored.redo()
		_check(restored.state_key() == cube.state_key(), "%d redo works after reload" % n)
		cube.undo()
		restored.undo()
		_check(restored.state_key() == cube.state_key(), "%d undo works after reload" % n)

func _test_invalid_states() -> void:
	var cube = Cube.new(3)
	cube.scramble(9, 84)
	var key: String = cube.state_key()
	var valid: Dictionary = cube.to_dict()
	var invalid_states: Array = []
	invalid_states.append({})
	var data: Dictionary = valid.duplicate(true)
	data.size = 1
	invalid_states.append(data)
	data = valid.duplicate(true)
	data.version = 99
	invalid_states.append(data)
	data = valid.duplicate(true)
	data.stickers.pop_back()
	invalid_states.append(data)
	data = valid.duplicate(true)
	data.stickers[0] = data.stickers[1].duplicate(true)
	invalid_states.append(data)
	data = valid.duplicate(true)
	data.stickers[0].p[0] = 0.25
	invalid_states.append(data)
	data = valid.duplicate(true)
	data.stickers[0].n = [1, 1, 0]
	invalid_states.append(data)
	data = valid.duplicate(true)
	data.stickers[0].c = 6
	invalid_states.append(data)
	data = valid.duplicate(true)
	data.history[0].layer = 999
	invalid_states.append(data)
	data = valid.duplicate(true)
	data.history[0].turns = 0
	invalid_states.append(data)
	data = valid.duplicate(true)
	data.history.pop_back()
	invalid_states.append(data)
	data = valid.duplicate(true)
	data.checksum = "damaged"
	invalid_states.append(data)
	for invalid in invalid_states:
		_check(not cube.from_dict(invalid), "reject invalid persisted puzzle")
		_check(cube.state_key() == key, "invalid import preserves live puzzle")

func _test_persistence() -> void:
	var test_path := "user://test_cube_store_%d.json" % OS.get_process_id()
	var store = Store.new(test_path)
	var data: Dictionary = store.load_data()
	_check(int(data.settings.selected_cube) == 3, "new save defaults to 3x3")
	var cube = Cube.new(7)
	cube.scramble(19, 765)
	data.cubes["7"] = cube.to_dict()
	data.settings.sound = "arcade"
	data.settings.volume = 0.31
	data.settings.selected_cube = 7
	_check(store.save_data(data), "atomic save writes successfully")
	var relaunched = Store.new(test_path)
	var loaded: Dictionary = relaunched.load_data()
	_check(loaded.settings.sound == "arcade", "sound change persists after process-style restart")
	_check(is_equal_approx(float(loaded.settings.volume), 0.31), "volume persists")
	var restored = Cube.new()
	_check(restored.from_dict(loaded.cubes["7"]), "saved cube restores after store restart")
	_check(restored.state_key() == cube.state_key(), "restart cube identity preserved")
	loaded.settings.sound = "plastic"
	_check(relaunched.save_data(loaded), "second save retains backup")
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string("{corrupted")
	file.close()
	var recovering = Store.new(test_path)
	var recovered: Dictionary = recovering.load_data()
	_check(recovering.recovered_from_backup, "corrupt primary recovers backup")
	_check(recovered.settings.sound == "arcade", "backup contains last known good save")
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
