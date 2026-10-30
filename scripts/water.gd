class_name Water
extends MeshInstance3D
## Malla del mar. Es una rejilla más densa en el centro que sigue al surfista;
## el shader la deforma con la misma fórmula que usa la física (WaveModel).

const WATER_SHADER := preload("res://shaders/water.gdshader")
const FAR_SHADER := preload("res://shaders/far_water.gdshader")

@export var radius := 210.0
@export var follow: Node3D
@export var snap := 4.0

var wave: WaveModel
var _grid := -1
var _mat: ShaderMaterial
var _far: MeshInstance3D
var _far_mat: ShaderMaterial


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = WATER_SHADER
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Mar lejano hasta el horizonte, 0.6 m por debajo para no asomar entre las olas.
	_far = MeshInstance3D.new()
	_far.name = "FarSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000, 9000)
	_far.mesh = plane
	_far_mat = ShaderMaterial.new()
	_far_mat.shader = FAR_SHADER
	_far.material_override = _far_mat
	_far.position = Vector3(0, -0.6, 0)
	_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_far)
	Ajustes.changed.connect(_apply_quality)
	_apply_quality()


func _apply_quality() -> void:
	var preset := Ajustes.preset()
	var n: int = preset["water_grid"]
	if n != _grid:
		_grid = n
		mesh = build_grid(n, radius)
	_mat.set_shader_parameter("detail_level", preset["water_detail"])


## Rejilla (n x n celdas) con espaciado que crece hacia los bordes:
## posición = R * (a·u + (1-a)·u³), con u en [-1, 1]. Con a = 0.11 y la rejilla
## de calidad Baja (136) los vértices del centro quedan a ~0.37 m.
static func build_grid(n: int, r: float) -> ArrayMesh:
	var a := 0.11
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.resize((n + 1) * (n + 1))
	normals.resize(verts.size())
	for j in n + 1:
		var v := -1.0 + 2.0 * j / n
		var z := r * (a * v + (1.0 - a) * v * v * v)
		for i in n + 1:
			var u := -1.0 + 2.0 * i / n
			var x := r * (a * u + (1.0 - a) * u * u * u)
			verts[j * (n + 1) + i] = Vector3(x, 0.0, z)
			normals[j * (n + 1) + i] = Vector3.UP
	for j in n:
		for i in n:
			var k := j * (n + 1) + i
			indices.append_array([k, k + 1, k + n + 1, k + 1, k + n + 2, k + n + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.custom_aabb = AABB(Vector3(-r, -6.0, -r), Vector3(2.0 * r, 14.0, 2.0 * r))
	return m


## Copia el estado de la ola al shader para el instante t (normalmente el tiempo
## de física interpolado, para que coincida con la tabla que se está dibujando).
func sync(t: float) -> void:
	if wave == null:
		return
	var d := wave.derived_at(t)
	_mat.set_shader_parameter("tube_strength", wave.tube_strength)
	_mat.set_shader_parameter("tide", wave.tide)
	_mat.set_shader_parameter("wave_time", t)
	_mat.set_shader_parameter("crest_z", d[0])
	_mat.set_shader_parameter("peel_x", d[1])
	_mat.set_shader_parameter("started", d[2])
	_mat.set_shader_parameter("amp", d[3])
	_mat.set_shader_parameter("peel_dir", wave.peel_dir)
	_mat.set_shader_parameter("front_width", wave.front_width)
	_mat.set_shader_parameter("back_width", wave.back_width)
	_mat.set_shader_parameter("swell_amp", wave.swell_amp)
	_mat.set_shader_parameter("set_spacing", wave.set_spacing)
	_mat.set_shader_parameter("set_amp1", d[4])
	_mat.set_shader_parameter("set_amp2", d[5])
	if follow:
		var p := follow.global_position
		global_position = Vector3(snappedf(p.x, snap), 0.0, snappedf(p.z, snap))


## Cielo (para el reflejo de Fresnel) y dirección hacia el sol (para la luz que atraviesa las crestas).
func set_sky(sky: Color, to_sun: Vector3) -> void:
	_mat.set_shader_parameter("sky_color", sky)
	_mat.set_shader_parameter("to_sun", to_sun.normalized())
	_far_mat.set_shader_parameter("sky_color", sky)


## Tabla y estela para la espuma de contacto. points: x, z, edad, intensidad.
func set_board(pos: Vector3, speed: float, touching: bool, points: PackedVector4Array, loads := PackedFloat32Array(), heading := Vector2(0,1), rail_load := 0.0) -> void:
	_mat.set_shader_parameter("board", Vector4(pos.x, pos.z, speed, 1.0 if touching else 0.0))
	_mat.set_shader_parameter("wake", points)
	_mat.set_shader_parameter("wake_count", points.size())
	_mat.set_shader_parameter("wake_load",loads)
	_mat.set_shader_parameter("board_rails",Vector3(heading.x,heading.y,rail_load))
	var lower := Vector2(pos.x,pos.z)-Vector2(1.5,1.5)
	var upper := Vector2(pos.x,pos.z)+Vector2(1.5,1.5)
	for point in points:
		lower=lower.min(Vector2(point.x,point.y)-Vector2(2.5,2.5))
		upper=upper.max(Vector2(point.x,point.y)+Vector2(2.5,2.5))
	_mat.set_shader_parameter("wake_bounds",Vector4(lower.x,lower.y,upper.x,upper.y))


func set_colors(deep: Color, shallow: Color, face: Color) -> void:
	_mat.set_shader_parameter("deep_color", deep)
	_far_mat.set_shader_parameter("deep_color", deep)
	_mat.set_shader_parameter("shallow_color", shallow)
	_mat.set_shader_parameter("face_color", face)


func set_debug_flat(on: bool) -> void:
	_mat.set_shader_parameter("debug_flat", 1.0 if on else 0.0)
