extends Node2D
signal defeated

@export var ship_name := "Player Ship"
@export var max_health := 50
@export var max_module_slots := 3

var health: int = 0
var block: int = 0
var bleed: int = 0

func _ready() -> void:
	PlayerData.ensure_run_state()
	max_health = PlayerData.max_hull
	max_module_slots = PlayerData.get_active_module_slot_capacity()
	block = 0
	bleed = 0
	health = clampi(PlayerData.current_hull, 1, max_health)
	PlayerData.sync_ship_state(health, max_health)

func take_damage(amount: int) -> void:
	var dmg: int = maxi(amount - block, 0)
	block = maxi(block - amount, 0)
	health = maxi(health - dmg, 0)
	PlayerData.sync_ship_state(health, max_health)
	if get_tree().current_scene.has_method("log_message"):
		get_tree().current_scene.log_message("%s took %d damage (HP: %d, Block: %d)" % [ship_name, dmg, health, block])
	if health <= 0:
		defeated.emit()
	if get_tree().current_scene.has_method("update_hud"):
		get_tree().current_scene.update_hud()

func clear_block() -> void:
	block = 0
	if get_tree().current_scene.has_method("update_hud"):
		get_tree().current_scene.update_hud()

func lose_hp(amount: int) -> void:
	health = maxi(health - amount, 0)
	PlayerData.sync_ship_state(health, max_health)
	if get_tree().current_scene.has_method("log_message"):
		get_tree().current_scene.log_message("%s lost %d HP (HP: %d, Block: %d)" % [ship_name, amount, health, block])
	if health <= 0:
		defeated.emit()
	if get_tree().current_scene.has_method("update_hud"):
		get_tree().current_scene.update_hud()

func add_block(amount: int) -> void:
	block += amount
	if get_tree().current_scene.has_method("log_message"):
		get_tree().current_scene.log_message("%s gained %d Block (Block: %d)" % [ship_name, amount, block])
	if get_tree().current_scene.has_method("update_hud"):
		get_tree().current_scene.update_hud()

func repair(amount: int) -> void:
	health = mini(health + amount, max_health)
	PlayerData.sync_ship_state(health, max_health)
	if get_tree().current_scene.has_method("log_message"):
		get_tree().current_scene.log_message("%s repaired %d (HP: %d)" % [ship_name, amount, health])
	if get_tree().current_scene.has_method("update_hud"):
		get_tree().current_scene.update_hud()

func apply_bleed(amount: int) -> void:
	bleed += amount
	lose_hp(amount)
	if get_tree().current_scene.has_method("log_message"):
		get_tree().current_scene.log_message("%s gained %d Bleed (Bleed: %d)" % [ship_name, amount, bleed])

func get_bleed() -> int:
	return bleed
