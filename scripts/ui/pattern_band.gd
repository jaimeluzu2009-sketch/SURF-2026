class_name PatternBand
extends Control
## Franja decorativa con motivos geométricos inspirados en la artesanía de la
## costa ecuatoriana. Se dibuja con primitivas (sin texturas) y se repite a lo largo.
##   0 «Greca»: escalones como los de la cerámica manteño-huancavilca.
##   1 «Tejido»: rombos entrelazados, como el tejido de paja toquilla.
##   2 «Olas»: espirales cuadradas que evocan las olas del Pacífico.

@export var motif := 0
@export var color := Color(UiKit.SAND, 0.35)
@export var accent := Color(UiKit.CORAL, 0.55)
@export var vertical := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var length := size.y if vertical else size.x
	var h := size.x if vertical else size.y
	if length <= 0.0 or h <= 0.0:
		return
	var step := h * 1.6
	var x := 0.0
	var i := 0
	while x < length:
		match motif:
			0:
				_greca(x, h, step, i)
			1:
				_rombo(x, h, step, i)
			_:
				_ola(x, h, step, i)
		x += step
		i += 1


func _pt(along: float, across: float) -> Vector2:
	return Vector2(across, along) if vertical else Vector2(along, across)


func _line(pts: Array, c: Color, w: float) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(_pt(q.x, q.y))
	draw_polyline(p, c, w, true)


func _greca(x: float, h: float, step: float, i: int) -> void:
	var w := maxf(1.5, h * 0.09)
	var a := h * 0.18
	var b := h * 0.82
	var s := step / 4.0
	_line([Vector2(x, b), Vector2(x + s, b), Vector2(x + s, (a + b) * 0.5), Vector2(x + 2 * s, (a + b) * 0.5),
		Vector2(x + 2 * s, a), Vector2(x + 3 * s, a), Vector2(x + 3 * s, (a + b) * 0.5),
		Vector2(x + 4 * s, (a + b) * 0.5), Vector2(x + 4 * s, b)], color, w)
	if i % 3 == 1:
		draw_circle(_pt(x + 2.5 * s, b - h * 0.12), h * 0.07, accent)


func _rombo(x: float, h: float, step: float, i: int) -> void:
	var w := maxf(1.2, h * 0.07)
	var c := Vector2(x + step * 0.5, h * 0.5)
	var rx := step * 0.48
	var ry := h * 0.4
	_line([c + Vector2(-rx, 0), c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)],
		color, w)
	var k := 0.45
	_line([c + Vector2(-rx * k, 0), c + Vector2(0, -ry * k), c + Vector2(rx * k, 0), c + Vector2(0, ry * k),
		c + Vector2(-rx * k, 0)], accent if i % 2 == 0 else color, w)


func _ola(x: float, h: float, step: float, i: int) -> void:
	var w := maxf(1.5, h * 0.08)
	var top := h * 0.2
	var bot := h * 0.8
	var s := step
	_line([Vector2(x, bot), Vector2(x + s * 0.55, bot), Vector2(x + s * 0.55, top), Vector2(x + s * 0.2, top),
		Vector2(x + s * 0.2, h * 0.55), Vector2(x + s * 0.38, h * 0.55)], color, w)
	_line([Vector2(x + s * 0.55, bot), Vector2(x + s, bot)], color, w)
	if i % 4 == 2:
		draw_circle(_pt(x + s * 0.8, top + h * 0.1), h * 0.08, accent)
