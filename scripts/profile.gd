extends Node
## Autoload "Perfil": carrera del jugador (experiencia y nivel), récords por spot,
## desafíos cumplidos, logros y personalización. Se guarda en user://perfil.cfg.

signal changed

const PATH := "user://perfil.cfg"

## Personalización. "level" es el nivel de carrera que la desbloquea.
const WETSUITS := [
	{"id": "negro", "name": "Negro clásico", "color": Color(0.09, 0.095, 0.105), "level": 1},
	{"id": "pacifico", "name": "Azul Pacífico", "color": Color(0.05, 0.16, 0.30), "level": 1},
	{"id": "coral", "name": "Coral", "color": Color(0.55, 0.16, 0.12), "level": 3},
	{"id": "arena", "name": "Arena", "color": Color(0.48, 0.40, 0.28), "level": 5},
]
const ACCENTS := [
	{"id": "amarillo", "name": "Amarillo Ecuador", "color": Color(0.98, 0.80, 0.10), "level": 1},
	{"id": "turquesa", "name": "Turquesa", "color": Color(0.10, 0.70, 0.68), "level": 1},
	{"id": "coral", "name": "Coral", "color": Color(0.96, 0.42, 0.33), "level": 2},
	{"id": "blanco", "name": "Blanco", "color": Color(0.92, 0.92, 0.9), "level": 4},
]
const DECKS := [
	{"id": "blanco", "name": "Blanco", "color": Color(0.95, 0.94, 0.90), "level": 1},
	{"id": "arena", "name": "Arena", "color": Color(0.86, 0.76, 0.58), "level": 2},
	{"id": "turquesa", "name": "Turquesa", "color": Color(0.55, 0.85, 0.82), "level": 4},
]
const BOTTOMS := [
	{"id": "turquesa", "name": "Turquesa", "color": Color(0.30, 0.72, 0.76), "level": 1},
	{"id": "coral", "name": "Coral", "color": Color(0.94, 0.45, 0.36), "level": 1},
	{"id": "pacifico", "name": "Azul Pacífico", "color": Color(0.08, 0.28, 0.55), "level": 3},
	{"id": "atardecer", "name": "Atardecer", "color": Color(0.98, 0.62, 0.22), "level": 6},
]
const SLOTS := {"wetsuit": WETSUITS, "accent": ACCENTS, "deck": DECKS, "bottom": BOTTOMS}

const ACHIEVEMENTS := [
	{"id": "primera", "name": "Primera ola", "desc": "Completa una ola en cualquier spot."},
	{"id": "trotamundos", "name": "Ruta del Spondylus", "desc": "Completa una ola en los tres spots."},
	{"id": "combo6", "name": "Encadenado", "desc": "Consigue un combo ×6."},
	{"id": "velocista", "name": "Velocista", "desc": "Supera los 30 km/h."},
	{"id": "pocket", "name": "Dueño del pocket", "desc": "Pasa 12 s en el pocket en una misma ola."},
	{"id": "maraton", "name": "Maratón", "desc": "Recorre 1.000 m en total."},
	{"id": "constancia", "name": "Constancia", "desc": "Ponte de pie en 10 olas."},
	{"id": "nivel5", "name": "Local de Santa Elena", "desc": "Llega al nivel 5."},
]

var xp := 0
var waves_ridden := 0
var waves_completed := 0
var total_distance := 0.0
## records[spot_id] = {score, distance, time, speed, combo}
var records := {}
## challenges_done[spot_id] = [ids]
var challenges_done := {}
var achievements := {}
var look := {"wetsuit": "negro", "accent": "amarillo", "deck": "blanco", "bottom": "turquesa"}


func _ready() -> void:
	_load()


# ------------------------------------------------------------------ nivel

static func xp_for_level(level: int) -> int:
	# Experiencia total necesaria para alcanzar ese nivel (nivel 1 = 0).
	var total := 0
	for l in range(1, level):
		total += 500 + 250 * (l - 1)
	return total


func level() -> int:
	var l := 1
	while xp >= xp_for_level(l + 1):
		l += 1
	return l


## Progreso dentro del nivel actual (0-1).
func level_progress() -> float:
	var l := level()
	var a := xp_for_level(l)
	var b := xp_for_level(l + 1)
	return float(xp - a) / float(b - a)


# ------------------------------------------------------------------ personalización

func item(slot: String, id: String) -> Dictionary:
	for it in SLOTS[slot]:
		if it["id"] == id:
			return it
	return SLOTS[slot][0]


func look_color(slot: String) -> Color:
	return item(slot, look[slot])["color"]


func unlocked(it: Dictionary) -> bool:
	return level() >= int(it["level"])


func set_look(slot: String, id: String) -> void:
	if not unlocked(item(slot, id)):
		return
	look[slot] = id
	_save()
	changed.emit()


# ------------------------------------------------------------------ desafíos

## ¿Cumple el desafío con las estadísticas de una ola?
static func challenge_met(ch: Dictionary, stats: Dictionary) -> bool:
	match ch["type"]:
		"complete":
			return stats["success"]
		"score":
			return stats["score"] >= ch["value"]
		"combo":
			return stats["combo"] >= ch["value"]
		"speed":
			return stats["speed"] * 3.6 >= ch["value"]
		"distance":
			return stats["distance"] >= ch["value"]
		"pocket":
			return stats["pocket"] >= ch["value"]
	return false


func challenge_is_done(spot_id: String, ch_id: String) -> bool:
	return ch_id in challenges_done.get(spot_id, [])


func record(spot_id: String) -> Dictionary:
	return records.get(spot_id, {})


# ------------------------------------------------------------------ fin de ola

## Registra una ola y devuelve lo conseguido:
## {xp, level_before, level_after, new_record, challenges: [textos], achievements: [nombres]}
func record_ride(spot: Dictionary, stats: Dictionary) -> Dictionary:
	var sid: String = spot["id"]
	var out := {"xp": 0, "level_before": level(), "new_record": false, "challenges": [], "achievements": []}
	if stats["time"] > 0.5:
		waves_ridden += 1
	if stats["success"]:
		waves_completed += 1
	total_distance += stats["distance"]

	var gained := int(stats["score"] / 10) + (150 if stats["success"] else 0)
	for ch in spot.get("challenges", []):
		if not challenge_is_done(sid, ch["id"]) and challenge_met(ch, stats):
			var lst: Array = challenges_done.get(sid, [])
			lst.append(ch["id"])
			challenges_done[sid] = lst
			gained += 200
			out["challenges"].append(ch["text"])

	var rec: Dictionary = records.get(sid, {})
	if stats["score"] > rec.get("score", 0):
		out["new_record"] = rec.has("score")
		rec["score"] = stats["score"]
	rec["distance"] = maxf(rec.get("distance", 0.0), stats["distance"])
	rec["time"] = maxf(rec.get("time", 0.0), stats["time"])
	rec["speed"] = maxf(rec.get("speed", 0.0), stats["speed"])
	rec["combo"] = maxi(rec.get("combo", 1), stats["combo"])
	if stats["success"]:
		rec["completed"] = true
	records[sid] = rec

	xp += gained
	out["xp"] = gained
	out["level_after"] = level()

	var checks := {
		"primera": waves_completed >= 1,
		"trotamundos": Spots.LIST.all(func(s): return records.get(s["id"], {}).get("completed", false)),
		"combo6": stats["combo"] >= 6,
		"velocista": stats["speed"] * 3.6 >= 30.0,
		"pocket": stats["pocket"] >= 12.0,
		"maraton": total_distance >= 1000.0,
		"constancia": waves_ridden >= 10,
		"nivel5": level() >= 5,
	}
	for a in ACHIEVEMENTS:
		if checks[a["id"]] and not achievements.has(a["id"]):
			achievements[a["id"]] = Time.get_unix_time_from_system()
			out["achievements"].append(a["name"])
	_save()
	changed.emit()
	return out


# ------------------------------------------------------------------ guardado

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	xp = cfg.get_value("carrera", "xp", 0)
	waves_ridden = cfg.get_value("carrera", "olas", 0)
	waves_completed = cfg.get_value("carrera", "completadas", 0)
	total_distance = cfg.get_value("carrera", "distancia", 0.0)
	records = cfg.get_value("carrera", "records", {})
	challenges_done = cfg.get_value("carrera", "desafios", {})
	achievements = cfg.get_value("carrera", "logros", {})
	var saved: Dictionary = cfg.get_value("aspecto", "look", {})
	for k in saved:
		if look.has(k):
			look[k] = saved[k]


func _save() -> void:
	if not Ajustes.persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("carrera", "xp", xp)
	cfg.set_value("carrera", "olas", waves_ridden)
	cfg.set_value("carrera", "completadas", waves_completed)
	cfg.set_value("carrera", "distancia", total_distance)
	cfg.set_value("carrera", "records", records)
	cfg.set_value("carrera", "desafios", challenges_done)
	cfg.set_value("carrera", "logros", achievements)
	cfg.set_value("aspecto", "look", look)
	cfg.save(PATH)
