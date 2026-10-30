class_name SurfAudio
extends Node
var sea: AudioStreamPlayer
var glide: AudioStreamPlayer
var wash: AudioStreamPlayer
var paddle: AudioStreamPlayer
var fall: AudioStreamPlayer
var _stroke := 0.0
var _wash_timer := 0.0
var _last_state := -1
var _mix := 0.0
var _filter: AudioEffectLowPassFilter
func _player(path: String, looped := false) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path).duplicate()
	if looped:
		(p.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(p.stream as AudioStreamWAV).loop_end = int(p.stream.get_length() * 22050)
	add_child(p)
	return p
func _ready() -> void:
	var bus := AudioServer.get_bus_index("SurfSea")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "SurfSea")
		_filter = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(bus, _filter)
	else:
		_filter = AudioServer.get_bus_effect(bus, 0)
	sea = _player("res://audio/mar.wav", true)
	glide = _player("res://audio/mar.wav", true)
	wash = _player("res://audio/espuma.wav")
	paddle = _player("res://audio/remada.wav")
	fall = _player("res://audio/inmersion.wav")
	for player in [sea, glide, wash]:
		player.bus = "SurfSea"
	sea.volume_db = -16.0
	glide.volume_db = -55.0
	sea.play()
	glide.play()
func sync(delta: float, surfer: Surfer, playing: bool) -> void:
	_mix = move_toward(_mix, 1.0 if surfer.in_tube else 0.0, delta * 3.0)
	sea.volume_db = -16.0 - _mix * 10.0
	sea.pitch_scale = lerpf(1.0, 0.85, _mix)
	_filter.cutoff_hz = lerpf(16000.0, 1100.0, _mix)
	glide.volume_db = lerpf(-50.0, -19.0, clampf(surfer.speed() / 8.0, 0.0, 1.0)) - (0.0 if playing else 14.0)
	if surfer.state==Surfer.State.AIRBORNE: glide.volume_db-=24.0
	if surfer.state==Surfer.State.RIDING and _last_state==Surfer.State.AIRBORNE:
		fall.volume_db=-19.0
		fall.play()
	glide.pitch_scale = 0.9 + absf(surfer.carve) * 0.5
	if not playing:
		return
	_stroke -= delta
	_wash_timer -= delta
	if surfer.paddling and surfer.state == Surfer.State.PRONE and _stroke <= 0.0:
		_stroke = 0.72
		paddle.volume_db = -12.0
		paddle.play()
	if surfer.touching_water() and float(surfer.last_sample.get("broken", 0.0)) > 0.3 and _wash_timer <= 0.0:
		_wash_timer = 2.5
		wash.volume_db = -15.0 + _mix * 5.0
		wash.play()
	if surfer.state == Surfer.State.WIPEOUT and _last_state != surfer.state:
		fall.volume_db = -6.0
		fall.play()
	_last_state = surfer.state

func _exit_tree() -> void:
	for p in [sea, glide, wash, paddle, fall]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
