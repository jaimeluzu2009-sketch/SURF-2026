class_name UiKit
extends RefCounted
## Paleta, tipografía, tema y componentes reutilizables de la interfaz de BARRELS.
## Estilo: surf premium del Pacífico ecuatoriano (azul Pacífico, turquesa, arena,
## coral y atardecer) con motivos artesanales sutiles (ver PatternBand).
## Fuentes: Barlow / Barlow Condensed (SIL Open Font License, fonts/OFL.txt).

const NIGHT := Color(0.035, 0.085, 0.125)
const DEEP := Color(0.05, 0.17, 0.25)
const PACIFIC := Color(0.06, 0.32, 0.50)
const TURQUOISE := Color(0.13, 0.74, 0.72)
const SAND := Color(0.96, 0.89, 0.76)
const CORAL := Color(0.98, 0.45, 0.36)
const SUNSET := Color(1.0, 0.66, 0.30)
const GOLD := Color(1.0, 0.82, 0.26)
const TEXT := Color(0.98, 0.96, 0.92)
const TEXT_DIM := Color(0.74, 0.80, 0.82)
const OK := Color(0.42, 0.86, 0.58)

static var _fonts := {}
static var _theme: Theme


static func _font(path: String) -> Font:
	if not _fonts.has(path):
		var f: Font = load(path)
		_fonts[path] = f if f else ThemeDB.fallback_font
	return _fonts[path]


## Titulares: Barlow Condensed ExtraBold Italic.
static func font_display() -> Font:
	return _font("res://fonts/BarlowCondensed-ExtraBoldItalic.ttf")


## Subtítulos, botones y cifras: Barlow Condensed Bold.
static func font_title() -> Font:
	return _font("res://fonts/BarlowCondensed-Bold.ttf")


## Texto corrido: Barlow SemiBold.
static func font_body() -> Font:
	return _font("res://fonts/Barlow-SemiBold.ttf")


static func box(bg: Color, radius := 12, border := Color(0, 0, 0, 0), border_w := 0, margin := 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.anti_aliasing = true
	return sb


## Tema global: botones, listas desplegables, casillas, deslizadores y barras.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)

	var b_normal := box(Color(NIGHT, 0.78), 10, Color(SAND, 0.16), 1, 12)
	var b_hover := box(Color(PACIFIC, 0.92), 10, Color(TURQUOISE, 0.7), 1, 12)
	var b_pressed := box(Color(TURQUOISE, 0.95), 10, Color(SAND, 0.6), 1, 12)
	var b_focus := box(Color(0, 0, 0, 0), 10, CORAL, 2, 12)
	var b_disabled := box(Color(NIGHT, 0.45), 10, Color(SAND, 0.06), 1, 12)
	for cls in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cls, b_normal)
		t.set_stylebox("hover", cls, b_hover)
		t.set_stylebox("pressed", cls, b_pressed)
		t.set_stylebox("hover_pressed", cls, b_pressed)
		t.set_stylebox("focus", cls, b_focus)
		t.set_stylebox("disabled", cls, b_disabled)
		t.set_font("font", cls, font_title())
		t.set_font_size("font_size", cls, 22)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, TEXT)
		t.set_color("font_pressed_color", cls, NIGHT)
		t.set_color("font_focus_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, Color(TEXT_DIM, 0.5))
	# Las casillas no se pintan de turquesa al estar activadas: solo el interruptor.
	for cls in ["CheckButton", "CheckBox"]:
		t.set_stylebox("pressed", cls, b_normal)
		t.set_stylebox("hover_pressed", cls, b_hover)
		t.set_color("font_pressed_color", cls, TEXT)
	t.set_stylebox("panel", "PopupMenu", box(Color(NIGHT, 0.98), 10, Color(TURQUOISE, 0.5), 1, 8))
	t.set_stylebox("hover", "PopupMenu", box(Color(PACIFIC, 1.0), 6, Color(0, 0, 0, 0), 0, 6))
	t.set_font("font", "PopupMenu", font_title())
	t.set_font_size("font_size", "PopupMenu", 22)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)

	var track := box(Color(SAND, 0.18), 6, Color(0, 0, 0, 0), 0, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(TURQUOISE, 6, Color(0, 0, 0, 0), 0, 0)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)

	t.set_stylebox("background", "ProgressBar", box(Color(SAND, 0.16), 6, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(TURQUOISE, 6, Color(0, 0, 0, 0), 0, 0))
	t.set_font_size("font_size", "ProgressBar", 1)
	t.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))

	t.set_stylebox("panel", "PanelContainer", box(Color(NIGHT, 0.82), 16, Color(SAND, 0.1), 1, 20))
	t.set_stylebox("panel", "TooltipPanel", box(Color(NIGHT, 0.95), 8))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	_theme = t
	return t


# ------------------------------------------------------------------ componentes

static func label(text: String, size := 20, color := TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Titular con sombra suave (para el menú y los resultados).
static func headline(text: String, size := 64, color := SAND) -> Label:
	var l := label(text, size, color, font_display())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l


## Etiqueta pequeña en mayúsculas, espaciada (sobretítulos de sección).
static func kicker(text: String, color := TURQUOISE) -> Label:
	var l := label(text.to_upper(), 16, color, font_title())
	return l


## Botón principal (coral, el más importante de cada pantalla) o secundario.
static func button(text: String, primary := false, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 56 if primary else 50)
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		b.add_theme_stylebox_override("normal", box(CORAL, 12, Color(SUNSET, 0.8), 1, 14))
		b.add_theme_stylebox_override("hover", box(SUNSET, 12, Color(SAND, 0.9), 1, 14))
		b.add_theme_stylebox_override("pressed", box(CORAL.darkened(0.15), 12, SAND, 1, 14))
		b.add_theme_color_override("font_color", NIGHT)
		b.add_theme_color_override("font_hover_color", NIGHT)
		b.add_theme_color_override("font_focus_color", NIGHT)
		b.add_theme_font_override("font", font_display())
		b.add_theme_font_size_override("font_size", 28)
	_hover_motion(b)
	return b


## Pequeño desplazamiento al pasar el ratón o el foco (se desactiva con "reducir movimiento").
static func _hover_motion(c: Control) -> void:
	var grow := func(on: bool) -> void:
		if Ajustes.reduce_motion or not c.is_inside_tree():
			return
		c.pivot_offset = c.size * 0.5
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector2.ONE * (1.03 if on else 1.0), 0.12)
	c.mouse_entered.connect(grow.bind(true))
	c.mouse_exited.connect(grow.bind(false))
	c.focus_entered.connect(grow.bind(true))
	c.focus_exited.connect(grow.bind(false))


static func panel(bg := Color(NIGHT, 0.82), radius := 16, border := Color(SAND, 0.1), margin := 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, border, 1, margin))
	return p


static func chip(text: String, bg: Color, fg := NIGHT, size := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(bg, 20, Color(0, 0, 0, 0), 0, 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, size, fg, font_title()))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func progress(value: float, color := TURQUOISE, height := 10.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.step = 0.001
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	pb.add_theme_stylebox_override("fill", box(color, 6, Color(0, 0, 0, 0), 0, 0))
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb


## Cifra grande con su rótulo debajo.
static func stat(value: String, caption: String, color := SAND) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var n := label(value, 34, color, font_title())
	n.name = "Value"
	v.add_child(n)
	v.add_child(label(caption.to_upper(), 14, TEXT_DIM, font_title()))
	return v


static func spacer(h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expand() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Fila de ajuste: rótulo (y ayuda) a la izquierda, control a la derecha.
static func setting_row(title: String, help: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(label(title, 21, TEXT, font_title()))
	if help != "":
		var h := label(help, 15, TEXT_DIM)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(h)
	row.add_child(texts)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 230)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row


static func option(items: Array, selected: int, on_select: Callable) -> OptionButton:
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(str(it))
	ob.select(clampi(selected, 0, items.size() - 1))
	ob.custom_minimum_size = Vector2(230, 46)
	# Abre la lista al soltar: si abriera al tocar, deslizar el menú sobre un
	# selector abría el desplegable y se tragaba el arrastre en el móvil.
	ob.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	ob.item_selected.connect(on_select)
	ob.get_popup().add_theme_font_size_override("font_size", 22)
	return ob


static func toggle(on: bool, on_toggle: Callable) -> CheckButton:
	var cb := CheckButton.new()
	cb.button_pressed = on
	cb.text = "Sí" if on else "No"
	cb.toggled.connect(func(v):
		cb.text = "Sí" if v else "No"
		on_toggle.call(v))
	cb.custom_minimum_size = Vector2(230, 46)
	return cb


## Deslizador con su valor a la derecha. fmt recibe el valor y devuelve el texto.
static func slider(min_v: float, max_v: float, step: float, value: float, fmt: Callable, on_change: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(300, 46)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	var l := label(fmt.call(value), 20, SAND, font_title())
	l.custom_minimum_size = Vector2(64, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v):
		l.text = fmt.call(v)
		on_change.call(v))
	h.add_child(s)
	h.add_child(l)
	return h


## Pestañas simples hechas con botones (más fáciles de usar con el dedo que TabBar).
static func tabs(names: Array, on_pick: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("pressed", box(Color(TURQUOISE, 0.95), 10, Color(0, 0, 0, 0), 0, 10))
		b.pressed.connect(on_pick.bind(i))
		if i == 0:
			b.button_pressed = true
		h.add_child(b)
	return h


## Aparición suave de una pantalla (fundido y deslizamiento corto).
static func reveal(c: Control, from := Vector2(0, 18)) -> void:
	c.visible = true
	if Ajustes.reduce_motion:
		c.modulate.a = 1.0
		return
	c.modulate.a = 0.0
	var base := c.position
	c.position = base + from
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.28)
	tw.tween_property(c, "position", base, 0.32)


static func kmh(ms: float) -> String:
	return "%d" % int(round(ms * 3.6))


## Número con separador de miles a la española (12.345).
static func num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
