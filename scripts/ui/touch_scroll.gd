class_name TouchScroll
extends Node
## Desplaza un ScrollContainer arrastrando el dedo aunque el toque empiece sobre un
## botón, panel o deslizador (esos controles se quedan el evento y el contenedor no
## llegaba a moverse en el móvil). Al superar el umbral vertical cancela la pulsación
## del control para que soltar el dedo no active el botón, y añade inercia.
## En el móvil manda el dedo (índice 0); en PC, sin toques, el ratón.

const THRESHOLD := 14.0
const FRICTION := 6.0

var _scroll: ScrollContainer
var _pressing := false
var _dragging := false
var _touch := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _velocity := 0.0
var _swallow_touch := false
var _swallow_mouse := false
var _injecting := false


static func attach(scroll: ScrollContainer) -> TouchScroll:
	var t := TouchScroll.new()
	t.name = "TouchScroll"
	t._scroll = scroll
	scroll.add_child(t, false, Node.INTERNAL_MODE_BACK)
	return t


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if _injecting:
		return
	if not _scroll.is_visible_in_tree():
		_pressing = false
		_dragging = false
		_touch = false
		return
	var st := event as InputEventScreenTouch
	if st and st.index == 0:
		if st.pressed:
			_touch = true
			_begin(st.position)
		else:
			if _swallow_touch:
				_swallow_touch = false
				get_viewport().set_input_as_handled()
			_touch = false
			_pressing = false
			_dragging = false
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if not _touch:
				_begin(mb.position)
		else:
			if _swallow_mouse:
				_swallow_mouse = false
				get_viewport().set_input_as_handled()
			if not _touch:
				_pressing = false
				_dragging = false
		return
	var sd := event as InputEventScreenDrag
	if sd and sd.index == 0:
		_move(sd.position)
		return
	var mm := event as InputEventMouseMotion
	if mm and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not _touch:
			_move(mm.position)
		elif _dragging:
			get_viewport().set_input_as_handled()  # ratón emulado del dedo


func _begin(pos: Vector2) -> void:
	_velocity = 0.0
	_pressing = _scroll.get_global_rect().has_point(pos) and _max_scroll() > 0
	_dragging = false
	_swallow_touch = false
	_swallow_mouse = false
	_start = pos
	_last = pos


func _move(pos: Vector2) -> void:
	if not _pressing:
		return
	if not _dragging:
		var d := pos - _start
		if absf(d.y) < THRESHOLD or absf(d.y) < absf(d.x):
			return
		_dragging = true
		_last = pos
		_cancel_press()
	var dy := pos.y - _last.y
	_last = pos
	_scroll.scroll_vertical = int(_scroll.scroll_vertical - dy)
	var dt := maxf(get_process_delta_time(), 1.0 / 120.0)
	_velocity = lerpf(_velocity, -dy / dt, 0.35)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _dragging or absf(_velocity) < 20.0:
		return
	_scroll.scroll_vertical = int(_scroll.scroll_vertical + _velocity * delta)
	_velocity *= exp(-FRICTION * delta)


func _max_scroll() -> float:
	var bar := _scroll.get_v_scroll_bar()
	return bar.max_value - bar.page if bar else 0.0


## Suelta fuera de su área el control que recibió la pulsación (así no se activa)
## y se queda el "soltar" real del dedo y de su ratón emulado.
func _cancel_press() -> void:
	var away := Vector2(-10000, -10000)
	var out := InputEventMouseMotion.new()
	out.button_mask = MOUSE_BUTTON_MASK_LEFT
	out.position = away
	out.global_position = away
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = away
	up.global_position = away
	_injecting = true
	get_viewport().push_input(out)
	get_viewport().push_input(up)
	_injecting = false
	get_viewport().gui_release_focus()
	_swallow_touch = _touch
	_swallow_mouse = not _touch or Input.is_emulating_mouse_from_touch()
