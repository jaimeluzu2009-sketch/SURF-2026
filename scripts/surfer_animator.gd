class_name SurferAnimator
extends Node
## Crea el AnimationTree del surfista:
## tumbado / remar / ponerse de pie / surfear (BlendSpace2D: giro × peso) / caer.

const LOOPS := ["prone_idle", "paddle", "ride", "carve_left", "carve_right", "lean_fwd", "lean_back"]

var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var skeleton: Skeleton3D


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
	sm.add_node("ride", ride)

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
	tree.set("parameters/ride/blend_position", Vector2(carve, trim))


func set_paddle_speed(s: float) -> void:
	tree.set("parameters/paddle/speed/scale", s)


## Posición global (interpolada) de la cabeza de un hueso.
func bone_position(bone: String) -> Vector3:
	var i := skeleton.find_bone(bone)
	return skeleton.get_global_transform_interpolated() * skeleton.get_bone_global_pose(i).origin
