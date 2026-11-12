extends SceneTree
const View = preload("res://scripts/view/cube_view.gd")
const State = preload("res://scripts/core/cube_state.gd")
func _initialize():
	call_deferred("run")
func run():
	root.size = Vector2i(540,960)
	var v = View.new()
	root.add_child(v)
	var s = State.new(3)
	v.setup(s)
	v.set_interaction_rect(Rect2(0,190,540,460))
	await process_frame
	var point = v.camera.unproject_position(Vector3(0.6,0.1,1.5))

	assert(not v._pick(point).is_empty())
	v._pointer_down(0,point)
	v._pointer_move(0,point+Vector2(140,0))
	assert(v.is_busy())
	assert(s.is_solved()) # preview does not mutate the logical state
	v._pointer_up(0,point+Vector2(140,0),true)
	assert(not v.is_busy())
	assert(s.is_solved())
	v._pointer_down(0,point)
	v._pointer_move(0,point+Vector2(140,0))
	v._pointer_down(1,point+Vector2(-50,0))
	assert(not v.is_busy())
	assert(s.is_solved()) # second pointer cancels uncommitted slice
	v._pointer_move(1,point+Vector2(-100,0))
	v._pointer_up(0,point,false)
	v._pointer_up(1,point,false)
	v._pointer_down(0,point)
	v._pointer_move(0,point+Vector2(140,0))
	v._pointer_up(0,point+Vector2(140,0),false)
	await create_timer(0.4).timeout
	assert(not s.is_solved())
	assert(v.request_undo())
	await create_timer(0.4).timeout
	assert(s.is_solved())
	assert(v.request_redo())
	await create_timer(0.4).timeout
	assert(not s.is_solved())
	var orbit_yaw = v.yaw
	v._pointer_down(0,Vector2(8,640))
	v._pointer_move(0,Vector2(40,630))
	v._pointer_up(0,Vector2(40,630),false)
	assert(v.yaw != orbit_yaw)
	var start = Time.get_ticks_usec()
	v.setup(State.new(10))
	print("10x10 mesh build ms=", (Time.get_ticks_usec()-start)/1000.0)
	print("VIEW_GESTURES_PASS")
	quit()
