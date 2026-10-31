class_name SurfSchool
extends Node
const LESSONS := [
	{"title":"Conoce tu tabla", "task":"Cambia de cámara y elige una vista cómoda.", "hint":"C, stick derecho o botón CÁMARA."},
	{"title":"Remada", "task":"Rema y avanza al menos 3 metros.", "hint":"Mantén REMAR; orienta la tabla con el joystick o WASD."},
	{"title":"Tomar la ola", "task":"Espera a que llegue y rema hasta poder pararte.", "hint":"Empieza a remar cuando la cresta esté cerca."},
	{"title":"Ponerse de pie", "task":"Párate con velocidad y completa la incorporación.", "hint":"Pulsa PARARSE cuando aparezca la indicación."},
	{"title":"Equilibrio", "task":"Mantén el equilibrio durante 4 segundos seguidos.", "hint":"Reparte el peso adelante/atrás con suavidad."},
	{"title":"Giro amplio", "task":"Traza un giro amplio y avanza sin caer.", "hint":"Gira suavemente; mantener todo el giro puede clavar el canto."},
	{"title":"Tu primera ola", "task":"Toma la ola y recórrela sin caerte.", "hint":"Combina remada, incorporación, equilibrio y giros."},
]
var game: Game
var active := false
var lesson := 0
var completed: Array[int] = []
var persist := true
var finished := false
var progress := 0.0
var _stable := 0.0
var _distance := 0.0
var _turn := 0.0
var _previous_position := Vector3.ZERO
var _previous_yaw := 0.0
var _initial_camera := 0
var _saw_popup := false
var _saw_ready := false
var _ui: Control
var _instruction: PanelContainer
var _title: Label
var _task: Label
var _hint: Label
var _bar: ProgressBar
var _result: Control
var _result_title: Label
var _result_detail: Label
var _next: Button
var _retry: Button

func setup(owner_game: Game) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 10
	persist = Ajustes.persist
	if persist: load_progress()
	_build_ui()

func progress_path() -> String:
	return "user://school-test.cfg" if "--qa" in OS.get_cmdline_user_args() else "user://surf_school.cfg"

func load_progress() -> void:
	completed.clear()
	var cfg := ConfigFile.new()
	if cfg.load(progress_path()) != OK or int(cfg.get_value("school","version",0)) != 1: return
	var saved: Variant = cfg.get_value("school","completed",[])
	if saved is Array:
		for value in saved:
			if value is int and value >= 0 and value < LESSONS.size() and not completed.has(value): completed.append(value)

func save_progress() -> void:
	if not persist: return
	var cfg := ConfigFile.new()
	cfg.set_value("school","version",1)
	cfg.set_value("school","completed",completed)
	var error := cfg.save(progress_path())
	if error != OK: push_warning("No se pudo guardar progreso de escuela: %s" % error)

func start(index: int) -> void:
	lesson = clampi(index,0,LESSONS.size()-1)
	active = true
	game.session.setup(game.spot,0)
	game.hud.set_school_mode(true)
	game.start_play()
	_ui.show()
	_instruction.show()
	_result.hide()

func prepare_attempt() -> void:
	finished = false
	progress = 0.0
	_stable = 0.0
	_distance = 0.0
	_turn = 0.0
	_saw_popup = false
	_saw_ready = false
	_initial_camera = Ajustes.camera_view
	Controles.paddle_latched = false
	Controles.touch_paddle = false
	Controles.touch_trick = false
	Controles._touch_stand = false
	game.touch._release_all()
	game.surfer.tricks.reset()
	game._missed_timer = -1.0
	var w := game.wave
	var s := game.surfer
	if lesson in [2,3]:
		var gap := 14.0 if lesson == 2 else 1.0
		w.time = (game.lineup.z-gap-w.start_z)/w.speed
		w.update()
		s.reset_to(Vector3(game.lineup.x,w.height_at(game.lineup.x,game.lineup.z),game.lineup.z),0.0)
		if lesson == 3: s.hvel = Vector2(0,w.speed*0.95)
	elif lesson in [4,5]:
		w.time = 15.0
		w.update()
		var x := w.peel_x + w.peel_dir*3.0
		var z := w.crest_z + w.front_width*0.9
		s.reset_to(Vector3(x,w.height_at(x,z)+Surfer.DECK_RIDE,z),w.peel_dir*PI*0.5)
		s.state = Surfer.State.RIDING
		s.hvel = Vector2(w.peel_dir*6.8,w.speed)
		s.animator.jump_to("ride")
		s._update_visual(0,w.sample(x,z))
		s.reset_physics_interpolation()
	_previous_position = s.global_position
	_previous_yaw = s.yaw
	game.cam.snap_now()
	_instruction.show()
	_result.hide()
	_ui.show()
	_refresh_text()

func _refresh_text() -> void:
	_title.text = "ESCUELA DEL PACÍFICO · %d / %d · %s" % [lesson+1,LESSONS.size(),LESSONS[lesson].title]
	_task.text = LESSONS[lesson].task
	var input_hint: String = LESSONS[lesson].hint
	if not game.touch.visible:
		if lesson == 0: input_hint = "Cámara: %s o stick derecho del mando." % Controles.key_label("surf_camera")
		elif lesson in [1,2]: input_hint = "Remar: %s / X o RB. Orientación: WASD, flechas o stick." % Controles.key_label("surf_paddle")
		elif lesson == 3: input_hint = "Pararse: %s o A cuando tengas velocidad con la ola." % Controles.key_label("surf_stand")
	if lesson in [2,3] and game.surfer.can_stand: input_hint = "¡YA PUEDES PARARTE! " + input_hint
	_hint.text = input_hint
	_bar.value = progress*100.0

func _physics_process(delta: float) -> void:
	if not active or finished or get_tree().paused or game.mode != Game.Mode.PLAY: return
	var s := game.surfer
	if s.state == Surfer.State.WIPEOUT: return
	var traveled := s.global_position.distance_to(_previous_position)
	var yaw_step := absf(wrapf(s.yaw-_previous_yaw,-PI,PI))
	_previous_position = s.global_position
	_previous_yaw = s.yaw
	match lesson:
		0:
			if Ajustes.camera_view != _initial_camera: complete()
		1:
			if s.state == Surfer.State.PRONE and s.paddling and s.speed() > 0.5: _distance += traveled
			progress = clampf(_distance/3.0,0,1)
			if _distance >= 3.0: complete()
		2:
			_saw_ready = _saw_ready or (s.can_stand and s.paddling)
			if _saw_ready: complete()
		3:
			_saw_popup = _saw_popup or s.state == Surfer.State.POPUP
			if _saw_popup and s.state == Surfer.State.RIDING: complete()
		4:
			_stable = _stable+delta if s.state == Surfer.State.RIDING and absf(s.balance)<0.55 and s.speed()>3.0 else 0.0
			progress = clampf(_stable/4.0,0,1)
			if _stable >= 4.0: complete()
		5:
			if s.state == Surfer.State.RIDING and s.speed()>3.0:
				_distance += traveled
				if absf(s.carve)>0.25: _turn += yaw_step
			progress = minf(clampf(_turn/0.45,0,1),clampf(_distance/4.0,0,1))
			if _turn>=0.45 and _distance>=4.0: complete()
		6:
			progress = clampf(s.ride_distance/100.0,0,0.95)
	_refresh_text()

func ride_ended(success: bool, title: String, detail: String) -> void:
	if not active or finished: return
	if lesson == 6 and success: complete()
	else: _show_result(false,title+". "+detail)

func missed_wave() -> void:
	if active and not finished: _show_result(false,"La ola pasó. Reintenta y empieza a remar un poco antes.")

func complete() -> void:
	if not active or finished: return
	progress = 1.0
	if not completed.has(lesson):
		completed.append(lesson)
		save_progress()
	_show_result(true,"Objetivo conseguido. Puedes repetir o seguir con la siguiente lección.")

func _show_result(success: bool, detail: String) -> void:
	finished = true
	_instruction.hide()
	_result_title.text = "¡LO TIENES!" if success else "VAMOS OTRA VEZ"
	_result_detail.text = detail
	_next.visible = success and lesson < LESSONS.size()-1
	_result.show()
	game.surfer.tricks.cancel_input()
	game.touch.active = false
	game.touch._release_all()
	game.touch.hide()
	get_tree().paused = true
	(_next if _next.visible else _retry).grab_focus()

func retry() -> void:
	get_tree().paused = false
	start(lesson)

func cancel() -> void:
	active = false
	finished = false
	_ui.hide()
	get_tree().paused = false
	game.hud.set_school_mode(false)
	game.touch._release_all()
	game.session.setup(game.spot,Ajustes.session_condition)

func choose_lessons() -> void:
	cancel()
	game.to_menu()
	game.menus.open("school","main")

func _build_ui() -> void:
	_ui = Control.new()
	_ui.name = "SchoolOverlay"
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.get_node("UI").add_child(_ui)
	_instruction = UiKit.panel(Color(UiKit.NIGHT,0.88),14,Color(UiKit.TURQUOISE,0.55),14)
	_instruction.position = Vector2(18,90)
	_instruction.custom_minimum_size = Vector2(650,0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",4)
	_title = UiKit.label("",18,UiKit.TURQUOISE,UiKit.font_display())
	_task = UiKit.label("",24,UiKit.SAND,UiKit.font_title())
	_hint = UiKit.label("",17,UiKit.TEXT_DIM)
	for label in [_title,_task,_hint]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(label)
	_bar = UiKit.progress(0,UiKit.TURQUOISE,6)
	col.add_child(_bar)
	_instruction.add_child(col)
	_ui.add_child(_instruction)
	_result = Control.new()
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_result)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(UiKit.NIGHT,0.6)
	_result.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.add_child(center)
	var panel := UiKit.panel(Color(UiKit.NIGHT,0.96),18,Color(UiKit.SAND,0.15),24)
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.custom_minimum_size.x = 590
	body.add_theme_constant_override("separation",12)
	panel.add_child(body)
	body.add_child(UiKit.kicker("ESCUELA DEL PACÍFICO · MI PRIMERA OLA"))
	_result_title = UiKit.headline("",54)
	body.add_child(_result_title)
	_result_detail = UiKit.label("",20,UiKit.TEXT_DIM)
	_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_result_detail)
	_next = UiKit.button("SIGUIENTE LECCIÓN",true)
	_next.pressed.connect(func(): start(lesson+1))
	body.add_child(_next)
	_retry = UiKit.button("REPETIR / REINTENTAR")
	_retry.pressed.connect(retry)
	body.add_child(_retry)
	var exit := UiKit.button("ELEGIR LECCIÓN / SALIR")
	exit.pressed.connect(choose_lessons)
	body.add_child(exit)
	_ui.resized.connect(func():
		_instruction.size.x = minf(700,maxf(400,_ui.size.x-290)))
	_ui.hide()


func set_paused(on: bool) -> void:
	_instruction.visible = active and not finished and not on

func _input(event: InputEvent) -> void:
	if not active or not finished: return
	if event.is_action_pressed("ui_cancel"):
		choose_lessons()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("surf_restart"):
		retry()
		get_viewport().set_input_as_handled()
