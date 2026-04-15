extends Node

static func get_combat_value(turn_manager, key: String, enemy = null) -> int:
	match key:
		"queue_limit":
			return turn_manager.get_queue_limit()
		"queue_size":
			return turn_manager.get_queue_size()
		"queued_cannons":
			return turn_manager.get_queued_cannons()
		"empty_cannons":
			return turn_manager.get_empty_cannons()
		"bleed_taken_this_turn":
			return turn_manager.bleed_taken_this_turn
		"bleed_taken_this_combat":
			return turn_manager.bleed_taken_this_combat
		"cards_played_this_turn":
			return turn_manager.cards_played_this_turn
		"cannons_fired_this_turn":
			return turn_manager.cannons_fired_this_turn
		"enemy_burn":
			if enemy and enemy.has_method("get_burn"):
				return int(enemy.get_burn())
			return 0
		_:
			return 0

static func get_card_numeric_value(turn_manager, card_data: Dictionary, key: String, enemy = null) -> int:
	if not card_data.has(key):
		return 0

	var raw = card_data.get(key, 0)

	if raw is int:
		return raw

	if raw is float:
		return int(raw)

	if raw is String:
		return evaluate_formula(turn_manager, raw, enemy)

	return 0

static func evaluate_formula(turn_manager, formula: String, enemy = null) -> int:
	var expr := Expression.new()
	var inputs := PackedStringArray([
		"queue_limit",
		"queue_size",
		"queued_cannons",
		"empty_cannons",
		"bleed_taken_this_turn",
		"bleed_taken_this_combat",
		"cards_played_this_turn",
		"cannons_fired_this_turn",
		"enemy_burn"
	])

	var err = expr.parse(formula, inputs)
	if err != OK:
		push_error("CombatMath: Failed to parse formula: %s" % formula)
		return 0

	var values = [
		get_combat_value(turn_manager, "queue_limit", enemy),
		get_combat_value(turn_manager, "queue_size", enemy),
		get_combat_value(turn_manager, "queued_cannons", enemy),
		get_combat_value(turn_manager, "empty_cannons", enemy),
		get_combat_value(turn_manager, "bleed_taken_this_turn", enemy),
		get_combat_value(turn_manager, "bleed_taken_this_combat", enemy),
		get_combat_value(turn_manager, "cards_played_this_turn", enemy),
		get_combat_value(turn_manager, "cannons_fired_this_turn", enemy),
		get_combat_value(turn_manager, "enemy_burn", enemy)
	]

	var result = expr.execute(values, turn_manager)
	if expr.has_execute_failed():
		push_error("CombatMath: Failed to execute formula: %s" % formula)
		return 0

	return int(result)

static func get_card_base_attack_value(turn_manager, card_data: Dictionary, enemy = null) -> int:
	var damage: int = int(get_card_numeric_value(turn_manager, card_data, "attack", enemy))

	if damage <= 0:
		damage = int(card_data.get("value", 0))

	if card_data.get("bonus_damage_per_bleed_taken_this_combat", 0) > 0:
		damage += int(card_data["bonus_damage_per_bleed_taken_this_combat"]) * turn_manager.bleed_taken_this_combat

	return damage

static func simulate_queue(turn_manager, action_queue: Array, enemy = null) -> Dictionary:
	var steps: Array = []
	var preview_cannon_bonus: int = turn_manager.cannon_bonus_this_turn
	var preview_next_multiplier: int = turn_manager.pending_next_cannon_multiplier_percent
	var last_cannon_index := -1

	for i in range(action_queue.size()):
		var c: Dictionary = action_queue[i]
		if c.get("is_cannon", false):
			last_cannon_index = i

	for i in range(action_queue.size()):
		var card_data: Dictionary = action_queue[i]
		var step := {
			"card": card_data,
			"damages": [],
			"damage_text": "",
			"damage_total": 0,
			"uses_multiplier": false,
			"sets_next_multiplier_to": 100,
			"repeat_count": 1
		}

		var t: String = String(card_data.get("type", "")).to_lower()

		if t == "attack":
			var repeat_count := 1
			if i == last_cannon_index and card_data.get("is_cannon", false):
				repeat_count = 1 + turn_manager.repeat_last_cannon_count

			var damages: Array = []
			var damage_total := 0

			for fire_index in range(repeat_count):
				var damage: int = get_card_base_attack_value(turn_manager, card_data, enemy)

				if i == action_queue.size() - 1 and fire_index == 0:
					damage += int(card_data.get("bonus_if_last_in_queue", 0))

				if card_data.get("is_cannon", false):
					damage += preview_cannon_bonus

					if preview_next_multiplier > 100:
						damage = int(floor(damage * preview_next_multiplier / 100.0))
						if fire_index == 0:
							step["uses_multiplier"] = true
						preview_next_multiplier = 100

				if fire_index == 0 and card_data.get("prime_next_cannon_multiplier_percent", 100) > 100:
					var next_mult := int(card_data["prime_next_cannon_multiplier_percent"])
					step["sets_next_multiplier_to"] = next_mult
					preview_next_multiplier = next_mult

				damages.append(damage)
				damage_total += damage

			step["repeat_count"] = repeat_count
			step["damages"] = damages
			step["damage_total"] = damage_total
			step["damage_text"] = str(damage_total)

		steps.append(step)

	return {
		"steps": steps,
		"final_next_multiplier_percent": preview_next_multiplier
	}

static func build_queue_card_data(card: Node, card_defs: Dictionary) -> Dictionary:
	var card_id = card.get_meta("card_id")
	var def: Dictionary = card_defs.get(card_id, {})
	if def.is_empty():
		return {}

	var card_data: Dictionary = def.duplicate(true)
	card_data["id"] = card_id
	card_data["name"] = def.get("name", card.card_name)
	card_data["type"] = String(def.get("type", card.card_type)).to_lower()
	card_data["value"] = int(def.get("value", card.value))
	card_data["attack"] = def.get("attack", null)
	card_data["block"] = def.get("block", def.get("value", 0) if String(def.get("type", "")).to_lower() == "block" else 0)
	card_data["heal"] = def.get("heal", def.get("value", 0) if String(def.get("type", "")).to_lower() == "heal" else 0)
	return card_data
