extends SceneTree
## Regressions for bugs found while reviewing application/state ownership.
const State = preload("res://scripts/core/cube_state.gd")
var application

func _initialize() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/main.tscn")
	application = scene.instantiate()
	root.add_child(application)
	await process_frame
	application.state.apply_move(0, 2, 1)
	application.view.rebuild()
	application._save()
	var free_key: String = application.state.state_key()
	application._start_lesson(2)
	assert(application.practice and application.state.size == 2)
	application._save()
	var saved: Dictionary = application.store.load_data()
	var saved_free = State.new()
	assert(int(saved.settings.selected_cube) == 3)
	assert(saved_free.from_dict(saved.cubes["3"]))
	assert(saved_free.state_key() == free_key) # Lesson autosave preserves free play.
	var intro_key: String = application.state.state_key()
	assert(application.view.animate_move(0, application.state.size - 1, 1))
	await _idle()
	assert(application.lesson_step == 0 and application.state.state_key() == intro_key)
	# Introduction stages teach pieces/notation without pretending to make a turn.
	while application.lesson_stage_index < application.lesson_stages.size() and application.lesson_stages[application.lesson_stage_index].moves.is_empty():
		application._advance_lesson_stage()
		await process_frame
	assert(application.lesson_stage_index < application.lesson_stages.size())
	var stage_index: int = application.lesson_stage_index
	var lesson_key: String = application.state.state_key()
	var expected: Dictionary = application.lesson_stages[stage_index].moves[0]
	assert(application.view.animate_move((int(expected.axis) + 1) % 3, application.state.size - 1, 1))
	await _idle()
	assert(application.lesson_step == 0)
	assert(application.state.state_key() == lesson_key) # Wrong step is rolled back.
	application._lesson_next()
	assert(application.view.is_busy())
	application._stop_lesson() # Exit during a committed snap cannot replace state.
	assert(application.practice and application.state.size == 2)
	await _idle()
	assert(application.lesson_step == 1)
	application._restart_lesson_stage()
	await process_frame
	assert(application.lesson_step == 0)
	assert(application.state.state_key() == lesson_key) # Restart returns to that stage's own checkpoint.
	for _step in range(application.lesson_moves.size()):
		application._lesson_next()
		await _idle()
	var completed_stage: String = application.state.state_key()
	assert(application.view.animate_move(1, application.state.size - 1, 1))
	await _idle()
	assert(application.state.state_key() == completed_stage) # Completed stages stay stable until explicit advance.
	application._navigate("홈")
	assert(not application.practice)
	assert(application.state.size == 3 and application.state.state_key() == free_key)
	application._start_lesson(3)
	while application.lesson_stages[application.lesson_stage_index].moves.is_empty():
		application._advance_lesson_stage()
		await process_frame
	var half_turn: Dictionary = application.lesson_moves[0]
	assert(absi(int(half_turn.turns)) == 2)
	var expected_half = State.new(3)
	assert(expected_half.from_dict(application.state.to_dict()))
	expected_half.apply_move(half_turn.axis, half_turn.layer, half_turn.turns)
	assert(application.view.animate_move(half_turn.axis, half_turn.layer, -half_turn.turns))
	await _idle()
	assert(application.lesson_step == 1 and application.state.state_key() == expected_half.state_key()) # Either180-degree direction is the same legal move.
	application._navigate("홈")
	assert(application.state.state_key() == free_key)
	application._save()
	application._shuffle()
	assert(application.scramble_active and not application.view.input_enabled)
	application._render() # A resize/re-layout must not unlock shuffle gestures.
	assert(not application.view.input_enabled)
	application.pending_scramble.clear()
	await create_timer(0.1).timeout
	assert(not application.scramble_active and application.view.input_enabled)
	application.data.cubes["2"] = null
	application._select_cube(2)
	assert(application.state.size == 2 and application.state.is_solved())
	application.data.records = [null, {}, {"size": "broken", "time": 1, "moves": 1}]
	application._navigate("아레나")
	assert(application.page == "아레나")
	application.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("APP_REGRESSIONS_PASS")
	quit(0)

func _idle() -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while application.view.is_busy() and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not application.view.is_busy())
	await process_frame
