class_name Hud
extends Control
## Marcador de juego: spot, puntuación y combo, avisos de maniobras, velocidad,
## desafíos del spot en vivo, barra de equilibrio, aviso «¡PÁRATE!» y botón de pausa.
## Los menús (pausa, resultados, ajustes...) están en Menus.

signal pause_pressed

var _spot: Dictionary
var _spot_chip: PanelContainer
var _spot_name: Label
var _score: Label
var _combo: PanelContainer
var _combo_label: Label
var _speed: Label
var _speed_unit: Label
var _sub: Label
var _hint: Label
var _hint_panel: PanelContainer
var _prompt: Label
var _fps: Label
var _challenges: VBoxContainer
var _ch_rows := []
var _popups: Control
var _pause_btn: Button
var _top_right: PanelContainer
var _hint_time := 0.0
var _balance := 0.0
var _show_balance := false
var _time := 0.0
var _fps_acc := 0.0
var _fps_frames := 0
var _fps_text := ""
var _last_combo := 1
var _playing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()

	# Spot (arriba a la izquierda).
	_spot_chip = UiKit.panel(Color(UiKit.NIGHT, 0.55), 12, Color(0, 0, 0, 0), 10)
	_spot_chip.position = Vector2(18, 14)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	_spot_name = UiKit.label("", 20, UiKit.SAND, UiKit.font_display())
	sv.add_child(_spot_name)
	var band := PatternBand.new()
	band.name = "Band"
	band.custom_minimum_size = Vector2(150, 8)
	sv.add_child(band)
	_spot_chip.add_child(sv)
	add_child(_spot_chip)

	_fps = UiKit.label("", 15, Color(0.7, 1, 0.7))
	_fps.position = Vector2(20, 84)
	add_child(_fps)

	# Puntuación y combo (arriba, centrado).
	var top := VBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", -6)
	_place(top, 0.5, 0.5, -200, 8, 200, 150)
	_score = UiKit.headline("0", 58, UiKit.SAND)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_score)
	var combo_center := CenterContainer.new()
	_combo = UiKit.chip("×2 COMBO", UiKit.CORAL, UiKit.NIGHT, 22)
	_combo_label = _combo.get_child(0)
	_combo_label.add_theme_font_override("font", UiKit.font_display())
	_combo.visible = false
	combo_center.add_child(_combo)
	top.add_child(combo_center)
	add_child(top)

	# Velocidad y estado (arriba a la derecha, bajo el botón de pausa).
	_top_right = UiKit.panel(Color(UiKit.NIGHT, 0.5), 12, Color(0, 0, 0, 0), 12)
	_place(_top_right, 1.0, 1.0, -250, 72, -18, 160)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", -4)
	var sp := HBoxContainer.new()
	sp.alignment = BoxContainer.ALIGNMENT_END
	_speed = UiKit.label("0", 44, UiKit.SAND, UiKit.font_display())
	sp.add_child(_speed)
	_speed_unit = UiKit.label("KM/H", 16, UiKit.TEXT_DIM, UiKit.font_title())
	_speed_unit.size_flags_vertical = Control.SIZE_SHRINK_END
	sp.add_child(_speed_unit)
	rv.add_child(sp)
	_sub = UiKit.label("", 17, UiKit.TEXT_DIM, UiKit.font_title())
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(_sub)
	_top_right.add_child(rv)
	add_child(_top_right)

	# Desafíos del spot (a la derecha).
	var chp := UiKit.panel(Color(UiKit.NIGHT, 0.5), 12, Color(0, 0, 0, 0), 12)
	chp.name = "ChallengesPanel"
	_place(chp, 1.0, 1.0, -300, 176, -18, 330)
	_challenges = VBoxContainer.new()
	_challenges.add_theme_constant_override("separation", 6)
	chp.add_child(_challenges)
	add_child(chp)

	# Avisos de maniobras que suben y se desvanecen.
	_popups = Control.new()
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_popups, 0.5, 0.5, -1, 150, 1, 151)
	add_child(_popups)

	# Ayuda (abajo, sobre la barra de equilibrio).
	_hint_panel = UiKit.panel(Color(UiKit.NIGHT, 0.6), 12, Color(UiKit.TURQUOISE, 0.35), 12)
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_left = -360
	_hint_panel.offset_right = 360
	_hint_panel.offset_top = -170
	_hint_panel.offset_bottom = -96
	_hint = UiKit.label("", 21, UiKit.TEXT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(_hint)
	add_child(_hint_panel)

	_prompt = UiKit.headline("¡PÁRATE!", 86, UiKit.CORAL)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_place(_prompt, 0.5, 0.5, -300, -150, 300, -40)
	_prompt.visible = false
	add_child(_prompt)

	_pause_btn = Button.new()
	_pause_btn.text = "II"
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.add_theme_font_override("font", UiKit.font_display())
	_pause_btn.add_theme_font_size_override("font_size", 26)
	add_child(_pause_btn)
	_place(_pause_btn, 1.0, 1.0, -80, 12, -18, 62)
	_pause_btn.pressed.connect(func(): pause_pressed.emit())

	Ajustes.changed.connect(_apply_contrast)
	_apply_contrast()
	set_playing(false)


func _place(c: Control, al: float, ar: float, left: float, top: float, right: float, bottom: float) -> void:
	c.anchor_left = al
	c.anchor_right = ar
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom


## Alto contraste: fondos opacos y bordes marcados.
func _apply_contrast() -> void:
	var hc := Ajustes.high_contrast
	for p in [_spot_chip, _top_right, get_node("ChallengesPanel"), _hint_panel]:
		var sb := UiKit.box(Color(UiKit.NIGHT, 0.95 if hc else 0.52), 12, Color(UiKit.SAND, 0.9 if hc else 0.0),
			2 if hc else 0, 12 if p != _spot_chip else 10)
		(p as PanelContainer).add_theme_stylebox_override("panel", sb)


func set_playing(on: bool) -> void:
	_playing = on
	visible = on


func set_spot(s: Dictionary) -> void:
	_spot = s
	_spot_name.text = "%s · %s" % [(s["name"] as String).to_upper(), s["zone"]]
	var band: PatternBand = _spot_chip.find_child("Band", true, false)
	band.motif = s["motif"]
	band.color = Color(s["ui_main"], 0.9)
	band.accent = Color(UiKit.SAND, 0.9)
	band.queue_redraw()
	for c in _challenges.get_children():
		c.queue_free()
	_ch_rows.clear()
	_challenges.add_child(UiKit.label("DESAFÍOS", 14, (s["ui_main"] as Color).lightened(0.2), UiKit.font_title()))
	for ch in s["challenges"]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var line := HBoxContainer.new()
		var mark := UiKit.label("○", 17, UiKit.TEXT_DIM, UiKit.font_title())
		line.add_child(mark)
		var txt := UiKit.label(ch["text"], 17, UiKit.TEXT, UiKit.font_title())
		line.add_child(txt)
		row.add_child(line)
		var bar := UiKit.progress(0.0, s["ui_main"], 5)
		row.add_child(bar)
		_challenges.add_child(row)
		_ch_rows.append({"ch": ch, "mark": mark, "text": txt, "bar": bar})


func show_hint(text: String, seconds := 4.0) -> void:
	if not Ajustes.show_hints:
		return
	_hint.text = text
	_hint_time = seconds


## Aviso de maniobra que sube desde el centro y se desvanece.
func popup(text: String, points: int) -> void:
	if not _playing:
		return
	var l := UiKit.headline(text + ("  +%s" % UiKit.num(points) if points > 0 else ""), 34,
		UiKit.GOLD if points >= 1000 else UiKit.SAND)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(-300, 0)
	l.size = Vector2(600, 50)
	_popups.add_child(l)
	if Ajustes.reduce_motion:
		get_tree().create_timer(1.2).timeout.connect(l.queue_free)
		return
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", -70.0, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.chain().tween_callback(l.queue_free)


func update_state(surfer: Surfer, wave: WaveModel, score: ScoreKeeper, delta: float) -> void:
	_time += delta
	_hint_time -= delta
	_hint_panel.visible = _hint_time > 0.0 and Ajustes.show_hints
	_prompt.visible = surfer.can_stand and surfer.state == Surfer.State.PRONE
	_prompt.modulate.a = 0.65 + 0.35 * sin(_time * 12.0)
	_show_balance = surfer.state == Surfer.State.RIDING
	_balance = surfer.balance

	_score.text = UiKit.num(score.score)
	_combo.visible = score.combo > 1
	if score.combo > 1:
		_combo_label.text = "×%d COMBO" % score.combo
		if score.combo != _last_combo and not Ajustes.reduce_motion:
			_combo.pivot_offset = _combo.size * 0.5
			_combo.scale = Vector2.ONE * 1.35
			_combo.create_tween().tween_property(_combo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_last_combo = score.combo

	_speed.text = UiKit.kmh(surfer.speed())
	if surfer.state == Surfer.State.PRONE:
		var gap := surfer.global_position.z - wave.crest_z
		_sub.text = "OLA A %d m" % int(gap) if gap > 0.0 and wave.amp > 0.3 else "ESPERANDO OLA"
	elif surfer.is_riding():
		_sub.text = "TUBO %.1f s · BUSCA LA SALIDA" % surfer.tube_seconds if surfer.in_tube else "DE PIE %.1f s · TUBOS %d" % [surfer.ride_time, surfer.tube_exits]
	else:
		_sub.text = ""

	for r in _ch_rows:
		var ch: Dictionary = r["ch"]
		var done_before := Perfil.challenge_is_done(_spot["id"], ch["id"])
		var p := 0.0
		match ch["type"]:
			"score":
				p = score.score / float(ch["value"])
			"combo":
				p = score.best_combo / float(ch["value"])
			"speed":
				p = score.top_speed * 3.6 / float(ch["value"])
			"distance":
				p = score.distance / float(ch["value"])
			"pocket":
				p = score.pocket_time / float(ch["value"])
			"complete":
				p = clampf((wave.crest_z + 37.0) / (Game.FINISH_Z + 37.0), 0.0, 1.0) if surfer.is_riding() else 0.0
		p = clampf(p, 0.0, 1.0)
		var met: bool = done_before or (p >= 1.0 and ch["type"] != "complete")
		(r["bar"] as ProgressBar).value = 1.0 if done_before else p
		(r["mark"] as Label).text = "✓" if met else "○"
		(r["mark"] as Label).add_theme_color_override("font_color", UiKit.OK if met else UiKit.TEXT_DIM)
		(r["text"] as Label).add_theme_color_override("font_color", UiKit.TEXT_DIM if done_before else UiKit.TEXT)

	_fps_acc += delta
	_fps_frames += 1
	if _fps_acc >= 0.5:
		var vp := get_viewport()
		_fps_text = "%d FPS · %.1f ms · %s · escala %.2f · %d draw calls" % [
			Engine.get_frames_per_second(), 1000.0 * _fps_acc / _fps_frames, Ajustes.preset()["name"],
			vp.scaling_3d_scale,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
		_fps_acc = 0.0
		_fps_frames = 0
	_fps.visible = Ajustes.show_fps
	_fps.text = _fps_text
	queue_redraw()


## Barra de equilibrio: zona segura en turquesa, peligro en coral y marcador de arena.
func _draw() -> void:
	if not _show_balance:
		return
	var w := minf(size.x * 0.42, 460.0)
	var h := 14.0
	var c := Vector2(size.x * 0.5, size.y - 54.0)
	var r := Rect2(c - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	var hc := Ajustes.high_contrast
	draw_rect(r.grow(6.0), Color(UiKit.NIGHT, 0.9 if hc else 0.55))
	var danger := Color(UiKit.CORAL, 0.75)
	var safe := Color(UiKit.TURQUOISE, 0.75)
	var seg := 40
	for i in seg:
		var t0 := float(i) / seg
		var x := lerpf(-1.2, 1.2, t0 + 0.5 / seg)
		var col := safe.lerp(danger, clampf((absf(x) - 0.55) / 0.45, 0.0, 1.0))
		draw_rect(Rect2(r.position + Vector2(w * t0, 0), Vector2(w / seg + 0.5, h)), col)
	var mx := c.x + clampf(_balance, -1.2, 1.2) / 1.2 * w * 0.5
	var alarm := absf(_balance) > 0.8
	var mk := Rect2(Vector2(mx - 5, c.y - h - 2), Vector2(10, h * 2 + 4))
	draw_rect(mk.grow(2.0), UiKit.NIGHT)
	draw_rect(mk, UiKit.CORAL if alarm and fmod(_time, 0.3) < 0.15 else UiKit.SAND)
	var f := UiKit.font_title()
	for item in [[Vector2(r.position.x - 62, c.y + 7), "COLA"], [Vector2(r.end.x + 12, c.y + 7), "PUNTA"]]:
		draw_string_outline(f, item[0], item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 6, Color(UiKit.NIGHT, 0.85))
		draw_string(f, item[0], item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UiKit.SAND)


func reset_ride_feedback() -> void:
	for child in _popups.get_children():
		child.queue_free()
