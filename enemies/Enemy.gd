extends Node2D

const EnemyList = preload("res://data/EnemyList.gd")
const EnemyActions = preload("res://globals/EnemyActions.gd")

signal defeated

var enemy_id: String = ""
var enemy_name: String = "Enemy"
var max_health: int = 10
var health: int = 10
var bleed: int = 0
var burn: int = 0
var block: int = 0

var dmg: int = 5
var hits: int = 1

var intent_pattern: Array = []
var weighted_actions: Array = []
var side_weighted_actions: Array = []
var intent_index: int = 0
var turn_count: int = 1
var last_action_key: String = ""
var temp_bonus_damage: int = 0
var current_action: Dictionary = {}
var combat_slot: String = "center"

func _ready() -> void:
	bleed = 0
	burn = 0
	block = 0
	health = max_health
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
	weighted_actions = EnemyList.get_weighted_actions(enemy_id)
	side_weighted_actions = EnemyList.get_side_weighted_actions(enemy_id)

	intent_index = 0
	turn_count = 1
	last_action_key = ""
	temp_bonus_damage = 0
	current_action = {}

	bleed = 0
	burn = 0
	block = 0

func set_combat_slot(new_slot: String, replan_intent: bool = false) -> void:
	combat_slot = new_slot
	if replan_intent or current_action.is_empty():
		current_action = EnemyActions.roll_next_action(self)

func get_active_weighted_actions() -> Array:
	if combat_slot == "center":
		return weighted_actions
	return side_weighted_actions

func take_damage(amount: int) -> void:
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
		if not intent_pattern.is_empty():
			intent_index = posmod(intent_index + 1, intent_pattern.size())

	current_action = EnemyActions.roll_next_action(self)
	_refresh_battle_hud()

func apply_bleed(amount: int) -> void:
	bleed += amount
	_log("%s gained %d Bleed (Bleed: %d)" % [enemy_name, amount, bleed])

func apply_burn(amount: int) -> void:
	burn += amount
	_log("%s gained %d Burn (Burn: %d)" % [enemy_name, amount, burn])

func tick_burn() -> void:
	if burn <= 0:
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

func _log_spawn() -> void:
	_log("%s spawned with %d health!" % [enemy_name, max_health])

func _log(message: String) -> void:
	var scene: Node = get_tree().current_scene
	if scene and scene.has_method("log_message"):
		scene.log_message(message)

func _refresh_battle_hud() -> void:
	var scene: Node = get_tree().current_scene
	if scene and scene.has_method("update_hud"):
		scene.update_hud()
