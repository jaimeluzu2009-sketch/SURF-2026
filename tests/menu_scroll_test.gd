extends Node
## --qa --menu-scroll-test: arrastrar el dedo sobre un botón de un menú con scroll
## debe desplazar la lista y NO activar el botón; un toque corto sí lo activa.
var game: Game
var failures: Array[String] = []


func _ready() -> void:
	game = get_parent()
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("[menu-scroll] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func frames(n := 3) -> void:
	for i in n: await get_tree().process_frame


func touch(pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await frames(2)


func drag(from: Vector2, to: Vector2, steps := 12) -> void:
	for i in range(1, steps + 1):
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = from.lerp(to, float(i) / steps)
		ev.relative = (to - from) / steps
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await frames(1)


func find_scroll(n: Node) -> ScrollContainer:
	for c in n.get_children():
		if c is ScrollContainer and (c as Control).is_visible_in_tree(): return c
		var r := find_scroll(c)
		if r: return r
	return null


func first_button(n: Node, rect: Rect2) -> Button:
	for c in n.get_children():
		if c is Button and (c as Control).is_visible_in_tree() and rect.encloses((c as Control).get_global_rect()): return c
		var r := first_button(c, rect)
		if r: return r
	return null


func to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func run() -> void:
	Ajustes.persist = false
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	await frames(5)
	for spec in [["settings", 2], ["settings", 0], ["career", 1]]:
		game.menus.open(spec[0])
		game.menus.select_tab(spec[0], spec[1])
		await frames(6)
		var scroll := find_scroll(game.menus)
		check(scroll != null, "%s/%d tiene ScrollContainer visible" % spec)
		if scroll == null: continue
		var bar := scroll.get_v_scroll_bar()
		if bar.max_value - bar.page <= 1.0:
			print("[menu-scroll] %s/%d cabe sin scroll (max %.0f, page %.0f)" % [spec[0], spec[1], bar.max_value, bar.page])
			continue
		var r := scroll.get_global_rect()
		var b := first_button(scroll, r)
		var start := b.get_global_rect().get_center() if b else r.get_center()
		start.y = clampf(start.y, r.position.y + 60, r.end.y - 40)
		print("[menu-scroll] %s/%d rect %s max %.0f page %.0f boton %s inicio %s" % [spec[0], spec[1], r, bar.max_value, bar.page, b.text if b else "-", start])
		var fired := [0]
		var cb := func(): fired[0] += 1
		if b: b.pressed.connect(cb)
		scroll.scroll_vertical = 0
		await frames(2)
		await touch(to_screen(start), true)
		await drag(to_screen(start), to_screen(start - Vector2(0, 260)))
		await touch(to_screen(start - Vector2(0, 260)), false)
		await frames(20)
		var moved := scroll.scroll_vertical
		check(moved >= mini(150, int(bar.max_value - bar.page) - 2),"%s/%d arrastre desplaza la lista (scroll %d)" % [spec[0], spec[1], moved])
		check(fired[0] == 0, "%s/%d el botón bajo el dedo no se activa al arrastrar" % spec)
		await drag(to_screen(start - Vector2(0, 260)), to_screen(start)) # sin dedo: no debe mover
		await frames(4)
		check(absi(scroll.scroll_vertical - moved) < 40, "%s/%d sin pulsar no se mueve" % spec)
		if b: b.pressed.disconnect(cb)
	# Un toque corto debe seguir pulsando botones.
	game.menus.open("settings")
	game.menus.select_tab("settings", 2)
	await frames(6)
	var scroll2 := find_scroll(game.menus)
	scroll2.scroll_vertical = 0
	await frames(3)
	var btn := first_button(scroll2, scroll2.get_global_rect())
	if btn:
		var hits := [0]
		var cb2 := func(): hits[0] += 1
		btn.pressed.connect(cb2)
		var p := to_screen(btn.get_global_rect().get_center())
		await touch(p, true)
		await touch(p, false)
		check(hits[0] == 1, "toque corto activa el botón '%s'" % btn.text)
		btn.pressed.disconnect(cb2)
	print("[menu-scroll] RESULTADO ", "OK" if failures.is_empty() else "FALLOS: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
