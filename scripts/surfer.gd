class_name Surfer
extends CharacterBody3D
## Tabla + surfista. Física sencilla de flotación y planeo sobre la superficie de WaveModel.
##
## Estados: tumbado (remar) -> ponerse de pie -> surfear -> caída / fin.
## La tabla (Visual) se orienta con la normal del agua; el surfista (Rider) va
## pegado a ella salvo cuando se cae, que se queda en el agua unido por el leash.

signal ride_ended(success: bool, title: String, detail: String)
signal hint(text: String)
signal maneuver_completed(result: Dictionary)

enum State { PRONE, POPUP, RIDING, WIPEOUT, DONE, AIRBORNE, FLOATER }
signal maneuver_failed
var tricks := SurfTricks.new()
var switch_stance := false
var _moved_by_trick := false

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
var rail_load := 0.0
var turns := SurfTurns.new()
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
var _wake_loads: Array[float] = []
var _wake_timer := 0.0
var _clock := 0.0
var _showcase := false
var showcase_board := false
var _stand_buffer := 0.0
var _stand_grace := 0.0
var in_tube := false
var tube_seconds := 0.0
var tube_exits := 0
var _tube_hit := 0.0
signal tube_exit(duration: float)
var _tube_stint := 0.0
var _fall_sign := 1.0
var _winter_mesh: Mesh
var _summer_mesh: Mesh
var _style_meshes := {}
var _original_board: Mesh


func _ready() -> void:
	tricks.setup(self)
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
	wake.amount = maxi(6, int(32 * Ajustes.preset()["particles"]))
	_apply_look()


## Materiales con los colores elegidos en «Surfista y tabla» (Perfil).
func _apply_look() -> void:
	var body := $Rider/SurferModel.find_child("Surfer", true, false) as MeshInstance3D
	if body and _winter_mesh == null:
		_winter_mesh = body.mesh
		if ResourceLoader.exists("res://assets/models/surfer_beach.glb"):
			var summer: Node = load("res://assets/models/surfer_beach.glb").instantiate()
			_summer_mesh = (summer.find_child("Surfer", true, false) as MeshInstance3D).mesh
			summer.free()
	if body:
		body.mesh = _summer_mesh if Perfil.outfit == 1 and _summer_mesh != null else _winter_mesh
	var board_mesh := $Visual/Board.find_child("Board", true, false) as MeshInstance3D
	if _original_board == null:
		_original_board = board_mesh.mesh
	if Perfil.style_id != "custom":
		var id: String = Perfil.style_id
		for prefix in ["surfer", "board"]:
			var cache_key: String = prefix + "_" + id
			if prefix=="surfer" and Perfil.outfit!=int(Perfil.STYLES[Perfil.style_index()].outfit):
				cache_key+="_beach" if Perfil.outfit==1 else "_wetsuit"
			if not _style_meshes.has(cache_key):
				var path := "res://assets/models/%s.glb" % cache_key
				if ResourceLoader.exists(path):
					var scene: Node = load(path).instantiate()
					_style_meshes[cache_key] = (scene.find_child("Surfer" if prefix == "surfer" else "Board", true, false) as MeshInstance3D).mesh
					scene.free()
		var body_key := "surfer_"+id
		if Perfil.outfit!=int(Perfil.STYLES[Perfil.style_index()].outfit): body_key+="_beach" if Perfil.outfit==1 else "_wetsuit"
		body.mesh = _style_meshes.get(body_key, body.mesh)
		board_mesh.mesh = _style_meshes.get("board_" + id, _original_board)
	else:
		board_mesh.mesh = _original_board
	var detail: bool = Ajustes.preset()["detail"]
	var look := {
		"Piel": Perfil.look_color("skin"), "Pelo": Perfil.look_color("hair"),
		"Neopreno": Perfil.look_color("wetsuit"), "Franja": Perfil.look_color("accent"),
		"Bermuda": Perfil.look_color("accent"), "Licra": Perfil.look_color("wetsuit"),
		"Cubierta": Perfil.look_color("deck"), "Fondo": Perfil.look_color("bottom"),
	}
	if Perfil.style_id == "retro":
		look["Costura"] = Color(0.08, 0.40, 0.46)
		look["Grip"] = Color(0.87, 0.86, 0.80)
	SurfMaterials.apply($Rider/SurferModel, detail, look)
	SurfMaterials.apply($Visual/Board, detail, look)
	if body: _character_lod(body)


## Congela al surfista (menús): no se mueve ni reacciona a las olas.
func set_frozen(on: bool) -> void:
	set_physics_process(not on)


## Pose de exhibición para la pantalla de personalización: de pie y con la tabla plana.
func update_showcase() -> void:
	if not _showcase or wave == null:
		return
	var p := global_position
	var n: Vector3 = wave.sample(p.x, p.z)["normal"]
	var f := forward()
	f = (f - n * f.dot(n)).normalized()
	var basis_on_water := Basis(n.cross(f), n, f)
	p.y = wave.height_at(p.x, p.z) + 0.06
	# Keep the rotating outfit preview above the moving wave at the board's edges.
	for dx in [-0.23, 0.0, 0.23]:
		for dz in [-0.88, 0.0, 0.88]:
			var offset: Vector3 = basis_on_water * Vector3(dx, 0, dz)
			p.y = maxf(p.y, wave.height_at(p.x + offset.x, p.z + offset.z) - offset.y + 0.04)
	if showcase_board:
		basis_on_water=basis_on_water*Basis(Vector3.BACK,PI)
		p.y+=0.16
	rider.visible=not showcase_board
	leash.visible=not showcase_board
	visual.global_transform = Transform3D(basis_on_water, p)
	rider.global_transform = visual.global_transform


func set_showcase(on: bool) -> void:
	_showcase = on
	_character_lod($Rider/SurferModel.find_child("Surfer",true,false) as MeshInstance3D)
	showcase_board=false
	rider.show()
	leash.show()
	if on:
		animator.jump_to("ride")
		animator.set_ride_blend(0.0, 0.0)
		visual.global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3(0, 0.05, 0))
		rider.global_transform = visual.global_transform
	else:
		animator.jump_to("prone_idle")


func reset_to(pos: Vector3, heading: float) -> void:
	tricks.reset()
	switch_stance=false
	state = State.PRONE
	_state_time = 0.0
	global_position = pos
	yaw = heading
	rotation = Vector3(0, yaw, 0)
	hvel = Vector2.ZERO
	carve = 0.0
	trim = 0.0
	balance = 0.0
	rail_load = 0.0
	turns.reset()
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
	_wake_loads.clear()
	_stand_buffer = 0.0
	_stand_grace = 0.0
	in_tube = false
	tube_seconds = 0.0
	tube_exits = 0
	_tube_hit = 0.0
	_tube_stint = 0.0
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
	_moved_by_trick=false
	tricks.advance(delta)
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
		State.AIRBORNE:
			_moved_by_trick=true
			tricks.air_step(delta)
		State.FLOATER:
			_moved_by_trick=true
			tricks.floater_step(delta)
		State.WIPEOUT, State.DONE:
			_do_after(delta, s)
	_move(delta, s)
	_update_visual(delta, s)
	_record_wake(delta)


func _record_wake(delta: float) -> void:
	_clock+=delta
	while not _wake.is_empty() and _clock-_wake.back().z>2.2:
		_wake.pop_back()
		_wake_loads.pop_back()
	_wake_timer-=delta
	if _wake_timer>0.0:
		return
	_wake_timer=0.09
	var strength := 0.0
	if is_riding() or state in [State.DONE,State.FLOATER]:
		strength=clampf((speed()-0.8)/7.0,0.0,1.25)*(0.65+0.45*minf(absf(rail_load),1.2))
	elif state==State.PRONE and speed()>0.8:
		strength=0.20*clampf(speed()/2.6,0.0,1.0)
	if strength<=0.0:
		return
	var tail: Vector3 = visual.global_transform*Vector3(0,0,0.65 if switch_stance else -0.65)
	# Do not stamp repeated segments while a stopped board drifts in place.
	if not _wake.is_empty() and Vector2(tail.x,tail.z).distance_to(Vector2(_wake[0].x,_wake[0].y))<0.10:
		return
	_wake.push_front(Vector4(tail.x,tail.z,_clock,strength))
	_wake_loads.push_front(clampf(rail_load,-1.2,1.2))
	var keep: int = Ajustes.preset()["wake_points"]
	while _wake.size()>keep:
		_wake.pop_back()
		_wake_loads.pop_back()


## Estela para el shader del agua (edad en segundos en lugar del instante).
func wake_points() -> PackedVector4Array:
	var out := PackedVector4Array()
	for w in _wake:
		out.append(Vector4(w.x, w.y, _clock - w.z, w.w))
	return out


func wake_loads() -> PackedFloat32Array:
	return PackedFloat32Array(_wake_loads)


## La tabla toca el agua (para la espuma de contacto).
func touching_water() -> bool:
	return state != State.AIRBORNE and (state != State.WIPEOUT or _state_time < 0.4)


# ------------------------------------------------------------------ tumbado

func _do_prone(delta: float, s: Dictionary) -> void:
	var st := Controles.stick()
	paddling = Controles.paddling() or st.y > 0.5
	yaw -= st.x * turn_rate_prone * delta * (1.0 if Controles.bot_enabled else Ajustes.steering_sensitivity)
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
	_stand_grace = 0.14 if can_stand else maxf(0.0, _stand_grace - delta)
	if Controles.take_stand():
		_stand_buffer = 0.22
	if _stand_buffer > 0.0:
		_stand_buffer -= delta
		if can_stand or (_stand_grace > 0.0 and s["broken"] < 0.4):
			_stand_buffer = 0.0
			_start_popup()
		elif _stand_buffer <= 0.0 and _hint_cooldown <= 0.0:
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
	if Ajustes.invert_weight and not Controles.bot_enabled:
		st.y = -st.y
	if not popup and tricks.surface(delta,s,st):
		return
	carve = lerpf(carve, st.x, 1.0 - exp(-8.0 * delta))
	trim = move_toward(trim, st.y, delta * 3.0)
	var spd := speed()
	# Rear-foot pressure closes the arc; speed and front-foot pressure open it.
	var rear_pressure := maxf(-trim,0.0)
	var pressure := carve*(1.0+rear_pressure*0.20)
	rail_load=lerpf(rail_load,pressure,1.0-exp(-10.0*delta))
	var speed_arc := lerpf(1.08,0.82,clampf((spd-4.0)/6.0,0.0,1.0))
	var weight_arc := 1.0+rear_pressure*0.20-maxf(trim,0.0)*0.12
	yaw -= carve*turn_rate_ride*clampf(spd/5.0,0.35,1.15)*speed_arc*weight_arc*delta*(1.0 if Controles.bot_enabled else Ajustes.steering_sensitivity)
	var f := Vector2(sin(yaw), cos(yaw))
	if switch_stance: f=-f
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
	kf += 0.035*carve*carve*clampf(spd/7.0,0.0,1.5)
	var grip := 5.5*(1.0+minf(absf(rail_load),1.2)*0.18)
	_drag(delta, Vector2(0.0, s["flow"] * 0.6), kf, grip)

	spd = speed()
	_update_tube(delta)
	if state == State.WIPEOUT:
		return
	animator.set_motion(speed(), balance, in_tube, 1.0 - (s["normal"] as Vector3).y, absf(rail_load))
	animator.set_ride_blend(clampf(rail_load,-1.0,1.0), minf(trim,-tricks.charge) if tricks.charge>0.0 else trim)
	if popup:
		if _state_time >= POPUP_TIME:
			state = State.RIDING
			_state_time = 0.0
			hint.emit("¡Arriba! Gira con %s / %s. Alterna peso para bombear; IMPULSO carga/suelta y TRUCO hace maniobras." % [Controles.key_label("surf_left"), Controles.key_label("surf_right")])
		return

	var ahead := (global_position.x-wave.peel_x)*wave.peel_dir
	if tricks.locks_turn(): turns.reset()
	var maneuver := {} if tricks.locks_turn() else turns.step(delta,carve,hvel,float(s["u"])/maxf(float(s["face_width"]),0.1),ahead,wave.peel_dir,profile>0.12 and float(s["broken"])<0.5)
	if not maneuver.is_empty():
		maneuver_completed.emit(maneuver)
	ride_time += delta
	ride_distance += spd * delta
	top_speed = maxf(top_speed, spd)

	# Equilibrio adelante/atrás: bajar en picado empuja hacia la punta, ir lento hacia la cola.
	var slope_along := -(n.x * f.x + n.z * f.y) / maxf(n.y, 0.2)
	var stall := clampf(1.0 - spd / 3.0, 0.0, 1.0)
	var chop := _noise.get_noise_1d(_state_time * 1.7) * (0.7 + wave.wind_chop)
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
			_wipeout("¡Al agua!", "Clavaste la punta. Echa el peso atrás (%s / joystick %s)." % [Controles.key_label("surf_up" if Ajustes.invert_weight else "surf_down"), "arriba" if Ajustes.invert_weight else "abajo"])
		else:
			_wipeout("¡Al agua!", "Te caíste de espaldas. Con poca velocidad, carga el pie delantero (%s)." % Controles.key_label("surf_down" if Ajustes.invert_weight else "surf_up"))
		return
	if s["broken"] > 0.55 and profile > 0.18 and not in_tube:
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
	tricks.cancel_input()
	maneuver_failed.emit()
	state = State.WIPEOUT
	_state_time = 0.0
	_end_success = false
	_end_title = title
	_end_detail = detail
	_rider_detached = true
	_fall_yaw = yaw
	_fall_sign = -1.0 if balance < -0.15 or carve < -0.4 else 1.0
	_spin = _fall_sign * (1.0 + clampf(speed() / 6.0, 0.0, 1.4))
	in_tube = false
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
		var tumble := sin(minf(_state_time * 2.0, PI)) * 0.55
		rider.global_transform = Transform3D(Basis(q) * Basis(Vector3.FORWARD, tumble * _fall_sign), rp)
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
	if _moved_by_trick or state in [State.AIRBORNE,State.FLOATER]: return
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
	if state==State.AIRBORNE:
		var b_air := Basis(Vector3.UP,yaw+tricks.air_spin)*Basis(Vector3.RIGHT,tricks.air_pitch)
		visual.global_transform=Transform3D(b_air,global_position)
		rider.global_transform=visual.global_transform
		wake.emitting=false
		return
	var n: Vector3 = s["normal"]
	var up_target := n if (is_riding() or state in [State.DONE,State.FLOATER]) else n.lerp(Vector3.UP, 0.3).normalized()
	var k := 1.0 if delta == 0.0 else 1.0 - exp(-10.0 * delta)
	_up = _up.lerp(up_target, k).normalized()
	var f := forward().rotated(Vector3.UP,tricks.landing_yaw_offset)
	var fwd := (f - _up * f.dot(_up)).normalized()
	var b := Basis(_up.cross(fwd), _up, fwd)
	var roll := 0.0
	var pitch := -0.05
	if is_riding() or state == State.DONE:
		roll = rail_load * deg_to_rad(max_roll_deg) * clampf(speed() / 5.0, 0.3, 1.0)
		pitch = trim * 0.05
	elif state == State.WIPEOUT:
		roll = _roll_wipe
		pitch = 0.0
	b = b * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	visual.global_transform = Transform3D(b, global_position)
	if not _rider_detached:
		rider.global_transform = visual.global_transform
	# Small ballistic spray from the outside rail; surface ribbons carry the foam.
	var spd := speed()
	var load := minf(absf(rail_load),1.2)
	var spray := maxf(tricks.impact,clampf((spd-2.5)/7.0,0.0,1.0)*(0.15+0.85*load))
	wake.emitting=state==State.RIDING and spd>2.8 and spray>0.025
	wake.position=Vector3(signf(rail_load)*0.18,0.04,0.52 if switch_stance else -0.52)
	wake.direction=Vector3(rail_load*1.7,0.65,0.8 if switch_stance else -0.8)
	if in_tube and tricks.tube_action=="hand_drag":
		var sk := animator.skeleton
		var hand := sk.get_bone_global_pose(sk.find_bone("hand_L"))
		var p: Vector3 = sk.global_transform*(hand*Vector3(0,0.191,0))
		p.y=wave.height_at(p.x,p.z)+0.015
		wake.position=visual.to_local(p)
		wake.direction=Vector3(-0.5,0.4,-0.5)
		spray=maxf(spray,0.35)
	wake.initial_velocity_min=0.45+spray*0.40
	wake.initial_velocity_max=0.85+spray*3.1
	wake.scale_amount_min=0.10
	wake.scale_amount_max=0.16+spray*0.28
	wake.spread=14.0+load*12.0
	wake.color=Color(0.82,0.94,1.0,0.35+spray*0.45)



func _update_tube(delta: float) -> void:
	var data := wave.tube_at(global_position, tricks.tube_head_height() if in_tube else 1.5)
	var was := in_tube
	in_tube = state == State.RIDING and data["inside"]
	if in_tube:
		tube_seconds += delta
		_tube_stint += delta
		if not was:
			tricks._rail_time=0.0
			tricks._drag_time=0.0
			hint.emit("¡Tubo! TRUCO agarra canto; con peso atrás frena con la mano. Bombea para recuperar velocidad y salir.")
		_tube_hit = _tube_hit + delta if data["clearance"] < 0.0 else maxf(0.0, _tube_hit - delta * 2.0)
		if _tube_hit > 0.20:
			_wipeout("Cerró el tubo", "El labio te alcanzó. Mantente en el centro y busca la salida.")
	elif was:
		if data["ahead"] > 6.0 and _tube_stint > 0.6:
			tube_exits += 1
			tube_exit.emit(_tube_stint)
		_tube_stint = 0.0
		_tube_hit = 0.0


func _character_lod(body: MeshInstance3D) -> void:
	# Anatomical face/fingers should not collapse in the outfit preview or close camera.
	# Keep automatic simplification at distance and a lighter bias on low-end phones.
	body.lod_bias=6.0 if _showcase else (4.0 if Ajustes.preset()["detail"] else 1.5)
