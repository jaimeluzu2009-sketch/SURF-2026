class_name Game
extends Node3D
## Escena principal. Carga el spot elegido (Spots.LIST), gestiona las olas, el
## surfista, la cámara, la puntuación, la calidad gráfica y las pantallas.
## Modos: menú (cámara cinematográfica), juego, pausa y resultados.

## Cuando la cresta pasa de aquí con el surfista de pie, la ola se da por completada.
const FINISH_Z := 50.0

enum Mode { MENU, PLAY, PAUSE, RESULTS }

@onready var water: Water = $Water
@onready var beach: Beach = $Beach
@onready var surfer: Surfer = $Surfer
@onready var cam: CameraRig = $Camera
@onready var hud: Hud = $UI/Hud
@onready var menus: Menus = $UI/Menus
@onready var touch: TouchControls = $UI/Touch
@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var lip_spray: CPUParticles3D = $LipSpray

var wave := WaveModel.new()
var score := ScoreKeeper.new()
var spot: Dictionary
var lineup := Vector3.ZERO
var mode := Mode.MENU
var _missed_timer := -1.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--spot="):
			Ajustes.spot = int(a.get_slice("=", 1))
	spot = Spots.get_spot(Ajustes.spot)
	Spots.apply_to_wave(spot, wave)
	lineup = Spots.lineup(spot)
	beach.build(spot)
	_apply_spot_look()
	hud.set_spot(spot)
	water.wave = wave
	water.follow = surfer
	surfer.wave = wave
	cam.wave = wave
	cam.surfer = surfer
	cam.lineup = lineup
	surfer.ride_ended.connect(_on_ride_ended)
	surfer.hint.connect(func(t): hud.show_hint(t))
	score.event.connect(func(t, p): hud.popup(t, p))
	hud.pause_pressed.connect(pause)
	menus.play_requested.connect(_on_play_requested)
	menus.restart_requested.connect(start_play)
	menus.resume_requested.connect(resume)
	menus.menu_requested.connect(to_menu)
	menus.customize_preview.connect(_on_customize_preview)
	Fx.setup_spray(lip_spray, 50, 0.7, 0.08, 0.3)
	lip_spray.direction = Vector3(0, 1, 0.8)
	lip_spray.spread = 30.0
	lip_spray.initial_velocity_min = 2.5
	lip_spray.initial_velocity_max = 5.5
	lip_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	lip_spray.emission_box_extents = Vector3(1.5, 0.2, 0.4)
	Fx.setup_spray(surfer.wake, 40, 0.5, 0.12, 0.5)
	surfer.wake.direction = Vector3(0, 1, -1)
	surfer.wake.spread = 30.0
	surfer.wake.initial_velocity_min = 1.5
	surfer.wake.initial_velocity_max = 3.5
	Ajustes.changed.connect(_apply_quality)
	_apply_quality()
	var bot_mode := "--bot" in args and ResourceLoader.exists("res://tests/bot.gd")
	if bot_mode or Ajustes.skip_menu:
		start_play()
	else:
		to_menu()
	Ajustes.skip_menu = false
	if bot_mode:
		var bot: Node = load("res://tests/bot.gd").new()
		bot.name = "Bot"
		bot.setup(self, args)
		add_child(bot)
	elif args.size() > 0 and args[0].begins_with("--ui-shots=") and ResourceLoader.exists("res://tests/ui_shots.gd"):
		var shots: Node = load("res://tests/ui_shots.gd").new()
		shots.setup(self, args)
		add_child(shots)


## Luz, cielo y colores del agua del spot.
func _apply_spot_look() -> void:
	sun.look_at_from_position(Vector3.ZERO, spot["sun_dir"], Vector3.UP)
	sun.light_color = spot["sun_color"]
	sun.light_energy = spot["sun_energy"]
	var env := world_env.environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = spot["sky_top"]
	sky.sky_horizon_color = spot["sky_horizon"]
	sky.ground_horizon_color = (spot["sky_horizon"] as Color).darkened(0.1)
	# Por debajo del horizonte el cielo toma el color del mar, para que no se note la línea.
	sky.ground_bottom_color = (spot["deep"] as Color)
	sky.ground_curve = 0.04
	# AgX conserva detalle en blancos (espuma, arena) y sombras; contraste y saturación suaves.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.92 if spot["sun_energy"] > 1.0 else 1.12
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	env.fog_light_color = spot["sky_horizon"]
	env.fog_density = spot.get("fog", 0.0011)
	# Con el cielo cubierto la luz ambiente pesa más que el sol.
	env.ambient_light_energy = 0.85 if spot["sun_energy"] > 1.0 else 1.1
	water.set_colors(spot["deep"], spot["shallow"], spot["face"])
	water.set_sky(spot["sky_horizon"], -(spot["sun_dir"] as Vector3))


func _apply_quality() -> void:
	var p := Ajustes.preset()
	sun.shadow_enabled = p["shadows"]
	# Sombras suaves según la calidad (en Baja no hay sombras).
	RenderingServer.directional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][Ajustes.quality])
	world_env.environment.glow_enabled = p["glow"]
	cam.far = p["far"]
	lip_spray.amount = maxi(10, int(70 * p["particles"]))


# ------------------------------------------------------------------ modos

func to_menu() -> void:
	get_tree().paused = false
	mode = Mode.MENU
	wave.reset()
	_place_surfer_at_lineup()
	surfer.set_frozen(true)
	hud.set_playing(false)
	cam.mode = CameraRig.Mode.CINEMATIC
	menus.open("main")


func start_play() -> void:
	get_tree().paused = false
	menus.close()
	mode = Mode.PLAY
	surfer.set_frozen(false)
	surfer.set_showcase(false)
	cam.mode = CameraRig.Mode.FOLLOW
	hud.set_playing(true)
	restart()


func pause() -> void:
	if mode != Mode.PLAY:
		return
	mode = Mode.PAUSE
	get_tree().paused = true
	menus.open("pause")


func resume() -> void:
	if mode != Mode.PAUSE:
		return
	menus.close()
	get_tree().paused = false
	mode = Mode.PLAY


func _on_play_requested(i: int) -> void:
	if i == Ajustes.spot:
		start_play()
		return
	# Otro spot: se recarga la escena con el escenario nuevo y se empieza a surfear directamente.
	Ajustes.spot = i
	Ajustes.skip_menu = true
	Ajustes.apply()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_customize_preview(on: bool) -> void:
	surfer.set_showcase(on)
	cam.mode = CameraRig.Mode.SHOWCASE if on else (CameraRig.Mode.CINEMATIC if mode == Mode.MENU else cam.mode)


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.PLAY and event.is_action_pressed("surf_pause"):
		pause()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ olas

func restart() -> void:
	wave.reset()
	score.reset()
	_place_surfer_at_lineup()
	_missed_timer = -1.0
	var side := "derecha: al pararte, gira a tu derecha (D o flecha derecha)" if wave.peel_dir < 0.0 \
		else "izquierda: al pararte, gira a tu izquierda (A o flecha izquierda)"
	hud.show_hint("Es una %s. Espera tumbado y rema hacia la playa cuando la ola esté a unos 10 m." % side, 7.0)


func _place_surfer_at_lineup() -> void:
	surfer.reset_to(Vector3(lineup.x, wave.height_at(lineup.x, lineup.z), lineup.z), 0.0)
	cam.snap_now()


func _physics_process(delta: float) -> void:
	wave.advance(delta)
	if mode == Mode.MENU:
		# En el menú las olas siguen llegando (fondo animado); el surfista está quieto en el lineup.
		if wave.crest_z > 55.0:
			wave.reset()
		return
	if surfer.state == Surfer.State.PRONE and _missed_timer < 0.0 \
			and wave.crest_z > surfer.global_position.z + 10.0:
		_missed_timer = 2.5
		hud.show_hint("Se te fue la ola. Viene la siguiente...", 2.5)
	if _missed_timer >= 0.0:
		_missed_timer -= delta
		if _missed_timer < 0.0:
			wave.reset()
			score.reset()
			if surfer.global_position.distance_to(lineup) > 14.0:
				_place_surfer_at_lineup()
			hud.show_hint("Nueva ola en camino. Colócate y rema cuando se acerque.", 4.0)
	if surfer.state == Surfer.State.RIDING:
		var ahead := (surfer.global_position.x - wave.peel_x) * wave.peel_dir
		score.step(delta, surfer.speed(), surfer.carve, ahead if wave.started > 0.5 else 99.0)
		if wave.crest_z > FINISH_Z:
			surfer.finish_success()
			score.finish_bonus()


func _process(delta: float) -> void:
	# El agua se dibuja en el mismo instante (interpolado) que la tabla.
	var t := wave.time
	if get_tree().physics_interpolation:
		t -= (1.0 - Engine.get_physics_interpolation_fraction()) * get_physics_process_delta_time()
	water.sync(t)
	water.set_board(surfer.get_global_transform_interpolated().origin, surfer.speed(), surfer.touching_water(),
		surfer.wake_points())
	_update_lip_spray(t)
	hud.update_state(surfer, wave, score, delta)
	touch.stand_ready = surfer.can_stand and surfer.state == Surfer.State.PRONE
	touch.active = mode == Mode.PLAY
	touch.visible = Ajustes.touch_enabled() and mode == Mode.PLAY
	if mode == Mode.PLAY and Input.is_action_just_pressed("surf_restart"):
		restart()
	if Input.is_action_just_pressed("toggle_fps"):
		Ajustes.show_fps = not Ajustes.show_fps
		Ajustes.apply()


func _update_lip_spray(t: float) -> void:
	var d := wave.derived_at(t)
	var on := d[2] > 0.5 and d[3] > 0.6
	lip_spray.emitting = on
	if on:
		var x := d[1] + wave.peel_dir * 1.5
		var z := d[0] + 0.6
		lip_spray.global_position = Vector3(x, wave.height_at(x, z) + 0.2, z)


func _on_ride_ended(success: bool, title: String, detail: String) -> void:
	var stats := {
		"success": success,
		"score": score.score,
		"time": surfer.ride_time,
		"distance": surfer.ride_distance,
		"speed": surfer.top_speed,
		"combo": score.best_combo,
		"pocket": score.pocket_time,
	}
	var gains := Perfil.record_ride(spot, stats)
	ride_result.emit(stats, gains)
	if has_node("Bot"):
		return
	mode = Mode.RESULTS
	hud.set_playing(false)
	menus.show_results(title, detail, stats, gains)


## Para las pruebas: estadísticas y premios de cada ola.
signal ride_result(stats: Dictionary, gains: Dictionary)
