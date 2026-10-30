class_name Fx
extends RefCounted
## Partículas de espuma y salpicaduras (CPUParticles3D: funcionan en Compatibilidad y en web).

static var _quad: QuadMesh


static func spray_mesh() -> QuadMesh:
	if _quad:
		return _quad
	# Gota con núcleo marcado y borde suave (32 px): se lee como agua y no como humo.
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.add_point(0.35, Color(1, 1, 1, 0.85))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Mezcla aditiva: brillan sobre el agua y desaparecen contra el cielo (sin "humo" gris),
	# y no dependen del orden de dibujo.
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.disable_receive_shadows = true
	mat.disable_fog = true
	_quad = QuadMesh.new()
	_quad.size = Vector2(0.35, 0.35)
	_quad.material = mat
	return _quad


static func setup_spray(p: CPUParticles3D, amount: int, lifetime: float, size_min: float, size_max: float) -> void:
	p.mesh = spray_mesh()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.42, 0.45, 0.47, 0.8))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = ramp
	p.emitting = false


static var _rail_quad: QuadMesh

## Board spray has slender droplets instead of the large round crest sprites.
static func setup_rail_spray(p: CPUParticles3D, amount: int) -> void:
	setup_spray(p,amount,0.40,0.12,0.40)
	if _rail_quad == null:
		var gradient := Gradient.new()
		gradient.set_color(0,Color(1,1,1,0.9))
		gradient.add_point(0.3,Color(1,1,1,0.7))
		gradient.set_color(gradient.get_point_count()-1,Color(1,1,1,0))
		var texture := GradientTexture2D.new()
		texture.gradient=gradient
		texture.fill=GradientTexture2D.FILL_RADIAL
		texture.fill_from=Vector2(0.5,0.5)
		texture.fill_to=Vector2(1.0,0.5)
		texture.width=32
		texture.height=64
		var material := StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo=true
		material.albedo_texture=texture
		material.disable_receive_shadows=true
		_rail_quad=QuadMesh.new()
		_rail_quad.size=Vector2(0.10,0.28)
		_rail_quad.material=material
	p.mesh=_rail_quad
	p.gravity=Vector3(0,-9.8,0)
	p.spread=22.0
	p.angle_min=-16.0
	p.angle_max=16.0
	p.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents=Vector3(0.04,0.015,0.06)
	var ramp := Gradient.new()
	ramp.set_color(0,Color(0.65,0.85,0.91,0.70))
	ramp.add_point(0.18,Color(0.90,0.97,1.0,0.60))
	ramp.set_color(ramp.get_point_count()-1,Color(0.8,0.92,0.97,0))
	p.color_ramp=ramp
