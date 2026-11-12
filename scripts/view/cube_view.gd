class_name CubeView
extends Node3D
## Rendering and gestures are independent from the exact, integer puzzle state.
## One merged mesh at rest, two while turning: no per-sticker scene nodes.

signal move_started
signal move_completed(axis: int, layer: int, turns: int)
signal touched
signal rotation_progress(speed: float)
signal gesture_cancelled

const CUBE_HALF := 1.5
# Engine face order: R, L, U, D, F(+Z), B(-Z).
const PALETTE := [Color("f45b68"), Color("ff9348"), Color("f7f4e9"), Color("f6c343"), Color("54d5b5"), Color("5688f4")]
const AXES := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]

var state: RefCounted
var camera: Camera3D
var interaction_rect := Rect2()
var input_enabled := true
var distance := 8.0
var _framing_distance := 8.0
var yaw := 0.62
var pitch := 0.48
var _still: MeshInstance3D
var _slice: MeshInstance3D
var _material: StandardMaterial3D
var _highlight_material: StandardMaterial3D
var _tween: Tween
var _busy := false
var _pointers: Dictionary = {}
var _primary := -999
var _drag_start := Vector2.ZERO
var _drag_last := Vector2.ZERO
var _hit: Dictionary = {}
var _turn_axis := -1
var _turn_layer := -1
var _angle := 0.0
var _screen_tangent := Vector2.ZERO
var _pixels_per_radian := 150.0
var _last_motion_time := 0
var _velocity := 0.0
var _pinch_distance := 0.0
var _pinching := false
var _mouse_down := false
var _history_action := 0


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.31
	_material.metallic_specular = 0.38
	_highlight_material = _material.duplicate()
	_highlight_material.emission_enabled = true
	_highlight_material.emission = Color(0.055, 0.065, 0.09)
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
	world.ambient_light_energy = 0.48
	world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = world
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_color = Color("edf5ff")
	key.light_energy = 1.1
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(15, 125, 0)
	rim.light_color = Color("dbe6ff")
	rim.light_energy = 0.35
	add_child(rim)
	get_viewport().msaa_3d = Viewport.MSAA_2X
	_update_camera()
	if state != null:
		rebuild()


func setup(puzzle: RefCounted) -> void:
	# Switching puzzles must never let an old tween mutate the replacement state.
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
	yaw = 0.62
	pitch = 0.48
	distance = 8.0
	_update_camera()
	_fit_camera()


func rebuild() -> void:
	if _still == null or state == null:
		return
	_still.mesh = _build_mesh(-1, -1, false)
	_slice.mesh = null
	_slice.rotation = Vector3.ZERO


func animate_move(axis: int, layer: int, turns: int, commit: bool = true) -> bool:
	if is_busy() or state == null or axis < 0 or axis > 2 or layer < 0 or layer >= state.size:
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
		return # A committed snap is atomic and finishes even if a dialog opens.
	if _turn_axis >= 0:
		_turn_axis = -1
		_turn_layer = -1
		_angle = 0.0
		rebuild()
		gesture_cancelled.emit()


func _update_camera() -> void:
	if camera == null:
		return
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	camera.position = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(global_position, Vector3.UP)
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
	var center := target.get_center()
	# Fit projected corners, including perspective, into the actual UI play area.
	for iteration in range(3):
		var ratio := 0.0
		for x in [-CUBE_HALF, CUBE_HALF]:
			for y in [-CUBE_HALF, CUBE_HALF]:
				for z in [-CUBE_HALF, CUBE_HALF]:
					var delta := camera.unproject_position(to_global(Vector3(x,y,z))) - center
					ratio = maxf(ratio, maxf(absf(delta.x) / (target.size.x * 0.5), absf(delta.y) / (target.size.y * 0.5)))
		distance = maxf(5.0, distance * ratio * 1.01)
		_update_camera()
	_framing_distance = distance


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_drag()


func _inside(point: Vector2) -> bool:
	return interaction_rect.has_point(point) if interaction_rect.size.x > 0.0 else get_viewport().get_visible_rect().has_point(point)


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
		pitch = clampf(pitch + delta.y * 0.008, -1.16, 1.16)
		_update_camera()
	elif _turn_axis < 0 and displacement.length() >= 7.0:
		_choose_slice(displacement)
	if _turn_axis >= 0:
		_velocity = lerpf(_velocity, delta.dot(_screen_tangent) / elapsed, 0.65)
		_angle = clampf(displacement.dot(_screen_tangent) / _pixels_per_radian, -TAU, TAU)
		_slice.rotation = AXES[_turn_axis] * _angle
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
	var turns := roundi(_angle / (PI * 0.5))
	# A deliberate fast flick may complete a quarter turn; stationary release cannot.
	if turns == 0 and absf(_angle) > 0.18 and absf(_velocity) > 650.0 and Time.get_ticks_msec() - _last_motion_time < 90:
		turns = 1 if _angle > 0.0 else -1
	_snap_to(turns, true)


func _pick(point: Vector2) -> Dictionary:
	var origin := to_local(camera.project_ray_origin(point))
	var direction := global_transform.basis.inverse() * camera.project_ray_normal(point)
	var enter := -INF
	var leave := INF
	var normal := Vector3.ZERO
	for axis in range(3):
		if absf(direction[axis]) < 0.00001:
			if absf(origin[axis]) > CUBE_HALF:
				return {}
			continue
		var first := (-CUBE_HALF - origin[axis]) / direction[axis]
		var second := (CUBE_HALF - origin[axis]) / direction[axis]
		var entry_normal := -1.0
		if first > second:
			var swap := first
			first = second
			second = swap
			entry_normal = 1.0
		if first > enter:
			enter = first
			normal = Vector3.ZERO
			normal[axis] = entry_normal
		leave = minf(leave, second)
		if leave < maxf(enter, 0.0):
			return {}
	if enter < 0.0:
		return {}
	var hit_point := origin + direction * enter
	var cell := CUBE_HALF * 2.0 / float(state.size)
	var coordinates := Vector3i.ZERO
	for axis in range(3):
		coordinates[axis] = clampi(int(floor((hit_point[axis] + CUBE_HALF) / cell)), 0, state.size - 1)
	return {"point": hit_point, "normal": normal, "coordinates": coordinates}


func _choose_slice(displacement: Vector2) -> void:
	var hit_point: Vector3 = _hit.point
	var face_normal: Vector3 = _hit.normal
	var origin_screen := camera.unproject_position(to_global(hit_point))
	var best := -1.0
	var chosen := -1
	for axis in range(3):
		if absf(AXES[axis].dot(face_normal)) > 0.5:
			continue
		var velocity: Vector3 = AXES[axis].cross(hit_point)
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
		_begin_slice(chosen, _hit.coordinates[chosen])


func _begin_slice(axis: int, layer: int) -> void:
	_turn_axis = axis
	_turn_layer = layer
	_angle = 0.0
	_still.mesh = _build_mesh(axis, layer, false)
	_slice.mesh = _build_mesh(axis, layer, true)
	_slice.material_override = _highlight_material
	_slice.rotation = Vector3.ZERO
	move_started.emit()


func _snap_to(turns: int, commit: bool) -> void:
	_busy = true
	var target := float(turns) * PI * 0.5
	var axis := _turn_axis
	var layer := _turn_layer
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(value: float):
		_angle = value
		_slice.rotation = AXES[axis] * value,
		_angle, target, clampf(absf(target - _angle) * 0.13, 0.09, 0.25))
	_tween.tween_callback(func():
		if _history_action == -1:
			state.undo()
		elif _history_action == 1:
			state.redo()
		elif commit and turns % 4 != 0:
			state.apply_move(axis, layer, turns)
		_history_action = 0
		_turn_axis = -1
		_turn_layer = -1
		_angle = 0.0
		_busy = false
		rebuild()
		if turns % 4 != 0:
			move_completed.emit(axis, layer, turns)
		else:
			gesture_cancelled.emit())


func _build_mesh(axis: int, layer: int, selected: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var cell := CUBE_HALF * 2.0 / float(state.size)
	var center := float(state.size - 1) * 0.5
	var body_color := Color("171e30")
	for x in range(state.size):
		for y in range(state.size):
			for z in range(state.size):
				if x > 0 and x < state.size - 1 and y > 0 and y < state.size - 1 and z > 0 and z < state.size - 1:
					continue
				var p := Vector3i(x, y, z)
				var on_slice: bool = axis >= 0 and p[axis] == layer
				if on_slice != selected:
					continue
				var position := (Vector3(p) - Vector3.ONE * center) * cell
				for face in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
					_add_body_face(vertices, normals, colors, indices, position + face * cell * 0.475, face, cell * 0.475, body_color)
	for sticker in state.stickers:
		var p: Vector3i = sticker.p
		var on_slice: bool = axis >= 0 and p[axis] == layer
		if on_slice != selected:
			continue
		var normal := Vector3(sticker.n)
		var position := (Vector3(p) - Vector3.ONE * center) * cell + normal * cell * 0.481
		var color: Color = PALETTE[clampi(sticker.c, 0, 5)]
		_add_rounded_face(vertices, normals, colors, indices, position, normal, cell * 0.415, cell * 0.065, color)
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


func _add_body_face(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, center: Vector3, normal: Vector3, half_size: float, color: Color) -> void:
	var tangent := Vector3.RIGHT if absf(normal.x) < 0.5 else Vector3.BACK
	var bitangent := normal.cross(tangent)
	var base := vertices.size()
	for point in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
		vertices.append(center + (tangent * point.x + bitangent * point.y) * half_size)
		normals.append(normal)
		colors.append(color)
	for index in [0, 2, 1, 0, 3, 2]:
		indices.append(base + index)


func _add_rounded_face(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, center: Vector3, normal: Vector3, half_size: float, radius: float, color: Color) -> void:
	var tangent := Vector3.RIGHT if absf(normal.x) < 0.5 else Vector3.BACK
	var bitangent := normal.cross(tangent)
	var base := vertices.size()
	vertices.append(center)
	normals.append(normal)
	colors.append(color)
	# A small bevel in the colors catches light without textures or extra nodes.
	var ring: Array[Vector2] = []
	for corner in range(4):
		var theta := float(corner) * PI * 0.5
		var corner_center := Vector2(cos(theta + PI * 0.25), sin(theta + PI * 0.25)).sign() * (half_size - radius)
		for step in range(4):
			var angle := theta + float(step) * PI / 6.0
			ring.append(corner_center + Vector2(cos(angle), sin(angle)) * radius)
	for point in ring:
		vertices.append(center + tangent * point.x + bitangent * point.y)
		normals.append(normal)
		colors.append(color)
	for index in range(ring.size()):
		indices.append(base)
		indices.append(base + 1 + (index + 1) % ring.size())
		indices.append(base + 1 + index)
