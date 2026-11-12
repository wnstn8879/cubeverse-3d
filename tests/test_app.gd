extends SceneTree
## Application integration checks. These drive the real coordinator and animated view.
## Physics, exact puzzle rules, and touch cancellation have separate unit/view tests.

var checks := 0
var failures: Array[String] = []
var application
var packed_scene: PackedScene


func _initialize() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("APP_CHECK_FAILED: " + message)


func _run() -> void:
	packed_scene = load("res://scenes/main.tscn") as PackedScene
	_check(packed_scene != null, "main scene loads")
	if packed_scene == null:
		_finish()
		return
	application = packed_scene.instantiate()
	root.add_child(application)
	await process_frame
	_check(application.state.size == 3, "fresh app starts with 3x3")
	_check(application.state.is_solved(), "fresh app starts solved")
	_check(application.sound.ready_for_audio, "audio preloads before gameplay")
	await _test_navigation()
	await _test_animated_history()
	await _test_cube_selection()
	await _test_timer()
	await _test_lessons()
	await _test_restart()
	application.queue_free()
	await process_frame
	# Let the audio server release stopped stream references before engine shutdown.
	await create_timer(0.15).timeout
	_finish()


func _test_navigation() -> void:
	for tab in ["홈", "큐브", "아카데미", "아레나", "상점", "설정"]:
		var button := _find_button(application.ui, tab)
		_check(button != null, "navigation button exists: " + tab)
		if button == null:
			continue
		button.pressed.emit()
		await process_frame
		_check(application.page == tab, "navigation signal opens: " + tab)
		_check(application.view.visible == (tab == "홈"), "cube visible only on play page: " + tab)
		_check(application.view.input_enabled == application.view.visible, "input follows page visibility: " + tab)
	application._navigate("홈")
	await process_frame


func _test_animated_history() -> void:
	var original: String = application.state.state_key()
	application._face_move("R")
	_check(application.view.is_busy(), "face action starts actual animation")
	await _wait_idle("face R")
	var rotated: String = application.state.state_key()
	_check(rotated != original, "animated face action commits state")
	_check(not application.state.is_solved(), "one face turn is unsolved")
	application._undo()
	await _wait_idle("undo")
	_check(application.state.state_key() == original, "animated undo restores exact state")
	application._redo()
	await _wait_idle("redo")
	_check(application.state.state_key() == rotated, "animated redo restores exact state")


func _test_cube_selection() -> void:
	var three_key: String = application.state.state_key()
	application._select_cube(2)
	await process_frame
	_check(application.state.size == 2 and application.view.state == application.state, "2x2 selection reaches actual view")
	application._face_move("R")
	await _wait_idle("2x2 move")
	var two_key: String = application.state.state_key()
	application._select_cube(10)
	await process_frame
	_check(application.state.size == 10 and application.view.state == application.state, "10x10 selection reaches actual view")
	application._face_move("F")
	await _wait_idle("10x10 move")
	var ten_key: String = application.state.state_key()
	application._select_cube(3)
	await process_frame
	_check(application.state.size == 3 and application.state.state_key() == three_key, "return to 3x3 restores its own state")
	application._select_cube(2)
	await process_frame
	_check(application.state.state_key() == two_key, "2x2 retains independent state")
	application._select_cube(10)
	await process_frame
	_check(application.state.state_key() == ten_key, "10x10 retains independent state")
	application._select_cube(3)
	await process_frame


func _test_timer() -> void:
	application.state.reset(3)
	application.view.setup(application.state)
	var records_before: int = application.data.records.size()
	application._start_timer()
	_check(application.armed and not application.running, "time attack arms before shuffle")
	_check(application.scramble_active, "time attack starts shuffle")
	_check(not application.view.input_enabled, "shuffle locks touch input")
	# Replace the random queue with a deterministic, reachable one-move fixture.
	# The real shuffle coordinator, animation, and record capture still run.
	application.pending_scramble = [{"axis": 0, "layer": 2, "turns": 1}]
	var deadline := Time.get_ticks_msec() + 2000
	while application.scramble_active and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not application.scramble_active, "shuffle completes within timeout")
	_check(application.armed and not application.running, "shuffle does not start timer")
	_check(application.moves == 0, "shuffle rotations do not count as player moves")
	_check(application.view.input_enabled, "touch input reenabled after shuffle")
	_check(not application.state.is_solved(), "deterministic shuffle is unsolved")
	application._face_move("R")
	_check(application.running and not application.armed, "timer starts at first rotation start")
	_check(application.moves == 0, "first rotation counts only when committed")
	await create_timer(0.025).timeout
	_check(application.elapsed > 0.0, "first rotation animation contributes elapsed time")
	await _wait_idle("timed solution")
	_check(application.state.is_solved(), "timed inverse rotation solves actual cube")
	_check(not application.running and not application.armed, "completion stops timer")
	_check(application.moves == 1, "first rotation counts exactly once")
	_check(application.data.records.size() == records_before + 1, "completion creates one local record")
	if application.data.records.size() > records_before:
		var result: Dictionary = application.data.records[0]
		_check(int(result.moves) == 1 and float(result.time) > 0.0, "record stores real elapsed time and move count")
		_check(result.replay.size() == 1 and not result.scramble.is_empty(), "record retains shuffle and one replay move")


func _test_lessons() -> void:
	for n in [2, 3]:
		application._start_lesson(n)
		await process_frame
		_check(application.practice and application.page == "아카데미", "%dx%d lesson opens playable practice" % [n, n])
		_check(not application.state.is_solved(), "%dx%d lesson starts from training state" % [n, n])
		for step in range(4):
			application._lesson_next()
			await _wait_idle("%dx%d lesson step %d" % [n, n, step + 1])
			_check(application.lesson_step == step + 1, "%dx%d lesson advances after correct move %d" % [n, n, step + 1])
		_check(application.state.is_solved(), "%dx%d four inverse moves solve lesson" % [n, n])
		_check(bool(application.data.progress.get("inverse_" + str(n), false)), "%dx%d lesson marks genuine completion" % [n, n])
		var saved: Dictionary = application.store.load_data()
		_check(bool(saved.progress.get("inverse_" + str(n), false)), "%dx%d lesson completion persisted to disk" % [n, n])
	application._navigate("홈")
	await process_frame


func _test_restart() -> void:
	application._choose_sound("plastic")
	_check(application.sound.preset == "plastic", "sound selection reaches playback engine")
	application._save()
	var key: String = application.state.state_key()
	var record_count: int = application.data.records.size()
	application.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	application = packed_scene.instantiate()
	root.add_child(application)
	await process_frame
	_check(application.state.size == 3 and application.state.state_key() == key, "app recreation restores selected cube and exact state")
	_check(application.sound.preset == "plastic" and application.data.settings.sound == "plastic", "app recreation restores selected sound")
	_check(application.data.records.size() == record_count and record_count > 0, "app recreation restores local records")
	_check(bool(application.data.progress.get("inverse_2", false)) and bool(application.data.progress.get("inverse_3", false)), "app recreation restores both academy completions")
	_check(application.data.cubes.has("2") and application.data.cubes.has("10"), "app recreation retains multiple cube states")


func _wait_idle(label: String) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while application.view.is_busy() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not application.view.is_busy(), "animation completes within 2s: " + label)
	await process_frame


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _finish() -> void:
	for failure in failures:
		printerr("APP_FAILURE: " + failure)
	print("APP_TEST_RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
