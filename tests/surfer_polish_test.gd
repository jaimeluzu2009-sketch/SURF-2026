extends Node
var game: Game
var failures: Array[String] = []
func check(ok: bool, label_text: String) -> void:
	print("[polish] ", "OK " if ok else "FAIL ", label_text)
	if not ok:
		failures.append(label_text)
func _ready() -> void:
	game = get_parent()
	call_deferred("run")
func run() -> void:
	Ajustes.persist = false
	var before := "--polish-before" in OS.get_cmdline_user_args()
	game.start_play()
	game.set_physics_process(false)
	game.cam.set_process(false)
	var s := game.surfer
	s.set_frozen(true)
	game.wave.time = 15.0
	game.wave.update()
	var w := game.wave
	var x := w.peel_x + w.peel_dir * 1.5
	var z := w.crest_z + w.front_width * 0.9
	s.reset_to(Vector3(x, w.height_at(x, z) + 0.045, z), PI * 0.5 * w.peel_dir)
	s.set_frozen(true)
	s.state = Surfer.State.RIDING
	s.hvel = Vector2(w.peel_dir * 8.0, w.speed)
	s._update_visual(0.0, w.sample(x, z))
	var folder := "res://capturas/mejoras_surfista/" + ("antes" if before else "despues")
	DirAccess.make_dir_recursive_absolute(folder)
	for index in range(1, 4):
		Perfil.set_style(index)
		s.animator.jump_to("ride")
		s.animator.set_ride_blend(0.0, 0.0)
		s.animator.tree.advance(0.1)
		var p := s.global_position
		game.cam.look_at_from_position(p + Vector3(-w.peel_dir * 1.9, 1.65, 2.6), p + Vector3(0, 0.85, 0))
		await shot(folder.path_join(Perfil.style_id + "_ingame.png"))
		if not before and index == 1:
			game.cam.look_at_from_position(p + Vector3(-w.peel_dir * 0.85, 1.65, -2.1), p + Vector3(0, 1.0, 0))
			await shot(folder.path_join("detalle_rostro_ingame.png"))
			var skeleton := s.animator.skeleton
			var head_index := skeleton.find_bone("head")
			var deformation := skeleton.get_bone_global_pose(head_index) * skeleton.get_bone_global_rest(head_index).affine_inverse()
			var center: Vector3 = skeleton.global_transform * (deformation * Vector3(0,1.685,0.012))
			var front: Vector3 = (skeleton.global_basis * deformation.basis * Vector3.BACK).normalized()
			game.cam.look_at_from_position(center + front * 1.2 + Vector3(0,0.12,0),center-Vector3(0,0.12,0))
			await shot(folder.path_join("rostro_cercano_ingame.png"))
	game.cam.mode = CameraRig.Mode.FOLLOW
	game.cam.snap_now()
	for frame in 90:
		game.cam._process(1.0 / 60.0)
	await shot(folder.path_join("camara_gameplay.png"))
	if not before:
		await checks(folder)
	print("[polish] RESULTADO: ", "OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func shot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for frame in 12:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func checks(folder: String) -> void:
	var s := game.surfer
	var animator := s.animator
	var player := s.get_node("Rider/SurferModel").find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(player.has_animation("tube_crouch"), "postura agachada disponible")
	check(is_equal_approx(player.get_animation("popup").length, Surfer.POPUP_TIME), "pop-up conserva sincronización de 0,7 segundos")
	var start: Variant = player.get_animation("paddle").track_get_key_value(0, 0)
	var end: Variant = player.get_animation("paddle").track_get_key_value(0, player.get_animation("paddle").track_get_key_count(0)-1)
	check(start.is_equal_approx(end), "ciclo de remada cierra sin salto")
	animator.jump_to("ride")
	animator.set_motion(8, 0.3, false, 0.3)
	animator.set_ride_blend(1.0,1.0)
	for frame in 120:
		animator._process(1.0/60.0)
		animator.tree.advance(1.0/60.0)
	check(animator._ride_blend.x + animator._ride_blend.y <= 1.001, "mezcla de giros y peso dentro de las poses válidas")
	var bone := animator.skeleton.find_bone("chest")
	animator._secondary_pose()
	var first := animator.skeleton.get_bone_pose_rotation(bone)
	for repeat in 100:
		animator._secondary_pose()
	check(first.is_equal_approx(animator.skeleton.get_bone_pose_rotation(bone)), "correcciones secundarias no se acumulan")
	# Authored neutral and tucked clips pin both ankles to the same deck points.
	animator.tree.active = false
	var feet := {}
	for clip in ["ride", "tube_crouch"]:
		player.play(clip)
		player.seek(0.0, true)
		animator.skeleton.force_update_all_bone_transforms()
		for foot in ["foot_L", "foot_R"]:
			var position := animator.skeleton.get_bone_global_pose(animator.skeleton.find_bone(foot)).origin
			if clip == "ride":
				feet[foot] = position
			else:
				check(position.distance_to(feet[foot]) < 0.025, "pie fijado al agacharse " + foot)
	player.stop()
	animator.tree.active = true
	animator.jump_to("ride")
	animator.set_ride_blend(0, 0)
	animator.set_motion(8, 0, true, 0.3)
	for frame in 120:
		animator._process(1.0/60.0)
		animator.tree.advance(1.0/60.0)
	check(animator._tuck > 0.9, "postura de tubo entra suavemente")
	await shot(folder.path_join("postura_tubo.png"))
	animator.set_motion(8, 0, false, 0.3)
	for frame in 120:
		animator._process(1.0/60.0)
		animator.tree.advance(1.0/60.0)
	var distances: Array[float] = []
	for scale_value in [0.75,1.35]:
		Ajustes.camera_distance = scale_value
		game.cam.snap_now()
		for frame in 120:
			game.cam._process(1.0/60.0)
		distances.append(game.cam.global_position.distance_to(s.global_position))
	check(distances[1] > distances[0] + 1.0, "distancia de cámara ajustable")
	var target := s.global_position + Vector3(0,0.9,0)
	var blocked := Vector3(target.x,game.wave.height_at(target.x,target.z)-1.0,target.z+7.0)
	check(not game.cam.clear_view(blocked,target), "detecta vista tapada por la superficie")
	var safe := game.cam.safe_follow_position(blocked,target)
	check(game.cam.clear_view(safe,target), "encuentra vista despejada sobre la ola")
	var all_clear := true
	var last_position := s.global_position
	for spot_index in 3:
		Spots.apply_to_wave(Spots.get_spot(spot_index), game.wave)
		for moment in [10.0,15.0,20.0]:
			game.wave.time = moment
			game.wave.update()
			var xx := game.wave.peel_x + game.wave.peel_dir * 1.5
			var zz := game.wave.crest_z + game.wave.front_width * 0.9
			s.global_position = Vector3(xx,game.wave.height_at(xx,zz)+0.05,zz)
			s.reset_physics_interpolation()
			await get_tree().process_frame
			s.hvel = Vector2(game.wave.peel_dir*8.0,game.wave.speed)
			game.cam.snap_now()
			for frame in 120:
				game.cam._process(1.0/60.0)
			var clear := game.cam.clear_view(game.cam.global_position,game.cam._look)
			all_clear = all_clear and clear
			check(clear,"cámara despejada spot %d tiempo %.0f" % [spot_index,moment])
	s.global_position = last_position
	s.reset_physics_interpolation()
	check(all_clear,"visibilidad comprobada en nueve situaciones de ola")
	Ajustes.reduce_motion = true
	game.cam._process(1.0)
	check(absf(game.cam.fov-70.0)<0.6, "reducir movimiento elimina variación de FOV")
	Ajustes.reduce_motion = false
	Ajustes.camera_distance = 1.25
	Ajustes.persist = true
	Ajustes._save()
	Ajustes.camera_distance = 1.0
	Ajustes._load()
	check(is_equal_approx(Ajustes.camera_distance,1.25), "distancia de cámara se guarda y recupera")
	Ajustes.persist = false
	Ajustes.camera_distance = 1.0
	Ajustes.camera_distance = 1.35
	Controles.reset_controls()
	check(is_equal_approx(Ajustes.camera_distance,1.0), "restablecer controles también reinicia cámara")
	DirAccess.remove_absolute(Ajustes.config_path())
	game.spot = Spots.get_spot(1)
	Ajustes.spot = 1
	game.beach.build(game.spot)
	game.hud.set_spot(game.spot)
	game._apply_spot_look()
	game.set_physics_process(false)
	s.set_frozen(true)
	var w := game.wave
	Spots.apply_to_wave(Spots.get_spot(1),w)
	w.time = 15.0
	w.update()
	for ahead in [1.0,2.5,5.0]:
		var xx: float = w.peel_x + w.peel_dir * ahead
		var sec := w.tube_section(xx)
		var zz: float = sec["z"]
		s.reset_to(Vector3(xx,w.height_at(xx,zz)+0.045,zz),PI*0.5*w.peel_dir)
		s.set_frozen(true)
		s.state = Surfer.State.RIDING
		s.in_tube = true
		await get_tree().process_frame
		s.hvel = Vector2(w.peel_dir*9.0,w.speed)
		s._update_visual(0.0,w.sample(xx,zz))
		s.animator.jump_to("ride")
		s.animator.set_motion(9.0,0.0,true)
		game.cam.snap_now()
		for frame in 180:
			game.cam._process(1.0/60.0)
			animator._process(1.0/60.0)
			animator.tree.advance(1.0/60.0)
		var section := w.tube_at(game.cam.global_position,0.1)
		print("[polish tube] pos=",s.global_position," interpolada=",s.get_global_transform_interpolated().origin," cam=",game.cam.global_position," sección=",section)
		check(section["inside"] and section["clearance"]>=0.0, "cámara dentro del tubo y bajo el labio, avance %.1f" % ahead)
		check(game.cam.global_position.y>w.height_at(game.cam.global_position.x,game.cam.global_position.z)+0.15,"cámara sobre el agua en el tubo %.1f" % ahead)
		if is_equal_approx(ahead,2.5):
			await shot(folder.path_join("camara_tubo_ingame.png"))
	s.in_tube = false
	# Inspect the new controls row and slider on the real settings screen.
	game.cam.set_process(true)
	game.to_menu()
	game.menus.open("settings","main")
	game.menus.select_tab("settings",2)
	await shot(folder.path_join("ajuste_camara.png"))
