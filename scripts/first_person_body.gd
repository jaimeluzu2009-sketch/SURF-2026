class_name FirstPersonBody
extends MeshInstance3D
var source_mesh: Mesh
var surface_sources: Array[int] = []
var _cache: Dictionary = {}

func sync_body(body: MeshInstance3D, rig: Skeleton3D) -> void:
	if source_mesh != body.mesh:
		source_mesh = body.mesh
		var key := source_mesh.get_instance_id()
		if not _cache.has(key): _cache[key] = _first_person_arms(source_mesh, body.skin, rig)
		mesh = _cache[key][0]
		surface_sources.assign(_cache[key][1])
		skin = body.skin
		skeleton = body.skeleton
		transform = body.transform
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surface in surface_sources.size():
		set_surface_override_material(surface, body.get_active_material(surface_sources[surface]))

func _first_person_arms(source: Mesh, bindings: Skin, rig: Skeleton3D) -> Array:
	var filtered := ArrayMesh.new()
	var sources: Array[int] = []
	var excluded: Array[int] = []
	for bone_name in ["hips", "spine", "chest", "neck", "head", "thigh_L", "thigh_R", "shin_L", "shin_R", "foot_L", "foot_R"]:
		var bone := rig.find_bone(bone_name)
		if bindings:
			for bind in bindings.get_bind_count():
				if bindings.get_bind_bone(bind) == bone or bindings.get_bind_name(bind) == bone_name: excluded.append(bind)
		else: excluded.append(bone)
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		var stride := bones.size()/vertices.size()
		for tri in range(0,indices.size(),3):
			var hidden := false
			for corner in 3:
				var v := indices[tri+corner]
				var head_weight := 0.0
				for influence in stride:
					if bones[v*stride+influence] in excluded: head_weight += weights[v*stride+influence]
				if head_weight > 0.2: hidden = true
			if not hidden: keep.append_array([indices[tri],indices[tri+1],indices[tri+2]])
		if keep.is_empty(): continue
		arrays[Mesh.ARRAY_INDEX] = keep
		filtered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		filtered.surface_set_material(filtered.get_surface_count()-1,source.surface_get_material(surface))
		sources.append(surface)
	return [filtered,sources]
