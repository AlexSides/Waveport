extends RefCounted

const ENEMY_DATA := {
	"piranha_swarm": {
		"display_name": "Piranha Swarm",
		"max_health": 8,
		"spawn_scene": "res://enemies/PiranhaSwarm.tscn",
		"weighted_actions": [
			{
				"key": "bite_flurry",
				"type": "attack",
				"damage": 1,
				"hits": 5,
				"weight": 1.0,
				"repeat_weight": 0.67,
				"log": "%s bites %d times for %d damage each!"
			},
			{
				"key": "swarm",
				"type": "attack",
				"damage": 2,
				"hits": 3,
				"weight": 1.0,
				"repeat_weight": 0.67,
				"log": "%s swarms %d times for %d damage each!"
			}
		],
		"side_weighted_actions": [
			{
				"key": "side_bite",
				"type": "attack",
				"damage": 2,
				"hits": 1,
				"weight": 1.0,
				"repeat_weight": 1.0,
				"log": "%s snaps from the side for %d damage!"
			}
		]
	},

	"pirate_gunner": {
		"display_name": "Pirate Gunner",
		"max_health": 20,
		"spawn_scene": "res://enemies/PirateGunner.tscn",
		"weighted_actions": [
			{
				"key": "brace",
				"type": "defend",
				"block": 4,
				"weight": 1.0,
				"repeat_weight": 0.7
			},
			{
				"key": "pistol_shot",
				"type": "attack",
				"damage": 8,
				"hits": 1,
				"weight": 1.2,
				"repeat_weight": 1.0,
				"log": "%s fires a shot for %d damage!"
			},
			{
				"key": "aimed_shot",
				"type": "attack",
				"damage": 5,
				"hits": 2,
				"weight": 0.8,
				"repeat_weight": 0.6,
				"min_turn": 2,
				"log": "%s fires %d aimed shots for %d damage each!"
			}
		]
	},

	"pirate_brute": {
		"display_name": "Pirate Brute",
		"max_health": 40,
		"spawn_scene": "res://enemies/PirateBrute.tscn",
		"weighted_actions": [
			{
				"key": "slam",
				"type": "attack",
				"damage": 8,
				"hits": 1,
				"weight": 2.0,
				"repeat_weight": 1.5,
				"max_health_percent_gte": 51,
				"log": "%s slams for %d damage!"
			},
			{
				"key": "brace",
				"type": "defend",
				"block": 6,
				"weight": 1.0,
				"repeat_weight": 0.8
			},
			{
				"key": "crush",
				"type": "attack",
				"damage": 14,
				"hits": 1,
				"weight": 2.0,
				"repeat_weight": 1.2,
				"min_health_percent_lte": 50,
				"log": "%s crushes for %d damage!"
			}
		]
	}
}

static func get_enemy_data(enemy_id: String) -> Dictionary:
	if ENEMY_DATA.has(enemy_id):
		return Dictionary(ENEMY_DATA[enemy_id])
	return {}

static func get_scene_path(enemy_id: String) -> String:
	var data: Dictionary = get_enemy_data(enemy_id)
	return String(data.get("spawn_scene", ""))

static func get_display_name(enemy_id: String) -> String:
	var data: Dictionary = get_enemy_data(enemy_id)
	return String(data.get("display_name", enemy_id))

static func get_max_health(enemy_id: String) -> int:
	var data: Dictionary = get_enemy_data(enemy_id)
	return int(data.get("max_health", 1))

static func get_pattern(enemy_id: String) -> Array:
	var data: Dictionary = get_enemy_data(enemy_id)
	return Array(data.get("pattern", [])).duplicate(true)

static func get_weighted_actions(enemy_id: String) -> Array:
	var data: Dictionary = get_enemy_data(enemy_id)
	return Array(data.get("weighted_actions", [])).duplicate(true)

static func get_side_weighted_actions(enemy_id: String) -> Array:
	var data: Dictionary = get_enemy_data(enemy_id)
	var side_actions: Array = Array(data.get("side_weighted_actions", []))
	if side_actions.is_empty():
		return get_weighted_actions(enemy_id)
	return side_actions.duplicate(true)
