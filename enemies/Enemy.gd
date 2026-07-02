extends Node2D

const EnemyList = preload("res://data/EnemyList.gd")
const EnemyActions = preload("res://globals/EnemyActions.gd")

signal defeated

static var texture_cache: Dictionary = {}

var enemy_id: String = ""
var enemy_name: String = "Enemy"
var max_health: int = 10
var health: int = 10
var bleed: int = 0
var burn: int = 0
var block: int = 0
var prepared_block: int = 0
var combat_damage_bonus: int = 0
var state_flags: Dictionary = {}
var scripted_next_action_key: String = ""

var dmg: int = 5
var hits: int = 1

var intent_pattern: Array = []
var side_intent_pattern: Array = []
var weighted_actions: Array = []
var side_weighted_actions: Array = []
var intent_index: int = 0
var turn_count: int = 1
var last_action_key: String = ""
var temp_bonus_damage: int = 0
var current_action: Dictionary = {}
var combat_slot: String = "center"
var base_body_color: Color = Color(0.443137, 0.65098, 0.631373, 1)
var base_body_modulate: Color = Color(1, 1, 1, 1)

func _ready() -> void:
	bleed = 0
	burn = 0
	block = 0
	prepared_block = 0
	combat_damage_bonus = 0
	health = max_health
	_refresh_visual_state()
	_log_spawn()

func setup_from_enemy_id(new_enemy_id: String) -> void:
	enemy_id = new_enemy_id

	var data: Dictionary = EnemyList.get_enemy_data(enemy_id)
	if data.is_empty():
		push_error("Enemy.gd: Missing enemy data for id %s" % enemy_id)
		return

	enemy_name = String(data.get("display_name", enemy_name))
	max_health = int(data.get("max_health", max_health))
	health = max_health
	intent_pattern = EnemyList.get_pattern(enemy_id)
	side_intent_pattern = EnemyList.get_side_pattern(enemy_id)
	weighted_actions = EnemyList.get_weighted_actions(enemy_id)
	side_weighted_actions = EnemyList.get_side_weighted_actions(enemy_id)
	state_flags = Dictionary(data.get("initial_flags", {})).duplicate(true)
	scripted_next_action_key = ""

	_configure_body_visual(EnemyList.get_ui_color(enemy_id), EnemyList.get_texture_path(enemy_id))

	intent_index = 0
	turn_count = 1
	last_action_key = ""
	temp_bonus_damage = 0
	current_action = {}

	bleed = 0
	burn = 0
	block = 0
	prepared_block = 0
	combat_damage_bonus = 0
	_refresh_visual_state()

func set_combat_slot(new_slot: String, replan_intent: bool = false) -> void:
	combat_slot = new_slot
	if replan_intent or current_action.is_empty():
		current_action = EnemyActions.roll_next_action(self)

func get_active_weighted_actions() -> Array:
	if combat_slot == "center":
		return weighted_actions
	return side_weighted_actions

func get_active_pattern() -> Array:
	if combat_slot == "center":
		return intent_pattern
	return side_intent_pattern if not side_intent_pattern.is_empty() else intent_pattern

func take_damage(amount: int) -> void:
	if not is_targetable():
		return

	var damage_after_block: int = amount

	if block > 0:
		var blocked: int = min(block, damage_after_block)
		block -= blocked
		damage_after_block -= blocked
		if blocked > 0:
			_log("%s blocks %d damage." % [enemy_name, blocked])

	if damage_after_block > 0:
		health = max(health - damage_after_block, 0)
		_log("%s took %d damage. Health: %d" % [enemy_name, damage_after_block, health])

	_refresh_battle_hud()

	if health <= 0:
		defeated.emit()
		die()

func prepare_block(amount: int) -> void:
	if amount <= 0:
		return
	prepared_block += amount
	_refresh_battle_hud()

func gain_block_immediate(amount: int) -> void:
	if amount <= 0:
		return
	block += amount
	_refresh_battle_hud()

func repair(amount: int) -> int:
	if amount <= 0:
		return 0
	var previous_health: int = health
	health = min(health + amount, max_health)
	_refresh_battle_hud()
	return health - previous_health

func activate_prepared_block() -> void:
	block = max(prepared_block, 0)
	prepared_block = 0
	_refresh_battle_hud()

func clear_active_block() -> void:
	if block <= 0:
		return
	if bool(state_flags.get("shell_guard", false)):
		return
	block = 0
	_refresh_battle_hud()

func die() -> void:
	queue_free()

func attack(target) -> void:
	var action: Dictionary = current_action

	if action.is_empty():
		action = EnemyActions.roll_next_action(self)
		current_action = Dictionary(action)

	if action.is_empty():
		_log("%s has no valid planned action." % enemy_name)
		return

	EnemyActions.execute_action(self, target, action)

	last_action_key = EnemyActions.get_action_key(self, action)

	if has_weighted_ai():
		turn_count += 1
	else:
		var active_pattern: Array = get_active_pattern()
		if not active_pattern.is_empty():
			intent_index = posmod(intent_index + 1, active_pattern.size())

	current_action = EnemyActions.roll_next_action(self)
	_refresh_battle_hud()

func apply_bleed(amount: int) -> void:
	if not is_targetable():
		return
	bleed += amount
	_log("%s gained %d Bleed (Bleed: %d)" % [enemy_name, amount, bleed])

func apply_burn(amount: int) -> void:
	if not is_targetable():
		return
	burn += amount
	_log("%s gained %d Burn (Burn: %d)" % [enemy_name, amount, burn])

func tick_burn() -> void:
	if burn <= 0:
		return
	if not is_targetable():
		return

	var damage: int = burn
	burn = max(burn - 1, 0)
	take_damage(damage)

	if health > 0:
		_log("%s's Burn ticks for %d. Burn is now %d." % [enemy_name, damage, burn])

func get_burn() -> int:
	return burn

func get_bleed() -> int:
	return bleed

func get_intent_text() -> String:
	return EnemyActions.get_intent_text_for_action(self, current_action)

func has_weighted_ai() -> bool:
	return not get_active_weighted_actions().is_empty()

func add_combat_damage_bonus(amount: int) -> void:
	if amount == 0:
		return
	combat_damage_bonus += amount
	_refresh_battle_hud()

func get_attack_damage_preview(base_damage: int) -> int:
	return max(base_damage + combat_damage_bonus, 0)

func set_state_flags(flag_values: Dictionary) -> void:
	for key in flag_values.keys():
		state_flags[String(key)] = flag_values[key]
	_refresh_visual_state()
	_refresh_battle_hud()

func clear_state_flags(flag_names: Array) -> void:
	for flag_name in flag_names:
		state_flags.erase(String(flag_name))
	_refresh_visual_state()
	_refresh_battle_hud()

func get_state_flag(flag_name: String, default_value = null):
	return state_flags.get(flag_name, default_value)

func queue_scripted_next_action(action_key: String) -> void:
	scripted_next_action_key = action_key

func is_targetable() -> bool:
	return not bool(state_flags.get("untargetable", false))

func _log_spawn() -> void:
	_log("%s spawned with %d health!" % [enemy_name, max_health])
	if bool(state_flags.get("shell_guard", false)):
		_log("%s is protected by Shell Guard." % enemy_name)

func _log(message: String) -> void:
	var scene: Node = get_tree().current_scene
	if scene and scene.has_method("log_message"):
		scene.log_message(message)

func _refresh_battle_hud() -> void:
	var scene: Node = get_tree().current_scene
	if scene and scene.has_method("update_hud"):
		scene.update_hud()

func _configure_body_visual(body_color: Color, texture_path: String) -> void:
	var body := get_node_or_null("BodyRect") as CanvasItem
	if body == null:
		return

	if body is ColorRect:
		var color_rect := body as ColorRect
		color_rect.color = body_color
		base_body_color = color_rect.color
	elif body is TextureRect and texture_path != "":
		var texture: Resource = texture_cache.get(texture_path)
		if texture == null:
			texture = load(texture_path)
			if texture is Texture2D:
				texture_cache[texture_path] = texture
		if texture is Texture2D:
			(body as TextureRect).texture = texture

	base_body_modulate = body.modulate

func _refresh_visual_state() -> void:
	var submerged: bool = bool(state_flags.get("submerged", false))
	var body := get_node_or_null("BodyRect") as CanvasItem

	if body is ColorRect:
		var color_rect := body as ColorRect
		color_rect.color = base_body_color if not submerged else base_body_color.darkened(0.3)
	elif body:
		body.modulate = base_body_modulate

	if submerged:
		modulate = Color(0.78, 0.88, 1.0, 0.5)
	else:
		modulate = Color(1, 1, 1, 1)
