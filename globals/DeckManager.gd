extends Node

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
	deck = PlayerData.get_battle_deck()
	deck.shuffle()

	var battle_bonus_cards: Array[String] = []

	var module_bonus_cards: Array[String] = PlayerData.get_module_bonus_cards()
	for card_id in module_bonus_cards:
		battle_bonus_cards.append(card_id)

	var pending_bonus_cards: Array[String] = PlayerData.consume_pending_bonus_cards()
	for card_id in pending_bonus_cards:
		battle_bonus_cards.append(card_id)

	for card_id in battle_bonus_cards:
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

func _create_card_in_hand(card_id: String) -> void:
	var def: Dictionary = card_defs.get(card_id, {})
	if def.is_empty():
		push_error("DeckManager: Missing card definition for %s" % card_id)
		return

	var card = card_scene.instantiate()
	card.set_meta("card_id", card_id)
	card.card_name = String(def.get("name", card_id))
	card.card_type = String(def.get("type", "Skill")).to_lower()
	card.value = _get_display_value(def)
	card.description = String(def.get("description", ""))
	card.card_category = String(def.get("category", "Queue"))
	card.art_path = String(def.get("art", ""))
	card.frame_path = String(def.get("frame", ""))
	card.hide_text = bool(def.get("hide_text", false))
	card.update_card()

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

func resolve_fire_phase() -> void:
	var needed: int = max_hand_size - hand.size()
	if needed <= 0:
		UIManager.update_deck_ui(deck.size(), discard_pile.size())
		return

	draw_cards(needed)
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
