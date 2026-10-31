extends Label
var _elapsed := 0.0
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_elapsed += delta
	if _elapsed < 0.25: return
	_elapsed = 0.0
	text = Ajustes.display_description()
