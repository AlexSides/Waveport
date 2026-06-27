extends Node

const CombatMath = preload("res://globals/CombatMath.gd")
const TurnEffects = preload("res://globals/TurnEffects.gd")
const QUEUE_ITEM_SCENE = preload("res://ui/QueueItem.tscn")

@export var queue_path: NodePath
@onready var queue_container: Node = null

var action_queue: Array = []

var max_commands: int = 4
var current_commands: int = 4

var cannon_bonus_this_turn: int = 0
var pending_next_cannon_multiplier_percent: int = 100
var gain_block_next_turn_pending: int = 0
var hold_fast_active: bool = false
var blood_rush_active: bool = false
var blood_rush_draw_count: int = 0
var lifesteal_attacks_this_turn_percent: int = 0
var cannons_apply_burn_this_turn: int = 0
var end_turn_without_firing_flag: bool = false
var repeat_last_cannon_count: int = 0

var bleed_taken_this_turn: int = 0
var bleed_taken_this_combat: int = 0
var regen_stacks: int = 0
var cards_played_this_turn: int = 0
var cannons_fired_this_turn: int = 0
var first_cannon_damage_bonus_this_turn: int = 0
var module_cannon_damage_bonus: int = 0

func _ready() -> void:
	if queue_path and has_node(queue_path):
		queue_container = get_node(queue_path)
	else:
		print("TurnManager: no ActionQueue found at path:", queue_path)

func reset_for_battle() -> void:
	action_queue.clear()

	max_commands = 4
	current_commands = max_commands

	cannon_bonus_this_turn = 0
	pending_next_cannon_multiplier_percent = 100
	gain_block_next_turn_pending = 0
	hold_fast_active = false
	blood_rush_active = false
	blood_rush_draw_count = 0
	lifesteal_attacks_this_turn_percent = 0
	cannons_apply_burn_this_turn = 0
	end_turn_without_firing_flag = false
	repeat_last_cannon_count = 0
	bleed_taken_this_turn = 0
	bleed_taken_this_combat = 0
	regen_stacks = 0
	cards_played_this_turn = 0
	cannons_fired_this_turn = 0
	first_cannon_damage_bonus_this_turn = 0
	module_cannon_damage_bonus = PlayerData.get_module_effect_total("cannon_damage_bonus")

	if queue_container:
		for child in queue_container.get_children():
			child.queue_free()

	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_method("get_player_ship"):
		var player_ship = battle_scene.get_player_ship()
		var combat_start_block: int = PlayerData.get_module_effect_total("combat_start_block")
		if player_ship and combat_start_block > 0:
			player_ship.add_block(combat_start_block)
			if battle_scene.has_method("log_message"):
				battle_scene.log_message("Modules grant %d Block at combat start." % combat_start_block)

func start_player_turn() -> void:
	var battle_scene = get_tree().current_scene
	if not battle_scene:
		return

	var player_ship = null
	if battle_scene.has_method("get_player_ship"):
		player_ship = battle_scene.get_player_ship()

	current_commands = max_commands
	bleed_taken_this_turn = 0
	cards_played_this_turn = 0
	cannons_fired_this_turn = 0
	first_cannon_damage_bonus_this_turn = PlayerData.get_module_effect_total("first_cannon_damage_bonus")
	module_cannon_damage_bonus = PlayerData.get_module_effect_total("cannon_damage_bonus")

	if player_ship and gain_block_next_turn_pending > 0:
		player_ship.add_block(gain_block_next_turn_pending)
		if battle_scene.has_method("log_message"):
			battle_scene.log_message("Prepare grants %d Block." % gain_block_next_turn_pending)
		gain_block_next_turn_pending = 0

	if player_ship and regen_stacks > 0:
		player_ship.repair(regen_stacks)
		if battle_scene.has_method("log_message"):
			battle_scene.log_message("Regen restores %d HP." % regen_stacks)

	cannon_bonus_this_turn = 0
	hold_fast_active = false
	blood_rush_active = false
	blood_rush_draw_count = 0
	lifesteal_attacks_this_turn_percent = 0
	cannons_apply_burn_this_turn = 0
	end_turn_without_firing_flag = false
	repeat_last_cannon_count = 0

	if battle_scene.has_method("update_hud"):
		battle_scene.update_hud()

func end_player_turn() -> void:
	var battle_scene = get_tree().current_scene
	if not battle_scene:
		return

	var player_ship = null
	if battle_scene.has_method("get_player_ship"):
		player_ship = battle_scene.get_player_ship()

	if hold_fast_active and player_ship:
		var empty_slots: int = get_empty_cannons()
		var block_to_gain: int = empty_slots * 4
		if block_to_gain > 0:
			player_ship.add_block(block_to_gain)
			if battle_scene.has_method("log_message"):
				battle_scene.log_message("Hold Fast grants %d Block." % block_to_gain)
		hold_fast_active = false

	TurnEffects.burn_flames_left_in_hand(player_ship)

	if battle_scene.has_method("update_hud"):
		battle_scene.update_hud()

func on_fire_button_pressed() -> void:
	var battle_scene = get_tree().current_scene
	if not battle_scene:
		return

	if end_turn_without_firing_flag:
		if battle_scene.has_method("log_message"):
			battle_scene.log_message("Your turn ends without firing.")

		end_player_turn()

		if not _should_skip_draw_after_fire(battle_scene):
			DeckManager.resolve_fire_phase()

		_clear_queue()
		_clear_turn_queue_modifiers()

		if battle_scene.has_method("update_hud"):
			battle_scene.update_hud()
		return

	var enemy = null
	if battle_scene.has_method("get_current_enemy"):
		enemy = battle_scene.get_current_enemy()

	var player_ship = null
	if battle_scene.has_method("get_player_ship"):
		player_ship = battle_scene.get_player_ship()

	var fired_queue: Array = action_queue.duplicate(true)
	var sim: Dictionary = CombatMath.simulate_queue(self, action_queue, enemy)

	for step in sim["steps"]:
		var card_data: Dictionary = step["card"]
		var t: String = String(card_data.get("type", "")).to_lower()

		if t == "attack":
			var damages: Array = step.get("damages", [])

			for damage_value in damages:
				enemy = null
				if battle_scene.has_method("get_current_enemy"):
					enemy = battle_scene.get_current_enemy()

				if enemy == null or not is_instance_valid(enemy):
					break

				var damage: int = int(damage_value)

				if card_data.get("is_cannon", false):
					cannons_fired_this_turn += 1

				if card_data.get("lose_hp", 0) > 0 and player_ship:
					player_ship.lose_hp(int(card_data["lose_hp"]))

				if card_data.get("self_damage", 0) > 0 and player_ship:
					player_ship.take_damage(int(card_data["self_damage"]))

				if card_data.get("bleed", 0) > 0 and player_ship:
					TurnEffects.apply_bleed_to_self(self, player_ship, int(card_data["bleed"]))

				if enemy != null and is_instance_valid(enemy) and enemy.health > 0:
					if enemy.has_method("is_targetable") and not enemy.is_targetable():
						continue

					enemy.take_damage(damage)

					if lifesteal_attacks_this_turn_percent > 0 and player_ship:
						var heal_amount: int = int(floor(damage * lifesteal_attacks_this_turn_percent / 100.0))
						if heal_amount > 0:
							player_ship.repair(heal_amount)

					if card_data.get("is_cannon", false) and cannons_apply_burn_this_turn > 0:
						TurnEffects.apply_burn_to_enemy(enemy, cannons_apply_burn_this_turn)

					if battle_scene.has_method("wait_for_enemy_hit_resolution"):
						await battle_scene.wait_for_enemy_hit_resolution()

					await get_tree().create_timer(0.45).timeout

			if int(step.get("sets_next_multiplier_to", 100)) > 100 and battle_scene.has_method("log_message"):
				battle_scene.log_message("%s primes the next cannon!" % String(card_data.get("name", "Card")))

		elif t == "block":
			if player_ship:
				enemy = null
				if battle_scene.has_method("get_current_enemy"):
					enemy = battle_scene.get_current_enemy()
				player_ship.add_block(int(CombatMath.get_card_numeric_value(self, card_data, "block", enemy)))

		elif t == "heal":
			if player_ship:
				player_ship.repair(int(CombatMath.get_card_numeric_value(self, card_data, "heal", enemy)))

	_finalize_fired_queue(fired_queue)
	end_player_turn()

	if not _should_skip_draw_after_fire(battle_scene):
		DeckManager.resolve_fire_phase()

	_clear_queue()
	_clear_turn_queue_modifiers()

	cannon_bonus_this_turn = 0
	cannons_apply_burn_this_turn = 0
	lifesteal_attacks_this_turn_percent = 0

	if battle_scene.has_method("update_hud"):
		battle_scene.update_hud()

func queue_card(card: Node) -> bool:
	var limit: int = PlayerData.get_queue_limit()
	if action_queue.size() >= limit:
		UIManager.show_warning("Queue is full (max %d)" % limit)
		return false

	var card_data: Dictionary = CombatMath.build_queue_card_data(card, DeckManager.card_defs)
	if card_data.is_empty():
		push_error("TurnManager: Missing card definition for %s" % str(card.get_meta("card_id")))
		return false

	var card_cost: int = int(card_data.get("cost", card.get("cost")))
	card_data["cost"] = card_cost

	if not can_afford_cost(card_cost):
		UIManager.show_warning("Not enough Commands")
		return false

	action_queue.append(card_data)
	_refresh_queue_ui()

	spend_commands(card_cost)
	DeckManager.remove_card_from_hand(card)

	if get_tree().current_scene.has_method("update_hud"):
		get_tree().current_scene.update_hud()

	return true

func resolve_instant_card(card: Node) -> bool:
	var card_cost: int = int(card.get("cost"))
	if not can_afford_cost(card_cost):
		UIManager.show_warning("Not enough Commands")
		return false

	spend_commands(card_cost)
	TurnEffects.resolve_instant_card(self, card)

	if get_tree().current_scene.has_method("update_hud"):
		get_tree().current_scene.update_hud()

	return true

func is_card_in_queue(card: Node) -> bool:
	for data in action_queue:
		if data["id"] == card.get_meta("card_id"):
			return true
	return false

func get_queue_size() -> int:
	return action_queue.size()

func get_queue_limit() -> int:
	return PlayerData.get_queue_limit()

func get_queued_cannons() -> int:
	var total: int = 0
	for card_data in action_queue:
		if card_data.get("is_cannon", false):
			total += 1
	return total

func get_empty_cannons() -> int:
	return max(get_queue_limit() - get_queued_cannons(), 0)

func get_combat_value(key: String, enemy = null) -> int:
	return CombatMath.get_combat_value(self, key, enemy)

func get_queue_preview(enemy = null) -> Array:
	return CombatMath.simulate_queue(self, action_queue, enemy).get("steps", [])

func unload_queue() -> void:
	var queue_copy: Array = action_queue.duplicate(true)
	_clear_queue()

	for card_data in queue_copy:
		refund_commands(int(card_data.get("cost", 0)))
		_add_card_to_hand_from_def(String(card_data.get("id", "")))

	if get_tree().current_scene.has_method("update_hud"):
		get_tree().current_scene.update_hud()

func get_current_commands() -> int:
	return current_commands

func get_max_commands() -> int:
	return max_commands

func can_afford_cost(card_cost: int) -> bool:
	return current_commands >= max(card_cost, 0)

func spend_commands(amount: int) -> void:
	current_commands = max(current_commands - max(amount, 0), 0)

func refund_commands(amount: int) -> void:
	current_commands = min(current_commands + max(amount, 0), max_commands)

func _add_card_to_hand_from_def(card_id: String) -> void:
	var card = DeckManager.create_card_instance(card_id)
	if card == null:
		return

	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_node("CardHand"):
		battle_scene.get_node("CardHand").add_child(card)
	else:
		DeckManager.battle_scene.card_hand.add_child(card)

	DeckManager.hand.append(card)
	UIManager.update_deck_ui(DeckManager.deck.size(), DeckManager.discard_pile.size())

func _finalize_fired_queue(fired_queue: Array) -> void:
	for card_data in fired_queue:
		var card_id: String = String(card_data.get("id", ""))
		if card_id == "":
			continue

		var def: Dictionary = DeckManager.card_defs.get(card_id, {})
		if bool(def.get("rot", false)):
			PlayerData.remove_card_from_deck(card_id)
		else:
			DeckManager.discard_card_id(card_id)

func _clear_queue() -> void:
	action_queue.clear()
	_refresh_queue_ui()

func _clear_turn_queue_modifiers() -> void:
	pending_next_cannon_multiplier_percent = 100
	repeat_last_cannon_count = 0

func _refresh_queue_ui() -> void:
	if queue_container == null:
		return

	for child in queue_container.get_children():
		child.queue_free()

	for card_data in action_queue:
		var item = QUEUE_ITEM_SCENE.instantiate()
		if item.has_method("setup"):
			item.setup(card_data)
		queue_container.add_child(item)

func _should_skip_draw_after_fire(battle_scene: Node) -> bool:
	if battle_scene and battle_scene.has_method("should_skip_draw_after_fire"):
		return bool(battle_scene.should_skip_draw_after_fire())
	return false
