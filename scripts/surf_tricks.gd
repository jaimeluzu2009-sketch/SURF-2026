class_name SurfTricks
extends RefCounted
## Trucos sobre la misma superficie analítica que mueve y dibuja el océano.
## No guarda una referencia fuerte al surfista (evita ciclos RefCounted/Node).
const MIN_AIR_CHARGE := 0.18
var _owner: WeakRef
var charge := 0.0
var impact := 0.0
var air_spin := 0.0
var air_pitch := 0.0
var landing_yaw_offset := 0.0
var air_time := 0.0
var air_vy := 0.0
var tube_action := ""
var last_landing := ""
var pump_count := 0
var _charge_held := false
var _trick_held := false
var _charge_release := false
var _trick_press := false
var _previous_charge := false
var _previous_trick := false
var _suppress := false
var _cooldown := 0.0
var _pump_clock := 5.0
var _pump_phase := 0
var _pump_travel := 0.0
var _snap_time := 0.0
var _snap_heading := 0.0
var _snap_sign := 0.0
var _turn_lock := 0.0
var _takeoff_yaw := 0.0
var _takeoff_speed := 0.0
var _takeoff_switch := false
var _grab_time := 0.0
var _float_time := 0.0
var _float_distance := 0.0
var _float_exit := false
var _rail_time := 0.0
var _drag_time := 0.0

func setup(s: Surfer) -> void:
	_owner = weakref(s)
	s.tube_exit.connect(_on_tube_exit)

func surfer() -> Surfer:
	return _owner.get_ref() as Surfer

func reset() -> void:
	charge=0.0
	impact=0.0
	air_spin=0.0
	air_pitch=0.0
	landing_yaw_offset=0.0
	air_time=0.0
	tube_action=""
	last_landing=""
	pump_count=0
	_previous_charge=false
	_previous_trick=false
	_suppress=false
	_cooldown=0.0
	_pump_clock=5.0
	_pump_phase=0
	_pump_travel=0.0
	_snap_time=0.0
	_turn_lock=0.0
	_float_exit=false
	_rail_time=0.0
	_drag_time=0.0

func cancel_input() -> void:
	charge=0.0
	_suppress=true
	_previous_charge=false
	_previous_trick=false

func advance(delta: float) -> void:
	var s := surfer()
	_charge_held=Controles.impulse_held()
	_trick_held=Controles.trick_held()
	if _suppress:
		if not _charge_held and not _trick_held: _suppress=false
		_charge_held=false
		_trick_held=false
	_charge_release=_previous_charge and not _charge_held
	_trick_press=_trick_held and not _previous_trick
	_previous_charge=_charge_held
	_previous_trick=_trick_held
	_cooldown=maxf(0.0,_cooldown-delta)
	_turn_lock=maxf(0.0,_turn_lock-delta)
	impact=move_toward(impact,0.0,delta*3.0)
	landing_yaw_offset*=exp(-18.0*delta)
	_pump_clock+=delta
	if s.state!=Surfer.State.RIDING:
		charge=0.0

func surface(delta: float, sample: Dictionary, stick: Vector2) -> bool:
	var s := surfer()
	var clean := float(sample.profile)>0.2 and float(sample.broken)<0.5
	var ratio: float = float(sample.u)/maxf(float(sample.face_width),0.1)
	# El bombeo requiere alternar compresión/extensión, tiempo y desplazamiento.
	_pump_travel+=s.speed()*delta
	var phase := 1 if stick.y>0.5 else (-1 if stick.y< -0.5 else 0)
	if phase!=0 and phase!=_pump_phase:
		if _pump_phase!=0 and _pump_clock>=0.18 and _pump_clock<=0.9 and _pump_travel>1.1 and clean and s.speed()>3.0:
			# La energía sale de la ola: rinde más en la pared alta (perfil) y cerca del
			# bolsillo, y se agota al acercarse al límite que esa ola puede dar.
			var limit: float = s.wave.speed*2.3
			var energy := clampf(1.0-s.speed()/limit,0.0,1.0)*clampf(float(sample.profile)*1.4,0.3,1.0)
			var gain := clampf(0.8-(s.speed()-6.0)*0.10,0.10,0.9)*energy
			if gain>0.03:
				s.hvel+=s.hvel.normalized()*gain
				pump_count+=1
				impact=0.12
				s.hint.emit("BOMBEO · impulso ganado")
			else:
				s.hint.emit("BOMBEO sin efecto: ya vas al máximo de esta ola o estás fuera de la pared")
		_pump_clock=0.0
		_pump_travel=0.0
		_pump_phase=phase
	if _charge_held and clean and not s.in_tube:
		charge=minf(1.0,charge+delta/0.65)
		s.animator.set_ride_blend(s.carve,-charge)
	if _charge_release:
		var power := charge
		charge=0.0
		if power>MIN_AIR_CHARGE and launch_available(sample):
			launch(power)
			return true
		elif power>MIN_AIR_CHARGE:
			s.hint.emit("Para despegar: velocidad y labio de la ola. Suelta IMPULSO cerca de la cresta.")
	_update_snap(delta,clean)
	if s.in_tube:
		if _trick_held:
			tube_action="hand_drag" if stick.y< -0.35 else "tube_rail"
			s.animator.travel(tube_action)
			if tube_action=="hand_drag":
				s.hvel*=exp(-0.35*delta)
				_drag_time+=delta
			else:
				s.balance*=exp(-1.8*delta)
				_rail_time+=delta
		elif tube_action!="":
			tube_action=""
			s.animator.travel("ride")
	elif tube_action!="":
		tube_action=""
		s.animator.travel("ride")
	if _trick_press and not s.in_tube and _cooldown<=0.0:
		if absf(ratio)<0.58 and clean and s.speed()>=4.5:
			if absf(stick.x)>0.4:
				_snap_time=0.38
				_snap_sign=signf(stick.x)
				_snap_heading=atan2(s.hvel.x,s.hvel.y)
				_turn_lock=0.65
				s.turns.reset()
				s.animator.travel("snap")
				_cooldown=0.8
			elif absf(s.hvel.normalized().x)>0.65 and (s.global_position.x-s.wave.peel_x)*s.wave.peel_dir<2.8 and (s.global_position.x-s.wave.peel_x)*s.wave.peel_dir> -1.4:
				start_floater()
				return true
			else:
				s.hint.emit("Para el FLOATER, entra en el labio junto a la espuma con velocidad lateral.")
		else:
			s.hint.emit("TRUCO en el labio: con giro = snap; sin giro = floater. En el aire: mantener para agarrar.")
	return false

func launch_available(sample: Dictionary) -> bool:
	return _cooldown <= 0.0 and can_launch(sample)

func can_launch(sample: Dictionary) -> bool:
	var s := surfer()
	var direction := Vector2(sin(s.yaw),cos(s.yaw))*(-1.0 if s.switch_stance else 1.0)
	return s.hvel.normalized().dot(direction)>0.70 and s.state==Surfer.State.RIDING and not s.in_tube and s.speed()>=5.0 and absf(float(sample.u))<float(sample.face_width)*0.70 and float(sample.profile)>0.5 and float(sample.broken)<0.5

func _update_snap(delta: float, clean: bool) -> void:
	if _snap_time<=0.0: return
	var s := surfer()
	s.yaw-=_snap_sign*2.6*delta
	_snap_time-=delta
	if _snap_time<=0.0:
		var angle := absf(wrapf(atan2(s.hvel.x,s.hvel.y)-_snap_heading,-PI,PI))
		if angle>0.30 and s.speed()>3.0 and clean:
			s.maneuver_completed.emit({"kind":"snap","speed":s.speed(),"angle":angle})
		s.animator.travel("ride")

func locks_turn() -> bool:
	return _turn_lock>0.0

func launch(power: float, floater_exit := false) -> void:
	var s := surfer()
	s.state=Surfer.State.AIRBORNE
	s._state_time=0.0
	_snap_time=0.0
	_takeoff_yaw=s.yaw
	_takeoff_speed=s.speed()
	_takeoff_switch=s.switch_stance
	air_time=0.0
	air_spin=0.0
	air_pitch=0.0
	_grab_time=0.0
	_float_exit=floater_exit
	air_vy=1.8 if floater_exit else lerpf(2.7,5.0,power)
	s.turns.reset()
	s.in_tube=false
	s.animator.travel("air")
	s.hint.emit("AÉREO · gira con el joystick; mantén TRUCO para agarrar. Suelta el giro para alinear 0° o 180°.")
	_cooldown=0.6

func air_step(delta: float) -> void:
	var s := surfer()
	var stick := Controles.stick()
	air_time+=delta
	air_vy-=WaveModel.G*delta
	if not _float_exit:
		air_spin=clampf(air_spin-stick.x*4.8*delta*(1.0 if Controles.bot_enabled else Ajustes.steering_sensitivity),-PI*1.35,PI*1.35)
		var weight := -stick.y if Ajustes.invert_weight and not Controles.bot_enabled else stick.y
		air_pitch=lerpf(air_pitch,weight*0.45,1.0-exp(-7.0*delta))
		if _trick_held:
			_grab_time+=delta
		s.animator.travel("grab" if _trick_held else "air")
	s.hvel*=exp(-0.045*delta)
	s.velocity=Vector3(s.hvel.x,air_vy,s.hvel.y)
	s.move_and_slide()
	s.hvel=Vector2(s.velocity.x,s.velocity.z)
	s.ride_time+=delta
	s.ride_distance+=s.speed()*delta
	s.top_speed=maxf(s.top_speed,s.speed())
	var sample := s.wave.sample(s.global_position.x,s.global_position.z)
	var deck: float = float(sample.height)+Surfer.DECK_RIDE
	if air_vy<0.0 and air_time>0.12 and s.global_position.y<=deck:
		land(sample)
	elif s.get_slide_collision_count()>0 or air_time>2.2:
		s._wipeout("Aéreo fallido","No pudiste volver a la cara de la ola.")

func landing_error() -> float:
	return minf(absf(wrapf(air_spin,-PI,PI)),absf(wrapf(air_spin-PI,-PI,PI)))

func land(sample: Dictionary) -> void:
	var s := surfer()
	var error := landing_error()
	var course := _takeoff_yaw+(PI if _takeoff_switch else 0.0)
	var course_error := absf(wrapf(atan2(s.hvel.x,s.hvel.y)-course,-PI,PI))
	var n: Vector3 = sample.normal
	var why := landing_failure(error,course_error,n,sample)
	if why!="":
		s._wipeout("Aterrizaje fallido",why)
		return
	var half_turn := absf(air_spin)>PI*0.5
	s.yaw=_takeoff_yaw+(signf(air_spin)*PI if half_turn else 0.0)
	landing_yaw_offset=air_spin-(signf(air_spin)*PI if half_turn else 0.0)
	s.switch_stance=(_takeoff_switch != half_turn)
	s.global_position.y=float(sample.height)+Surfer.DECK_RIDE
	s.state=Surfer.State.RIDING
	s._state_time=0.0
	s._foam_time=0.0
	s._danger=0.0
	s.balance=0.0 if error<0.2 else 0.35
	var quality := 1.2 if error<0.16 and absf(air_pitch)<0.12 else (1.0 if error<0.38 else 0.7)
	last_landing="PERFECTO" if quality>1.0 else ("LIMPIO" if quality==1.0 else "AJUSTADO")
	s.hvel*=lerpf(0.78,0.96,clampf(quality-0.2,0.0,1.0))
	impact=0.9
	s.animator.travel("landing")
	var kind := "air180" if half_turn else "air"
	if _grab_time>=0.18: kind="grab180" if half_turn else "grab_air"
	if _float_exit: kind="floater"
	if not _float_exit or (_float_time>=0.25 and _float_distance>=2.0):
		s.maneuver_completed.emit({"kind":kind,"speed":_takeoff_speed,"quality":quality,"landing":last_landing})
	s.hint.emit("ATERRIZAJE %s%s" % [last_landing," · SWITCH" if s.switch_stance else ""])
	_turn_lock=0.28
	_float_exit=false

## Motivo concreto de una recepción fallida ("" si es válida). Tolerancias: ±34° de
## rotación respecto a 0°/180°, peso ±0.34, trayectoria ±41° respecto al despegue.
func landing_failure(error: float, course_error: float, n: Vector3, sample: Dictionary) -> String:
	if error>deg_to_rad(34.0):
		return "Caíste girado %d° respecto a 0°/180°: suelta el giro antes para alinear la tabla." % int(rad_to_deg(error))
	if absf(air_pitch)>0.34:
		return "Peso muy %s al caer: centra el joystick antes de tocar el agua." % ("adelante" if air_pitch>0.0 else "atrás")
	if course_error>0.72:
		return "La tabla no apuntaba hacia donde ibas: despega con más velocidad en línea recta."
	if float(sample.broken)>0.55:
		return "Caíste en la espuma: despega antes del punto de rotura para volver a la pared limpia."
	if float(sample.profile)<0.12 or n.y<0.42:
		return "Caíste fuera de la pared (agua plana o demasiado vertical): busca el labio con menos altura."
	if air_vy< -8.0:
		return "Caída demasiado alta y dura: carga menos IMPULSO."
	return ""

func start_floater() -> void:
	var s := surfer()
	s.state=Surfer.State.FLOATER
	s._state_time=0.0
	_float_time=0.0
	_float_distance=0.0
	_snap_time=0.0
	s.turns.reset()
	s.animator.travel("floater")
	s.hint.emit("FLOATER · mantén TRUCO sobre la cresta; suelta para volver a la cara.")

func floater_step(delta: float) -> void:
	var s := surfer()
	_float_time+=delta
	_float_distance+=absf(s.hvel.x)*delta
	var z := s.wave.crest_z+s.wave.front_width*0.12
	s.hvel.y=lerpf(s.hvel.y,s.wave.speed+clampf((z-s.global_position.z)*4.0,-3.0,3.0),1.0-exp(-10.0*delta))
	s.hvel.x*=exp(-0.12*delta)
	var target: float = s.wave.height_at(s.global_position.x,s.global_position.z)+Surfer.DECK_RIDE+0.07
	s.velocity=Vector3(s.hvel.x,clampf((target-s.global_position.y)*14.0,-8.0,8.0),s.hvel.y)
	s.move_and_slide()
	s.ride_time+=delta
	s.ride_distance+=s.speed()*delta
	s.top_speed=maxf(s.top_speed,s.speed())
	if s.get_slide_collision_count()>0:
		s._wipeout("Floater fallido","La tabla chocó contra las rocas.")
		return
	if (_float_time>0.25 and not _trick_held) or _float_time>1.15 or s.speed()<3.0:
		s.hvel.y=s.wave.speed+2.0
		s.yaw=atan2(s.hvel.x,s.hvel.y)+(PI if s.switch_stance else 0.0)
		launch(0.0,true)

func tube_head_height() -> float:
	return 1.0 if tube_action!="" else 1.25

func _on_tube_exit(_duration: float) -> void:
	var s := surfer()
	if maxf(_rail_time,_drag_time)>=0.25:
		s.maneuver_completed.emit({"kind":"hand_drag" if _drag_time>_rail_time else "tube_rail","speed":maxf(3.0,s.speed())})
	_rail_time=0.0
	_drag_time=0.0

func status() -> String:
	var s := surfer()
	if s.state not in [Surfer.State.RIDING,Surfer.State.AIRBORNE,Surfer.State.FLOATER]: return ""
	if s.state==Surfer.State.AIRBORNE:
		return "%s · %d° · %s" % ["AGARRE" if _trick_held else "AÉREO",int(absf(rad_to_deg(air_spin))),"ALINEADO" if landing_error()<0.30 and absf(air_pitch)<0.20 else "ALINEA"]
	if s.state==Surfer.State.FLOATER: return "FLOATER · %.1f m" % _float_distance
	if tube_action!="": return "MANO EN EL AGUA" if tube_action=="hand_drag" else "AGARRE DEL CANTO"
	if charge>0.0: return "IMPULSO %d%% · SUELTA EN EL LABIO" % int(charge*100.0)
	if _snap_time>0.0: return "SNAP"
	return ""
