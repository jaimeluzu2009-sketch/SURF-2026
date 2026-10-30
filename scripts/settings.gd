extends Node
## Autoload "Ajustes": calidad gráfica, límite de FPS, controles táctiles.
## Se guardan en user://ajustes.cfg.

signal changed

const PATH := "user://ajustes.cfg"
const PRESETS := [
	{"name": "Baja", "water_grid": 136, "shadows": false, "shadow_size": 1024, "msaa": Viewport.MSAA_DISABLED,
		"scale": 0.7, "particles": 0.35, "detail": false, "water_detail": 0, "wake_points": 6, "glow": false, "far": 700.0, "scenery": 0},
	{"name": "Media", "water_grid": 152, "shadows": true, "shadow_size": 2048, "msaa": Viewport.MSAA_DISABLED,
		"scale": 0.85, "particles": 0.7, "detail": true, "water_detail": 1, "wake_points": 10, "glow": false, "far": 900.0, "scenery": 1},
	{"name": "Alta", "water_grid": 196, "shadows": true, "shadow_size": 4096, "msaa": Viewport.MSAA_4X,
		"scale": 1.0, "particles": 1.0, "detail": true, "water_detail": 2, "wake_points": 12, "glow": true, "far": 1200.0, "scenery": 2},
]
const TOUCH_MODES := ["Auto", "Siempre", "Nunca"]

var quality := 1
var fps_limit := 60
var show_fps := false
var touch_mode := 0
var adaptive := true
## Audio (bus Master, 0-1). El juego todavía no tiene sonidos, pero el control es real.
var volume := 0.8
var session_condition := 1
## Controles
var touch_size := 1.0         ## Tamaño de los controles táctiles (0.8-1.4)
var left_handed := false      ## Joystick a la derecha y botones a la izquierda
var camera_distance := 1.0    ## Distancia de seguimiento (0.75-1.35)
var steering_sensitivity := 1.0
var stick_deadzone := 0.15
var invert_weight := false
var key_bindings: Dictionary = {}
var paddle_toggle := false    ## Remar: true = un toque activa/desactiva, false = mantener
## Accesibilidad
var ui_scale := 1.0           ## Escala de toda la interfaz (0.9-1.3)
var show_hints := true        ## Avisos de ayuda en pantalla
var high_contrast := false    ## HUD con fondos opacos y bordes marcados
var reduce_motion := false    ## Sin cámara cinematográfica ni animaciones de interfaz
## Último spot elegido (índice en Spots.LIST).
var spot := 0
## Se pone a true justo antes de recargar la escena al cambiar de spot.
var skip_menu := false
## Las pruebas automáticas lo ponen a false para no tocar los ajustes guardados.
var persist := true
## Escala de render actual (la baja la resolución adaptativa si faltan FPS).
var render_scale := 1.0

var _acc_time := 0.0
var _acc_frames := 0
var _slow_windows := 0
var _fast_windows := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	persist = not ("--bot" in OS.get_cmdline_user_args() or "--qa" in OS.get_cmdline_user_args())
	_defaults()
	if persist:
		_load()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--condition="):
			session_condition = clampi(int(a.get_slice("=", 1)), 0, 2)
	apply()


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _defaults() -> void:
	if is_mobile():
		quality = 0
		fps_limit = 30
	elif OS.has_feature("web"):
		quality = 1
		fps_limit = 60
	else:
		quality = 2
		fps_limit = 60


func preset() -> Dictionary:
	return PRESETS[quality]


func touch_enabled() -> bool:
	match touch_mode:
		1:
			return true
		2:
			return false
	return is_mobile() or DisplayServer.is_touchscreen_available()


func set_quality(q: int) -> void:
	quality = clampi(q, 0, PRESETS.size() - 1)
	apply()


func apply() -> void:
	var p := preset()
	var vp := get_viewport()
	render_scale = p["scale"]
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = render_scale
	vp.msaa_3d = p["msaa"]
	Engine.max_fps = fps_limit
	RenderingServer.directional_shadow_atlas_set_size(p["shadow_size"], true)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	get_window().content_scale_factor = ui_scale
	_slow_windows = 0
	changed.emit()
	_save()


func _process(delta: float) -> void:
	# Resolución adaptativa: si durante 3 ventanas de 2 s seguidas no llega al
	# 85 % del objetivo, baja la escala de render (mínimo 0.5); si va sobrada
	# durante 5 ventanas, la vuelve a subir hasta la del preset.
	if not adaptive or Engine.max_fps == 0:
		return
	# Un fotograma de más de 0.25 s es una pausa o una pestaña en segundo plano
	# (el navegador frena la página): no cuenta como falta de rendimiento.
	if delta > 0.25 or not get_window().has_focus():
		_acc_time = 0.0
		_acc_frames = 0
		return
	_acc_time += delta
	_acc_frames += 1
	if _acc_time < 2.0:
		return
	var fps := _acc_frames / _acc_time
	_acc_time = 0.0
	_acc_frames = 0
	# Una ventana enfocada a menos de 10 FPS sí debe reducir resolución.
	var vp := get_viewport()
	if fps < fps_limit * 0.85:
		_slow_windows += 1
		_fast_windows = 0
	elif fps >= fps_limit * 0.97:
		_fast_windows += 1
		_slow_windows = 0
	if _slow_windows >= 3 and render_scale > 0.5:
		render_scale = maxf(0.5, render_scale - 0.1)
		vp.scaling_3d_scale = render_scale
		_slow_windows = 0
	elif _fast_windows >= 5 and render_scale < preset()["scale"]:
		render_scale = minf(preset()["scale"], render_scale + 0.05)
		vp.scaling_3d_scale = render_scale
		_fast_windows = 0


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path()) != OK:
		return
	quality = clampi(cfg.get_value("video", "calidad", quality), 0, PRESETS.size() - 1)
	fps_limit = cfg.get_value("video", "fps", fps_limit)
	show_fps = cfg.get_value("video", "mostrar_fps", show_fps)
	adaptive = cfg.get_value("video", "adaptativa", adaptive)
	touch_mode = cfg.get_value("controles", "tactiles", touch_mode)
	spot = cfg.get_value("juego", "spot", spot)
	volume = cfg.get_value("audio", "volumen", volume)
	session_condition = clampi(cfg.get_value("juego", "condicion", 1), 0, 2)
	touch_size = cfg.get_value("controles", "tamano", touch_size)
	steering_sensitivity = clampf(float(cfg.get_value("controles", "sensibilidad", 1.0)), 0.5, 1.5)
	camera_distance = clampf(float(cfg.get_value("controles", "distancia_camara", 1.0)), 0.75, 1.35)
	stick_deadzone = clampf(float(cfg.get_value("controles", "zona_muerta", 0.15)), 0.0, 0.4)
	invert_weight = bool(cfg.get_value("controles", "invertir_peso", false))
	var saved_bindings: Variant = cfg.get_value("controles", "teclas", {})
	key_bindings = saved_bindings if saved_bindings is Dictionary else {}
	left_handed = cfg.get_value("controles", "zurdo", left_handed)
	paddle_toggle = cfg.get_value("controles", "remar_alternar", paddle_toggle)
	ui_scale = cfg.get_value("accesibilidad", "escala", ui_scale)
	show_hints = cfg.get_value("accesibilidad", "ayudas", show_hints)
	high_contrast = cfg.get_value("accesibilidad", "contraste", high_contrast)
	reduce_motion = cfg.get_value("accesibilidad", "menos_movimiento", reduce_motion)


func _save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("video", "calidad", quality)
	cfg.set_value("video", "fps", fps_limit)
	cfg.set_value("video", "mostrar_fps", show_fps)
	cfg.set_value("video", "adaptativa", adaptive)
	cfg.set_value("controles", "tactiles", touch_mode)
	cfg.set_value("juego", "spot", spot)
	cfg.set_value("audio", "volumen", volume)
	cfg.set_value("juego", "condicion", session_condition)
	cfg.set_value("controles", "tamano", touch_size)
	cfg.set_value("controles", "zurdo", left_handed)
	cfg.set_value("controles", "sensibilidad", steering_sensitivity)
	cfg.set_value("controles", "distancia_camara", camera_distance)
	cfg.set_value("controles", "zona_muerta", stick_deadzone)
	cfg.set_value("controles", "invertir_peso", invert_weight)
	cfg.set_value("controles", "teclas", key_bindings)
	cfg.set_value("controles", "remar_alternar", paddle_toggle)
	cfg.set_value("accesibilidad", "escala", ui_scale)
	cfg.set_value("accesibilidad", "ayudas", show_hints)
	cfg.set_value("accesibilidad", "contraste", high_contrast)
	cfg.set_value("accesibilidad", "menos_movimiento", reduce_motion)
	cfg.save(config_path())


func config_path() -> String:
	var args := OS.get_cmdline_user_args()
	if "--qa" in args and "--polish-test" in args:
		return "user://polish-test.cfg"
	return "user://controls-test.cfg" if "--qa" in args and "--controls-test" in args else PATH
