class_name SurferAnimator
extends Node
## Crea el AnimationTree del surfista:
## tumbado / remar / ponerse de pie / surfear (BlendSpace2D: giro × peso) / caer.

const LOOPS := ["prone_idle", "paddle", "ride", "carve_left", "carve_right", "lean_fwd", "lean_back", "tube_crouch"]

var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var skeleton: Skeleton3D
var _motion_speed := 0.0
var _motion_balance := 0.0
var _crouch := false
var _breath := 0.0
var _ride_target := Vector2.ZERO
var _ride_blend := Vector2.ZERO
var _speed_target := 0.0
var _balance_target := 0.0
var _slope_target := 0.0
var _tuck := 0.0
var _turn_load := 0.0
var _secondary_source := {}
var _secondary_result := {}
var _posing := false


func setup(model: Node) -> void:
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	for anim_name in LOOPS:
		player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

	var sm := AnimationNodeStateMachine.new()
	sm.add_node("prone_idle", _anim("prone_idle"))

	var paddle := AnimationNodeBlendTree.new()
	paddle.add_node("anim", _anim("paddle"))
	paddle.add_node("speed", AnimationNodeTimeScale.new())
	paddle.connect_node("speed", 0, "anim")
	paddle.connect_node("output", 0, "speed")
	sm.add_node("paddle", paddle)

	sm.add_node("popup", _anim("popup"))
	sm.add_node("fall", _anim("fall"))

	var ride := AnimationNodeBlendSpace2D.new()
	var points := {"ride": Vector2.ZERO, "carve_right": Vector2(1, 0), "carve_left": Vector2(-1, 0),
		"lean_fwd": Vector2(0, 1), "lean_back": Vector2(0, -1)}
	for anim_name in points:
		ride.add_blend_point(_anim(anim_name), points[anim_name], -1, anim_name)
	var surf := AnimationNodeBlendTree.new()
	surf.add_node("surf", ride)
	surf.add_node("tuck", _anim("tube_crouch"))
	var mix := AnimationNodeBlend2.new()
	surf.add_node("mix", mix)
	surf.connect_node("mix", 0, "surf")
	surf.connect_node("mix", 1, "tuck")
	surf.connect_node("output", 0, "mix")
	sm.add_node("ride", surf)

	_link(sm, "prone_idle", "paddle", 0.3)
	_link(sm, "paddle", "prone_idle", 0.4)
	_link(sm, "prone_idle", "popup", 0.12)
	_link(sm, "paddle", "popup", 0.12)
	var auto := _link(sm, "popup", "ride", 0.12)
	auto.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	auto.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	for from in ["ride", "popup", "paddle", "prone_idle"]:
		_link(sm, from, "fall", 0.15)
	_link(sm, "fall", "prone_idle", 0.5)
	_link(sm, "ride", "prone_idle", 0.5)

	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = sm
	tree.active = true
	playback = tree.get("parameters/playback")
	playback.start("prone_idle")
	skeleton.skeleton_updated.connect(_secondary_pose)


func _anim(anim_name: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = anim_name
	return a


func _link(sm: AnimationNodeStateMachine, from: String, to: String, xfade: float) -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	sm.add_transition(from, to, t)
	return t


func travel(state: String) -> void:
	if playback and playback.get_current_node() != state:
		playback.travel(state)


func jump_to(state: String) -> void:
	if playback:
		playback.start(state)


func current() -> String:
	return playback.get_current_node() if playback else ""


func set_ride_blend(carve: float, trim: float) -> void:
	_ride_target = Vector2(clampf(carve,-1.0,1.0),clampf(trim,-1.0,1.0))
	var total := absf(_ride_target.x) + absf(_ride_target.y)
	if total > 1.0:
		_ride_target /= total


func set_paddle_speed(s: float) -> void:
	tree.set("parameters/paddle/speed/scale", s)


## Posición global (interpolada) de la cabeza de un hueso.
func bone_position(bone: String) -> Vector3:
	var i := skeleton.find_bone(bone)
	return skeleton.get_global_transform_interpolated() * skeleton.get_bone_global_pose(i).origin


func set_motion(spd: float, balance: float, crouch: bool, slope := 0.0, turn_load := 0.0) -> void:
	_speed_target = maxf(0.0, spd)
	_balance_target = clampf(balance, -1.0, 1.0)
	_slope_target = clampf(slope, 0.0, 1.0)
	_crouch = crouch
	_turn_load = clampf(turn_load,0.0,1.2)

func _process(delta: float) -> void:
	_breath = fmod(_breath + delta, 100.0)
	var k := 1.0 - exp(-8.0 * delta)
	_motion_speed = lerpf(_motion_speed, _speed_target, k)
	_motion_balance = lerpf(_motion_balance, _balance_target, k)
	_ride_blend = _ride_blend.lerp(_ride_target, k)
	var tuck_goal := 0.92 if _crouch else clampf(_motion_speed * 0.008 + _slope_target * 0.18 + _turn_load * 0.10, 0.0, 0.28)
	_tuck = lerpf(_tuck, tuck_goal, k)
	if tree:
		tree.set("parameters/ride/surf/blend_position", _ride_blend)
		tree.set("parameters/ride/mix/blend_amount", _tuck)

func _secondary_pose() -> void:
	if _posing or current() != "ride":
		return
	_posing = true
	# Upper body only: compression uses an authored pose with feet on the board.
	for entry in [["chest", Vector3.RIGHT, _motion_balance * 0.06 + sin(_breath * 2.4) * 0.010],
		["spine", Vector3.RIGHT, -0.025 * clampf(_motion_speed / 8.0, 0.0, 1.0)],
		["head", Vector3.UP, _ride_blend.x * 0.10],
		["upper_arm_L", Vector3.FORWARD, sin(_breath * 1.8) * 0.025],
		["upper_arm_R", Vector3.FORWARD, -sin(_breath * 1.8) * 0.025]]:
		var bone := skeleton.find_bone(entry[0])
		if bone < 0:
			continue
		var source := skeleton.get_bone_pose_rotation(bone)
		if _secondary_result.has(bone) and source.is_equal_approx(_secondary_result[bone]):
			source = _secondary_source[bone]
		_secondary_source[bone] = source
		var result: Quaternion = source * Quaternion(entry[1], entry[2])
		_secondary_result[bone] = result
		skeleton.set_bone_pose_rotation(bone, result)
	_posing = false
