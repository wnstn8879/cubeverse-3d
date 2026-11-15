class_name PyraminxView
extends Node3D
## A tetrahedral renderer and 120-degree gesture controller for PyraminxState.
## Geometry previews never change puzzle state; a released turn commits atomically.

signal move_started
signal move_completed(axis: int, layer: int, turns: int)
signal touched
signal rotation_progress(speed: float)
signal gesture_cancelled

const Puzzle = preload("res://scripts/puzzles/pyraminx_state.gd")
const PALETTE := [Color("f7cd61"), Color("f47f94"), Color("779df4"), Color("67dfbc")]
const TURN_ANGLE := TAU / 3.0

var state: RefCounted
var camera: Camera3D
var interaction_rect := Rect2()
var input_enabled := true
var tip_mode := false
var distance := 8.0
var yaw := 0.82
var pitch := 0.30
var _framing_distance := 8.0
var _still: MeshInstance3D
var _slice: MeshInstance3D
var _material: StandardMaterial3D
var _highlight_material: StandardMaterial3D
var _tween: Tween
var _busy := false
var _history_action := 0
var _turn_axis := -1
var _turn_layer := -1
var _angle := 0.0
var _pointers: Dictionary = {}
var _primary := -999
var _mouse_down := false
var _pinching := false
var _pinch_distance := 0.0
var _drag_start := Vector2.ZERO
var _drag_last := Vector2.ZERO
var _hit: Dictionary = {}
var _screen_tangent := Vector2.ZERO
var _pixels_per_radian := 120.0
var _last_motion_time := 0
var _velocity := 0.0
var _input_exclusions: Array[Rect2] = []


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.36
	_material.metallic_specular = 0.35
	_highlight_material = _material.duplicate()
	_highlight_material.emission_enabled = true
	_highlight_material.emission = Color(0.045, 0.055, 0.075)
	_still = MeshInstance3D.new()
	_slice = MeshInstance3D.new()
	add_child(_still)
	add_child(_slice)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 36.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = 0.1
	camera.far = 50.0
	add_child(camera)
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("0a0e1b")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color("eef2ff")
	world.ambient_light_energy = 0.55
	world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = world
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_color = Color("edf5ff")
	key.light_energy = 1.05
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(15, 125, 0)
	rim.light_color = Color("dbe6ff")
	rim.light_energy = 0.3
	add_child(rim)
	get_viewport().msaa_3d = Viewport.MSAA_2X
	_update_camera()
	if state != null:
		rebuild()


func setup(puzzle: RefCounted) -> void:
	if _busy:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_busy = false
		_history_action = 0
		_turn_axis = -1
		_turn_layer = -1
	cancel_drag()
	state = puzzle
	if is_node_ready():
		rebuild()


func get_palette() -> Array:
	return PALETTE.duplicate()


func set_variant(_id: String) -> bool:
	# Pyraminx has its own four-color puzzle definition, not an NxN skin.
	return not is_busy()


func set_tip_mode(enabled: bool) -> void:
	tip_mode = enabled


func set_input_exclusion_rects(rects: Array) -> void:
	_input_exclusions.clear()
	for rect in rects:
		if rect is Rect2:
			_input_exclusions.append(rect)


func set_interaction_rect(rect: Rect2) -> void:
	var changed := interaction_rect != rect
	interaction_rect = rect
	if camera != null:
		_update_camera()
		if changed:
			_fit_camera()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		cancel_drag()


func is_busy() -> bool:
	return _busy or _turn_axis >= 0


func reset_camera() -> void:
	yaw = 0.82
	pitch = 0.30
	distance = 8.0
	_update_camera()
	_fit_camera()


func set_face_camera(normal_or_face: Variant) -> bool:
	if is_busy():
		return false
	var normal := Vector3.ZERO
	if normal_or_face is int:
		if normal_or_face < 0 or normal_or_face > 3:
			return false
		normal = -Puzzle.axis_direction(normal_or_face)
	elif normal_or_face is Vector3 or normal_or_face is Vector3i:
		normal = Vector3(normal_or_face)
	if normal.length_squared() < 0.5:
		return false
	cancel_drag()
	var direction := normal.normalized()
	yaw = atan2(direction.x, direction.z) + 0.10
	pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)) + 0.04, -1.37, 1.37)
	_update_camera()
	_fit_camera()
	return true


func rebuild() -> void:
	if _still == null or state == null:
		return
	_still.mesh = _build_mesh(-1, -1, false)
	_slice.mesh = null
	_slice.basis = Basis.IDENTITY


func animate_move(axis: int, layer: int, turns: int, commit: bool = true) -> bool:
	if is_busy() or state == null or axis < 0 or axis > 3 or layer < 0 or layer > 1 or posmod(turns, 3) == 0:
		return false
	_begin_slice(axis, layer)
	_snap_to(turns, commit)
	return true


func request_undo() -> bool:
	if is_busy() or state == null or state.history.is_empty():
		return false
	var move: Dictionary = state.history.back()
	_history_action = -1
	_begin_slice(move.axis, move.layer)
	_snap_to(-move.turns, false)
	return true


func request_redo() -> bool:
	if is_busy() or state == null or state.future.is_empty():
		return false
	var move: Dictionary = state.future.back()
	_history_action = 1
	_begin_slice(move.axis, move.layer)
	_snap_to(move.turns, false)
	return true


func cancel_drag() -> void:
	_pointers.clear()
	_primary = -999
	_mouse_down = false
	_pinching = false
	_hit.clear()
	if _busy:
		return
	if _turn_axis >= 0:
		_turn_axis = -1
		_turn_layer = -1
		_angle = 0.0
		rebuild()
		gesture_cancelled.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_drag()


func _update_camera() -> void:
	if camera == null:
		return
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	var target := to_global(Vector3(0, 0.36, 0))
	camera.global_position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target, Vector3.UP)
	var viewport_size := get_viewport().get_visible_rect().size
	if interaction_rect.size.x > 0.0 and viewport_size.x > 0.0:
		var shift := interaction_rect.get_center() - viewport_size * 0.5
		var world_per_pixel := 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5) / viewport_size.x
		camera.h_offset = -shift.x * world_per_pixel
		camera.v_offset = shift.y * world_per_pixel


func _fit_camera() -> void:
	if camera == null or interaction_rect.size.x <= 0.0 or interaction_rect.size.y <= 0.0:
		return
	var target := interaction_rect.grow(-maxf(18.0, interaction_rect.size.x * 0.045))
	for _iteration in range(3):
		var ratio := 0.0
		for point in Puzzle.VERTICES:
			var delta := camera.unproject_position(to_global(point)) - target.get_center()
			ratio = maxf(ratio, maxf(absf(delta.x) / (target.size.x * 0.5), absf(delta.y) / (target.size.y * 0.5)))
		distance = maxf(5.0, distance * ratio * 1.02)
		_update_camera()
	_framing_distance = distance


func _inside(point: Vector2) -> bool:
	for excluded in _input_exclusions:
		if excluded.has_point(point):
			return false
	return interaction_rect.has_point(point) if interaction_rect.size.x > 0.0 else get_viewport().get_visible_rect().has_point(point)


func _input(event: InputEvent) -> void:
	if not input_enabled or state == null or camera == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down(event.index, event.position)
		else:
			_pointer_up(event.index, event.position, event.canceled)
	elif event is InputEventScreenDrag:
		_pointer_move(event.index, event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = event.pressed
			if event.pressed:
				_pointer_down(-1, event.position)
			else:
				_pointer_up(-1, event.position, false)
		elif event.pressed and _inside(event.position):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				distance = clampf(distance - 0.4, _framing_distance * 0.72, _framing_distance * 1.5)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				distance = clampf(distance + 0.4, _framing_distance * 0.72, _framing_distance * 1.5)
			_update_camera()
	elif event is InputEventMouseMotion and _mouse_down:
		_pointer_move(-1, event.position)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_drag()


func _pointer_down(id: int, point: Vector2) -> void:
	if _busy or not _inside(point):
		return
	_pointers[id] = point
	if _pointers.size() >= 2:
		if _turn_axis >= 0:
			_turn_axis = -1
			_turn_layer = -1
			_angle = 0.0
			rebuild()
			gesture_cancelled.emit()
		_pinching = true
		_hit.clear()
		var points := _pointers.values()
		_pinch_distance = points[0].distance_to(points[1])
		return
	_primary = id
	_drag_start = point
	_drag_last = point
	_last_motion_time = Time.get_ticks_msec()
	_velocity = 0.0
	_hit = _pick(point)
	if not _hit.is_empty():
		touched.emit()


func _pointer_move(id: int, point: Vector2) -> void:
	if not _pointers.has(id) or _busy:
		return
	_pointers[id] = point
	if _pinching:
		if _pointers.size() >= 2:
			var points := _pointers.values()
			var next_distance: float = points[0].distance_to(points[1])
			if _pinch_distance > 1.0 and next_distance > 1.0:
				distance = clampf(distance * _pinch_distance / next_distance, _framing_distance * 0.72, _framing_distance * 1.5)
				_update_camera()
			_pinch_distance = next_distance
		return
	if id != _primary:
		return
	var delta := point - _drag_last
	var displacement := point - _drag_start
	var now := Time.get_ticks_msec()
	var elapsed := maxf(float(now - _last_motion_time) / 1000.0, 0.001)
	if _hit.is_empty():
		yaw -= delta.x * 0.008
		pitch = clampf(pitch + delta.y * 0.008, -1.18, 1.18)
		_update_camera()
	elif _turn_axis < 0 and displacement.length() >= 7.0:
		_choose_slice(displacement)
	if _turn_axis >= 0:
		_velocity = lerpf(_velocity, delta.dot(_screen_tangent) / elapsed, 0.65)
		_angle = clampf(displacement.dot(_screen_tangent) / _pixels_per_radian, -TAU, TAU)
		_slice.basis = Basis(Puzzle.axis_direction(_turn_axis), _angle)
		rotation_progress.emit(absf(_velocity) / _pixels_per_radian)
	_drag_last = point
	_last_motion_time = now


func _pointer_up(id: int, _point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id):
		return
	_pointers.erase(id)
	if canceled:
		cancel_drag()
		return
	if _pinching:
		if _pointers.is_empty():
			_pinching = false
			_primary = -999
		return
	if id != _primary:
		return
	_primary = -999
	_hit.clear()
	if _turn_axis < 0:
		return
	var turns := roundi(_angle / TURN_ANGLE)
	if turns == 0 and absf(_angle) > 0.18 and absf(_velocity) > 650.0 and Time.get_ticks_msec() - _last_motion_time < 90:
		turns = 1 if _angle > 0.0 else -1
	_snap_to(turns, true)


func _pick(point: Vector2) -> Dictionary:
	var origin := to_local(camera.project_ray_origin(point))
	var direction := global_transform.basis.inverse() * camera.project_ray_normal(point)
	var enter := -INF
	var leave := INF
	var face := -1
	for index in range(4):
		var normal: Vector3 = -Puzzle.axis_direction(index)
		var signed_distance := normal.dot(origin) - Puzzle.RADIUS / 3.0
		var velocity := normal.dot(direction)
		if absf(velocity) < 0.00001:
			if signed_distance > 0.0:
				return {}
			continue
		var time := -signed_distance / velocity
		if velocity < 0.0:
			if time > enter:
				enter = time
				face = index
		else:
			leave = minf(leave, time)
		if leave < maxf(0.0, enter):
			return {}
	if enter < 0.0 or face < 0:
		return {}
	var hit_point := origin + direction * enter
	var weights: Array = []
	for axis in range(4):
		weights.append(clampf((1.0 + 3.0 * hit_point.dot(Puzzle.VERTICES[axis]) / (Puzzle.RADIUS * Puzzle.RADIUS)) * 0.25, 0.0, 1.0))
	return {"point": hit_point, "face": face, "normal": -Puzzle.axis_direction(face), "barycentric": weights}


func _choose_slice(displacement: Vector2) -> void:
	var hit_point: Vector3 = _hit.point
	var weights: Array = _hit.barycentric
	var origin_screen := camera.unproject_position(to_global(hit_point))
	var largest := 0
	for index in range(1, 4):
		if weights[index] > weights[largest]:
			largest = index
	var layer := 0 if tip_mode or weights[largest] > 2.0 / 3.0 else 1
	var chosen := -1
	var best := -1.0
	for axis in range(4):
		if axis == int(_hit.face):
			continue
		if layer == 0 and axis != largest:
			continue
		if layer == 1 and float(weights[axis]) < 1.0 / 3.0 - 0.02:
			continue
		var velocity := Puzzle.axis_direction(axis).cross(hit_point)
		var projected := (camera.unproject_position(to_global(hit_point + velocity * 0.05)) - origin_screen) / 0.05
		if projected.length() < 1.0:
			continue
		var alignment := absf(displacement.normalized().dot(projected.normalized()))
		if alignment > best:
			best = alignment
			chosen = axis
			_screen_tangent = projected.normalized()
			_pixels_per_radian = maxf(projected.length(), 45.0)
	if chosen >= 0:
		_begin_slice(chosen, layer)


func _begin_slice(axis: int, layer: int) -> void:
	_turn_axis = axis
	_turn_layer = layer
	_angle = 0.0
	_still.mesh = _build_mesh(axis, layer, false)
	_slice.mesh = _build_mesh(axis, layer, true)
	_slice.material_override = _highlight_material
	_slice.basis = Basis.IDENTITY
	move_started.emit()


func _snap_to(turns: int, commit: bool) -> void:
	_busy = true
	var target := float(turns) * TURN_ANGLE
	var axis := _turn_axis
	var layer := _turn_layer
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(value: float):
		_angle = value
		_slice.basis = Basis(Puzzle.axis_direction(axis), value),
		_angle, target, clampf(absf(target - _angle) * 0.11, 0.09, 0.27))
	_tween.tween_callback(func():
		if _history_action == -1:
			state.undo()
		elif _history_action == 1:
			state.redo()
		elif commit and posmod(turns, 3) != 0:
			state.apply_move(axis, layer, turns)
		_history_action = 0
		_turn_axis = -1
		_turn_layer = -1
		_angle = 0.0
		_busy = false
		rebuild()
		if posmod(turns, 3) != 0:
			move_completed.emit(axis, layer, -1 if posmod(turns, 3) == 2 else 1)
		else:
			gesture_cancelled.emit())


func _build_mesh(axis: int, layer: int, selected: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_add_body(vertices, normals, colors, indices, axis, layer, selected)
	for sticker in state.stickers:
		var on_slice: bool = axis >= 0 and state.selected_sticker(sticker, axis, layer)
		if on_slice != selected:
			continue
		var center: Vector3 = sticker.center
		var normal: Vector3 = sticker.normal
		var triangle: Array = []
		for point in sticker.vertices:
			triangle.append(center + (point - center) * 0.923 + normal * 0.016)
		_add_polygon(vertices, normals, colors, indices, triangle, PALETTE[sticker.c], normal)
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material)
	return mesh


func _add_body(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, axis: int, layer: int, selected: bool) -> void:
	var body_color := Color("172136")
	if axis < 0:
		for face in range(4):
			var points: Array = []
			for index in range(4):
				if index != face:
					points.append(Puzzle.VERTICES[index])
			_add_polygon(vertices, normals, colors, indices, points, body_color, -Puzzle.axis_direction(face))
		return
	var fraction := 2.0 / 3.0 if layer == 0 else 1.0 / 3.0
	var others: Array = []
	var cuts := {}
	for index in range(4):
		if index != axis:
			others.append(index)
			cuts[index] = Puzzle.VERTICES[index].lerp(Puzzle.VERTICES[axis], fraction)
	if selected:
		for face in others:
			var points: Array = [Puzzle.VERTICES[axis]]
			for index in others:
				if index != face:
					points.append(cuts[index])
			_add_polygon(vertices, normals, colors, indices, points, body_color, -Puzzle.axis_direction(face))
		var base: Array = []
		for index in others:
			base.append(cuts[index])
		_add_polygon(vertices, normals, colors, indices, base, body_color, -Puzzle.axis_direction(axis))
	else:
		var bottom: Array = []
		for index in others:
			bottom.append(Puzzle.VERTICES[index])
		_add_polygon(vertices, normals, colors, indices, bottom, body_color, -Puzzle.axis_direction(axis))
		for face in others:
			var edge: Array = []
			for index in others:
				if index != face:
					edge.append(index)
			var points: Array = [Puzzle.VERTICES[edge[0]], Puzzle.VERTICES[edge[1]], cuts[edge[1]], cuts[edge[0]]]
			_add_polygon(vertices, normals, colors, indices, points, body_color, -Puzzle.axis_direction(face))
		var cap: Array = []
		for index in others:
			cap.append(cuts[index])
		_add_polygon(vertices, normals, colors, indices, cap, body_color, Puzzle.axis_direction(axis))


func _add_polygon(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, polygon: Array, color: Color, normal: Vector3) -> void:
	if polygon.size() < 3:
		return
	var points := polygon.duplicate()
	# Godot's clockwise front faces are the inverse of an outward cross product.
	var cross: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
	if cross.dot(normal) < 0.0:
		points.reverse()
	var base := vertices.size()
	for point in points:
		vertices.append(point)
		normals.append(normal)
		colors.append(color)
	for index in range(1, points.size() - 1):
		indices.append(base)
		indices.append(base + index + 1)
		indices.append(base + index)
