class_name PyraminxMinimap
extends Control
## Four true triangular faces, including the hidden underside, at commit time.

signal face_selected(face: int)

const Puzzle = preload("res://scripts/puzzles/pyraminx_state.gd")
const DEFAULT_PALETTE := [Color("f7cd61"), Color("f47f94"), Color("779df4"), Color("67dfbc")]
const LABELS := ["아래 · 노랑", "오른쪽 · 분홍", "왼쪽 · 파랑", "앞 · 민트"]

var state: RefCounted
var palette: Array = DEFAULT_PALETTE.duplicate()
var turning := false
var show_caption := true
var target_face := -1
var _face_triangles: Array = [[], [], [], []]
var _face_colors: Array = [[], [], [], []]
var _hit_rects: Array[Rect2] = []
var _triangle_rects: Array[Rect2] = []
var _last_touch_position := Vector2(-999, -999)
var _last_touch_ms := -1000


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(180, 100)
	resized.connect(queue_redraw)
	queue_redraw()


func set_state(puzzle: RefCounted) -> void:
	state = puzzle
	refresh()


func set_palette(colors: Array) -> void:
	if colors.size() != 4: return
	for color in colors:
		if not color is Color: return
	palette = colors.duplicate()
	queue_redraw()


func set_turning(value: bool) -> void:
	turning = value
	queue_redraw()


func set_target(face: int) -> void:
	target_face = face if face >= 0 and face < 4 else -1
	queue_redraw()


func refresh() -> void:
	_face_triangles = [[], [], [], []]
	_face_colors = [[], [], [], []]
	if state == null:
		queue_redraw()
		return
	var slots: Array = state.get_slots()
	var colors_by_slot: Dictionary = {}
	for sticker in state.stickers:
		colors_by_slot[int(sticker.slot)] = int(sticker.c)
	for slot_index in range(slots.size()):
		var slot: Dictionary = slots[slot_index]
		var face: int = int(slot.face)
		var triangle: Array = []
		for vertex in slot.vertices:
			triangle.append(_project_face_point(vertex, face))
		_face_triangles[face].append(triangle)
		_face_colors[face].append(int(colors_by_slot.get(slot_index, -1)))
	queue_redraw()


func get_face_colors(face: int) -> Array:
	return _face_colors[face].duplicate() if face >= 0 and face < 4 else []


static func _project_face_point(point: Vector3, face: int) -> Vector2:
	var normal: Vector3 = -Puzzle.VERTICES[face].normalized()
	var up := Vector3.UP - normal * normal.dot(Vector3.UP)
	if up.length_squared() < 0.01: up = Vector3.BACK
	up = up.normalized()
	var right := up.cross(normal).normalized()
	return Vector2(point.dot(right), -point.dot(up))


func _layout() -> void:
	_hit_rects.clear()
	_triangle_rects.clear()
	var caption_height := 17.0 if show_caption else 0.0
	var row_height := maxf(30.0, (size.y - caption_height) * 0.5)
	var column_width := size.x * 0.5
	for face in range(4):
		var cell := Rect2(Vector2((face % 2) * column_width, caption_height + (face / 2) * row_height), Vector2(column_width, row_height))
		_hit_rects.append(cell)
		var height := maxf(14.0, row_height - 17.0)
		var width := minf(column_width - 10.0, height * 2.0 / sqrt(3.0))
		height = width * sqrt(3.0) * 0.5
		_triangle_rects.append(Rect2(cell.position + Vector2((cell.size.x - width) * 0.5, 1), Vector2(width, height)))


func _face_projection_bounds(face: int) -> Rect2:
	var first := true
	var bounds := Rect2()
	for axis in range(4):
		if axis == face: continue
		var point := _project_face_point(Puzzle.VERTICES[axis], face)
		if first:
			bounds = Rect2(point, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(point)
	return bounds


func _draw() -> void:
	_layout()
	var font := get_theme_default_font()
	if show_caption:
		var text := "회전 중 · 확정된 네 면" if turning else "피라밍크스 네 면 · 눌러 시점 이동"
		draw_string(font, Vector2(0,12), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color("9aabc3"))
	for face in range(4):
		var rect := _triangle_rects[face]
		var projection_bounds := _face_projection_bounds(face)
		for index in range(_face_triangles[face].size()):
			var points := PackedVector2Array()
			var triangle: Array = _face_triangles[face][index]
			var center := Vector2.ZERO
			for vertex in triangle:
				center += vertex
			center /= 3.0
			for vertex in triangle:
				# A fine dark gap preserves the nine physical stickers on each face.
				var shrunk: Vector2 = center + (vertex - center) * 0.93
				points.append(rect.position + (shrunk - projection_bounds.position) / projection_bounds.size * rect.size)
			var color_index: int = int(_face_colors[face][index])
			var color: Color = palette[color_index] if color_index >= 0 and color_index < 4 else Color("253249")
			draw_colored_polygon(points, color)
		var outline := PackedVector2Array()
		for axis in range(4):
			if axis == face: continue
			var point := _project_face_point(Puzzle.VERTICES[axis], face)
			outline.append(rect.position + (point - projection_bounds.position) / projection_bounds.size * rect.size)
		outline.append(outline[0])
		draw_polyline(outline, Color("73f6c4") if face == target_face else Color("34465d"), 2.0 if face == target_face else 1.0, true)
		draw_string(font, Vector2(_hit_rects[face].position.x, rect.end.y + 12), LABELS[face], HORIZONTAL_ALIGNMENT_CENTER, _hit_rects[face].size.x, 10, Color("c5d2e7"))


func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		point = event.position
		_last_touch_position = point
		_last_touch_ms = Time.get_ticks_msec()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
		# Synthetic mouse may arrive before raw touch; only ScreenTouch owns it.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			accept_event()
			return
	else:
		return
	_layout()
	for face in range(_hit_rects.size()):
		if _hit_rects[face].has_point(point):
			face_selected.emit(face)
			accept_event()
			return
