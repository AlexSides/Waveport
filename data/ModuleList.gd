extends Node

const MODULE_LIBRARY := {
	"basic_cannon": {
		"id": "basic_cannon",
		"name": "Basic Cannon",
		"slot_type": "cannon",
		"tags": ["weapon", "cannon"],
		"effects": [],
		"description": "A standard ship cannon. Adds 1 cannon slot to your active battery.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": ["cannon_shot"],
		"bonus_cards": ["cannon_shot"]
	},

	"powder_cannon": {
		"id": "powder_cannon",
		"name": "Powder Cannon",
		"slot_type": "cannon",
		"tags": ["weapon", "cannon", "powder"],
		"effects": [
			{
				"type": "cannon_damage_bonus",
				"amount": 2
			}
		],
		"description": "Adds a Cannon Shot card. Shots from this cannon will eventually hit harder.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": ["cannon_shot"],
		"bonus_cards": ["cannon_shot"]
	},

	"deck_crew": {
		"id": "deck_crew",
		"name": "Deck Crew",
		"slot_type": "crew",
		"tags": ["crew"],
		"effects": [],
		"description": "+1 max Commands each turn.",
		"command_bonus": 1,
		"hull_bonus": 0,
		"granted_cards": [],
		"bonus_cards": []
	},

	"ship_surgeon": {
		"id": "ship_surgeon",
		"name": "Ship Surgeon",
		"slot_type": "crew",
		"tags": ["crew", "support"],
		"effects": [
			{
				"type": "end_of_combat_heal",
				"amount": 2
			}
		],
		"description": "Heal 2 HP at end of combat.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": [],
		"bonus_cards": []
	},

	"lookout_watch": {
		"id": "lookout_watch",
		"name": "Lookout Watch",
		"slot_type": "watch",
		"tags": ["watch"],
		"effects": [
			{
				"type": "hand_size_bonus",
				"amount": 1
			}
		],
		"description": "+1 hand size.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": [],
		"bonus_cards": []
	},

	"ram": {
		"id": "ram",
		"name": "Ram",
		"slot_type": "front",
		"tags": ["front", "weapon", "ram"],
		"effects": [],
		"description": "Adds a Ram card to your deck.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": ["ram"],
		"bonus_cards": ["ram"]
	},

	"reinforced_prow": {
		"id": "reinforced_prow",
		"name": "Reinforced Prow",
		"slot_type": "front",
		"tags": ["front", "defense"],
		"effects": [],
		"description": "+5 max Hull.",
		"command_bonus": 0,
		"hull_bonus": 5,
		"granted_cards": [],
		"bonus_cards": []
	},

	"stern_plating": {
		"id": "stern_plating",
		"name": "Stern Plating",
		"slot_type": "rear",
		"tags": ["rear", "defense"],
		"effects": [
			{
				"type": "combat_start_block",
				"amount": 4
			}
		],
		"description": "Start combat with 4 Block.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": [],
		"bonus_cards": []
	},

	"powder_racks": {
		"id": "powder_racks",
		"name": "Powder Racks",
		"slot_type": "rear",
		"tags": ["rear", "powder"],
		"effects": [
			{
				"type": "first_cannon_damage_bonus",
				"amount": 1
			}
		],
		"description": "Your first cannon fired each turn deals +1 damage.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": [],
		"bonus_cards": []
	},

	"powder_crew": {
		"id": "powder_crew",
		"name": "Deck Crew",
		"slot_type": "crew",
		"tags": ["crew", "legacy"],
		"effects": [],
		"description": "+1 max Commands each turn.",
		"command_bonus": 1,
		"hull_bonus": 0,
		"granted_cards": [],
		"bonus_cards": []
	},

	"surgeon": {
		"id": "surgeon",
		"name": "Ship Surgeon",
		"slot_type": "crew",
		"tags": ["crew", "support", "legacy"],
		"effects": [
			{
				"type": "end_of_combat_heal",
				"amount": 2
			}
		],
		"description": "Heal 2 HP at end of combat.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": [],
		"bonus_cards": []
	},

	"crows_nest": {
		"id": "crows_nest",
		"name": "Lookout Watch",
		"slot_type": "watch",
		"tags": ["watch", "legacy"],
		"effects": [
			{
				"type": "hand_size_bonus",
				"amount": 1
			}
		],
		"description": "+1 hand size.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": [],
		"bonus_cards": []
	},

	"powder_reserve": {
		"id": "powder_reserve",
		"name": "Powder Racks",
		"slot_type": "rear",
		"tags": ["rear", "powder", "legacy"],
		"effects": [
			{
				"type": "first_cannon_damage_bonus",
				"amount": 1
			}
		],
		"description": "Your first cannon fired each turn deals +1 damage.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": [],
		"bonus_cards": []
	},

	"reinforced_hull": {
		"id": "reinforced_hull",
		"name": "Stern Plating",
		"slot_type": "rear",
		"tags": ["rear", "defense", "legacy"],
		"effects": [
			{
				"type": "combat_start_block",
				"amount": 4
			}
		],
		"description": "Start combat with 4 Block.",
		"command_bonus": 0,
		"hull_bonus": 0,
		"granted_cards": [],
		"bonus_cards": []
	}
}

static func get_module(module_id: String) -> Dictionary:
	return MODULE_LIBRARY.get(module_id, {}).duplicate(true)

static func has_module(module_id: String) -> bool:
	return MODULE_LIBRARY.has(module_id)

static func get_all_modules() -> Dictionary:
	return MODULE_LIBRARY.duplicate(true)

static func get_modules_for_slot(slot_type: String) -> Array:
	var results: Array = []
	for module_id in MODULE_LIBRARY.keys():
		var module_def: Dictionary = MODULE_LIBRARY[module_id]
		if String(module_def.get("slot_type", "")) == slot_type:
			results.append(module_def.duplicate(true))
	return results

static func get_module_granted_cards(module_id: String) -> Array[String]:
	var module_def: Dictionary = get_module(module_id)
	if module_def.is_empty():
		return []

	var granted: Array[String] = []

	for card_id_variant in module_def.get("granted_cards", []):
		var card_id: String = String(card_id_variant)
		if card_id != "":
			granted.append(card_id)

	if granted.is_empty():
		for card_id_variant in module_def.get("bonus_cards", []):
			var card_id: String = String(card_id_variant)
			if card_id != "":
				granted.append(card_id)

	if granted.is_empty():
		for card_id_variant in module_def.get("card_unlocks", []):
			var card_id: String = String(card_id_variant)
			if card_id != "":
				granted.append(card_id)

	return granted

static func get_all_module_granted_card_ids() -> Array[String]:
	var granted_ids: Array[String] = []

	for module_id in MODULE_LIBRARY.keys():
		for card_id in get_module_granted_cards(String(module_id)):
			if not granted_ids.has(card_id):
				granted_ids.append(card_id)

	return granted_ids
