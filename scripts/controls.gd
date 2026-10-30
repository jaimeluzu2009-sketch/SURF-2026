extends Node
## Autoload "Controles": junta teclado, mando y controles táctiles en una sola entrada.
## Las acciones se crean aquí si no existen en el Mapa de Entrada del proyecto.

const KEYS := {
	"surf_left": [KEY_A, KEY_LEFT],
	"surf_right": [KEY_D, KEY_RIGHT],
	"surf_up": [KEY_W, KEY_UP],
	"surf_down": [KEY_S, KEY_DOWN],
	"surf_paddle": [KEY_SPACE],
	"surf_stand": [KEY_E, KEY_SHIFT],
	"surf_restart": [KEY_R],
	"surf_pause": [KEY_ESCAPE, KEY_P],
	"toggle_fps": [KEY_F3],
}
const PAD_BUTTONS := {
	"surf_paddle": [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER],
	"surf_stand": [JOY_BUTTON_A],
	"surf_restart": [JOY_BUTTON_Y],
	"surf_pause": [JOY_BUTTON_START],
}
const PAD_AXES := {
	"surf_left": [JOY_AXIS_LEFT_X, -1.0],
	"surf_right": [JOY_AXIS_LEFT_X, 1.0],
	"surf_up": [JOY_AXIS_LEFT_Y, -1.0],
	"surf_down": [JOY_AXIS_LEFT_Y, 1.0],
}

## Joystick táctil: x = derecha, y = adelante.
signal bindings_changed
signal binding_message(text: String)
var capture_action := ""
var touch_stick := Vector2.ZERO
var touch_paddle := false
var _touch_stand := false

## Para las pruebas automáticas (tests/bot.gd).
var bot_enabled := false
var bot_stick := Vector2.ZERO
var bot_paddle := false
var _bot_stand := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for button in PAD_BUTTONS.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = button
			InputMap.action_add_event(action, jb)
		if PAD_AXES.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = PAD_AXES[action][0]
			jm.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, jm)

	apply_bindings()


func stick() -> Vector2:
	if bot_enabled:
		return bot_stick
	if capture_action != "":
		return Vector2.ZERO
	var pad := Vector2.ZERO
	for device in Input.get_connected_joypads():
		var raw := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), -Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if raw.length_squared() > pad.length_squared():
			pad = raw
	var analog := filter_stick(pad)
	var touch := filter_stick(touch_stick)
	if touch.length_squared() > analog.length_squared():
		analog = touch
	var keys := Vector2(float(_key_down("surf_right")) - float(_key_down("surf_left")),
		float(_key_down("surf_up")) - float(_key_down("surf_down")))
	var result := Vector2(keys.x if keys.x != 0.0 else analog.x, keys.y if keys.y != 0.0 else analog.y)
	return result.limit_length(1.0)


## Con Ajustes.paddle_toggle, un toque de "remar" activa la remada y otro la para.
var paddle_latched := false


func _input(event: InputEvent) -> void:
	if capture_action != "":
		get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and not event.echo:
			var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if key == KEY_ESCAPE:
				cancel_rebind()
			elif event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
				binding_message.emit("Usa una tecla sin Ctrl, Alt ni Meta. Esc cancela.")
			else:
				var message := rebind(capture_action, key)
				if message == "":
					capture_action = ""
					bindings_changed.emit()
					binding_message.emit("Tecla guardada.")
				else:
					binding_message.emit(message + " Esc cancela.")
		return
	if not get_tree().paused and Ajustes.paddle_toggle and event.is_action_pressed("surf_paddle"):
		paddle_latched = not paddle_latched


func toggle_touch_paddle() -> void:
	paddle_latched = not paddle_latched


func paddling() -> bool:
	if bot_enabled:
		return bot_paddle
	if Ajustes.paddle_toggle:
		return paddle_latched
	return Input.is_action_pressed("surf_paddle") or touch_paddle


## Devuelve true una sola vez por pulsación del botón "ponerse de pie".
func take_stand() -> bool:
	if bot_enabled:
		var b := _bot_stand
		_bot_stand = false
		return b
	var t := _touch_stand
	_touch_stand = false
	return Input.is_action_just_pressed("surf_stand") or t


func press_touch_stand() -> void:
	_touch_stand = true


func bot_stand() -> void:
	_bot_stand = true


const ACTION_NAMES := {"surf_left": "Girar a la izquierda", "surf_right": "Girar a la derecha",
	"surf_up": "Peso adelante / remar", "surf_down": "Peso atrás", "surf_paddle": "Remar",
	"surf_stand": "Ponerse de pie", "surf_pause": "Pausa", "surf_restart": "Reiniciar ola", "toggle_fps": "Mostrar FPS"}

func filter_stick(raw: Vector2) -> Vector2:
	var radius := minf(raw.length(), 1.0)
	var dead: float = Ajustes.stick_deadzone
	if radius <= dead:
		return Vector2.ZERO
	return raw.normalized() * clampf((radius - dead) / (1.0 - dead), 0.0, 1.0)

func _key_down(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and Input.is_physical_key_pressed(event.physical_keycode):
			return true
	return false

func _set_keys(action: String, values: Array) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for code in values:
		var ev := InputEventKey.new()
		ev.physical_keycode = int(code)
		InputMap.action_add_event(action, ev)

func apply_bindings() -> void:
	# Validate the complete saved layout first: swaps must survive a restart.
	var accepted := {}
	for action in Ajustes.key_bindings:
		var value: Variant = Ajustes.key_bindings[action]
		if KEYS.has(action) and value is int and value > 0 and value != KEY_ESCAPE and not OS.get_keycode_string(value).is_empty():
			accepted[action] = value
	for iteration in KEYS.size():
		var conflict := ""
		for action in accepted:
			for other in KEYS:
				if other == action:
					continue
				var values: Array = [accepted[other]] if accepted.has(other) else KEYS[other]
				if accepted[action] in values:
					conflict = action
		if conflict == "":
			break
		accepted.erase(conflict)
	Ajustes.key_bindings = accepted
	for action in KEYS:
		var values: Array = KEYS[action]
		if accepted.has(action):
			values = [KEY_ESCAPE, accepted[action]] if action == "surf_pause" else [accepted[action]]
		_set_keys(action, values)
	bindings_changed.emit()


func _binding_error(action: String, key: int) -> String:
	if not KEYS.has(action) or key <= 0 or key == KEY_ESCAPE or OS.get_keycode_string(key).is_empty():
		return "Tecla no permitida. Esc se reserva para volver o pausar."
	for other in KEYS:
		if other == action:
			continue
		for event in InputMap.action_get_events(other):
			if event is InputEventKey and event.physical_keycode == key:
				return "Esa tecla ya se usa para: %s." % ACTION_NAMES[other]
	return ""

func _store_binding(action: String, key: int) -> void:
	_set_keys(action, [KEY_ESCAPE, key] if action == "surf_pause" else [key])
	Ajustes.key_bindings[action] = key

func rebind(action: String, key: int) -> String:
	var error := _binding_error(action, key)
	if error != "":
		return error
	_store_binding(action, key)
	paddle_latched = false
	Ajustes._save()
	bindings_changed.emit()
	return ""

func key_label(action: String) -> String:
	var names := PackedStringArray()
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			names.append(OS.get_keycode_string(event.physical_keycode))
	return " / ".join(names)

func begin_rebind(action: String) -> void:
	if not KEYS.has(action):
		return
	capture_action = action
	paddle_latched = false
	bindings_changed.emit()
	binding_message.emit("Pulsa una tecla para «%s». Esc cancela." % ACTION_NAMES[action])

func cancel_rebind() -> void:
	if capture_action == "":
		return
	capture_action = ""
	bindings_changed.emit()
	binding_message.emit("Cambio cancelado.")

func reset_controls() -> void:
	cancel_rebind()
	Ajustes.key_bindings.clear()
	Ajustes.camera_distance = 1.0
	Ajustes.steering_sensitivity = 1.0
	Ajustes.stick_deadzone = 0.15
	Ajustes.invert_weight = false
	Ajustes.touch_mode = 0
	Ajustes.touch_size = 1.0
	Ajustes.left_handed = false
	Ajustes.paddle_toggle = false
	paddle_latched = false
	touch_paddle = false
	touch_stick = Vector2.ZERO
	apply_bindings()
	Ajustes.apply()
