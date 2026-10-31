extends Node
var game: Game
var failures: Array[String] = []
func _ready() -> void:
	game = get_parent()
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("[tube-touch] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in 8: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://capturas/tubo_controles/"+name+".png")
func touch_at(id: int, local: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = id
	ev.position = game.touch.get_global_transform_with_canvas() * local
	ev.pressed = down
	game.touch._input(ev)
func run() -> void:
	Ajustes.persist = false
	Ajustes.adaptive = false
	Ajustes.touch_mode = 1
	Ajustes.touch_opacity = 0.8
	Ajustes.apply()
	DirAccess.make_dir_recursive_absolute("res://capturas/tubo_controles")
	game.start_play()
	game.set_physics_process(false)
	game.set_process(false)
	game.cam.set_process(false)
	var s := game.surfer
	var w := game.wave
	Spots.apply_to_wave(Spots.get_spot(1),w)
	game.hud.set_spot(Spots.get_spot(1))
	w.time=15.0
	w.update()
	var x:=w.peel_x+w.peel_dir*2.5
	var sec:=w.tube_section(x)
	var z:float=sec["z"]
	s.reset_to(Vector3(x,w.height_at(x,z)+0.045,z),PI*0.5*w.peel_dir)
	s.set_frozen(true)
	s.state=Surfer.State.RIDING
	s.in_tube=true
	s.hvel=Vector2(w.peel_dir*8.0,w.speed)
	s._update_visual(0.0,w.sample(x,z))
	s.animator.jump_to("ride")
	s.animator.tube_compression=0.9
	s.animator.set_motion(8,0,true)
	for i in 100:
		s.animator._process(1.0/60.0)
		s.animator.tree.advance(1.0/60.0)
	game.water.sync(w.time)
	game.hud.update_state(s,w,game.score,0.0)
	game.hud.set_hint_lane(game.touch.hint_lane())
	game.barrel._timer=0.0
	game.barrel.sync(w.time,0.1)
	game.touch.active=true
	game.touch.set_riding_context(true)
	game.touch.tube_context=true
	game.touch.trick_ready=true
	check(WaveModel.tube_roof(sec,z-float(sec["rz"])*0.5)>WaveModel.tube_roof(sec,z+float(sec["rz"])*0.5),"arco interior asimétrico")
	Ajustes.camera_view=1
	game.cam.mode=CameraRig.Mode.FOLLOW
	game.cam.snap_now()
	for i in 120: game.cam._process(1.0/60.0)
	game.touch._process(0)
	await shot("interior_primera")
	Ajustes.camera_view=0
	game.cam.snap_now()
	for i in 120: game.cam._process(1.0/60.0)
	await shot("interior_tercera")
	game.touch.tube_context=false
	game.touch.launch_ready=true
	game.touch.impulse_charge=0.18
	check(not game.touch.release_ready(),"no anuncia salida con carga insuficiente")
	game.touch.impulse_charge=0.75
	check(game.touch.release_ready(),"anuncia soltar con carga y lanzamiento disponibles")
	game.touch.launch_ready=false
	check(not game.touch.release_ready(),"cargar no garantiza despegue fuera del labio")
	s.tricks._cooldown=1.0
	check(not s.tricks.launch_available(w.sample(x,z)),"cooldown impide disponibilidad de salto")
	s.tricks._cooldown=0
	game.touch.launch_ready=true
	game.touch.tube_context=false
	game.touch.impulse_charge=0.75
	await shot("botones_carga")
	var old_paddle:=game.touch._paddle_c
	var old_stand:=game.touch._stand_c
	Ajustes.touch_opacity=0.35
	Ajustes.apply()
	check(is_equal_approx(game.touch.self_modulate.a,0.35),"opacidad visual al 35 por ciento")
	check(old_paddle.is_equal_approx(game.touch._paddle_c) and old_stand.is_equal_approx(game.touch._stand_c),"opacidad conserva áreas táctiles")
	await shot("opacidad_35")
	Ajustes.touch_opacity=0.65
	Ajustes.persist=true
	Ajustes._save()
	Ajustes.touch_opacity=1.0
	Ajustes._load()
	Ajustes.persist=false
	check(is_equal_approx(Ajustes.touch_opacity,0.65),"opacidad se guarda y recupera en archivo aislado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.config_path()))
	for left in [false,true]:
		Ajustes.left_handed=left
		Ajustes.apply()
		game.touch.set_riding_context(true)
		touch_at(3,game.touch._paddle_c,true)
		touch_at(4,game.touch._stand_c,true)
		check(Controles.touch_paddle and Controles.touch_trick,"dos botones simultáneos, zurdo=%s"%left)
		touch_at(3,game.touch._paddle_c,false)
		check(not Controles.touch_paddle and Controles.touch_trick,"soltar impulso no suelta truco, zurdo=%s"%left)
		touch_at(4,game.touch._stand_c,false)
		check(not Controles.touch_trick,"truco libera su propio dedo, zurdo=%s"%left)
	Ajustes.left_handed=false
	Ajustes.touch_opacity=0.8
	Ajustes.apply()
	game.touch.set_riding_context(false)
	game.touch.stand_ready=false
	await shot("botones_remada")
	print("[tube-touch] RESULTADO ","OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
