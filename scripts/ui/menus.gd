class_name Menus
extends Control
## Pantallas de BARRELS: menú principal, selección de spot, surfista y tabla,
## carrera (progreso, récords, logros, desafíos), ajustes, pausa y resultados.
## Todo lee y escribe en los sistemas reales: Ajustes, Perfil y Spots.

signal play_requested(spot_index: int)
signal restart_requested
signal resume_requested
signal menu_requested
signal customize_preview(on: bool)

const MARGIN := 56.0

var _screens := {}
var _current := ""
var _back_to := {}
var _settings_tabs: HBoxContainer
var _career_tabs: HBoxContainer
var _settings_body: VBoxContainer
var _settings_tab := 0
var _career_body: VBoxContainer
var _career_tab := 0
var _customizer: SurfCustomizer
signal customize_view(index: int)
var _main_level: Label
var _main_xp: ProgressBar
var _main_xp_text: Label
var _main_play: Button
var _spot_cards: HBoxContainer
var _pause_kicker: Label
var _res := {}


func _ready() -> void:
	theme = UiKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_main()
	_build_spots()
	_build_custom()
	_build_career()
	_build_settings()
	_build_pause()
	_build_results()
	for s in _screens.values():
		s.visible = false


# ------------------------------------------------------------------ navegación

func is_open() -> bool:
	return _current != ""


func current() -> String:
	return _current


func open(screen: String, back := "") -> void:
	Controles.cancel_rebind()
	if _current == "custom" and screen != "custom":
		customize_preview.emit(false)
	for s in _screens.values():
		s.visible = false
	_current = screen
	if back != "":
		_back_to[screen] = back
	var node: Control = _screens[screen]
	match screen:
		"main":
			_refresh_main()
		"spots":
			_refresh_spots()
		"custom":
			_refresh_custom()
			customize_preview.emit(true)
		"career":
			_refresh_career()
		"settings":
			_refresh_settings()
		"pause":
			_pause_kicker.text = _spot_name().to_upper()
	UiKit.reveal(node)
	_focus_first(node)


func close() -> void:
	Controles.cancel_rebind()
	if _current == "custom":
		customize_preview.emit(false)
	for s in _screens.values():
		s.visible = false
	_current = ""


func back() -> void:
	match _current:
		"main", "":
			return
		"pause":
			resume_requested.emit()
		"results":
			return
		_:
			open(_back_to.get(_current, "main"))


func _unhandled_input(event: InputEvent) -> void:
	if _current != "" and event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()


func _focus_first(node: Node) -> void:
	for c in node.find_children("*", "BaseButton", true, false):
		if (c as Control).is_visible_in_tree() and not (c as BaseButton).disabled:
			(c as Control).grab_focus()
			return


func _spot() -> Dictionary:
	return Spots.get_spot(Ajustes.spot)


func _spot_name() -> String:
	var s := _spot()
	return "%s · %s" % [s["name"], s["zone"]]


# ------------------------------------------------------------------ piezas comunes

func _screen(screen_name: String, dim := 0.0) -> Control:
	var c := Control.new()
	c.name = screen_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	if dim > 0.0:
		var bg := ColorRect.new()
		bg.color = Color(UiKit.NIGHT, dim)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(bg)
	add_child(c)
	_screens[screen_name] = c
	return c


## Degradado lateral (oscuro a transparente) para leer texto sobre la escena 3D.
func _side_shade(parent: Control, width_frac: float, alpha := 0.92) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(UiKit.NIGHT, alpha))
	g.set_color(1, Color(UiKit.NIGHT, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 4
	var tr := TextureRect.new()
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.anchor_right = width_frac
	tr.anchor_bottom = 1.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)


func _margin_box(parent: Control, l := MARGIN, t := 40.0, r := MARGIN, b := 36.0) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", int(l))
	m.add_theme_constant_override("margin_top", int(t))
	m.add_theme_constant_override("margin_right", int(r))
	m.add_theme_constant_override("margin_bottom", int(b))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)
	return m


## Cabecera de pantalla: volver, sobretítulo, título y franja de motivos.
func _header(parent: VBoxContainer, kicker: String, title: String, motif := 0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var back_btn := UiKit.button("‹  VOLVER", false, 150)
	back_btn.pressed.connect(back)
	row.add_child(back_btn)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -6)
	titles.add_child(UiKit.kicker(kicker))
	titles.add_child(UiKit.headline(title, 52))
	row.add_child(titles)
	parent.add_child(row)
	var band := PatternBand.new()
	band.motif = motif
	band.custom_minimum_size = Vector2(0, 12)
	band.color = Color(UiKit.SAND, 0.22)
	parent.add_child(band)


func _clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()


# ------------------------------------------------------------------ menú principal

func _build_main() -> void:
	var s := _screen("main")
	_side_shade(s, 0.62)
	var stripe := PatternBand.new()
	stripe.vertical = true
	stripe.motif = 0
	stripe.color = Color(UiKit.CORAL, 0.55)
	stripe.accent = Color(UiKit.SAND, 0.7)
	stripe.anchor_bottom = 1.0
	stripe.offset_right = 14
	s.add_child(stripe)
	var m := _margin_box(s, MARGIN + 20, 34, MARGIN, 28)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.custom_minimum_size.x = 430
	m.add_child(col)
	col.add_child(UiKit.kicker("Santa Elena · Manabí · Ecuador", UiKit.SUNSET))
	var logo := UiKit.headline("BARRELS", 104, UiKit.SAND)
	logo.add_theme_constant_override("line_spacing", -20)
	col.add_child(logo)
	var sub := UiKit.label("Surf en la costa del Pacífico ecuatoriano", 22, UiKit.TEXT_DIM, UiKit.font_body())
	col.add_child(sub)
	var band := PatternBand.new()
	band.motif = 2
	band.custom_minimum_size = Vector2(0, 16)
	band.color = Color(UiKit.TURQUOISE, 0.6)
	band.accent = Color(UiKit.CORAL, 0.8)
	col.add_child(band)
	col.add_child(UiKit.spacer(4))
	_main_play = UiKit.button("SURFEAR", true, 430)
	_main_play.pressed.connect(func(): play_requested.emit(Ajustes.spot))
	col.add_child(_main_play)
	for entry in [["SPOTS", "spots"], ["SURFISTA Y TABLA", "custom"], ["CARRERA Y LOGROS", "career"], ["AJUSTES", "settings"]]:
		var b := UiKit.button(entry[0], false, 430)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var target: String = entry[1]
		b.pressed.connect(func(): open(target, "main"))
		col.add_child(b)
	col.add_child(UiKit.expand())
	var card := UiKit.panel(Color(UiKit.NIGHT, 0.75), 14, Color(UiKit.SAND, 0.12), 16)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	_main_level = UiKit.label("NIVEL 1", 26, UiKit.GOLD, UiKit.font_display())
	top.add_child(_main_level)
	top.add_child(UiKit.expand())
	_main_xp_text = UiKit.label("", 16, UiKit.TEXT_DIM, UiKit.font_title())
	top.add_child(_main_xp_text)
	cv.add_child(top)
	_main_xp = UiKit.progress(0.0, UiKit.GOLD, 10)
	cv.add_child(_main_xp)
	card.add_child(cv)
	col.add_child(card)
	var credit := UiKit.label("Fuentes Barlow (SIL OFL) · Todo lo demás generado por el juego", 13,
		Color(UiKit.TEXT_DIM, 0.6))
	credit.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.offset_left = -520
	credit.offset_top = -30
	credit.offset_right = -20
	credit.offset_bottom = -8
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.add_child(credit)


func _refresh_main() -> void:
	_main_play.text = "SURFEAR · %s" % (_spot()["name"] as String).to_upper()
	var lvl := Perfil.level()
	_main_level.text = "NIVEL %d" % lvl
	_main_xp.value = Perfil.level_progress()
	_main_xp_text.text = "%s / %s XP" % [UiKit.num(Perfil.xp), UiKit.num(Perfil.xp_for_level(lvl + 1))]


# ------------------------------------------------------------------ spots

func _build_spots() -> void:
	var s := _screen("spots", 0.55)
	var m := _margin_box(s)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	m.add_child(col)
	_header(col, "Costa del Pacífico", "ELIGE TU SPOT", 1)
	col.add_child(UiKit.setting_row("Condiciones de sesión", "Cambian tamaño, espera entre series, marejada y nivel del agua.",
		UiKit.option(["Limpio", "Marea media", "Mar de fondo"], Ajustes.session_condition, func(i):
			Ajustes.session_condition = i
			Ajustes.apply())))
	_spot_cards = HBoxContainer.new()
	_spot_cards.add_theme_constant_override("separation", 20)
	_spot_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_spot_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_spot_cards)


func _refresh_spots() -> void:
	_clear(_spot_cards)
	for i in Spots.LIST.size():
		_spot_cards.add_child(_spot_card(i))


func _spot_card(i: int) -> Control:
	var s: Dictionary = Spots.LIST[i]
	var main: Color = s["ui_main"]
	var current := i == Ajustes.spot
	var card := UiKit.panel(Color(UiKit.NIGHT, 0.9), 18, main if current else Color(main, 0.35), 0)
	(card.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(3 if current else 1)
	card.custom_minimum_size = Vector2(350, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var art := SpotArt.new()
	art.custom_minimum_size = Vector2(0, 150)
	art.set_spot(s)
	art.clip_contents = true
	v.add_child(art)
	var band := PatternBand.new()
	band.motif = s["motif"]
	band.custom_minimum_size = Vector2(0, 14)
	band.color = Color(main, 0.9)
	band.accent = Color(UiKit.SAND, 0.9)
	v.add_child(band)
	var body := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 16 if side != "top" else 12)
	v.add_child(body)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	body.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_child(UiKit.headline((s["name"] as String).to_upper(), 40, main.lightened(0.15)))
	name_row.add_child(UiKit.expand())
	name_row.add_child(UiKit.chip("DERECHA" if s["dir"] < 0.0 else "IZQUIERDA", main))
	info.add_child(name_row)
	info.add_child(UiKit.label(s["zone"], 18, UiKit.TEXT_DIM, UiKit.font_title()))
	var tag := UiKit.label(s["tagline"], 17, UiKit.TEXT)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(tag)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 22)
	stats.add_child(UiKit.stat("%.1f m" % s["height"], "Ola"))
	stats.add_child(UiKit.stat(["", "Fácil", "Media", "Difícil"][s["level"]], "Nivel", main.lightened(0.2)))
	var rec := Perfil.record(s["id"])
	stats.add_child(UiKit.stat(UiKit.num(rec.get("score", 0)) if rec.has("score") else "—", "Récord"))
	info.add_child(stats)
	var done := 0
	for ch in s["challenges"]:
		if Perfil.challenge_is_done(s["id"], ch["id"]):
			done += 1
	var ch_row := HBoxContainer.new()
	ch_row.add_child(UiKit.label("Desafíos", 17, UiKit.TEXT_DIM, UiKit.font_title()))
	ch_row.add_child(UiKit.expand())
	ch_row.add_child(UiKit.label("%d / %d" % [done, s["challenges"].size()], 17, UiKit.SAND, UiKit.font_title()))
	info.add_child(ch_row)
	info.add_child(UiKit.progress(float(done) / s["challenges"].size(), main, 8))
	info.add_child(UiKit.label(s["time"], 15, UiKit.TEXT_DIM))
	info.add_child(UiKit.spacer(4))
	var go := UiKit.button("SURFEAR AQUÍ" if not current else "SURFEAR", current)
	go.pressed.connect(func(): play_requested.emit(i))
	info.add_child(go)
	return card


# ------------------------------------------------------------------ surfista y tabla

func _build_custom() -> void:
	var screen := _screen("custom")
	_side_shade(screen,0.58,0.97)
	var margin := MarginContainer.new()
	margin.anchor_right=0.44
	margin.anchor_bottom=1.0
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,24)
	screen.add_child(margin)
	_customizer=SurfCustomizer.new()
	_customizer.finished.connect(back)
	_customizer.view_changed.connect(func(i): customize_view.emit(i))
	margin.add_child(_customizer)

func _refresh_custom() -> void:
	_customizer.reset_preview()
	_customizer.refresh()


# ------------------------------------------------------------------ carrera

func _build_career() -> void:
	var s := _screen("career", 0.6)
	var m := _margin_box(s)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	m.add_child(col)
	_header(col, "Tu camino en la costa", "CARRERA", 0)
	_career_tabs = UiKit.tabs(["PROGRESO", "RÉCORDS", "LOGROS", "DESAFÍOS"], func(i):
		_career_tab = i
		_refresh_career())
	col.add_child(_career_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_career_body = VBoxContainer.new()
	_career_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_career_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_career_body)


func _refresh_career() -> void:
	_clear(_career_body)
	match _career_tab:
		0:
			_career_progress()
		1:
			_career_records()
		2:
			_career_achievements()
		_:
			_career_challenges()


func _career_progress() -> void:
	var lvl := Perfil.level()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 28)
	var badge := UiKit.panel(Color(UiKit.GOLD, 0.95), 20, Color(UiKit.SAND, 0.8), 18)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", -8)
	bv.add_child(UiKit.label("NIVEL", 18, UiKit.NIGHT, UiKit.font_title()))
	bv.add_child(UiKit.label(str(lvl), 72, UiKit.NIGHT, UiKit.font_display()))
	badge.add_child(bv)
	top.add_child(badge)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(UiKit.label("%s XP" % UiKit.num(Perfil.xp), 30, UiKit.SAND, UiKit.font_title()))
	right.add_child(UiKit.progress(Perfil.level_progress(), UiKit.GOLD, 14))
	right.add_child(UiKit.label("Faltan %s XP para el nivel %d" % [UiKit.num(Perfil.xp_for_level(lvl + 1) - Perfil.xp), lvl + 1],
		17, UiKit.TEXT_DIM))
	top.add_child(right)
	_career_body.add_child(top)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 48)
	stats.add_child(UiKit.stat(str(Perfil.waves_ridden), "Olas de pie"))
	stats.add_child(UiKit.stat(str(Perfil.waves_completed), "Olas completadas"))
	stats.add_child(UiKit.stat("%d m" % int(Perfil.total_distance), "Recorrido total"))
	stats.add_child(UiKit.stat("%d / %d" % [Perfil.achievements.size(), Perfil.ACHIEVEMENTS.size()], "Logros"))
	_career_body.add_child(UiKit.panel(Color(UiKit.NIGHT, 0.6), 14, Color(UiKit.SAND, 0.08), 18))
	_career_body.get_child(_career_body.get_child_count() - 1).add_child(stats)
	_career_body.add_child(UiKit.kicker("Próximos desbloqueos", UiKit.SUNSET))
	var names := {"skin":"Piel", "hair":"Cabello", "wetsuit": "Neopreno", "accent": "Franja", "deck": "Cubierta", "bottom": "Fondo"}
	var any := false
	for slot in Perfil.SLOTS:
		for it in Perfil.SLOTS[slot]:
			if not Perfil.unlocked(it):
				any = true
				var row := HBoxContainer.new()
				row.add_child(UiKit.chip("NIVEL %d" % it["level"], UiKit.GOLD))
				row.add_child(UiKit.label("%s %s" % [names[slot], (it["name"] as String).to_lower()], 19))
				_career_body.add_child(row)
	if not any:
		_career_body.add_child(UiKit.label("Lo tienes todo desbloqueado.", 19, UiKit.OK))
	_career_body.add_child(UiKit.label("Cómo se gana experiencia: puntos ÷ 10, +150 por completar la ola y +200 por cada desafío nuevo.",
		15, UiKit.TEXT_DIM))


func _career_records() -> void:
	for s in Spots.LIST:
		var rec := Perfil.record(s["id"])
		var p := UiKit.panel(Color(UiKit.NIGHT, 0.6), 14, Color(s["ui_main"], 0.5), 16)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 36)
		var nm := VBoxContainer.new()
		nm.custom_minimum_size.x = 260
		nm.add_child(UiKit.label((s["name"] as String).to_upper(), 30, (s["ui_main"] as Color).lightened(0.2), UiKit.font_display()))
		nm.add_child(UiKit.label("Completada" if rec.get("completed", false) else "Sin completar", 15,
			UiKit.OK if rec.get("completed", false) else UiKit.TEXT_DIM))
		row.add_child(nm)
		if rec.is_empty():
			row.add_child(UiKit.label("Todavía no has surfeado aquí.", 19, UiKit.TEXT_DIM))
		else:
			row.add_child(UiKit.stat(UiKit.num(rec.get("score", 0)), "Puntos"))
			row.add_child(UiKit.stat("%d m" % int(rec.get("distance", 0.0)), "Recorrido"))
			row.add_child(UiKit.stat("%.1f s" % rec.get("time", 0.0), "De pie"))
			row.add_child(UiKit.stat("%s km/h" % UiKit.kmh(rec.get("speed", 0.0)), "Velocidad"))
			row.add_child(UiKit.stat("×%d" % rec.get("combo", 1), "Combo"))
		p.add_child(row)
		_career_body.add_child(p)


func _career_achievements() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for a in Perfil.ACHIEVEMENTS:
		var got: bool = Perfil.achievements.has(a["id"])
		var p := UiKit.panel(Color(UiKit.NIGHT, 0.7 if got else 0.45), 14,
			Color(UiKit.GOLD, 0.8) if got else Color(UiKit.SAND, 0.08), 14)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var medal := UiKit.chip("★" if got else "·", UiKit.GOLD if got else Color(UiKit.SAND, 0.15),
			UiKit.NIGHT, 26)
		row.add_child(medal)
		var t := VBoxContainer.new()
		t.add_theme_constant_override("separation", 0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_child(UiKit.label(a["name"], 22, UiKit.SAND if got else UiKit.TEXT_DIM, UiKit.font_title()))
		var d := UiKit.label(a["desc"], 16, UiKit.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.add_child(d)
		row.add_child(t)
		p.add_child(row)
		grid.add_child(p)
	_career_body.add_child(grid)


func _career_challenges() -> void:
	for s in Spots.LIST:
		_career_body.add_child(UiKit.label((s["name"] as String).to_upper(), 28, (s["ui_main"] as Color).lightened(0.2),
			UiKit.font_display()))
		for ch in s["challenges"]:
			var done := Perfil.challenge_is_done(s["id"], ch["id"])
			var row := HBoxContainer.new()
			row.add_child(UiKit.chip("✓" if done else "  ", UiKit.OK if done else Color(UiKit.SAND, 0.15)))
			row.add_child(UiKit.label(ch["text"], 20, UiKit.TEXT if done else UiKit.TEXT_DIM))
			row.add_child(UiKit.expand())
			row.add_child(UiKit.label("+200 XP", 16, UiKit.GOLD if not done else UiKit.TEXT_DIM, UiKit.font_title()))
			_career_body.add_child(row)


# ------------------------------------------------------------------ ajustes

func _build_settings() -> void:
	var s := _screen("settings", 0.62)
	var m := _margin_box(s)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	m.add_child(col)
	_header(col, "Configuración", "AJUSTES", 1)
	_settings_tabs = UiKit.tabs(["GRÁFICOS", "AUDIO", "CONTROLES", "ACCESIBILIDAD"], func(i):
		_settings_tab = i
		_refresh_settings())
	col.add_child(_settings_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var wrap := UiKit.panel(Color(UiKit.NIGHT, 0.7), 16, Color(UiKit.SAND, 0.08), 22)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(wrap)
	_settings_body = VBoxContainer.new()
	_settings_body.add_theme_constant_override("separation", 18)
	wrap.add_child(_settings_body)


func _apply() -> void:
	Ajustes.apply()


## Cambia de pestaña desde código (mando, teclado o pruebas).
func select_tab(screen: String, i: int) -> void:
	Controles.cancel_rebind()
	var bar := _settings_tabs if screen == "settings" else _career_tabs
	(bar.get_child(i) as Button).button_pressed = true
	if screen == "settings":
		_settings_tab = i
		_refresh_settings()
	else:
		_career_tab = i
		_refresh_career()


func _refresh_settings() -> void:
	_clear(_settings_body)
	var b := _settings_body
	match _settings_tab:
		0:
			b.add_child(UiKit.setting_row("Calidad gráfica",
				"Baja: sin sombras ni detalle fino (móviles). Alta: máxima nitidez y sombras suaves.",
				UiKit.option(Ajustes.PRESETS.map(func(p): return p["name"]), Ajustes.quality, func(i): Ajustes.set_quality(i))))
			var fps_values := [30, 60, 0]
			b.add_child(UiKit.setting_row("Límite de FPS", "30 ahorra batería en móviles.",
				UiKit.option(["30", "60", "Sin límite"], maxi(0, fps_values.find(Ajustes.fps_limit)), func(i):
					Ajustes.fps_limit = fps_values[i]
					_apply())))
			b.add_child(UiKit.setting_row("Resolución adaptativa", "Baja la resolución 3D si faltan FPS.",
				UiKit.toggle(Ajustes.adaptive, func(v):
					Ajustes.adaptive = v
					_apply())))
			b.add_child(UiKit.setting_row("Mostrar FPS", "Contador de rendimiento (tecla %s)." % Controles.key_label("toggle_fps"),
				UiKit.toggle(Ajustes.show_fps, func(v):
					Ajustes.show_fps = v
					_apply())))
		1:
			b.add_child(UiKit.setting_row("Volumen general", "",
				UiKit.slider(0.0, 1.0, 0.05, Ajustes.volume, func(v): return "%d %%" % int(round(v * 100.0)), func(v):
					Ajustes.volume = v
					_apply())))
			var note := UiKit.label("Mar de fondo, remadas, rompiente, deslizamiento y caídas. Dentro del tubo el mar suena más grave y amortiguado. Sonidos originales sintetizados para BARRELS.",
				16, UiKit.TEXT_DIM)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_child(note)
		2:
			b.add_child(UiKit.setting_row("Distancia de cámara", "Acerca o aleja la cámara de seguimiento.",
				UiKit.slider(0.75, 1.35, 0.05, Ajustes.camera_distance, func(v): return "%d %%" % int(round(v * 100.0)), func(v):
					Ajustes.camera_distance = v
					_apply())))
			b.add_child(UiKit.setting_row("Sensibilidad de giro", "Afecta al teclado, al joystick táctil y al mando.",
				UiKit.slider(0.5, 1.5, 0.05, Ajustes.steering_sensitivity, func(v): return "%d %%" % int(v * 100), func(v):
					Ajustes.steering_sensitivity = v
					_apply())))
			b.add_child(UiKit.setting_row("Zona muerta del joystick", "Evita giros por pequeños movimientos o deriva del mando.",
				UiKit.slider(0.0, 0.4, 0.01, Ajustes.stick_deadzone, func(v): return "%d %%" % int(v * 100), func(v):
					Ajustes.stick_deadzone = v
					_apply())))
			b.add_child(UiKit.setting_row("Invertir peso adelante/atrás", "Invierte el eje vertical; girar no cambia.",
				UiKit.toggle(Ajustes.invert_weight, func(v):
					Ajustes.invert_weight = v
					_apply())))
			b.add_child(UiKit.setting_row("Controles táctiles", "Auto: aparecen en pantallas táctiles.",
				UiKit.option(Ajustes.TOUCH_MODES, Ajustes.touch_mode, func(i):
					Ajustes.touch_mode = i
					_apply())))
			b.add_child(UiKit.setting_row("Tamaño de los controles táctiles", "",
				UiKit.slider(0.8, 1.4, 0.05, Ajustes.touch_size, func(v): return "%d %%" % int(round(v * 100.0)), func(v):
					Ajustes.touch_size = v
					_apply())))
			b.add_child(UiKit.setting_row("Modo zurdo", "Joystick a la derecha y botones a la izquierda.",
				UiKit.toggle(Ajustes.left_handed, func(v):
					Ajustes.left_handed = v
					_apply())))
			b.add_child(UiKit.setting_row("Remar", "Mantener pulsado o un toque para empezar y otro para parar.",
				UiKit.option(["Mantener", "Alternar"], 1 if Ajustes.paddle_toggle else 0, func(i):
					Ajustes.paddle_toggle = i == 1
					Controles.paddle_latched = false
					_apply())))
			b.add_child(ControlBindings.new())
			var reset := UiKit.button("RESTABLECER CONTROLES")
			reset.pressed.connect(func():
				Controles.reset_controls()
				_refresh_settings())
			b.add_child(reset)
		_:
			b.add_child(UiKit.setting_row("Tamaño de la interfaz", "Agranda textos y botones.",
				UiKit.slider(0.9, 1.3, 0.05, Ajustes.ui_scale, func(v): return "%d %%" % int(round(v * 100.0)), func(v):
					Ajustes.ui_scale = v
					_apply())))
			b.add_child(UiKit.setting_row("Avisos de ayuda", "Consejos en pantalla mientras juegas.",
				UiKit.toggle(Ajustes.show_hints, func(v):
					Ajustes.show_hints = v
					_apply())))
			b.add_child(UiKit.setting_row("Alto contraste", "Fondos opacos y bordes marcados en el marcador.",
				UiKit.toggle(Ajustes.high_contrast, func(v):
					Ajustes.high_contrast = v
					_apply())))
			b.add_child(UiKit.setting_row("Reducir movimiento", "Sin cámara cinematográfica ni animaciones de la interfaz.",
				UiKit.toggle(Ajustes.reduce_motion, func(v):
					Ajustes.reduce_motion = v
					_apply())))


# ------------------------------------------------------------------ pausa

func _build_pause() -> void:
	var s := _screen("pause", 0.62)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(center)
	var p := UiKit.panel(Color(UiKit.NIGHT, 0.92), 20, Color(UiKit.TURQUOISE, 0.35), 28)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size.x = 420
	p.add_child(v)
	_pause_kicker = UiKit.kicker("")
	v.add_child(_pause_kicker)
	v.add_child(UiKit.headline("PAUSA", 72))
	var band := PatternBand.new()
	band.motif = 0
	band.custom_minimum_size = Vector2(0, 12)
	v.add_child(band)
	var resume := UiKit.button("CONTINUAR", true)
	resume.pressed.connect(func(): resume_requested.emit())
	v.add_child(resume)
	for entry in [["REINICIAR OLA", "restart"], ["AJUSTES", "settings"], ["CAMBIAR DE SPOT", "spots"], ["MENÚ PRINCIPAL", "menu"]]:
		var b := UiKit.button(entry[0])
		var what: String = entry[1]
		b.pressed.connect(_pause_action.bind(what))
		v.add_child(b)


func _pause_action(what: String) -> void:
	match what:
		"restart":
			restart_requested.emit()
		"menu":
			menu_requested.emit()
		_:
			open(what, "pause")


# ------------------------------------------------------------------ resultados

func _build_results() -> void:
	var s := _screen("results", 0.55)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(center)
	var p := UiKit.panel(Color(UiKit.NIGHT, 0.94), 22, Color(UiKit.SAND, 0.14), 30)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size.x = 820
	p.add_child(v)
	_res["kicker"] = UiKit.kicker("")
	v.add_child(_res["kicker"])
	var title_row := HBoxContainer.new()
	_res["title"] = UiKit.headline("", 64)
	title_row.add_child(_res["title"])
	title_row.add_child(UiKit.expand())
	_res["record"] = UiKit.chip("NUEVO RÉCORD", UiKit.GOLD, UiKit.NIGHT, 20)
	title_row.add_child(_res["record"])
	v.add_child(title_row)
	_res["detail"] = UiKit.label("", 19, UiKit.TEXT_DIM)
	_res["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_res["detail"])
	var band := PatternBand.new()
	band.motif = 2
	band.custom_minimum_size = Vector2(0, 12)
	v.add_child(band)
	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 40)
	var sc := VBoxContainer.new()
	sc.add_theme_constant_override("separation", -10)
	sc.add_child(UiKit.label("PUNTOS", 16, UiKit.TEXT_DIM, UiKit.font_title()))
	_res["score"] = UiKit.label("0", 84, UiKit.SAND, UiKit.font_display())
	sc.add_child(_res["score"])
	score_row.add_child(sc)
	_res["stats"] = HBoxContainer.new()
	_res["stats"].add_theme_constant_override("separation", 30)
	_res["stats"].alignment = BoxContainer.ALIGNMENT_END
	_res["stats"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_row.add_child(_res["stats"])
	v.add_child(score_row)
	var xp_row := HBoxContainer.new()
	_res["xp"] = UiKit.label("", 22, UiKit.GOLD, UiKit.font_title())
	xp_row.add_child(_res["xp"])
	xp_row.add_child(UiKit.expand())
	_res["level"] = UiKit.label("", 20, UiKit.SAND, UiKit.font_title())
	xp_row.add_child(_res["level"])
	v.add_child(xp_row)
	_res["bar"] = UiKit.progress(0.0, UiKit.GOLD, 12)
	v.add_child(_res["bar"])
	_res["gains"] = VBoxContainer.new()
	_res["gains"].add_theme_constant_override("separation", 4)
	v.add_child(_res["gains"])
	v.add_child(UiKit.spacer(6))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	var again := UiKit.button("OTRA OLA", true)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): restart_requested.emit())
	btns.add_child(again)
	var spots := UiKit.button("CAMBIAR DE SPOT")
	spots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spots.pressed.connect(func(): open("spots", "main"))
	btns.add_child(spots)
	var menu := UiKit.button("MENÚ")
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func(): menu_requested.emit())
	btns.add_child(menu)
	v.add_child(btns)


## stats: success, score, time, distance, speed, combo, pocket. gains: lo que devuelve Perfil.record_ride().
func show_results(title: String, detail: String, stats: Dictionary, gains: Dictionary) -> void:
	var s := _spot()
	_res["kicker"].text = _spot_name().to_upper()
	_res["title"].text = title.to_upper()
	_res["title"].add_theme_color_override("font_color", UiKit.OK.lightened(0.2) if stats["success"] else UiKit.CORAL)
	_res["detail"].text = detail
	_res["record"].visible = gains["new_record"]
	_clear(_res["stats"])
	_res["stats"].add_child(UiKit.stat("%.1f s" % stats["time"], "De pie"))
	_res["stats"].add_child(UiKit.stat("%d m" % int(stats["distance"]), "Recorrido"))
	_res["stats"].add_child(UiKit.stat("%s km/h" % UiKit.kmh(stats["speed"]), "Vel. máx."))
	_res["stats"].add_child(UiKit.stat("×%d" % stats["combo"], "Combo", s["ui_main"]))
	_res["stats"].add_child(UiKit.stat("%.1f s" % stats["pocket"], "Pocket"))
	_res["stats"].add_child(UiKit.stat("%.1f s / %d" % [stats.get("tube_time", 0.0), stats.get("tube_exits", 0)], "Tubo / salidas"))
	_res["xp"].text = "+%s XP" % UiKit.num(gains["xp"])
	var lvl := Perfil.level()
	_res["level"].text = "NIVEL %d%s" % [lvl, "  ·  ¡SUBISTE DE NIVEL!" if gains["level_after"] > gains["level_before"] else ""]
	_clear(_res["gains"])
	for t in gains["challenges"]:
		var row := HBoxContainer.new()
		row.add_child(UiKit.chip("DESAFÍO", s["ui_main"]))
		row.add_child(UiKit.label("%s  ·  +200 XP" % t, 19))
		_res["gains"].add_child(row)
	for t in gains["achievements"]:
		var row := HBoxContainer.new()
		row.add_child(UiKit.chip("★ LOGRO", UiKit.GOLD))
		row.add_child(UiKit.label(t, 19))
		_res["gains"].add_child(row)
	open("results")
	# Cifras que suben (se saltan con "reducir movimiento").
	var target: int = stats["score"]
	var bar: ProgressBar = _res["bar"]
	if Ajustes.reduce_motion:
		_res["score"].text = UiKit.num(target)
		bar.value = Perfil.level_progress()
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x): _res["score"].text = UiKit.num(int(x)), 0.0, float(target), 1.1)
	bar.value = 0.0 if gains["level_after"] > gains["level_before"] else maxf(0.0, Perfil.level_progress() - 0.25)
	tw.tween_property(bar, "value", Perfil.level_progress(), 1.0).set_delay(0.3)
