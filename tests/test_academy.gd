extends SceneTree
## These tests verify the taught physical checkpoints, not just fixture replay.
const Academy = preload("res://scripts/academy/beginner_academy.gd")
const Cube = preload("res://scripts/core/cube_state.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)


func _run() -> void:
	var academy = Academy.new()
	_check(academy.get_steps(4).is_empty(),"unsupported puzzle has no fake lesson")
	_check(not academy.make_course(4).verified,"unsupported course rejects")
	for n in [2,3]:
		var course: Dictionary = academy.make_course(n)
		_check(course.verified,"%dx%d course verifies" % [n,n])
		_check(course.scope=="prepared_beginner_course","scope explicit")
		_check(not course.state.is_solved(),"course starts unsolved")
		var puzzle = course.state
		var repeat: Dictionary = academy.make_course(n)
		_check(repeat.state.state_key()==puzzle.state_key(),"course repeat is deterministic")
		_check(course.stages.size()==(9 if n==3 else 5),"all reading and solving stages present")
		_check(not academy.stage_complete(puzzle,-1,n),"negative stage rejects")
		_check(not academy.stage_complete(puzzle,999,n),"unknown stage rejects")
		for stage_index in range(course.stages.size()):
			var stage: Dictionary = course.stages[stage_index]
			_check(stage.has_all(["id","title","goal","explanation","tip","look_for","moves","move_notes","before","after","checkpoint_key"]),"stage data complete")
			_check(stage.explanation.length()>50,"meaningful explanation")
			_check(stage.tip.length()>15,"meaningful beginner tip")
			_check(stage.move_notes.size()==stage.moves.size(),"each move has human instruction")
			_check(puzzle.state_key()==_import(stage.before,n).state_key(),"stage starts at expected legal checkpoint")
			for m in stage.moves:
				_check(puzzle.apply_move(m.axis,m.layer,m.turns),"every guided turn is legal")
				_check(not academy.notation(m,n).is_empty(),"every turn has notation")
			_check(academy.stage_complete(puzzle,stage_index,n),"physical checkpoint achieved: "+stage.id)
			_check(puzzle.state_key()==stage.checkpoint_key,"checkpoint exact key matches")
			_check(puzzle.state_key()==_import(stage.after,n).state_key(),"after snapshot legal")
			# Every course checkpoint is a persistent legal state, not recolored art.
			_check(_import(puzzle.to_dict(),n).state_key()==puzzle.state_key(),"course save/load retains state")
			if stage.id=="daisy":
				_check(academy.daisy_count(puzzle)==4,"daisy has four white edge petals")
				_check(not academy.stage_complete(puzzle,stage_index+1,n),"daisy is not white cross down")
				var broken = _import(puzzle.to_dict(),n)
				broken.apply_move(0,n-1,1)
				_check(not academy.stage_complete(broken,stage_index,n),"broken petal rejects daisy")
			if stage.id=="white_cross":
				var bad_alignment = _import(puzzle.to_dict(),n)
				bad_alignment.apply_move(1,0,1)
				_check(not academy.stage_complete(bad_alignment,stage_index,n),"white cross also requires side centers aligned")
			if stage.id=="white_layer" or stage.id=="white_corners":
				var false_white = _import(puzzle.to_dict(),n)
				for sticker in false_white.stickers:
					if sticker.p.y==0 and sticker.n.x==1:
						sticker.c=1
				_check(not academy.stage_complete(false_white,stage_index,n),"white face without side colors is not first layer")
		_check(puzzle.is_solved(),"full course actually ends solved")
		_check(not course.state==repeat.state,"course instances do not alias")
	for n in [2,3]:
		for face in ["R","L","U","D","F","B"]:
			for suffix in ["","'","2"]:
				var token: String = face+suffix
				var parsed: Array = academy.parse_algorithm(token,n)
				_check(parsed.size()==1,"parse "+token)
				_check(academy.notation(parsed[0],n).begins_with(token+" ·"),"human notation roundtrip "+token)
	_check(academy.parse_algorithm("R invalid U").is_empty(),"invalid algorithm never partially executes")
	for failure in failures: printerr("ACADEMY_FAILURE: "+failure)
	print("ACADEMY_TEST_RESULT checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)


func _import(data: Dictionary, n: int) -> RefCounted:
	var puzzle = Cube.new(n)
	_check(puzzle.from_dict(data),"snapshot import validates legal moves")
	return puzzle
