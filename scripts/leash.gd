class_name Leash
extends MeshInstance3D
## Cuerda del leash entre el tapón de la cola y el tobillo trasero. Se rehace cada fotograma.

## Tapón del leash en coordenadas de la tabla (la punta está en +Z).
const PLUG := Vector3(0.0, 0.017, -0.869)
const LENGTH := 1.7
const RADIUS := 0.007
const SEGMENTS := 12
const SIDES := 4

var board: Node3D
var animator: SurferAnimator
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.06)
	mat.roughness = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat


func plug_position() -> Vector3:
	return board.get_global_transform_interpolated() * PLUG


func _process(_delta: float) -> void:
	if board == null or animator == null or animator.skeleton == null:
		return
	global_transform = Transform3D.IDENTITY
	var a := plug_position()
	var b := animator.bone_position("foot_R") + Vector3(0, 0.04, 0)
	var d := a.distance_to(b)
	var sag := sqrt(maxf(LENGTH * LENGTH - d * d, 0.0)) * 0.45
	var c := (a + b) * 0.5 + Vector3.DOWN * sag
	var pts: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_ring: Array[Vector3] = []
	for i in pts.size():
		var tangent := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := tangent.cross(Vector3.UP)
		if side.length_squared() < 1e-4:
			side = tangent.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(tangent).normalized()
		var ring: Array[Vector3] = []
		for k in SIDES:
			var ang := TAU * k / SIDES
			ring.append(pts[i] + (side * cos(ang) + up * sin(ang)) * RADIUS)
		if not prev_ring.is_empty():
			for k in SIDES:
				var k2 := (k + 1) % SIDES
				for v in [prev_ring[k], ring[k], ring[k2], prev_ring[k], ring[k2], prev_ring[k2]]:
					_mesh.surface_set_normal((v - pts[i]).normalized())
					_mesh.surface_add_vertex(v)
		prev_ring = ring
	_mesh.surface_end()
