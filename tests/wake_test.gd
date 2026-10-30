extends Node
var failures: Array[String] = []
var game: Game
func check(ok: bool, text: String) -> void:
	print("[wake] ","OK " if ok else "FAIL ",text)
	if not ok: failures.append(text)
func _ready() -> void:
	game=get_parent()
	call_deferred("run")
func run() -> void:
	Ajustes.persist=false
	game.start_play()
	game.set_physics_process(false)
	var s := game.surfer
	s.set_frozen(true)
	var sample := {"normal":Vector3.UP,"height":0.0,"flow":0.0,"profile":0.7,"u":1.5,"broken":0.0,"face_width":2.3}
	s.state=Surfer.State.RIDING
	s.hvel=Vector2(0,1)
	s.rail_load=0
	s._update_visual(0.016,sample)
	check(not s.wake.emitting,"sin salpicaduras al estar casi parado")
	s.hvel=Vector2(0,8)
	s._update_visual(0.016,sample)
	var straight_size := s.wake.scale_amount_max
	var straight_velocity := s.wake.initial_velocity_max
	s.rail_load=1.0
	s._update_visual(0.016,sample)
	check(s.wake.emitting and s.wake.scale_amount_max>straight_size and s.wake.initial_velocity_max>straight_velocity,"más proyección en giros cargados que al avanzar recto")
	check(s.wake.position.x>0 and s.wake.direction.x>0,"emisión desde el canto exterior positivo")
	s.rail_load=-1
	s._update_visual(0.016,sample)
	check(s.wake.position.x<0 and s.wake.direction.x<0,"abanico cambia de lado al invertir el giro")
	check((s.wake.mesh as QuadMesh).size.x<(s.wake.mesh as QuadMesh).size.y,"gotas alargadas en vez de discos grandes")
	check(s.wake.lifetime<=0.4 and s.wake.local_coords==false,"gotas breves quedan en el mundo y no siguen pegadas a la tabla")
	for quality in 3:
		Ajustes.set_quality(quality)
		check(s.wake.amount<=32 and s.wake.amount>=6,"presupuesto de partículas calidad %d" % quality)
	s._wake.clear()
	s._wake_loads.clear()
	s._wake_timer=0
	s.state=Surfer.State.RIDING
	s.hvel=Vector2(0,8)
	for frame in 18:
		s.global_position.x+=0.7
		s._update_visual(0.1,sample)
		s._record_wake(0.1)
	var points := s.wake_points()
	var loads := s.wake_loads()
	check(points.size()==12 and loads.size()==points.size(),"historia acotada y carga de canto sincronizada")
	check(points[points.size()-1].z>points[0].z and points[0].z>=0,"edad de espuma ordenada")
	check(loads[0]<0,"la estela conserva el lado del giro")
	var tail: Vector3 = s.visual.global_transform*Vector3(0,0,-0.65)
	check(Vector2(points[0].x,points[0].y).distance_to(Vector2(tail.x,tail.z))<0.001,"espuma nace en la cola real")
	var count := points.size()
	s.hvel=Vector2.ZERO
	for frame in 3: s._record_wake(0.1)
	check(s.wake_points().size()==count,"no acumula espuma al quedarse parado")
	game.water.set_board(s.global_position,0,false,s.wake_points(),s.wake_loads(),Vector2(0,1),s.rail_load)
	check(int(game.water._mat.get_shader_parameter("wake_count"))==count,"espuma anterior permanece al perder contacto con el agua")
	var bounds: Vector4 = game.water._mat.get_shader_parameter("wake_bounds")
	check(bounds.z-bounds.x<20.0 and bounds.w-bounds.y<10.0,"shader limitado a la zona local de la estela")
	s.state=Surfer.State.WIPEOUT
	s._update_visual(0.016,sample)
	check(not s.wake.emitting,"deja de emitir al caerse")
	for frame in 25: s._record_wake(0.1)
	check(s.wake_points().is_empty() and s.wake_loads().is_empty(),"historia desaparece después de 2,2 segundos")
	s.reset_to(s.global_position,0)
	check(s.wake_points().is_empty() and s.wake_loads().is_empty(),"reiniciar no deja segmentos antiguos")
	print("[wake] RESULTADO: ","OK" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
