extends Node
## Application coordinator: UI, durable state, training and offline timing.
const State = preload("res://scripts/core/cube_state.gd")
const Store = preload("res://scripts/core/save_store.gd")
const View = preload("res://scripts/view/cube_view.gd")
const Sound = preload("res://scripts/audio/cube_audio.gd")
const FONT = preload("res://assets/fonts/CubeVerseSans.otf")
const BG = Color("0b101b")
const PANEL = Color("151e2c")
const INK = Color("eef4ff")
const MUTED = Color("8796ad")
const MINT = Color("73f6c4")
const PRESETS = {"bubble":"뽁뽁이", "magnetic":"마그네틱", "mechanical":"기계식", "arcade":"아케이드", "soft":"소프트 클릭", "plastic":"플라스틱 큐브"}
var state
var store
var data: Dictionary
var view
var sound
var canvas: CanvasLayer
var ui: Control
var body: Control
var page: String = "홈"
var timer_label: Label
var state_label: Label
var hint_label: Label
var running := false
var armed := false
var elapsed := 0.0
var moves := 0
var practice := false
var lesson_step := 0
var lesson_moves: Array = []
var pending_scramble: Array = []
var scramble_active := false
var scramble_timer := 0.0
var last_saved := 0.0
var toast_label: Label
var toast_time := 0.0
var record_scramble: Dictionary = {}
var record_moves: Array = []
var restoring := false
var native_size := Vector2.ZERO

func _ready() -> void:
	store = Store.new()
	data = store.load_data()
	state = State.new(int(data.settings.selected_cube))
	var key = str(state.size)
	if data.cubes.get(key) is Dictionary:
		if not state.from_dict(data.cubes[key]):
			state.reset(int(data.settings.selected_cube))
	view = View.new()
	add_child(view)
	view.setup(state)
	view.move_completed.connect(_move_completed)
	sound = Sound.new()
	add_child(sound)
	sound.set_preset(str(data.settings.sound))
	sound.set_volume(float(data.settings.volume))
	sound.set_haptics(bool(data.settings.haptics), float(data.settings.strength))
	view.touched.connect(func(): sound.play_event("touch"))
	view.move_started.connect(_move_started)
	view.rotation_progress.connect(func(speed): sound.play_event("rotate", speed))
	canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 17
	ui.theme = theme
	get_tree().root.size_changed.connect(_render)
	_render()
	if not store.last_error.is_empty(): _toast("저장 파일 확인: " + store.last_error)
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if is_instance_valid(view): view.cancel_drag()
		if store != null: _save()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(view): view.cancel_drag()
		if store != null: _save()

func _process(delta: float) -> void:
	if running:
		elapsed += delta
		if is_instance_valid(timer_label): timer_label.text = _time(elapsed)
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0 and is_instance_valid(toast_label): toast_label.visible = false
	if scramble_active and not view.is_busy():
		scramble_timer -= delta
		if scramble_timer <= 0:
			if pending_scramble.is_empty():
				scramble_active = false
				view.set_input_enabled(true)
				if armed:
					record_scramble = state.to_dict().duplicate(true)
					record_moves.clear()
					_toast("준비 완료 · 첫 회전부터 타이머가 시작됩니다")
				else: _toast("셔플 완료 · 자유롭게 돌려 보세요")
				_update_status()
				_save()
			else:
				var m = pending_scramble.pop_front()
				view.animate_move(m.axis, m.layer, m.turns)
				scramble_timer = 0.01
	last_saved += delta
	if last_saved >= 5.0:
		last_saved = 0.0
		_save()

func _style(color: Color, radius: int = 16, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1)
	s.border_color = border
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _label(parent: Node, text: String, size: int = 18, color: Color = INK) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, action: Callable, accent := false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 50
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", _style(MINT if accent else PANEL, 14, Color("263449") if not accent else MINT))
	b.add_theme_stylebox_override("hover", _style(Color("9fffdc") if accent else Color("243249")))
	b.add_theme_stylebox_override("pressed", _style(Color("55cba2") if accent else Color("32445d")))
	b.add_theme_color_override("font_color", BG if accent else INK)
	b.add_theme_color_override("font_hover_color", BG if accent else INK)
	b.add_theme_color_override("font_pressed_color", BG if accent else INK)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _column(parent: Node, gap := 12) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	parent.add_child(v)
	return v

func _row(parent: Node, gap := 10) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	parent.add_child(h)
	return h

func _render() -> void:
	if ui == null: return
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	timer_label = null
	state_label = null
	hint_label = null
	var sz = get_viewport().get_visible_rect().size
	native_size = sz
	var w = sz.x
	var h = sz.y
	var margin = maxf(22, (w - 680) / 2)
	var top = _column(ui, 6)
	top.position = Vector2(margin, 28)
	top.size.x = w - margin * 2
	var brand = _row(top)
	_label(brand, "◈", 30, MINT)
	_label(brand, "CUBEVERSE", 24)
	var version = _label(brand, "  3D / ALPHA", 12, MUTED)
	version.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(top, "손끝에서 시작되는 작은 우주", 14, MUTED)
	var divider = ColorRect.new()
	divider.color = Color("243044")
	divider.position = Vector2(margin, 105)
	divider.size = Vector2(w - margin * 2, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(divider)
	var nav = _row(ui, 4)
	nav.position = Vector2(margin - 8, h - 78)
	nav.size = Vector2(w - margin * 2 + 16, 58)
	for tab in ["홈", "큐브", "아카데미", "아레나", "상점", "설정"]:
		var b = _button(nav, tab, _navigate.bind(tab), page == tab)
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size.x = 0
		b.add_theme_stylebox_override("normal", _style(Color("20372f") if page == tab else BG, 12))
		b.add_theme_color_override("font_color", MINT if page == tab else MUTED)
	toast_label = _label(ui, "", 14, MINT)
	toast_label.position = Vector2(margin, h - 117)
	toast_label.size.x = w - 2 * margin
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.visible = false
	view.visible = page == "홈" or (page == "아카데미" and practice)
	view.set_input_enabled(view.visible and not scramble_active)
	if view.visible:
		_render_play(w, h, margin)
	else:
		var scroll = ScrollContainer.new()
		scroll.position = Vector2(margin, 127)
		scroll.size = Vector2(w - 2 * margin, h - 254)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ui.add_child(scroll)
		body = _column(scroll, 14)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		match page:
			"큐브": _render_cubes()
			"아카데미": _render_academy()
			"아레나": _render_arena()
			"상점": _render_shop()
			"설정": _render_settings()
	_update_status()

func _render_play(w: float, h: float, margin: float) -> void:
	var summary = _column(ui, 4)
	summary.position = Vector2(margin, 126)
	_label(summary, "GUIDED PRACTICE" if practice else ("OFFLINE TIME ATTACK" if armed or running else "FREE PLAY"), 11, MINT)
	_label(summary, "%d × %d  %s" % [state.size, state.size, "연습 큐브" if practice else "클래식 큐브"], 25)
	state_label = _label(summary, "", 14, MUTED)
	timer_label = _label(ui, _time(elapsed) if armed or running else "", 25, INK)
	timer_label.position = Vector2(w - margin - 145, 146)
	timer_label.size.x = 145
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var area_top = 215.0
	var controls_top = h - 295.0
	view.set_interaction_rect(Rect2(0, area_top, w, maxf(220, controls_top - area_top)))
	var controls = _column(ui, 10)
	controls.position = Vector2(margin, controls_top)
	controls.size.x = w - 2 * margin
	hint_label = _label(controls, "조각을 드래그해 회전 · 배경을 드래그해 시점 변경", 13, MUTED)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if practice:
		_label(controls, "정해진 역순 동작을 따라 원래 상태로 되돌립니다", 13, MUTED)
		_button(controls, "다음 동작 시범", _lesson_next, true)
		_button(controls, "연습 종료", func(): _stop_lesson(); _navigate("아카데미"))
	else:
		var actions = _row(controls)
		_button(actions, "⇄  섞기", _shuffle, true)
		_button(actions, "↶  취소", _undo)
		_button(actions, "↷  다시", _redo)
		var faces = _row(controls, 6)
		for face in ["R", "U", "F", "L", "D", "B"]:
			var b = _button(faces, face, _face_move.bind(face))
			b.custom_minimum_size.y = 42
		var footer = _row(controls)
		_button(footer, "초기화", _confirm_reset)
		_button(footer, "♪ " + PRESETS.get(str(data.settings.sound), "사운드"), func(): _navigate("설정"))

func _navigate(tab: String) -> void:
	if view.is_busy() or scramble_active:
		_toast("회전이 끝난 뒤 이동할 수 있습니다")
		return
	view.cancel_drag()
	_save()
	if practice: _stop_lesson()
	page = tab
	_render()

func _render_cubes() -> void:
	_label(body, "당신의 큐브를 고르세요", 25)
	_wrapped("2×2부터 10×10까지, 같은 규칙으로 이어지는 아홉 가지 도전.")
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for n in range(2, 11):
		var b = _button(grid, "%d × %d\n%s" % [n, n, "플레이 중" if n == state.size else "클래식"], _select_cube.bind(n), n == state.size)
		b.custom_minimum_size = Vector2(130, 100)
	_label(body, "다음에 만날 퍼즐", 20)
	_wrapped("미러 · 피라밍크스 · 메가밍크스 · 스큐브\n기어 · 스퀘어-1 · 피셔 · 고스트\n\n개발 예정입니다. 각 퍼즐의 실제 구조를 갖춘 별도 엔진으로 추가합니다.")

func _select_cube(n: int) -> void:
	_save()
	state = State.new(n)
	if data.cubes.get(str(n)) is Dictionary: state.from_dict(data.cubes[str(n)])
	data.settings.selected_cube = n
	practice = false
	_reset_timer()
	view.setup(state)
	page = "홈"
	_save()
	_render()

func _render_academy() -> void:
	_label(body, "큐브 아카데미", 26)
	_wrapped("첫 수업: 회전과 역회전\nR은 오른쪽, U는 위쪽 면입니다. '는 반대 방향을 뜻합니다. 버튼 시범과 직접 조작을 함께 연습하세요.")
	for n in [2, 3]:
		var done = bool(data.progress.get("inverse_" + str(n), false))
		_button(body, "%d×%d · 네 동작 되돌리기%s" % [n,n, "  ✓ 수료" if done else ""], _start_lesson.bind(n), true)
	_label(body, "현재 제공 범위", 20)
	_wrapped("검증 가능한 고정 상태에서 R U R' U'와 역순 복원을 연습합니다. 임의 상태를 푸는 전체 해법, 상태별 화살표, 고차 큐브 강의는 아직 구현되지 않았습니다.")

func _start_lesson(n: int) -> void:
	_save()
	practice = true
	_reset_timer()
	state = State.new(n)
	var sequence = [{"axis":0,"layer":n-1,"turns":-1},{"axis":1,"layer":n-1,"turns":-1},{"axis":0,"layer":n-1,"turns":1},{"axis":1,"layer":n-1,"turns":1}]
	for m in sequence: state.apply_move(m.axis,m.layer,m.turns)
	lesson_moves = []
	for i in range(sequence.size()-1,-1,-1):
		var m = sequence[i]
		lesson_moves.append({"axis":m.axis,"layer":m.layer,"turns":-m.turns})
	lesson_step = 0
	practice = true
	view.setup(state)
	page = "아카데미"
	_render()

func _stop_lesson() -> void:
	if view.is_busy(): return
	practice = false
	state = State.new(int(data.settings.selected_cube))
	if data.cubes.get(str(state.size)) is Dictionary: state.from_dict(data.cubes[str(state.size)])
	view.setup(state)

func _lesson_next() -> void:
	if view.is_busy(): return
	if lesson_step >= lesson_moves.size():
		_toast("연습 완료! 자유롭게 동작을 복습하세요")
		return
	var m = lesson_moves[lesson_step]
	view.animate_move(m.axis,m.layer,m.turns)

func _render_arena() -> void:
	_label(body, "큐브 아레나", 26)
	_label(body, "OFFLINE TIME ATTACK", 12, MINT)
	_wrapped("셔플이 끝나면 첫 회전부터 시간을 잽니다. 완성하면 기기 안에 기록을 저장합니다. 취소·다시·초기화는 측정을 종료합니다.")
	_button(body, "%d×%d 기록 도전 시작" % [state.size,state.size], _start_timer, true)
	_label(body, "내 기록", 21)
	if data.records.is_empty(): _wrapped("아직 기록이 없습니다. 첫 완성에 도전하세요.")
	var shown := 0
	for r in data.records:
		if not r is Dictionary or not r.has_all(["size","time","moves"]): continue
		if not (r.size is int or r.size is float) or not (r.time is int or r.time is float) or not (r.moves is int or r.moves is float): continue
		if shown >= 12: break
		_label(body, "%d×%d   %s   ·   %d회" % [int(r.size),int(r.size),_time(float(r.time)),int(r.moves)], 18)
		shown += 1
	_wrapped("온라인 대전 · 친구 · 랜덤 매칭 · 서버 검증 · 랭킹은 개발 예정입니다. 현재 기록은 로컬 연습 기록이며 공인 기록이 아닙니다.")

func _start_timer() -> void:
	_reset_timer()
	armed = true
	page = "홈"
	_render()
	_shuffle(true)

func _render_shop() -> void:
	_label(body, "사운드 스튜디오", 26)
	_wrapped("여섯 가지 무료 사운드를 먼저 들어 보세요. 각 프리셋은 직접 합성한 임시 오디오이며 최종 음질 튜닝 전입니다.")
	for id in PRESETS:
		var r = _row(body)
		var l = _label(r, PRESETS[id], 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(r, "미리 듣기", func(): sound.preview(id))
	_label(body, "프리미엄 컬렉션 · 준비 중", 20)
	_wrapped("Thock · 크리미 · Clacky · 메탈\n유리 구슬 · 물방울 · 젤리 팝 · 나무 클릭\n\n스킨과 프리미엄 음원, Google Play 결제와 구매 복원은 미구현입니다. 이 버전에는 구매 기능이 없습니다.")

func _render_settings() -> void:
	_label(body, "나만의 플레이 감각", 26)
	_label(body, "사운드 프리셋", 18)
	for id in PRESETS:
		_button(body, ("●  " if data.settings.sound == id else "○  ") + PRESETS[id], _choose_sound.bind(id), data.settings.sound == id)
	_label(body, "효과음 볼륨", 18)
	var volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = float(data.settings.volume)
	volume.custom_minimum_size.y = 44
	body.add_child(volume)
	volume.value_changed.connect(func(value): data.settings.volume = value; sound.set_volume(value); _save())
	var haptic = CheckButton.new()
	haptic.text = "햅틱 사용" if sound.haptics_supported else "햅틱 · 이 환경에서 지원되지 않음"
	haptic.disabled = not sound.haptics_supported
	haptic.custom_minimum_size.y = 52
	haptic.button_pressed = bool(data.settings.haptics)
	body.add_child(haptic)
	haptic.toggled.connect(func(on): data.settings.haptics=on; sound.set_haptics(on,float(data.settings.strength)); _save())
	_label(body, "햅틱 강도", 18)
	var strength = HSlider.new()
	strength.min_value=0.1
	strength.max_value=1
	strength.step=0.1
	strength.value=float(data.settings.strength)
	strength.custom_minimum_size.y=44
	strength.editable=bool(sound.haptics_supported)
	body.add_child(strength)
	strength.value_changed.connect(func(value): data.settings.strength=value; sound.set_haptics(bool(data.settings.haptics),value); _save())
	_wrapped("Android는 기기 진동 기능을 사용합니다. 실제 강도 제어는 기기 지원에 따라 달라집니다. 웹은 브라우저가 진동 API를 지원할 때만 동작합니다. 실기기 검증 전입니다.\n\n상태는 이 기기·브라우저에 자동 저장됩니다. 계정 로그인과 클라우드 동기화는 아직 지원하지 않습니다.\n\nCubeVerse 3D 0.1.0 · 한국어\nEnglish UI: planned")

func _choose_sound(id: String) -> void:
	data.settings.sound = id
	sound.set_preset(id)
	sound.preview(id)
	_save()
	_render()

func _wrapped(text: String) -> void:
	var l = _label(body,text,16,MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _shuffle(for_timer := false) -> void:
	if view.is_busy() or scramble_active: return
	if not for_timer: _reset_timer()
	practice = false
	pending_scramble.clear()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var last_axis := -1
	for i in range(maxi(18, state.size * 8)):
		var axis = rng.randi_range(0,2)
		while axis == last_axis: axis = rng.randi_range(0,2)
		last_axis = axis
		pending_scramble.append({"axis":axis,"layer":rng.randi_range(0,state.size-1),"turns":1 if rng.randf()>0.5 else -1})
	scramble_active = true
	view.set_input_enabled(false)
	_toast("큐브를 섞고 있습니다…")
	_update_status()

func _face_move(face: String) -> void:
	if scramble_active or view.is_busy(): return
	var mapping = {"R":[0,state.size-1,-1],"L":[0,0,1],"U":[1,state.size-1,-1],"D":[1,0,1],"F":[2,state.size-1,-1],"B":[2,0,1]}
	var m = mapping[face]
	view.animate_move(m[0],m[1],m[2])

func _undo() -> void:
	if view.is_busy() or scramble_active: return
	_reset_timer()
	view.request_undo()

func _redo() -> void:
	if view.is_busy() or scramble_active: return
	_reset_timer()
	view.request_redo()

func _confirm_reset() -> void:
	if view.is_busy() or scramble_active: return
	var dialog = ConfirmationDialog.new()
	dialog.title="큐브 초기화"
	dialog.dialog_text="현재 큐브를 완성 상태로 되돌릴까요?"
	dialog.ok_button_text="초기화"
	dialog.cancel_button_text="계속 플레이"
	dialog.theme=ui.theme
	ui.add_child(dialog)
	dialog.confirmed.connect(func(): _reset_timer(); state.reset(); view.setup(state); _save(); _update_status(); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(420,180))

func _move_started() -> void:
	sound.play_event("start")
	if armed and not scramble_active:
		armed=false
		running=true
		elapsed=0
		moves=0

func _move_completed(axis: int, layer: int, turns: int) -> void:
	sound.play_event("snap",1.0)
	if not scramble_active:
		if running:
			moves+=1
			record_moves.append({"axis":axis,"layer":layer,"turns":turns})
		if practice:
			if lesson_step < lesson_moves.size():
				var expected = lesson_moves[lesson_step]
				if axis==expected.axis and layer==expected.layer and turns==expected.turns:
					lesson_step+=1
				else:
					# Undo a wrong step without advancing the course.
					state.undo()
					view.rebuild()
					_toast("다른 동작입니다. 다음 동작 시범으로 방향을 확인하세요")
		if state.is_solved():
			sound.play_event("complete")
			if running:
				running=false
				data.records.push_front({"size":state.size,"time":elapsed,"moves":moves,"date":Time.get_datetime_string_from_system(),"scramble":record_scramble,"replay":record_moves.duplicate(true)})
				if data.records.size()>100: data.records.resize(100)
				_toast("완성! " + _time(elapsed) + " · 기기에 기록을 저장했습니다")
			elif practice and lesson_step==lesson_moves.size():
				data.progress["inverse_"+str(state.size)]=true
				_toast("수업 완료! 네 동작을 정확히 되돌렸습니다")
	_update_status()
	_save()

func _reset_timer() -> void:
	running=false
	armed=false
	elapsed=0
	moves=0

func _update_status() -> void:
	if is_instance_valid(state_label):
		state_label.text = "셔플 중…" if scramble_active else ("완성 상태 · 나만의 리듬으로" if state.is_solved() else "플레이 중 · 자동 저장")
	if is_instance_valid(hint_label) and practice:
		var names=["U", "R", "U'", "R'"]
		hint_label.text="연습 완료 ✓" if lesson_step>=4 else "단계 %d / 4   →   %s" % [lesson_step+1,names[lesson_step]]

func _save() -> void:
	if store == null or state == null: return
	if not practice:
		data.cubes[str(state.size)] = state.to_dict()
		data.settings.selected_cube = state.size
	if not store.save_data(data):
		_toast("저장 실패 · " + store.last_error)

func _toast(text: String) -> void:
	if is_instance_valid(toast_label):
		toast_label.text = text
		toast_label.visible=true
		toast_time=5.0

func _time(seconds: float) -> String:
	var minutes = int(seconds)/60
	return "%02d:%05.2f" % [minutes, fmod(seconds,60.0)]
