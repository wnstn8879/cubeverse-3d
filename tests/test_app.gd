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
	await _test_variants_and_pyraminx()
	await _test_timer()
	await _test_lessons()
	await _test_pyraminx_lesson()
	await _test_restart()
	application.queue_free()
	await process_frame
	# Let the audio server release stopped stream references before engine shutdown.
	await create_timer(0.5).timeout
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


func _test_variants_and_pyraminx() -> void:
	var original: String = application.state.state_key()
	var snapshots: Dictionary = {}
	for id in ["three_color", "pillow", "crystal", "neon"]:
		application._select_variant(id)
		await process_frame
		_check(application.variant == id and application.puzzle_kind == "cube", "appearance selector reaches actual cube: " + id)
		_check(application.view.variant == id, "renderer receives selected geometry/palette: " + id)
		_check(is_instance_valid(application.minimap) and application.minimap.state == application.state, "minimap follows actual variant state: " + id)
		var before: String = application.state.state_key()
		application._face_move("F")
		await _wait_idle("variant " + id)
		_check(application.state.state_key() != before, "appearance retains legal playable rotations: " + id)
		snapshots[id] = application.state.state_key()
	# On the three-color puzzle, opposite colors intentionally look identical.
	# A middle half-turn changes exact six-color state but remains visibly solved.
	application._select_variant("three_color")
	await process_frame
	application.state.reset(3)
	application.state.apply_move(0, 1, 2)
	application.view.rebuild()
	_check(not application.state.is_solved() and application._is_solved(), "three-color solved detection follows visible color pairs")
	snapshots["three_color"] = application.state.state_key()
	for id in snapshots:
		application._select_variant(id)
		await process_frame
		_check(application.state.state_key() == snapshots[id], "variant switching preserves its independent puzzle: " + id)
	application._select_variant("classic")
	await process_frame
	_check(application.state.state_key() == original, "new variants do not overwrite classic saved progress")
	application._select_pyraminx()
	await process_frame
	_check(application.puzzle_kind == "pyraminx" and application.state.puzzle_id == "pyraminx", "Pyraminx uses its separate tetrahedral state engine")
	_check(application.state.is_solved(), "new Pyraminx starts solved")
	var tetrahedron: String = application.state.state_key()
	application._face_move("U")
	await _wait_idle("Pyraminx main turn")
	var turned: String = application.state.state_key()
	_check(turned != tetrahedron and not application.state.is_solved(), "Pyraminx120-degree main turn changes real puzzle state")
	application._undo()
	await _wait_idle("Pyraminx undo")
	_check(application.state.state_key() == tetrahedron, "Pyraminx animated undo restores tetrahedron")
	application._redo()
	await _wait_idle("Pyraminx redo")
	_check(application.state.state_key() == turned, "Pyraminx animated redo restores turn")
	application._toggle_tip()
	application._face_move("R")
	await _wait_idle("Pyraminx tip turn")
	_check(int(application.state.history.back().layer) == 0, "Pyraminx tip mode commits independent tip rotation")
	var saved_pyraminx: String = application.state.state_key()
	application._select_cube(3)
	await process_frame
	_check(application.state.state_key() == original, "returning from Pyraminx restores original classic puzzle")
	application._select_pyraminx()
	await process_frame
	_check(application.state.state_key() == saved_pyraminx, "Pyraminx has independent durable puzzle progress")
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
		_check(application.practice and application.page == "아카데미", "%dx%d course opens playable practice" % [n, n])
		_check(application.lesson_stages.size() >= (9 if n == 3 else 5), "%dx%d course teaches introductions and full method stages" % [n, n])
		_check(not application.state.is_solved(), "%dx%d course starts from a prepared unsolved example" % [n, n])
		var stages: Array = application.lesson_stages.duplicate(true)
		for index in range(stages.size()):
			var stage: Dictionary = stages[index]
			_check(application.lesson_stage_index == index, "%dx%d opens stage %d in order" % [n, n, index])
			_check(not str(stage.get("title", "")).is_empty() and not str(stage.get("explanation", "")).is_empty(), "%dx%d stage %d includes plain-language teaching" % [n, n, index])
			_check(not str(stage.get("goal", "")).is_empty(), "%dx%d stage %d states a visible goal" % [n, n, index])
			var steps: Array = stage.moves
			if not steps.is_empty():
				application._advance_lesson_stage()
				await process_frame
				_check(application.lesson_stage_index == index, "%dx%d stage %d cannot be skipped before solving" % [n, n, index])
			for step in range(steps.size()):
				application._lesson_next()
				await _wait_idle("%dx%d stage %d move %d" % [n, n, index, step])
				_check(application.lesson_step == step + 1, "%dx%d stage %d commits correct hint %d" % [n, n, index, step])
			if index == stages.size() - 1:
				_check(application.state.is_solved(), "%dx%d complete method solves all six actual faces" % [n, n])
			application._advance_lesson_stage()
			await process_frame
		_check(bool(application.data.progress.get("beginner_" + str(n) + "_complete", false)), "%dx%d course records full completion" % [n, n])
		var saved: Dictionary = application.store.load_data()
		_check(bool(saved.progress.get("beginner_" + str(n) + "_complete", false)), "%dx%d course completion persists to disk" % [n, n])
		application._navigate("홈")
		await process_frame


func _test_pyraminx_lesson() -> void:
	var free_key: String = application.state.state_key()
	application._start_pyraminx_lesson()
	await process_frame
	_check(application.practice and application.puzzle_kind == "pyraminx", "Pyraminx course uses its own playable puzzle")
	_check(application.lesson_stages.size() >= 5, "Pyraminx teaches pieces, notation, tips, centers and edges")
	var stages: Array = application.lesson_stages.duplicate(true)
	for index in range(stages.size()):
		var stage: Dictionary = stages[index]
		_check(application.lesson_stage_index == index, "Pyraminx course opens stage %d in order" % index)
		_check(not str(stage.get("explanation", "")).is_empty() and not str(stage.get("goal", "")).is_empty(), "Pyraminx stage %d has beginner explanations" % index)
		if not stage.moves.is_empty():
			application._advance_lesson_stage()
			_check(application.lesson_stage_index == index, "Pyraminx stage %d requires actual turns before advancing" % index)
		for step in range(stage.moves.size()):
			application._lesson_next()
			await _wait_idle("Pyraminx stage %d move %d" % [index, step])
			_check(application.lesson_step == step + 1, "Pyraminx follows correct120-degree hint %d/%d" % [index, step])
		if index == stages.size() - 1:
			_check(application.state.is_solved(), "Pyraminx full course actually solves all four faces")
		application._advance_lesson_stage()
		await process_frame
	_check(bool(application.data.progress.get("beginner_pyraminx_complete", false)), "Pyraminx course records completion")
	_check(bool(application.store.load_data().progress.get("beginner_pyraminx_complete", false)), "Pyraminx course completion survives local save")
	application._navigate("홈")
	await process_frame
	_check(application.puzzle_kind == "cube" and application.state.state_key() == free_key, "Pyraminx course preserves and restores prior classic puzzle")


func _test_restart() -> void:
	application._choose_sound("plastic")
	_check(application.sound.preset == "plastic", "sound selection reaches playback engine")
	application._save()
	var key: String = application.state.state_key()
	var record_count: int = application.data.records.size()
	application.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	application = packed_scene.instantiate()
	root.add_child(application)
	await process_frame
	_check(application.state.size == 3 and application.state.state_key() == key, "app recreation restores selected cube and exact state")
	_check(application.sound.preset == "plastic" and application.data.settings.sound == "plastic", "app recreation restores selected sound")
	_check(application.data.records.size() == record_count and record_count > 0, "app recreation restores local records")
	_check(bool(application.data.progress.get("beginner_2_complete", false)) and bool(application.data.progress.get("beginner_3_complete", false)), "app recreation restores both academy completions")
	_check(application.data.cubes.has("2") and application.data.cubes.has("10"), "app recreation retains multiple cube states")
	_check(bool(application.data.progress.get("beginner_pyraminx_complete", false)), "app recreation restores Pyraminx course completion")


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
