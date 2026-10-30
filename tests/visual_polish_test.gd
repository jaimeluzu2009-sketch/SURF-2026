extends Node
var game: Game
var folder := ""
func _ready() -> void:
	game=get_parent()
	run.call_deferred()
func shot(name: String) -> void:
	for i in 12: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder+"/"+name+".png")
func run() -> void:
	Ajustes.persist=false
	Ajustes.adaptive=false
	Ajustes.set_quality(1)
	game.set_physics_process(false)
	game.cam.set_process(false)
	game.surfer.set_frozen(true)
	folder="res://capturas/pulido_realista/"+("antes" if "--visual-before" in OS.get_cmdline_user_args() else "despues")
	DirAccess.make_dir_recursive_absolute(folder)
	game.wave.time=5.0
	game.wave.update()
	game.cam._t=10.0
	game.cam.mode=CameraRig.Mode.CINEMATIC
	game.cam.snap_now()
	for i in 120: game.cam._menu_camera(1.0/60.0)
	await shot("menu_agua")
	Perfil.set_style(1)
	game.menus.open("custom","main")
	game.cam.snap_now()
	for i in 120: game.cam._menu_camera(1.0/60.0)
	await shot("surfista_menu")
	game.menus.close()
	game.surfer.set_frozen(true)
	var s := game.surfer
	game.wave.time=15.0
	game.wave.update()
	var w := game.wave
	var x := w.peel_x+w.peel_dir*8.0
	var z := w.crest_z+w.front_width*.8
	s.reset_to(Vector3(x,w.height_at(x,z)+.045,z),w.peel_dir*PI*.5)
	s.state=Surfer.State.RIDING
	s.hvel=Vector2(w.peel_dir*7.0,w.speed)
	s.animator.jump_to("ride")
	s.animator.set_motion(7,0,false)
	s.animator.set_ride_blend(0,0)
	s._update_visual(0.0,w.sample(x,z))
	s.reset_physics_interpolation()
	for i in 4: await RenderingServer.frame_post_draw
	game.cam.look_at_from_position(s.global_position+Vector3(-w.peel_dir*2.4,1.7,3.0),s.global_position+Vector3(0,.8,0))
	await shot("surfeando")
	if "--full-lod" in OS.get_cmdline_user_args():
		(s.get_node("Rider/SurferModel").find_child("Surfer",true,false) as MeshInstance3D).lod_bias=1000.0
	var sk := s.animator.skeleton
	var b := sk.find_bone("head")
	var deform := sk.get_bone_global_pose(b)*sk.get_bone_global_rest(b).affine_inverse()
	var center: Vector3 = sk.global_transform*(deform*Vector3(0,1.685,.012))
	var front: Vector3 = (sk.global_basis*deform.basis*Vector3.BACK).normalized()
	game.cam.look_at_from_position(center+front*.52+Vector3(.06,.035,0),center-Vector3(0,.035,0))
	await shot("rostro")
	for quality in 3:
		Ajustes.set_quality(quality)
		game.cam.look_at_from_position(s.global_position+Vector3(-w.peel_dir*5.0,2.2,4.0),s.global_position+Vector3(w.peel_dir*2.5,.5,0))
		await shot("agua_calidad_%d"%quality)
	print("[visual-polish] Capturas guardadas: ",folder)
	get_tree().quit()
