extends SceneTree
const View = preload("res://scripts/view/cube_view.gd")
const State = preload("res://scripts/core/cube_state.gd")
func _initialize():
	call_deferred("run")
func run():
	root.size = Vector2i(540,960)
	var v = View.new()
	root.add_child(v)
	var checks = 0
	for size in [3,10]:
		var s = State.new(size)
		v.setup(s)
		v.set_interaction_rect(Rect2(0,215,540,450))
		for yaw in [-3.0,-2.0,-1.0,0.0,0.6,1.5,2.5,3.1]:
			for pitch in [-0.8,0.0,0.8]:
				v.yaw = yaw
				v.pitch = pitch
				v._update_camera()
				v._fit_camera()
				var face = v.camera.position.abs().max_axis_index()
				var p = Vector3(0.23,0.14,0.17)
				p[face] = 1.5 if v.camera.position[face] > 0 else -1.5
				var point = v.camera.unproject_position(p)
				assert(not v._pick(point).is_empty())
				for axis in range(3):
					if axis == face: continue
					var velocity = v.AXES[axis].cross(p)
					var projected = v.camera.unproject_position(p+velocity*0.05)-point
					var delta = projected.normalized()*70
					v._pointer_down(0,point)
					v._pointer_move(0,point+delta)
					assert(v._turn_axis == axis, "drag axis mismatch")
					assert(v._angle > 0, "drag sign mismatch")
					v.cancel_drag()
					assert(s.is_solved())
					checks += 1
	print("VIEW_CAMERA_DRAG_PASS checks=",checks)
	quit()
