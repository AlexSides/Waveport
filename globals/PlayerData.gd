extends Node

const ModuleList = preload("res://data/ModuleList.gd")

signal gold_changed(new_gold: int)
signal hull_changed(current_hull: int, max_hull: int)
signal deck_changed()

const CAPTAIN_1_STARTER_DECK: Array[String] = [
	"brace",
	"brace",
	"brace",
	"blood_oath",
	"blood_rush"
]

const DEFAULT_STARTER_DECK: Array[String] = [
	"brace",
	"brace",
	"brace",
	"blood_oath",
	"blood_rush"
]

const CAPTAIN_1_STARTER_MODULES: Array[String] = [
	"basic_cannon",
	"basic_cannon"
]

const DEFAULT_STARTER_MODULES: Array[String] = [
	"basic_cannon",
	"basic_cannon"
]

var gold: int = 0
var max_hull: int = 40
var current_hull: int = 40

var starter_deck: Array[String] = DEFAULT_STARTER_DECK.duplicate()
var run_deck: Array[String] = DEFAULT_STARTER_DECK.duplicate()

var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var hand: Array[String] = []

var modules: Array[String] = DEFAULT_STARTER_MODULES.duplicate()
var pending_bonus_cards: Array[String] = []

var current_health: int:
	get:
		return current_hull

var current_max_health: int:
	get:
		return max_hull

func _ready() -> void:
	if draw_pile.is_empty():
		reset_run()

func reset_run() -> void:
	run_deck = starter_deck.duplicate()
	draw_pile = run_deck.duplicate()
	discard_pile.clear()
	hand.clear()
	pending_bonus_cards.clear()
	gold = 0
	current_hull = max_hull
	emit_signal("gold_changed", gold)
	emit_signal("hull_changed", current_hull, max_hull)
	emit_signal("deck_changed")

func ensure_run_state() -> void:
	if starter_deck.is_empty():
		starter_deck = DEFAULT_STARTER_DECK.duplicate()

	if run_deck.is_empty():
		run_deck = starter_deck.duplicate()

	if modules.is_empty():
		modules = DEFAULT_STARTER_MODULES.duplicate()

	if current_hull <= 0:
		current_hull = max_hull

	if draw_pile.is_empty() and discard_pile.is_empty() and hand.is_empty():
		draw_pile = run_deck.duplicate()

func apply_captain_starting_deck(captain_id: String) -> void:
	match captain_id:
		"captain_1":
			starter_deck = CAPTAIN_1_STARTER_DECK.duplicate()
			modules = CAPTAIN_1_STARTER_MODULES.duplicate()
		_:
			starter_deck = DEFAULT_STARTER_DECK.duplicate()
			modules = DEFAULT_STARTER_MODULES.duplicate()

	reset_run()

func set_hull(value: int) -> void:
	var clamped_value: int = clampi(value, 0, max_hull)
	current_hull = clamped_value
	emit_signal("hull_changed", current_hull, max_hull)

func heal_hull(amount: int) -> int:
	if amount <= 0:
		return 0

	var before: int = current_hull
	var healed_to: int = clampi(current_hull + amount, 0, max_hull)
	current_hull = healed_to
	var healed: int = current_hull - before
	emit_signal("hull_changed", current_hull, max_hull)
	return healed

func damage_hull(amount: int) -> void:
	if amount <= 0:
		return

	current_hull = maxi(current_hull - amount, 0)
	emit_signal("hull_changed", current_hull, max_hull)

func repair_ship(amount: int) -> void:
	heal_hull(amount)

func sync_ship_state(health: int, hull_max: int) -> void:
	max_hull = hull_max
	current_hull = clampi(health, 0, max_hull)
	emit_signal("hull_changed", current_hull, max_hull)

func get_battle_deck() -> Array[String]:
	ensure_run_state()
	if run_deck.is_empty():
		run_deck = starter_deck.duplicate()
	return run_deck.duplicate()

func get_module_bonus_cards() -> Array[String]:
	var bonus_cards: Array[String] = []

	for module_id in modules:
		var module_data: Dictionary = ModuleList.MODULE_LIBRARY.get(module_id, {})
		var unlocks: Array = module_data.get("card_unlocks", [])

		for card_id_variant in unlocks:
			var card_id: String = String(card_id_variant)
			if card_id != "":
				bonus_cards.append(card_id)

	return bonus_cards

func consume_pending_bonus_cards() -> Array[String]:
	var cards: Array[String] = pending_bonus_cards.duplicate()
	pending_bonus_cards.clear()
	return cards

func add_pending_bonus_card(card_id: String) -> void:
	if card_id == "":
		return
	pending_bonus_cards.append(card_id)

func queue_bonus_cards_for_next_battle(cards: Array) -> void:
	for card_id_variant in cards:
		var card_id: String = String(card_id_variant)
		if card_id != "":
			pending_bonus_cards.append(card_id)

func get_queue_limit() -> int:
	var total: int = 0

	for module_id in modules:
		var module_data: Dictionary = ModuleList.MODULE_LIBRARY.get(module_id, {})
		total += int(module_data.get("queue_bonus", 0))

	return total

func to_save_dict() -> Dictionary:
	return {
		"gold": gold,
		"max_hull": max_hull,
		"current_hull": current_hull,
		"starter_deck": starter_deck.duplicate(),
		"run_deck": run_deck.duplicate(),
		"modules": modules.duplicate(),
		"pending_bonus_cards": pending_bonus_cards.duplicate()
	}

func load_from_save_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", 0))
	max_hull = int(data.get("max_hull", 40))
	current_hull = int(data.get("current_hull", max_hull))

	starter_deck.clear()
	for card_id in data.get("starter_deck", DEFAULT_STARTER_DECK):
		starter_deck.append(String(card_id))

	run_deck.clear()
	for card_id in data.get("run_deck", starter_deck):
		run_deck.append(String(card_id))

	modules.clear()
	for module_data in data.get("modules", DEFAULT_STARTER_MODULES):
		modules.append(String(module_data))

	pending_bonus_cards.clear()
	for card_id in data.get("pending_bonus_cards", []):
		pending_bonus_cards.append(String(card_id))

	draw_pile = run_deck.duplicate()
	discard_pile.clear()
	hand.clear()

	emit_signal("gold_changed", gold)
	emit_signal("hull_changed", current_hull, max_hull)
	emit_signal("deck_changed")

func add_gold(amount: int) -> void:
	if amount <= 0:
		return

	gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false

	gold -= amount
	emit_signal("gold_changed", gold)
	return true

func add_card_to_deck(card_id: String) -> void:
	if card_id == "":
		return

	starter_deck.append(card_id)
	run_deck.append(card_id)
	discard_pile.append(card_id)
	emit_signal("deck_changed")

func add_cards_to_deck(cards: Array) -> void:
	for card_id_variant in cards:
		var card_id: String = String(card_id_variant)
		if card_id != "":
			add_card_to_deck(card_id)

func remove_card_from_deck(card_id: String) -> bool:
	var removed: bool = false

	if starter_deck.has(card_id):
		starter_deck.erase(card_id)
		removed = true

	if run_deck.has(card_id):
		run_deck.erase(card_id)
		removed = true

	if draw_pile.has(card_id):
		draw_pile.erase(card_id)
		removed = true

	if discard_pile.has(card_id):
		discard_pile.erase(card_id)
		removed = true

	if hand.has(card_id):
		hand.erase(card_id)
		removed = true

	if removed:
		emit_signal("deck_changed")

	return removed
