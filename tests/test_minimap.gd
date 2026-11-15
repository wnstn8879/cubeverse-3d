extends SceneTree
const State = preload("res://scripts/core/cube_state.gd")
const Map = preload("res://scripts/view/cube_minimap.gd")
const View = preload("res://scripts/view/cube_view.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _run() -> void:
	var map = Map.new()
	root.add_child(map)
	map.size = Vector2(288, 140)
	check(map.size == Vector2(288,140), "compact map fits intended mobile area")
	for n in range(2,11):
		var state = State.new(n)
		map.set_state(state)
		for normal in State.FACE_NORMALS:
			var colors = map.get_face_colors(normal)
			check(colors.size() == n*n, "all face slots size%d" % n)
			check(colors.count(State.FACE_NORMALS.find(normal)) == n*n, "solved face color size%d" % n)
		var before = map.get_face_colors(Vector3i.BACK)
		state.apply_move(0, n-1, 1)
		check(map.get_face_colors(Vector3i.BACK) == before, "snapshot stable before committed refresh")
		map.set_turning(true)
		check(map.get_face_colors(Vector3i.BACK) == before, "preview label never mutates face map")
		map.refresh()
		check(map.get_face_colors(Vector3i.BACK) != before, "committed refresh shows new stickers")
		var counts = [0,0,0,0,0,0]
		for normal in State.FACE_NORMALS:
			for color in map.get_face_colors(normal): counts[color] += 1
		for count in counts: check(count == n*n, "net preserves global color count")
		# Independent boundary assertions: adjacent unfolded edges share positions.
		for x in range(n):
			check(Map.face_coordinate(Vector3i(x,n-1,n-1),Vector3i.UP,n)==Vector2i(x,n-1), "U south matches F north")
			check(Map.face_coordinate(Vector3i(x,0,n-1),Vector3i.DOWN,n)==Vector2i(x,0), "D north matches F south")
		for y in range(n):
			check(Map.face_coordinate(Vector3i(0,y,n-1),Vector3i.LEFT,n)==Vector2i(n-1,n-1-y), "L east matches F west")
			check(Map.face_coordinate(Vector3i(n-1,y,n-1),Vector3i.RIGHT,n)==Vector2i(0,n-1-y), "R west matches F east")
			check(Map.face_coordinate(Vector3i(n-1,y,0),Vector3i.FORWARD,n)==Vector2i(0,n-1-y), "B west matches R east")
		# Distinct synthetic marker per physical slot catches mirroring/transposition.
		for sticker in state.stickers:
			sticker.c = sticker.p.x*100 + sticker.p.y*10 + sticker.p.z
		map.refresh()
		check(map.get_face_colors(Vector3i.RIGHT)[0] == (n-1)*100+(n-1)*10+(n-1), "R top-left points toward F")
		check(map.get_face_colors(Vector3i.FORWARD)[0] == (n-1)*100+(n-1)*10, "B top-left physical orientation")
	map._layout_faces()
	check(map._face_rects.size()==6, "all six visible hit regions")
	var selected: Array = []
	map.face_selected.connect(func(normal): selected.append(normal))
	for i in range(6):
		var event = InputEventMouseButton.new()
		event.pressed=true
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=map._face_rects[i].get_center()
		map._gui_input(event)
		check(selected.back()==Map.NORMALS[i], "whole face taps select correct face")
	var count_before=selected.size()
	var touch=InputEventScreenTouch.new()
	touch.pressed=true
	touch.position=map._face_rects[0].get_center()
	map._gui_input(touch)
	var emulated=InputEventMouseButton.new()
	emulated.pressed=true
	emulated.button_index=MOUSE_BUTTON_LEFT
	emulated.device=InputEvent.DEVICE_ID_EMULATION
	emulated.position=touch.position
	map._gui_input(emulated)
	check(selected.size()==count_before+1, "touch emulated mouse does not select twice")
	map.set_target(Vector3i.FORWARD)
	check(map.target_normal==Vector3i.FORWARD,"tutorial target outline")
	var view=View.new()
	root.add_child(view)
	var state=State.new(3)
	view.setup(state)
	view.set_interaction_rect(Rect2(0,215,540,330))
	var key=state.state_key()
	var classic_vertices=view._still.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	for id in ["classic","three_color","pillow","crystal","neon"]:
		check(view.set_variant(id), "variant accepted "+id)
		check(state.state_key()==key,"variant keeps puzzle state "+id)
		check(view.get_palette().size()==6,"variant six face mapping "+id)
		if id=="three_color":
			var palette=view.get_palette()
			check(palette[0]==palette[1] and palette[2]==palette[3] and palette[4]==palette[5],"three visible color pairs")
		if id in ["pillow","crystal"]:
			var vertices: PackedVector3Array=view._still.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var extent=0.0
			for point in vertices:
				extent=maxf(extent,maxf(absf(point.x),maxf(absf(point.y),absf(point.z))))
			check(extent>1.55,"raised physical shape "+id)
			check(vertices.size()>classic_vertices,"different geometry topology "+id)
	check(not view.set_variant("unimplemented_mirror"),"unsupported variant rejected")
	for normal in State.FACE_NORMALS:
		check(view.set_face_camera(normal),"face camera accepts axis")
		check(view.camera.position.normalized().dot(Vector3(normal))>0.97,"face camera looks at selected side")
	view.set_input_exclusion_rects([Rect2(200,400,100,100)])
	check(not view._inside(Vector2(230,450)),"minimap overlay never starts cube drag")
	view.queue_free()
	map.queue_free()
	await process_frame
	for failure in failures: printerr("MINIMAP_FAILURE ",failure)
	print("MINIMAP_VARIANT_RESULT checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
