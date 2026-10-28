class_name WaveModel
extends RefCounted
## Ola surfeable que avanza hacia la playa (+Z) y rompe de lado (peel).
##
## La misma fórmula está en shaders/wave_common.gdshaderinc. El script pasa al
## shader los valores derivados (cresta, punto de rotura, amplitud), así que la
## superficie visible y la que usa la física son la misma. Si cambias height_at()
## aquí, cambia wave_height() allí (tests/wave_parity.gd lo comprueba).

const G := 9.81

var height := 2.1          ## Altura de la cara (m).
var speed := 5.2           ## Velocidad de la ola hacia la playa (m/s).
var front_width := 3.1     ## Anchura de la cara (lado playa).
var back_width := 9.0      ## Anchura de la espalda (lado mar).
var start_z := -82.0       ## Posición de la cresta al empezar.
var break_z := -38.0       ## Donde empieza a romper.
var peel_x0 := 6.0         ## Pico de la ola.
var peel_dir := -1.0       ## -1: rompe hacia -X (una derecha, como La Punta de Montañita).
var peel_speed := 5.0      ## Velocidad del punto de rotura a lo largo de la ola.
var swell_amp := 0.10      ## Marejada de fondo.
## Olas de la misma serie que vienen detrás (0-2). No rompen: son líneas de mar de fondo.
var set_count := 0
## Separación entre olas de la serie (m): velocidad × periodo (unos 14 s en Ecuador).
var set_spacing := 70.0
var time := 0.0

# Valores derivados para el instante actual (los recalcula update()).
var crest_z := 0.0
var peel_x := 0.0
var started := 0.0         ## 0 antes de romper, 1 rompiendo.
var amp := 0.0             ## Altura base tras el asomeramiento y la orilla.
var set_amp1 := 0.0        ## Altura de la 2.ª y 3.ª ola de la serie.
var set_amp2 := 0.0


func reset() -> void:
	time = 0.0
	update()


func advance(delta: float) -> void:
	time += delta
	update()


func update() -> void:
	var d := derived_at(time)
	crest_z = d[0]
	peel_x = d[1]
	started = d[2]
	amp = d[3]
	set_amp1 = d[4]
	set_amp2 = d[5]


## Valores derivados en un instante cualquiera, sin modificar el estado
## (el agua los usa con el tiempo interpolado del fotograma).
## [cresta, punto de rotura, rompiendo, altura, altura 2.ª ola, altura 3.ª ola]
func derived_at(t: float) -> PackedFloat32Array:
	var cz := start_z + speed * t
	var t_break := (break_z - start_z) / speed
	var px := peel_x0 + peel_dir * peel_speed * maxf(0.0, t - t_break)
	var st := sstep(t_break - 0.5, t_break + 1.5, t)
	var a := _shoal(cz)
	var a1 := 0.6 * _shoal(cz - set_spacing) if set_count >= 1 else 0.0
	var a2 := 0.4 * _shoal(cz - 2.0 * set_spacing) if set_count >= 2 else 0.0
	return PackedFloat32Array([cz, px, st, a, a1, a2])


## Altura según dónde está la cresta: crece al llegar a la rompiente y se apaga en la orilla.
func _shoal(cz: float) -> float:
	return height * sstep(-100.0, -60.0, cz) * (1.0 - 0.75 * sstep(38.0, 64.0, cz))


static func sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Altura del agua en (x, z). Igual que wave_height() del shader.
func height_at(x: float, z: float) -> float:
	var ahead := (x - peel_x) * peel_dir
	var broken := started * sstep(0.5, -3.5, ahead)
	var q := (ahead - 1.5) / 4.0
	var peak := started * exp(-q * q)
	var shoulder := 1.0 - 0.55 * sstep(20.0, 75.0, absf(x - peel_x))
	var xm := -x * peel_dir  # en espejo: el cabo queda siempre en +xm
	var lateral := sstep(-160.0, -120.0, xm) * sstep(45.0, 25.0, xm)
	var a := amp * shoulder * lateral * (1.0 - 0.45 * broken) * (1.0 + 0.18 * peak)
	var wf := front_width * (1.0 - 0.3 * peak) * (1.0 + 0.9 * broken)
	var u := z - crest_z
	var w := wf if u > 0.0 else back_width
	var h := a * exp(-(u * u) / (w * w))
	# Resto de la serie: líneas que no rompen, con la misma forma que la ola sin romper.
	var sl := lateral * shoulder
	var u1 := u + set_spacing
	var w1 := front_width if u1 > 0.0 else back_width
	h += set_amp1 * sl * exp(-(u1 * u1) / (w1 * w1))
	var u2 := u + 2.0 * set_spacing
	var w2 := front_width if u2 > 0.0 else back_width
	h += set_amp2 * sl * exp(-(u2 * u2) / (w2 * w2))
	return h + swell_at(x, z)


func swell_at(x: float, z: float) -> float:
	return swell_amp * sin(0.23 * x + 0.31 * z - 1.3 * time) \
		+ swell_amp * 0.7 * sin(-0.17 * x + 0.41 * z - 1.7 * time)


## Datos de la superficie para la física.
## Devuelve: altura, normal, flujo del agua hacia la playa, espuma (0-1),
## perfil (0 en agua plana, 1 en la cresta) y distancia a la cresta (u > 0: en la cara).
func sample(x: float, z: float) -> Dictionary:
	var e := 0.2
	var h := height_at(x, z)
	var dx := (height_at(x + e, z) - height_at(x - e, z)) / (2.0 * e)
	var dz := (height_at(x, z + e) - height_at(x, z - e)) / (2.0 * e)
	var normal := Vector3(-dx, 1.0, -dz).normalized()
	var ahead := (x - peel_x) * peel_dir
	var broken := started * sstep(0.5, -3.5, ahead)
	var u := z - crest_z
	var w := front_width if u > 0.0 else back_width
	var profile := exp(-(u * u) / (w * w)) * clampf(amp / maxf(height, 0.01), 0.0, 1.0)
	var flow := speed * (0.72 * profile + 0.5 * broken * profile)
	return {
		"height": h,
		"normal": normal,
		"flow": flow,
		"broken": broken,
		"profile": profile,
		"u": u,
		"face_width": front_width,
	}
