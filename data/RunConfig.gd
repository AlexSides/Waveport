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

const PLUNDER_MODULE_POOL: Array[String] = [
	"ram",
	"reinforced_prow",
	"lookout_watch",
	"deck_crew",
	"stern_plating",
	"powder_racks",
	"powder_cannon",
	"ship_surgeon"
]

const PLUNDER_BUNDLE_PATTERNS: Array = [
	["module"],
	["card_bundle"],
	["module", "card_bundle"],
	["module", "module"],
	["card_bundle", "card_bundle"]
]

const PLUNDER_REWARD_PATTERNS: Array = [
	["module", "module"],
	["module", "card_pack"],
	["card_pack", "module"],
	["card_pack", "card_pack"]
]

static func get_default_enemy_paths() -> Array[String]:
	return DEFAULT_ENEMY_PATHS.duplicate()

static func get_plunder_gold_reward(plunder_index: int) -> int:
	if plunder_index == 0:
		return 50
	elif plunder_index == 1:
		return 100
	return 125

static func get_random_card_bundle_ids() -> Array[String]:
	var ids: Array[String] = []
	for set_id in CARGO_SET_LIBRARY.keys():
		ids.append(String(set_id))
	ids.shuffle()
	return ids

static func get_random_cargo_set_ids() -> Array[String]:
	return get_random_card_bundle_ids()

static func get_cargo_set(set_id: String) -> Dictionary:
	if CARGO_SET_LIBRARY.has(set_id):
		return Dictionary(CARGO_SET_LIBRARY[set_id])
	return {}

static func get_card_bundle(set_id: String) -> Dictionary:
	return get_cargo_set(set_id)

static func get_cargo_set_name(set_id: String) -> String:
	var data := get_cargo_set(set_id)
	return String(data.get("name", set_id.capitalize()))

static func get_card_bundle_name(set_id: String) -> String:
	return get_cargo_set_name(set_id)

static func get_cargo_set_cards(set_id: String) -> Array:
	var data := get_cargo_set(set_id)
	return Array(data.get("cards", []))

static func get_card_bundle_cards(set_id: String) -> Array:
	return get_cargo_set_cards(set_id)

static func generate_plunder_bundle(plunder_index: int) -> Dictionary:
	var pattern_options: Array = PLUNDER_BUNDLE_PATTERNS.duplicate(true)
	pattern_options.shuffle()
	var pattern: Array = Array(pattern_options.front())

	var module_pool: Array[String] = PLUNDER_MODULE_POOL.duplicate()
	module_pool.shuffle()
	var card_bundle_ids: Array[String] = get_random_card_bundle_ids()

	var items: Array[Dictionary] = []
	for reward_type_variant in pattern:
		var reward_type: String = String(reward_type_variant)
		match reward_type:
			"module":
				if module_pool.is_empty():
					continue
				var module_id: String = String(module_pool.pop_front())
				items.append({
					"kind": "module",
					"module_id": module_id,
					"claimed": false
				})
			"card_bundle":
				if card_bundle_ids.is_empty():
					card_bundle_ids = get_random_card_bundle_ids()
				if card_bundle_ids.is_empty():
					continue
				var bundle_id: String = String(card_bundle_ids.pop_front())
				items.append({
					"kind": "card_bundle",
					"bundle_id": bundle_id,
					"bundle_name": get_card_bundle_name(bundle_id),
					"cards": get_card_bundle_cards(bundle_id),
					"claimed": false
				})

	return {
		"gold_amount": get_plunder_gold_reward(plunder_index),
		"gold_claimed": false,
		"items": items
	}

static func generate_plunder_reward_choices() -> Array[Dictionary]:
	var pattern_options: Array = PLUNDER_REWARD_PATTERNS.duplicate(true)
	pattern_options.shuffle()
	var pattern: Array = Array(pattern_options[0])

	var module_pool: Array[String] = PLUNDER_MODULE_POOL.duplicate()
	module_pool.shuffle()
	var card_bundle_ids: Array[String] = get_random_card_bundle_ids()

	var choices: Array[Dictionary] = []
	for reward_type_variant in pattern:
		var reward_type: String = String(reward_type_variant)
		match reward_type:
			"module":
				if module_pool.is_empty():
					continue
				var module_id: String = String(module_pool.pop_front())
				choices.append({
					"kind": "module",
					"module_id": module_id
				})
			"card_pack":
				if card_bundle_ids.is_empty():
					card_bundle_ids = get_random_card_bundle_ids()
				if card_bundle_ids.is_empty():
					continue
				var bundle_id: String = String(card_bundle_ids.pop_front())
				choices.append({
					"kind": "card_pack",
					"bundle_id": bundle_id,
					"pack_name": get_card_bundle_name(bundle_id),
					"cards": get_card_bundle_cards(bundle_id)
				})

	return choices
