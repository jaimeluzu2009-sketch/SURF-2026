extends Node
var game: Game
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	print("[styles] ", "OK " if ok else "FAIL ", message)
	if not ok:
		failures.append(message)
func _ready() -> void:
	game = get_parent()
	call_deferred("run")
func run() -> void:
	Ajustes.persist = false
	var s := game.surfer
	var body := s.get_node("Rider/SurferModel").find_child("Surfer", true, false) as MeshInstance3D
	var original_skeleton := s.animator.skeleton
	var expected_bones: Array[String] = []
	for i in original_skeleton.get_bone_count():
		expected_bones.append(original_skeleton.get_bone_name(i))
	for index in range(1, 4):
		Perfil.set_style(index)
		var id: String = Perfil.style_id
		var instance: Node = load("res://assets/models/surfer_%s.glb" % id).instantiate()
		var skeleton := instance.find_child("Skeleton3D", true, false) as Skeleton3D
		check(skeleton.get_bone_count() == 19, id + " conserva 19 huesos")
		for bone in 19:
			check(skeleton.get_bone_name(bone) == expected_bones[bone] and skeleton.get_bone_rest(bone).is_equal_approx(original_skeleton.get_bone_rest(bone)), id + " enlace/resto " + expected_bones[bone])
		var player := instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for clip in ["prone_idle", "paddle", "popup", "ride", "carve_left", "carve_right", "lean_fwd", "lean_back", "fall"]:
			check(player.has_animation(clip), id + " animación " + clip)
		check(body.mesh == s._style_meshes["surfer_" + id], id + " malla activa en gameplay")
		check(s._style_meshes.has("board_" + id), id + " tabla propia cargada")
		for slot in Perfil.SLOTS:
			check(Perfil.unlocked(Perfil.item(slot, Perfil.look[slot])), id + " color disponible " + slot)
		var before := body.mesh
		Perfil.set_look("wetsuit", "pacifico")
		check(body.mesh == before and Perfil.style_id == id, id + " permite personalizar conservando modelo")
		Perfil.set_style(index)
		Ajustes.persist = true
		Perfil._save()
		var restored: Node = load("res://scripts/profile.gd").new()
		restored._load()
		check(restored.style_id == id and restored.look == Perfil.look, id + " guarda y recupera elección")
		restored.free()
		Ajustes.persist = false
		instance.free()
	s.set_showcase(true)
	var saved_time := game.wave.time
	var clear := true
	for moment in [0.0, 6.0, 12.0, 18.0, 24.0]:
		game.wave.time = moment
		game.wave.update()
		s.update_showcase()
		for dx in [-0.23, 0.0, 0.23]:
			for dz in [-0.88, 0.0, 0.88]:
				var point: Vector3 = s.visual.global_transform * Vector3(dx, 0, dz)
				clear = clear and point.y > game.wave.height_at(point.x, point.z) + 0.03
	check(clear, "personalización mantiene la tabla visible durante el paso de la ola")
	s.set_showcase(false)
	var before_preview := s.visual.global_transform
	s.update_showcase()
	check(s.visual.global_transform == before_preview, "flotación de personalización no actúa durante el gameplay")
	game.wave.time = saved_time
	game.wave.update()
	Perfil.set_style(0) # Clothing now preserves identity; choose the original explicitly.
	Perfil.set_outfit(0)
	check(Perfil.style_id == "custom" and body.mesh == s._winter_mesh, "vuelve al neopreno original")
	Perfil.set_outfit(1)
	check(body.mesh == s._summer_mesh, "vuelve a ropa de playa original")
	if DisplayServer.get_name() != "headless":
		await capture()
	DirAccess.remove_absolute(Perfil.config_path())
	print("[styles] RESULTADO: ", "OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func capture() -> void:
	var folder := "res://capturas/tres_apariencias"
	DirAccess.make_dir_recursive_absolute(folder)
	game.start_play()
	game.set_physics_process(false)
	game.cam.set_physics_process(false)
	game.cam.set_process(false)
	var s := game.surfer
	s.set_frozen(true)
	var w := game.wave
	Spots.apply_to_wave(Spots.get_spot(1), w)
	w.time = 15.0
	w.update()
	var x := w.peel_x + w.peel_dir * 1.5
	var section := w.tube_section(x)
	var z: float = section["z"]
	s.reset_to(Vector3(x, w.height_at(x, z) + 0.045, z), PI * 0.5 * w.peel_dir)
	s.set_frozen(true)
	s.state = Surfer.State.RIDING
	s.hvel = Vector2(w.peel_dir * 9.0, w.speed)
	s.animator.jump_to("ride")
	s.animator.set_ride_blend(0.0, 0.0)
	s.animator.tree.advance(0.1)
	game.barrel.sync(w.time, 0.1)
	# Same camera, frozen wave and pose across the three looks.
	var p := s.global_position
	game.cam.surfer = null
	game.cam.look_at_from_position(p - Vector3(w.peel_dir * 2.5, -0.8, 0), p + Vector3(w.peel_dir * 3.0, 0.8, 0))
	for index in range(1, 4):
		Perfil.set_style(index)
		for frame in 20:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder.path_join(Perfil.style_id + "_ingame.png"))
	game.cam.surfer = s
	game.cam.set_process(true)
	game.to_menu()
	game.menus.open("custom", "main")
	for frame in 120:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("selector.png"))
