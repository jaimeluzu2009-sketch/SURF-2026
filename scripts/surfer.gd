class_name Surfer
extends CharacterBody3D
## Tabla + surfista. Física sencilla de flotación y planeo sobre la superficie de WaveModel.
##
## Estados: tumbado (remar) -> ponerse de pie -> surfear -> caída / fin.
## La tabla (Visual) se orienta con la normal del agua; el surfista (Rider) va
## pegado a ella salvo cuando se cae, que se queda en el agua unido por el leash.

signal ride_ended(success: bool, title: String, detail: String)
signal hint(text: String)

enum State { PRONE, POPUP, RIDING, WIPEOUT, DONE }

const POPUP_TIME := 0.7
const DECK_RIDE := 0.045
const DECK_PRONE := -0.005

@export_group("Remar")
@export var paddle_accel := 2.9
@export var paddle_max := 2.6
@export var turn_rate_prone := 1.6
@export_group("Surfear")
@export var turn_rate_ride := 1.9
@export var max_roll_deg := 24.0
## Ayuda para mantenerse en la cara de la ola (0 = realista, 1 = muy asistido).
@export_range(0.0, 1.0) var face_assist := 0.55
@export_group("Equilibrio")
@export var balance_slope := 1.15
@export var balance_stall := 0.8
@export var balance_chop := 0.35
@export var balance_trim := 1.0

@onready var visual: Node3D = $Visual
@onready var rider: Node3D = $Rider
@onready var animator: SurferAnimator = $Rider/Animator
@onready var leash: Leash = $Leash
@onready var wake: CPUParticles3D = $Visual/Wake

var wave: WaveModel
var state := State.PRONE
var yaw := 0.0
var hvel := Vector2.ZERO
var carve := 0.0
var trim := 0.0
var balance := 0.0
var can_stand := false
var ride_time := 0.0
var ride_distance := 0.0
var top_speed := 0.0
var paddling := false
var last_sample := {}

var _state_time := 0.0
var _danger := 0.0
var _foam_time := 0.0
var _rail_time := 0.0
var _slow_time := 0.0
var _up := Vector3.UP
var _bob := 0.0
var _paddle_amount := 0.0
var _rider_detached := false
var _fall_yaw := 0.0
var _spin := 0.0
var _roll_wipe := 0.0
var _reported := false
var _end_success := false
var _end_title := ""
var _end_detail := ""
var _noise := FastNoiseLite.new()
var _hint_cooldown := 0.0
## Recorrido reciente de la tabla para la estela: x, z, instante, intensidad.
var _wake: Array[Vector4] = []
var _wake_timer := 0.0
var _clock := 0.0
var _showcase := false


func _ready() -> void:
	_noise.seed = 7
	_noise.frequency = 0.9
	animator.setup($Rider/SurferModel)
	leash.board = visual
	leash.animator = animator
	rider.top_level = true
	Ajustes.changed.connect(_apply_quality)
	Perfil.changed.connect(_apply_look)
	_apply_quality()


func _apply_quality() -> void:
	wake.amount = maxi(8, int(48 * Ajustes.preset()["particles"]))
	_apply_look()


## Materiales con los colores elegidos en «Surfista y tabla» (Perfil).
func _apply_look() -> void:
	var detail: bool = Ajustes.preset()["detail"]
	var look := {
		"Neopreno": Perfil.look_color("wetsuit"), "Franja": Perfil.look_color("accent"),
		"Cubierta": Perfil.look_color("deck"), "Fondo": Perfil.look_color("bottom"),
	}
	SurfMaterials.apply($Rider/SurferModel, detail, look)
	SurfMaterials.apply($Visual/Board, detail, look)


## Congela al surfista (menús): no se mueve ni reacciona a las olas.
func set_frozen(on: bool) -> void:
	set_physics_process(not on)


## Pose de exhibición para la pantalla de personalización: de pie y con la tabla plana.
func set_showcase(on: bool) -> void:
	_showcase = on
	if on:
		animator.jump_to("ride")
		animator.set_ride_blend(0.0, 0.0)
		visual.global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3(0, 0.05, 0))
		rider.global_transform = visual.global_transform
	else:
		animator.jump_to("prone_idle")


func reset_to(pos: Vector3, heading: float) -> void:
	state = State.PRONE
	_state_time = 0.0
	global_position = pos
	yaw = heading
	rotation = Vector3(0, yaw, 0)
	hvel = Vector2.ZERO
	carve = 0.0
	trim = 0.0
	balance = 0.0
	_danger = 0.0
	_foam_time = 0.0
	_rail_time = 0.0
	_slow_time = 0.0
	ride_time = 0.0
	ride_distance = 0.0
	top_speed = 0.0
	_rider_detached = false
	_reported = false
	_wake.clear()
	_up = Vector3.UP
	_roll_wipe = 0.0
	animator.jump_to("prone_idle")
	if wave:
		last_sample = wave.sample(pos.x, pos.z)
		_update_visual(0.0, last_sample)
	reset_physics_interpolation()
	rider.reset_physics_interpolation()
	visual.reset_physics_interpolation()


func forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


func speed() -> float:
	return hvel.length()


func is_riding() -> bool:
	return state == State.POPUP or state == State.RIDING


func _physics_process(delta: float) -> void:
	if wave == null:
		return
	_state_time += delta
	_hint_cooldown = maxf(0.0, _hint_cooldown - delta)
	var s := wave.sample(global_position.x, global_position.z)
	last_sample = s
	match state:
		State.PRONE:
			_do_prone(delta, s)
		State.POPUP:
			_do_ride(delta, s, true)
		State.RIDING:
			_do_ride(delta, s, false)
		State.WIPEOUT, State.DONE:
			_do_after(delta, s)
	_move(delta, s)
	_update_visual(delta, s)
	_record_wake(delta)


func _record_wake(delta: float) -> void:
	_clock += delta
	_wake_timer -= delta
	if _wake_timer > 0.0:
		return
	_wake_timer = 0.09
	var strength := 0.0
	if is_riding() or state == State.DONE:
		strength = clampf(speed() / 6.0, 0.2, 1.2) * (0.8 + 0.5 * absf(carve))
	elif state == State.PRONE and speed() > 0.8:
		strength = 0.35
	if strength <= 0.0:
		return
	_wake.push_front(Vector4(global_position.x, global_position.z, _clock, strength))
	var keep: int = Ajustes.preset()["wake_points"]
	while _wake.size() > keep:
		_wake.pop_back()


## Estela para el shader del agua (edad en segundos en lugar del instante).
func wake_points() -> PackedVector4Array:
	var out := PackedVector4Array()
	for w in _wake:
		out.append(Vector4(w.x, w.y, _clock - w.z, w.w))
	return out


## La tabla toca el agua (para la espuma de contacto).
func touching_water() -> bool:
	return state != State.WIPEOUT or _state_time < 0.4


# ------------------------------------------------------------------ tumbado

func _do_prone(delta: float, s: Dictionary) -> void:
	var st := Controles.stick()
	paddling = Controles.paddling() or st.y > 0.5
	yaw -= st.x * turn_rate_prone * delta
	var f := Vector2(sin(yaw), cos(yaw))
	var n: Vector3 = s["normal"]
	var acc := Vector2(n.x, n.z) * WaveModel.G * 0.75
	if paddling:
		var rel_f: float = hvel.dot(f) - s["flow"] * f.y
		acc += f * paddle_accel * clampf(1.0 - rel_f / paddle_max, 0.0, 1.0)
	hvel += acc * delta
	_drag(delta, Vector2(0.0, s["flow"]), 0.55, 2.4)
	_paddle_amount = move_toward(_paddle_amount, 1.0 if paddling else 0.0, delta * 4.0)
	animator.travel("paddle" if _paddle_amount > 0.3 else "prone_idle")
	animator.set_paddle_speed(1.0 + 0.4 * _paddle_amount)

	# En la espuma no se ofrece pararse: te tumbaría al instante.
	can_stand = s["u"] > -0.4 and s["profile"] > 0.22 and hvel.y > wave.speed * 0.6 and speed() > 3.2 \
		and s["broken"] < 0.4
	if Controles.take_stand():
		if can_stand:
			_start_popup()
		elif _hint_cooldown <= 0.0:
			_hint_cooldown = 1.5
			if s["broken"] >= 0.4 and s["profile"] > 0.15:
				hint.emit("Estás en la espuma: espera a la siguiente ola y cógela antes de que rompa")
			elif s["profile"] < 0.15:
				hint.emit("Aún no hay ola debajo: espera y rema cuando llegue")
			else:
				hint.emit("Te falta velocidad: rema más fuerte con la ola")


func _start_popup() -> void:
	state = State.POPUP
	_state_time = 0.0
	can_stand = false
	balance = 0.0
	animator.travel("popup")


# ------------------------------------------------------------------ de pie

func _do_ride(delta: float, s: Dictionary, popup: bool) -> void:
	var st := Vector2.ZERO if popup else Controles.stick()
	carve = move_toward(carve, st.x, delta * 3.5)
	trim = move_toward(trim, st.y, delta * 3.0)
	var spd := speed()
	yaw -= carve * turn_rate_ride * clampf(spd / 5.0, 0.35, 1.15) * delta
	var f := Vector2(sin(yaw), cos(yaw))
	var n: Vector3 = s["normal"]
	var acc := Vector2(n.x, n.z) * WaveModel.G
	var profile: float = s["profile"]
	if face_assist > 0.0 and profile > 0.05:
		var target_u: float = s["face_width"] * 0.9
		acc.y += clampf((target_u - s["u"]) * 0.9, -3.0, 3.0) * face_assist * profile
	if trim > 0.0:
		acc += f * 1.1 * trim * clampf(profile * 2.0, 0.0, 1.0)
	hvel += acc * delta
	var kf := 0.10 + 0.010 * spd + (0.9 * -trim if trim < 0.0 else 0.0)
	_drag(delta, Vector2(0.0, s["flow"] * 0.6), kf, 5.5)

	spd = speed()
	animator.set_ride_blend(carve, trim)
	if popup:
		if _state_time >= POPUP_TIME:
			state = State.RIDING
			_state_time = 0.0
			hint.emit("¡Arriba! Gira con A/D o el joystick para recorrer la ola")
		return

	ride_time += delta
	ride_distance += spd * delta
	top_speed = maxf(top_speed, spd)

	# Equilibrio adelante/atrás: bajar en picado empuja hacia la punta, ir lento hacia la cola.
	var slope_along := -(n.x * f.x + n.z * f.y) / maxf(n.y, 0.2)
	var stall := clampf(1.0 - spd / 3.0, 0.0, 1.0)
	var chop := _noise.get_noise_1d(_state_time * 1.7)
	balance += (balance_slope * -slope_along * clampf(spd / 6.0, 0.4, 1.2) - balance_stall * stall
		+ balance_chop * chop + balance_trim * trim) * delta
	balance -= balance * 0.9 * delta
	balance = clampf(balance, -1.4, 1.4)

	if absf(balance) > 1.0:
		_danger += delta
	else:
		_danger = maxf(0.0, _danger - delta * 2.0)
	if _danger > 0.3:
		if balance > 0.0:
			_wipeout("¡Al agua!", "Clavaste la punta. Echa el peso atrás (S / joystick abajo) en las bajadas.")
		else:
			_wipeout("¡Al agua!", "Te caíste de espaldas. Con poca velocidad, carga el pie delantero (W).")
		return
	if s["broken"] > 0.55 and profile > 0.18:
		_foam_time += delta
	else:
		_foam_time = maxf(0.0, _foam_time - delta)
	if _foam_time > 0.35:
		_wipeout("¡Al agua!", "Te alcanzó la espuma. Corre por delante de donde rompe la ola.")
		return
	if absf(carve) > 0.75 and spd < 2.2:
		_rail_time += delta
	else:
		_rail_time = 0.0
	if _rail_time > 0.6:
		_wipeout("¡Al agua!", "Giro demasiado cerrado sin velocidad: se te clavó el canto.")
		return
	if s["u"] < -3.0 and profile < 0.5:
		_wipeout("Fin de la ola", "Te pasaste por detrás de la cresta.")
		return
	if spd < 1.3 and profile < 0.12:
		_slow_time += delta
	else:
		_slow_time = 0.0
	if _slow_time > 1.0:
		_wipeout("Fin de la ola", "Te quedaste sin ola en el agua plana.")


## Llamado por el juego cuando la ola llega a la orilla y el surfista sigue de pie.
func finish_success() -> void:
	if state != State.RIDING:
		return
	state = State.DONE
	_state_time = 0.0
	_end_success = true
	_end_title = "¡Ola completada!"
	_end_detail = "Recorriste la ola sin caerte."
	carve = 0.0
	trim = 0.0


func _wipeout(title: String, detail: String) -> void:
	state = State.WIPEOUT
	_state_time = 0.0
	_end_success = false
	_end_title = title
	_end_detail = detail
	_rider_detached = true
	_fall_yaw = yaw
	_spin = randf_range(-2.5, 2.5)
	animator.travel("fall")


# ------------------------------------------------------------------ después

func _do_after(delta: float, s: Dictionary) -> void:
	if state == State.DONE:
		# La tabla sigue planeando y frena poco a poco.
		hvel = hvel.lerp(Vector2(0.0, s["flow"] * 0.5), 1.0 - exp(-0.8 * delta))
		animator.set_ride_blend(0.0, -0.3)
	else:
		hvel = hvel.lerp(Vector2(0.0, s["flow"]), 1.0 - exp(-1.6 * delta))
		yaw += _spin * delta * exp(-_state_time * 1.5)
		_roll_wipe = lerpf(_roll_wipe, PI * 0.92, 1.0 - exp(-3.0 * delta))
		# El surfista flota donde cayó y la espuma lo empuja.
		var rp := rider.global_position
		var rs := wave.sample(rp.x, rp.z)
		rp += Vector3(0.0, 0.0, rs["flow"] * 0.85) * delta
		rp.y = lerpf(rp.y, rs["height"], 1.0 - exp(-6.0 * delta))
		var upright := Basis(Vector3.UP, _fall_yaw)
		var q := rider.global_basis.get_rotation_quaternion().slerp(upright.get_rotation_quaternion(),
			1.0 - exp(-6.0 * delta))
		rider.global_transform = Transform3D(Basis(q), rp)
		# El leash no deja que la tabla se aleje más de su longitud.
		var ankle := rider.global_position
		var to := Vector2(global_position.x - ankle.x, global_position.z - ankle.z)
		if to.length() > Leash.LENGTH + 0.4:
			hvel -= to.normalized() * (to.length() - Leash.LENGTH) * 6.0 * delta
	var wait := 1.6 if state == State.DONE else 2.4
	if _state_time > wait and not _reported:
		_reported = true
		ride_ended.emit(_end_success, _end_title, _end_detail)


# ------------------------------------------------------------------ común

func _drag(delta: float, water: Vector2, kf: float, kl: float) -> void:
	var f := Vector2(sin(yaw), cos(yaw))
	var r := Vector2(-cos(yaw), sin(yaw))
	var rel := hvel - water
	var vf := rel.dot(f) * exp(-kf * delta)
	var vl := rel.dot(r) * exp(-kl * delta)
	hvel = water + f * vf + r * vl


func _move(delta: float, s: Dictionary) -> void:
	var deck := DECK_RIDE if (is_riding() or state == State.DONE) else DECK_PRONE
	var target_y: float = s["height"] + deck
	if state == State.PRONE or state == State.WIPEOUT:
		_bob += delta
		target_y += sin(_bob * 2.1) * 0.015
	var vy := clampf((target_y - global_position.y) * 14.0, -10.0, 10.0)
	velocity = Vector3(hvel.x, vy, hvel.y)
	rotation = Vector3(0.0, yaw, 0.0)
	var before := hvel
	move_and_slide()
	hvel = Vector2(velocity.x, velocity.z)
	if state == State.RIDING and get_slide_collision_count() > 0 and (before - hvel).length() > 2.5:
		_wipeout("¡Al agua!", "Chocaste contra las rocas.")


func _update_visual(delta: float, s: Dictionary) -> void:
	var n: Vector3 = s["normal"]
	var up_target := n if (is_riding() or state == State.DONE) else n.lerp(Vector3.UP, 0.3).normalized()
	var k := 1.0 if delta == 0.0 else 1.0 - exp(-10.0 * delta)
	_up = _up.lerp(up_target, k).normalized()
	var f := forward()
	var fwd := (f - _up * f.dot(_up)).normalized()
	var b := Basis(_up.cross(fwd), _up, fwd)
	var roll := 0.0
	var pitch := -0.05
	if is_riding() or state == State.DONE:
		roll = carve * deg_to_rad(max_roll_deg) * clampf(speed() / 5.0, 0.3, 1.0)
		pitch = trim * 0.05
	elif state == State.WIPEOUT:
		roll = _roll_wipe
		pitch = 0.0
	b = b * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	visual.global_transform = Transform3D(b, global_position)
	if not _rider_detached:
		rider.global_transform = visual.global_transform
	# Salpicadura de la cola: más cuanto más rápido y más cerrado el giro, hacia fuera de la curva.
	var spd := speed()
	wake.emitting = state == State.RIDING and spd > 2.5
	var spray := clampf((spd - 2.0) / 7.0 * (0.3 + 0.7 * absf(carve)), 0.05, 1.0)
	wake.scale_amount_max = 0.25 + 0.6 * spray
	wake.direction = Vector3(carve * 1.1, 1.0, -0.5)
	wake.initial_velocity_max = 2.0 + 3.0 * absf(carve) * clampf(spd / 7.0, 0.0, 1.2)
