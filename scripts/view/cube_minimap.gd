class_name CubeMinimap
extends Control
## An unfolded net of the last committed puzzle state. Each face can be tapped.
## Columns/rows are defined looking at each face from outside the physical cube.

signal face_selected(normal: Vector3i)

const NORMALS := [Vector3i.UP, Vector3i.LEFT, Vector3i.BACK, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.DOWN]
const CELLS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2)]
const LABELS := ["위 U", "왼쪽 L", "앞 F", "오른쪽 R", "뒤 B", "아래 D"]
const DEFAULT_PALETTE := [Color("f45b68"), Color("ff9348"), Color("f7f4e9"), Color("f6c343"), Color("54d5b5"), Color("5688f4")]

var state: RefCounted
var palette: Array = DEFAULT_PALETTE.duplicate()
var cube_size := 3
var turning := false
var show_caption := true
var compact_layout := false
var target_normal := Vector3i.ZERO
var _faces: Dictionary = {}
var _face_rects: Array[Rect2] = []
var _face_hit_rects: Array[Rect2] = []
var _last_touch_position := Vector2(-999, -999)
var _last_touch_ms := -1000


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(180, 124)
	resized.connect(queue_redraw)
	queue_redraw()


func set_state(puzzle: RefCounted) -> void:
	state = puzzle
	refresh()


func set_palette(colors: Array) -> void:
	if colors.size() != 6:
		return
	for color in colors:
		if not color is Color:
			return
	palette = colors.duplicate()
	queue_redraw()


func set_turning(value: bool) -> void:
	turning = value
	queue_redraw()


func set_target(normal: Vector3i) -> void:
	target_normal = normal if normal in NORMALS else Vector3i.ZERO
	queue_redraw()


func refresh() -> void:
	# Take a value snapshot: animation previews must not leak into this map.
	_faces.clear()
	if state == null:
		queue_redraw()
		return
	cube_size = int(state.size)
	for normal in NORMALS:
		var colors: Array = []
		colors.resize(cube_size * cube_size)
		colors.fill(-1)
		_faces[normal] = colors
	for sticker in state.stickers:
		var normal: Vector3i = sticker.n
		if not _faces.has(normal): continue
		var coordinate := face_coordinate(sticker.p, normal, cube_size)
		_faces[normal][coordinate.y * cube_size + coordinate.x] = int(sticker.c)
	queue_redraw()


func get_face_colors(normal: Vector3i) -> Array:
	return _faces.get(normal, []).duplicate()


static func face_coordinate(point: Vector3i, normal: Vector3i, n: int) -> Vector2i:
	if normal == Vector3i.BACK: return Vector2i(point.x, n - 1 - point.y)
	if normal == Vector3i.FORWARD: return Vector2i(n - 1 - point.x, n - 1 - point.y)
	if normal == Vector3i.RIGHT: return Vector2i(n - 1 - point.z, n - 1 - point.y)
	if normal == Vector3i.LEFT: return Vector2i(point.z, n - 1 - point.y)
	if normal == Vector3i.UP: return Vector2i(point.x, point.z)
	return Vector2i(point.x, n - 1 - point.z)


func _layout_faces() -> void:
	_face_rects.clear()
	_face_hit_rects.clear()
	var caption_height := 21.0 if show_caption else 0.0
	var gap := 6.0
	var label_height := 15.0
	var compact := compact_layout or size.x / maxf(1.0, size.y) > 1.6
	var columns := 3 if compact else 4
	var rows := 2 if compact else 3
	var side := maxf(15.0, minf((size.x - gap * (columns - 1)) / columns, (size.y - caption_height - label_height * rows - gap * (rows - 1)) / rows))
	var width := side * columns + gap * (columns - 1)
	var height := (side + label_height) * rows + gap * (rows - 1)
	var origin := Vector2(maxf(0, (size.x - width) / 2.0), caption_height + maxf(0, (size.y - caption_height - height) / 2.0))
	for index in range(CELLS.size()):
		var cell: Vector2i = Vector2i(index % 3, index / 3) if compact else CELLS[index]
		var point := origin + Vector2(cell.x * (side + gap), cell.y * (side + label_height + gap))
		if compact:
			var column_width := size.x / 3.0
			point.x = cell.x * column_width + (column_width - side) * 0.5
			_face_hit_rects.append(Rect2(Vector2(cell.x * column_width, point.y - 2), Vector2(column_width, side + label_height + gap)))
		else:
			_face_hit_rects.append(Rect2(point - Vector2(2,2), Vector2(side + 4, side + 17)))
		_face_rects.append(Rect2(point, Vector2(side, side)))


func _draw() -> void:
	_layout_faces()
	var font := get_theme_default_font()
	if show_caption:
		var caption := "회전 중 · 확정된 상태" if turning else "전체 면 보기 · 면을 눌러 시점 이동"
		draw_string(font, Vector2(0, 13), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color("9aabc3"))
	for face_index in range(NORMALS.size()):
		var rect := _face_rects[face_index]
		draw_style_box(_panel_style(), rect.grow(2))
		if NORMALS[face_index] == target_normal:
			draw_rect(rect.grow(3), Color("73f6c4"), false, 2.0)
		var colors: Array = _faces.get(NORMALS[face_index], [])
		var cell_size := rect.size.x / float(cube_size)
		var inset := clampf(cell_size * 0.07, 0.35, 1.5)
		for row in range(cube_size):
			for col in range(cube_size):
				var index := row * cube_size + col
				var color_index: int = int(colors[index]) if index < colors.size() else -1
				var color: Color = palette[color_index] if color_index >= 0 and color_index < palette.size() else Color("253249")
				var square := Rect2(rect.position + Vector2(col, row) * cell_size + Vector2.ONE * inset, Vector2.ONE * maxf(0.5, cell_size - inset * 2.0))
				draw_rect(square, color)
		draw_string(font, rect.position + Vector2(-4, rect.size.y + 12), LABELS[face_index], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x + 8, 10, Color("c5d2e7"))


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101827")
	style.border_color = Color("34465d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		point = event.position
		_last_touch_position = point
		_last_touch_ms = Time.get_ticks_msec()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
		# Godot can dispatch the synthetic mouse BEFORE its raw touch event.
		# Raw ScreenTouch owns touchscreen interaction in this custom control.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			accept_event()
			return
	else:
		return
	_layout_faces()
	for index in range(_face_rects.size()):
		if _face_hit_rects[index].has_point(point):
			face_selected.emit(NORMALS[index])
			accept_event()
			return
