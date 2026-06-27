extends Node

static func roll_next_action(enemy) -> Dictionary:
	if enemy == null:
		return {}

	var scripted_next_action_key: String = String(enemy.scripted_next_action_key)
	if scripted_next_action_key != "":
		var scripted_action: Dictionary = _find_action_by_key(enemy, scripted_next_action_key)
		if enemy.has_method("queue_scripted_next_action"):
			enemy.queue_scripted_next_action("")
		else:
			enemy.scripted_next_action_key = ""
		if not scripted_action.is_empty():
			return scripted_action

	if enemy.has_method("has_weighted_ai") and enemy.has_weighted_ai():
		var active_actions: Array = []
		if enemy.has_method("get_active_weighted_actions"):
			active_actions = Array(enemy.get_active_weighted_actions())
		else:
			active_actions = Array(enemy.weighted_actions)

		var weighted_action: Dictionary = _roll_weighted_action(enemy, active_actions)
		if not weighted_action.is_empty():
			return weighted_action

	var active_pattern: Array = []
	if enemy.has_method("get_active_pattern"):
		active_pattern = Array(enemy.get_active_pattern())
	else:
		active_pattern = Array(enemy.intent_pattern)

	if not active_pattern.is_empty():
		var idx: int = posmod(enemy.intent_index, active_pattern.size())
		return Dictionary(active_pattern[idx])

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
			if enemy.has_method("get_attack_damage_preview"):
				damage = int(enemy.get_attack_damage_preview(damage))
			var hits: int = int(action.get("hits", 1))
			var gained_block: int = int(action.get("gain_block_after", 0))
			if hits <= 1:
				if gained_block > 0:
					return "%d ATK +%d Block" % [damage, gained_block]
				return "%d ATK" % damage
			if gained_block > 0:
				return "%dx%d ATK +%d Block" % [hits, damage, gained_block]
			return "%dx%d ATK" % [hits, damage]

		"defend":
			var block_amount: int = int(action.get("block", 0))
			return "Prepare %d Block" % block_amount

		"defend_allies":
			var ally_block_amount: int = int(action.get("block", 0))
			return "Prepare %d Team Block" % ally_block_amount

		"guard":
			var active_block_amount: int = int(action.get("block", 0))
			return "+%d Block" % active_block_amount

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
	_apply_action_state_transitions(enemy, action, "before")

	match action_type:
		"attack", "burn_attack":
			_execute_attack(enemy, target, action)

		"defend":
			var block_amount: int = int(action.get("block", 0))
			if block_amount > 0:
				if enemy.has_method("prepare_block"):
					enemy.prepare_block(block_amount)
				else:
					enemy.block += block_amount
				enemy._log("%s prepares %d Block for the next volley." % [enemy.enemy_name, block_amount])

		"defend_allies":
			var ally_block_amount: int = int(action.get("block", 0))
			if ally_block_amount > 0:
				_apply_block_to_allies(enemy, ally_block_amount, bool(action.get("same_enemy_id_only", false)))

		"guard":
			var active_block_amount: int = int(action.get("block", 0))
			var guard_log: String = String(action.get("log", ""))
			if guard_log != "":
				enemy._log(guard_log % [enemy.enemy_name])
			if active_block_amount > 0:
				_gain_active_block(enemy, active_block_amount)
				enemy._log("%s gains %d Block." % [enemy.enemy_name, active_block_amount])

		"buff":
			var bonus_damage: int = int(action.get("bonus_damage", 0))
			if bonus_damage > 0:
				enemy.temp_bonus_damage += bonus_damage
				enemy._log("%s powers up (+%d damage next hit)." % [enemy.enemy_name, bonus_damage])
			else:
				var custom_log: String = String(action.get("log", ""))
				if custom_log != "":
					enemy._log(custom_log % [enemy.enemy_name])
				else:
					enemy._log("%s uses %s." % [enemy.enemy_name, String(action.get("label", "Buff"))])

	var gained_block_after: int = int(action.get("gain_block_after", 0))
	if gained_block_after > 0:
		_gain_active_block(enemy, gained_block_after)
		enemy._log("%s gains %d Block." % [enemy.enemy_name, gained_block_after])

	var healed_after: int = _heal_enemy_from_action(enemy, action)
	if healed_after > 0:
		enemy._log("%s regains %d HP." % [enemy.enemy_name, healed_after])

	var gained_damage_bonus_after: int = int(action.get("gain_combat_damage_bonus_after", 0))
	if gained_damage_bonus_after != 0:
		if enemy.has_method("add_combat_damage_bonus"):
			enemy.add_combat_damage_bonus(gained_damage_bonus_after)
		else:
			enemy.combat_damage_bonus += gained_damage_bonus_after
		enemy._log("%s gains +%d damage for this combat." % [enemy.enemy_name, gained_damage_bonus_after])

	_apply_action_state_transitions(enemy, action, "after")

static func _execute_attack(enemy, target, action: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return

	var base_damage: int = int(action.get("damage", enemy.dmg))
	var combat_bonus_damage: int = int(enemy.combat_damage_bonus)
	var temp_bonus_damage: int = int(enemy.temp_bonus_damage)
	var damage: int = base_damage + combat_bonus_damage + temp_bonus_damage
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

	if action.has("requires_flags"):
		var required_flags: Dictionary = Dictionary(action.get("requires_flags", {}))
		for flag_name in required_flags.keys():
			var expected_value = required_flags[flag_name]
			var actual_value = null
			if enemy.has_method("get_state_flag"):
				actual_value = enemy.get_state_flag(String(flag_name), null)
			elif enemy.state_flags is Dictionary:
				actual_value = enemy.state_flags.get(String(flag_name), null)
			if actual_value != expected_value:
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

static func _apply_block_to_allies(enemy, block_amount: int, same_enemy_id_only: bool) -> void:
	var scene: Node = enemy.get_tree().current_scene if enemy != null else null
	if scene == null:
		return

	var scene_enemies = scene.get("enemies_by_slot")
	if not (scene_enemies is Dictionary):
		return

	var affected_names: Array[String] = []
	for slot in ["left", "center", "right"]:
		var ally = scene_enemies.get(slot, null)
		if ally == null or not is_instance_valid(ally):
			continue
		if same_enemy_id_only and String(ally.enemy_id) != String(enemy.enemy_id):
			continue
		if ally.has_method("prepare_block"):
			ally.prepare_block(block_amount)
		else:
			ally.block += block_amount
		affected_names.append(String(ally.enemy_name))

	if affected_names.is_empty():
		return

	if affected_names.size() == 1:
		enemy._log("%s prepares %d Block for the next volley." % [affected_names[0], block_amount])
	else:
		enemy._log("%s prepare %d Block each for the next volley." % [", ".join(affected_names), block_amount])

static func _gain_active_block(enemy, block_amount: int) -> void:
	if block_amount <= 0 or enemy == null:
		return
	if enemy.has_method("gain_block_immediate"):
		enemy.gain_block_immediate(block_amount)
	else:
		enemy.block += block_amount

static func _heal_enemy_from_action(enemy, action: Dictionary) -> int:
	if enemy == null:
		return 0

	var heal_amount: int = int(action.get("heal_after", 0))
	if action.has("heal_percent_max_after"):
		heal_amount += int(floor(float(enemy.max_health) * float(action.get("heal_percent_max_after", 0.0)) / 100.0))

	if heal_amount <= 0:
		return 0

	if enemy.has_method("repair"):
		return int(enemy.repair(heal_amount))

	var previous_health: int = int(enemy.health)
	enemy.health = min(int(enemy.health) + heal_amount, int(enemy.max_health))
	return int(enemy.health) - previous_health

static func _find_action_by_key(enemy, action_key: String) -> Dictionary:
	if action_key == "":
		return {}

	var active_actions: Array = []
	if enemy.has_method("get_active_weighted_actions"):
		active_actions = Array(enemy.get_active_weighted_actions())
	else:
		active_actions = Array(enemy.weighted_actions)

	for raw_action in active_actions:
		var action: Dictionary = Dictionary(raw_action)
		if get_action_key(enemy, action) == action_key:
			return action

	var active_pattern: Array = []
	if enemy.has_method("get_active_pattern"):
		active_pattern = Array(enemy.get_active_pattern())
	else:
		active_pattern = Array(enemy.intent_pattern)

	for raw_action in active_pattern:
		var action: Dictionary = Dictionary(raw_action)
		if get_action_key(enemy, action) == action_key:
			return action

	return {}

static func _apply_action_state_transitions(enemy, action: Dictionary, phase: String) -> void:
	var set_key: String = "set_flags_%s" % phase
	var clear_key: String = "clear_flags_%s" % phase
	var queue_key: String = "queue_next_action_key_%s" % phase

	if action.has(set_key):
		var flag_values: Dictionary = Dictionary(action.get(set_key, {}))
		if not flag_values.is_empty():
			if enemy.has_method("set_state_flags"):
				enemy.set_state_flags(flag_values)
			elif enemy.state_flags is Dictionary:
				for flag_name in flag_values.keys():
					enemy.state_flags[String(flag_name)] = flag_values[flag_name]

	if action.has(clear_key):
		var clear_flags: Array = Array(action.get(clear_key, []))
		if not clear_flags.is_empty():
			if enemy.has_method("clear_state_flags"):
				enemy.clear_state_flags(clear_flags)
			elif enemy.state_flags is Dictionary:
				for flag_name in clear_flags:
					enemy.state_flags.erase(String(flag_name))

	if action.has(queue_key):
		var next_action_key: String = String(action.get(queue_key, ""))
		if enemy.has_method("queue_scripted_next_action"):
			enemy.queue_scripted_next_action(next_action_key)
		else:
			enemy.scripted_next_action_key = next_action_key
