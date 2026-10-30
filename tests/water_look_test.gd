extends Node
var game: Game
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	print("[water-look] ", "OK " if ok else "FAIL ", message)
	if not ok: failures.append(message)
func _ready() -> void:
	game = get_parent()
	call_deferred("run")
func run() -> void:
	Ajustes.persist = false
	var before := "--water-before" in OS.get_cmdline_user_args()
	var folder := "res://capturas/ola_tubo/" + ("antes" if before else "despues")
	DirAccess.make_dir_recursive_absolute(folder)
	game.start_play()
	game.set_physics_process(false)
	game.cam.set_process(false)
	var w := game.wave
	Spots.apply_to_wave(Spots.get_spot(1),w)
	w.time = 15.0
	w.update()
	var x := w.peel_x + w.peel_dir * 2.5
	var sec := w.tube_section(x)
	var z: float = sec["z"]
	var s := game.surfer
	Perfil.set_style(1)
	s.reset_to(Vector3(x,w.height_at(x,z)+0.045,z), PI*0.5*w.peel_dir)
	s.set_frozen(true)
	s.state = Surfer.State.RIDING
	s.in_tube = true
	s.hvel = Vector2(w.peel_dir*9.0,w.speed)
	s._update_visual(0.0,w.sample(x,z))
	s.animator.jump_to("ride")
	s.animator.set_ride_blend(0,0)
	s.animator.set_motion(9,0,true)
	for frame in 120:
		s.animator._process(1.0/60.0)
		s.animator.tree.advance(1.0/60.0)
	await get_tree().process_frame
	game.barrel._timer = 0
	game.barrel.sync(w.time,0.1)
	var p := s.global_position
	for shot_name in ["interior", "exterior"]:
		if shot_name == "interior":
			game.cam.look_at_from_position(p - Vector3(w.peel_dir * 2.1,-0.85,0),p+Vector3(w.peel_dir*1.8,0.8,0))
		else:
			game.cam.look_at_from_position(p+Vector3(-w.peel_dir*5.4,3.1,6.8),p+Vector3(0,1.0,0))
		await shot(folder.path_join(shot_name+"_ingame.png"))
	if not before:
		await checks(folder)
	print("[water-look] RESULTADO: ", "OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func shot(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in 20:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func checks(folder: String) -> void:
	var barrel := game.barrel
	var w := game.wave
	for quality in 3:
		Ajustes.set_quality(quality)
		var old_time := w.time
		var old_crest := w.crest_z
		var old_amp := w.amp
		barrel._timer=0
		barrel.sync(w.time,0.1)
		check(is_equal_approx(old_time,w.time) and is_equal_approx(old_crest,w.crest_z) and is_equal_approx(old_amp,w.amp),"construcción no modifica la física, calidad %d" % quality)
		check(barrel.mesh.get_surface_count()==1,"una sola superficie, calidad %d" % quality)
		var data := barrel.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = data[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
		var max_error := 0.0
		var good_normals := true
		for i in vertices.size():
			good_normals = good_normals and normals[i].is_finite() and absf(normals[i].length()-1.0)<0.001
			if uv[i].y<0.001 or uv[i].y>0.999:
				continue
			var p: Vector3 = barrel.global_transform * vertices[i]
			var section := w.tube_at(p,0.0)
			max_error=maxf(max_error,absf(p.y-float(section["roof"])))
		check(good_normals,"normales suaves normalizadas, calidad %d" % quality)
		check(max_error<0.005,"arco y techo físico coinciden (<5 mm), calidad %d: %.6f m" % [quality,max_error])
		check(vertices.size()<=1295 and indices.size()<=7344,"geometría dentro del presupuesto, calidad %d" % quality)
		print("[water-look] calidad=",quality," vértices=",vertices.size()," triángulos=",indices.size()/3)
		await shot(folder.path_join("calidad_%d_ingame.png" % quality))
	# Between mesh updates the shell follows the interpolated wave translation.
	barrel._timer=0
	barrel.sync(w.time,0.1)
	var old_mesh := barrel.mesh.get_rid()
	var t := w.time+0.008
	barrel.sync(t,0.008)
	var derived := w.derived_at(t)
	check(barrel.mesh.get_rid()==old_mesh and absf(barrel.position.x-(derived[1]-barrel._origin_peel))<0.0001 and absf(barrel.position.z-(derived[0]-barrel._origin_crest))<0.0001,"traslación continua entre actualizaciones de geometría")
	Ajustes.set_quality(1)
	barrel._timer=0
	barrel.sync(w.time,0.1)
	check(is_equal_approx(float(game.water._mat.get_shader_parameter("tube_strength")),w.tube_strength),"espuma superficial vinculada al tubo activo")
	# Restore the comparison view at medium quality after the quality captures.
	var p := game.surfer.global_position
	game.cam.look_at_from_position(p-Vector3(w.peel_dir*2.1,-0.85,0),p+Vector3(w.peel_dir*1.8,0.8,0))
	await shot(folder.path_join("interior_ingame.png"))
	game.cam.look_at_from_position(p+Vector3(-w.peel_dir*5.4,3.1,6.8),p+Vector3(0,1.0,0))
	await shot(folder.path_join("exterior_ingame.png"))
	var strength := w.tube_strength
	w.tube_strength=0
	barrel.sync(w.time,0.1)
	check(not barrel.visible,"se oculta en spots sin tubo")
	w.tube_strength=strength
	barrel.sync(w.time,0.1)
