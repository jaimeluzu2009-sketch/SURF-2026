extends Node
var game: Game
var failures: Array[String] = []
var autopilot := false
var folder := "res://capturas/escuela_pc"
func _ready() -> void:
	game = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()
func check(ok: bool, text: String) -> void:
	print("[school] ", "PASS " if ok else "FAIL ", text)
	if not ok: failures.append(text)
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in 8: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder+"/"+name+".png")
func _physics_process(_delta: float) -> void:
	if not autopilot or get_tree().paused: return
	var s := game.surfer
	var w := game.wave
	Controles.bot_stick = Vector2.ZERO
	if s.state == Surfer.State.PRONE:
		Controles.bot_paddle = s.global_position.z-w.crest_z < 13.0 and w.amp > 0.5
		if game.school.lesson == 1: Controles.bot_paddle = true
		Controles.bot_stick.x = clampf(wrapf(s.yaw,-PI,PI)*2.0,-1,1)
		if s.can_stand and game.school.lesson != 2: Controles.bot_stand()
	elif s.state in [Surfer.State.RIDING,Surfer.State.POPUP]:
		var sample := s.last_sample
		var err: float = sample["u"]-w.front_width*0.9
		var desired := PI*0.5*w.peel_dir+w.peel_dir*clampf(err*0.35,-0.75,0.75)
		if (s.global_position.x-w.peel_x)*w.peel_dir<5.0: desired-=w.peel_dir*0.2
		Controles.bot_stick = Vector2(clampf(-wrapf(desired-s.yaw,-PI,PI)*2.2,-1,1),clampf(-s.balance*1.6+(0.35 if s.speed()<4 else 0),-1,1))
		if game.school.lesson == 5: Controles.bot_stick.x = 0.55
func run() -> void:
	Ajustes.persist=false
	Ajustes.adaptive=false
	Ajustes.touch_mode=1
	Ajustes.apply()
	Engine.max_fps=0
	game.school.persist=false
	DirAccess.make_dir_recursive_absolute(folder)
	if "--school-layout" in OS.get_cmdline_user_args():
		await run_layout()
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	var profile_before := var_to_str([Perfil.xp,Perfil.records,Perfil.achievements])
	game.menus.open("school","main")
	await shot("seleccion_lecciones")
	check(game.menus._school_body.get_child_count()>=7,"selector de siete lecciones disponible")
	(game.menus._school_body.get_child(2) as Button).pressed.emit()
	check(game.school.active and game.school.lesson==2,"botón de lección inicia la práctica elegida")
	game.school.start(0)
	await shot("leccion_camara")
	for i in 3: await get_tree().physics_frame
	check(not game.school.finished,"lección cámara no se completa sin cambiar POV")
	game.cam.cycle_view()
	for i in 3: await get_tree().physics_frame
	check(game.school.completed.has(0),"lección cámara completada por cambio real de POV")
	await shot("objetivo_completado")
	Controles.bot_enabled=true
	autopilot=true
	for lesson in range(1,7):
		game.school.start(lesson)
		var max_frames := 2400 if lesson == 6 else 1000
		for frame in max_frames:
			await get_tree().physics_frame
			if game.school.finished: break
		print("[school] lección ",lesson," estado=",game.surfer.state," avance=",game.school.progress)
		check(game.school.completed.has(lesson),"lección %d completada con piloto y física real"%lesson)
		if lesson == 3: await shot("incorporacion_aprendida")
	autopilot=false
	Controles.bot_enabled=false
	check(profile_before == var_to_str([Perfil.xp,Perfil.records,Perfil.achievements]),"escuela no modifica XP, récords ni logros de carrera")
	game.school.persist=true
	game.school.save_progress()
	game.school.completed.clear()
	game.school.load_progress()
	check(game.school.completed.size()==7,"progreso escolar se guarda y recupera de archivo aislado")
	game.school.persist=false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.school.progress_path()))
	game.school.start(4)
	game.pause()
	check(not game.school._instruction.visible,"pausa oculta instrucción escolar")
	var stable_before := game.school._stable
	for i in 10: await get_tree().process_frame
	check(is_equal_approx(game.school._stable,stable_before),"pausa no cuenta como equilibrio")
	game.resume()
	check(game.school._instruction.visible,"reanudar restaura instrucción escolar")
	game.surfer._wipeout("Prueba de caída","Reintenta sin penalización.")
	for i in 180:
		await get_tree().physics_frame
		if game.school.finished: break
	check(game.school.finished and get_tree().paused,"caída abre reintento escolar")
	game.school.retry()
	check(not game.school.finished and not get_tree().paused and game.surfer.state==Surfer.State.RIDING,"reintento restaura checkpoint de equilibrio")
	game.school.choose_lessons()
	check(not game.school.active and not game.hud.school_active and not get_tree().paused,"salir restaura modo normal y HUD")
	game.menus.close()
	game.start_play()
	game.set_physics_process(false)
	game.set_process(false)
	game.cam.set_process(false)
	game.surfer.set_frozen(true)
	var s := game.surfer
	var w := game.wave
	s.reset_to(Vector3(0,w.height_at(0,-43),-43),0)
	var player := s.get_node("Rider/SurferModel").find_child("AnimationPlayer",true,false) as AnimationPlayer
	s.animator.tree.active=false
	player.play("paddle")
	player.seek(0.16,true)
	s.animator.skeleton.force_update_all_bone_transforms()
	s._update_visual(0,w.sample(0,-43))
	s.reset_physics_interpolation()
	s.rider.reset_physics_interpolation()
	Ajustes.camera_view=1
	game.cam.mode=CameraRig.Mode.FOLLOW
	game.cam.snap_now()
	for i in 120: game.cam._process(1.0/60)
	game.hud._hint_time=0
	game.hud.update_state(s,w,game.score,0.0)
	check(not game.hud.get_node("ChallengesPanel").visible,"primera persona despeja la vista de los brazos")
	check(game.cam._fp_body != null and game.cam._fp_body.visible,"cuerpo de primera persona conserva brazos visibles")
	check(game.cam._fp_body.skin == (s.get_node("Rider/SurferModel").find_child("Surfer",true,false) as MeshInstance3D).skin,"brazos comparten skin y animación originales")
	await shot("primera_persona_remando")
	player.seek(0.65,true)
	s.animator.skeleton.force_update_all_bone_transforms()
	for i in 10: game.cam._process(1.0/60)
	await shot("remada_segunda_fase")
	for style in 4:
		Perfil.set_style(style)
		for outfit in 2:
			Perfil.set_outfit(outfit)
			game.cam._process(0.0)
			var filtered := game.cam._fp_body.mesh
			var count := 0
			for surface in filtered.get_surface_count(): count += (filtered.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
			check(count>500 and count<20000,"brazos sin cabeza/torso, apariencia %d/%d (%d triángulos)"%[style,outfit,count])
	Perfil.set_style(0)
	Perfil.set_outfit(0)
	s.animator.tree.active=true
	# Reproducible absolute tumble, independent of simulation step rate.
	var ends: Array[Quaternion] = []
	for hz in [30,60,120]:
		s.reset_to(Vector3(0,1,0),0.4)
		s.state=Surfer.State.RIDING
		s.rider.global_basis=Basis(Vector3.UP,0.4)
		s.hvel=Vector2(5,5)
		s._wipeout("QA","QA")
		var previous := s.rider.global_basis.get_rotation_quaternion()
		var accumulated := 0.0
		for frame in int(2.0*hz):
			s._state_time=float(frame+1)/hz
			s._do_after(1.0/hz,w.sample(s.global_position.x,s.global_position.z))
			var current := s.rider.global_basis.get_rotation_quaternion()
			accumulated += previous.angle_to(current)
			previous=current
		ends.append(previous)
		check(accumulated<2.5,"caída sin vueltas acumuladas a %d Hz (%.3f rad)"%[hz,accumulated])
	check(ends[0].angle_to(ends[2])<0.01,"orientación final de caída independiente de FPS")
	# Real native fullscreen transition, restoring window state afterwards.
	if DisplayServer.get_name() != "headless":
		Engine.max_fps=60
		var window := get_window()
		var old_size := window.size
		var old_pos := window.position
		var fullscreen_event := InputEventKey.new()
		fullscreen_event.physical_keycode = KEY_F11
		fullscreen_event.pressed = true
		Ajustes._unhandled_input(fullscreen_event)
		for i in 20: await get_tree().process_frame
		check(window.mode==Window.MODE_FULLSCREEN,"F11 activa pantalla completa nativa")
		print("[school] resolución completa=",window.size," framebuffer=",get_viewport().get_texture().get_size()," escala3D=",Ajustes.render_scale)
		var window_event := InputEventKey.new()
		window_event.physical_keycode = KEY_ENTER
		window_event.alt_pressed = true
		window_event.pressed = true
		Ajustes._unhandled_input(window_event)
		for i in 20: await get_tree().process_frame
		check(window.mode==Window.MODE_WINDOWED,"Alt+Enter regresa a ventana")
		window.size=old_size
		window.position=old_pos
	print("[school] RESULTADO ","OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func run_layout() -> void:
	folder="res://capturas/escuela_pc_576"
	DirAccess.make_dir_recursive_absolute(folder)
	game.menus.open("main")
	await shot("menu_escuela")
	game.menus.open("school","main")
	await shot("lecciones")
	check(game.menus._school_body.size.x <= game.menus.size.x,"lista escolar adaptable")
	game.school.start(4)
	game.surfer.set_frozen(true)
	await shot("practica_equilibrio")
	check(game.school._instruction.get_global_rect().end.x < game.hud.size.x,"consigna escolar cabe en pantalla")
	game.school.complete()
	await shot("resultado")
	check(game.school._retry.get_global_rect().end.y <= game.hud.size.y,"reintento accesible en formato bajo")
	await click_button(game.school._next)
	check(game.school.lesson==5 and not game.school.finished and not get_tree().paused,"clic real SIGUIENTE funciona con juego pausado")
	game.school.complete()
	await click_button(game.school._retry)
	check(game.school.lesson==5 and not game.school.finished and not get_tree().paused,"clic real REINTENTAR restaura práctica")
	game.school.complete()
	var exit_event := InputEventKey.new()
	exit_event.physical_keycode=KEY_ESCAPE
	exit_event.keycode=KEY_ESCAPE
	exit_event.pressed=true
	game.school._input(exit_event)
	check(not game.school.active and game.menus.current()=="school","Esc desde resultado vuelve al selector escolar")
	game.menus.open("settings","main")
	game.menus.select_tab("settings",0)
	await shot("ajustes_pantalla")
	print("[school-layout] RESULTADO ","OK" if failures.is_empty() else failures)


func click_button(button: Button) -> void:
	for i in 3: await get_tree().process_frame
	var point := get_viewport().get_final_transform()*button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.pressed=pressed
		Input.parse_input_event(event)
		for i in 2: await get_tree().process_frame
