class_name SurfTurns
extends RefCounted
## Classifies real trajectory arcs. Holding a direction without moving earns nothing.
var _active := false
var _armed := true
var _cooldown := 0.0
var _sign := 0.0
var _time := 0.0
var _distance := 0.0
var _angle := 0.0
var _absolute_angle := 0.0
var _last_heading := 0.0
var _peak_speed := 0.0
var _start_ratio := 0.0
var _min_ratio := 0.0
var _max_ratio := 0.0
var _start_ahead := 0.0
var _start_projection := 0.0
var _went_back := false

func reset() -> void:
	_active=false
	_armed=true
	_cooldown=0.0
	_time=0.0
	_distance=0.0
	_angle=0.0
	_absolute_angle=0.0
	_went_back=false

func step(delta: float, steering: float, velocity: Vector2, ratio: float, ahead: float, peel_dir: float, clean_face: bool) -> Dictionary:
	_cooldown=maxf(0.0,_cooldown-delta)
	var speed := velocity.length()
	if absf(steering)<0.20: _armed=true
	if not clean_face or speed<3.0:
		# Un giro que sube la pared gasta velocidad: si ya trazó el arco, se evalúa
		# (antes se descartaba y el bottom turn bien hecho no contaba).
		if _active and clean_face and _time>0.28:
			return _finish()
		_active=false
		return {}
	var heading := atan2(velocity.x,velocity.y)
	if _active:
		var change := wrapf(heading-_last_heading,-PI,PI)
		_angle+=change
		_absolute_angle+=absf(change)
		_last_heading=heading
		_time+=delta
		_distance+=speed*delta
		_peak_speed=maxf(_peak_speed,speed)
		_min_ratio=minf(_min_ratio,ratio)
		_max_ratio=maxf(_max_ratio,ratio)
		_went_back=_went_back or velocity.x*peel_dir/speed < -0.35
		if absf(steering)<0.20 or (signf(steering)!=_sign and absf(steering)>0.3):
			return _finish()
		if _time>4.0:
			_armed=false
			_active=false
			return {}
	elif _armed and _cooldown<=0.0 and absf(steering)>0.48:
		_active=true
		_sign=signf(steering)
		_time=0.0
		_distance=0.0
		_angle=0.0
		_absolute_angle=0.0
		_last_heading=heading
		_peak_speed=speed
		_start_ratio=ratio
		_min_ratio=ratio
		_max_ratio=ratio
		_start_ahead=ahead
		_start_projection=velocity.x*peel_dir/speed
		_went_back=false
	return {}

func _finish() -> Dictionary:
	_active=false
	_cooldown=0.25
	var angle := absf(_angle)
	if OS.has_environment("TURN_LOG"):
		print("[turn] t=%.2f d=%.1f ang=%.0f abs=%.0f r0=%.2f rmin=%.2f rmax=%.2f back=%s" % [_time,_distance,rad_to_deg(angle),rad_to_deg(_absolute_angle),_start_ratio,_min_ratio,_max_ratio,_went_back])
	var strong_climb := _start_ratio>=0.95 and _start_ratio-_min_ratio>=0.6
	var min_angle := deg_to_rad(15.0 if strong_climb else 24.0)
	if _time<0.28 or _distance<2.4 or angle<min_angle or angle>deg_to_rad(280.0): return {}
	if angle<0.75*_absolute_angle: return {}
	var kind := "carving"
	if _went_back and _start_projection>0.35 and _start_ahead>3.5 and angle>=deg_to_rad(105.0) and _distance>4.0:
		kind="cutback"
	elif _start_ratio>=0.95 and ((_start_ratio-_min_ratio>=0.22 and angle>=deg_to_rad(32.0)) or _start_ratio-_min_ratio>=0.6):
		# Desde la base hacia la cresta. Una subida fuerte cuenta aunque el rumbo gire poco
		# (la gravedad curva la trayectoria al subir la pared).
		kind="bottom_turn"
	elif _start_ratio<=0.45 and _max_ratio-_min_ratio>=0.15 and angle>=deg_to_rad(40.0):
		# Arriba en la pared (cerca de la cresta) y el giro te devuelve hacia abajo.
		kind="top_turn"
	return {"kind":kind,"speed":_peak_speed,"angle":angle,"distance":_distance,"duration":_time}
