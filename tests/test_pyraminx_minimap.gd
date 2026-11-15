extends SceneTree
const Puzzle = preload("res://scripts/puzzles/pyraminx_state.gd")
const Map = preload("res://scripts/view/pyraminx_minimap.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _run() -> void:
	var state=Puzzle.new()
	var map=Map.new()
	root.add_child(map)
	map.size=Vector2(255,110)
	map.set_state(state)
	check(map.size==Vector2(255,110),"fits tutorial mini area")
	for face in range(4):
		check(map.get_face_colors(face).size()==9,"nine physical stickers per tetrahedral face")
		check(map.get_face_colors(face).count(face)==9,"solved color face%d"%face)
		check(map._face_triangles[face].size()==9,"nine triangular polygons face%d"%face)
		var bounds=map._face_projection_bounds(face)
		check(bounds.size.x>0 and bounds.size.y>0,"projection has area")
		for triangle in map._face_triangles[face]:
			check(triangle.size()==3,"each sticker has three corners")
			var area=absf((triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]))
			check(area>0.0001,"triangle not degenerate")
	var old: Array=[]
	for face in range(4):old.append(map.get_face_colors(face))
	state.apply_move(0,1,1)
	map.set_turning(true)
	for face in range(4):check(map.get_face_colors(face)==old[face],"preview keeps committed face snapshot")
	map.refresh()
	var changed=false
	var color_count=[0,0,0,0]
	for face in range(4):
		if map.get_face_colors(face)!=old[face]:changed=true
		for color in map.get_face_colors(face):color_count[color]+=1
	check(changed,"committed refresh updates tetrahedral faces")
	for count in color_count:check(count==9,"snapshot preserves total sticker color")
	var slots=state.get_slots()
	var offset=[0,0,0,0]
	for slot_index in range(slots.size()):
		var face=int(slots[slot_index].face)
		check(map.get_face_colors(face)[offset[face]]==state.face_color_at_slot(slot_index),"snapshot color follows exact moved physical slot")
		offset[face]+=1
	map._layout()
	var selected: Array=[]
	map.face_selected.connect(func(face):selected.append(face))
	for face in range(4):
		check(map._hit_rects[face].size.x>=44 and map._hit_rects[face].size.y>=44,"whole face touch cell remains large")
		var touch=InputEventScreenTouch.new()
		touch.pressed=true
		touch.position=map._hit_rects[face].get_center()
		map._gui_input(touch)
		check(selected.back()==face,"face tap emits matching index")
		var count=selected.size()
		var mouse=InputEventMouseButton.new()
		mouse.pressed=true
		mouse.button_index=MOUSE_BUTTON_LEFT
		mouse.device=InputEvent.DEVICE_ID_EMULATION
		mouse.position=touch.position
		map._gui_input(mouse)
		check(selected.size()==count,"emulated mouse does not duplicate touch")
	map.set_target(2)
	check(map.target_face==2,"target face can be highlighted")
	map.set_target(8)
	check(map.target_face==-1,"invalid target cleared")
	map.queue_free()
	await process_frame
	for failure in failures:printerr("PYRAMINX_MINIMAP_FAILURE ",failure)
	print("PYRAMINX_MINIMAP_RESULT checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
