extends Node

const ModuleList = preload("res://data/ModuleList.gd")
const ShipList = preload("res://data/ShipList.gd")

signal gold_changed(new_gold: int)
signal hull_changed(current_hull: int, max_hull: int)
signal deck_changed()
signal modules_changed
signal ship_changed

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

const DEFAULT_STARTER_SHIP_ID := "starter_sloop"
const DEBUG_STARTER_CARGO_MODULES: Array[String] = [
	"ram",
	"reinforced_prow",
	"lookout_watch",
	"deck_crew",
	"stern_plating",
	"powder_racks",
	"powder_cannon"
]

var gold: int = 0
var max_hull: int = 40
var current_hull: int = 40

var starter_deck: Array[String] = DEFAULT_STARTER_DECK.duplicate()
var run_deck: Array[String] = DEFAULT_STARTER_DECK.duplicate()

var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var hand: Array[String] = []

var selected_captain: String = ""
var current_ship_id: String = DEFAULT_STARTER_SHIP_ID
var installed_modules_by_slot: Dictionary = {}
var cargo_modules: Array[String] = []
var cargo_capacity: int = 3

var modules: Array[String] = []
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
	_setup_default_ship_state()
	_recalculate_ship_stats()
	current_hull = max_hull
	_sync_modules_cache()
	emit_signal("gold_changed", gold)
	emit_signal("hull_changed", current_hull, max_hull)
	emit_signal("deck_changed")
	emit_signal("modules_changed")
	emit_signal("ship_changed")

func ensure_run_state() -> void:
	if starter_deck.is_empty():
		starter_deck = DEFAULT_STARTER_DECK.duplicate()

	if run_deck.is_empty():
		run_deck = starter_deck.duplicate()

	if current_ship_id == "":
		current_ship_id = DEFAULT_STARTER_SHIP_ID

	if installed_modules_by_slot.is_empty():
		_setup_default_ship_state()

	if cargo_capacity <= 0:
		cargo_capacity = ShipList.get_cargo_capacity(current_ship_id)

	_recalculate_ship_stats()

	if current_hull <= 0:
		current_hull = max_hull

	if draw_pile.is_empty() and discard_pile.is_empty() and hand.is_empty():
		draw_pile = run_deck.duplicate()

	_sync_modules_cache()

func apply_captain_starting_deck(captain_id: String) -> void:
	selected_captain = captain_id

	match captain_id:
		"captain_1":
			starter_deck = CAPTAIN_1_STARTER_DECK.duplicate()
			current_ship_id = DEFAULT_STARTER_SHIP_ID
			_setup_default_ship_state()
		_:
			starter_deck = DEFAULT_STARTER_DECK.duplicate()
			current_ship_id = DEFAULT_STARTER_SHIP_ID
			_setup_default_ship_state()

	reset_run()

func _setup_default_ship_state() -> void:
	current_ship_id = DEFAULT_STARTER_SHIP_ID if current_ship_id == "" else current_ship_id
	installed_modules_by_slot = ShipList.get_default_installed_modules(current_ship_id)
	cargo_capacity = ShipList.get_cargo_capacity(current_ship_id)
	cargo_modules.clear()
	_seed_debug_starter_cargo()
	_sync_modules_cache()

func _seed_debug_starter_cargo() -> void:
	for module_id in DEBUG_STARTER_CARGO_MODULES:
		if cargo_modules.size() >= cargo_capacity:
			break
		if not ModuleList.has_module(module_id):
			continue
		cargo_modules.append(module_id)

func _sync_modules_cache() -> void:
	modules = get_active_modules()

func _recalculate_ship_stats() -> void:
	var old_max_hull: int = max_hull
	max_hull = 40 + get_total_hull_bonus()

	if max_hull <= 0:
		max_hull = 40

	if current_hull > max_hull:
		current_hull = max_hull
	elif current_hull <= 0 and old_max_hull > 0:
		current_hull = max_hull

func get_ship_definition() -> Dictionary:
	return ShipList.get_ship(current_ship_id)

func get_ship() -> Dictionary:
	return ShipList.get_ship(current_ship_id)

func get_ship_slots() -> Array:
	return ShipList.get_ship_slots(current_ship_id)

func get_ship_slot_count(slot_type: String) -> int:
	return ShipList.get_slot_count_by_type(current_ship_id, slot_type)

func get_installed_modules() -> Dictionary:
	return installed_modules_by_slot.duplicate(true)

func get_installed_module(slot_id: String) -> String:
	return String(installed_modules_by_slot.get(slot_id, ""))

func get_cargo_modules() -> Array[String]:
	return cargo_modules.duplicate()

func get_cargo_capacity() -> int:
	return cargo_capacity

func get_cargo_count() -> int:
	return cargo_modules.size()

func get_active_modules() -> Array[String]:
	var active: Array[String] = []
	for slot_id in installed_modules_by_slot.keys():
		var module_id: String = String(installed_modules_by_slot.get(slot_id, ""))
		if module_id != "":
			active.append(module_id)
	return active

func get_active_module_slot_capacity() -> int:
	return ShipList.get_active_slot_count(current_ship_id)

func get_total_module_capacity() -> int:
	return ShipList.get_total_slot_count(current_ship_id)

func get_total_slot_count() -> int:
	return ShipList.get_total_slot_count(current_ship_id)

func get_active_slot_count() -> int:
	return ShipList.get_active_slot_count(current_ship_id)

func get_max_commands() -> int:
	var total: int = 4
	for module_id in get_active_modules():
		var module_data: Dictionary = ModuleList.get_module(module_id)
		total += int(module_data.get("command_bonus", 0))
		total += int(module_data.get("commands_bonus", 0))
	return max(total, 0)

func get_total_hull_bonus() -> int:
	var total: int = 0
	for module_id in get_active_modules():
		var module_data: Dictionary = ModuleList.get_module(module_id)
		total += int(module_data.get("hull_bonus", 0))
	return total

func get_max_hand_size() -> int:
	return max(5 + get_module_effect_total("hand_size_bonus"), 0)

func get_module_effect_total(effect_type: String) -> int:
	var total: int = 0

	for effect in get_module_effects(effect_type):
		total += int(effect.get("amount", 0))

	return total

func get_module_effects(effect_type: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []

	for module_id in get_active_modules():
		var module_data: Dictionary = ModuleList.get_module(module_id)
		for effect_variant in module_data.get("effects", []):
			var effect: Dictionary = effect_variant
			if String(effect.get("type", "")) != effect_type:
				continue
			var effect_copy: Dictionary = effect.duplicate(true)
			effect_copy["module_id"] = module_id
			matches.append(effect_copy)

	return matches

func set_hull(value: int) -> void:
	current_hull = clampi(value, 0, max_hull)
	emit_signal("hull_changed", current_hull, max_hull)

func heal_hull(amount: int) -> int:
	if amount <= 0:
		return 0

	var before: int = current_hull
	current_hull = clampi(current_hull + amount, 0, max_hull)
	var healed: int = current_hull - before
	emit_signal("hull_changed", current_hull, max_hull)
	return healed

func damage_hull(amount: int) -> void:
	if amount <= 0:
		return
	current_hull = maxi(current_hull - amount, 0)
	emit_signal("hull_changed", current_hull, max_hull)

func repair_hull(amount: int) -> void:
	heal_hull(amount)

func repair_ship(amount: int) -> void:
	heal_hull(amount)

func sync_ship_state(health: int, hull_max: int) -> void:
	max_hull = hull_max
	current_hull = clampi(health, 0, max_hull)
	emit_signal("hull_changed", current_hull, max_hull)

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	emit_signal("gold_changed", gold)
	return true

func get_battle_deck() -> Array[String]:
	ensure_run_state()
	if run_deck.is_empty():
		run_deck = starter_deck.duplicate()
	return _build_active_run_deck()

func add_card_to_deck(card_id: String) -> void:
	if card_id == "":
		return

	run_deck.append(card_id)
	discard_pile.append(card_id)
	emit_signal("deck_changed")

func add_cards_to_deck(cards: Array) -> void:
	for card_id in cards:
		if card_id is String and String(card_id) != "":
			add_card_to_deck(String(card_id))

func remove_card_from_deck(card_id: String) -> bool:
	if card_id == "":
		return false

	var removed: bool = false

	var run_idx: int = run_deck.find(card_id)
	if run_idx != -1:
		run_deck.remove_at(run_idx)
		removed = true

	var draw_idx: int = draw_pile.find(card_id)
	if draw_idx != -1:
		draw_pile.remove_at(draw_idx)
		removed = true

	var discard_idx: int = discard_pile.find(card_id)
	if discard_idx != -1:
		discard_pile.remove_at(discard_idx)
		removed = true

	var hand_idx: int = hand.find(card_id)
	if hand_idx != -1:
		hand.remove_at(hand_idx)
		removed = true

	if removed:
		emit_signal("deck_changed")

	return removed

func get_module_bonus_cards() -> Array[String]:
	return get_module_granted_cards()

func get_module_granted_cards() -> Array[String]:
	var granted_cards: Array[String] = []

	for module_id in get_active_modules():
		for card_id in ModuleList.get_module_granted_cards(module_id):
			granted_cards.append(card_id)

	return granted_cards

func consume_pending_bonus_cards() -> Array[String]:
	var cards: Array[String] = pending_bonus_cards.duplicate()
	pending_bonus_cards.clear()
	return cards

func add_pending_bonus_card(card_id: String) -> void:
	if card_id == "":
		return
	pending_bonus_cards.append(card_id)

func queue_bonus_card(card_id: String) -> void:
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

	for slot in ShipList.get_slots_of_type(current_ship_id, "cannon"):
		var slot_id: String = String(slot.get("id", ""))
		var module_id: String = String(installed_modules_by_slot.get(slot_id, ""))
		if module_id != "":
			total += 1

	for module_id in get_active_modules():
		var module_data: Dictionary = ModuleList.get_module(module_id)
		total += int(module_data.get("queue_bonus", 0))

	return max(total, 0)

func get_ship_name() -> String:
	return ShipList.get_ship_name(current_ship_id)

func get_ship_art_path() -> String:
	return ShipList.get_ship_art_path(current_ship_id)

func get_slot_type(slot_id: String) -> String:
	return ShipList.get_slot_type(current_ship_id, slot_id)

func get_ship_preview_data() -> Dictionary:
	var slot_entries: Array[Dictionary] = []

	for slot in get_ship_slots():
		var slot_id: String = String(slot.get("id", ""))
		slot_entries.append({
			"slot_id": slot_id,
			"slot_type": String(slot.get("type", "")),
			"module_id": get_installed_module(slot_id)
		})

	return {
		"ship_id": current_ship_id,
		"ship_name": get_ship_name(),
		"art_path": get_ship_art_path(),
		"current_hull": current_hull,
		"max_hull": max_hull,
		"cargo_capacity": cargo_capacity,
		"cargo_count": cargo_modules.size(),
		"cargo_modules": cargo_modules.duplicate(),
		"slots": slot_entries
	}

func add_module_to_cargo(module_id: String) -> bool:
	if module_id == "":
		return false
	if cargo_modules.size() >= cargo_capacity:
		return false

	cargo_modules.append(module_id)
	emit_signal("modules_changed")
	return true

func replace_cargo_module(index: int, new_module_id: String) -> bool:
	if new_module_id == "":
		return false
	if index < 0 or index >= cargo_modules.size():
		return false

	cargo_modules[index] = new_module_id
	emit_signal("modules_changed")
	return true

func remove_cargo_module(index: int) -> String:
	if index < 0 or index >= cargo_modules.size():
		return ""

	var removed: String = cargo_modules[index]
	cargo_modules.remove_at(index)
	emit_signal("modules_changed")
	return removed

func install_module_to_slot(slot_id: String, module_id: String) -> bool:
	if slot_id == "" or module_id == "":
		return false

	var slot_type: String = _get_slot_type(slot_id)
	if slot_type == "" or slot_type == "cargo":
		return false

	var module_def: Dictionary = ModuleList.get_module(module_id)
	if module_def.is_empty():
		return false

	var module_slot_type: String = String(module_def.get("slot_type", ""))
	if module_slot_type != slot_type:
		return false

	if not cargo_modules.has(module_id):
		return false

	var old_module: String = String(installed_modules_by_slot.get(slot_id, ""))

	if old_module != "":
		if cargo_modules.size() >= cargo_capacity:
			return false
		cargo_modules.append(old_module)

	var cargo_index: int = cargo_modules.find(module_id)
	if cargo_index != -1:
		cargo_modules.remove_at(cargo_index)

	installed_modules_by_slot[slot_id] = module_id
	_sync_modules_cache()
	_recalculate_ship_stats()
	if DeckManager.has_method("refresh_module_granted_cards"):
		DeckManager.refresh_module_granted_cards()
	emit_signal("modules_changed")
	emit_signal("ship_changed")
	emit_signal("hull_changed", current_hull, max_hull)
	return true

func swap_cargo_module_with_installed(slot_id: String, cargo_index: int) -> bool:
	if slot_id == "":
		return false
	if cargo_index < 0 or cargo_index >= cargo_modules.size():
		return false
	if not installed_modules_by_slot.has(slot_id):
		return false

	var installed_module_id: String = String(installed_modules_by_slot.get(slot_id, ""))
	if installed_module_id == "":
		return false

	var cargo_module_id: String = String(cargo_modules[cargo_index])
	if cargo_module_id == "":
		return false

	var slot_type: String = _get_slot_type(slot_id)
	if slot_type == "" or slot_type == "cargo":
		return false

	var cargo_module_def: Dictionary = ModuleList.get_module(cargo_module_id)
	if cargo_module_def.is_empty():
		return false
	if String(cargo_module_def.get("slot_type", "")) != slot_type:
		return false

	cargo_modules[cargo_index] = installed_module_id
	installed_modules_by_slot[slot_id] = cargo_module_id
	_sync_modules_cache()
	_recalculate_ship_stats()
	if DeckManager.has_method("refresh_module_granted_cards"):
		DeckManager.refresh_module_granted_cards()
	emit_signal("modules_changed")
	emit_signal("ship_changed")
	emit_signal("hull_changed", current_hull, max_hull)
	return true

func remove_installed_module(slot_id: String) -> bool:
	if slot_id == "":
		return false
	if cargo_modules.size() >= cargo_capacity:
		return false
	if not installed_modules_by_slot.has(slot_id):
		return false

	var module_id: String = String(installed_modules_by_slot.get(slot_id, ""))
	if module_id == "":
		return false

	cargo_modules.append(module_id)
	installed_modules_by_slot[slot_id] = ""
	_sync_modules_cache()
	_recalculate_ship_stats()
	if DeckManager.has_method("refresh_module_granted_cards"):
		DeckManager.refresh_module_granted_cards()
	emit_signal("modules_changed")
	emit_signal("ship_changed")
	emit_signal("hull_changed", current_hull, max_hull)
	return true

func set_current_ship(ship_id: String) -> void:
	current_ship_id = ship_id if ShipList.has_ship(ship_id) else DEFAULT_STARTER_SHIP_ID
	_setup_default_ship_state()
	_recalculate_ship_stats()
	emit_signal("modules_changed")
	emit_signal("ship_changed")
	emit_signal("hull_changed", current_hull, max_hull)

func _get_slot_type(slot_id: String) -> String:
	for slot in ShipList.get_ship_slots(current_ship_id):
		if String(slot.get("id", "")) == slot_id:
			return String(slot.get("type", ""))
	return ""

func to_save_dict() -> Dictionary:
	return {
		"selected_captain": selected_captain,
		"gold": gold,
		"max_hull": max_hull,
		"current_hull": current_hull,
		"starter_deck": starter_deck.duplicate(),
		"run_deck": _get_persistent_run_deck(),
		"current_ship_id": current_ship_id,
		"installed_modules_by_slot": installed_modules_by_slot.duplicate(true),
		"cargo_modules": cargo_modules.duplicate(),
		"cargo_capacity": cargo_capacity,
		"modules": get_active_modules().duplicate(),
		"pending_bonus_cards": pending_bonus_cards.duplicate()
	}

func load_from_save_dict(data: Dictionary) -> void:
	selected_captain = String(data.get("selected_captain", ""))
	gold = int(data.get("gold", 0))
	max_hull = int(data.get("max_hull", 40))
	current_hull = int(data.get("current_hull", max_hull))

	starter_deck.clear()
	for card_id in data.get("starter_deck", DEFAULT_STARTER_DECK):
		starter_deck.append(String(card_id))

	run_deck.clear()
	for card_id in data.get("run_deck", starter_deck):
		run_deck.append(String(card_id))

	current_ship_id = String(data.get("current_ship_id", DEFAULT_STARTER_SHIP_ID))
	if not ShipList.has_ship(current_ship_id):
		current_ship_id = DEFAULT_STARTER_SHIP_ID

	installed_modules_by_slot = _sanitize_installed_modules(
		current_ship_id,
		data.get("installed_modules_by_slot", {})
	)

	cargo_modules.clear()
	for module_id in data.get("cargo_modules", []):
		var cargo_module_id: String = String(module_id)
		if ModuleList.has_module(cargo_module_id):
			cargo_modules.append(cargo_module_id)

	cargo_capacity = int(data.get("cargo_capacity", ShipList.get_cargo_capacity(current_ship_id)))
	cargo_capacity = maxi(cargo_capacity, ShipList.get_cargo_capacity(current_ship_id))
	while cargo_modules.size() > cargo_capacity:
		cargo_modules.pop_back()

	var saved_installed: Dictionary = data.get("installed_modules_by_slot", {})
	if saved_installed.is_empty():
		var legacy_modules: Array = data.get("modules", [])
		installed_modules_by_slot = ShipList.get_default_installed_modules(current_ship_id)
		var cannon_slots: Array = ShipList.get_slots_of_type(current_ship_id, "cannon")
		for i in range(min(cannon_slots.size(), legacy_modules.size())):
			var legacy_module_id: String = String(legacy_modules[i])
			if ModuleList.has_module(legacy_module_id):
				installed_modules_by_slot[String(cannon_slots[i].get("id", ""))] = legacy_module_id

	pending_bonus_cards.clear()
	for card_id in data.get("pending_bonus_cards", []):
		pending_bonus_cards.append(String(card_id))

	draw_pile = run_deck.duplicate()
	discard_pile.clear()
	hand.clear()
	_sync_modules_cache()
	_recalculate_ship_stats()

	emit_signal("gold_changed", gold)
	emit_signal("hull_changed", current_hull, max_hull)
	emit_signal("deck_changed")
	emit_signal("modules_changed")
	emit_signal("ship_changed")

func _sanitize_installed_modules(ship_id: String, saved_installed: Dictionary) -> Dictionary:
	var installed: Dictionary = ShipList.get_default_installed_modules(ship_id)

	for slot_id_variant in saved_installed.keys():
		var slot_id: String = String(slot_id_variant)
		if not installed.has(slot_id):
			continue

		var module_id: String = String(saved_installed[slot_id_variant])
		if module_id == "":
			installed[slot_id] = ""
			continue

		if not ModuleList.has_module(module_id):
			continue

		var slot_type: String = ShipList.get_slot_type(ship_id, slot_id)
		var module_def: Dictionary = ModuleList.get_module(module_id)
		if String(module_def.get("slot_type", "")) != slot_type:
			continue

		installed[slot_id] = module_id

	return installed

func _build_active_run_deck() -> Array[String]:
	var deck_cards: Array[String] = _get_persistent_run_deck()

	for card_id in get_module_granted_cards():
		deck_cards.append(card_id)

	return deck_cards

func _get_persistent_run_deck() -> Array[String]:
	var persistent_cards: Array[String] = run_deck.duplicate()
	var granted_counts: Dictionary = {}

	for card_id in get_module_granted_cards():
		granted_counts[card_id] = int(granted_counts.get(card_id, 0)) + 1

	if granted_counts.is_empty():
		return persistent_cards

	var sanitized: Array[String] = []
	for card_id in persistent_cards:
		var granted_remaining: int = int(granted_counts.get(card_id, 0))
		if granted_remaining > 0:
			granted_counts[card_id] = granted_remaining - 1
			continue
		sanitized.append(card_id)

	return sanitized
