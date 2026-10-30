class_name ScoreKeeper
extends RefCounted
## Puntuación de una ola. La alimenta game.gd en cada paso de física mientras el
## surfista está de pie.
##   - Recorrido: 4 puntos por metro.
##   - Gameplay: SurfTurns valida trayectoria y emite una maniobra real;
##     award_maneuver aplica (60 + 25·velocidad) × combo × factor del tipo.
##   - step conserva el detector sencillo anterior para compatibilidad con
##     pruebas independientes; game.gd lo desactiva para evitar doble puntuación.
##   - Combo: cada giro dentro de 2.5 s del anterior sube el multiplicador (máx. ×8).
##   - Pocket: surfear a menos de 4 m del punto de rotura suma 40 puntos/s.
##   - Completar la ola: +1000.

signal event(text: String, points: int)

const COMBO_WINDOW := 2.5
const MAX_COMBO := 8

var score := 0
var combo := 1
var best_combo := 1
var flow := 0.0
var trick_counts := {}
var _last_kind := ""
var _repeats := 0
var _deep_pending := 0.0
var turns := 0
var tube_time := 0.0
var tube_exits := 0
var _tube_acc := 0.0
var pocket_time := 0.0
var distance := 0.0
var top_speed := 0.0

var _carve_time := 0.0
var _combo_timer := 0.0
var _pocket_acc := 0.0
var _dist_acc := 0.0
var _in_pocket := false


func reset() -> void:
	flow=0.0
	trick_counts.clear()
	_last_kind=""
	_repeats=0
	_deep_pending=0.0
	score = 0
	combo = 1
	best_combo = 1
	turns = 0
	tube_time = 0.0
	tube_exits = 0
	_tube_acc = 0.0
	pocket_time = 0.0
	distance = 0.0
	top_speed = 0.0
	_carve_time = 0.0
	_combo_timer = 0.0
	_pocket_acc = 0.0
	_dist_acc = 0.0
	_in_pocket = false


## Paso de puntuación. ahead: distancia por delante del punto de rotura (m).
func step(delta: float, speed: float, carve: float, ahead: float, detect_turns := true, advance_clock := true) -> void:
	if advance_clock: tick(delta)
	top_speed = maxf(top_speed, speed)
	distance += speed * delta
	_dist_acc += speed * delta * 4.0
	if _dist_acc >= 1.0:
		var p := int(_dist_acc)
		score += p
		_dist_acc -= p

	if detect_turns and absf(carve) > 0.7:
		_carve_time += delta
	else:
		if detect_turns and _carve_time >= 0.35:
			_turn(speed)
		_carve_time = 0.0

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


func tick(delta: float) -> void:
	flow=maxf(0.0,flow-delta*0.025)
	if _combo_timer>0.0:
		_combo_timer-=delta
		if _combo_timer<=0.0: combo=1

func break_chain() -> void:
	combo=1
	_combo_timer=0.0
	flow*=0.5
	_deep_pending=0.0

func trick_count(kind: String) -> int:
	if kind=="air":
		return int(trick_counts.get("air",0))+int(trick_counts.get("air180",0))+int(trick_counts.get("grab_air",0))+int(trick_counts.get("grab180",0))
	return int(trick_counts.get(kind,0))

func _turn(speed: float, label_text := "GIRO", factor := 1.0) -> void:
	turns += 1
	if _combo_timer > 0.0:
		combo = mini(combo + 1, MAX_COMBO)
	_combo_timer = COMBO_WINDOW + flow*1.2
	best_combo = maxi(best_combo, combo)
	var pts := int((60.0 + 25.0 * speed) * combo * factor)
	score += pts
	event.emit("%s ×%d" % [label_text,combo] if combo > 1 else label_text, pts)


func finish_bonus() -> void:
	score += 1000
	event.emit("OLA COMPLETADA", 1000)


func tube_step(delta: float, inside: bool, depth := 0.0) -> void:
	if not inside:
		return
	_deep_pending+=delta*clampf(depth,0.0,1.0)*75.0
	tube_time += delta
	_tube_acc += delta * 120.0
	var pts := int(_tube_acc)
	score += pts
	_tube_acc -= pts

func tube_exit_bonus(duration: float) -> void:
	tube_exits += 1
	var pts := 800 + int(duration * 100.0) + int(_deep_pending)
	_deep_pending=0.0
	score += pts
	event.emit("SALIDA DEL TUBO", pts)


func award_maneuver(result: Dictionary) -> void:
	var kinds := {"carving":["CARVING",1.0],"bottom_turn":["BOTTOM TURN",1.15],"cutback":["CUTBACK",1.55],
		"snap":["SNAP",1.5],"floater":["FLOATER",1.7],"air":["AÉREO",2.0],"air180":["AÉREO 180",2.7],
		"grab_air":["AÉREO CON AGARRE",2.5],"grab180":["AGARRE 180",3.2],"tube_rail":["CANTO + SALIDA",0.8],"hand_drag":["MANO + SALIDA",1.1]}
	var kind: String = result.get("kind","")
	if not kinds.has(kind) or float(result.get("speed",0))<3.0: return
	# Variantes de aéreo comparten familia: alternar 0/180 no elimina la penalización.
	var family := "air" if kind in ["air","air180","grab_air","grab180"] else kind
	_repeats=_repeats+1 if family==_last_kind else 0
	_last_kind=family
	var repeat_factor := maxf(0.30,pow(0.65,_repeats))
	var flow_factor := 1.0+flow*0.35
	flow=minf(1.0,flow+(0.13 if _repeats==0 else 0.035))
	trick_counts[kind]=int(trick_counts.get(kind,0))+1
	var label: String = kinds[kind][0]
	if result.has("landing"): label+=" · "+str(result.landing)
	_turn(float(result.speed),label,float(kinds[kind][1])*repeat_factor*flow_factor*clampf(float(result.get("quality",1.0)),0.5,1.25))
