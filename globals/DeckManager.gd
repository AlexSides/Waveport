extends Node

const ModuleList = preload("res://data/ModuleList.gd")

var deck: Array = []
var hand: Array = []
var discard_pile: Array = []
var max_hand_size: int = 5
var card_scene = preload("res://cards/Card.tscn")
var card_defs
var battle_scene = null

func setup_battle(scene_ref, definitions) -> void:
	battle_scene = scene_ref
	card_defs = definitions
	reset()

func reset() -> void:
	_clear_hand_nodes()
	hand.clear()
	discard_pile.clear()
	max_hand_size = PlayerData.get_max_hand_size()
	deck = PlayerData.get_battle_deck()
	deck.shuffle()

	var pending_bonus_cards: Array[String] = PlayerData.consume_pending_bonus_cards()

	for card_id in pending_bonus_cards:
		var idx: int = deck.find(card_id)
		if idx != -1:
			deck.remove_at(idx)
		_create_card_in_hand(card_id)

	draw_cards(max_hand_size - hand.size())
	UIManager.update_deck_ui(deck.size(), discard_pile.size())

func draw_cards(count: int = 1) -> void:
	for i in range(count):
		if deck.is_empty():
			if discard_pile.is_empty():
				UIManager.update_deck_ui(deck.size(), discard_pile.size())
				return

			deck = discard_pile.duplicate()
			deck.shuffle()
			discard_pile.clear()
			UIManager.update_deck_ui(deck.size(), discard_pile.size())

		var card_id: String = String(deck.pop_front())
		_create_card_in_hand(card_id)

	UIManager.update_deck_ui(deck.size(), discard_pile.size())

func create_card_instance(card_id: String) -> Node:
	var def: Dictionary = card_defs.get(card_id, {})
	if def.is_empty():
		push_error("DeckManager: Missing card definition for %s" % card_id)
		return null

	var card = card_scene.instantiate()
	card.set_meta("card_id", card_id)
	card.card_id = card_id
	card.card_name = String(def.get("name", card_id))
	card.card_type = String(def.get("type", "Skill")).to_lower()
	card.value = _get_display_value(def)
	card.cost = int(def.get("cost", 0))
	card.description = String(def.get("description", ""))
	card.card_category = String(def.get("category", "Queue"))
	card.art_path = String(def.get("art", ""))
	card.frame_path = String(def.get("frame", ""))
	card.hide_text = bool(def.get("hide_text", false))
	card.update_card()
	return card

func _create_card_in_hand(card_id: String) -> void:
	var card = create_card_instance(card_id)
	if card == null:
		return

	battle_scene.card_hand.add_child(card)
	hand.append(card)

func play_card(card: Node) -> void:
	if hand.has(card):
		hand.erase(card)

	var id = card.get_meta("card_id")
	var def: Dictionary = card_defs.get(id, {})

	if not bool(def.get("rot", false)):
		discard_pile.append(id)

	if not TurnManager.is_card_in_queue(card):
		card.queue_free()

	if card.has_method("on_play"):
		card.on_play()

	UIManager.update_deck_ui(deck.size(), discard_pile.size())

func remove_card_from_hand(card: Node) -> void:
	if hand.has(card):
		hand.erase(card)

	if is_instance_valid(card):
		card.queue_free()

	UIManager.update_deck_ui(deck.size(), discard_pile.size())

func discard_card_id(card_id: String) -> void:
	if card_id == "":
		return

	discard_pile.append(card_id)
	UIManager.update_deck_ui(deck.size(), discard_pile.size())

func resolve_fire_phase() -> void:
	var needed: int = max_hand_size - hand.size()
	if needed <= 0:
		UIManager.update_deck_ui(deck.size(), discard_pile.size())
		return

	draw_cards(needed)
	UIManager.update_deck_ui(deck.size(), discard_pile.size())

func refresh_module_granted_cards() -> void:
	if card_defs == null:
		return

	var module_card_ids: Array[String] = ModuleList.get_all_module_granted_card_ids()
	if module_card_ids.is_empty():
		return

	var desired_counts: Dictionary = {}
	for card_id in PlayerData.get_module_granted_cards():
		desired_counts[card_id] = int(desired_counts.get(card_id, 0)) + 1

	var current_counts: Dictionary = {}
	for card_id in deck:
		var deck_card_id: String = String(card_id)
		if module_card_ids.has(deck_card_id):
			current_counts[deck_card_id] = int(current_counts.get(deck_card_id, 0)) + 1

	for card_id in discard_pile:
		var discard_card_id: String = String(card_id)
		if module_card_ids.has(discard_card_id):
			current_counts[discard_card_id] = int(current_counts.get(discard_card_id, 0)) + 1

	for card in hand:
		if card == null or not is_instance_valid(card):
			continue
		var hand_card_id: String = String(card.get_meta("card_id", ""))
		if module_card_ids.has(hand_card_id):
			current_counts[hand_card_id] = int(current_counts.get(hand_card_id, 0)) + 1

	for card_id in module_card_ids:
		var desired: int = int(desired_counts.get(card_id, 0))
		var current: int = int(current_counts.get(card_id, 0))

		while current > desired:
			if _remove_card_id_from_zone(deck, card_id):
				current -= 1
				continue
			if _remove_card_id_from_zone(discard_pile, card_id):
				current -= 1
				continue
			if _remove_card_instance_from_hand(card_id):
				current -= 1
				continue
			break

		while current < desired:
			deck.append(card_id)
			current += 1

	UIManager.update_deck_ui(deck.size(), discard_pile.size())

func remove_card_permanently(card: Node) -> void:
	if hand.has(card):
		hand.erase(card)

	var id = card.get_meta("card_id")

	var discard_idx: int = discard_pile.find(id)
	if discard_idx != -1:
		discard_pile.remove_at(discard_idx)

	var deck_idx: int = deck.find(id)
	if deck_idx != -1:
		deck.remove_at(deck_idx)

	var run_idx: int = PlayerData.run_deck.find(id)
	if run_idx != -1:
		PlayerData.run_deck.remove_at(run_idx)

	card.queue_free()
	UIManager.update_deck_ui(deck.size(), discard_pile.size())

func _clear_hand_nodes() -> void:
	if battle_scene and battle_scene.card_hand:
		for child in battle_scene.card_hand.get_children():
			child.queue_free()

func _remove_card_id_from_zone(zone: Array, card_id: String) -> bool:
	var idx: int = zone.find(card_id)
	if idx == -1:
		return false
	zone.remove_at(idx)
	return true

func _remove_card_instance_from_hand(card_id: String) -> bool:
	for card in hand.duplicate():
		if card == null or not is_instance_valid(card):
			continue
		if String(card.get_meta("card_id", "")) != card_id:
			continue
		remove_card_from_hand(card)
		return true
	return false

func _get_display_value(def: Dictionary) -> int:
	if def.has("value"):
		return int(def.get("value", 0))

	if def.has("attack"):
		var attack_value = def.get("attack", 0)
		if attack_value is int or attack_value is float:
			return int(attack_value)
		return 0

	if def.has("block"):
		var block_value = def.get("block", 0)
		if block_value is int or block_value is float:
			return int(block_value)
		return 0

	if def.has("heal"):
		var heal_value = def.get("heal", 0)
		if heal_value is int or heal_value is float:
			return int(heal_value)
		return 0

	return 0
