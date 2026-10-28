class_name CameraRig
extends Camera3D
## Cámara en tercera persona que sigue al surfista con suavidad.
## Tumbado: vista lateral desde el lado hacia el que corre la ola, para ver
## llegar la ola y la playa a la vez. De pie: detrás del surfista y desplazada
## hacia la orilla, para ver la cara de la ola sin que la tape la espuma.

enum Mode { FOLLOW, CINEMATIC, SHOWCASE }

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
		var p := surfer.global_position
		var a := 0.6 + 0.25 * sin(t * 0.3)
		pos = p + Vector3(sin(a) * 3.4, 1.35, cos(a) * 3.4)
		# Mirar a un punto a la izquierda del surfista para que quede en la mitad derecha
		# de la pantalla (la izquierda es para el panel de personalización).
		var to_cam := (pos - p).normalized()
		var screen_left := Vector3.UP.cross(-to_cam).normalized()
		look = p + Vector3(0, 0.85, 0) + screen_left * 1.6
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
	var look_off := Vector3(0.0, 0.5, -2.5)
	match surfer.state:
		Surfer.State.POPUP, Surfer.State.RIDING, Surfer.State.DONE:
			if travel.length() > 2.0:
				want = travel.normalized().lerp(line, 0.35).normalized()
			back = 5.2
			shore = 3.4
			height = 2.1
			look_off = Vector3(0.0, 0.7, 0.0)
		Surfer.State.WIPEOUT:
			target = surfer.rider.get_global_transform_interpolated().origin
			back = 6.5
			shore = 3.5
			height = 2.8
			look_off = Vector3(0.0, 0.3, 0.0)
	if not _ready_once:
		_dir = want
	_dir = _dir.slerp(want, 1.0 - exp(-turn_speed * delta)).normalized()
	var desired := target - _dir * back + Vector3(0.0, height, shore)
	var look_target := target + look_off
	var pos := desired
	if _ready_once:
		pos = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
		_look = _look.lerp(look_target, 1.0 - exp(-6.0 * delta))
	else:
		_look = look_target
	pos.y = maxf(pos.y, wave.height_at(pos.x, pos.z) + 1.0)
	_ready_once = true
	global_position = pos
	look_at(_look, Vector3.UP)
