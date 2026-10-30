extends Node3D
## Comprueba que la ola que se DIBUJA coincide con la que usa la FÍSICA.
## Renderiza la malla del agua real desde arriba (cámara ortográfica) con el
## shader en modo depuración, que escribe la altura de cada píxel codificada
## en color, y la compara con WaveModel.height_at() en el mismo punto (x, z).
## Así se mide también el error de la rejilla (la interpolación entre vértices).
##   godot --path . res://tests/wave_parity.tscn
## Necesita GPU (no funciona con --headless).

const W := 512
const H := 256
const SPAN := 32.0
const TIMES := [8.5, 11.0, 16.0]
const CENTERS_X := [-4.0, -14.0, 4.0]
const TOLERANCE := 0.12

var wave := WaveModel.new()
var condition := -1
var water: Water
var vp: SubViewport
var cam: Camera3D


func _ready() -> void:
	Ajustes.persist = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			Ajustes.set_quality(int(a.get_slice("=", 1)))
		elif a.begins_with("--spot="):
			Spots.apply_to_wave(Spots.get_spot(int(a.get_slice("=", 1))), wave)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--condition="):
			condition = clampi(int(a.get_slice("=", 1)), 0, 2)
	if condition >= 0:
		wave.tide = SurfSession.PRESETS[condition]["tide"]
		wave.height *= SurfSession.PRESETS[condition]["height"]
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = 1.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	add_child(vp)
	water = Water.new()
	water.wave = wave
	vp.add_child(water)
	water.set_debug_flat(true)
	(water.material_override as ShaderMaterial).set_shader_parameter("detail_level", 0)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = SPAN
	cam.near = 0.5
	cam.far = 50.0
	vp.add_child(cam)
	cam.current = true
	_run()


func _run() -> void:
	var worst := 0.0
	var total := 0
	print("[paridad] rejilla del agua: %d celdas (calidad %s)" % [Ajustes.preset()["water_grid"], Ajustes.preset()["name"]])
	for t in TIMES:
		for cx0 in CENTERS_X:
			var cx: float = cx0 * -wave.peel_dir  # en las izquierdas, los cortes se reflejan
			wave.time = t
			wave.update()
			var cz := wave.crest_z + 2.0
			water.global_position = Vector3(snappedf(cx, 4.0), 0, snappedf(cz, 4.0))
			water.sync(t)
			# Cámara cenital: mira a -Y; derecha de la imagen = +X, arriba = -Z.
			cam.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(cx, 20.0, cz))
			for i in 3:
				await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			var max_err := 0.0
			var sum_err := 0.0
			var n := 0
			var span_z := SPAN * H / W
			for py in range(4, H - 4, 6):
				for px in range(4, W - 4, 6):
					# En Compatibilidad el SubViewport devuelve los valores escritos sin conversión sRGB.
					var c := img.get_pixel(px, py)
					var hi := roundf(c.r * 64.0) / 64.0
					var v := hi + c.g / 64.0
					var y_gpu := v * 6.0 - 2.0
					var x: float = cx + (px + 0.5 - W * 0.5) / W * SPAN
					var z: float = cz + (py + 0.5 - H * 0.5) / H * span_z
					var err := absf(y_gpu - wave.height_at(x, z))
					max_err = maxf(max_err, err)
					sum_err += err
					n += 1
			total += n
			print("[paridad] t=%.1f x=%.0f z=%.0f: %d puntos, error medio %.3f m, máximo %.3f m" % [
				t, cx, cz, n, sum_err / maxi(n, 1), max_err])
			worst = maxf(worst, max_err)
	var ok := worst < TOLERANCE
	print("[paridad] RESULTADO: %d puntos, error máximo %.3f m (tolerancia %.2f) → %s" % [
		total, worst, TOLERANCE, "OK" if ok else "NO COINCIDE"])
	get_tree().quit(0 if ok else 1)
