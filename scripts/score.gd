class_name ScoreKeeper
extends RefCounted
## Puntuación de una ola. La alimenta game.gd en cada paso de física mientras el
## surfista está de pie.
##   - Recorrido: 4 puntos por metro.
##   - Giros: un giro cuenta cuando se mantiene el carve fuerte (>0.7) al menos
##     0.35 s y luego se suelta. Vale 60 + 25·velocidad, por el multiplicador.
##   - Combo: cada giro dentro de 2.5 s del anterior sube el multiplicador (máx. ×8).
##   - Pocket: surfear a menos de 4 m del punto de rotura suma 40 puntos/s.
##   - Completar la ola: +1000.

signal event(text: String, points: int)

const COMBO_WINDOW := 2.5
const MAX_COMBO := 8

var score := 0
var combo := 1
var best_combo := 1
var turns := 0
var pocket_time := 0.0
var distance := 0.0
var top_speed := 0.0

var _carve_time := 0.0
var _combo_timer := 0.0
var _pocket_acc := 0.0
var _dist_acc := 0.0
var _in_pocket := false


func reset() -> void:
	score = 0
	combo = 1
	best_combo = 1
	turns = 0
	pocket_time = 0.0
	distance = 0.0
	top_speed = 0.0
	_carve_time = 0.0
	_combo_timer = 0.0
	_pocket_acc = 0.0
	_dist_acc = 0.0
	_in_pocket = false


## Paso de puntuación. ahead: distancia por delante del punto de rotura (m).
func step(delta: float, speed: float, carve: float, ahead: float) -> void:
	top_speed = maxf(top_speed, speed)
	distance += speed * delta
	_dist_acc += speed * delta * 4.0
	if _dist_acc >= 1.0:
		var p := int(_dist_acc)
		score += p
		_dist_acc -= p

	if absf(carve) > 0.7:
		_carve_time += delta
	else:
		if _carve_time >= 0.35:
			_turn(speed)
		_carve_time = 0.0

	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 1

	var pocket := ahead > -0.5 and ahead < 4.0
	if pocket:
		pocket_time += delta
		_pocket_acc += 40.0 * delta
		if _pocket_acc >= 10.0:
			score += int(_pocket_acc)
			_pocket_acc = fmod(_pocket_acc, 1.0)
		if not _in_pocket:
			event.emit("EN EL POCKET", 0)
	_in_pocket = pocket


func _turn(speed: float) -> void:
	turns += 1
	if _combo_timer > 0.0:
		combo = mini(combo + 1, MAX_COMBO)
	_combo_timer = COMBO_WINDOW
	best_combo = maxi(best_combo, combo)
	var pts := int((60.0 + 25.0 * speed) * combo)
	score += pts
	event.emit("GIRO ×%d" % combo if combo > 1 else "GIRO", pts)


func finish_bonus() -> void:
	score += 1000
	event.emit("OLA COMPLETADA", 1000)
