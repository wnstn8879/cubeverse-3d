class_name BeginnerAcademy
extends RefCounted
## A complete, verified prepared example of the beginner method.
## This teaches real checkpoints; it is deliberately not an arbitrary-state solver.
## All moves use the same exact CubeState engine as free play.

const Cube = preload("res://scripts/core/cube_state.gd")
const SCOPE := "prepared_beginner_course"
const WHITE := 2
const YELLOW := 3
const NORMALS := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
const FACE_NAMES := {"R":"오른쪽", "L":"왼쪽", "U":"위", "D":"아래", "F":"앞", "B":"뒤"}


func get_steps(n: int = 3) -> Array:
	if n != 2 and n != 3:
		return []
	var intro := {
		"id":"pieces", "title":"먼저 조각을 알아봐요", "goal":"색의 자리와 조각 종류를 알아봅니다.",
		"explanation":("3×3의 가운데 한 칸은 센터입니다. 센터 색이 그 면의 완성 색을 알려 줍니다. 색이 두 개인 조각은 엣지, 세 개인 조각은 코너입니다. 한 칸의 스티커가 아니라 조각 전체가 움직입니다. 이 수업은 노란 센터가 위, 흰 센터가 아래가 되도록 준비했어요." if n == 3 else "2×2에는 센터와 엣지가 없고, 세 가지 색을 가진 코너 8개만 있습니다. 흰색 한 면만 만드는 것보다 옆면 색도 이어지게 만드는 것이 중요해요. 이 수업은 흰색을 아래쪽에 맞추는 방향으로 준비했어요."),
		"tip":"미니맵에서 위·아래·앞·뒤·왼쪽·오른쪽을 함께 보세요. 면을 누르면 그쪽을 바라볼 수 있어요.",
		"algorithm":"", "look_for":"먼저 흰색과 노란색을 찾아보세요. 아직 큐브를 돌릴 필요는 없습니다.",
	}
	var notation_step := {
		"id":"notation", "title":"회전 표시를 읽어 봐요", "goal":"한 동작씩 직접 따라 할 준비를 합니다.",
		"explanation":"R=오른쪽, L=왼쪽, U=위, D=아래, F=앞, B=뒤입니다. 글자만 있으면 그 면을 정면에서 보았을 때 시계 방향 90도, '가 붙으면 반시계 방향 90도, 2가 붙으면 180도입니다. 화면에서 큐브를 바라보는 방향을 바꾸어도 면 이름은 유지됩니다.",
		"tip":"처음에는 공식을 외우지 않아도 됩니다. ‘한 동작 보기’를 누르고 어떤 조각이 이동했는지 미니맵에서 확인하세요.",
		"algorithm":"", "look_for":"예: R2는 오른쪽 면을 반 바퀴, U'는 위 면을 반시계 방향으로 한 번 돌립니다.",
	}
	if n == 2:
		return [intro, notation_step,
			{
				"id":"white_layer", "title":"1. 흰색 한 층 만들기", "goal":"아래 흰색 4칸과 옆면 아래 줄의 색을 함께 맞춥니다.",
				"explanation":"흰색이 있는 코너를 찾으세요. 코너의 나머지 두 색이 들어갈 자리의 옆면 색과 같아야 합니다. 이 예제에서는 마지막 흰 코너가 오른쪽 위에 있어요. 오른쪽 면과 위 면을 이용해 코너를 아래 자리로 넣습니다. 흰 면만 보고 끝내지 말고 옆 색이 같은 줄인지 확인하세요.",
				"tip":"흰색이 다 보여도 옆면 아래 두 칸이 서로 다른 색이면 한 층이 완성된 것이 아닙니다. 코너가 아래에 잘못 들어갔다면 그 자리를 오른쪽 앞에 두고 R U R'로 위로 꺼낸 뒤 다시 준비합니다.",
				"algorithm":"R U R'", "look_for":"흰 코너 하나와 그 코너의 다른 두 색을 함께 따라가 보세요.",
			},
			{
				"id":"yellow_face", "title":"2. 윗면을 노란색으로", "goal":"아래 층을 유지하며 위쪽 4칸을 노란색으로 만듭니다.",
				"explanation":"흰색 한 층은 계속 아래에 둡니다. 이제 위 코너의 방향을 바꾸어 노란색이 위를 보게 만듭니다. 이 예제의 노란색 배치는 오른손 공식 R U R' U R U2 R' 한 번으로 정리됩니다. 공식 중간에 아래 층이 잠깐 흐트러져도 끝까지 진행하면 돌아옵니다.",
				"tip":"노란색 4칸이 다 위를 보아도 옆면이 아직 어긋날 수 있어요. 다음 단계에서 코너의 자리를 바꿉니다.",
				"algorithm":"R U R' U R U2 R'", "look_for":"위쪽에서 노란색을 보이는 코너의 개수를 확인하세요.",
			},
			{
				"id":"finish", "title":"3. 마지막 코너의 자리 맞추기", "goal":"모든 면의 색을 같은 색으로 맞춥니다.",
				"explanation":"노란 면의 방향은 맞았으니 코너가 어느 자리에 있어야 하는지 봅니다. 코너의 세 색이 만나는 세 면과 일치해야 합니다. 이 연습은 오른쪽 코너 둘의 교환이 필요한 상태로 준비했습니다. 안내된 교환 공식을 끝까지 따라 하면 옆면의 색 띠도 맞아집니다.",
				"tip":"이 교환 공식은 이 예제의 배치에 맞춘 것입니다. 임의의 섞인 상태를 모두 같은 공식 한 번으로 풀 수 있다는 뜻은 아닙니다.",
				"algorithm":"R U R' U' R' F R2 U' R' U' R U R' F'", "look_for":"위쪽 코너의 옆 색을 보고 아래층의 같은 색 줄과 비교하세요.",
			},
		]
	return [intro, notation_step,
		{
			"id":"daisy", "title":"1. 노란 센터 주위에 데이지", "goal":"노란 센터 둘레 엣지 4개를 흰색 꽃잎으로 만듭니다.",
			"explanation":"위쪽 노란 센터를 꽃 가운데라고 생각하세요. 흰색이 있는 엣지 조각 네 개를 찾아 노란 센터의 위·아래·왼쪽·오른쪽에 올립니다. 지금은 엣지의 다른 색을 맞출 필요가 없습니다. 코너의 흰색은 꽃잎에 포함하지 않아요. 이 예제는 꽃잎 하나가 이미 위에 있고 나머지 셋을 반 바퀴 돌려 올리는 상태입니다.",
			"tip":"위 면의 네 모서리 칸이 아니라 센터와 맞닿은 네 칸을 보세요. 그것이 엣지입니다.",
			"algorithm":"F2 R2 L2", "look_for":"미니맵 위 면의 노란 가운데와, 그 주위 흰색 엣지 4칸을 세어 보세요.",
		},
		{
			"id":"white_cross", "title":"2. 아래에 흰색 십자가", "goal":"흰 엣지를 아래로 내리고 옆 색을 센터와 맞춥니다.",
			"explanation":"데이지의 흰 엣지 하나를 고르고 그 엣지의 옆 색을 봅니다. 위 면을 돌려 옆 색이 같은 센터 위에 오게 맞춘 뒤 그 면을 180도 돌리면 흰색이 아래로 내려갑니다. 네 번 반복하면 아래 흰 십자가와 옆면의 짧은 색 띠가 맞습니다. 이 예제는 옆 색이 이미 맞아 있어 왼쪽·뒤·오른쪽·앞 면을 차례로 반 바퀴 돌립니다.",
			"tip":"아래 흰 십자가만 보지 말고 엣지의 옆 색과 바로 아래 센터 색이 같은지도 확인하세요.",
			"algorithm":"L2 B2 R2 F2", "look_for":"아래 면의 흰 십자가와 네 옆면의 센터·엣지 색 연결을 확인하세요.",
		},
		{
			"id":"white_corners", "title":"3. 흰 코너로 첫 층 채우기", "goal":"아래 면 전체와 옆면의 아래 줄을 완성합니다.",
			"explanation":"흰색이 있는 코너의 세 색을 함께 보세요. 그 세 색의 센터가 만나는 아래 자리가 코너의 집입니다. 코너를 집 바로 위로 옮긴 다음 오른쪽·위 면을 이용해 넣습니다. 이 연습은 마지막 흰 코너를 넣는 배치로 준비되어 있어 R U R' 세 동작으로 첫 층이 완성됩니다.",
			"tip":"흰 면이 다 채워져도 옆면 아래 줄이 같은 색으로 이어지지 않으면 코너 자리가 틀린 것입니다. 잘못 낀 아래 코너는 오른쪽 앞에 두고 R U R'로 위로 꺼내어 다시 준비합니다.",
			"algorithm":"R U R'", "look_for":"흰 코너의 옆 두 색이 해당 센터와 같은 면에 있는지 보세요.",
		},
		{
			"id":"middle_layer", "title":"4. 가운데 층 엣지 넣기", "goal":"흰 첫 층을 유지하며 가운데 층 네 자리를 채웁니다.",
			"explanation":"위 층에서 노란색이 없는 엣지를 찾습니다. 앞쪽 색을 같은 센터와 맞추면 다른 색이 가야 할 방향이 정해져요. 이 예제는 앞에서 오른쪽으로 들어갈 엣지이므로 오른쪽 넣기 공식을 사용합니다. 공식을 끝까지 하면 아래 첫 층이 복원되고 엣지가 가운데 오른쪽에 들어갑니다.",
			"tip":"노란색이 섞인 엣지는 가운데 층에 넣지 않습니다. 왼쪽 넣기는 U' L' U L U F U' F'입니다. 가운데에 엣지가 잘못 끼었다면 같은 넣기 공식으로 다른 엣지를 그 자리에 넣어 위로 꺼냅니다.",
			"algorithm":"U R U' R' U' F' U F", "look_for":"앞 센터와 엣지의 앞 색이 같고, 엣지의 다른 색이 오른쪽 센터 색인지 확인하세요.",
		},
		{
			"id":"yellow_cross", "title":"5. 위에 노란 십자가", "goal":"위쪽 노란 엣지 네 개의 방향을 맞춥니다.",
			"explanation":"위 면의 노란색 엣지만 봅니다. 코너는 잠깐 무시하세요. 점·ㄱ자·가로줄 모양을 거쳐 십자가를 만듭니다. 이 연습은 안내된 앞면 기준에서 F R U R' U' F' 한 번으로 십자가가 되는 배치입니다. 아직 옆 색과 엣지 자리가 모두 맞을 필요는 없습니다.",
			"tip":"흰 첫 층과 가운데 층은 그대로 유지합니다. 위 면의 센터와 엣지 네 칸만 확인하세요.",
			"algorithm":"F R U R' U' F'", "look_for":"노란 센터 주위 네 칸이 모두 노란색인지 보세요. 코너 색은 다음 단계입니다.",
		},
		{
			"id":"yellow_face", "title":"6. 노란 코너 방향 맞추기", "goal":"노란 십자가를 유지하며 윗면 전체를 노란색으로 만듭니다.",
			"explanation":"위 코너의 노란색이 어느 면을 보는지 확인합니다. 코너를 돌려 노란색이 위를 보게 하는 단계입니다. 이 예제는 R U R' U R U2 R' 공식 한 번에 맞는 배치로 준비했습니다. 모든 코너가 위를 보이면 노란 면이 완성되지만, 코너와 엣지의 옆 색 자리는 다음 단계까지 남을 수 있습니다.",
			"tip":"수업의 정해진 앞면 기준을 유지하세요. 다른 패턴에서는 공식의 준비 방향이나 반복 횟수가 달라집니다.",
			"algorithm":"R U R' U R U2 R'", "look_for":"위 면 아홉 칸이 모두 노란색이고 아래 두 층이 보존되는지 확인하세요.",
		},
		{
			"id":"finish", "title":"7. 마지막 층의 자리 맞추기", "goal":"코너와 엣지의 옆 색을 맞춰 여섯 면을 완성합니다.",
			"explanation":"위 면이 노란색이어도 옆면의 위 줄은 다를 수 있습니다. 방향이 맞은 조각을 올바른 자리로 옮겨야 합니다. 이 예제는 코너 한 쌍과 엣지 한 쌍을 교환하는 T 교환 공식에 맞춘 상태입니다. 한 동작씩 끝까지 진행한 뒤 각 면의 위 줄과 센터 색이 같은지 확인하세요.",
			"tip":"이 단계의 교환은 준비된 예제에 해당합니다. 임의 상태의 모든 마지막 층 패턴을 자동 판별하는 풀이기는 아직 아닙니다.",
			"algorithm":"R U R' U' R' F R2 U' R' U' R U R' F'", "look_for":"미니맵 여섯 면이 각각 한 가지 색으로 이어지는지 확인하세요.",
		},
	]


func make_course(n: int = 3) -> Dictionary:
	var steps := get_steps(n)
	if steps.is_empty():
		return {"verified":false, "scope":SCOPE, "error":"이 과정은 2×2와 3×3을 지원합니다."}
	var puzzle = _canonical(n)
	# Build a deliberate case for each standard beginner algorithm. This is not a
	# user's scramble trace: the course is a fixed chain of real method checkpoints.
	for index in range(steps.size() - 1, -1, -1):
		var parsed := parse_algorithm(steps[index].algorithm, n)
		for move_index in range(parsed.size() - 1, -1, -1):
			var m: Dictionary = parsed[move_index]
			puzzle.apply_move(m.axis, m.layer, -m.turns)
	var initial: Dictionary = puzzle.to_dict()
	var stages: Array = []
	var verified := true
	for index in range(steps.size()):
		var stage: Dictionary = steps[index].duplicate(true)
		stage["moves"] = parse_algorithm(stage.algorithm, n)
		stage["before"] = puzzle.to_dict()
		stage["move_notes"] = []
		for move_index in range(stage.moves.size()):
			var m: Dictionary = stage.moves[move_index]
			stage.move_notes.append(_move_note(stage.id,move_index,m,n))
			puzzle.apply_move(m.axis, m.layer, m.turns)
		stage["after"] = puzzle.to_dict()
		stage["checkpoint_key"] = puzzle.state_key()
		stage["verified"] = stage_complete(puzzle, index, n)
		verified = verified and stage.verified
		stages.append(stage)
	verified = verified and puzzle.is_solved()
	var starting = Cube.new(n)
	if not starting.from_dict(initial):
		verified = false
	return {
		"state":starting, "stages":stages, "verified":verified, "scope":SCOPE,
		"size":n, "title":"%d×%d 처음부터 완성까지" % [n,n],
		"scope_note":"단계마다 알맞은 배치로 준비한 전체 풀이 예제입니다. 자유 플레이의 임의 상태를 자동으로 푸는 기능은 아닙니다.",
		"orientation":"흰색 아래 · 노란색 위 · 파란색 앞 · 빨간색 오른쪽",
	}


func _move_note(stage_id: String, index: int, move: Dictionary, n: int) -> String:
	var purpose := "공식 중간에는 맞춘 부분이 움직일 수 있습니다. 끝까지 한 동작씩 이어 갑니다."
	match stage_id:
		"daisy":
			purpose = ["앞쪽 아래 흰 엣지를 위로 올려 앞 꽃잎을 만듭니다.","오른쪽 아래 흰 엣지를 위로 올려 오른쪽 꽃잎을 만듭니다.","왼쪽 아래 흰 엣지를 위로 올리면 흰 꽃잎 네 개가 모입니다."][index]
		"white_cross":
			purpose = ["옆 색이 왼쪽 센터와 맞는 흰 꽃잎을 아래로 내립니다.","옆 색이 뒤 센터와 맞는 흰 꽃잎을 아래로 내립니다.","옆 색이 오른쪽 센터와 맞는 흰 꽃잎을 아래로 내립니다.","마지막 앞 꽃잎을 내리면 아래 흰 십자가가 됩니다."][index]
		"white_corners", "white_layer":
			purpose = ["오른쪽 면을 올려 코너가 들어갈 통로를 엽니다.","위 면을 돌려 흰 코너를 열린 자리 앞으로 가져옵니다.","오른쪽 면을 내리며 흰 코너를 아래 집에 넣습니다."][index]
		"middle_layer":
			if index == 0: purpose="오른쪽으로 들어갈 엣지를 잠시 옆으로 피합니다."
			elif index == 3: purpose="오른쪽 면을 복원합니다. 아직 앞쪽 연결을 마저 복원해야 합니다."
			elif index == 7: purpose="앞면을 복원하면 첫 층을 유지한 채 가운데 엣지가 들어갑니다."
		"yellow_cross":
			if index==0: purpose="앞면을 열고 위 엣지의 방향을 바꿀 준비를 합니다."
			elif index==5: purpose="앞면을 닫고 위 면의 노란 엣지 네 개를 확인합니다."
		"yellow_face":
			if index==5: purpose="위 면을 반 바퀴 돌려 남은 코너를 공식이 처리할 자리로 가져옵니다."
			elif index==6: purpose="오른쪽 면을 복원한 뒤 위 면 전체가 노란색인지 확인합니다."
		"finish":
			if index==13: purpose="마지막 앞면을 복원합니다. 미니맵 여섯 면이 각각 한 색인지 확인하세요."
	return notation(move,n)+"\n"+purpose


func face_normal(move: Dictionary, n: int = 3) -> Vector3i:
	if not move.has_all(["axis","layer"]): return Vector3i.ZERO
	var axis:=int(move.axis)
	var layer:=int(move.layer)
	if axis<0 or axis>2 or (layer!=0 and layer!=n-1): return Vector3i.ZERO
	var normal:=Vector3i.ZERO
	normal[axis]=1 if layer==n-1 else -1
	return normal


func stage_complete(puzzle: RefCounted, index: int, n: int = 3) -> bool:
	var steps := get_steps(n)
	if puzzle == null or puzzle.size != n or index < 0 or index >= steps.size():
		return false
	var id: String = steps[index].id
	match id:
		"pieces", "notation":
			return true # Reading stages advance only on the user's explicit Next.
		"daisy":
			return daisy_count(puzzle) == 4 and _center_color(puzzle, Vector3i.UP) == YELLOW
		"white_cross":
			return _white_cross(puzzle)
		"white_corners", "white_layer":
			return _lower_layers_match(puzzle, 0)
		"middle_layer":
			return _lower_layers_match(puzzle, n - 2)
		"yellow_cross":
			return _lower_layers_match(puzzle, n - 2) and _yellow_cross(puzzle)
		"yellow_face":
			if not _lower_layers_match(puzzle, n - 2):
				return false
			for s in puzzle.stickers:
				if s.n == Vector3i.UP and s.c != YELLOW:
					return false
			return true
		"finish":
			return puzzle.is_solved()
	return false


func daisy_count(puzzle: RefCounted) -> int:
	if puzzle == null or puzzle.size != 3:
		return 0
	var count := 0
	for s in puzzle.stickers:
		if s.n == Vector3i.UP and s.c == WHITE and _boundary_count(s.p, puzzle.size) == 2:
			count += 1
	return count


func parse_algorithm(algorithm: String, n: int = 3) -> Array:
	var result: Array = []
	for token in algorithm.split(" ", false):
		if token.is_empty(): continue
		var face := token.substr(0, 1)
		var mapping := {"R":[0,n-1,-1],"L":[0,0,1],"U":[1,n-1,-1],"D":[1,0,1],"F":[2,n-1,-1],"B":[2,0,1]}
		if not mapping.has(face) or not token in [face,face+"'",face+"2"]:
			return []
		var definition: Array = mapping[face]
		var multiple := 2 if token.ends_with("2") else (-1 if token.ends_with("'") else 1)
		var turns: int = int(definition[2]) * multiple
		if abs(turns) == 2: turns = 2
		result.append({"axis":int(definition[0]), "layer":int(definition[1]), "turns":turns})
	return result


func notation(move: Dictionary, n: int = 3) -> String:
	if not move.has_all(["axis","layer","turns"]):
		return "잘못된 회전 정보"
	var axis := int(move.axis)
	var layer := int(move.layer)
	if axis < 0 or axis > 2 or layer < 0 or layer >= n:
		return "잘못된 회전 정보"
	if layer != 0 and layer != n-1:
		return "%s축 %d번째 층 회전" % [["X","Y","Z"][axis],layer+1]
	var face: String = [["L","R"],["D","U"],["B","F"]][axis][1 if layer==n-1 else 0]
	var base := -1 if layer==n-1 else 1
	var amount := posmod(int(move.turns)*base,4)
	if amount == 2:
		return "%s2 · %s 면을 반 바퀴 (180도)" % [face,FACE_NAMES[face]]
	if amount == 3:
		return "%s' · %s 면을 정면에서 보고 반시계 방향 90도" % [face,FACE_NAMES[face]]
	if amount == 1:
		return "%s · %s 면을 정면에서 보고 시계 방향 90도" % [face,FACE_NAMES[face]]
	return "%s · 회전하지 않음" % face


func _canonical(n: int) -> RefCounted:
	var puzzle = Cube.new(n)
	for layer in range(n):
		puzzle.apply_move(0,layer,2)
	return puzzle


func _reference_colors() -> Dictionary:
	# After rotating the whole solved cube 180 degrees around X.
	return {Vector3i.RIGHT:0,Vector3i.LEFT:1,Vector3i.UP:3,Vector3i.DOWN:2,Vector3i.BACK:5,Vector3i.FORWARD:4}


func _lower_layers_match(puzzle: RefCounted, max_y: int) -> bool:
	var reference := _reference_colors()
	for s in puzzle.stickers:
		if s.p.y <= max_y and s.c != reference.get(s.n,-1):
			return false
	return true


func _white_cross(puzzle: RefCounted) -> bool:
	if puzzle.size != 3:
		return false
	var reference := _reference_colors()
	var edges := 0
	for s in puzzle.stickers:
		if s.p.y == 0 and _boundary_count(s.p,puzzle.size)==2:
			if s.c != reference.get(s.n,-1): return false
			if s.n == Vector3i.DOWN: edges += 1
	return edges == 4


func _yellow_cross(puzzle: RefCounted) -> bool:
	var count := 0
	for s in puzzle.stickers:
		if s.n == Vector3i.UP and _boundary_count(s.p,puzzle.size)==2:
			if s.c != YELLOW: return false
			count += 1
	return count == 4


func _boundary_count(p: Vector3i, n: int) -> int:
	var count := 0
	for axis in range(3):
		if p[axis] == 0 or p[axis] == n-1: count += 1
	return count


func _center_color(puzzle: RefCounted, normal: Vector3i) -> int:
	for s in puzzle.stickers:
		if s.n == normal and _boundary_count(s.p,puzzle.size)==1:
			return s.c
	return -1
