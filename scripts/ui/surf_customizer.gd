class_name SurfCustomizer
extends VBoxContainer
## UI embebida: ninguna selección depende de ventanas emergentes nativas.
signal finished
signal view_changed(index: int)
var tab := 0
var _tabs: HBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _status: Label
var _view := 0
var _pending := false
var _view_buttons: Array[Button]=[]

func _ready() -> void:
	add_theme_constant_override("separation",12)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",12)
	var back := UiKit.button("‹ VOLVER",false,100)
	back.name="Back"
	back.pressed.connect(func(): finished.emit())
	header.add_child(back)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation",0)
	titles.add_child(UiKit.kicker("PERSONALIZACIÓN"))
	titles.add_child(UiKit.headline("SURFISTA Y TABLA",32))
	header.add_child(titles)
	add_child(header)
	var band := PatternBand.new()
	band.custom_minimum_size.y=8
	band.color=UiKit.TURQUOISE
	add_child(band)
	_tabs=UiKit.tabs(["APARIENCIA","ROPA","TABLA"],select_tab)
	add_child(_tabs)
	_scroll=ScrollContainer.new()
	_scroll.name="OptionsScroll"
	_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus=true
	_scroll.scroll_deadzone=12
	add_child(_scroll)
	TouchScroll.attach(_scroll)
	_body=VBoxContainer.new()
	_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation",14)
	_scroll.add_child(_body)
	var views := HBoxContainer.new()
	for i in 2:
		var button := UiKit.button("VER SURFISTA" if i==0 else "VER FONDO",false,0)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.toggle_mode=true
		button.name="View%d"%i
		_view_buttons.append(button)
		button.pressed.connect(func():
			_view=i
			for j in _view_buttons.size(): _view_buttons[j].button_pressed=j==i
			view_changed.emit(i))
		views.add_child(button)
	add_child(views)
	_status=UiKit.label("",15,UiKit.TEXT_DIM)
	_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	Perfil.changed.connect(_schedule_refresh)
	refresh()

func select_tab(index: int) -> void:
	tab=clampi(index,0,2)
	_scroll.scroll_vertical=0
	_view=0
	for i in _view_buttons.size(): _view_buttons[i].button_pressed=i==0
	view_changed.emit(0)
	refresh()

func _schedule_refresh() -> void:
	if _pending or not is_visible_in_tree(): return
	_pending=true
	refresh.call_deferred()

func refresh() -> void:
	_pending=false
	if _body==null: return
	var offset := _scroll.scroll_vertical
	var focused := get_viewport().gui_get_focus_owner()
	var focus_name := str(focused.name) if focused!=null and _body.is_ancestor_of(focused) else ""
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	for i in 3: (_tabs.get_child(i) as Button).button_pressed=i==tab
	match tab:
		0:
			_body.add_child(UiKit.kicker("ELIGE TU ESTILO",UiKit.SUNSET))
			var grid := GridContainer.new()
			grid.columns=2
			grid.add_theme_constant_override("h_separation",8)
			grid.add_theme_constant_override("v_separation",8)
			_body.add_child(grid)
			for i in Perfil.STYLES.size():
				var style: Dictionary=Perfil.STYLES[i]
				var button := _choice(style.name,Perfil.style_index()==i)
				button.name="Style_"+style.id
				button.pressed.connect(Perfil.set_style.bind(i))
				grid.add_child(button)
			palette("skin","TONO DE PIEL")
			palette("hair","COLOR DEL CABELLO")
		1:
			_body.add_child(UiKit.kicker("ROPA PARA EL AGUA",UiKit.SUNSET))
			for i in 2:
				var button := _choice("NEOPRENO COMPLETO" if i==0 else "LICRA Y BERMUDA",Perfil.outfit==i)
				button.name="Outfit_%d"%i
				button.pressed.connect(Perfil.set_outfit.bind(i))
				_body.add_child(button)
			palette("wetsuit","COLOR PRINCIPAL")
			palette("accent","DETALLE / BERMUDA")
			_level_note()
		2:
			palette("deck","CUBIERTA")
			palette("bottom","FONDO")
			_level_note()
			var note := UiKit.label("Pulsa VER FONDO para revisar el color de la parte inferior de tu tabla.",17,UiKit.TEXT_DIM)
			note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(note)
	_status.text="%s · %s\nCambios aplicados al surfista y guardados automáticamente."%[Perfil.STYLES[Perfil.style_index()].name,"Neopreno" if Perfil.outfit==0 else "Licra y bermuda"]
	_scroll.set_deferred("scroll_vertical",offset)
	if focus_name!="":
		var target := _body.find_child(focus_name,true,false) as Control
		if target: target.grab_focus.call_deferred()

func _choice(text: String, selected: bool) -> Button:
	var button := UiKit.button(text,selected,0)
	button.toggle_mode=true
	button.button_pressed=selected
	button.custom_minimum_size.y=54
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",19)
	return button

func palette(slot: String, title: String) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation",7)
	section.add_child(UiKit.kicker(title,UiKit.SUNSET))
	section.add_child(UiKit.label(Perfil.item(slot,Perfil.look[slot]).name,17,UiKit.SAND))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",10)
	row.add_theme_constant_override("v_separation",8)
	for item in Perfil.SLOTS[slot]:
		var button := Button.new()
		button.name="Color_"+slot+"_"+item.id
		button.custom_minimum_size=Vector2(50,50)
		var unlocked := Perfil.unlocked(item)
		var selected: bool=Perfil.look[slot]==item.id
		var color: Color=item.color
		button.add_theme_stylebox_override("normal",UiKit.box(color if unlocked else color.darkened(.65),12,UiKit.SAND if selected else Color(UiKit.SAND,.2),3 if selected else 1,4))
		button.add_theme_stylebox_override("hover",UiKit.box(color,12,UiKit.TURQUOISE,3,4))
		button.add_theme_stylebox_override("focus",UiKit.box(Color.TRANSPARENT,12,UiKit.CORAL,3,4))
		button.add_theme_stylebox_override("pressed",UiKit.box(color.lightened(.15),12,UiKit.SAND,3,4))
		button.tooltip_text=item.name if unlocked else "%s · desbloquea en nivel %d"%[item.name,item.level]
		if not unlocked:
			button.disabled=true
			button.text="NV %d"%item.level
		button.pressed.connect(Perfil.set_look.bind(slot,item.id))
		row.add_child(button)
	section.add_child(row)
	_body.add_child(section)

func _level_note() -> void:
	var note := UiKit.label("NV indica el nivel necesario para desbloquear ese color.",15,UiKit.TEXT_DIM)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(note)

func reset_preview() -> void:
	_view=0
	for i in _view_buttons.size(): _view_buttons[i].button_pressed=i==0
	view_changed.emit(0)
