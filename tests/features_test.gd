extends Node
var game: Game
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	print("[features] ", "OK " if value else "FAIL ", message)
	if not value:
		failures.append(message)
func _ready() -> void:
	game = get_parent()
	call_deferred("run")
func run() -> void:
	Ajustes.persist = false
	for c in 3:
		var session := SurfSession.new()
		session.setup(Spots.get_spot(1), c)
		var w := WaveModel.new()
		session.next(w)
		var first := w.height
		var wait_z := w.start_z
		session.next(w)
		check(not is_equal_approx(first, w.height) and wait_z < w.start_z, "serie y pausa condición %d" % c)
		check(is_equal_approx(w.tide, float(SurfSession.PRESETS[c]["tide"])), "marea aplicada %d" % c)
	game.start_play()
	var s := game.surfer
	var w := game.wave
	Controles.bot_enabled = true
	s.hvel = Vector2(0, 4.4)
	var early := {"normal": Vector3.UP, "flow": 0.0, "u": 1.0, "profile": 0.2, "broken": 0.0}
	Controles.bot_stand()
	s._do_prone(0.016, early)
	check(s.state == Surfer.State.PRONE and s._stand_buffer > 0.0, "pulsación anticipada se conserva")
	early["profile"] = 0.8
	s._do_prone(0.016, early)
	check(s.state == Surfer.State.POPUP, "pulsación anticipada inicia incorporación al coger la ola")
	Spots.apply_to_wave(Spots.get_spot(1), w)
	w.time = 15.0
	w.update()
	var section := w.tube_section(w.peel_x + w.peel_dir * 1.5)
	check(section["active"], "labio activo en La Rinconada")
	var x := w.peel_x + w.peel_dir * 1.5
	var z: float = section["z"]
	s.reset_to(Vector3(x, w.height_at(x, z) + 0.045, z), PI * 0.5 * w.peel_dir)
	s.state = Surfer.State.RIDING
	s.hvel = Vector2(w.peel_dir * 9.0, w.speed)
	s.animator.jump_to("ride")
	Controles.bot_enabled = true
	if "--capture" in OS.get_cmdline_user_args():
		await capture_tube()
	var entered := false
	for frame in 240:
		var desired := w.peel_dir * 1.16
		Controles.bot_stick = Vector2(clampf(-wrapf(desired - s.yaw, -PI, PI) * 2.2, -1.0, 1.0), -s.balance * 1.4)
		await get_tree().physics_frame
		entered = entered or s.in_tube
		if s.tube_exits > 0 or s.state == Surfer.State.WIPEOUT:
			break
	check(entered, "entrada real al tubo")
	check(s.tube_exits > 0, "salida con movimiento real y bonus")
	print("[features] tubo=", s.tube_seconds, " salidas=", s.tube_exits, " estado=", s.state, " puntos=", game.score.score)
	check(game.score.tube_time > 0.0, "tiempo del tubo puntúa")
	game.surfer.set_frozen(true)
	w.time = 15.0
	w.update()
	x = w.peel_x + w.peel_dir * 1.5
	section = w.tube_section(x)
	z = section["z"] - section["rz"] * 0.88
	s.reset_to(Vector3(x, w.height_at(x, z) + 0.05, z), 0.0)
	s.state = Surfer.State.RIDING
	s._update_tube(0.25)
	check(s.state == Surfer.State.WIPEOUT, "colisión con labio provoca caída")
	check(game.surf_audio.sea.playing, "audio ambiente reproduciéndose")
	check(AudioServer.get_bus_index("SurfSea") >= 0, "filtro de audio del tubo conectado")
	for outfit in 2:
		Perfil.set_outfit(outfit)
		check(s._summer_mesh != null and s._winter_mesh != null, "ropa disponible %d" % outfit)
	game.mode = Game.Mode.PLAY
	game.pause()
	game.resume()
	print("[features] RESULTADO: ", "OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func capture_tube() -> void:
	game.set_physics_process(false)
	game.surfer.set_frozen(true)
	Perfil.set_outfit(1)
	var camera := game.cam
	camera.surfer = null
	var p := game.surfer.global_position
	var folder := "res://capturas/seis_mejoras"
	DirAccess.make_dir_recursive_absolute(folder)
	game.barrel._timer = 0.0
	game.barrel.sync(game.wave.time, 0.1)
	for shot in ["tubo_exterior", "tubo_interior"]:
		var pos := p + Vector3(-game.wave.peel_dir * 5.5, 2.5, 6.0)
		var target := p + Vector3(0, 0.9, 0)
		if shot == "tubo_interior":
			pos = p - Vector3(game.wave.peel_dir * 2.5, -0.8, 0)
			target = p + Vector3(game.wave.peel_dir * 3.0, 0.8, 0)
		camera.look_at_from_position(pos, target)
		for i in 12:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder.path_join(shot + ".png"))
	camera.surfer = game.surfer
	camera.snap_now()
	game.set_physics_process(true)
	game.surfer.set_frozen(false)
