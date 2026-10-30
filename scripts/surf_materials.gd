class_name SurfMaterials
extends RefCounted
## Materiales del surfista y de la tabla. Sustituyen a los colores planos del GLB
## (que se conservan como color base) por materiales con textura de detalle.
##
## Todas las texturas se generan en el propio Godot con ruido (NoiseTexture2D):
## no hay imágenes externas ni licencias que registrar. Son pequeñas (64-256 px),
## sin costuras (seamless), con mipmaps y filtrado anisótropo. Las UV de los
## modelos están a escala real (1 unidad = 1 m), así que uv1_scale indica cuántas
## veces se repite la textura por metro.

static var _cache := {}


## Textura de ruido sin costuras. normal = true la convierte en mapa de normales.
static func noise_tex(key: String, size: int, freq: float, octaves: int, normal: bool, bump := 4.0,
		stretch := Vector2.ONE) -> NoiseTexture2D:
	if _cache.has(key):
		return _cache[key]
	var n := FastNoiseLite.new()
	n.seed = key.hash() & 0xffff
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = int(size * stretch.x)
	t.height = int(size * stretch.y)
	t.seamless = true
	t.noise = n
	t.generate_mipmaps = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	_cache[key] = t
	return t


static func _base(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Crea el material para un nombre de material del GLB (ver tools/build_assets.py).
static func make(mat_name: String, col: Color, detail: bool) -> Material:
	var m := _base(col)
	match mat_name:
		"Neopreno":
			# Neopreno mojado: casi mate, con un tejido fino que se ve de cerca.
			m.roughness = 0.62
			m.metallic_specular = 0.35
			if detail:
				m.normal_enabled = true
				m.normal_texture = noise_tex("neopreno_n", 128, 0.25, 2, true, 3.0)
				m.normal_scale = 0.35
				m.uv1_scale = Vector3(14, 14, 1)
				m.roughness_texture = noise_tex("neopreno_r", 64, 0.08, 2, false)
				m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		"Licra", "Bermuda", "Costura", "Grafica", "Franja", "Rodilleras", "Leash":
			m.roughness = 0.55
			m.metallic_specular = 0.4
			if detail:
				m.normal_enabled = true
				m.normal_texture = noise_tex("neopreno_n", 128, 0.25, 2, true, 3.0)
				m.normal_scale = 0.3
				m.uv1_scale = Vector3(14, 14, 1)
		"Piel":
			# Piel con brillo sutil (agua) y un borde de luz que la separa del fondo.
			m.roughness = 0.48
			m.metallic_specular = 0.42
			m.rim_enabled = true
			m.rim = 0.25
			m.rim_tint = 0.6
			if detail:
				m.normal_enabled = true
				m.normal_texture = noise_tex("piel_n", 128, 0.3, 3, true, 1.5)
				m.normal_scale = 0.25
				m.uv1_scale = Vector3(10, 10, 1)
		"Pelo":
			# Mechones: ruido estirado en una dirección.
			m.roughness = 0.55
			m.metallic_specular = 0.45
			if detail:
				m.normal_enabled = true
				m.normal_texture = noise_tex("pelo_n", 64, 0.35, 3, true, 6.0, Vector2(1, 4))
				m.normal_scale = 0.8
				m.uv1_scale = Vector3(18, 5, 1)
		"Ojos":
			m.roughness = 0.1
			m.metallic_specular = 0.8
		"Cubierta":
			# Fibra de vidrio con parafina: brillo suave y manchas de cera más mates.
			m.roughness = 0.22
			m.metallic_specular = 0.55
			if detail:
				m.roughness_texture = noise_tex("cera", 128, 0.06, 3, false)
				m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				m.roughness = 0.55
				m.normal_enabled = true
				m.normal_texture = noise_tex("cera_n", 128, 0.12, 2, true, 1.2)
				m.normal_scale = 0.2
				m.uv1_scale = Vector3(3, 3, 1)
		"Fondo":
			m.roughness = 0.18
			m.metallic_specular = 0.6
		"Larguero":
			m.roughness = 0.35
		"Grip":
			# Pad de goma EVA con surcos.
			m.roughness = 0.95
			m.metallic_specular = 0.2
			if detail:
				m.normal_enabled = true
				m.normal_texture = noise_tex("grip_n", 64, 0.5, 1, true, 8.0, Vector2(1, 4))
				m.normal_scale = 1.0
				m.uv1_scale = Vector3(6, 24, 1)
		"Quillas":
			m.roughness = 0.3
			m.metallic_specular = 0.5
		_:
			m.roughness = 0.6
	return m


## Sustituye los materiales de todos los MeshInstance3D del modelo.
## look: colores elegidos por el jugador, por nombre de material (p. ej. "Neopreno").
static func apply(model: Node, detail: bool, look := {}) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			var col: Color = look.get(src.resource_name, src.albedo_color)
			(mi as MeshInstance3D).set_surface_override_material(i, make(src.resource_name, col, detail))
