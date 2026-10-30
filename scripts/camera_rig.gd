class_name CameraRig
extends Camera3D
## Cámara en tercera persona que sigue al surfista con suavidad.
## Tumbado: vista lateral desde el lado hacia el que corre la ola, para ver
## llegar la ola y la playa a la vez. De pie: detrás del surfista y desplazada
## hacia la orilla, para ver la cara de la ola sin que la tape la espuma.

enum Mode { FOLLOW, CINEMATIC, SHOWCASE }
var showcase_view := 0

@export var surfer: Surfer
@export var follow_speed := 3.0
@export var turn_speed := 2.0

var wave: WaveModel
var mode := Mode.FOLLOW
var lineup := Vector3.ZERO
var _t := 0.0
var _dir := Vector3(-1, 0, 0)
var _look := Vector3.ZERO
var _ready_once := false
var _lead := Vector3.ZERO
var _tube_mix := 0.0
var _avoidance := Vector3.ZERO


func _ready() -> void:
	# Se mueve en _process con posiciones ya interpoladas: no necesita interpolación de física.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Cámaras de los menús. CINEMATIC: barrido lento por la rompiente mirando hacia el pico
## (la mitad izquierda de la pantalla queda para el menú). SHOWCASE: primer plano del
## surfista a la derecha de la pantalla. "Reducir movimiento" las deja fijas.
func _menu_camera(delta: float) -> void:
	var t := 0.0 if Ajustes.reduce_motion else _t
	var side := -wave.peel_dir  # lado del cabo
	var pos: Vector3
	var look: Vector3
	if mode == Mode.CINEMATIC:
		var a := t * 0.045
		pos = lineup + Vector3(side * (-14.0 + 6.0 * sin(a)), 3.4 + 0.8 * sin(a * 1.7), 16.0 + 5.0 * cos(a))
		look = lineup + Vector3(side * 8.0, 1.2, -8.0)
	else:
		var p := surfer.visual.global_position
		var a := 0.6 + 0.25 * sin(t * 0.3)
		pos = p + Vector3(sin(a) * 3.4, 1.35, cos(a) * 3.4)
		# Mirar a un punto a la izquierda del surfista para que quede en la mitad derecha
		# de la pantalla (la izquierda es para el panel de personalización).
		var to_cam := (pos - p).normalized()
		var screen_left := Vector3.UP.cross(-to_cam).normalized()
		look = p + Vector3(0,0.10 if showcase_view==1 else 0.85,0) + screen_left * 1.6
	pos.y = maxf(pos.y, wave.height_at(pos.x, pos.z) + 1.0)
	if _ready_once:
		var k := 1.0 - exp(-2.5 * delta)
		global_position = global_position.lerp(pos, k)
		_look = _look.lerp(look, k)
	else:
		global_position = pos
		_look = look
		_ready_once = true
	look_at(_look, Vector3.UP)


func snap_now() -> void:
	_ready_once = false
	_lead = Vector3.ZERO
	_tube_mix = 0.0
	_avoidance = Vector3.ZERO


## Conservative height-field visibility test; water uses the same wave formula.
func clear_view(eye: Vector3, aim: Vector3) -> bool:
	if wave == null:
		return true
	for i in range(1, 8):
		var point := aim.lerp(eye, float(i) / 8.0)
		if point.y < wave.height_at(point.x, point.z) + 0.12:
			return false
	return true

func safe_follow_position(eye: Vector3, aim: Vector3) -> Vector3:
	var candidate := eye
	candidate.y = maxf(candidate.y, wave.height_at(candidate.x, candidate.z) + 0.65)
	if clear_view(candidate, aim):
		return candidate
	# Shoreward and closer viewpoints are preferred to a large vertical jump.
	for offset in [Vector3(0, 0.65, 1.6), Vector3(0, 1.25, 2.6), Vector3(0, 2.2, 3.0)]:
		var alternative: Vector3 = eye + offset
		alternative.y = maxf(alternative.y, wave.height_at(alternative.x, alternative.z) + 0.65)
		if clear_view(alternative, aim):
			return alternative
	return candidate + Vector3(0, 2.5, 2.5)

func _process(delta: float) -> void:
	if surfer == null or wave == null:
		return
	_t += delta
	if mode != Mode.FOLLOW:
		_menu_camera(delta)
		return
	var target := surfer.get_global_transform_interpolated().origin
	var line := Vector3(wave.peel_dir, 0.0, 0.0)
	var travel := Vector3(surfer.hvel.x, 0.0, surfer.hvel.y)
	var want := line
	var back := 5.5
	var shore := 1.5
	var height := 2.0
	var look_off := Vector3(0.0, 0.55, -1.5)
	var riding := surfer.state in [Surfer.State.POPUP, Surfer.State.RIDING, Surfer.State.DONE, Surfer.State.AIRBORNE, Surfer.State.FLOATER]
	if riding:
		if travel.length() > 2.0 and not Ajustes.reduce_motion:
			want = travel.normalized().lerp(line, 0.35).normalized().rotated(Vector3.UP, -clampf(surfer.rail_load,-1.0,1.0) * 0.08)
		back = 5.2
		shore = 3.4
		height = 2.1
		look_off = Vector3(0, 0.85, 0)
	elif surfer.state == Surfer.State.WIPEOUT:
		target = surfer.rider.get_global_transform_interpolated().origin
		back = 6.5
		shore = 3.5
		height = 2.8
		look_off = Vector3(0, 0.3, 0)
	var lead_goal := travel.limit_length(10.0) * 0.12 if riding and not Ajustes.reduce_motion else Vector3.ZERO
	_lead = _lead.lerp(lead_goal, 1.0 - exp(-4.0 * delta))
	if not _ready_once:
		_dir = want
	# Planar shortest-angle interpolation also handles a full reversal safely.
	var angle := lerp_angle(atan2(_dir.x, _dir.z), atan2(want.x, want.z), 1.0 - exp(-turn_speed * delta))
	_dir = Vector3(sin(angle), 0, cos(angle))
	var distance_scale := clampf(Ajustes.camera_distance, 0.75, 1.35)
	var desired := target - _dir * back * distance_scale + Vector3(0, height, shore * sqrt(distance_scale))
	var look_target := target + look_off + _lead * 0.55
	var tube_goal := 1.0 if surfer.in_tube and not Ajustes.reduce_motion else 0.0
	_tube_mix = lerpf(_tube_mix, tube_goal, 1.0 - exp(-5.0 * delta))
	var ahead := (target.x - wave.peel_x) * wave.peel_dir
	var tube_back := clampf(ahead - 0.4, 0.4, 2.2)
	var tube_pos := target - line * tube_back + Vector3(0, 0.85, 0)
	desired = desired.lerp(tube_pos, _tube_mix)
	look_target = look_target.lerp(target + line * 1.8 + Vector3(0, 0.8, 0), _tube_mix)
	if _tube_mix < 0.5:
		var correction := safe_follow_position(desired, look_target) - desired
		var avoid_rate := 12.0 if correction.length_squared() > _avoidance.length_squared() else 2.5
		_avoidance = _avoidance.lerp(correction, 1.0 - exp(-avoid_rate * delta))
		desired += _avoidance
	var pos := desired
	if _ready_once:
		pos = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
		_look = _look.lerp(look_target, 1.0 - exp(-6.0 * delta))
	else:
		_look = look_target
	var minimum := 0.22 if _tube_mix > 0.5 else 0.65
	pos.y = maxf(pos.y, wave.height_at(pos.x, pos.z) + minimum)
	if _tube_mix > 0.5:
		var tube := wave.tube_at(pos, 0.10)
		if tube["inside"]:
			var roof: float = tube["roof"] - 0.15
			var floor_height := wave.height_at(pos.x, pos.z) + 0.22
			if roof >= floor_height:
				pos.y = clampf(pos.y, floor_height, roof)
	_ready_once = true
	global_position = pos
	var target_fov := 70.0 if Ajustes.reduce_motion else lerpf(68.0, 74.0, clampf(surfer.speed() / 12.0, 0, 1))
	fov = lerpf(fov, target_fov, 1.0 - exp(-2.0 * delta))
	look_at(_look, Vector3.UP)
