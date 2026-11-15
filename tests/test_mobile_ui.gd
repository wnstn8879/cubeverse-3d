extends SceneTree
## Real Viewport input dispatch, without Button.pressed.emit().
## Headless parse_input_event may not perform OS touch-to-mouse synthesis.

var app
var checks := 0
var failures: Array[String] = []
var touch_gui_supported := false
var completed_moves := 0
var map_face_taps := 0


func _initialize() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("MOBILE_UI_CHECK_FAILED: " + message)


func _run() -> void:
	_check(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", false)), "project enables touch-to-mouse for native GUI")
	_check(Input.is_emulating_mouse_from_touch(), "runtime enables touch-to-mouse")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var original: String = app.state.state_key()
	var cube_tab := _find_button(app.ui, "큐브")
	_check(cube_tab != null, "cube tab has a pointer target")
	if cube_tab == null:
		_finish()
		return
	await _screen_tap(cube_tab.get_global_rect().get_center())
	touch_gui_supported = app.page == "큐브"
	if touch_gui_supported:
		print("MOBILE_UI_INPUT_SCOPE=Input.parse_input_event screen-touch GUI and cube dispatch verified; physical-device delivery remains unverified")
	else:
		print("MOBILE_UI_INPUT_SCOPE=headless raw ScreenTouch does not synthesize GUI mouse; testing mouse GUI dispatch and raw touch cube gestures. OS/browser touch-to-mouse delivery remains device-test scope.")
		await _mouse_click(cube_tab.get_global_rect().get_center())
	_check(app.page == "큐브", "pointer activates cube tab")
	_check(app.state.state_key() == original, "navigation pointer does not rotate cube")
	_check(not app.view.input_enabled, "cube picker disables gameplay input")
	await _activate("2 × 2", true)
	_check(app.state.size == 2 and app.page == "홈", "pointer selects actual 2x2 puzzle")
	_check(app.state.is_solved() and app.state.history.is_empty(), "cube selection pointer produces no turn")
	var two_key: String = app.state.state_key()
	await _activate("설정")
	_check(app.page == "설정", "pointer opens settings")
	_check(app.state.state_key() == two_key, "settings pointer preserves cube")
	await _activate("플라스틱 큐브", false, true)
	_check(app.sound.preset == "plastic", "pointer changes functional sound setting")
	_check(app.store.load_data().settings.sound == "plastic", "pointer-selected sound persists")
	await _activate("홈")
	_check(app.page == "홈" and app.view.input_enabled, "pointer returns to interactive play")
	_check(app.state.state_key() == two_key, "GUI clicks never add cube turns")
	await _test_minimap_faces(false)
	await _test_touch_turn()
	await _test_pyraminx_ui()
	app.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	_finish()


func _test_minimap_faces(is_pyraminx: bool) -> void:
	await process_frame
	await process_frame
	var map = app.minimap
	_check(is_instance_valid(map), "live face minimap exists for selected puzzle")
	if not is_instance_valid(map): return
	if is_pyraminx: map._layout()
	else: map._layout_faces()
	var rectangles: Array = map._hit_rects if is_pyraminx else map._face_hit_rects
	var expected := 4 if is_pyraminx else 6
	_check(rectangles.size() == expected, "minimap exposes every actual puzzle face")
	map.face_selected.connect(_on_map_face)
	var original: String = app.state.state_key()
	var history_count: int = app.state.history.size()
	for index in range(rectangles.size()):
		var point: Vector2 = map.global_position + rectangles[index].get_center()
		_check(root.get_visible_rect().has_point(point), "minimap face tap is visible: %d" % index)
		var before: Vector3 = app.view.camera.position
		var taps_before := map_face_taps
		if touch_gui_supported: await _screen_tap(point)
		else: await _mouse_click(point)
		_check(map_face_taps == taps_before + 1, "touch selects a minimap face exactly once: %d" % index)
		_check(app.view.camera.position.distance_to(before) > 0.01, "minimap touch changes actual camera: %d" % index)
		_check(app.state.state_key() == original and app.state.history.size() == history_count, "minimap camera tap never rotates puzzle pieces: %d" % index)
	map.face_selected.disconnect(_on_map_face)
	app.view.reset_camera()


func _on_map_face(_face: Variant) -> void:
	map_face_taps += 1


func _test_pyraminx_ui() -> void:
	var saved_cube: String = app.state.state_key()
	await _activate("큐브")
	await _activate("△  피라밍크스", true)
	_check(app.puzzle_kind == "pyraminx", "actual pointer selects the tetrahedral puzzle")
	await _test_minimap_faces(true)
	await _activate("큰 층")
	_check(app.tip_mode and app.view.tip_mode, "tip UI mode reaches actual Pyraminx gesture renderer")
	await _activate("U")
	var deadline := Time.get_ticks_msec() + 2000
	while app.view.is_busy() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not app.view.is_busy(), "Pyraminx pointer move finishes within timeout")
	_check(not app.state.history.is_empty() and int(app.state.history.back().layer) == 0, "Pyraminx pointer control turns the independent tip")
	await _activate("큐브")
	await _activate("2 × 2", true)
	_check(app.puzzle_kind == "cube" and app.state.state_key() == saved_cube, "actual pointer returns to the saved classic cube")


func _test_touch_turn() -> void:
	app.view.move_completed.connect(_on_move_completed)
	var view = app.view
	var point: Vector2 = view.camera.unproject_position(Vector3(0.6, 0.1, 1.5))
	_check(view.interaction_rect.has_point(point) and not view._pick(point).is_empty(), "touch target lies on playable cube")
	var original: String = app.state.state_key()
	var history_before: int = app.state.history.size()
	_screen_touch(point, true)
	await process_frame
	# Android/browser input may deliver synthetic mouse events beside raw touch.
	# They must not become a second pointer or trigger a second turn.
	_mouse_button(point, true, InputEvent.DEVICE_ID_EMULATION)
	await process_frame
	_check(view._pointers.size() == 1 and view._pointers.has(0), "emulated mouse does not duplicate touch pointer")
	var endpoint := point + Vector2(140, 0)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _window_point(endpoint)
	drag.relative = root.get_final_transform().basis_xform(Vector2(140, 0))
	Input.parse_input_event(drag)
	await process_frame
	_check(view.is_busy(), "raw screen drag previews a slice")
	_check(app.state.state_key() == original, "touch preview leaves logical state unchanged")
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.device = InputEvent.DEVICE_ID_EMULATION
	mouse_motion.position = drag.position
	mouse_motion.relative = drag.relative
	Input.parse_input_event(mouse_motion)
	_screen_touch(endpoint, false)
	_mouse_button(endpoint, false, InputEvent.DEVICE_ID_EMULATION)
	var deadline := Time.get_ticks_msec() + 2000
	while view.is_busy() and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	_check(not view.is_busy(), "touch release snaps within timeout")
	_check(completed_moves == 1, "raw touch plus emulated mouse commits exactly one move")
	_check(app.state.history.size() == history_before + 1, "touch gesture adds exactly one history entry")
	_check(app.state.state_key() != original, "raw touch gesture changes actual puzzle")
	_check(view._pointers.is_empty(), "touch release clears pointer state")


func _on_move_completed(_axis: int, _layer: int, _turns: int) -> void:
	completed_moves += 1


func _activate(text: String, prefix := false, suffix := false) -> void:
	await process_frame
	var button := _find_button(app.ui, text, prefix, suffix)
	_check(button != null, "pointer target exists: " + text)
	if button == null:
		return
	var parent := button.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(button)
			await process_frame
			await process_frame
			break
		parent = parent.get_parent()
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "pointer target lies in viewport: " + text)
	if touch_gui_supported:
		await _screen_tap(point)
	else:
		await _mouse_click(point)


func _screen_tap(point: Vector2) -> void:
	_screen_touch(point, true)
	await process_frame
	_screen_touch(point, false)
	await process_frame
	await process_frame


func _screen_touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = _window_point(point)
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse_click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _window_point(point)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await process_frame
	_mouse_button(point, true)
	await process_frame
	_mouse_button(point, false)
	await process_frame
	await process_frame


func _mouse_button(point: Vector2, pressed: bool, device: int = 0) -> void:
	var event := InputEventMouseButton.new()
	event.device = device
	event.position = _window_point(point)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)


func _window_point(logical_position: Vector2) -> Vector2:
	# Headless DisplayServer can expose a 64x64 physical window while the project
	# renders a logical 540x960 viewport. parse_input_event expects window pixels.
	return root.get_final_transform() * logical_position


func _find_button(node: Node, text: String, prefix := false, suffix := false) -> Button:
	if node is Button:
		if node.text == text or (prefix and node.text.begins_with(text)) or (suffix and node.text.ends_with(text)):
			return node as Button
	for child in node.get_children():
		var found := _find_button(child, text, prefix, suffix)
		if found != null:
			return found
	return null


func _finish() -> void:
	for failure in failures:
		printerr("MOBILE_UI_FAILURE: " + failure)
	print("MOBILE_UI_TEST_RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
