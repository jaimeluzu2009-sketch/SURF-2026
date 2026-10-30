extends Node
var failures: Array[String]=[]
var game: Game
func _ready() -> void:
	game=get_parent()
	run.call_deferred()
func check(ok: bool,text: String) -> void:
	print("[anatomy] ","PASS " if ok else "FAIL ",text)
	if not ok: failures.append(text)
func run() -> void:
	Ajustes.persist=false
	var s := game.surfer
	s.set_frozen(true)
	game.set_physics_process(false)
	var body := s.get_node("Rider/SurferModel").find_child("Surfer",true,false) as MeshInstance3D
	for style in 4:
		Perfil.set_style(style)
		for outfit in 2:
			Perfil.set_outfit(outfit)
			var triangles := 0
			var colored := 0
			for surface in body.mesh.get_surface_count():
				var arrays := body.mesh.surface_get_arrays(surface)
				triangles+=(arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
				if arrays[Mesh.ARRAY_COLOR]!=null: colored+=(arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size()
			check(triangles>25000 and triangles<42000,"presupuesto anatómico %d/%d: %d triángulos"%[style,outfit,triangles])
			check(colored>0,"detalle de color exportado %d/%d"%[style,outfit])
			check(s.animator.skeleton.get_bone_count()==19,"rig conservado %d/%d"%[style,outfit])
	Perfil.set_style(0)
	Perfil.set_outfit(0)
	s.global_position=Vector3(0,3,0)
	s.visual.global_transform=Transform3D(Basis.IDENTITY,s.global_position)
	s.rider.global_transform=s.visual.global_transform
	var a := s.animator
	var player := s.get_node("Rider/SurferModel").find_child("AnimationPlayer",true,false) as AnimationPlayer
	a.tree.active=false
	for clip in ["ride","tube_crouch","grab","floater"]:
		player.play(clip)
		player.seek(.1,true)
		a.skeleton.force_update_all_bone_transforms()
		var foot_min := {"foot_L":99.0,"foot_R":99.0}
		for surface in body.mesh.get_surface_count():
			var arrays := body.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			if bones.is_empty():continue
			var influences := weights.size()/positions.size()
			for vertex in positions.size():
				if positions[vertex].y>.035:continue
				var result := Vector3.ZERO
				var foot := ""
				for j in influences:
					var bind := bones[vertex*influences+j]
					var weight := weights[vertex*influences+j]
					if weight<=0:continue
					var name := str(body.skin.get_bind_name(bind))
					var bone := a.skeleton.find_bone(name) if name!="" else body.skin.get_bind_bone(bind)
					name=a.skeleton.get_bone_name(bone)
					if weight>.60 and name in ["foot_L","foot_R"]:foot=name
					var transform := a.skeleton.get_bone_global_pose(bone)*body.skin.get_bind_pose(bind)
					result+=(transform*positions[vertex])*weight
				if foot!="":
					var local: Vector3=s.visual.global_transform.affine_inverse()*(a.skeleton.global_transform*result)
					foot_min[foot]=minf(foot_min[foot],local.y)
		for foot in foot_min:
			print("[anatomy] suela ",clip," ",foot," y=",foot_min[foot])
			var ankle := a.skeleton.get_bone_global_pose(a.skeleton.find_bone(foot)).origin
			var local: Vector3=s.visual.global_transform.affine_inverse()*(a.skeleton.global_transform*ankle)
			var deck := deck_height(Vector2(local.x,local.z))
			var gap: float=foot_min[foot]-deck
			print("[anatomy] separación suela/cubierta=",gap)
			check(gap> -0.010 and gap<.020,"suela mantiene apoyo real "+clip+" "+foot)
	print("[anatomy] RESULTADO: ","OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func deck_height(point: Vector2) -> float:
	var board := game.surfer.get_node("Visual/Board").find_child("Board",true,false) as MeshInstance3D
	var height := -10.0
	for surface in board.mesh.get_surface_count():
		var data := board.mesh.surface_get_arrays(surface)
		var vs: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
		var ids: PackedInt32Array=data[Mesh.ARRAY_INDEX]
		for i in range(0,ids.size(),3):
			var a := vs[ids[i]]
			var b := vs[ids[i+1]]
			var c := vs[ids[i+2]]
			var ab := Vector2(b.x-a.x,b.z-a.z)
			var ac := Vector2(c.x-a.x,c.z-a.z)
			var rel := point-Vector2(a.x,a.z)
			var determinant := ab.cross(ac)
			if absf(determinant)<0.0000001:continue
			var u := rel.cross(ac)/determinant
			var v := ab.cross(rel)/determinant
			if u>= -0.001 and v>= -0.001 and u+v<=1.001:
				height=maxf(height,a.y+(b.y-a.y)*u+(c.y-a.y)*v)
	return height
