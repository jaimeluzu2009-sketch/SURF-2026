extends Node
## --qa --academy-test [--spot=N]: las cinco lecciones de la academia se completan
## con pilotos que ejecutan la acción real (física y detectores del juego), y NO se
## completan sin hacerla (piloto pasivo que solo pulsa TRUCO).
var game: Game
var failures: Array[String] = []


func _ready() -> void:
	game = get_parent()
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("[academy] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in 6: await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://capturas/academia")
	get_viewport().get_texture().get_image().save_png("res://capturas/academia/%s.png" % name)


func along(s: Surfer, w: WaveModel, extra := 0.0) -> float:
	var err: float = float(s.last_sample.get("u", 0.0)) - w.front_width * 0.9
	var desired := PI * 0.5 * w.peel_dir + w.peel_dir * (clampf(err * 0.35, -0.75, 0.75) + extra)
	return clampf(-wrapf(desired - s.yaw, -PI, PI) * 2.2, -1, 1)


func pilot(lesson: int, active: bool, frames := 900) -> bool:
	var school := game.school
	school.start(lesson)
	await get_tree().physics_frame
	var s := game.surfer
	var w := game.wave
	var t := 0.0
	var shot_taken := false
	var seen: Array[String] = []
	var cb := func(r): seen.append(str(r.get("kind","")))
	s.maneuver_completed.connect(cb)
	var log_t := 0.0
	for i in frames:
		if school.finished: break
		t += 1.0 / 60.0
		var st := Vector2(along(s, w), 0.0)
		Controles.bot_impulse = false
		Controles.bot_trick = false
		if not active:
			# Pulsar TRUCO con correcciones suaves (sin giro marcado) no debe aprobar nada.
			Controles.bot_trick = i % 30 < 3
			st.x = clampf(st.x, -0.3, 0.3)
		else:
			match lesson:
				7: st.y = 1.0 if int(t / 0.3) % 2 == 0 else -1.0
				8:
					# Giro sostenido hacia la cresta (lado "arriba" = +peel_dir en el rumbo).
					if t <= 0.2: st.x = 0.0
					elif t > 0.2 and t < 1.1: st.x = w.peel_dir * -1.0
					elif t >= 1.1 and t < 1.4: st.x = 0.0
				9:
					if t <= 0.2: st.x = 0.0
					elif t > 0.2 and t < 1.1: st.x = w.peel_dir * 1.0
					elif t >= 1.1 and t < 1.4: st.x = 0.0
				11:
					# Mantener línea: rumbo un poco hacia la playa y peso centrado.
					st = Vector2(clampf(-wrapf(w.peel_dir * 1.16 - s.yaw, -PI, PI) * 2.2, -1, 1), -s.balance * 1.4)
				10:
					if s.state == Surfer.State.RIDING:
						var ready: bool = s.tricks.launch_available(s.last_sample)
						Controles.bot_impulse = not (ready and s.tricks.charge > 0.5)
					else:
						st = Vector2.ZERO
						if not shot_taken:
							shot_taken = true
							await shot("aereo")
		Controles.bot_stick = st
		if OS.has_environment("ACADEMY_LOG") and active and t - log_t > 0.25:
			log_t = t
			print("[academy] L%d t=%.2f st=%s ratio=%.2f vel=%.1f tubo=%s estado=%s" % [lesson, t, st, float(s.last_sample.get("u",0))/w.front_width, s.speed(), s.in_tube, Surfer.State.keys()[s.state]])
		await get_tree().physics_frame
	s.maneuver_completed.disconnect(cb)
	print("[academy] lección %d %s: maniobras %s, terminó=%s" % [lesson, "activa" if active else "pasiva", seen, school.finished])
	Controles.bot_stick = Vector2.ZERO
	Controles.bot_impulse = false
	Controles.bot_trick = false
	var ok := school.completed.has(lesson) and school.finished and school.progress >= 1.0
	if ok and lesson == 11: await shot("tubo")
	school.cancel()
	return ok


func run() -> void:
	Ajustes.persist = false
	Controles.bot_enabled = true
	game.school.persist = false
	for lesson in [7, 8, 9, 10, 11]:
		game.school.completed.clear()
		var passive := await pilot(lesson, false, 420)
		check(not passive, "%s: sin la acción real NO se aprueba" % SurfSchool.LESSONS[lesson].title)
		game.school.completed.clear()
		var done := await pilot(lesson, true)
		check(done, "%s: se aprueba al ejecutar la acción" % SurfSchool.LESSONS[lesson].title)
	Controles.bot_enabled = false
	print("[academy] RESULTADO ", "OK" if failures.is_empty() else "FALLOS: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
