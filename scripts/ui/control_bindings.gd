class_name ControlBindings
extends VBoxContainer
var _buttons := {}
var _status: Label
func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiKit.kicker("TECLADO · REASIGNAR TECLAS"))
	_status = UiKit.label("Selecciona una acción. Esc siempre permite cancelar o volver.", 16, UiKit.TEXT_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	for action in Controles.ACTION_NAMES:
		var button := UiKit.button("", false, 260)
		button.pressed.connect(Controles.begin_rebind.bind(action))
		_buttons[action] = button
		add_child(UiKit.setting_row(Controles.ACTION_NAMES[action], "", button))
	Controles.bindings_changed.connect(_refresh)
	Controles.binding_message.connect(_show_message)
	_refresh()
	var note := UiKit.label("Mando: stick izquierdo para girar y repartir peso; X/RB para remar, A para pararse, Y para reiniciar y Start para pausar. Los botones del mando conservan estas asignaciones.", 16, UiKit.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
func _show_message(message: String) -> void:
	_status.text = message
func _refresh() -> void:
	for action in _buttons:
		(_buttons[action] as Button).text = "PULSA UNA TECLA…" if Controles.capture_action == action else Controles.key_label(action)
