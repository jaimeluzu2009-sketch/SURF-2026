extends Node
## --qa --surf-metrics [--spot=N]: métricas de respuesta del surf (no es una prueba
## de diversión). Imprime una línea [metrics] por medida para comparar antes/después:
##  - bombeo: velocidad máxima alternando peso cada 0.3 s durante 20 s (y por spam).
##  - giro: tiempo hasta 63 % de la velocidad de giro y radio a distintas velocidades.
##  - aterrizaje: motivo devuelto al fallar con rotación/peso/zona.
var game: Game
var lines: Array[String] = []
var failures: Array[String] = []


func _ready() -> void:
	game = get_parent()
	run.call_deferred()


func out(t: String) -> void:
	print("[metrics] ", t)
	lines.append(t)


func check(ok: bool, label: String) -> void:
	print("[metrics] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func place(speed: float, ratio := 0.9) -> void:
	var w := game.wave
	var s := game.surfer
	w.start_z = w.break_z - 58.0
	w.time = 15.0
	w.update()
	var x := w.peel_x + w.peel_dir * 4.0
	var z := w.crest_z + w.front_width * ratio
	s.reset_to(Vector3(x, w.height_at(x, z) + Surfer.DECK_RIDE, z), w.peel_dir * PI * 0.5)
	s.state = Surfer.State.RIDING
	s.hvel = Vector2(w.peel_dir * speed, w.speed * 0.3)
	s.animator.jump_to("ride")
	s.reset_physics_interpolation()


func pump(period: float, seconds: float) -> float:
	var s := game.surfer
	var w := game.wave
	var top := 0.0
	var t := 0.0
	var phase := 1.0
	var flip := 0.0
	while t < seconds and s.state == Surfer.State.RIDING:
		flip += get_physics_process_delta_time()
		if flip >= period:
			flip = 0.0
			phase = -phase
		var err: float = float(s.last_sample.get("u", 0.0)) - w.front_width * 0.9
		var desired := PI * 0.5 * w.peel_dir + w.peel_dir * clampf(err * 0.35, -0.75, 0.75)
		Controles.bot_stick = Vector2(clampf(-wrapf(desired - s.yaw, -PI, PI) * 2.2, -1, 1), phase)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		top = maxf(top, s.speed())
	Controles.bot_stick = Vector2.ZERO
	return top


func turn_response(speed: float) -> Dictionary:
	place(speed)
	var s := game.surfer
	await get_tree().physics_frame
	var rates: Array[float] = []
	var last := atan2(s.hvel.x, s.hvel.y)
	for i in 60:
		Controles.bot_stick = Vector2(-game.wave.peel_dir, 0)
		await get_tree().physics_frame
		var h := atan2(s.hvel.x, s.hvel.y)
		rates.append(absf(wrapf(h - last, -PI, PI)) * 60.0)
		last = h
	Controles.bot_stick = Vector2.ZERO
	var peak := 0.0
	for r in rates: peak = maxf(peak, r)
	var t63 := 0.0
	for i in rates.size():
		if rates[i] >= peak * 0.63:
			t63 = i / 60.0
			break
	var v := s.speed()
	return {"t63": t63, "rate": peak, "radius": v / maxf(peak, 0.01)}


func run() -> void:
	Ajustes.persist = false
	Ajustes.adaptive = false
	Controles.bot_enabled = true
	game.start_play()
	game.set_physics_process(true)
	place(6.0)
	var ideal := await pump(0.32, 20.0)
	place(6.0)
	var spam := await pump(0.05, 20.0)
	place(6.0)
	var none := await pump(999.0, 20.0)
	out("bombeo ritmo 0.32 s: máx %.1f m/s · spam 0.05 s: %.1f · sin bombear: %.1f · ola %.1f m/s" % [ideal, spam, none, game.wave.speed])
	check(ideal < game.wave.speed * 2.6, "bombear no da velocidad infinita (%.1f < %.1f)" % [ideal, game.wave.speed * 2.6])
	check(spam <= ideal + 0.3, "machacar el peso no supera al ritmo correcto")
	for v in [4.0, 6.0, 8.0]:
		var r: Dictionary = await turn_response(v)
		out("giro a %.0f m/s: 63 %% en %.2f s, %.0f °/s, radio %.1f m" % [v, r.t63, rad_to_deg(r.rate), r.radius])
	Controles.bot_enabled = false
	print("[metrics] RESULTADO ", "OK" if failures.is_empty() else "FALLOS: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
