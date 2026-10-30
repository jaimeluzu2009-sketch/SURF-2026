extends Node
var game: Game
var ui: SurfCustomizer
var failures: Array[String]=[]
func _ready() -> void:
	game=get_parent()
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("[custom] ","PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func wait_frames(count := 3) -> void:
	for i in count: await get_tree().process_frame
func tap(name: String) -> void:
	var button := ui.find_child(name,true,false) as Button
	check(button!=null and not button.disabled,"botón accesible: "+name)
	if button==null or button.disabled: return
	if ui._scroll.is_ancestor_of(button): ui._scroll.ensure_control_visible(button)
	await wait_frames()
	var position := get_viewport().get_final_transform()*button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT
	down.position=position
	down.pressed=true
	Input.parse_input_event(down)
	await wait_frames(1)
	var up := InputEventMouseButton.new()
	up.button_index=MOUSE_BUTTON_LEFT
	up.position=position
	up.pressed=false
	Input.parse_input_event(up)
	await wait_frames()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await wait_frames(24)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://capturas/personalizacion")
	get_viewport().get_texture().get_image().save_png("res://capturas/personalizacion/"+("panoramico_" if get_viewport().get_visible_rect().size.x>1300 else "")+name+".png")
func color_on_model(material: String) -> Color:
	var body := game.surfer.get_node("Rider/SurferModel").find_child("Surfer",true,false) as MeshInstance3D
	for i in body.mesh.get_surface_count():
		if body.mesh.surface_get_material(i).resource_name==material:
			return (body.get_surface_override_material(i) as BaseMaterial3D).albedo_color
	return Color.MAGENTA
func run() -> void:
	Ajustes.persist=false
	Input.emulate_touch_from_mouse=true # Desktop touchscreen simulation for ScrollContainer drag.
	game.menus.open("custom","main")
	game.cam.snap_now()
	ui=game.menus._customizer
	await wait_frames()
	check(ui.find_children("*","OptionButton",true,false).is_empty(),"selecciones embebidas sin popups nativos")
	var body := game.surfer.get_node("Rider/SurferModel").find_child("Surfer",true,false) as MeshInstance3D
	for i in 4:
		ui.select_tab(0)
		await wait_frames()
		var id: String=Perfil.STYLES[i].id
		await tap("Style_"+id)
		check(Perfil.style_id==id,"apariencia responde al click: "+id)
		ui.select_tab(1)
		await wait_frames()
		var previous: Mesh
		for outfit in 2:
			await tap("Outfit_%d"%outfit)
			check(Perfil.style_id==id and Perfil.outfit==outfit,"ropa conserva apariencia: %s/%d"%[id,outfit])
			if outfit==1: check(body.mesh!=previous,"cambia la malla real de ropa: "+id)
			previous=body.mesh
			if id=="local": await shot("local_neopreno" if outfit==0 else "local_licra")
	ui.select_tab(0)
	await wait_frames()
	await tap("Color_skin_morena")
	check(color_on_model("Piel").is_equal_approx(Perfil.look_color("skin")),"tono de piel llega al material real")
	await tap("Color_hair_cobrizo")
	check(color_on_model("Pelo").is_equal_approx(Perfil.look_color("hair")),"color de cabello llega al material real")
	await shot("apariencia_ingame")
	ui.select_tab(1)
	await wait_frames()
	await tap("Color_wetsuit_tropical")
	await tap("Color_accent_azulmar")
	await shot("ropa_ingame")
	await swipe_options()
	ui.select_tab(2)
	await wait_frames()
	var locked := ui.find_child("Color_bottom_pacifico",true,false) as Button
	check(locked.disabled,"colores de nivel bloqueados se identifican y no se aplican")
	await tap("Color_bottom_coral")
	await tap("View1")
	check(game.surfer.showcase_board and not game.surfer.rider.visible,"vista de fondo muestra solo la tabla invertida")
	await shot("tabla_fondo_ingame")
	await touch_tab(0)
	check(ui.tab==0,"pestañas responden a toque de pantalla")
	await touch_choice("Style_local")
	check(Perfil.style_id=="local","apariencia responde a toque de pantalla")
	await shot("movil_apariencia_ingame")
	var snapshot := Perfil.look.duplicate()
	var style := Perfil.style_id
	var outfit := Perfil.outfit
	Ajustes.persist=true
	Perfil._save()
	Ajustes.persist=false
	var loaded: Node = load("res://scripts/profile.gd").new()
	loaded._load()
	check(loaded.style_id==style and loaded.outfit==outfit and loaded.look==snapshot,"guardado y recarga reales en archivo aislado")
	loaded.free()
	DirAccess.remove_absolute(Perfil.config_path())
	game.menus.back()
	check(not game.surfer.showcase_board and game.surfer.rider.visible and game.surfer.leash.visible,"salir restaura surfista y leash")
	game.start_play()
	check(game.surfer.state==Surfer.State.PRONE and game.surfer.rider.visible,"personalización no deja el gameplay oculto o invertido")
	print("[custom] RESULTADO: ","OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func touch_tab(index: int) -> void:
	await screen_touch((ui._tabs.get_child(index) as Control).get_global_rect().get_center())
func touch_choice(name: String) -> void:
	var button := ui.find_child(name,true,false) as Control
	if ui._scroll.is_ancestor_of(button): ui._scroll.ensure_control_visible(button)
	await wait_frames()
	await screen_touch(button.get_global_rect().get_center())
func screen_touch(position: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index=0
	down.position=get_viewport().get_final_transform()*position
	down.pressed=true
	Input.parse_input_event(down)
	await wait_frames(1)
	var up := InputEventScreenTouch.new()
	up.index=0
	up.position=get_viewport().get_final_transform()*position
	up.pressed=false
	Input.parse_input_event(up)
	await wait_frames()

func swipe_options() -> void:
	ui._scroll.scroll_vertical=0
	await wait_frames()
	var start := ui._scroll.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index=0
	down.position=get_viewport().get_final_transform()*start
	down.pressed=true
	Input.parse_input_event(down)
	await wait_frames(1)
	for i in 6:
		var drag := InputEventScreenDrag.new()
		drag.index=0
		drag.position=get_viewport().get_final_transform()*(start+Vector2(0,-20*(i+1)))
		drag.relative=get_viewport().get_final_transform().get_scale()*Vector2(0,-20)
		Input.parse_input_event(drag)
		await wait_frames(1)
	var up := InputEventScreenTouch.new()
	up.index=0
	up.position=get_viewport().get_final_transform()*(start+Vector2(0,-120))
	up.pressed=false
	Input.parse_input_event(up)
	await wait_frames()
	print("[custom] scroll=",ui._scroll.scroll_vertical," max=",ui._scroll.get_v_scroll_bar().max_value," page=",ui._scroll.get_v_scroll_bar().page)
	check(ui._scroll.scroll_vertical>0,"deslizar con el dedo desplaza las opciones de ropa")
