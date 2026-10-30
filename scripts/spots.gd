class_name Spots
extends RefCounted
## Spots de la costa ecuatoriana. Cada uno define su ola, su escenario y su luz.
## Para añadir otro, copia una entrada y cambia los valores.
##
## Coordenadas: la ola siempre avanza hacia la playa (+Z). "dir" es hacia dónde
## rompe: -1 hacia -X (una derecha para quien mira a la playa), +1 una izquierda.
## El escenario se construye en espejo según "dir", así que el cabo siempre queda
## del lado donde nace la ola.
##
## Referencias: Surfline y Surf-Forecast (agua 27-28 °C, mar de fondo del SO de
## ~14 s, olas de 0,9 a 1,8 m), la guía de La FAE de Surf-Forecast y vídeos de
## los tres spots aportados por el autor.

const LIST := [
	{
		"id": "montanita",
		"name": "Montañita",
		"zone": "La Punta",
		"desc": "Derecha de punta, larga y noble, que abre junto a las rocas bajo el pueblo.",
		"level": 2,
		"dir": -1.0,
		"height": 2.1, "speed": 5.2, "front_width": 3.1, "back_width": 9.0,
		"peel_speed": 5.0, "break_z": -38.0, "swell": 0.10, "sets": 1,
		"scenery": "point",
		# Cielo cubierto (garúa), como en buena parte del vídeo.
		"sun_dir": Vector3(-0.35, -0.62, -0.70), "sun_color": Color(0.96, 0.96, 0.95), "sun_energy": 0.85,
		"sky_top": Color(0.46, 0.53, 0.60), "sky_horizon": Color(0.74, 0.77, 0.79), "fog": 0.0018,
		"deep": Color(0.05, 0.19, 0.23), "shallow": Color(0.12, 0.37, 0.37), "face": Color(0.20, 0.50, 0.45),
		"time": "Mañana nublada",
		# Interfaz: colores propios, motivo y desafíos.
		"ui_main": Color(0.96, 0.45, 0.33), "ui_dark": Color(0.30, 0.10, 0.10), "ui_sky": Color(0.99, 0.70, 0.45),
		"motif": 0, "tagline": "La punta que hizo famoso al Ecuador",
		"challenges": [
			{"id": "m1", "text": "Completa la ola", "type": "complete", "value": 1},
			{"id": "m2", "text": "Suma 2.500 puntos", "type": "score", "value": 2500},
			{"id": "m3", "text": "Combo ×4", "type": "combo", "value": 4},
		],
	},
	{
		"id": "rinconada",
		"name": "La Rinconada",
		"zone": "Manabí",
		"desc": "Derecha gruesa y tubular frente a acantilados secos. La preferida de los bodyboarders de Manta.",
		"level": 3,
		"dir": -1.0,
		"height": 2.3, "speed": 5.0, "front_width": 2.6, "back_width": 8.5,
		"peel_speed": 5.0, "break_z": -37.0, "swell": 0.12, "sets": 1,
		"scenery": "cliffs",
		"sun_dir": Vector3(-0.30, -0.70, -0.65), "sun_color": Color(0.97, 0.96, 0.93), "sun_energy": 0.95,
		"sky_top": Color(0.50, 0.57, 0.64), "sky_horizon": Color(0.80, 0.82, 0.82), "fog": 0.0016,
		"deep": Color(0.03, 0.20, 0.20), "shallow": Color(0.08, 0.40, 0.34), "face": Color(0.12, 0.52, 0.40),
		"time": "Nublado, mar de fondo del suroeste",
		"ui_main": Color(0.86, 0.66, 0.38), "ui_dark": Color(0.26, 0.18, 0.10), "ui_sky": Color(0.80, 0.82, 0.80),
		"motif": 1, "tagline": "Tubos gruesos bajo los acantilados de Manabí",
		"challenges": [
			{"id": "r1", "text": "Completa la ola", "type": "complete", "value": 1},
			{"id": "r2", "text": "Alcanza 28 km/h", "type": "speed", "value": 28},
			{"id": "r3", "text": "10 s en el pocket", "type": "pocket", "value": 10},
		],
	},
	{
		"id": "fae",
		"name": "La FAE",
		"zone": "Salinas",
		# Según Surf-Forecast: izquierda de punta expuesta, muy consistente, mejor con mar de fondo
		# del suroeste y viento del noreste; peligros: acceso privado (base aérea) y corrientes.
		"desc": "Izquierda de punta frente a la base aérea, sobre roca con algas. Muy consistente y con corrientes.",
		"level": 2,
		"dir": 1.0,
		"height": 1.6, "speed": 4.9, "front_width": 3.0, "back_width": 9.0,
		"peel_speed": 4.6, "break_z": -37.0, "swell": 0.10, "sets": 2,
		"scenery": "base",
		"sun_dir": Vector3(0.30, -0.72, -0.62), "sun_color": Color(1.0, 0.97, 0.90), "sun_energy": 1.35,
		"sky_top": Color(0.20, 0.42, 0.78), "sky_horizon": Color(0.70, 0.80, 0.90), "fog": 0.0009,
		"deep": Color(0.02, 0.16, 0.34), "shallow": Color(0.05, 0.40, 0.52), "face": Color(0.10, 0.55, 0.62),
		"time": "Sol, varias líneas de olas",
		"ui_main": Color(0.16, 0.62, 0.86), "ui_dark": Color(0.04, 0.14, 0.28), "ui_sky": Color(0.55, 0.80, 0.96),
		"motif": 2, "tagline": "La izquierda de Salinas frente a la base aérea",
		"challenges": [
			{"id": "f1", "text": "Completa la ola", "type": "complete", "value": 1},
			{"id": "f2", "text": "Recorre 110 m", "type": "distance", "value": 110},
			{"id": "f3", "text": "Combo ×5", "type": "combo", "value": 5},
		],
	},
]


static func get_spot(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]


static func apply_to_wave(spot: Dictionary, wave: WaveModel) -> void:
	wave.peel_dir = spot["dir"]
	wave.height = spot["height"]
	wave.speed = spot["speed"]
	wave.front_width = spot["front_width"]
	wave.back_width = spot["back_width"]
	wave.peel_speed = spot["peel_speed"]
	wave.break_z = spot["break_z"]
	wave.swell_amp = spot["swell"]
	wave.set_count = spot.get("sets", 0)
	wave.set_spacing = wave.speed * 14.0  # periodo típico del mar de fondo en Ecuador
	# El pico está siempre 6 m "detrás" del lineup, del lado del cabo.
	wave.peel_x0 = -6.0 * wave.peel_dir
	wave.tide = 0.0
	wave.tube_strength = 1.0 if spot["id"] == "rinconada" else 0.0
	wave.reset()


## Posición de espera: un poco hacia el hombro desde el pico.
static func lineup(spot: Dictionary) -> Vector3:
	return Vector3(1.0 * spot["dir"], 0.0, -43.0)
