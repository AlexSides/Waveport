extends Node

const STARTING_GOLD := 200
const DEFAULT_MAX_HEALTH := 50

const DEFAULT_ENEMY_PATHS: Array[String] = [
	"res://enemies/PiranhaSwarm.tscn",
	"res://enemies/PirateGunner.tscn",
	"res://enemies/PirateBrute.tscn"
]

const CARGO_SET_LIBRARY := {
	"powder": {
		"name": "Powder",
		"cards": ["chain_shot", "overload", "touch_up"]
	},
	"bulwark": {
		"name": "Bulwark",
		"cards": ["prepare", "hold_fast", "barricade"]
	},
	"blood": {
		"name": "Blood",
		"cards": ["blood_oath", "sacrifice", "blood_rush"]
	}
}

static func get_default_enemy_paths() -> Array[String]:
	return DEFAULT_ENEMY_PATHS.duplicate()

static func get_random_cargo_set_ids() -> Array[String]:
	var ids: Array[String] = []
	for set_id in CARGO_SET_LIBRARY.keys():
		ids.append(String(set_id))
	ids.shuffle()
	return ids

static func get_cargo_set(set_id: String) -> Dictionary:
	if CARGO_SET_LIBRARY.has(set_id):
		return Dictionary(CARGO_SET_LIBRARY[set_id])
	return {}

static func get_cargo_set_name(set_id: String) -> String:
	var data := get_cargo_set(set_id)
	return String(data.get("name", set_id.capitalize()))

static func get_cargo_set_cards(set_id: String) -> Array:
	var data := get_cargo_set(set_id)
	return Array(data.get("cards", []))
