extends Node
var game: Game
var failures: Array[String] = []
func _ready() -> void:
	game = get_parent()
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("[camera-motion] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in 8: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://capturas/camaras_movimiento/" + name + ".png")
func run() -> void:
	Ajustes.persist = false
	Ajustes.adaptive = false
	Ajustes.touch_mode = 1
	Ajustes.apply()
	DirAccess.make_dir_recursive_absolute("res://capturas/camaras_movimiento")
	game.start_play()
	game.set_physics_process(false)
	game.cam.set_process(false)
	var s := game.surfer
	var w := game.wave
	Spots.apply_to_wave(Spots.get_spot(1), w)
	game.hud.set_spot(Spots.get_spot(1))
	w.time = 15.0
	w.update()
	var x := w.peel_x + w.peel_dir * 2.5
	var sec := w.tube_section(x)
	var z: float = sec["z"]
	s.reset_to(Vector3(x,w.height_at(x,z)+0.045,z),PI*0.5*w.peel_dir)
	s.set_frozen(true)
	s.state = Surfer.State.RIDING
	s.in_tube = true
	s.hvel = Vector2(w.peel_dir*8.0,w.speed)
	s._update_visual(0.0,w.sample(x,z))
	s.animator.jump_to("ride")
	s.animator.set_motion(8,0,true,0.3,0.5)
	s.animator.tube_compression = 1.0
	for i in 120:
		s.animator._process(1.0/60.0)
		s.animator.tree.advance(1.0/60.0)
	check(s.animator._tuck > 0.98,"compresión completa con techo bajo")
	s.animator.tube_compression = 0.0
	for i in 120: s.animator._process(1.0/60.0)
	check(s.animator._tuck < 0.67,"postura menos comprimida con espacio libre")
	game.barrel._timer = 0.0
	game.barrel.sync(w.time,0.1)
	await get_tree().process_frame
	game.touch._process(0.0)
	for view in 3:
		Ajustes.camera_view = view
		game.cam.mode = CameraRig.Mode.FOLLOW
		game.cam.snap_now()
		for i in 120: game.cam._process(1.0/60.0)
		check(game.cam.global_position.is_finite(),"cámara finita modo %d"%view)
		check(game.cam.global_position.y >= w.height_at(game.cam.global_position.x,game.cam.global_position.z),"cámara fuera del agua modo %d"%view)
		var body := s.get_node("Rider/SurferModel").find_child("Surfer",true,false) as MeshInstance3D
		check(body.visible == (view != 1),"visibilidad del cuerpo modo %d"%view)
		await shot(["tercera","primera","frontal"][view])
	game.cam.mode = CameraRig.Mode.SHOWCASE
	Ajustes.camera_view = 1
	game.cam._process(1.0/60.0)
	check((s.get_node("Rider/SurferModel").find_child("Surfer",true,false) as MeshInstance3D).visible,"cuerpo restaurado al personalizar")
	game.cam.mode = CameraRig.Mode.FOLLOW
	Ajustes.camera_view = 2
	game.cam.cycle_view()
	check(Ajustes.camera_view == 0,"ciclo frontal a tercera persona")
	game.touch._camera_button.pressed.emit()
	check(Ajustes.camera_view == 1,"botón táctil cambia cámara")
	Ajustes.camera_view = 0
	game.mode = Game.Mode.PLAY
	var camera_event := InputEventJoypadButton.new()
	camera_event.button_index = JOY_BUTTON_RIGHT_STICK
	camera_event.pressed = true
	game._unhandled_input(camera_event)
	check(Ajustes.camera_view == 1,"mando cambia cámara por evento real InputMap")
	check(InputMap.event_is_action(camera_event,"surf_camera"),"stick derecho registrado")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	check(InputMap.event_is_action(a,"surf_stand"),"botón A conectado a pararse/truco")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	check(InputMap.event_is_action(b,"ui_cancel"),"botón B conectado a volver")
	var connected := Input.get_connected_joypads()
	Controles._pad_connection(-1,false)
	if not connected.is_empty():
		check(game.mode == Game.Mode.PLAY,"no pausa mientras queda un mando conectado")
		Controles.gamepad_lost.emit() # Simular la pérdida final sin desconectar hardware real.
	check(game.mode == Game.Mode.PAUSE,"señal de pérdida del último mando pausa la partida")
	game.resume()
	check(game.mode == Game.Mode.PLAY,"reanudar después de desconexión")
	Ajustes.camera_view = 0
	s.in_tube = false
	game.cam.mode = CameraRig.Mode.FOLLOW
	game.cam.snap_now()
	s.animator.set_motion(8,0.4,false,0.4,1.0)
	s.animator.set_ride_blend(0.9,0.1)
	for i in 120:
		s.animator._process(1.0/60.0)
		s.animator.tree.advance(1.0/60.0)
	game.cam.look_at_from_position(s.global_position+Vector3(-w.peel_dir*3.0,1.6,3.0),s.global_position+Vector3.UP*0.8)
	await shot("postura_giro")
	print("[camera-motion] RESULTADO ", "OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
