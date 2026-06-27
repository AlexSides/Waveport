extends Node

const DEFAULT_CAPTAIN_ID := "captain_1"

const DEFAULT_STARTER_DECK: Array[String] = [
	"brace",
	"brace",
	"brace",
	"blood_oath",
	"blood_rush"
]

const CAPTAINS := [
	{
		"id": "captain_1",
		"name": "Captain 1",
		"description": "Blood-focused captain.",
		"focus": "Blood tactics",
		"visual_label": "Blood Tide",
		"visual_color": Color(0.48, 0.16, 0.14, 1),
		"starter_deck": DEFAULT_STARTER_DECK,
		"starting_ship_id": "starter_sloop"
	},
	{
		"id": "captain_2",
		"name": "Captain 2",
		"description": "Defense-focused captain.",
		"focus": "Defensive command",
		"visual_label": "Iron Wake",
		"visual_color": Color(0.18, 0.29, 0.36, 1),
		"starter_deck": DEFAULT_STARTER_DECK,
		"starting_ship_id": "starter_sloop"
	},
	{
		"id": "captain_3",
		"name": "Captain 3",
		"description": "Balanced captain.",
		"focus": "Balanced tactics",
		"visual_label": "Even Keel",
		"visual_color": Color(0.24, 0.33, 0.2, 1),
		"starter_deck": DEFAULT_STARTER_DECK,
		"starting_ship_id": "starter_sloop"
	}
]

static func get_all_captains() -> Array[Dictionary]:
	var captains: Array[Dictionary] = []
	for captain_variant in CAPTAINS:
		var captain: Dictionary = captain_variant
		captains.append(captain.duplicate(true))
	return captains

static func get_captain(captain_id: String) -> Dictionary:
	for captain_variant in CAPTAINS:
		var captain: Dictionary = captain_variant
		if String(captain.get("id", "")) == captain_id:
			return captain.duplicate(true)

	if CAPTAINS.is_empty():
		return {}

	var default_captain: Dictionary = CAPTAINS[0]
	return default_captain.duplicate(true)

static func has_captain(captain_id: String) -> bool:
	for captain_variant in CAPTAINS:
		var captain: Dictionary = captain_variant
		if String(captain.get("id", "")) == captain_id:
			return true
	return false

static func get_starter_deck(captain_id: String) -> Array[String]:
	var captain: Dictionary = get_captain(captain_id)
	var deck: Array[String] = []
	for card_id_variant in captain.get("starter_deck", DEFAULT_STARTER_DECK):
		var card_id := String(card_id_variant)
		if card_id != "":
			deck.append(card_id)
	return deck

static func get_starting_ship_id(captain_id: String) -> String:
	var captain: Dictionary = get_captain(captain_id)
	var ship_id := String(captain.get("starting_ship_id", "starter_sloop"))
	return ship_id if ship_id != "" else "starter_sloop"
