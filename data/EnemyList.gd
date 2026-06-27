extends RefCounted

const ENEMY_DATA := {
	"shellback_crab": {
		"display_name": "Shellback Crab",
		"max_health": 11,
		"spawn_scene": "res://enemies/SeaMonster.tscn",
		"ui_color": Color(0.737255, 0.305882, 0.286275, 1),
		"initial_flags": {
			"shell_guard": true
		},
		"pattern": [
			{
				"key": "claw_swipe",
				"type": "attack",
				"damage": 4,
				"hits": 1,
				"log": "%s swipes for %d damage!"
			},
			{
				"key": "shell_up",
				"type": "guard",
				"block": 9,
				"label": "Shell Up",
				"log": "%s tucks into its shell."
			},
			{
				"key": "guarded_snap",
				"type": "attack",
				"damage": 6,
				"hits": 1,
				"gain_block_after": 5,
				"log": "%s snaps for %d damage!"
			},
			{
				"key": "crushing_claw",
				"type": "attack",
				"damage": 8,
				"hits": 1,
				"log": "%s crushes for %d damage!"
			}
		]
	},

	"jellyfish": {
		"display_name": "Jellyfish",
		"max_health": 14,
		"spawn_scene": "res://enemies/SeaMonster.tscn",
		"ui_color": Color(0.894118, 0.537255, 0.745098, 1),
		"pattern": [
			{
				"key": "sting",
				"type": "attack",
				"damage": 5,
				"hits": 1,
				"log": "%s stings for %d damage!"
			},
			{
				"key": "shock_burst",
				"type": "attack",
				"damage": 5,
				"hits": 2,
				"log": "%s pulses %d times for %d damage each!"
			}
		],
		"side_pattern": [
			{
				"key": "shield_the_shoal",
				"type": "defend_allies",
				"block": 4,
				"same_enemy_id_only": true,
				"intent_text": "+4 Team Block"
			}
		]
	},

	"eel": {
		"display_name": "Reef Eel",
		"max_health": 11,
		"spawn_scene": "res://enemies/SeaMonster.tscn",
		"ui_color": Color(0.862745, 0.772549, 0.290196, 1),
		"pattern": [
			{
				"key": "charge_bite",
				"type": "attack",
				"damage": 4,
				"hits": 1,
				"gain_combat_damage_bonus_after": 1,
				"log": "%s strikes for %d damage and surges with power!"
			},
			{
				"key": "thrash",
				"type": "attack",
				"damage": 2,
				"hits": 3,
				"log": "%s thrashes %d times for %d damage each!"
			}
		]
	},

	"reef_shark": {
		"display_name": "Reef Shark",
		"max_health": 38,
		"spawn_scene": "res://enemies/SeaMonster.tscn",
		"ui_color": Color(0.431373, 0.556863, 0.647059, 1),
		"initial_flags": {
			"dive_ready": false,
			"shark_sequence_step": "idle",
			"submerged": false,
			"untargetable": false
		},
		"weighted_actions": [
			{
				"key": "bite",
				"type": "attack",
				"damage": 8,
				"hits": 1,
				"weight": 1.6,
				"repeat_weight": 1.2,
				"log": "%s bites for %d damage!",
				"set_flags_after": {
					"dive_ready": true,
					"shark_sequence_step": "idle"
				}
			},
			{
				"key": "dive",
				"type": "buff",
				"label": "Dive",
				"intent_text": "Dive",
				"weight": 0.9,
				"repeat_weight": 0.0,
				"min_turn": 2,
				"requires_flags": {
					"dive_ready": true,
					"shark_sequence_step": "idle",
					"submerged": false,
					"untargetable": false
				},
				"log": "%s dives beneath the waves!",
				"set_flags_after": {
					"dive_ready": false,
					"shark_sequence_step": "dived",
					"submerged": true,
					"untargetable": true
				},
				"queue_next_action_key_after": "surface_strike"
			},
			{
				"key": "surface_strike",
				"type": "attack",
				"damage": 18,
				"hits": 1,
				"weight": 0.0,
				"requires_flags": {
					"shark_sequence_step": "dived",
					"submerged": true,
					"untargetable": true
				},
				"log": "%s surges up for %d damage!",
				"set_flags_before": {
					"submerged": false,
					"untargetable": false
				},
				"set_flags_after": {
					"shark_sequence_step": "resting"
				},
				"queue_next_action_key_after": "rest"
			},
			{
				"key": "rest",
				"type": "buff",
				"label": "Rest",
				"intent_text": "Rest",
				"weight": 0.0,
				"requires_flags": {
					"shark_sequence_step": "resting",
					"submerged": false,
					"untargetable": false
				},
				"log": "%s circles below and regathers itself.",
				"set_flags_after": {
					"shark_sequence_step": "idle",
					"dive_ready": false
				}
			}
		]
	},

	"starfish": {
		"display_name": "Starfish",
		"max_health": 20,
		"spawn_scene": "res://enemies/SeaMonster.tscn",
		"ui_color": Color(0.933333, 0.619608, 0.396078, 1),
		"weighted_actions": [
			{
				"key": "basic_attack",
				"type": "attack",
				"damage": 5,
				"hits": 1,
				"weight": 1.4,
				"repeat_weight": 1.0,
				"log": "%s lashes out for %d damage!"
			},
			{
				"key": "needle_flurry",
				"type": "attack",
				"damage": 1,
				"hits": 5,
				"weight": 1.0,
				"repeat_weight": 0.0,
				"requires_last_action_not": "needle_flurry",
				"log": "%s scatters needles %d times for %d damage each!"
			},
			{
				"key": "regrow",
				"type": "buff",
				"label": "Regrow",
				"intent_text": "Regrow",
				"weight": 0.8,
				"repeat_weight": 0.0,
				"min_turn": 2,
				"requires_last_action_not": "regrow",
				"heal_percent_max_after": 30,
				"gain_combat_damage_bonus_after": 1,
				"log": "%s regrows lost limbs."
			}
		]
	},

	"piranha_a": {
		"display_name": "Piranha A",
		"max_health": 7,
		"spawn_scene": "res://enemies/SeaMonster.tscn",
		"ui_color": Color(0.337255, 0.713726, 0.352941, 1),
		"pattern": [
			{
				"key": "nibble_3",
				"type": "attack",
				"damage": 3,
				"hits": 1,
				"log": "%s bites for %d damage!"
			},
			{
				"key": "nibble_4",
				"type": "attack",
				"damage": 4,
				"hits": 1,
				"log": "%s bites for %d damage!"
			},
			{
				"key": "nibble_5",
				"type": "attack",
				"damage": 5,
				"hits": 1,
				"log": "%s bites for %d damage!"
			}
		],
		"side_pattern": [
			{
				"key": "side_bite",
				"type": "attack",
				"damage": 2,
				"hits": 1,
				"log": "%s snaps from the side for %d damage!"
			}
		]
	},

	"piranha_b": {
		"display_name": "Piranha B",
		"max_health": 12,
		"spawn_scene": "res://enemies/SeaMonster.tscn",
		"ui_color": Color(0.266667, 0.658824, 0.607843, 1),
		"pattern": [
			{
				"key": "wait_1",
				"type": "buff",
				"label": "Wait",
				"intent_text": "Wait"
			},
			{
				"key": "lunge_9",
				"type": "attack",
				"damage": 9,
				"hits": 1,
				"log": "%s lunges for %d damage!"
			},
			{
				"key": "wait_2",
				"type": "buff",
				"label": "Wait",
				"intent_text": "Wait"
			},
			{
				"key": "lunge_9_repeat",
				"type": "attack",
				"damage": 9,
				"hits": 1,
				"log": "%s lunges for %d damage!"
			}
		],
		"side_pattern": [
			{
				"key": "side_bite",
				"type": "attack",
				"damage": 2,
				"hits": 1,
				"log": "%s snaps from the side for %d damage!"
			}
		]
	},

	"piranha_c": {
		"display_name": "Piranha C",
		"max_health": 8,
		"spawn_scene": "res://enemies/SeaMonster.tscn",
		"ui_color": Color(0.301961, 0.517647, 0.843137, 1),
		"pattern": [
			{
				"key": "double_nip",
				"type": "attack",
				"damage": 2,
				"hits": 2,
				"log": "%s bites %d times for %d damage each!"
			},
			{
				"key": "double_chomp",
				"type": "attack",
				"damage": 3,
				"hits": 2,
				"log": "%s bites %d times for %d damage each!"
			}
		],
		"side_pattern": [
			{
				"key": "side_bite",
				"type": "attack",
				"damage": 2,
				"hits": 1,
				"log": "%s snaps from the side for %d damage!"
			}
		]
	},

	"piranha_swarm": {
		"display_name": "Piranha Swarm",
		"max_health": 8,
		"spawn_scene": "res://enemies/PiranhaSwarm.tscn",
		"ui_color": Color(0.266667, 0.658824, 0.607843, 1),
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

static func get_ui_color(enemy_id: String) -> Color:
	var data: Dictionary = get_enemy_data(enemy_id)
	return Color(data.get("ui_color", Color(0.443137, 0.65098, 0.631373, 1)))

static func get_max_health(enemy_id: String) -> int:
	var data: Dictionary = get_enemy_data(enemy_id)
	return int(data.get("max_health", 1))

static func get_pattern(enemy_id: String) -> Array:
	var data: Dictionary = get_enemy_data(enemy_id)
	return Array(data.get("pattern", [])).duplicate(true)

static func get_side_pattern(enemy_id: String) -> Array:
	var data: Dictionary = get_enemy_data(enemy_id)
	var side_pattern: Array = Array(data.get("side_pattern", []))
	if side_pattern.is_empty():
		return get_pattern(enemy_id)
	return side_pattern.duplicate(true)

static func get_weighted_actions(enemy_id: String) -> Array:
	var data: Dictionary = get_enemy_data(enemy_id)
	return Array(data.get("weighted_actions", [])).duplicate(true)

static func get_side_weighted_actions(enemy_id: String) -> Array:
	var data: Dictionary = get_enemy_data(enemy_id)
	var side_actions: Array = Array(data.get("side_weighted_actions", []))
	if side_actions.is_empty():
		return get_weighted_actions(enemy_id)
	return side_actions.duplicate(true)
