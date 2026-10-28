extends Node
## Bot de pruebas: juega solo para comprobar que la ola se puede surfear.
## Se activa con argumentos de usuario al lanzar la escena principal:
##   godot --path . -- --bot [--runs=3] [--shots=CARPETA] [--perf] [--quality=N]
## Imprime una línea "[bot]" por cada ola y un resumen final, y cierra el juego.

var game: Node
var surfer: Surfer
var wave: WaveModel
var runs := 3
var shots_dir := ""
var perf := false
var _run := 0
var _results := []
var _t := 0.0
var _log_t := 0.0
var _ride_t := 0.0
var _shots_taken := {}
var _perf_q := -1
var _perf_t := 0.0
var _perf_frames := 0
var _perf_out := []
var _done := false


func setup(g: Node, args: PackedStringArray) -> void:
	game = g
	surfer = g.surfer
	wave = g.wave
	Ajustes.persist = false
	for a in args:
		if a.begins_with("--runs="):
			runs = int(a.get_slice("=", 1))
		elif a.begins_with("--shots="):
			shots_dir = a.get_slice("=", 1)
		elif a == "--perf":
			perf = true
		elif a.begins_with("--quality="):
			Ajustes.set_quality(int(a.get_slice("=", 1)))
	Controles.bot_enabled = true
	if "--materials" in args:
		for mi in surfer.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for i in m.get_surface_override_material_count():
				var om := m.get_surface_override_material(i) as StandardMaterial3D
				if om:
					print("[mat] %s/%d rough=%.2f normal=%s tex=%s" % [m.name, i, om.roughness, om.normal_enabled,
						om.normal_texture != null])
	surfer.ride_ended.connect(_on_end)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var st := Vector2.ZERO
	match surfer.state:
		Surfer.State.PRONE:
			var gap := surfer.global_position.z - wave.crest_z
			Controles.bot_paddle = gap < 13.0 and wave.amp > 0.5
			st.x = clampf(wrapf(surfer.yaw, -PI, PI) * 2.0, -1.0, 1.0)
			if surfer.can_stand:
				Controles.bot_stand()
		Surfer.State.RIDING, Surfer.State.POPUP:
			_ride_t += delta
			var s := surfer.last_sample
			var err: float = s["u"] - wave.front_width * 0.9
			var ahead := (surfer.global_position.x - wave.peel_x) * wave.peel_dir
			# Rumbo a lo largo de la ola; más hacia arriba (mar) si va bajo en la cara.
			var dir := wave.peel_dir
			var desired := PI * 0.5 * dir + dir * clampf(err * 0.35, -0.75, 0.75)
			if ahead < 5.0:
				desired -= dir * 0.2
			var e := wrapf(desired - surfer.yaw, -PI, PI)
			st.x = clampf(-e * 2.2, -1.0, 1.0)
			st.y = clampf(-surfer.balance * 1.6 + (0.35 if surfer.speed() < 4.0 else 0.0), -1.0, 1.0)
	Controles.bot_stick = st
	_log_t += delta
	if _log_t >= 1.0:
		_log_t = 0.0
		var s2 := surfer.last_sample
		print("[bot] t=%.1f estado=%s u=%.1f vel=%.1f eq=%.2f ahead=%.1f cresta=%.1f" % [_t,
			Surfer.State.keys()[surfer.state], s2.get("u", 0.0), surfer.speed(), surfer.balance,
			(surfer.global_position.x - wave.peel_x) * wave.peel_dir, wave.crest_z])


func _process(delta: float) -> void:
	if shots_dir != "":
		_maybe_shot()
	if perf:
		_perf_step(delta)


var _cape_shot := false
var _detail_shot := false
var _busy := false


## Captura desde una cámara fija con el juego congelado (para comparar antes/después).
func _fixed_shot(file: String, pos: Vector3, look: Vector3) -> void:
	_busy = true
	var cam: CameraRig = game.cam
	cam.surfer = null
	Engine.time_scale = 0.0
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	for i in 4:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(file))
	Engine.time_scale = 1.0
	cam.surfer = surfer
	cam.snap_now()
	_busy = false


func _maybe_shot() -> void:
	if _busy:
		return
	if not _cape_shot and _t > 1.5:
		_cape_shot = true
		var side := -wave.peel_dir  # el cabo está del lado de donde viene la rotura
		_fixed_shot("9_cabo.png", Vector3(-10.0 * side, 6.0, 20.0), Vector3(45.0 * side, 4.0, 60.0))
		return
	if not _detail_shot and _ride_t > 2.5:
		# Primer plano del surfista y la tabla desde el lado de la playa.
		_detail_shot = true
		var p := surfer.global_position
		_fixed_shot("8_detalle.png", p + Vector3(-1.6 * wave.peel_dir, 1.3, 2.6), p + Vector3(0, 0.8, 0))
		return
	var wanted := {"0_espera": _t > 3.0, "1_remando": surfer.paddling and surfer.state == Surfer.State.PRONE,
		"2_de_pie": surfer.state == Surfer.State.POPUP and surfer._state_time > 0.3,
		"3_surf": _ride_t > 3.0, "4_surf_tarde": _ride_t > 8.0,
		"5_fin": surfer.state == Surfer.State.WIPEOUT and surfer._state_time > 1.0}
	for key in wanted:
		if wanted[key] and not _shots_taken.has(key):
			_shots_taken[key] = true
			DirAccess.make_dir_recursive_absolute(shots_dir)
			var img := get_viewport().get_texture().get_image()
			img.save_png(shots_dir.path_join("%s.png" % key))


func _perf_step(delta: float) -> void:
	if surfer.state != Surfer.State.RIDING and _perf_q < 0:
		return
	if _perf_q < 0:
		_perf_q = 0
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Ajustes.adaptive = false
		Ajustes.set_quality(0)
		Engine.max_fps = 0
	_perf_t += delta
	_perf_frames += 1
	if _perf_t >= 4.0:
		_perf_out.append("%s: %.0f FPS (%.2f ms)" % [Ajustes.preset()["name"], _perf_frames / _perf_t,
			1000.0 * _perf_t / _perf_frames])
		_perf_t = 0.0
		_perf_frames = 0
		_perf_q += 1
		if _perf_q > 2:
			print("[perf] ", " | ".join(_perf_out))
			perf = false
		else:
			Ajustes.set_quality(_perf_q)
			Engine.max_fps = 0


func _on_end(success: bool, title: String, detail: String) -> void:
	_run += 1
	var line := "%s: %s — %s (de pie %.1f s, %d m, máx %d km/h)" % ["OK" if success else "FALLO", title, detail,
		surfer.ride_time, int(surfer.ride_distance), int(surfer.top_speed * 3.6)]
	_results.append(line)
	print("[bot] ola %d → %s" % [_run, line])
	if _run >= runs and not perf:
		_finish()
	else:
		await get_tree().create_timer(0.5).timeout
		_ride_t = 0.0
		game.restart()


func _finish() -> void:
	_done = true
	var ok := _results.filter(func(r): return r.begins_with("OK")).size()
	print("[bot] RESUMEN: %d de %d olas completadas" % [ok, _results.size()])
	get_tree().quit(0)
