extends Node
var failures: Array[String] = []
func check(ok: bool, label_text: String) -> void:
	print("[controls] ", "OK " if ok else "FAIL ", label_text)
	if not ok:
		failures.append(label_text)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var g: Game = get_parent()
	Ajustes.persist = false
	Controles.reset_controls()
	check(Controles.rebind("surf_stand", KEY_D) != "", "rechaza teclas en conflicto")
	check(Controles.rebind("surf_stand", KEY_ESCAPE) != "", "Esc queda reservado")
	check(Controles.rebind("surf_stand", KEY_K) == "", "reasigna pararse a K")
	check(InputMap.action_has_event("surf_stand", key(KEY_K)), "InputMap usa K")
	check(not InputMap.action_has_event("surf_stand", key(KEY_E)), "elimina tecla anterior")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	check(InputMap.action_has_event("surf_stand", pad), "mantiene botón del mando")
	check(Controles.rebind("surf_pause", KEY_O) == "" and InputMap.action_has_event("surf_pause", key(KEY_ESCAPE)), "pausa conserva Esc")
	Ajustes.key_bindings = {"surf_stand": KEY_K, "unknown": KEY_G, "surf_left": "bad"}
	Controles.apply_bindings()
	check(Ajustes.key_bindings.size() == 1 and InputMap.action_has_event("surf_stand", key(KEY_K)), "recarga y filtra mapa guardado")
	Ajustes.key_bindings = {"surf_left": KEY_D, "surf_right": KEY_A, "surf_stand": KEY_K}
	Controles.apply_bindings()
	check(InputMap.action_has_event("surf_left", key(KEY_D)) and InputMap.action_has_event("surf_right", key(KEY_A)), "intercambio de teclas sobrevive recarga")
	Ajustes.steering_sensitivity = 1.35
	Ajustes.persist = true
	Ajustes._save()
	Ajustes.steering_sensitivity = 1.0
	Ajustes.key_bindings.clear()
	Ajustes._load()
	Ajustes.persist = false
	Controles.apply_bindings()
	check(is_equal_approx(Ajustes.steering_sensitivity, 1.35) and Ajustes.key_bindings.get("surf_stand") == KEY_K, "guardado y recarga reales en archivo de prueba aislado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.config_path()))
	check(Controles.filter_stick(Vector2(0.1, 0)).is_zero_approx(), "zona muerta evita deriva")
	check(is_equal_approx(Controles.filter_stick(Vector2(0.575, 0)).x, 0.5), "salida analógica gradual")
	check(is_equal_approx(Controles.filter_stick(Vector2.ONE).length(), 1.0), "diagonal limitada")
	Input.parse_input_event(key(KEY_A, true))
	Input.flush_buffered_events()
	check(Controles.stick().x > 0.99, "teclado digital mantiene respuesta completa")
	Input.parse_input_event(key(KEY_A, false))
	Input.flush_buffered_events()
	Controles.touch_stick = Vector2(0.1, 0.0)
	check(Controles.stick().is_zero_approx(), "zona muerta también funciona en táctil")
	Controles.touch_stick = Vector2(1.0, 0.0)
	check(Controles.stick().x > 0.99, "táctil conserva recorrido completo")
	Controles.touch_stick = Vector2.ZERO
	g.menus.open("settings", "main")
	g.menus.select_tab("settings", 2)
	Controles.begin_rebind("surf_stand")
	Input.parse_input_event(key(KEY_Z, true))
	Input.flush_buffered_events()
	await get_tree().process_frame
	Input.parse_input_event(key(KEY_Z, false))
	check(Controles.capture_action == "" and InputMap.action_has_event("surf_stand", key(KEY_Z)), "captura evento de teclado real")
	Controles.begin_rebind("surf_stand")
	Input.parse_input_event(key(KEY_ESCAPE, true))
	Input.flush_buffered_events()
	await get_tree().process_frame
	Input.parse_input_event(key(KEY_ESCAPE, false))
	check(Controles.capture_action == "" and InputMap.action_has_event("surf_stand", key(KEY_Z)), "Esc cancela sin cambiar asignación")
	Controles.begin_rebind("surf_paddle")
	g.menus.select_tab("settings", 0)
	check(Controles.capture_action == "", "salir de pestaña cancela captura")
	Ajustes.steering_sensitivity = 1.4
	Ajustes.left_handed = true
	Controles.paddle_latched = true
	Controles.reset_controls()
	check(is_equal_approx(Ajustes.steering_sensitivity, 1.0) and not Ajustes.left_handed and not Controles.paddle_latched, "restablece valores y remada")
	check(InputMap.action_has_event("surf_stand", key(KEY_E)), "restaura E y controles originales")
	if "--capture" in OS.get_cmdline_user_args():
		g.menus.select_tab("settings", 2)
		for i in 8:
			await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://capturas/controles")
		get_viewport().get_texture().get_image().save_png("res://capturas/controles/ajustes.png")
	if "--capture" in OS.get_cmdline_user_args():
		var bindings := g.menus._settings_body.find_child("*", true, false)
		for node in g.menus._settings_body.get_children():
			if node is ControlBindings:
				var scroll := node.get_parent()
				while scroll != null and not (scroll is ScrollContainer):
					scroll = scroll.get_parent()
				if scroll != null:
					scroll.ensure_control_visible(node)
		for i in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://capturas/controles/teclas.png")
	print("[controls] RESULTADO: ", "OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func key(code: int, pressed := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	return ev
