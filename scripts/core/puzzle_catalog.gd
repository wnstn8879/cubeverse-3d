extends RefCounted
## Cosmetic shape modifications retain the genuine NxN move rules.
const VARIANTS = {
	"classic": {"name":"클래식", "detail":"여섯 색으로 배우는 기본 큐브"},
	"three_color": {"name":"3컬러 듀오", "detail":"마주 보는 면이 같은 색. 세 가지 색만으로 맞춰 보세요."},
	"pillow": {"name":"말랑 쿠션", "detail":"볼록하게 부푼 쿠션 조각. 같은 층 회전 규칙이에요."},
	"crystal": {"name":"크리스털 컷", "detail":"보석처럼 모서리를 깎은 입체 조각"},
	"neon": {"name":"네온 글로우", "detail":"어둠 속에서 색이 빛나는 큐브"},
}

static func save_key(n: int, variant: String) -> String:
	return str(n) if variant == "classic" else "%d@%s" % [n,variant]

static func is_solved(state, variant: String) -> bool:
	if variant != "three_color": return state.is_solved()
	var faces: Dictionary = {}
	for sticker in state.stickers:
		var color := int(sticker.c) / 2
		if faces.has(sticker.n) and faces[sticker.n] != color: return false
		faces[sticker.n] = color
	return faces.size() == 6
