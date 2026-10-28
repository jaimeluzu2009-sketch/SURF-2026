extends Node
## Recorre las pantallas y guarda capturas (revisión visual de la interfaz).
##   godot --path . -- --ui-shots=CARPETA [--spot=N]
## Juega una ola real con el piloto del bot para capturar el HUD, la pausa y los resultados.

var game: Game
var dir := ""


func setup(g: Game, args: PackedStringArray) -> void:
	game = g
	Ajustes.persist = false
	for a in args:
		if a.begins_with("--ui-shots="):
			dir = a.get_slice("=", 1)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(2.5)
	await _shot("01_menu")
	game.menus.open("spots", "main")
	await _wait(0.8)
	await _shot("02_spots")
	game.menus.open("custom", "main")
	await _wait(1.8)
	await _shot("03_surfista")
	game.menus.open("career", "main")
	await _wait(0.6)
	await _shot("04_carrera")
	game.menus.select_tab("career", 2)
	await _wait(0.4)
	await _shot("05_logros")
	game.menus.open("settings", "main")
	await _wait(0.5)
	await _shot("06_ajustes_graficos")
	game.menus.select_tab("settings", 2)
	await _wait(0.4)
	await _shot("07_ajustes_controles")
	game.menus.select_tab("settings", 3)
	await _wait(0.4)
	await _shot("08_ajustes_accesibilidad")

	game.start_play()
	var pilot: Node = load("res://tests/bot.gd").new()
	pilot.name = "AutoPilot"
	pilot.setup(game, PackedStringArray())
	game.surfer.ride_ended.disconnect(pilot._on_end)
	game.add_child(pilot)
	while game.surfer.ride_time < 4.0:
		await get_tree().process_frame
	await _shot("09_hud")
	game.pause()
	await _wait(0.6)
	await _shot("10_pausa")
	game.resume()
	while game.mode != Game.Mode.RESULTS:
		await get_tree().process_frame
	await _wait(2.0)
	await _shot("11_resultados")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
