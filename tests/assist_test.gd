extends Node
## --qa --assist-test [--spot=N]: compara un jugador principiante simulado con y sin
## modo asistido usando la entrada real (joystick táctil y botón PARARSE), no el bot.
## El principiante pulsa PARARSE a menudo, rema solo si NO hay asistencia y gira
## hacia el hombro sin corregir el equilibrio. También comprueba la curva del joystick.
var game: Game
var failures: Array[String] = []
var results := {}


func _ready() -> void:
	game = get_parent()
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("[assist] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func run() -> void:
	Ajustes.persist = false
	Ajustes.adaptive = false
	Controles.bot_enabled = false
	# Curva: con respuesta suave medio recorrido gira bastante menos que el máximo.
	Ajustes.stick_deadzone = 0.0
	for r in 3:
		Ajustes.stick_response = r
		Controles.touch_stick = Vector2(0.5, 0)
		print("[assist] respuesta %s: joystick 50 %% -> giro %.2f" % [Ajustes.STICK_RESPONSES[r], Controles.stick().x])
	Ajustes.stick_response = 0
	Controles.touch_stick = Vector2(1, 0)
	check(is_equal_approx(Controles.stick().x, 1.0), "el borde del joystick sigue dando giro máximo")
	Controles.touch_stick = Vector2.ZERO
	Ajustes.stick_response = 1
	Ajustes.stick_deadzone = 0.15
	game.start_play()
	for assist in [false, true]:
		Ajustes.assist = assist
		var rides: Array[float] = []
		var stood := 0
		var completed := 0
		for attempt in 3:
			var r: Dictionary = await novice_wave()
			rides.append(r.ride)
			stood += int(r.stood)
			completed += int(r.ok)
			print("[assist] asistido=%s intento %d: de pie=%s, %.1f s, %s" % [assist, attempt + 1, r.stood, r.ride, r.title])
		var avg := 0.0
		for v in rides: avg += v
		avg /= rides.size()
		results[assist] = {"stood": stood, "avg": avg, "ok": completed}
		print("[assist] asistido=%s: se puso de pie %d/3, completó %d/3, media de pie %.1f s" % [assist, stood, completed, avg])
	check(results[true].stood >= results[false].stood, "asistido se pone de pie al menos igual de veces")
	check(results[true].stood >= 2, "asistido: el principiante se pone de pie en 2 de 3 olas o más")
	check(results[true].avg >= results[false].avg, "asistido: aguanta de pie al menos lo mismo")
	Ajustes.assist = false
	print("[assist] RESULTADO ", "OK" if failures.is_empty() else "FALLOS: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


func novice_wave() -> Dictionary:
	game.restart()
	var s := game.surfer
	var w := game.wave
	var ended := [false, false, ""]
	var cb := func(ok, title, d):
		ended[0] = true
		ended[1] = ok
		ended[2] = "%s (%s)" % [title, d]
	s.ride_ended.connect(cb)
	var stood := false
	var tap := 0.0
	var t := 0.0
	while not ended[0] and t < 45.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		match s.state:
			Surfer.State.PRONE:
				Controles.touch_stick = Vector2.ZERO
				Controles.touch_paddle = (not Ajustes.assist) and s.global_position.z - w.crest_z < 13.0
				tap -= get_physics_process_delta_time()
				if tap <= 0.0 and s.global_position.z - w.crest_z < 8.0:
					tap = 0.35
					Controles.press_touch_stand()
			Surfer.State.POPUP, Surfer.State.RIDING:
				if OS.has_environment("ASSIST_LOG") and Engine.get_physics_frames() % 30 == 0:
					print("[assist] t=%.1f u=%.1f fw=%.1f prof=%.2f vel=%.1f eq=%.2f yaw=%.2f broken=%.2f" % [t, s.last_sample["u"], s.last_sample["face_width"], s.last_sample["profile"], s.speed(), s.balance, s.yaw, s.last_sample["broken"]])
				stood = true
				Controles.touch_paddle = false
				var desired := PI * 0.5 * w.peel_dir
				var e := wrapf(desired - s.yaw, -PI, PI)
				Controles.touch_stick = Vector2(clampf(-e * 1.5, -1.0, 1.0), 0.0)
			_:
				Controles.touch_stick = Vector2.ZERO
		# Sin ola en 45 s o perdida: el juego lanza la siguiente; contamos solo la primera.
		if s.state == Surfer.State.PRONE and game._missed_timer >= 0.0:
			break
	s.ride_ended.disconnect(cb)
	Controles.touch_stick = Vector2.ZERO
	Controles.touch_paddle = false
	return {"stood": stood, "ride": s.ride_time, "ok": ended[1], "title": ended[2] if ended[0] else "ola perdida"}
