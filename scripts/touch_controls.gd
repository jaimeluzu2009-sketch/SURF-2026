class_name TouchControls
extends Control
## Controles táctiles: joystick flotante en la mitad izquierda y botones
## REMAR / PARARSE abajo a la derecha. El tamaño se adapta a la pantalla.
## Con el ratón también funcionan (útil para probar en el escritorio).

const MOUSE_ID := -1
const NONE := -100

var active := true
var stand_ready := false

var _stick_id := NONE
var _stick_center := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _paddle_id := NONE
var _stand_flash := 0.0
var _r := 80.0
var _margin := 24.0
var _paddle_c := Vector2.ZERO
var _stand_c := Vector2.ZERO
var _rest_c := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	Ajustes.changed.connect(_refresh)
	resized.connect(_layout)
	_refresh()
	_layout()


func _refresh() -> void:
	visible = Ajustes.touch_enabled()
	_layout()
	if not visible:
		_release_all()


func _layout() -> void:
	var s := size
	var short := minf(s.x, s.y)
	_r = clampf(short * 0.12, 48.0, 120.0) * Ajustes.touch_size
	_margin = clampf(short * 0.04, 14.0, 40.0)
	_paddle_c = Vector2(s.x - _margin - _r * 1.15, s.y - _margin - _r * 1.15)
	_stand_c = _paddle_c + Vector2(-_r * 2.45, -_r * 0.35)
	_rest_c = Vector2(_margin + _r * 1.5, s.y - _margin - _r * 1.5)
	if Ajustes.left_handed:
		# Modo zurdo: todo en espejo (joystick a la derecha, botones a la izquierda).
		_paddle_c.x = s.x - _paddle_c.x
		_stand_c.x = s.x - _stand_c.x
		_rest_c.x = s.x - _rest_c.x
	queue_redraw()


func _in_stick_zone(pos: Vector2) -> bool:
	var left := pos.x < size.x * 0.5
	return (left != Ajustes.left_handed) and pos.y > size.y * 0.25


func _release_all() -> void:
	_stick_id = NONE
	_paddle_id = NONE
	Controles.touch_stick = Vector2.ZERO
	Controles.touch_paddle = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not active:
		_release_all()
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return  # ratón emulado a partir de un toque: ya se trató como toque
	var id := NONE
	var pos := Vector2.ZERO
	var pressed := false
	var is_press := false
	var is_drag := false
	if event is InputEventScreenTouch:
		id = event.index
		pos = event.position
		pressed = event.pressed
		is_press = true
	elif event is InputEventScreenDrag:
		id = event.index
		pos = event.position
		is_drag = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		id = MOUSE_ID
		pos = event.position
		pressed = event.pressed
		is_press = true
	elif event is InputEventMouseMotion and _stick_id == MOUSE_ID:
		id = MOUSE_ID
		pos = event.position
		is_drag = true
	else:
		return
	pos = get_global_transform_with_canvas().affine_inverse() * pos

	if is_press and pressed:
		if pos.distance_to(_paddle_c) < _r * 1.2:
			_paddle_id = id
			Controles.touch_paddle = true
			if Ajustes.paddle_toggle:
				Controles.toggle_touch_paddle()
		elif pos.distance_to(_stand_c) < _r * 1.0:
			Controles.press_touch_stand()
			_stand_flash = 0.25
		elif _in_stick_zone(pos) and _stick_id == NONE:
			_stick_id = id
			_stick_center = pos
			_stick_pos = pos
			_update_stick()
	elif is_press and not pressed:
		if id == _paddle_id:
			_paddle_id = NONE
			Controles.touch_paddle = false
		if id == _stick_id:
			_stick_id = NONE
			Controles.touch_stick = Vector2.ZERO
	elif is_drag and id == _stick_id:
		_stick_pos = pos
		_update_stick()
	queue_redraw()


func _update_stick() -> void:
	var d := (_stick_pos - _stick_center) / _r
	if d.length() > 1.0:
		d = d.normalized()
	# Pantalla: y hacia abajo. Juego: y = adelante.
	Controles.touch_stick = Vector2(d.x, -d.y)


func _process(delta: float) -> void:
	_time += delta
	_stand_flash = maxf(0.0, _stand_flash - delta)
	if visible:
		queue_redraw()


func _draw() -> void:
	var font := UiKit.font_display()
	var white := Color(1, 1, 1, 0.85)
	# Joystick
	var c := _stick_center if _stick_id != NONE else _rest_c
	draw_circle(c, _r, Color(UiKit.NIGHT, 0.35))
	draw_arc(c, _r, 0, TAU, 48, Color(UiKit.SAND, 0.55), 3.0, true)
	draw_arc(c, _r * 0.78, 0, TAU, 48, Color(UiKit.SAND, 0.18), 2.0, true)
	var knob := c + Vector2(Controles.touch_stick.x, -Controles.touch_stick.y) * _r
	draw_circle(knob, _r * 0.42, Color(UiKit.SAND, 0.6 if _stick_id != NONE else 0.32))
	# REMAR
	var paddle_on := _paddle_id != NONE or (Ajustes.paddle_toggle and Controles.paddle_latched)
	draw_circle(_paddle_c, _r, Color(UiKit.TURQUOISE, 0.8 if paddle_on else 0.45))
	draw_arc(_paddle_c, _r, 0, TAU, 48, white, 3.0, true)
	_label(font, _paddle_c, "REMAR", _r)
	# PARARSE (late cuando se puede)
	var pulse := 0.5 + 0.5 * sin(_time * 10.0) if stand_ready else 0.0
	var col := Color(UiKit.CORAL, 0.6 + 0.35 * pulse) if stand_ready else Color(UiKit.NIGHT, 0.45)
	if _stand_flash > 0.0:
		col = Color(1, 1, 1, 0.8)
	var rs := _r * (0.9 + 0.08 * pulse)
	draw_circle(_stand_c, rs, col)
	draw_arc(_stand_c, rs, 0, TAU, 48, white, 3.0, true)
	_label(font, _stand_c, "PARARSE", _r)


func _label(font: Font, center: Vector2, text: String, r: float) -> void:
	var fs := int(r * 0.3)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, center + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4,
		Color(0, 0, 0, 0.6))
	draw_string(font, center + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
