extends Node

static func roll_next_action(enemy) -> Dictionary:
	if enemy == null:
		return {}

	if enemy.has_method("has_weighted_ai") and enemy.has_weighted_ai():
		var active_actions: Array = []
		if enemy.has_method("get_active_weighted_actions"):
			active_actions = Array(enemy.get_active_weighted_actions())
		else:
			active_actions = Array(enemy.weighted_actions)

		var weighted_action: Dictionary = _roll_weighted_action(enemy, active_actions)
		if not weighted_action.is_empty():
			return weighted_action

	if not enemy.intent_pattern.is_empty():
		var idx: int = posmod(enemy.intent_index, enemy.intent_pattern.size())
		return Dictionary(enemy.intent_pattern[idx])

	if enemy.dmg > 0:
		return {
			"key": "fallback_attack",
			"type": "attack",
			"damage": enemy.dmg,
			"hits": max(1, enemy.hits)
		}

	return {}

static func get_intent_text(enemy) -> String:
	if enemy == null:
		return "?"
	return get_intent_text_for_action(enemy, enemy.current_action)

static func get_intent_text_for_action(enemy, action: Dictionary) -> String:
	if action.is_empty():
		return "?"

	var override_text: String = String(action.get("intent_text", ""))
	if override_text != "":
		return override_text

	var action_type: String = String(action.get("type", "attack"))

	match action_type:
		"attack", "burn_attack":
			var damage: int = int(action.get("damage", enemy.dmg))
			var hits: int = int(action.get("hits", 1))
			if hits <= 1:
				return "%d ⚔" % damage
			return "%dx%d ⚔" % [damage, hits]

		"defend":
			var block_amount: int = int(action.get("block", 0))
			return "+%d Block" % block_amount

		"buff":
			return String(action.get("label", "Buff"))

		_:
			return "?"

static func execute_turn(enemy, target) -> void:
	if enemy == null:
		return
	enemy.attack(target)

static func execute_action(enemy, target, action: Dictionary) -> void:
	if action.is_empty():
		return

	var action_type: String = String(action.get("type", "attack"))

	match action_type:
		"attack", "burn_attack":
			_execute_attack(enemy, target, action)

		"defend":
			var block_amount: int = int(action.get("block", 0))
			if block_amount > 0:
				enemy.block += block_amount
				enemy._log("%s gains %d Block." % [enemy.enemy_name, block_amount])

		"buff":
			var bonus_damage: int = int(action.get("bonus_damage", 0))
			if bonus_damage > 0:
				enemy.temp_bonus_damage += bonus_damage
				enemy._log("%s powers up (+%d damage next hit)." % [enemy.enemy_name, bonus_damage])

static func _execute_attack(enemy, target, action: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return

	var base_damage: int = int(action.get("damage", enemy.dmg))
	var temp_bonus_damage: int = int(enemy.temp_bonus_damage)
	var damage: int = base_damage + temp_bonus_damage
	var hits: int = max(1, int(action.get("hits", 1)))

	for i in range(hits):
		if target.has_method("take_damage"):
			target.take_damage(damage)

	var custom_log: String = String(action.get("log", ""))
	if custom_log != "":
		if hits <= 1:
			enemy._log(custom_log % [enemy.enemy_name, damage])
		else:
			enemy._log(custom_log % [enemy.enemy_name, hits, damage])
	else:
		if hits <= 1:
			enemy._log("%s attacks for %d damage!" % [enemy.enemy_name, damage])
		else:
			enemy._log("%s attacks %d times for %d damage each!" % [enemy.enemy_name, hits, damage])

	enemy.temp_bonus_damage = 0

static func _roll_weighted_action(enemy, actions: Array) -> Dictionary:
	if actions.is_empty():
		return {}

	var weighted_entries: Array = []
	var total_weight: float = 0.0

	for raw_action in actions:
		var action: Dictionary = Dictionary(raw_action)

		if not _passes_conditions(enemy, action):
			continue

		var action_key: String = get_action_key(enemy, action)

		var weight: float = float(action.get("weight", 1.0))
		if action_key == String(enemy.last_action_key):
			weight = float(action.get("repeat_weight", weight))

		weight = max(weight, 0.0)
		if weight <= 0.0:
			continue

		weighted_entries.append({
			"action": action,
			"weight": weight
		})
		total_weight += weight

	if weighted_entries.is_empty():
		return {}

	var roll: float = randf() * total_weight
	var running_weight: float = 0.0

	for entry in weighted_entries:
		running_weight += float(entry["weight"])
		if roll <= running_weight:
			return Dictionary(entry["action"])

	return Dictionary(weighted_entries[weighted_entries.size() - 1]["action"])

static func _passes_conditions(enemy, action: Dictionary) -> bool:
	if int(action.get("min_turn", 1)) > int(enemy.turn_count):
		return false

	if int(action.get("max_turn", 999999)) < int(enemy.turn_count):
		return false

	var health_percent: float = 0.0
	if int(enemy.max_health) > 0:
		health_percent = float(enemy.health) * 100.0 / float(enemy.max_health)

	if action.has("min_health_percent_lte"):
		if health_percent > float(action.get("min_health_percent_lte", 100.0)):
			return false

	if action.has("max_health_percent_gte"):
		if health_percent < float(action.get("max_health_percent_gte", 0.0)):
			return false

	if action.has("requires_last_action_not"):
		if String(action.get("requires_last_action_not", "")) == String(enemy.last_action_key):
			return false

	return true

static func get_action_key(enemy, action: Dictionary) -> String:
	var key: String = String(action.get("key", ""))
	if key != "":
		return key

	if enemy != null and enemy.intent_pattern is Array:
		for i in range(enemy.intent_pattern.size()):
			if Dictionary(enemy.intent_pattern[i]) == action:
				return "pattern_%d" % i

	return String(action.get("type", "action"))
