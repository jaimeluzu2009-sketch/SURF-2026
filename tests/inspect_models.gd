extends SceneTree
# Lista nodos, huesos y animaciones de los GLB importados.
# godot --headless --path . -s tests/inspect_models.gd

func _init() -> void:
	for path in ["res://assets/models/surfer.glb", "res://assets/models/board.glb"]:
		var scene: Node = (load(path) as PackedScene).instantiate()
		print("== ", path)
		_dump(scene, 0)
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player:
			for anim_name in player.get_animation_list():
				print("  anim ", anim_name, " ", player.get_animation(anim_name).length, "s")
		var skel := scene.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel:
			var names := []
			for i in skel.get_bone_count():
				names.append(skel.get_bone_name(i))
			print("  bones ", names)
		scene.free()
	quit()


func _dump(n: Node, depth: int) -> void:
	var extra := ""
	if n is Node3D:
		extra = " pos=%s" % (n as Node3D).position
	if n is MeshInstance3D:
		var aabb := (n as MeshInstance3D).get_aabb()
		extra += " aabb=%s" % aabb
		var mesh := (n as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			var fmt := (mesh as ArrayMesh).surface_get_format(i)
			extra += "\n      sup %d: %s '%s' uv=%s" % [i, m.get_class() if m else "null", m.resource_name if m else "",
				(fmt & Mesh.ARRAY_FORMAT_TEX_UV) != 0]
	print("  ".repeat(depth + 1), n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children():
		_dump(c, depth + 1)
