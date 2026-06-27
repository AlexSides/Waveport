var CARD_LIBRARY = {
	"cannon_shot": {
		"id": "cannon_shot",
		"name": "Cannon Shot",
		"type": "Attack",
		"attack": 3,
		"value": 3,
		"cost": 1,
		"category": "Queue",
		"is_cannon": true,
		"frame": "res://assets/cards/Orange_Layout.png",
		"art": "res://assets/cards/Cannon_Shot.png",
		"hide_text": false,
		"description": "Deal X damage."
	},

	"loaded_shot": {
		"id": "loaded_shot",
		"name": "Loaded Shot",
		"type": "Attack",
		"attack": 3,
		"value": 3,
		"cost": 2,
		"category": "Queue",
		"is_cannon": true,
		"bonus_if_last_in_queue": 2,
		"frame": "res://assets/cards/Orange_Layout.png",
		"art": "res://assets/cards/Cannon_Shot.png",
		"hide_text": false,
		"description": "Deal 3 damage. If this is the last card in your queue, deal 2 more."
	},

	"brace": {
		"id": "brace",
		"name": "Brace",
		"type": "Block",
		"block": 3,
		"value": 3,
		"cost": 1,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"art": "res://assets/cards/Brace.png",
		"hide_text": false,
		"description": "Gain X Block."
	},

	"crate": {
		"id": "crate",
		"name": "Crate",
		"type": "Skill",
		"value": 0,
		"cost": 0,
		"category": "Queue",
		"playable": false,
		"unplayable_text": "Cannot be played.",
		"frame": "res://assets/cards/Orange_Layout.png",
		"art": "res://assets/cards/crate.png",
		"hide_text": false,
		"description": "Cannot be played."
	},

	"repair": {
		"id": "repair",
		"name": "Repair",
		"type": "Heal",
		"heal": 2,
		"value": 2,
		"cost": 1,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"art": "res://assets/cards/Repair.png",
		"description": "Restore X HP."
	},

	"ram": {
		"id": "ram",
		"name": "Ram",
		"type": "Attack",
		"attack": "current_block",
		"value": 0,
		"cost": 1,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"consume_all_block": true,
		"description": "Deal damage equal to your current Block. Remove all Block."
	},

	"blood_oath": {
		"id": "blood_oath",
		"name": "Blood Oath",
		"type": "Attack",
		"attack": 8,
		"value": 8,
		"cost": 1,
		"bleed": 3,
		"category": "Queue",
		"frame": "res://assets/cards/Orange_Layout.png",
		"is_cannon": true,
		"description": "Deal X damage. Bleed 3."
	},

	"chain_shot": {
		"id": "chain_shot",
		"name": "Chain Shot",
		"type": "Attack",
		"attack": 1,
		"value": 1,
		"cost": 1,
		"category": "Queue",
		"frame": "res://assets/cards/Orange_Layout.png",
		"is_cannon": true,
		"prime_next_cannon_multiplier_percent": 150,
		"description": "Deal 1 damage. The next shot deals 50% more damage."
	},

	"overload": {
		"id": "overload",
		"name": "Overload",
		"type": "Skill",
		"cost": 0,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"bleed": 4,
		"cannon_bonus_this_turn": 3,
		"description": "Bleed 4. Cannons deal +3 damage this turn."
	},

	"touch_up": {
		"id": "touch_up",
		"name": "Touch Up",
		"type": "Skill",
		"cost": 0,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"art": "res://assets/cards/Touch_Up.png",
		"rot": true,
		"repeat_last_cannon_in_queue": 1,
		"description": "This turn, the last cannon in your queue fires an additional time."
	},

	"prepare": {
		"id": "prepare",
		"name": "Prepare",
		"type": "Block",
		"cost": 1,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"block": 2,
		"gain_block_next_turn": 4,
		"description": "Gain 2 Block. At the start of next turn, gain 4 Block."
	},

	"hold_fast": {
		"id": "hold_fast",
		"name": "Hold Fast",
		"type": "Block",
		"cost": 1,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"draw": 1,
		"block_per_empty_cannon_slot_end_turn": 4,
		"description": "Draw 1. At the end of your turn, gain 4 Block for each empty cannon slot."
	},

	"barricade": {
		"id": "barricade",
		"name": "Barricade",
		"type": "Block",
		"cost": 2,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"rot": true,
		"block": 20,
		"end_turn_without_firing": true,
		"description": "Gain 20 Block. End turn without firing."
	},

	"sacrifice": {
		"id": "sacrifice",
		"name": "Sacrifice",
		"type": "Skill",
		"cost": 1,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"bleed": 2,
		"block": 7,
		"description": "Bleed 2. Gain 7 Block."
	},

	"blood_rush": {
		"id": "blood_rush",
		"name": "Blood Rush",
		"type": "Skill",
		"cost": 1,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"draw_on_bleed_this_turn": 2,
		"description": "If you Bleed this turn, draw 2 instantly."
	},

	"restore": {
		"id": "restore",
		"name": "Restore",
		"type": "Heal",
		"cost": 2,
		"category": "Instant",
		"frame": "res://assets/cards/Orange_Layout.png",
		"rot": true,
		"heal_from_hp_lost_this_combat_percent": 50,
		"description": "Rot. Restore HP equal to 50% of HP lost this combat."
	}
}
