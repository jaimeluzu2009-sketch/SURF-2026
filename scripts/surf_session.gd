class_name SurfSession
extends RefCounted
const PRESETS := [
	{"name": "Limpio", "height": 0.93, "wind": 0.15, "tide": -0.10, "period": 13.5},
	{"name": "Marea media", "height": 1.0, "wind": 0.35, "tide": 0.0, "period": 14.0},
	{"name": "Mar de fondo", "height": 1.08, "wind": 0.60, "tide": 0.16, "period": 15.0},
]
var index := 0
var number := 0
var base := {}
var condition := {}
func setup(spot: Dictionary, seed_value: int) -> void:
	base = spot
	index = posmod(seed_value, PRESETS.size())
	number = 0
func next(wave: WaveModel) -> void:
	condition = PRESETS[index].duplicate()
	var sizes := [0.94, 1.02, 1.07]
	var set_wave := number % 3
	Spots.apply_to_wave(base, wave)
	wave.height *= float(condition["height"]) * sizes[set_wave]
	wave.tide = condition["tide"]
	wave.wind_chop = condition["wind"]
	wave.swell_amp *= 0.75 + wave.wind_chop
	wave.set_spacing = wave.speed * float(condition["period"])
	wave.start_z = -82.0 - (14.0 if set_wave == 0 else 0.0)
	wave.reset()
	number += 1
func description() -> String:
	return "%s · ola %d/3 · %.0f s · marea %+.2f m" % [condition["name"], (number - 1) % 3 + 1, condition["period"], condition["tide"]]
