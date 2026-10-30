extends Node
var game: Game
var failures: Array[String] = []
var events: Array[Dictionary] = []
func check(ok: bool, text: String) -> void:
	print("[turns] ","OK " if ok else "FAIL ",text)
	if not ok: failures.append(text)
func _ready() -> void:
	game=get_parent()
	call_deferred("run")
func sample_arc(angle: float, ratio_start: float, ratio_end: float, ahead: float, moving := true, clean := true, direction := 1.0, fps := 60.0) -> Dictionary:
	var detector := SurfTurns.new()
	var result := {}
	for frame in int(fps)+1:
		var f := float(frame)/fps
		var a := PI*0.5-angle*f
		var velocity := Vector2(sin(a)*direction,cos(a))*7.5 if moving else Vector2.ZERO
		var found := detector.step(1.0/fps,0.9*direction,velocity,lerpf(ratio_start,ratio_end,f),ahead,direction,clean)
		if not found.is_empty(): result=found
	var a := PI*0.5-angle
	var velocity := Vector2(sin(a)*direction,cos(a))*7.5 if moving else Vector2.ZERO
	var found := detector.step(1.0/fps,0,velocity,ratio_end,ahead,direction,clean)
	if not found.is_empty(): result=found
	check(detector.step(1.0/fps,0,velocity,ratio_end,ahead,direction,clean).is_empty(),"una sola emisión al soltar")
	return result
func run() -> void:
	Ajustes.persist=false
	var carving := sample_arc(deg_to_rad(60.0),0.7,0.7,2.0)
	var bottom := sample_arc(deg_to_rad(70.0),1.3,0.6,2.0)
	var cutback := sample_arc(deg_to_rad(145.0),0.7,0.8,8.0)
	check(carving.get("kind","")=="carving","reconoce arco de carving")
	check(bottom.get("kind","")=="bottom_turn","bottom turn exige subir desde la parte baja")
	check(cutback.get("kind","")=="cutback","cutback exige volver hacia la rotura")
	check(sample_arc(2.0,1.3,0.5,8.0,false).is_empty(),"no puntúa sin desplazamiento")
	check(sample_arc(0,0.7,0.7,8.0).is_empty(),"no puntúa si solo se mantiene una tecla")
	check(sample_arc(2.0,1.3,0.5,8.0,true,false).is_empty(),"no puntúa fuera de la cara limpia")
	check(sample_arc(deg_to_rad(145.0),0.7,0.8,8.0,true,true,-1.0).get("kind","")=="cutback","cutback funciona en la dirección opuesta")
	check(sample_arc(TAU,0.7,0.7,8.0).is_empty(),"no premia círculos completos como cutbacks")
	var slow := sample_arc(1.0,0.7,0.7,2.0,true,true,1.0,30.0)
	var fast := sample_arc(1.0,0.7,0.7,2.0,true,true,1.0,120.0)
	check(slow.get("kind","")==fast.get("kind","") and absf(float(slow.get("angle",0))-float(fast.get("angle",0)))<0.04,"clasificación estable entre 30 y 120 pasos por segundo")
	var score := ScoreKeeper.new()
	score.award_maneuver(carving)
	score.award_maneuver(bottom)
	score.award_maneuver(cutback)
	check(score.turns==3 and score.combo==3,"maniobras usan el combo real")
	for frame in 60: score.step(1.0/60.0,7.0,0.9,2.0,false)
	for frame in 60: score.step(1.0/60.0,7.0,0.0,2.0,false)
	check(score.turns==3,"puntuación antigua desactivada evita contar dos veces")
	if not "--turns-unit-only" in OS.get_cmdline_user_args():
		game.surfer.maneuver_completed.connect(func(result): events.append(result))
		for kind in ["carving","bottom_turn","cutback"]:
			await real_turn(kind)
	print("[turns] RESULTADO: ","OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func real_turn(kind: String) -> void:
	events.clear()
	Perfil.set_style(1)
	game.start_play()
	game.set_physics_process(true)
	var w := game.wave
	Spots.apply_to_wave(Spots.get_spot(0),w)
	w.time=15.0
	w.update()
	var dir := w.peel_dir
	var ratio := 0.72
	var ahead := 4.0
	var velocity := Vector2(dir*8.0,w.speed*0.45)
	var steer := -dir*0.70
	var trim := 0.0
	var hold := 0.75
	if kind=="bottom_turn":
		ratio=1.15
		ahead=5.0
		velocity=Vector2(dir*5.2,6.0)
		steer=-dir*0.90
		hold=0.72
	elif kind=="cutback":
		ratio=0.70
		ahead=12.0
		velocity=Vector2(dir*10.0,w.speed*0.4)
		steer=dir*0.95
		trim=-0.25
		hold=1.65
	var x := w.peel_x+dir*ahead
	var z := w.crest_z+w.front_width*ratio
	var s := game.surfer
	s.reset_to(Vector3(x,w.height_at(x,z)+0.045,z),atan2(velocity.x,velocity.y))
	s.state=Surfer.State.RIDING
	s.hvel=velocity
	s.animator.jump_to("ride")
	game.score.reset()
	Controles.bot_enabled=true
	Controles.bot_paddle=false
	var captured := false
	for frame in 190:
		Controles.bot_stick=Vector2(steer if frame/60.0<hold else 0.0,trim)
		await get_tree().physics_frame
		if frame%15==0:
			print("[real turn] ",kind," t=",frame/60.0," u=",float(s.last_sample.get("u",0))/w.front_width," speed=",s.speed()," angle=",rad_to_deg(s.turns._angle)," back=",s.turns._went_back," state=",s.state)
		if not captured and frame>=int(hold*60.0*0.75) and s.state==Surfer.State.RIDING:
			captured=true
			await capture(kind+"_ingame",s,w)
		if not events.is_empty() or s.state!=Surfer.State.RIDING:
			break
	check(events.any(func(e): return e["kind"]==kind),"maniobra realizada con física y controles: "+kind+" -> "+str(events))
	check(game.score.turns==events.size(),"una puntuación por maniobra real: "+kind)
	if not events.is_empty():
		await get_tree().create_timer(0.12).timeout
		await capture(kind+"_resultado",s,w)
	Controles.bot_stick=Vector2.ZERO
	game.surfer.set_frozen(true)
	game.set_physics_process(false)

func capture(name_text: String, s: Surfer, w: WaveModel) -> void:
	if DisplayServer.get_name()=="headless": return
	var folder := "res://capturas/giros"
	DirAccess.make_dir_recursive_absolute(folder)
	var cam := game.cam
	var old := cam.global_transform
	cam.set_process(false)
	var p := s.global_position
	cam.look_at_from_position(p+Vector3(-w.peel_dir*2.0,1.8,2.8),p+Vector3(0,0.8,0))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join(name_text+".png"))
	if "--wake-shots" in OS.get_cmdline_user_args():
		var wake_folder := "res://capturas/estela/despues"
		DirAccess.make_dir_recursive_absolute(wake_folder)
		cam.look_at_from_position(p+Vector3(-w.peel_dir*2.7,3.6,3.5),p+Vector3(0,0.2,0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(wake_folder.path_join(name_text+"_estela.png"))
	cam.global_transform=old
	cam.set_process(true)
