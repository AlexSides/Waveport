extends Node
const CombatMath = preload("res://globals/CombatMath.gd")

static func resolve_instant_card(turn_manager, card: Node) -> void:
	var battle_scene = turn_manager.get_tree().current_scene
	if not battle_scene:
		return

	var player_ship = null
	if battle_scene.has_method("get_player_ship"):
		player_ship = battle_scene.get_player_ship()

	var enemy = null
	if battle_scene.has_method("get_current_enemy"):
		enemy = battle_scene.get_current_enemy()

	var def: Dictionary = DeckManager.card_defs.get(card.get_meta("card_id"), {})
	if def.is_empty():
		push_error("TurnEffects: Missing instant card definition for %s" % str(card.get_meta("card_id")))
		return

	var t: String = String(def.get("type", card.card_type)).to_lower()
	turn_manager.cards_played_this_turn += 1

	match t:
		"block":
			var block_amount := int(def.get("block", def.get("value", 0)))
			if player_ship and block_amount > 0:
				player_ship.add_block(block_amount)

		"heal":
			var heal_amount := int(def.get("heal", def.get("value", 0)))
			if def.get("heal_from_hp_lost_this_combat_percent", 0) > 0:
				heal_amount = int(floor(turn_manager.bleed_taken_this_combat * int(def["heal_from_hp_lost_this_combat_percent"]) / 100.0))
			if player_ship and heal_amount > 0:
				player_ship.repair(heal_amount)

		"attack":
			if enemy and is_instance_valid(enemy) and enemy.health > 0:
				if not (enemy.has_method("is_targetable") and not enemy.is_targetable()):
					var damage := int(CombatMath.get_card_numeric_value(turn_manager, def, "attack", enemy))
					if damage <= 0:
						damage = int(def.get("value", 0))
					enemy.take_damage(damage)

			if def.get("consume_all_block", false) and player_ship:
				player_ship.clear_block()

	if def.get("block", 0) > 0 and t != "block" and player_ship:
		player_ship.add_block(int(def["block"]))

	if def.get("bleed", 0) > 0 and player_ship:
		apply_bleed_to_self(turn_manager, player_ship, int(def["bleed"]))

	if def.get("self_damage", 0) > 0 and player_ship:
		player_ship.take_damage(int(def["self_damage"]))

	if def.get("lose_hp", 0) > 0 and player_ship:
		player_ship.lose_hp(int(def["lose_hp"]))

	if def.get("cannon_bonus_this_turn", 0) > 0:
		turn_manager.cannon_bonus_this_turn += int(def["cannon_bonus_this_turn"])

	if def.get("gain_block_next_turn", 0) > 0:
		turn_manager.gain_block_next_turn_pending += int(def["gain_block_next_turn"])

	if def.get("draw", 0) > 0:
		draw_cards(int(def["draw"]))

	if def.get("draw_on_bleed_this_turn", 0) > 0:
		turn_manager.blood_rush_active = true
		turn_manager.blood_rush_draw_count = int(def["draw_on_bleed_this_turn"])

	if def.get("lifesteal_attacks_this_turn_percent", 0) > 0:
		turn_manager.lifesteal_attacks_this_turn_percent = int(def["lifesteal_attacks_this_turn_percent"])

	if def.get("regen", 0) > 0:
		turn_manager.regen_stacks += int(def["regen"])

	if def.get("repeat_last_cannon_in_queue", 0) > 0:
		turn_manager.repeat_last_cannon_count += int(def["repeat_last_cannon_in_queue"])

	if def.get("apply_burn", 0) > 0 and enemy and is_instance_valid(enemy):
		apply_burn_to_enemy(enemy, int(def["apply_burn"]))

	if def.get("double_enemy_burn", false) and enemy and is_instance_valid(enemy):
		double_enemy_burn(enemy)

	if def.get("cannons_apply_burn_this_turn", 0) > 0:
		turn_manager.cannons_apply_burn_this_turn += int(def["cannons_apply_burn_this_turn"])

	if def.get("end_turn_without_firing", false):
		turn_manager.end_turn_without_firing_flag = true

	if def.get("block_per_empty_cannon_slot_end_turn", 0) > 0:
		turn_manager.hold_fast_active = true

	if def.get("add_to_hand", []).size() > 0:
		for entry in def["add_to_hand"]:
			var add_id: String = entry.get("id", "")
			var count: int = int(entry.get("count", 1))
			for i in range(count):
				add_card_to_hand(add_id)

	if def.get("look_top_deck", 0) > 0:
		print("prep_and_pack not fully implemented yet.")

	if def.get("rot", false):
		DeckManager.remove_card_permanently(card)
	else:
		DeckManager.play_card(card)

	turn_manager._refresh_queue_ui()

	if battle_scene.has_method("update_hud"):
		battle_scene.update_hud()

static func apply_bleed_to_self(turn_manager, player_ship, amount: int) -> void:
	if amount <= 0 or player_ship == null:
		return
	turn_manager.bleed_taken_this_turn += amount
	turn_manager.bleed_taken_this_combat += amount
	player_ship.lose_hp(amount)
	if turn_manager.blood_rush_active:
		draw_cards(int(turn_manager.blood_rush_draw_count))

static func apply_bleed_to_enemy(enemy, amount: int) -> void:
	if amount <= 0 or enemy == null:
		return
	if enemy.has_method("is_targetable") and not enemy.is_targetable():
		return
	if enemy.has_method("apply_bleed"):
		enemy.apply_bleed(amount)
	else:
		print("Enemy missing apply_bleed(), bleed not persisted.")

static func apply_burn_to_enemy(enemy, amount: int) -> void:
	if amount <= 0 or enemy == null:
		return
	if enemy.has_method("is_targetable") and not enemy.is_targetable():
		return
	if enemy.has_method("apply_burn"):
		enemy.apply_burn(amount)
	else:
		print("Enemy missing apply_burn(), burn not persisted.")

static func double_enemy_burn(enemy) -> void:
	if enemy == null:
		return
	if enemy.has_method("is_targetable") and not enemy.is_targetable():
		return
	if enemy.has_method("get_burn") and enemy.has_method("apply_burn"):
		var current_burn: int = int(enemy.get_burn())
		if current_burn > 0:
			enemy.apply_burn(current_burn)
	elif "burn" in enemy:
		enemy.burn *= 2
	else:
		print("Enemy burn doubling not implemented on enemy script.")

static func draw_cards(count: int) -> void:
	if count <= 0:
		return
	if DeckManager.has_method("draw_cards"):
		DeckManager.draw_cards(count)
	else:
		for i in range(count):
			if DeckManager.has_method("draw_card"):
				DeckManager.draw_card()

static func add_card_to_hand(card_id: String) -> void:
	if card_id == "":
		return
	var battle_scene: Node = Engine.get_main_loop().current_scene
	if battle_scene == null:
		return
	if not DeckManager.card_defs.has(card_id):
		return
	var card: Node = DeckManager.create_card_instance(card_id)
	if card == null:
		return
	if battle_scene.card_hand == null:
		return
	battle_scene.card_hand.add_child(card)
	DeckManager.hand.append(card)
	UIManager.update_deck_ui(DeckManager.deck.size(), DeckManager.discard_pile.size())

static func burn_flames_left_in_hand(player_ship) -> void:
	if player_ship == null:
		return
	for card in DeckManager.hand:
		if is_instance_valid(card):
			var card_id = card.get_meta("card_id", "")
			if card_id == "flame":
				player_ship.take_damage(1)
