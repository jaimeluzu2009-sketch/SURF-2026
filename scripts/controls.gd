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


func stick() -> Vector2:
	if bot_enabled:
		return bot_stick
	var k := Vector2(Input.get_axis("surf_left", "surf_right"), Input.get_axis("surf_down", "surf_up"))
	return (k + touch_stick).limit_length(1.0)


## Con Ajustes.paddle_toggle, un toque de "remar" activa la remada y otro la para.
var paddle_latched := false


func _input(event: InputEvent) -> void:
	if Ajustes.paddle_toggle and event.is_action_pressed("surf_paddle"):
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
