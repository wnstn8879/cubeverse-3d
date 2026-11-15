extends Node
## Application coordinator: UI, durable state, training and offline timing.
const State = preload("res://scripts/core/cube_state.gd")
const Store = preload("res://scripts/core/save_store.gd")
const View = preload("res://scripts/view/cube_view.gd")
const Sound = preload("res://scripts/audio/cube_audio.gd")
const Catalog = preload("res://scripts/core/puzzle_catalog.gd")
const Minimap = preload("res://scripts/view/cube_minimap.gd")
const Academy = preload("res://scripts/academy/beginner_academy.gd")
const PyState = preload("res://scripts/puzzles/pyraminx_state.gd")
const PyView = preload("res://scripts/view/pyraminx_view.gd")
const PyMinimap = preload("res://scripts/view/pyraminx_minimap.gd")
const PyCourse = preload("res://scripts/puzzles/pyraminx_course.gd")
const FONT = preload("res://assets/fonts/CubeVerseSans.otf")
const BG = Color("0b101b")
const PANEL = Color("151e2c")
const INK = Color("eef4ff")
const MUTED = Color("8796ad")
const MINT = Color("73f6c4")
const PRESETS = Sound.PRESETS
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
var puzzle_kind := "cube"
var variant := "classic"
var tip_mode := false
var minimap
var academy=Academy.new()
var pyra_academy=PyCourse.new()
var lesson_course: Dictionary = {}
var lesson_stages: Array = []
var lesson_stage_index := 0
var lesson_stage_start: Dictionary = {}
var lesson_info: Label
var lesson_action: Label
var lesson_next_button: Button
var lesson_advance_button: Button
var lesson_progress_label: Label


func _ready() -> void:
	store = Store.new()
	var existing_save = FileAccess.file_exists(store.path) or FileAccess.file_exists(store.path+".bak")
	data = store.load_data()
	if not existing_save: data.settings.sound="squishy"
	variant = str(data.settings.get("variant","classic"))
	if not Catalog.VARIANTS.has(variant): variant="classic"
	puzzle_kind = str(data.settings.get("selected_puzzle","cube"))
	if puzzle_kind not in ["cube","pyraminx"]: puzzle_kind="cube"
	_restore_free_state()
	sound = Sound.new()
	add_child(sound)
	sound.set_preset(str(data.settings.sound))
	sound.set_volume(float(data.settings.volume))
	sound.set_haptics(bool(data.settings.haptics),float(data.settings.strength))
	_create_view()
	canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var theme = Theme.new()
	theme.default_font=FONT
	theme.default_font_size=17
	ui.theme=theme
	get_tree().root.size_changed.connect(_render)
	_render()
	if not store.last_error.is_empty(): _toast("저장 파일 확인: "+store.last_error)
	get_tree().auto_accept_quit=false

func _restore_free_state() -> void:
	if puzzle_kind=="pyraminx":
		state=PyState.new()
		if data.cubes.get("pyraminx") is Dictionary: state.from_dict(data.cubes.pyraminx)
	else:
		state=State.new(int(data.settings.selected_cube))
		var key=Catalog.save_key(state.size,variant)
		if data.cubes.get(key) is Dictionary: state.from_dict(data.cubes[key])

func _create_view() -> void:
	if is_instance_valid(view):
		view.cancel_drag()
		remove_child(view)
		view.queue_free()
	view=PyView.new() if puzzle_kind=="pyraminx" else View.new()
	add_child(view)
	view.setup(state)
	if puzzle_kind=="cube": view.set_variant("classic" if practice else variant)
	elif view.has_method("set_tip_mode"): view.set_tip_mode(tip_mode)
	view.move_completed.connect(_move_completed)
	view.touched.connect(func(): sound.play_event("touch"))
	view.move_started.connect(_move_started)
	view.rotation_progress.connect(func(speed): sound.play_event("rotate",speed))

func _is_solved() -> bool:
	return state.is_solved() if puzzle_kind=="pyraminx" or practice else Catalog.is_solved(state,variant)

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
	# Touch also emits a GUI mouse event. Rebuild after that dispatch finishes.
	b.pressed.connect(action, CONNECT_DEFERRED)
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
	minimap = null
	lesson_info=null
	lesson_action=null
	lesson_next_button=null
	lesson_advance_button=null
	lesson_progress_label=null
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
	var summary = _column(ui,4)
	summary.position=Vector2(margin,126)
	summary.size.x=w-margin*2-(255 if practice else 0)
	_label(summary,"STEP BY STEP" if practice else ("OFFLINE TIME ATTACK" if armed or running else "FREE PLAY"),11,MINT)
	var title=("피라밍크스 입문" if practice else "피라밍크스") if puzzle_kind=="pyraminx" else "%d × %d  %s" % [state.size,state.size,"입문 과정" if practice else Catalog.VARIANTS[variant].name]
	_label(summary,title,22 if practice else 25)
	state_label=_label(summary,"",13,MUTED)
	if practice:
		state_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		state_label.custom_minimum_size.x=220
	else:
		timer_label=_label(ui,_time(elapsed) if armed or running else "",25,INK)
		timer_label.position=Vector2(w-margin-145,146)
		timer_label.size.x=145
		timer_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var controls_top=h-(435 if practice else 295)
	var mini_h=110.0 if practice else 140.0
	var mini_top=139.0 if practice else controls_top-mini_h-12
	minimap=PyMinimap.new() if puzzle_kind=="pyraminx" else Minimap.new()
	ui.add_child(minimap)
	minimap.custom_minimum_size=Vector2.ZERO
	minimap.show_caption=not practice
	minimap.position=Vector2(w-margin-255 if practice else margin+115,mini_top)
	minimap.size=Vector2(255 if practice else w-margin*2-115,mini_h)
	minimap.set_state(state)
	minimap.set_palette(view.get_palette())
	minimap.face_selected.connect(func(face):
		if not view.is_busy(): view.set_face_camera(face))
	if not practice:
		var caption=_label(ui,"전체 면 보기\n뒤·옆·밑까지\n면을 눌러 이동",12,MUTED)
		caption.position=Vector2(margin,mini_top+29)
	var area_top=252.0 if practice else 215.0
	var area_bottom=controls_top-10 if practice else mini_top-10
	view.set_interaction_rect(Rect2(0,area_top,w,maxf(170,area_bottom-area_top)))
	var controls=_column(ui,8)
	controls.position=Vector2(margin,controls_top)
	controls.size.x=w-margin*2
	if practice:
		_render_lesson_controls(controls,w-margin*2)
	else:
		hint_label=_label(controls,"조각 드래그: 층 회전 · 배경 드래그: 시점 · 두 손가락: 확대",12,MUTED)
		hint_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		hint_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var actions=_row(controls)
		_button(actions,"⇄  섞기",_shuffle,true)
		_button(actions,"↶  취소",_undo)
		_button(actions,"↷  다시",_redo)
		var faces=_row(controls,6)
		for face in (["U","L","R","B"] if puzzle_kind=="pyraminx" else ["R","U","F","L","D","B"]):
			var b=_button(faces,face,_face_move.bind(face))
			b.custom_minimum_size.y=42
		if puzzle_kind=="pyraminx":
			_button(faces,"꼭짓점" if tip_mode else "큰 층",_toggle_tip,tip_mode)
		var footer=_row(controls)
		_button(footer,"초기화",_confirm_reset)
		_button(footer,"♪ "+PRESETS.get(str(data.settings.sound),"사운드"),func(): _navigate("설정"))

func _toggle_tip() -> void:
	if view.is_busy() or scramble_active: return
	tip_mode=not tip_mode
	view.set_tip_mode(tip_mode)
	_render()

func _render_lesson_controls(parent: Control, width: float) -> void:
	var stage=lesson_stages[lesson_stage_index]
	lesson_progress_label=_label(parent,"%d / %d 단계  ·  %s" % [lesson_stage_index+1,lesson_stages.size(),stage.title],18,MINT)
	lesson_progress_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(width,115)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	lesson_info=_label(scroll,str(stage.explanation)+"

도움말 · "+str(stage.tip),15,INK)
	lesson_info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	lesson_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	lesson_action=_label(parent,"",14,MINT)
	lesson_action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	lesson_action.custom_minimum_size.y=40
	var row=_row(parent)
	lesson_next_button=_button(row,"한 동작 보기",_lesson_next,true)
	lesson_advance_button=_button(row,"다음 단계 →",_advance_lesson_stage)
	var other=_row(parent)
	_button(other,"이 단계 다시",_restart_lesson_stage)
	_button(other,"학습 나가기",func(): _navigate("아카데미"))

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
	_label(body,"어떤 큐브로 놀까요?",25)
	_wrapped("크기를 고르고, 모양과 색도 바꿔 보세요. 각 퍼즐의 진행 상태를 따로 저장합니다.")
	var grid=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	body.add_child(grid)
	for n in range(2,11):
		var b=_button(grid,"%d × %d\n%s" % [n,n,"플레이 중" if puzzle_kind=="cube" and n==state.size else Catalog.VARIANTS[variant].name],_select_cube.bind(n),puzzle_kind=="cube" and n==state.size)
		b.custom_minimum_size=Vector2(130,90)
	_label(body,"색다른 모양과 색",21)
	for id in Catalog.VARIANTS:
		var item=Catalog.VARIANTS[id]
		_button(body,item.name+("  ✓" if variant==id and puzzle_kind=="cube" else ""),_select_variant.bind(id),variant==id and puzzle_kind=="cube")
		_wrapped(item.detail)
	_label(body,"새로운 회전 규칙",21)
	_button(body,"△  피라밍크스 · 120° 삼각 퍼즐",_select_pyraminx,true)
	_wrapped("큰 층과 끝 꼭짓점이 따로 도는 정사면체 퍼즐입니다.")
	_label(body,"다음 퍼즐 · 개발 예정",19)
	_wrapped("진짜 미러 큐브 · 메가밍크스 · 스큐브 · 기어 · 스퀘어-1 · 피셔 · 고스트. 현재 모양 스타일은 NxN 규칙을 사용하며 이 특수 퍼즐을 대신하지 않습니다.")

func _select_cube(n: int) -> void:
	if view.is_busy() or scramble_active: return
	_save()
	practice=false
	puzzle_kind="cube"
	data.settings.selected_cube=n
	data.settings.selected_puzzle=puzzle_kind
	_restore_free_state()
	_reset_timer()
	_create_view()
	page="홈"
	_save()
	_render()

func _select_variant(id: String) -> void:
	if not Catalog.VARIANTS.has(id) or view.is_busy() or scramble_active: return
	_save()
	variant=id
	data.settings.variant=id
	practice=false
	puzzle_kind="cube"
	data.settings.selected_puzzle=puzzle_kind
	_restore_free_state()
	_reset_timer()
	_create_view()
	page="홈"
	_save()
	_render()

func _select_pyraminx() -> void:
	if view.is_busy() or scramble_active: return
	_save()
	practice=false
	puzzle_kind="pyraminx"
	data.settings.selected_puzzle=puzzle_kind
	_restore_free_state()
	_reset_timer()
	_create_view()
	page="홈"
	_save()
	_render()

func _render_academy() -> void:
	_label(body,"처음부터 큐브 아카데미",25)
	_wrapped("한 번도 맞춰 본 적 없어도 괜찮아요. 조각 찾기부터 완성까지, 설명을 읽고 한 동작씩 따라갑니다.")
	for n in [3,2]:
		var done=bool(data.progress.get("beginner_%d_complete" % n,false))
		_button(body,"%d×%d 처음부터 배우기%s" % [n,n,"  ✓ 수료" if done else ""],_start_lesson.bind(n),true)
		for item in academy.get_steps(n):
			_label(body,"• "+str(item.title),15,MUTED)
	_label(body,"이 수업은 이렇게 진행돼요",20)
	_wrapped("예제로 준비된 큐브를 끝까지 완성하는 안내 수업입니다. 자유 플레이 상태는 그대로 보관합니다. 설명은 직접 맞출 때도 참고할 수 있지만, 임의로 섞은 모든 상태를 분석하는 자동 해법은 아직 제공하지 않습니다.")
	_label(body,"피라밍크스 첫걸음",20)
	_wrapped("① 끝 꼭짓점의 세 색을 옆 큰 조각과 먼저 맞춰요.\n② 한 색을 바닥으로 정하고 같은 색의 모서리 세 개를 모아요.\n③ 바닥을 유지하며 나머지 세 모서리의 자리를 맞춰요.\n큰 층은 120°, 끝 꼭짓점은 따로 돕니다.")
	_button(body,"피라밍크스 처음부터 배우기"+("  ✓ 수료" if data.progress.get("beginner_pyraminx_complete",false) else ""),_start_pyraminx_lesson,true)
	_button(body,"피라밍크스 자유 플레이",_select_pyraminx)

func _start_lesson(n: int) -> void:
	if view.is_busy() or scramble_active: return
	_save()
	lesson_course=academy.make_course(n)
	if not bool(lesson_course.get("verified",false)):
		_toast("검증된 수업을 불러오지 못했습니다")
		return
	practice=true
	_reset_timer()
	puzzle_kind="cube"
	state=lesson_course.state
	lesson_stages=lesson_course.stages
	lesson_stage_index=0
	lesson_step=0
	lesson_moves=lesson_stages[0].moves
	lesson_stage_start=state.to_dict().duplicate(true)
	_create_view()
	page="아카데미"
	_render()

func _stop_lesson() -> void:
	if view.is_busy(): return
	practice=false
	puzzle_kind=str(data.settings.get("selected_puzzle","cube"))
	variant=str(data.settings.get("variant","classic"))
	_restore_free_state()
	_create_view()

func _start_pyraminx_lesson() -> void:
	if view.is_busy() or scramble_active: return
	_save()
	lesson_course=pyra_academy.make_course()
	if not bool(lesson_course.get("verified",false)):
		_toast("검증된 수업을 불러오지 못했습니다")
		return
	practice=true
	_reset_timer()
	puzzle_kind="pyraminx"
	state=lesson_course.state
	lesson_stages=lesson_course.stages
	lesson_stage_index=0
	lesson_step=0
	lesson_moves=lesson_stages[0].moves
	lesson_stage_start=state.to_dict().duplicate(true)
	_create_view()
	page="아카데미"
	_render()

func _lesson_prefix() -> String:
	return "beginner_pyraminx" if puzzle_kind=="pyraminx" else "beginner_%d" % state.size

func _lesson_stage_complete() -> bool:
	return pyra_academy.stage_complete(state,lesson_stage_index) if puzzle_kind=="pyraminx" else academy.stage_complete(state,lesson_stage_index,state.size)

func _lesson_next() -> void:
	if not practice or view.is_busy(): return
	if lesson_step>=lesson_moves.size():
		_toast("설명과 목표를 확인한 뒤 다음 단계로 이동하세요")
		return
	var m=lesson_moves[lesson_step]
	view.animate_move(m.axis,m.layer,m.turns)

func _advance_lesson_stage() -> void:
	if not practice or view.is_busy(): return
	if lesson_step<lesson_moves.size():
		_toast("이 단계의 동작을 먼저 따라해 보세요")
		return
	if not _lesson_stage_complete():
		_toast("아직 목표 상태가 아닙니다. 이 단계를 다시 시작해 주세요")
		return
	var stage=lesson_stages[lesson_stage_index]
	data.progress["%s_%s" % [_lesson_prefix(),stage.id]]=true
	if lesson_stage_index>=lesson_stages.size()-1:
		if not state.is_solved():
			_toast("아직 완성이 아닙니다. 이 단계를 다시 시작해 주세요")
			return
		data.progress[_lesson_prefix()+"_complete"]=true
		_save()
		_toast("수료했습니다! 이제 같은 순서를 직접 연습해 보세요")
		return
	lesson_stage_index+=1
	lesson_step=0
	lesson_moves=lesson_stages[lesson_stage_index].moves
	lesson_stage_start=state.to_dict().duplicate(true)
	_save()
	_render()

func _restart_lesson_stage() -> void:
	if not practice or view.is_busy(): return
	if not state.from_dict(lesson_stage_start): return
	lesson_step=0
	view.setup(state)
	_render()

func _render_arena() -> void:
	_label(body, "큐브 아레나", 26)
	_label(body, "OFFLINE TIME ATTACK", 12, MINT)
	_wrapped("셔플이 끝나면 첫 회전부터 시간을 잽니다. 완성하면 기기 안에 기록을 저장합니다. 취소·다시·초기화는 측정을 종료합니다.")
	var puzzle_name="피라밍크스" if puzzle_kind=="pyraminx" else "%d×%d %s" % [state.size,state.size,Catalog.VARIANTS[variant].name]
	_button(body,puzzle_name+" 기록 도전 시작",_start_timer,true)
	_label(body, "내 기록", 21)
	if data.records.is_empty(): _wrapped("아직 기록이 없습니다. 첫 완성에 도전하세요.")
	var shown := 0
	for r in data.records:
		if not r is Dictionary or not r.has_all(["size","time","moves"]): continue
		if not (r.size is int or r.size is float) or not (r.time is int or r.time is float) or not (r.moves is int or r.moves is float): continue
		if shown >= 12: break
		var record_name="피라밍크스" if r.get("puzzle","cube")=="pyraminx" else "%d×%d" % [int(r.size),int(r.size)]
		if r.get("puzzle","cube")!="pyraminx" and r.get("variant","classic")!="classic": record_name+=" "+str(Catalog.VARIANTS.get(r.variant,{"name":""}).name)
		_label(body,"%s   %s   ·   %d회" % [record_name,_time(float(r.time)),int(r.moves)],18)
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
	_wrapped("말랑이·슬라임·크리미 폼·물방울 젤을 새로 추가했어요. 누르는 소리부터 놓는 소리까지 미리 들어 보세요. 직접 제작한 합성 사운드이며 청감 튜닝은 계속 진행합니다.")
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
	_wrapped("Android는 기기 진동 기능을 사용합니다. 실제 강도 제어는 기기 지원에 따라 달라집니다. 웹은 브라우저가 진동 API를 지원할 때만 동작합니다. 실기기 검증 전입니다.\n\n상태는 이 기기·브라우저에 자동 저장됩니다. 계정 로그인과 클라우드 동기화는 아직 지원하지 않습니다.\n\nCubeVerse 3D 0.2.0 · 한국어\nEnglish UI: planned")

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
	practice=false
	pending_scramble.clear()
	var rng=RandomNumberGenerator.new()
	rng.randomize()
	var last_axis := -1
	for i in range(20 if puzzle_kind=="pyraminx" else maxi(18,state.size*8)):
		var axis=rng.randi_range(0,3 if puzzle_kind=="pyraminx" else 2)
		while axis==last_axis: axis=rng.randi_range(0,3 if puzzle_kind=="pyraminx" else 2)
		last_axis=axis
		var layer=rng.randi_range(0,1) if puzzle_kind=="pyraminx" else rng.randi_range(0,state.size-1)
		pending_scramble.append({"axis":axis,"layer":layer,"turns":1 if rng.randf()>0.5 else -1})
	scramble_active=true
	view.set_input_enabled(false)
	_toast("퍼즐을 섞고 있습니다…")
	_update_status()

func _face_move(face: String) -> void:
	if scramble_active or view.is_busy(): return
	if puzzle_kind=="pyraminx":
		view.animate_move({"U":0,"L":1,"R":2,"B":3}[face],0 if tip_mode else 1,-1)
		return
	var mapping={"R":[0,state.size-1,-1],"L":[0,0,1],"U":[1,state.size-1,-1],"D":[1,0,1],"F":[2,state.size-1,-1],"B":[2,0,1]}
	var m=mapping[face]
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
	dialog.confirmed.connect(func(): _reset_timer(); state.reset(); view.setup(state); _save(); _render(); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(420,180))

func _move_started() -> void:
	if is_instance_valid(minimap): minimap.set_turning(true)
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
				var cycle=3 if puzzle_kind=="pyraminx" else 4
				if axis==expected.axis and layer==expected.layer and posmod(turns,cycle)==posmod(expected.turns,cycle):
					lesson_step+=1
				else:
					# Undo a wrong step without advancing the course.
					state.undo()
					view.rebuild()
					_toast("다른 동작입니다. 다음 동작 시범으로 방향을 확인하세요")
			else:
				state.undo()
				view.rebuild()
				_toast("설명과 목표를 확인한 뒤 다음 단계로 이동하세요")
		if _is_solved():
			sound.play_event("complete")
			if running:
				running=false
				data.records.push_front({"puzzle":puzzle_kind,"variant":variant,"size":state.size,"time":elapsed,"moves":moves,"date":Time.get_datetime_string_from_system(),"scramble":record_scramble,"replay":record_moves.duplicate(true)})
				if data.records.size()>100: data.records.resize(100)
				_toast("완성! " + _time(elapsed) + " · 기기에 기록을 저장했습니다")
			elif practice and lesson_step==lesson_moves.size():
				_toast("목표를 확인하고 다음 단계로 이동하세요")
	if is_instance_valid(minimap): minimap.refresh()
	_update_status()
	_save()

func _reset_timer() -> void:
	running=false
	armed=false
	elapsed=0
	moves=0

func _update_status() -> void:
	if is_instance_valid(state_label):
		if practice:
			state_label.text=str(lesson_stages[lesson_stage_index].goal)
		else:
			state_label.text="셔플 중…" if scramble_active else ("완성 상태 · 나만의 리듬으로" if _is_solved() else "플레이 중 · 자동 저장")
	if is_instance_valid(minimap): minimap.set_turning(view.is_busy())
	if practice and is_instance_valid(lesson_action):
		if lesson_step>=lesson_moves.size():
			lesson_action.text="✓ 설명을 읽었다면 다음 단계로 이동하세요" if lesson_moves.is_empty() else "✓ 목표 달성 · 다음 단계로 이동하세요"
			lesson_next_button.disabled=true
			lesson_advance_button.disabled=false
		else:
			var m=lesson_moves[lesson_step]
			var note=str(lesson_stages[lesson_stage_index].move_notes[lesson_step])
			lesson_action.text="%d / %d 동작 · %s" % [lesson_step+1,lesson_moves.size(),note]
			lesson_next_button.disabled=false
			lesson_advance_button.disabled=true
			if is_instance_valid(minimap) and minimap.has_method("set_target"):
				if puzzle_kind=="cube": minimap.set_target(academy.face_normal(m,state.size))

func _save() -> void:
	if store==null or state==null: return
	if not practice:
		var key="pyraminx" if puzzle_kind=="pyraminx" else Catalog.save_key(state.size,variant)
		data.cubes[key]=state.to_dict()
		if puzzle_kind=="cube": data.settings.selected_cube=state.size
		data.settings.selected_puzzle=puzzle_kind
		data.settings.variant=variant
	if not store.save_data(data): _toast("저장 실패 · "+store.last_error)

func _toast(text: String) -> void:
	if is_instance_valid(toast_label):
		toast_label.text = text
		toast_label.visible=true
		toast_time=5.0

func _time(seconds: float) -> String:
	var minutes = int(seconds)/60
	return "%02d:%05.2f" % [minutes, fmod(seconds,60.0)]
