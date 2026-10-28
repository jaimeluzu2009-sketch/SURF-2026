extends SceneTree
# Prueba de ScoreKeeper: giros, combo, pocket y bonus.
# godot --headless --path . -s tests/score_test.gd

func _init() -> void:
	var s := ScoreKeeper.new()
	var events := []
	s.event.connect(func(t, p): events.append("%s %d" % [t, p]))
	var dt := 1.0 / 60.0
	# 4 giros encadenados (0.5 s de carve fuerte y 0.5 s suelto) a 7 m/s en el pocket.
	for turn in 4:
		for i in 30:
			s.step(dt, 7.0, 0.9 * (1 if turn % 2 == 0 else -1), 2.0)
		for i in 30:
			s.step(dt, 7.0, 0.1, 2.0)
	# 3 s sin girar fuera del pocket: el combo debe caer.
	for i in 180:
		s.step(dt, 7.0, 0.0, 10.0)
	s.finish_bonus()
	print("eventos: ", events)
	print("giros=%d combo_max=%d combo_actual=%d pocket=%.1f s distancia=%.1f m puntos=%d" % [
		s.turns, s.best_combo, s.combo, s.pocket_time, s.distance, s.score])
	var ok := s.turns == 4 and s.best_combo == 4 and s.combo == 1 and absf(s.pocket_time - 4.0) < 0.05
	print("RESULTADO: ", "OK" if ok else "FALLO")
	quit(0 if ok else 1)
