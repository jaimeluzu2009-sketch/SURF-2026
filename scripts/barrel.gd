class_name Barrel
extends MeshInstance3D
## One smooth indexed shell. The solid arc uses WaveModel.tube_section unchanged.
## A short decorative foam skirt joins the falling lip to the real water surface.
var wave: WaveModel
var _timer := 0.0
var _array_mesh := ArrayMesh.new()
var _mat: ShaderMaterial
var mesh_time := 0.0
var arc_segments := 0
var length_segments := 0
var _origin_crest := 0.0
var _origin_peel := 0.0
var _quality := -1

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/barrel.gdshader")
	var spot := Spots.get_spot(Ajustes.spot)
	_mat.set_shader_parameter("tint", spot["shallow"])
	_mat.set_shader_parameter("thin_tint", spot["face"])
	_mat.set_shader_parameter("sky_tint", spot["sky_horizon"])
	_mat.set_shader_parameter("to_sun", -(spot["sun_dir"] as Vector3).normalized())
	material_override = _mat

func sync(t: float, delta: float) -> void:
	if wave == null or wave.tube_strength <= 0.0:
		visible = false
		return
	var d := wave.derived_at(t)
	visible = d[2] > 0.08 and d[3] > 0.35
	if not visible:
		return
	_mat.set_shader_parameter("wave_time",t)
	_mat.set_shader_parameter("detail_level",Ajustes.quality)
	_timer -= delta
	# Follow translation every render frame, even between geometry refreshes.
	if mesh != null:
		position = Vector3(d[1]-_origin_peel,0,d[0]-_origin_crest)
	if _timer > 0.0 and _quality == Ajustes.quality:
		return
	_quality = Ajustes.quality
	_timer = 1.0 / (30.0 if _quality > 0 else 20.0)
	length_segments = [18,28,36][_quality]
	arc_segments = [16,24,32][_quality]
	mesh_time = t
	_origin_peel = d[1]
	_origin_crest = d[0]
	position = Vector3.ZERO
	_build(t,d)

func _build(t: float, d: PackedFloat32Array) -> void:
	var nx := length_segments
	var nr := arc_segments
	var rows := nr + 3
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize((nx+1)*rows)
	normals.resize(vertices.size())
	tangents.resize(vertices.size()*4)
	uvs.resize(vertices.size())
	# Sample sections once per column, rather than several times per triangle.
	var old_time := wave.time
	for i in nx+1:
		var u := float(i)/nx
		var x := d[1]+wave.peel_dir*lerpf(-1.5,6.8,u)
		var sec := wave.tube_section(x,t)
		wave.time = t
		wave.update()
		var lip_z: float = sec["z"]+sec["rz"]
		var lip_y: float = sec["floor"]+0.12
		var impact_y := minf(lip_y,wave.height_at(x,lip_z+0.08)+0.025)
		for j in rows:
			var p: Vector3
			var v: float
			if j < 2:
				var f := 1.0-float(j)*0.5
				p = Vector3(x,lerpf(lip_y,impact_y,f),lip_z+0.08*f)
				v = -0.10*f
			else:
				v = float(j-2)/nr
				var angle := v*PI
				p = Vector3(x,sec["floor"]+0.12+sec["ry"]*sin(angle),sec["z"]+sec["rz"]*cos(angle))
			vertices[i*rows+j] = p
			uvs[i*rows+j] = Vector2(u,v)
	wave.time = old_time
	wave.update()
	for i in nx+1:
		for j in rows:
			var k := i*rows+j
			var tx := vertices[mini(i+1,nx)*rows+j]-vertices[maxi(i-1,0)*rows+j]
			var ty := vertices[i*rows+mini(j+1,rows-1)]-vertices[i*rows+maxi(j-1,0)]
			var n := tx.cross(ty).normalized()*wave.peel_dir
			if n.length_squared()<0.5: n=Vector3.UP
			var tangent := (tx-n*tx.dot(n)).normalized()
			normals[k]=n
			tangents[k*4]=tangent.x
			tangents[k*4+1]=tangent.y
			tangents[k*4+2]=tangent.z
			tangents[k*4+3]=wave.peel_dir
			if i<nx and j<rows-1:
				if wave.peel_dir>0:
					indices.append_array([k,k+rows,k+1,k+rows,k+rows+1,k+1])
				else:
					indices.append_array([k,k+1,k+rows,k+rows,k+1,k+rows+1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TANGENT]=tangents
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	_array_mesh.clear_surfaces()
	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh=_array_mesh
