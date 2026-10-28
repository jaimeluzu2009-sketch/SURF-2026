class_name SpotArt
extends Control
## Ilustración vectorial de cada spot para las tarjetas de selección, dibujada con
## polígonos (sin imágenes): cielo, sol, costa característica y la ola rompiendo
## hacia su lado (derecha o izquierda).

var spot: Dictionary
var selected := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_spot(s: Dictionary) -> void:
	spot = s
	queue_redraw()


func _grad_rect(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end,
		r.position + Vector2(0, r.size.y)]), PackedColorArray([top, top, bottom, bottom]))


func _draw() -> void:
	if spot.is_empty():
		return
	var w := size.x
	var h := size.y
	var hz := h * 0.56
	var main: Color = spot["ui_main"]
	var dark: Color = spot["ui_dark"]
	var sky: Color = spot["ui_sky"]
	var sea_top: Color = (spot["face"] as Color).lightened(0.15)
	var sea_bot: Color = (spot["deep"] as Color).darkened(0.2)
	_grad_rect(Rect2(0, 0, w, hz), sky.darkened(0.25), sky.lightened(0.25))
	# Sol bajo con halo.
	var sun := Vector2(w * (0.7 if spot["dir"] < 0.0 else 0.3), hz * 0.62)
	draw_circle(sun, h * 0.2, Color(UiKit.SUNSET, 0.18))
	draw_circle(sun, h * 0.12, Color(UiKit.SUNSET, 0.35))
	draw_circle(sun, h * 0.075, Color(1.0, 0.92, 0.7, 0.95))
	_grad_rect(Rect2(0, hz, w, h - hz), sea_top, sea_bot)

	# Costa según el escenario. side: lado del cabo (de donde viene la rotura).
	var side := 1.0 if spot["dir"] < 0.0 else -1.0
	var land := dark.lerp(main, 0.25)
	match spot["scenery"]:
		"point":
			_headland(side, land, 0.42, 0.34)
			for k in 7:
				var px := w * (0.5 + side * (0.08 + k * 0.035))
				draw_rect(Rect2(px, hz - h * 0.05 - (k % 3) * 3.0, 7, 6), Color(0.85, 0.36, 0.25, 0.9))
		"cliffs":
			_headland(side, land, 0.5, 0.42)
			_headland(-side, land.darkened(0.15), 0.3, 0.3)
		_:
			# Costa llana con la torre de la base y los edificios de Salinas.
			draw_rect(Rect2(0, hz - h * 0.035, w, h * 0.035), land)
			var bx := w * (0.5 - side * 0.32)
			for k in 6:
				var bh := h * (0.1 + 0.05 * ((k * 7) % 4))
				draw_rect(Rect2(bx + k * w * 0.035 * -side, hz - bh, w * 0.026, bh), Color(0.92, 0.9, 0.86, 0.85))
			var tx := w * (0.5 + side * 0.3)
			draw_rect(Rect2(tx, hz - h * 0.16, w * 0.012, h * 0.16), Color(0.9, 0.88, 0.84))
			draw_rect(Rect2(tx - w * 0.012, hz - h * 0.18, w * 0.036, h * 0.025), Color(0.3, 0.45, 0.5))
	_wave(side)
	if selected:
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiKit.SAND, 0.0), false)


func _headland(side: float, col: Color, width: float, height: float) -> void:
	var w := size.x
	var h := size.y
	var hz := h * 0.56
	var edge := w if side > 0.0 else 0.0
	var tip := w * (0.5 + side * (0.5 - width))
	var pts := PackedVector2Array([
		Vector2(edge, hz + h * 0.02), Vector2(tip, hz + h * 0.02), Vector2(tip + side * w * 0.04, hz - h * 0.05),
		Vector2(tip + side * w * 0.1, hz - h * height * 0.7), Vector2(tip + side * w * 0.2, hz - h * height),
		Vector2(edge, hz - h * height * 1.05)])
	draw_colored_polygon(pts, col)


## Ola: cara curva, labio que cae y espuma, abriendo hacia el lado contrario al cabo.
func _wave(side: float) -> void:
	var w := size.x
	var h := size.y
	var base := h * 0.86
	var face := Color((spot["face"] as Color).lightened(0.1), 0.95)
	var lip_x := w * (0.5 + side * 0.18)
	var pts := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var t := float(i) / n
		var x := lerpf(w * (0.5 - side * 0.55), lip_x, t)
		var y := base - h * 0.3 * pow(t, 2.2)
		pts.append(Vector2(x, y))
	pts.append(Vector2(lip_x + side * w * 0.06, base - h * 0.24))
	pts.append(Vector2(lip_x + side * w * 0.05, base))
	draw_colored_polygon(pts, face)
	# Labio que se curva.
	var lip := PackedVector2Array()
	for i in 13:
		var a := PI * 0.5 + side * PI * 0.9 * float(i) / 12.0
		lip.append(Vector2(lip_x, base - h * 0.2) + Vector2(cos(a) * w * 0.06 * side, -sin(a) * h * 0.1))
	draw_polyline(lip, Color(1, 1, 1, 0.85), maxf(2.0, h * 0.02), true)
	# Espuma y salpicaduras detrás del labio.
	for k in 9:
		var fx := lip_x + side * w * (0.03 + 0.04 * k)
		draw_circle(Vector2(fx, base - h * (0.02 + 0.03 * (k % 3))), h * (0.03 + 0.01 * (k % 2)), Color(1, 1, 1, 0.8))
	draw_rect(Rect2(0, base, w, h - base), Color(sea_shade(), 0.6))


func sea_shade() -> Color:
	return (spot["deep"] as Color).darkened(0.3)
