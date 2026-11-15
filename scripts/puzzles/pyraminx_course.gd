class_name PyraminxCourse
extends RefCounted
## A verified prepared example, with real Pyraminx piece/axis predicates.
## This is a guided first solve, not an arbitrary-state solving algorithm.

const Puzzle = preload("res://scripts/puzzles/pyraminx_state.gd")
const SCOPE := "prepared_beginner_course"
const AXIS_NAMES := ["U", "L", "R", "B"]
const AXIS_KOREAN := ["위", "왼쪽", "오른쪽", "뒤"]


func get_steps(_n: int = 3) -> Array:
	return [
		{
			"id":"pieces", "title":"피라밍크스는 이렇게 생겼어요", "goal":"팁·중앙·엣지 조각을 구분합니다.",
			"explanation":"피라밍크스는 면이 네 개인 삼각뿔 퍼즐입니다. 작은 꼭짓점 네 개를 팁이라고 해요. 팁을 돌리면 그 꼭짓점에 모인 세 면의 작은 삼각형이 한 칸씩 함께 움직입니다. 팁 바로 안쪽의 중앙 조각은 그 꼭짓점의 큰 층과 함께 움직이고, 두 색을 가진 조각은 두 면 사이의 엣지입니다. 큐브와 달리 한 번에 90도가 아니라 120도씩 돌아갑니다.",
			"tip":"화면 배경을 끌면 뒤쪽도 볼 수 있습니다. 먼저 작은 팁과 그 아래 큰 층의 경계를 찾아보세요.",
			"algorithm":"", "look_for":"작은 삼각형 팁 네 개와 두 색을 가진 엣지 여섯 개를 찾아보세요.",
		},
		{
			"id":"notation", "title":"작은 글자와 큰 글자의 차이", "goal":"팁과 큰 층을 구분해 한 동작씩 돌립니다.",
			"explanation":"U는 위, L은 왼쪽, R은 오른쪽, B는 뒤 꼭짓점의 큰 층입니다. 작은 글자 u·l·r·b는 그 꼭짓점의 작은 팁만 뜻합니다. 글자만 있으면 해당 꼭짓점 끝에서 퍼즐 안쪽을 보았을 때 시계 방향 120도, '가 붙으면 반시계 방향 120도입니다. 한 바퀴는 세 번의 회전입니다.",
			"tip":"처음부터 공식을 외우지 않아도 됩니다. ‘한 동작 보기’로 어느 조각이 도는지 먼저 보고 따라 하세요.",
			"algorithm":"", "look_for":"예: r은 오른쪽 작은 팁만, R은 오른쪽 꼭짓점 아래 큰 층을 돌립니다.",
		},
		{
			"id":"tips", "title":"1. 작은 팁의 색 맞추기", "goal":"각 팁의 세 색을 바로 안쪽 중앙 조각과 잇습니다.",
			"explanation":"팁 하나의 작은 삼각형 색과 바로 안쪽의 중앙 삼각형 색을 비교하세요. 세 면에서 색이 이어지도록 작은 팁만 한 번씩 돌립니다. 이 연습에서는 위·왼쪽·오른쪽·뒤 팁을 차례로 맞춥니다. 다른 팁을 맞추어도 이미 맞춘 팁은 흐트러지지 않습니다.",
			"tip":"전체 면의 색을 맞추려 하지 말고 팁과 바로 안쪽 조각 사이의 색 연결만 봅니다. 큰 층을 돌리면 팁과 중앙 조각은 함께 움직이므로 둘의 색 연결이 유지됩니다.",
			"algorithm":"u l' r b'", "look_for":"팁 하나를 세 방향에서 보아 작은 삼각형과 안쪽 삼각형이 같은 색인지 확인하세요.",
		},
		{
			"id":"centers", "title":"2. 네 면의 중앙 색 정리", "goal":"각 면의 중앙 삼각형 세 개를 같은 색으로 모읍니다.",
			"explanation":"이제 작은 팁 대신 꼭짓점 아래의 큰 층을 봅니다. 한 면의 중앙 삼각형 세 개가 같은 색을 보도록 큰 층을 맞춥니다. 이 준비된 예제는 왼쪽 큰 층을 시계 방향 120도 돌리면 네 면의 중앙 색이 정리됩니다. 팁과 중앙의 색 연결도 그대로 유지됩니다.",
			"tip":"지금은 두 색 엣지가 모두 맞지 않아도 괜찮습니다. 중앙 조각과 작은 팁이 이어져 있는지부터 확인합니다.",
			"algorithm":"L", "look_for":"각 면에서 팁 바로 안쪽의 중앙 삼각형 세 개가 모두 같은 색인지 확인하세요.",
		},
		{
			"id":"finish", "title":"3. 엣지를 옮겨 네 면 완성", "goal":"중앙과 팁을 복원하며 엣지를 올바른 자리에 넣습니다.",
			"explanation":"두 색 엣지는 그 두 색의 면 사이에 있어야 합니다. 이 예제는 오른쪽과 위 큰 층을 이용하는 R U R' U' 네 동작으로 남은 엣지가 정리되는 배치입니다. 공식 중간에는 중앙과 팁이 움직여도 네 동작을 끝내면 돌아옵니다. 마지막에 앞·뒤·밑을 둘러보며 네 면이 각각 한 색인지 확인하세요.",
			"tip":"이 네 동작은 현재 수업에서 준비한 엣지 배치에 맞습니다. 임의로 섞은 모든 피라밍크스가 같은 공식 한 번으로 풀리는 것은 아닙니다.",
			"algorithm":"R U R' U'", "look_for":"두 색 엣지의 양쪽 색이 각각 중앙 색과 같고, 네 면 전체가 한 색인지 봅니다.",
		},
	]


func make_course(_n: int = 3) -> Dictionary:
	var steps := get_steps()
	var puzzle = Puzzle.new()
	# Prepare one exact edge case, then center and tip cases. These are deliberate
	# method checkpoints, independent from a player's free-play scramble history.
	var edges := parse_algorithm("R U R' U'")
	for index in range(edges.size() - 1, -1, -1):
		var move: Dictionary = edges[index]
		puzzle.apply_move(move.axis, move.layer, -move.turns)
	puzzle.apply_move(1, 1, 1)
	for move in parse_algorithm("u' l r' b"):
		puzzle.apply_move(move.axis, move.layer, move.turns)
	var initial: Dictionary = puzzle.to_dict()
	var stages: Array = []
	var verified := true
	for index in range(steps.size()):
		var stage: Dictionary = steps[index].duplicate(true)
		stage["moves"] = parse_algorithm(stage.algorithm)
		stage["before"] = puzzle.to_dict()
		stage["move_notes"] = []
		for move_index in range(stage.moves.size()):
			var move: Dictionary = stage.moves[move_index]
			stage.move_notes.append(notation(move) + "\n" + _move_note(stage.id, move_index))
			puzzle.apply_move(move.axis, move.layer, move.turns)
		stage["after"] = puzzle.to_dict()
		stage["checkpoint_key"] = puzzle.state_key()
		stage["verified"] = stage_complete(puzzle, index)
		verified = verified and stage.verified
		stages.append(stage)
	var starting = Puzzle.new()
	verified = verified and starting.from_dict(initial) and puzzle.is_solved()
	return {
		"state":starting, "stages":stages, "verified":verified, "scope":SCOPE,
		"size":3, "puzzle":"pyraminx", "title":"피라밍크스 처음부터 완성까지",
		"orientation":"위 U · 왼쪽 L · 오른쪽 R · 뒤 B 꼭짓점",
		"scope_note":"팁·중앙·엣지를 차례로 맞추는 준비된 전체 풀이 예제입니다. 자유 플레이의 임의 상태를 자동으로 푸는 기능은 아닙니다.",
	}


func stage_complete(puzzle: RefCounted, index: int, _n: int = 3) -> bool:
	if puzzle == null or index < 0 or index >= get_steps().size(): return false
	match get_steps()[index].id:
		"pieces", "notation": return true
		"tips": return tips_aligned(puzzle)
		"centers": return tips_aligned(puzzle) and centers_aligned(puzzle)
		"finish": return puzzle.is_solved()
	return false


func tips_aligned(puzzle: RefCounted) -> bool:
	var slots: Array = puzzle.get_slots()
	var tips := {}
	var centers := {}
	for sticker in puzzle.stickers:
		var slot: Dictionary = slots[int(sticker.slot)]
		var weights: Array = slot.b
		var maximum: int = weights.max()
		if maximum != 7 and maximum != 5: continue
		var axis: int = weights.find(maximum)
		var key := "%d:%d" % [axis, int(sticker.face)]
		if maximum == 7: tips[key] = int(sticker.c)
		else: centers[key] = int(sticker.c)
	if tips.size() != 12 or centers.size() != 12: return false
	for key in tips:
		if tips[key] != centers.get(key, -1): return false
	return true


func centers_aligned(puzzle: RefCounted) -> bool:
	var slots: Array = puzzle.get_slots()
	var colors := {}
	var count := 0
	for sticker in puzzle.stickers:
		if slots[int(sticker.slot)].b.max() != 5: continue
		var face: int = sticker.face
		if colors.has(face) and colors[face] != sticker.c: return false
		colors[face] = sticker.c
		count += 1
	return colors.size() == 4 and count == 12


func parse_algorithm(algorithm: String, _n: int = 3) -> Array:
	var result: Array = []
	for token in algorithm.split(" ", false):
		var letter := token.substr(0, 1)
		var axis := AXIS_NAMES.find(letter.to_upper())
		if axis < 0 or not token in [letter, letter + "'"]: return []
		result.append({"axis":axis, "layer":0 if letter == letter.to_lower() else 1, "turns":1 if token.ends_with("'") else -1})
	return result


func notation(move: Dictionary, _n: int = 3) -> String:
	if not move.has_all(["axis", "layer", "turns"]): return "잘못된 회전 정보"
	var axis := int(move.axis)
	var layer := int(move.layer)
	if axis < 0 or axis > 3 or not layer in [0, 1] or posmod(int(move.turns), 3) == 0: return "잘못된 회전 정보"
	var letter: String = AXIS_NAMES[axis].to_lower() if layer == 0 else AXIS_NAMES[axis]
	var counterclockwise := posmod(int(move.turns), 3) == 1
	return "%s%s · %s 꼭짓점의 %s을 %s 방향으로 120도 돌리세요" % [letter, "'" if counterclockwise else "", AXIS_KOREAN[axis], "작은 팁" if layer == 0 else "큰 층", "반시계" if counterclockwise else "시계"]


func face_normal(move: Dictionary, _n: int = 3) -> Vector3:
	return Puzzle.axis_direction(int(move.get("axis", 0)))


func _move_note(stage_id: String, index: int) -> String:
	match stage_id:
		"tips": return ["위 팁을 중앙 색과 이어요.", "왼쪽 팁을 중앙 색과 이어요.", "오른쪽 팁을 중앙 색과 이어요.", "뒤 팁까지 맞춘 뒤 네 꼭짓점을 확인해요."][index]
		"centers": return "왼쪽 큰 층을 돌린 뒤 각 면의 중앙 색이 모였는지 확인해요."
		"finish": return ["오른쪽 큰 층을 열어 엣지가 이동할 길을 만듭니다.", "위 큰 층을 돌려 다음 엣지를 옮깁니다.", "오른쪽 층을 되돌려 중앙과 팁을 복원할 준비를 합니다.", "위 층까지 되돌리면 엣지가 제자리에 들어갑니다. 네 면을 모두 확인하세요."][index]
	return "한 동작씩 보고 조각이 움직이는 모습을 따라가세요."
