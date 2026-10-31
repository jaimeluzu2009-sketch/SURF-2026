extends Node
## --qa --paddle-zone-test: remar sin parar hacia la playa (y hacia un lado) no debe
## llevar al surfista tumbado hasta la arena; vuelve al lineup.
var game: Game
var failures: Array[String] = []


func _ready() -> void:
	game = get_parent()
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("[paddle-zone] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func paddle(heading: float, seconds: float) -> Dictionary:
	game.restart()
	var s := game.surfer
	s.yaw = heading
	var max_z := -INF
	var max_x := 0.0
	var resets := 0
	var last := s.global_position
	for i in int(seconds * 60.0):
		Controles.bot_paddle = true
		Controles.bot_stick = Vector2(clampf(wrapf(s.yaw - heading, -PI, PI) * 2.0, -1, 1), 0)
		await get_tree().physics_frame
		var p := s.global_position
		if p.distance_to(last) > 5.0: resets += 1
		last = p
		if s.state == Surfer.State.PRONE:
			max_z = maxf(max_z, p.z - game.lineup.z)
			max_x = maxf(max_x, absf(p.x - game.lineup.x))
	Controles.bot_paddle = false
	return {"max_z": max_z, "max_x": max_x, "resets": resets, "z": s.global_position.z}


func run() -> void:
	Ajustes.persist = false
	Controles.bot_enabled = true
	game.start_play()
	var shore := await paddle(0.0, 40.0)
	print("[paddle-zone] hacia la playa: máx %.1f m del lineup, %d vueltas al lineup" % [shore.max_z, shore.resets])
	# Margen: durante el aviso de 1,5 s la espuma puede empujar unos metros más.
	check(shore.max_z < Game.PADDLE_ZONE.y + 12.0, "remando hacia la playa no pasa de la zona del pico")
	check(shore.z < Beach.SHORE_Z - 60.0, "nunca llega a la arena (z final %.1f)" % shore.z)
	var side := await paddle(PI * 0.5, 40.0)
	print("[paddle-zone] de lado: máx %.1f m laterales, %d vueltas" % [side.max_x, side.resets])
	check(side.max_x < Game.PADDLE_ZONE.x + 6.0, "remando de lado no se escapa del pico")
	Controles.bot_enabled = false
	print("[paddle-zone] RESULTADO ", "OK" if failures.is_empty() else "FALLOS: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
