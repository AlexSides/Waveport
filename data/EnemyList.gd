extends RefCounted

const ENEMY_DATA := {
	"shellback_crab": {
		"display_name": "Shellback Crab",
		"max_health": 11,
		"spawn_scene": "res://enemies/SeaMonster.tscn",
		"texture_path": "res://assets/enemies/crab_red.png",
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
		"texture_path": "res://assets/enemies/jellyfish_purple.png",
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
		"texture_path": "res://assets/enemies/electric_eel_blue.png",
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
		"texture_path": "res://assets/enemies/piranha_blue_d.png",
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
		"texture_path": "res://assets/enemies/starfish_blue.png",
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
		"texture_path": "res://assets/enemies/piranha_blue_a.png",
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
		"texture_path": "res://assets/enemies/piranha_blue_b.png",
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
		"texture_path": "res://assets/enemies/piranha_blue_c.png",
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
		"texture_path": "res://assets/enemies/piranha_blue_a.png",
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

	"pirate_skiff": {
		"display_name": "Pirate Skiff",
		"faction": "pirate",
		"max_health": 12,
		"spawn_scene": "res://enemies/PirateShip.tscn",
		"ui_color": Color(0.55, 0.42, 0.28, 1),
		"texture_path": "res://assets/enemies/pirate_skiff.png",
		"pattern": [
			{
				"key": "quick_shot",
				"type": "attack",
				"damage": 4,
				"hits": 1,
				"log": "%s snaps off a quick shot for %d damage!"
			},
			{
				"key": "patch_hull",
				"type": "guard",
				"block": 5,
				"label": "Patch Hull",
				"log": "%s patches its hull."
			},
			{
				"key": "cheap_volley",
				"type": "attack",
				"damage": 3,
				"hits": 2,
				"log": "%s fires a cheap volley %d times for %d damage each!"
			}
		]
	},

	"raider_cutter": {
		"display_name": "Raider Cutter",
		"faction": "pirate",
		"max_health": 22,
		"spawn_scene": "res://enemies/PirateShip.tscn",
		"ui_color": Color(0.48, 0.35, 0.24, 1),
		"texture_path": "res://assets/enemies/pirate_raider_cutter.png",
		"weighted_actions": [
			{
				"key": "cannon_fire",
				"type": "attack",
				"damage": 7,
				"hits": 1,
				"weight": 1.4,
				"repeat_weight": 1.0,
				"log": "%s fires its cannon for %d damage!"
			},
			{
				"key": "brace_hull",
				"type": "guard",
				"block": 7,
				"label": "Brace Hull",
				"weight": 1.0,
				"repeat_weight": 0.7,
				"log": "%s braces its hull."
			},
			{
				"key": "load_shot",
				"type": "guard",
				"block": 4,
				"label": "Load Shot",
				"intent_text": "Load Shot",
				"weight": 0.9,
				"repeat_weight": 0.0,
				"log": "%s loads a heavier shot.",
				"set_flags_after": {
					"loaded_shot": true
				},
				"queue_next_action_key_after": "loaded_cannon_fire"
			},
			{
				"key": "loaded_cannon_fire",
				"type": "attack",
				"damage": 11,
				"hits": 1,
				"weight": 0.0,
				"repeat_weight": 0.0,
				"log": "%s fires a loaded cannon for %d damage!",
				"set_flags_after": {
					"loaded_shot": false
				}
			}
		]
	},

	"pirate_frigate": {
		"display_name": "Pirate Frigate",
		"faction": "pirate",
		"max_health": 34,
		"spawn_scene": "res://enemies/PirateShip.tscn",
		"ui_color": Color(0.36, 0.28, 0.22, 1),
		"texture_path": "res://assets/enemies/pirate_frigate.png",
		"pattern": [
			{
				"key": "load_broadside",
				"type": "guard",
				"block": 10,
				"label": "Load Broadside",
				"intent_text": "Load Broadside",
				"log": "%s loads a broadside.",
				"queue_next_action_key_after": "heavy_broadside"
			},
			{
				"key": "heavy_broadside",
				"type": "attack",
				"damage": 16,
				"hits": 1,
				"log": "%s fires a heavy broadside for %d damage!"
			},
			{
				"key": "reinforced_hull",
				"type": "guard",
				"block": 14,
				"label": "Reinforced Hull",
				"log": "%s reinforces its hull."
			}
		]
	},

	# Reward stealing is intentionally a placeholder until plunder/reward loss
	# has a dedicated combat resolution hook.
	"smuggler": {
		"display_name": "Smuggler",
		"faction": "pirate",
		"max_health": 18,
		"spawn_scene": "res://enemies/PirateShip.tscn",
		"ui_color": Color(0.31, 0.38, 0.32, 1),
		"texture_path": "res://assets/enemies/pirate_smuggler.png",
		"weighted_actions": [
			{
				"key": "pocket_goods",
				"type": "buff",
				"label": "Pocket Goods",
				"intent_text": "Pocket Goods",
				"weight": 1.0,
				"repeat_weight": 0.4,
				"log": "%s pockets cargo for a future reward-steal hook.",
				"increment_flags_after": {
					"stolen_goods": 1
				}
			},
			{
				"key": "smoke_screen",
				"type": "guard",
				"block": 8,
				"label": "Smoke Screen",
				"weight": 1.1,
				"repeat_weight": 0.7,
				"log": "%s vanishes behind a smoke screen."
			},
			{
				"key": "escape_route",
				"type": "buff",
				"label": "Escape Route",
				"intent_text": "Escape Route",
				"weight": 0.8,
				"repeat_weight": 0.0,
				"log": "%s charts an escape route.",
				"queue_next_action_key_after": "flee"
			},
			{
				"key": "flee",
				"type": "flee",
				"label": "Flee",
				"intent_text": "Flee",
				"weight": 0.0,
				"repeat_weight": 0.0,
				"log": "%s slips away before the reward-steal system exists."
			}
		]
	},

	"twin_corsair_left": {
		"display_name": "Twin Corsair",
		"sandbox_name": "Twin Corsairs",
		"sandbox_enemies": {
			"center": "twin_corsair_left",
			"right": "twin_corsair_right"
		},
		"faction": "pirate",
		"max_health": 16,
		"spawn_scene": "res://enemies/PirateShip.tscn",
		"ui_color": Color(0.44, 0.31, 0.24, 1),
		"texture_path": "res://assets/enemies/pirate_twin_corsair.png",
		"weighted_actions": [
			{
				"key": "crossfire",
				"type": "attack",
				"damage": 5,
				"hits": 1,
				"weight": 1.4,
				"repeat_weight": 1.0,
				"requires_any_enemy_id_alive": ["twin_corsair_right"],
				"log": "%s joins the crossfire for %d damage!"
			},
			{
				"key": "cover_fire",
				"type": "attack",
				"damage": 4,
				"hits": 1,
				"gain_block_after": 4,
				"weight": 1.0,
				"repeat_weight": 0.7,
				"requires_any_enemy_id_alive": ["twin_corsair_right"],
				"log": "%s lays cover fire for %d damage!"
			},
			{
				"key": "revenge_volley",
				"type": "attack",
				"damage": 9,
				"hits": 1,
				"weight": 2.0,
				"repeat_weight": 1.2,
				"requires_no_enemy_id_alive": ["twin_corsair_right"],
				"log": "%s fires a revenge volley for %d damage!"
			}
		]
	},

	"twin_corsair_right": {
		"display_name": "Twin Corsair",
		"sandbox_hidden": true,
		"faction": "pirate",
		"max_health": 16,
		"spawn_scene": "res://enemies/PirateShip.tscn",
		"ui_color": Color(0.44, 0.31, 0.24, 1),
		"texture_path": "res://assets/enemies/pirate_twin_corsair.png",
		"weighted_actions": [
			{
				"key": "crossfire",
				"type": "attack",
				"damage": 5,
				"hits": 1,
				"weight": 1.4,
				"repeat_weight": 1.0,
				"requires_any_enemy_id_alive": ["twin_corsair_left"],
				"log": "%s joins the crossfire for %d damage!"
			},
			{
				"key": "cover_fire",
				"type": "attack",
				"damage": 4,
				"hits": 1,
				"gain_block_after": 4,
				"weight": 1.0,
				"repeat_weight": 0.7,
				"requires_any_enemy_id_alive": ["twin_corsair_left"],
				"log": "%s lays cover fire for %d damage!"
			},
			{
				"key": "revenge_volley",
				"type": "attack",
				"damage": 9,
				"hits": 1,
				"weight": 2.0,
				"repeat_weight": 1.2,
				"requires_no_enemy_id_alive": ["twin_corsair_left"],
				"log": "%s fires a revenge volley for %d damage!"
			}
		]
	},

	"powder_skiff": {
		"display_name": "Powder Skiff",
		"faction": "pirate",
		"max_health": 16,
		"spawn_scene": "res://enemies/PirateShip.tscn",
		"ui_color": Color(0.54, 0.25, 0.18, 1),
		"texture_path": "res://assets/enemies/pirate_powder_skiff.png",
		"initial_flags": {
			"fuse_lit": false,
			"fuse_turns": 0
		},
		"weighted_actions": [
			{
				"key": "light_fuse",
				"type": "buff",
				"label": "Fuse 2",
				"intent_text": "Fuse 2",
				"weight": 2.0,
				"repeat_weight": 0.0,
				"requires_flags": {
					"fuse_lit": false
				},
				"log": "%s lights the powder fuse.",
				"set_flags_after": {
					"fuse_lit": true,
					"fuse_turns": 2
				}
			},
			{
				"key": "drift_closer",
				"type": "guard",
				"block": 4,
				"label": "Fuse Ticks",
				"intent_text": "Fuse Ticks",
				"weight": 1.5,
				"repeat_weight": 1.0,
				"requires_flags": {
					"fuse_lit": true
				},
				"requires_flag_gte": {
					"fuse_turns": 1
				},
				"log": "%s drifts closer as the fuse burns.",
				"increment_flags_after": {
					"fuse_turns": -1
				},
				"flag_mins": {
					"fuse_turns": 0
				}
			},
			{
				"key": "detonate",
				"type": "detonate",
				"label": "Explode 16",
				"intent_text": "Explode 16",
				"player_damage": 16,
				"enemy_splash_damage": 7,
				"weight": 3.0,
				"repeat_weight": 3.0,
				"requires_flags": {
					"fuse_lit": true
				},
				"requires_flag_lte": {
					"fuse_turns": 0
				},
				"log": "%s detonates for %d damage!"
			}
		]
	},

	"boarding_tender": {
		"display_name": "Boarding Tender",
		"faction": "pirate",
		"max_health": 28,
		"spawn_scene": "res://enemies/PirateShip.tscn",
		"ui_color": Color(0.40, 0.32, 0.24, 1),
		"texture_path": "res://assets/enemies/pirate_boarding_tender.png",
		"weighted_actions": [
			{
				"key": "launch_rowboat",
				"type": "summon",
				"label": "Launch Rowboat",
				"intent_text": "Launch Rowboat",
				"summon_enemy_id": "rowboat",
				"max_alive_enemy_id": "rowboat",
				"max_alive": 2,
				"preferred_slots": ["left", "right"],
				"requires_empty_side_slot": true,
				"weight": 2.0,
				"repeat_weight": 0.7,
				"log": "%s launches %s."
			},
			{
				"key": "covering_fire",
				"type": "attack",
				"damage": 6,
				"hits": 1,
				"weight": 1.1,
				"repeat_weight": 1.0,
				"log": "%s fires covering shots for %d damage!"
			},
			{
				"key": "signal_flare",
				"type": "defend_allies",
				"block": 3,
				"intent_text": "+3 Team Block",
				"weight": 0.9,
				"repeat_weight": 0.6
			},
			{
				"key": "patch_deck",
				"type": "guard",
				"block": 7,
				"label": "Patch Deck",
				"weight": 1.0,
				"repeat_weight": 0.8,
				"log": "%s patches its deck."
			}
		]
	},

	"rowboat": {
		"display_name": "Rowboat",
		"faction": "pirate",
		"max_health": 6,
		"spawn_scene": "res://enemies/PirateShip.tscn",
		"ui_color": Color(0.46, 0.36, 0.23, 1),
		"texture_path": "res://assets/enemies/pirate_rowboat.png",
		"initial_flags": {
			"passive_end_turn_damage": 2
		},
		"weighted_actions": [
			{
				"key": "boarding_pressure",
				"type": "passive_pressure",
				"label": "Board 2",
				"intent_text": "Board 2",
				"weight": 1.0,
				"repeat_weight": 1.0,
				"log": "%s rows into boarding position."
			}
		]
	},

	# TODO: If player-turn damage tracking becomes centralized, remove one
	# loaded cannon when Dread Corsair takes 12+ damage in a single turn.
	"dread_corsair": {
		"display_name": "Dread Corsair",
		"faction": "pirate",
		"max_health": 45,
		"spawn_scene": "res://enemies/PirateShip.tscn",
		"ui_color": Color(0.24, 0.22, 0.26, 1),
		"texture_path": "res://assets/enemies/pirate_dread_corsair.png",
		"initial_flags": {
			"loaded_cannons": 0
		},
		"weighted_actions": [
			{
				"key": "load_cannons",
				"type": "guard",
				"block": 6,
				"label": "Load Cannons",
				"intent_text": "+1 Cannon +6 Block",
				"weight": 1.5,
				"repeat_weight": 1.0,
				"log": "%s loads another cannon.",
				"increment_flags_after": {
					"loaded_cannons": 1
				},
				"flag_caps": {
					"loaded_cannons": 3
				}
			},
			{
				"key": "brace_the_deck",
				"type": "guard",
				"block": 12,
				"label": "Brace the Deck",
				"weight": 1.0,
				"repeat_weight": 0.7,
				"log": "%s braces the deck."
			},
			{
				"key": "fire_broadside",
				"type": "attack",
				"damage_flag": "loaded_cannons",
				"damage_per_flag": 7,
				"min_damage": 7,
				"hits": 1,
				"weight": 1.5,
				"repeat_weight": 0.5,
				"requires_flag_gte": {
					"loaded_cannons": 1
				},
				"log": "%s fires a loaded broadside for %d damage!",
				"set_flags_after": {
					"loaded_cannons": 0
				}
			},
			{
				"key": "captains_order",
				"type": "pirate_order",
				"label": "Captain's Order",
				"intent_text": "Captain's Order",
				"block": 6,
				"fallback_increment_flag": "loaded_cannons",
				"fallback_increment": 1,
				"fallback_cap": 3,
				"weight": 0.9,
				"repeat_weight": 0.7
			},
			{
				"key": "punishing_volley",
				"type": "attack",
				"damage": 4,
				"hits": 2,
				"weight": 1.1,
				"repeat_weight": 0.8,
				"log": "%s fires a punishing volley %d times for %d damage each!"
			}
		]
	}
}

const LEGACY_ENEMY_ID_ALIASES := {
	"pirate_gunner": "pirate_skiff",
	"pirate_brute": "pirate_frigate"
}

static func get_canonical_enemy_id(enemy_id: String) -> String:
	return String(LEGACY_ENEMY_ID_ALIASES.get(enemy_id, enemy_id))

static func get_sandbox_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	for enemy_id in ENEMY_DATA.keys():
		var data: Dictionary = Dictionary(ENEMY_DATA[enemy_id])
		if bool(data.get("sandbox_hidden", false)):
			continue

		var enemies: Dictionary = Dictionary(data.get("sandbox_enemies", {
			"center": String(enemy_id)
		}))

		entries.append({
			"id": String(enemy_id),
			"name": String(data.get("sandbox_name", data.get("display_name", enemy_id))),
			"enemies": enemies
		})

	return entries

static func get_enemy_data(enemy_id: String) -> Dictionary:
	var canonical_id: String = get_canonical_enemy_id(enemy_id)
	if ENEMY_DATA.has(canonical_id):
		return Dictionary(ENEMY_DATA[canonical_id])
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

static func get_texture_path(enemy_id: String) -> String:
	var data: Dictionary = get_enemy_data(enemy_id)
	return String(data.get("texture_path", ""))

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
