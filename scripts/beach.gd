class_name Beach
extends Node3D
## Escenario procedural de cada spot. Arena y rocas tienen colisión.
##   point:  Montañita — playa larga, La Punta (cabo con vegetación y rocas oscuras), el pueblo de
##           tejados rojos en la ladera, cerros, palmeras y cabañas.
##   cliffs: La Rinconada (Manabí) — playa estrecha al pie de acantilados secos de color beige.
##   base:   La FAE (Salinas) — plataforma de roca oscura con algas, base aérea con hangares,
##           torre de control y pista, y los edificios de Salinas al fondo.
##
## Todo se construye en coordenadas "locales" donde la ola rompe hacia -X y el
## cabo queda en +X; si el spot es una izquierda se refleja en X (mirror = -1).

const SHORE_Z := 66.0
const SAND_SLOPE := 0.075

var mirror := 1.0
var scenery := "point"
var _noise := FastNoiseLite.new()


func build(spot: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	mirror = -float(spot["dir"])
	scenery = spot["scenery"]
	_noise.seed = 1977
	_noise.frequency = 0.02
	_build_sand()
	_build_rocks()
	match scenery:
		"base":
			_build_base()
			_build_palms(8)
		"cliffs":
			_build_cliffs()
			_build_palms(6)
		_:
			_build_hills()
			_build_huts(9)
			_build_town()
			_build_palms(24)
	if not Ajustes.changed.is_connected(_apply_quality):
		Ajustes.changed.connect(_apply_quality)
	_apply_quality()


func _apply_quality() -> void:
	var level: int = Ajustes.preset()["scenery"]
	var palms := get_node_or_null("Palms") as MultiMeshInstance3D
	if palms:
		var total := palms.multimesh.instance_count
		palms.multimesh.visible_instance_count = [total / 3, total * 2 / 3, -1][level]


static func sand_height(x: float, z: float) -> float:
	return (z - SHORE_Z) * SAND_SLOPE + 0.25 * sin(x * 0.05) * WaveModel.sstep(SHORE_Z, SHORE_Z + 30.0, z)


func _vc_material(cull_off := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	if cull_off:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Pasa un punto de coordenadas locales a coordenadas del mundo (espejo en X).
func _w(p: Vector3) -> Vector3:
	return Vector3(p.x * mirror, p.y, p.z)


const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
enum Kind { PLAIN = -1, SAND = 0, ROCK = 1, GROUND = 2 }


func _terrain_material(kind: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("detail_level", 1 if Ajustes.preset()["detail"] else 0)
	return m


func _add_mesh(node_name: String, mesh: Mesh, cull_off: bool, collide: bool, kind := Kind.PLAIN) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = _vc_material(cull_off) if kind == Kind.PLAIN else _terrain_material(kind)
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.name = node_name + "Col"
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		add_child(body)
	return mi


## Rejilla con altura y color por función (en coordenadas locales).
func _grid(node_name: String, x0: float, x1: float, z0: float, z1: float, nx: int, nz: int,
		height: Callable, color: Callable, collide: bool, kind := Kind.PLAIN) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for j in nz + 1:
		var row := []
		for i in nx + 1:
			var x := lerpf(x0, x1, float(i) / nx)
			var z := lerpf(z0, z1, float(j) / nz)
			row.append(Vector3(x, height.call(x, z), z))
		pts.append(row)
	# Normales suaves por vértice (diferencias centrales de la rejilla). Antes cada
	# triángulo tenía su normal y su color propios y los cerros se veían facetados.
	var nrms := []
	var cols := []
	for j in nz + 1:
		var nrow := []
		var crow := []
		for i in nx + 1:
			var px: Vector3 = pts[j][mini(i + 1, nx)] - pts[j][maxi(i - 1, 0)]
			var pz: Vector3 = pts[mini(j + 1, nz)][i] - pts[maxi(j - 1, 0)][i]
			var n_local := pz.cross(px).normalized()
			nrow.append(n_local)
			crow.append(color.call(pts[j][i], n_local))
		nrms.append(nrow)
		cols.append(crow)
	for j in nz:
		for i in nx:
			for tri in [[Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1)], [Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]]:
				var order := [0, 1, 2] if mirror > 0.0 else [0, 2, 1]  # el espejo invierte el sentido de las caras
				for k in order:
					var g: Vector2i = tri[k]
					var nl: Vector3 = nrms[g.y][g.x]
					st.set_color(cols[g.y][g.x])
					st.set_normal(Vector3(nl.x * mirror, nl.y, nl.z))
					st.add_vertex(_w(pts[g.y][g.x]))
	return _add_mesh(node_name, st.commit(), false, collide, kind)


func _build_sand() -> void:
	var wet := Color(0.42, 0.36, 0.28)
	var dry := Color(0.68, 0.6, 0.46)
	if scenery == "base":
		dry = Color(0.72, 0.66, 0.54)
	var color := func(p: Vector3, _n: Vector3) -> Color:
		return wet.lerp(dry, WaveModel.sstep(SHORE_Z, SHORE_Z + 10.0, p.z))
	var height := func(x: float, z: float) -> float: return sand_height(x, z)
	_grid("Sand", -300.0, 70.0, 30.0, 150.0, 60, 30, height, color, true, Kind.SAND)


## Cabo donde nace la ola (y, en la ensenada, otro al final de la playa).
func rocks_height(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x * 2.0, z * 2.0) * 6.0 + _noise.get_noise_2d(x * 7.0, z * 7.0) * 1.5
	var ridge := 0.0
	var base := -4.0 + 8.0 * WaveModel.sstep(30.0, 48.0, x)
	# El cabo se alarga mar adentro lo mismo que la rompiente (Spots.OFFSHORE).
	var o := Spots.OFFSHORE
	match scenery:
		"point":
			ridge = 30.0 * WaveModel.sstep(34.0, 95.0, x) * WaveModel.sstep(-32.0 - o, 30.0, z)
		"cliffs":
			ridge = 26.0 * WaveModel.sstep(34.0, 70.0, x) * WaveModel.sstep(-28.0 - o, 20.0, z)
		"base":
			# Plataforma rocosa baja y plana, casi a ras del agua.
			ridge = 3.0 * WaveModel.sstep(34.0, 60.0, x) * WaveModel.sstep(-40.0 - o, 0.0, z)
			n *= 0.35
	return maxf(base + ridge + n, sand_height(x, z) - 0.5)


func _rock_color(p: Vector3, nrm: Vector3) -> Color:
	var rock := Color(0.36, 0.32, 0.28)
	var dark := Color(0.17, 0.16, 0.15)
	var top := Color(0.25, 0.42, 0.18)
	match scenery:
		"cliffs":
			rock = Color(0.66, 0.56, 0.40)
			dark = Color(0.42, 0.36, 0.28)
			top = Color(0.58, 0.54, 0.36)
		"base":
			top = Color(0.48, 0.44, 0.3)
	var flat := WaveModel.sstep(0.55, 0.85, nrm.y)
	var high := WaveModel.sstep(3.0, 9.0, p.y)
	var c := dark.lerp(rock, WaveModel.sstep(-1.0, 2.0, p.y))
	if scenery == "base":
		# Roca volcánica oscura cubierta de algas verdes junto al agua.
		var algae := Color(0.20, 0.30, 0.12).lerp(Color(0.32, 0.38, 0.16), _noise.get_noise_2d(p.x * 6.0, p.z * 6.0) + 0.5)
		c = algae.lerp(Color(0.16, 0.15, 0.14), WaveModel.sstep(0.8, 2.2, p.y))
	elif scenery == "cliffs":
		# Estratos horizontales en el acantilado.
		c = c.darkened(0.12 * (0.5 + 0.5 * sin(p.y * 1.7)))
	return c.lerp(top, flat * high)


func _build_rocks() -> void:
	_grid("Point", 26.0, 170.0, -45.0 - Spots.OFFSHORE, 160.0, 48, 74, rocks_height, _rock_color, true, Kind.ROCK)


## La Rinconada: acantilado seco que cierra la playa por detrás, con la meseta encima.
func cliff_height(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x * 1.5, z * 1.5) * 3.0 + _noise.get_noise_2d(x * 6.0, z * 6.0) * 0.8
	var wall := 24.0 * WaveModel.sstep(96.0, 106.0, z + 4.0 * _noise.get_noise_2d(x * 0.5, 3.0))
	return sand_height(x, minf(z, 96.0)) + wall + n * WaveModel.sstep(90.0, 104.0, z)


func _build_cliffs() -> void:
	_grid("Cliffs", -420.0, 40.0, 88.0, 300.0, 70, 30, cliff_height, _rock_color, true, Kind.ROCK)
	# Unas pocas casas sobre la meseta.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var x := -120.0 + i * 26.0
		var z := 125.0 + (i % 2) * 8.0
		_house(st, Vector3(x, cliff_height(x, z), z), Color(0.82, 0.78, 0.7), Color(0.5, 0.44, 0.36))
	_add_mesh("Houses", st.commit(), true, false)


## Montañita: casas de tejado rojo en la ladera, al pie de La Punta.
func _build_town() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var walls := [Color(0.92, 0.88, 0.8), Color(0.85, 0.8, 0.66), Color(0.8, 0.72, 0.6)]
	for i in 26:
		var x := rng.randf_range(4.0, 46.0)
		var z := rng.randf_range(84.0, 150.0)
		var y := maxf(rocks_height(x, z), sand_height(x, z))
		var roof := Color(0.70, 0.24, 0.16).lerp(Color(0.82, 0.38, 0.22), rng.randf())
		_house(st, Vector3(x, y, z), walls[i % walls.size()], roof)
	_add_mesh("Town", st.commit(), true, false)


## Normal de un faldón de tejado (en coordenadas del mundo), siempre hacia arriba y afuera.
func _roof_normal(a: Vector3, b: Vector3, apex: Vector3) -> Vector3:
	var n := _w((b - a).cross(apex - a).normalized())
	return -n if n.y < 0.0 else n


func _house(st: SurfaceTool, base: Vector3, wall: Color, roof: Color) -> void:
	var w := 2.6
	var d := 2.2
	var hh := 3.0
	_box(st, base + Vector3(0, hh * 0.5 - 0.4, 0), Vector3(w * 2.0, hh + 0.8, d * 2.0), wall)
	var y0 := base.y + hh
	var corners := [Vector3(-w * 1.15, 0, -d * 1.15), Vector3(w * 1.15, 0, -d * 1.15),
		Vector3(w * 1.15, 0, d * 1.15), Vector3(-w * 1.15, 0, d * 1.15)]
	var apex := Vector3(base.x, y0 + 1.6, base.z)
	for k in 4:
		var a: Vector3 = Vector3(base.x, y0, base.z) + corners[k]
		var b: Vector3 = Vector3(base.x, y0, base.z) + corners[(k + 1) % 4]
		_tri(st, _w(a), _w(apex), _w(b), roof, _roof_normal(a, b, apex))


func _build_hills() -> void:
	var green := Color(0.27, 0.45, 0.2)
	var dry := Color(0.5, 0.5, 0.3)
	var amp := 30.0 if scenery == "point" else 40.0
	var height := func(x: float, z: float) -> float:
		var rise := WaveModel.sstep(140.0, 230.0, z)
		return sand_height(x, 140.0) + rise * (25.0 + amp * (_noise.get_noise_2d(x * 0.6, z * 0.6) + 0.5))
	var color := func(_p: Vector3, nrm: Vector3) -> Color:
		return green.lerp(dry, clampf((1.0 - nrm.y) * 2.5, 0.0, 0.6))
	_grid("Hills", -420.0, 260.0, 140.0, 460.0, 34, 16, height, color, false, Kind.GROUND)


## La FAE: tierra llana y seca, base aérea y la ciudad de Salinas al fondo.
func _build_base() -> void:
	var dry := Color(0.62, 0.56, 0.42)
	var height := func(x: float, z: float) -> float:
		return sand_height(x, 140.0) + 2.0 * WaveModel.sstep(140.0, 200.0, z) \
			+ 1.5 * _noise.get_noise_2d(x * 0.8, z * 0.8)
	var color := func(_p: Vector3, nrm: Vector3) -> Color: return dry.darkened(clampf((1.0 - nrm.y) * 3.0, 0.0, 0.3))
	_grid("Land", -420.0, 260.0, 140.0, 460.0, 34, 16, height, color, false, Kind.GROUND)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ground := sand_height(0.0, 140.0) + 2.0
	# Pista
	_box(st, Vector3(-60.0, ground + 0.05, 230.0), Vector3(180.0, 0.1, 14.0), Color(0.2, 0.2, 0.21))
	_box(st, Vector3(-60.0, ground + 0.12, 230.0), Vector3(150.0, 0.02, 0.6), Color(0.85, 0.85, 0.8))
	# Hangares (bóveda aproximada con dos cajas)
	for i in 4:
		var c := Vector3(-150.0 + i * 38.0, ground, 190.0)
		_box(st, c + Vector3(0, 5.0, 0), Vector3(26.0, 10.0, 18.0), Color(0.45, 0.5, 0.42))
		_box(st, c + Vector3(0, 11.0, 0), Vector3(20.0, 2.0, 18.0), Color(0.5, 0.55, 0.47))
	# Torre de control
	_box(st, Vector3(20.0, ground + 9.0, 200.0), Vector3(4.0, 18.0, 4.0), Color(0.85, 0.83, 0.78))
	_box(st, Vector3(20.0, ground + 19.5, 200.0), Vector3(7.0, 3.0, 7.0), Color(0.3, 0.45, 0.5))
	# Edificios de Salinas en la orilla lejana
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 12:
		var x := -380.0 + i * 22.0 + rng.randf_range(-5.0, 5.0)
		var z := rng.randf_range(150.0, 175.0)
		var h := rng.randf_range(18.0, 55.0)
		var tone := rng.randf_range(0.82, 0.95)
		_box(st, Vector3(x, sand_height(x, z) + h * 0.5, z), Vector3(14.0, h, 14.0), Color(tone, tone, tone * 0.97))
	_add_mesh("Base", st.commit(), true, false)


## Caja con colores por vértice (coordenadas locales: se refleja con el resto).
func _box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := center + n * h
		var uu := u * h
		var vv := v * h
		var quad := [c - uu - vv, c + uu - vv, c + uu + vv, c - uu + vv]
		var shade := col.darkened(0.12 if n.y == 0.0 and n.x != 0.0 else 0.0)
		var wn := Vector3(n.x * mirror, n.y, n.z)
		_tri(st, _w(quad[0]), _w(quad[1]), _w(quad[2]), shade, wn)
		_tri(st, _w(quad[0]), _w(quad[2]), _w(quad[3]), shade, wn)


## Triángulo en coordenadas del mundo, con el sentido de giro que hace que su cara
## delantera mire hacia la normal (si no, en materiales de doble cara Godot la
## invierte al verlo por detrás y la cara queda a oscuras).
func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, col: Color, n: Vector3) -> void:
	if (p2 - p0).cross(p1 - p0).dot(n) < 0.0:
		var t := p1
		p1 = p2
		p2 = t
	for p in [p0, p1, p2]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


func _build_palms(count: int) -> void:
	var trunk_c := Color(0.42, 0.33, 0.22)
	var leaf_c := Color(0.2, 0.43, 0.15)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 7.0
	var segs := 6
	var sides := 6
	var spine := func(t: float) -> Vector3: return Vector3(0.9 * t * t, h * t, 0.0)
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var r0 := lerpf(0.2, 0.12, t0)
		var r1 := lerpf(0.2, 0.12, t1)
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var p00: Vector3 = spine.call(t0) + Vector3(cos(a0), 0, sin(a0)) * r0
			var p01: Vector3 = spine.call(t0) + Vector3(cos(a1), 0, sin(a1)) * r0
			var p10: Vector3 = spine.call(t1) + Vector3(cos(a0), 0, sin(a0)) * r1
			var p11: Vector3 = spine.call(t1) + Vector3(cos(a1), 0, sin(a1)) * r1
			for p in [p00, p10, p01, p01, p10, p11]:
				st.set_color(trunk_c)
				st.set_normal(Vector3(p.x - spine.call(t0).x, 0, p.z).normalized())
				st.add_vertex(p)
	var top: Vector3 = spine.call(1.0)
	for k in 8:
		var ang := TAU * k / 8 + 0.3
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := dir.cross(Vector3.UP).normalized()
		var prev_l := top
		var prev_r := top
		for s in range(1, 6):
			var t := s / 5.0
			var w := 0.55 * sin(PI * minf(t * 1.1, 1.0))
			var c := top + dir * (3.2 * t) + Vector3.UP * (0.9 * t - 2.2 * t * t)
			var l := c + side * w
			var r := c - side * w
			for p in [prev_l, l, prev_r, prev_r, l, r]:
				st.set_color(leaf_c)
				st.set_normal(Vector3.UP)
				st.add_vertex(p)
			prev_l = l
			prev_r = r
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	mm.instance_count = count
	# En La Rinconada la playa es estrecha: las palmeras van entre la arena y el acantilado.
	var z_max := 104.0 if scenery != "cliffs" else 90.0
	for i in count:
		var x := rng.randf_range(-210.0, 22.0)
		var z := rng.randf_range(82.0 if scenery == "cliffs" else 86.0, z_max)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.25))
		mm.set_instance_transform(i, Transform3D(b, _w(Vector3(x, sand_height(x, z) - 0.1, z))))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Palms"
	mmi.multimesh = mm
	mmi.material_override = _vc_material(true)
	add_child(mmi)


func _build_huts(count: int) -> void:
	var wall := Color(0.62, 0.5, 0.34)
	var roof := Color(0.72, 0.62, 0.38)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var spacing := 20.0 if scenery == "point" else 24.0
	for i in count:
		var x := -170.0 + i * spacing + rng.randf_range(-4.0, 4.0)
		if scenery == "cove":
			x = -90.0 + i * spacing
		var z := rng.randf_range(108.0, 122.0)
		var c := Vector3(x, sand_height(x, z), z)
		var w := rng.randf_range(2.5, 4.0)
		var d := rng.randf_range(2.5, 3.5)
		var hh := 2.6
		var corners := [Vector3(-w, 0, -d), Vector3(w, 0, -d), Vector3(w, 0, d), Vector3(-w, 0, d)]
		for k in 4:
			var a: Vector3 = c + corners[k]
			var b: Vector3 = c + corners[(k + 1) % 4]
			var nrm := (b - a).cross(Vector3.UP).normalized()
			var up := Vector3.UP * hh
			_tri(st, _w(a), _w(b + up), _w(b), wall, -_w(nrm))
			_tri(st, _w(a), _w(a + up), _w(b + up), wall, -_w(nrm))
		var apex := c + Vector3(0, hh + 2.0, 0)
		for k in 4:
			var a: Vector3 = c + corners[k] * 1.25 + Vector3.UP * (hh - 0.3)
			var b: Vector3 = c + corners[(k + 1) % 4] * 1.25 + Vector3.UP * (hh - 0.3)
			_tri(st, _w(a), _w(apex), _w(b), roof, _roof_normal(a, b, apex))
	_add_mesh("Huts", st.commit(), true, false)
