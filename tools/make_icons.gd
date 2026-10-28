extends SceneTree
## Genera los iconos de BARRELS (sin imágenes externas):
##   icon.png (512, también para la ficha de Google Play), icono adaptativo de Android
##   (fondo y primer plano 432×432 y monocromo) en res://assets/icon/.
## godot --path . -s tools/make_icons.gd   (necesita GPU: no usar --headless)

const OUT := "res://assets/icon/"


class IconArt:
	extends Control
	var layer := "full"   # full · background · foreground · mono

	func _draw() -> void:
		var s := size.x
		if layer == "full" or layer == "background":
			# Cielo de atardecer a mar Pacífico.
			var top := Color(1.0, 0.62, 0.36)
			var mid := Color(0.98, 0.45, 0.36)
			var sea := Color(0.04, 0.24, 0.40)
			var hz := s * 0.58
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s, 0), Vector2(s, hz), Vector2(0, hz)]),
				PackedColorArray([top, top, mid, mid]))
			draw_polygon(PackedVector2Array([Vector2(0, hz), Vector2(s, hz), Vector2(s, s), Vector2(0, s)]),
				PackedColorArray([Color(0.08, 0.5, 0.58), Color(0.08, 0.5, 0.58), sea, sea]))
			draw_circle(Vector2(s * 0.82, s * 0.4), s * 0.085, Color(1, 0.88, 0.6, 0.95))
		if layer == "background":
			return
		var white := Color(0.98, 0.96, 0.9) if layer != "mono" else Color.WHITE
		# En el icono adaptativo el dibujo debe caber en el 66 % central (zona segura).
		var k := 1.0 if layer == "full" else 0.66
		var o := Vector2(s, s) * (1.0 - k) * 0.5
		var c := o + Vector2(s, s) * k * Vector2(0.44, 0.56)
		var r := s * k * 0.3
		# Cara de la ola (turquesa) y labio en espiral (tubo).
		if layer != "mono":
			draw_circle(c, r * 1.05, Color(0.13, 0.74, 0.72))
			draw_circle(c, r * 0.55, Color(0.06, 0.32, 0.5))
		var spiral := PackedVector2Array()
		for i in 61:
			var t := float(i) / 60.0
			var a := PI * 0.5 + t * PI * 2.4
			spiral.append(c + Vector2(cos(a), -sin(a)) * r * (1.05 - 0.62 * t))
		draw_polyline(spiral, white, s * k * 0.07, true)
		draw_line(c + Vector2(-r * 1.45, r * 1.05), c + Vector2(r * 1.45, r * 1.05), white, s * k * 0.05, true)
		for i in 5:
			draw_circle(c + Vector2(r * (0.3 + 0.28 * i), -r * (1.05 + 0.12 * (i % 2))), s * k * 0.022, white)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	for job in [["icon.png", "full", 512], ["adaptive_background.png", "background", 432],
			["adaptive_foreground.png", "foreground", 432], ["monochrome.png", "mono", 432]]:
		var vp := SubViewport.new()
		vp.size = Vector2i(job[2], job[2])
		vp.transparent_bg = job[1] != "full" and job[1] != "background"
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var art := IconArt.new()
		art.layer = job[1]
		art.size = Vector2(job[2], job[2])
		vp.add_child(art)
		root.add_child(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + job[0]))
		print("icono: ", job[0])
		vp.queue_free()
	quit()
