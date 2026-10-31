extends Node
## QA usa entradas reales del mismo agregador que teclado/touch, sin otorgar puntos al piloto.
var game: Game
var failures: Array[String]=[]
var events: Array[Dictionary]=[]
var shots := false
var max_height := 0.0

func _ready() -> void:
	game=get_parent() as Game
	shots="--tricks-shots" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("[tricks] ","PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func prepare(spot: int, ratio: float, ahead: float, velocity: Vector2) -> void:
	Controles.bot_enabled=true
	Controles.bot_stick=Vector2.ZERO
	Controles.bot_impulse=false
	Controles.bot_trick=false
	if game.spot.id!=Spots.get_spot(spot).id:
		game.spot=Spots.get_spot(spot)
		game.session.setup(game.spot,Ajustes.session_condition)
		game.lineup=Spots.lineup(game.spot)
		game.beach.build(game.spot)
		game._apply_spot_look()
		game.hud.set_spot(game.spot)
		game.cam.lineup=game.lineup
	game.start_play()
	game.set_physics_process(true)
	var w := game.wave
	Spots.apply_to_wave(Spots.get_spot(spot),w)
	w.start_z=w.break_z-58.0  # mismo momento de la ola que antes de alejar la rompiente
	w.time=15.0
	w.update()
	events.clear()
	var s := game.surfer
	var x := w.peel_x+w.peel_dir*ahead
	var z := w.crest_z+w.front_width*ratio
	s.reset_to(Vector3(x,w.height_at(x,z)+Surfer.DECK_RIDE,z),atan2(velocity.x,velocity.y))
	s.state=Surfer.State.RIDING
	s.hvel=velocity
	s.animator.jump_to("ride")
	s.reset_physics_interpolation()
	game.cam.snap_now()

func shot(name: String) -> void:
	if not shots or DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := "res://capturas/trucos"
	DirAccess.make_dir_recursive_absolute(folder)
	get_viewport().get_texture().get_image().save_png(folder+"/"+name+".png")

func has_kind(kind: String) -> bool:
	for e in events:
		if e.kind==kind: return true
	return false

func takeoff() -> void:
	prepare(0,0.28,12.0,Vector2(-8.0,5.8))
	await frames(2)
	Controles.bot_impulse=true
	await frames(26)
	Controles.bot_impulse=false
	await frames(2)
	check(game.surfer.state==Surfer.State.AIRBORNE,"carga y suelta despegan desde el labio")

func await_landing(spin := false, grab := false, bad := false, bad_spin := false) -> void:
	var s := game.surfer
	var before := game.score.turns
	var initial_wake := s._wake.size()
	var captured := false
	max_height=0.0
	for i in 150:
		if s.state!=Surfer.State.AIRBORNE: break
		Controles.bot_trick=grab
		Controles.bot_stick=Vector2(-1.0 if (spin and absf(s.tricks.air_spin)<PI-0.04) or bad_spin else 0.0,1.0 if bad else 0.0)
		await frames(1)
		if s.state==Surfer.State.AIRBORNE:
			var height := s.global_position.y-game.wave.height_at(s.global_position.x,s.global_position.z)
			max_height=maxf(max_height,height)
			if i==12: check(not s.touching_water() and not s.wake.emitting,"sin contacto ni spray mientras vuela")
			if i==12:
				check(game.score.turns==before,"aéreo pendiente no suma maniobra antes del aterrizaje")
				check(s._wake.size()<=initial_wake,"aéreo no escribe nuevas marcas de espuma sobre el agua")
			if not captured and i>=20:
				await shot("fallo_peso_ingame" if bad else ("fallo_giro_ingame" if bad_spin else ("agarre180_ingame" if spin else ("agarre_ingame" if grab else "aereo_ingame"))))
				captured=true
	Controles.bot_stick=Vector2.ZERO
	Controles.bot_trick=false
	check(max_height>0.30,"trayectoria se separa realmente de la superficie")
	if bad or bad_spin:
		check(s.state==Surfer.State.WIPEOUT,"aterrizaje desalineado o con peso extremo provoca caída")
		check(game.score.turns==before,"caída descarta el aéreo pendiente")
	else:
		check(s.state==Surfer.State.RIDING,"vuelve físicamente a la superficie surfeable")
		check(game.score.turns==before+1,"puntos de aéreo se confirman una sola vez al aterrizar")
		check(s.switch_stance==spin,"180 conserva desplazamiento y cambia a switch")
		await shot("aterrizaje180_ingame" if spin else "aterrizaje_ingame")
		if spin:
			var course := s.hvel.normalized()
			await frames(18)
			check(s.state==Surfer.State.RIDING and s.hvel.dot(course)>3.0 and s.switch_stance,"switch conserva la inercia y continúa surfeando tras aterrizar")
	print("[tricks] vuelo altura=",max_height," estado=",s.state," giro=",s.tricks.air_spin," eventos=",events)

func run() -> void:
	Ajustes.persist=false
	game.surfer.maneuver_completed.connect(func(result): events.append(result))
	model_checks()
	var score := ScoreKeeper.new()
	score.award_maneuver({"kind":"snap","speed":7.0})
	var first := score.score
	score.tick(4.0)
	var p := score.score
	score.award_maneuver({"kind":"snap","speed":7.0})
	check(score.score-p<first,"repetir la misma familia reduce su valor sin depender del combo")
	var flow := score.flow
	score.award_maneuver({"kind":"floater","speed":7.0})
	check(score.flow>flow and score.trick_count("floater")==1,"variedad alimenta Flujo y registra trucos")
	score.tick(5.0)
	check(score.combo==1,"ventana de combo expira incluso fuera del estado de surf")
	flow=score.flow
	score.break_chain()
	check(score.combo==1 and score.flow<=flow*.5,"caída corta combo y reduce Flujo")
	score.reset()
	score.tube_step(1.0,true,1.0)
	check(score.score==100,"profundidad del tubo queda pendiente hasta salir")
	score.tube_exit_bonus(1.0)
	check(score.score==1110,"salida valida bonificación por profundidad")
	score.reset()
	score.tube_step(1.0,true,1.0,0.0,1.0)
	check(score.score==30,"tubo sin control apenas puntúa (solo estar dentro no basta)")
	check(Perfil.challenge_met(Spots.get_spot(0).challenges[3],{"tricks":{"grab180":1}}),"progresión admite las variantes del aéreo")
	prepare(0,1.4,12.0,Vector2(-8,5.8))
	check(not game.surfer.tricks.can_launch(game.wave.sample(game.surfer.global_position.x,game.surfer.global_position.z)),"no despega desde la parte baja de la cara")
	prepare(0,.4,12.0,Vector2(-1,1))
	check(not game.surfer.tricks.can_launch(game.wave.sample(game.surfer.global_position.x,game.surfer.global_position.z)),"no despega sin velocidad")

	await takeoff()
	await await_landing(false,false,false)
	check(has_kind("air"),"aéreo básico sin agarre se valida al aterrizar")
	await takeoff()
	await await_landing(false,true,false)
	check(has_kind("grab_air"),"agarre exige sostener TRUCO durante vuelo y aterrizar")
	await takeoff()
	await await_landing(true,true,false)
	check(has_kind("grab180"),"180 con agarre validado sobre trayectoria real")
	await takeoff()
	await await_landing(false,false,true)

	await takeoff()
	await await_landing(false,false,false,true)

	# Snap: entrada de truco contextual y arco físico, sin inyectar evento.
	prepare(0,.28,10.0,Vector2(-8,5.2))
	await frames(2)
	Controles.bot_stick=Vector2(0.9,0)
	Controles.bot_trick=true
	await frames(10)
	await shot("snap_ingame")
	await frames(22)
	Controles.bot_trick=false
	check(has_kind("snap"),"snap exige rotación física en el labio")
	print("[tricks] snap eventos=",events)

	# Floater en la izquierda, sobre la misma cresta que se dibuja.
	prepare(2,.18,-0.7,Vector2(8,4.9))
	await frames(2)
	Controles.bot_trick=true
	await frames(20)
	check(game.surfer.state==Surfer.State.FLOATER,"floater contextual funciona en la izquierda de La FAE")
	await shot("floater_ingame")
	if shots:
		var previous_touch := Ajustes.touch_mode
		Ajustes.touch_mode=1
		game.touch._refresh()
		await shot("controles_trucos_ingame")
		Ajustes.touch_mode=previous_touch
		game.touch._refresh()
	Controles.bot_trick=false
	for i in 140:
		await frames(1)
		if has_kind("floater") or game.surfer.state==Surfer.State.WIPEOUT: break
	check(has_kind("floater") and game.surfer.state==Surfer.State.RIDING,"floater puntúa después de regresar a la cara")
	await shot("floater_salida_ingame")
	print("[tricks] floater eventos=",events)

	prepare(2,.18,-.7,Vector2(8,4.9))
	await frames(2)
	Controles.bot_trick=true
	await frames(74)
	check(game.surfer.state!=Surfer.State.FLOATER,"floater sostenido termina automáticamente: no hay inmunidad infinita")
	Controles.bot_trick=false

	prepare(2,.18,12.0,Vector2(8,4.9))
	await frames(2)
	Controles.bot_trick=true
	await frames(2)
	check(game.surfer.state==Surfer.State.RIDING,"floater exige la zona de rotura, no cualquier cresta")
	Controles.bot_trick=false

	# Bombeo rítmico: no mantener una tecla, no sumar velocidad en agua plana.
	prepare(0,.9,16.0,Vector2(-8,5.2))
	Controles.bot_stick=Vector2(0,-.8)
	await frames(18)
	Controles.bot_stick=Vector2(0,.8)
	await frames(2)
	check(game.surfer.tricks.pump_count==1,"alternar peso a ritmo genera un impulso medido")
	await frames(12)
	check(game.surfer.tricks.pump_count==1,"mantener peso no genera bombeos infinitos")

	# Pausa cancela carga: soltar una tecla en el menú no provoca despegue.
	prepare(0,.4,12.0,Vector2(-8,5.8))
	Controles.bot_impulse=true
	await frames(12)
	game.pause()
	Controles.bot_impulse=false
	game.resume()
	await frames(2)
	check(game.surfer.state==Surfer.State.RIDING and game.surfer.tricks.charge==0.0,"pausa cancela impulso pendiente")
	await tube_case(false)
	await tube_case(true)
	await input_case()
	print("[tricks] RESULTADO: ","OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func tube_case(drag: bool) -> void:
	prepare(1,.84,1.5,Vector2(-9.0,5.0))
	var surf := game.surfer
	surf.yaw=-PI*.5
	var entered := false
	var action_frames := 0
	var verified := false
	var entry_speed := 0.0
	for frame in 420:
		var desired := game.wave.peel_dir*1.16
		var weight := -surf.balance*1.4
		if drag and action_frames>=22: weight=0.7 if (frame/22)%2==0 else -0.7
		var held := surf.in_tube and action_frames<22
		if held:
			if action_frames==0: entry_speed=surf.speed()
			action_frames+=1
			if drag: weight=-.55
		Controles.bot_trick=held
		Controles.bot_stick=Vector2(clampf(-wrapf(desired-surf.yaw,-PI,PI)*2.2,-1,1),weight)
		await frames(1)
		entered=entered or surf.in_tube
		if action_frames==18 and not verified:
			check(surf.tricks.tube_action==("hand_drag" if drag else "tube_rail"),"acción de tubo se activa con la entrada contextual correcta")
			check(events.is_empty(),"acción de tubo no se premia antes de salir")
			if drag: check(surf.speed()<entry_speed,"arrastrar mano reduce velocidad real antes de volver a bombear")
			await shot("mano_tubo_ingame" if drag else "canto_tubo_ingame")
			verified=true
		if surf.tube_exits>0 or surf.state==Surfer.State.WIPEOUT: break
	check(entered and surf.tube_exits>0,"acciones del tubo permiten salida con movimiento real")
	check(has_kind("hand_drag" if drag else "tube_rail"),"acción dentro del tubo confirma premio solamente al salir")
	print("[tricks] tubo drag=",drag," duración=",surf.tube_seconds," estado=",surf.state," eventos=",events)

func input_case() -> void:
	Controles.bot_enabled=false
	Controles.reset_controls()
	Controles.riding_context=true
	Ajustes.paddle_toggle=true
	Controles.rebind("surf_stand",KEY_K)
	var key := InputEventKey.new()
	key.physical_keycode=KEY_K
	key.pressed=true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(Controles.trick_held(),"truco usa la misma acción reasignable que pararse")
	var key_up := InputEventKey.new()
	key_up.physical_keycode=KEY_K
	key_up.pressed=false
	Input.parse_input_event(key_up)
	Input.flush_buffered_events()
	Input.action_press("surf_paddle")
	check(Controles.impulse_held(),"impulso responde a mantener incluso con remar alternable")
	Input.action_release("surf_paddle")
	check(not Controles.impulse_held(),"soltar impulso no queda enclavado")
	var touch := game.touch
	touch.visible=true
	touch.active=true
	touch.set_riding_context(true)
	var e := InputEventScreenTouch.new()
	e.index=3
	e.position=touch.get_global_transform_with_canvas()*touch._stand_c
	e.pressed=true
	touch._input(e)
	check(Controles.trick_held(),"táctil conserva TRUCO mientras el dedo permanece abajo")
	e.pressed=false
	touch._input(e)
	check(not Controles.trick_held(),"táctil libera TRUCO al levantar el dedo")
	e.position=touch.get_global_transform_with_canvas()*touch._paddle_c
	e.pressed=true
	touch._input(e)
	check(Controles.impulse_held() and not Controles.paddle_latched,"IMPULSO táctil no activa el modo remar alternable")
	touch.active=false
	touch._process(.016)
	check(not Controles.impulse_held() and not Controles.trick_held(),"ocultar o desactivar controles libera los botones")
	Controles.reset_controls()

func model_checks() -> void:
	var s := game.surfer
	var a := s.animator
	var player := s.get_node("Rider/SurferModel").find_child("AnimationPlayer",true,false) as AnimationPlayer
	a.tree.active=false
	var feet := {}
	for clip in ["ride","air","grab","snap","landing","floater","tube_rail","hand_drag"]:
		check(player.has_animation(clip),"clip 3D disponible: "+clip)
		player.play(clip)
		player.seek(0.16,true)
		a.skeleton.force_update_all_bone_transforms()
		for foot in ["foot_L","foot_R"]:
			var pos := a.skeleton.get_bone_global_pose(a.skeleton.find_bone(foot)).origin
			if clip=="ride": feet[foot]=pos
			else: check(pos.distance_to(feet[foot])<0.025,"pie sobre la tabla: "+clip+" "+foot)
		if clip in ["grab","tube_rail","hand_drag"]:
			var hand := a.skeleton.get_bone_global_pose(a.skeleton.find_bone("hand_L")).origin
			var pose := a.skeleton.get_bone_global_pose(a.skeleton.find_bone("hand_L"))
			var tip: Vector3 = pose*Vector3(0,.191,0)
			print("[tricks] mano ",clip," muñeca=",hand," punta=",tip)
			check(absf(tip.y+Surfer.DECK_RIDE)<0.07 if clip=="hand_drag" else absf(tip.y-.025)<0.05,"mano alcanza agua o canto: "+clip)
	player.stop()
	a.tree.active=true
	a.jump_to("prone_idle")
