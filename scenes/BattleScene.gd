extends Control

const EnemyList = preload("res://data/EnemyList.gd")
const EnemyRunConfig = preload("res://data/EnemyRunConfig.gd")
const TurnEffects = preload("res://globals/TurnEffects.gd")

const ROTATE_STEP_DELAY := 0.45

const TUT_WELCOME := 0
const TUT_DRAW_HAND := 1
const TUT_QUEUE_INFO := 2
const TUT_FIRST_FISH_PROMPT := 3
const TUT_FIRST_COMBAT := 4
const TUT_FIRST_FIRE_PROMPT := 5
const TUT_FIRST_FIRE_ACTION := 6
const TUT_SECOND_FISH_PROMPT := 7
const TUT_SECOND_WRONG_ORDER := 8
const TUT_SECOND_WRONG_ORDER_PROMPT := 9
const TUT_SECOND_UNLOAD := 10
const TUT_SECOND_RELOAD_CORRECT := 11
const TUT_SECOND_FIRE_PROMPT := 12
const TUT_SECOND_FIRE_ACTION := 13
const TUT_THIRD_FISH_PROMPT := 14
const TUT_THIRD_COMBAT := 15
const TUT_DONE := 16

const TUTORIAL_CHAIN_ENCOUNTER := {
	"wave_name": "Tutorial Chain",
	"enemies": {
		"left": "piranha_swarm",
		"center": "piranha_swarm",
		"right": "piranha_swarm"
	},
	"health_overrides": {
		"center": 6,
		"right": 5,
		"left": 11
	}
}

@onready var card_hand = $BattleUI/CardHand
@onready var discard_label = $BattleUI/DiscardPile/DiscardLabel
@onready var deck_label = $BattleUI/DeckPile/DeckLabel
@onready var player_ship = $BattleWorld/ShipContainer/PlayerShip
@onready var hp_label = $HUD/PanelContainer/VBoxContainer/ShipHPLabel
@onready var block_label = $HUD/PanelContainer/VBoxContainer/BlockLabel
@onready var queue_label = $HUD/PanelContainer/VBoxContainer/QueueLabel
@onready var enemy_intent_label = $BattleUI/EnemyIntentLabel
@onready var fire_button = $BattleUI/ButtonsContainer/FireButton
@onready var unload_button = $BattleUI/ButtonsContainer/UnloadButton
@onready var plunder_screen = $PlunderScreen
@onready var enemy_hp_label = $BattleUI/EnemyHPLabel
@onready var enemy_name_label = $BattleUI/EnemyNameLabel
@onready var gold_label = $HUD/PanelContainer/VBoxContainer/GoldLabel
@onready var module_slots_label = $HUD/PanelContainer/VBoxContainer/ModuleSlotsLabel
@onready var tutorial_overlay = $TutorialOverlay
@onready var tutorial_title = $TutorialOverlay/PanelContainer/VBoxContainer/TitleLabel
@onready var tutorial_body = $TutorialOverlay/PanelContainer/VBoxContainer/BodyLabel
@onready var tutorial_button = $TutorialOverlay/PanelContainer/VBoxContainer/ContinueButton

var encounter_queue: Array = []
var current_encounter: Dictionary = {}
var current_enemy_id: String = ""
var current_enemy: Node = null
var enemies_by_slot := {
	"left": null,
	"center": null,
	"right": null
}

var enemy_hp_labels := {}
var enemy_intent_labels := {}

var resolving_player_fire: bool = false
var pending_enemy_defeat_flow: bool = false
var formation_animating: bool = false
var waiting_for_tutorial_start: bool = false

var tutorial_active: bool = true
var tutorial_step: int = TUT_WELCOME
var tutorial_pause_after_fire: bool = false
var skip_draw_after_fire_once: bool = false
var tutorial_third_tip_shown: bool = false

func _ready() -> void:
	print("Captain is: ", RunData.selected_captain)
	player_ship.defeated.connect(_on_player_defeated)
	plunder_screen.reward_taken.connect(_on_plunder_finished)
	tutorial_button.pressed.connect(_on_tutorial_continue_pressed)

	_setup_enemy_slot_labels()

	var restore_state: Dictionary = SaveManager.consume_requested_save()
	if restore_state.is_empty():
		_start_new_run_state()
	else:
		_restore_run_state(restore_state)
		tutorial_active = false
		tutorial_step = TUT_DONE

	GameManager.begin_battle(self)

	show_battle_ui()
	plunder_screen.hide()
	tutorial_overlay.hide()
	TurnManager.reset_for_battle()

	if restore_state.is_empty():
		_setup_new_battle_sequence()
	else:
		_setup_restored_battle_sequence(restore_state)

	start_player_turn()
	update_hud()
	_save_pre_battle_state()
	log_message("BattleScene ready!")

func _process(_delta: float) -> void:
	update_enemy_name_label()

func show_battle_ui() -> void:
	$BattleUI.show()
	$BattleWorld.show()
	$DebugCanvas.show()
	$HUD.show()

func hide_battle_ui() -> void:
	$BattleUI.hide()
	$BattleWorld.hide()
	$DebugCanvas.hide()
	$HUD.hide()

func get_player_ship():
	return player_ship

func get_current_enemy() -> Node:
	_clean_enemy_refs()
	_ensure_center_enemy()

	var center_enemy = enemies_by_slot["center"]
	if center_enemy and is_instance_valid(center_enemy):
		return center_enemy
	return null

func start_player_turn() -> void:
	TurnManager.start_player_turn()
	update_hud()

func update_hud() -> void:
	_clean_enemy_refs()
	_ensure_center_enemy()
	_layout_enemies()

	current_enemy = get_current_enemy()
	current_enemy_id = ""
	if current_enemy:
		current_enemy_id = String(current_enemy.enemy_id)

	if player_ship:
		hp_label.text = "HP: %d / %d" % [player_ship.health, player_ship.max_health]
		block_label.text = "Block: %d" % player_ship.block
		gold_label.text = "Gold: %d" % PlayerData.gold
		module_slots_label.text = "Modules: %d / %d" % [PlayerData.modules.size(), player_ship.max_module_slots]

	var queue_texts: Array[String] = []
	var preview_steps: Array = TurnManager.get_queue_preview(get_current_enemy())

	for step in preview_steps:
		var card_data: Dictionary = step["card"]
		var card_type: String = String(card_data.get("type", "")).to_lower()

		if card_type == "attack":
			var name: String = str(card_data.get("name", "Card"))
			var shown_damage: int = int(step.get("damage_total", 0))
			queue_texts.append("%s (%d dmg)" % [name, shown_damage])

	if queue_texts.is_empty():
		queue_label.text = "Queued Attacks: none"
	else:
		queue_label.text = "Queued Attacks:\n" + "\n".join(queue_texts)

	update_enemy_hp_label()
	update_enemy_intent_label()
	_update_tutorial_progress()

func spawn_enemy(encounter_override: Dictionary = {}) -> void:
	_clear_current_encounter()

	var encounter: Dictionary = encounter_override
	if encounter.is_empty():
		if encounter_queue.is_empty():
			end_battle(true)
			return
		encounter = Dictionary(encounter_queue.pop_front())

	current_encounter = encounter.duplicate(true)

	var enemy_slots: Dictionary = Dictionary(current_encounter.get("enemies", {}))
	var health_overrides: Dictionary = Dictionary(current_encounter.get("health_overrides", {}))

	for slot in ["left", "center", "right"]:
		if not enemy_slots.has(slot):
			continue

		var enemy_id: String = String(enemy_slots.get(slot, ""))
		if enemy_id == "":
			continue

		var scene_path: String = EnemyList.get_scene_path(enemy_id)
		if scene_path.is_empty():
			push_error("BattleScene: Missing scene path for enemy id %s" % enemy_id)
			continue

		var enemy_scene: PackedScene = load(scene_path)
		if enemy_scene == null:
			push_error("BattleScene: failed to load enemy scene %s" % scene_path)
			continue

		var enemy: Node = enemy_scene.instantiate()
		$BattleWorld/EnemyContainer.add_child(enemy)

		if enemy.has_method("setup_from_enemy_id"):
			enemy.setup_from_enemy_id(enemy_id)
		if enemy.has_method("set_combat_slot"):
			enemy.set_combat_slot(slot, true)

		if health_overrides.has(slot):
			var override_hp: int = int(health_overrides.get(slot, enemy.health))
			enemy.max_health = override_hp
			enemy.health = override_hp

		enemy.defeated.connect(_on_enemy_defeated.bind(enemy), CONNECT_ONE_SHOT)
		enemies_by_slot[slot] = enemy

	_clean_enemy_refs()
	_ensure_center_enemy()
	_layout_enemies()

	TurnManager.pending_next_cannon_multiplier_percent = 100
	TurnManager.cannon_bonus_this_turn = 0

	current_enemy = get_current_enemy()
	current_enemy_id = ""
	if current_enemy:
		current_enemy_id = String(current_enemy.enemy_id)

	update_hud()

func _clear_current_encounter() -> void:
	for slot in ["left", "center", "right"]:
		var enemy = enemies_by_slot[slot]
		if enemy and is_instance_valid(enemy):
			enemy.queue_free()
		enemies_by_slot[slot] = null

	current_enemy = null
	current_enemy_id = ""
	current_encounter.clear()

func _layout_enemies() -> void:
	_clean_enemy_refs()

	var center_pos := Vector2(800, 400)
	var left_pos := Vector2(660, 340)
	var right_pos := Vector2(940, 340)

	for slot in ["left", "center", "right"]:
		var enemy = enemies_by_slot[slot]
		if enemy == null or not is_instance_valid(enemy):
			continue

		match slot:
			"left":
				enemy.position = left_pos
				enemy.scale = Vector2(0.8, 0.8)
			"center":
				enemy.position = center_pos
				enemy.scale = Vector2(1.0, 1.0)
			"right":
				enemy.position = right_pos
				enemy.scale = Vector2(0.8, 0.8)

func _on_fire_button_pressed() -> void:
	if formation_animating or waiting_for_tutorial_start:
		return

	if tutorial_active:
		if tutorial_overlay.visible:
			log_message("Click Continue on the tutorial first.")
			return

		match tutorial_step:
			TUT_FIRST_COMBAT:
				log_message("Load both Cannon Shots first.")
				return
			TUT_FIRST_FIRE_PROMPT:
				log_message("Click Continue first.")
				return
			TUT_FIRST_FIRE_ACTION:
				if _get_queue_ids() != ["cannon_shot", "cannon_shot"]:
					log_message("Load both Cannon Shots first.")
					return
			TUT_SECOND_FISH_PROMPT:
				log_message("Click Continue first.")
				return
			TUT_SECOND_WRONG_ORDER:
				log_message("Load Cannon Shot first, then Chain Shot.")
				return
			TUT_SECOND_WRONG_ORDER_PROMPT:
				log_message("Click Continue first.")
				return
			TUT_SECOND_UNLOAD:
				log_message("Unload first.")
				return
			TUT_SECOND_RELOAD_CORRECT:
				log_message("Load Chain Shot first, then Cannon Shot.")
				return
			TUT_SECOND_FIRE_PROMPT:
				log_message("Click Continue first.")
				return
			TUT_SECOND_FIRE_ACTION:
				if _get_queue_ids() != ["chain_shot", "cannon_shot"]:
					log_message("Load Chain Shot first, then Cannon Shot.")
					return
			TUT_THIRD_FISH_PROMPT:
				log_message("Click Continue first.")
				return

	if tutorial_active and (
		tutorial_step == TUT_FIRST_FIRE_ACTION
		or tutorial_step == TUT_SECOND_FIRE_ACTION
	):
		skip_draw_after_fire_once = true

	_clean_enemy_refs()
	_ensure_center_enemy()
	_layout_enemies()

	log_message("Fire button clicked!")
	resolving_player_fire = true
	pending_enemy_defeat_flow = false

	await TurnManager.on_fire_button_pressed()

	resolving_player_fire = false

	_clean_enemy_refs()
	_ensure_center_enemy()
	_layout_enemies()

	if tutorial_pause_after_fire:
		tutorial_pause_after_fire = false
		update_hud()
		return

	if pending_enemy_defeat_flow:
		_finish_enemy_defeat_flow()
		update_hud()
		return

	if get_current_enemy() == null:
		if _has_any_living_enemies():
			update_hud()
			return
		_finish_enemy_defeat_flow()
		update_hud()
		return

	enemy_turn()
	update_hud()

func _on_unload_button_pressed() -> void:
	if formation_animating or waiting_for_tutorial_start:
		return

	if tutorial_active:
		if tutorial_overlay.visible:
			log_message("Click Continue on the tutorial first.")
			return

		if tutorial_step != TUT_SECOND_UNLOAD:
			log_message("Not right now.")
			return

	TurnManager.unload_queue()
	update_hud()

	if tutorial_active and tutorial_step == TUT_SECOND_UNLOAD:
		tutorial_step = TUT_SECOND_RELOAD_CORRECT
		log_message("Now load Chain Shot first, then Cannon Shot.")

func enemy_turn() -> void:
	_clean_enemy_refs()
	_ensure_center_enemy()
	_layout_enemies()

	for slot in ["left", "center", "right"]:
		var enemy = enemies_by_slot[slot]
		if enemy and is_instance_valid(enemy) and enemy.has_method("tick_burn"):
			enemy.tick_burn()

	_clean_enemy_refs()
	_ensure_center_enemy()
	_layout_enemies()

	for slot in ["left", "center", "right"]:
		var enemy = enemies_by_slot[slot]
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.health <= 0:
			continue

		enemy.attack(player_ship)

		if player_ship == null or player_ship.health <= 0:
			update_hud()
			return

		_clean_enemy_refs()
		_ensure_center_enemy()
		_layout_enemies()

	if player_ship:
		player_ship.clear_block()

	if tutorial_active and tutorial_step == TUT_THIRD_COMBAT and not tutorial_third_tip_shown:
		tutorial_third_tip_shown = true
		_prepare_third_fish_intent(12)
		_show_tutorial(
			"Finish It",
			"If you can kill the fish before it attacks, you can avoid the damage."
		)

	start_player_turn()
	update_hud()

func _on_enemy_defeated(defeated_enemy: Node) -> void:
	var slot := _get_slot_for_enemy(defeated_enemy)

	if defeated_enemy and is_instance_valid(defeated_enemy):
		log_message("%s defeated!" % defeated_enemy.enemy_name)
		defeated_enemy.hide()

	if slot != "":
		enemies_by_slot[slot] = null

	if slot == "center":
		await _animate_rotate_right()
	else:
		_clean_enemy_refs()
		_layout_enemies()

	current_enemy = get_current_enemy()
	current_enemy_id = ""
	if current_enemy:
		current_enemy_id = String(current_enemy.enemy_id)

	if tutorial_active:
		if tutorial_step == TUT_FIRST_FIRE_ACTION:
			tutorial_step = TUT_SECOND_FISH_PROMPT
			tutorial_pause_after_fire = true
			_show_tutorial(
				"Order Matters",
				"You still have two cards left.\n\nTry loading Cannon Shot first, then Chain Shot."
			)
			update_hud()
			return

		if tutorial_step == TUT_SECOND_FIRE_ACTION:
			_setup_third_fish_tutorial_draw()
			_prepare_third_fish_intent(6)
			tutorial_step = TUT_THIRD_FISH_PROMPT
			tutorial_pause_after_fire = true
			_show_tutorial(
				"Out of Cards",
				"Nice.\n\nWe're out of cards, so let's draw back up to 4.\n\nThis fish attacks for 6.\n\nBrace is an Instant card, so it works right away."
			)
			update_hud()
			return

	if _has_any_living_enemies():
		update_hud()
		return

	if resolving_player_fire:
		pending_enemy_defeat_flow = true
		update_hud()
		return

	_finish_enemy_defeat_flow()

func wait_for_enemy_hit_resolution() -> void:
	await get_tree().process_frame

	while formation_animating:
		await get_tree().process_frame

	_clean_enemy_refs()
	_ensure_center_enemy()
	_layout_enemies()
	update_hud()

func _animate_rotate_right() -> void:
	formation_animating = true

	_clean_enemy_refs()

	var left_enemy = enemies_by_slot["left"]
	var right_enemy = enemies_by_slot["right"]

	current_enemy = null
	current_enemy_id = ""
	enemies_by_slot["center"] = null

	_layout_enemies()
	_update_enemy_slot_labels_only()

	await get_tree().create_timer(ROTATE_STEP_DELAY).timeout

	if right_enemy and is_instance_valid(right_enemy):
		enemies_by_slot["center"] = right_enemy
		enemies_by_slot["right"] = null
		if enemies_by_slot["center"].has_method("set_combat_slot"):
			enemies_by_slot["center"].set_combat_slot("center", false)

		_layout_enemies()
		_update_enemy_slot_labels_only()

		await get_tree().create_timer(ROTATE_STEP_DELAY).timeout

	if left_enemy and is_instance_valid(left_enemy):
		enemies_by_slot["right"] = left_enemy
		enemies_by_slot["left"] = null
		if enemies_by_slot["right"].has_method("set_combat_slot"):
			enemies_by_slot["right"].set_combat_slot("right", false)

	_layout_enemies()

	formation_animating = false

func _ensure_center_enemy() -> void:
	if formation_animating:
		return

	_clean_enemy_refs()

	var center_enemy = enemies_by_slot["center"]
	if center_enemy and is_instance_valid(center_enemy):
		return

	var left_enemy = enemies_by_slot["left"]
	var right_enemy = enemies_by_slot["right"]

	if right_enemy and is_instance_valid(right_enemy):
		enemies_by_slot["center"] = right_enemy
		enemies_by_slot["left"] = null
		enemies_by_slot["right"] = left_enemy if (left_enemy and is_instance_valid(left_enemy)) else null

		if enemies_by_slot["center"] and enemies_by_slot["center"].has_method("set_combat_slot"):
			enemies_by_slot["center"].set_combat_slot("center", false)
		if enemies_by_slot["right"] and enemies_by_slot["right"].has_method("set_combat_slot"):
			enemies_by_slot["right"].set_combat_slot("right", false)
		return

	if left_enemy and is_instance_valid(left_enemy):
		enemies_by_slot["center"] = left_enemy
		enemies_by_slot["left"] = null
		enemies_by_slot["right"] = null

		if enemies_by_slot["center"] and enemies_by_slot["center"].has_method("set_combat_slot"):
			enemies_by_slot["center"].set_combat_slot("center", false)
		return

	enemies_by_slot["center"] = null
	enemies_by_slot["left"] = null
	enemies_by_slot["right"] = null

func _has_any_living_enemies() -> bool:
	_clean_enemy_refs()
	for slot in ["left", "center", "right"]:
		var enemy = enemies_by_slot[slot]
		if enemy and is_instance_valid(enemy):
			return true
	return false

func _clean_enemy_refs() -> void:
	for slot in ["left", "center", "right"]:
		var enemy = enemies_by_slot[slot]
		if enemy != null and not is_instance_valid(enemy):
			enemies_by_slot[slot] = null

	if current_enemy != null and not is_instance_valid(current_enemy):
		current_enemy = null

func _finish_enemy_defeat_flow() -> void:
	pending_enemy_defeat_flow = false

	if tutorial_active and tutorial_step == TUT_THIRD_COMBAT:
		tutorial_active = false
		tutorial_step = TUT_DONE

	if encounter_queue.is_empty():
		end_battle(true)
	else:
		hide_battle_ui()
		plunder_screen.show_plunder()

func _on_plunder_finished() -> void:
	show_battle_ui()
	TurnManager.reset_for_battle()
	DeckManager.reset()
	spawn_enemy()
	start_player_turn()
	update_hud()
	_save_pre_battle_state()

func _on_player_defeated() -> void:
	log_message("Your ship has been destroyed!")
	end_battle(false)

func end_battle(victory: bool) -> void:
	PlayerData.sync_ship_state(player_ship.health, player_ship.max_health)
	SaveManager.clear_save()

	var result_scene = load("res://scenes/ResultScreen.tscn").instantiate()
	result_scene.is_victory = victory

	get_tree().root.add_child(result_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = result_scene

func log_message(msg: String) -> void:
	var label = Label.new()
	label.text = msg
	$DebugCanvas/DebugLogPanel/ScrollContainer/LogVBox.add_child(label)

	await get_tree().process_frame
	$DebugCanvas/DebugLogPanel/ScrollContainer.scroll_vertical = (
		$DebugCanvas/DebugLogPanel/ScrollContainer.get_v_scroll_bar().max_value
	)

func is_mouse_over_enemy_body() -> bool:
	current_enemy = get_current_enemy()
	if not current_enemy:
		return false

	if not current_enemy.has_node("BodyRect"):
		return false

	var body = current_enemy.get_node("BodyRect")
	return Rect2(body.global_position, body.size).has_point(get_global_mouse_position())

func update_enemy_name_label() -> void:
	current_enemy = get_current_enemy()

	if current_enemy and is_instance_valid(current_enemy) and is_mouse_over_enemy_body():
		enemy_name_label.text = current_enemy.enemy_name
		enemy_name_label.show()
		_position_label_for_enemy(enemy_name_label, current_enemy, 40.0)
	else:
		enemy_name_label.text = ""
		enemy_name_label.hide()

func update_enemy_hp_label() -> void:
	for slot in ["left", "center", "right"]:
		var label: Label = enemy_hp_labels.get(slot)
		var enemy = enemies_by_slot[slot]

		if label == null:
			continue

		if enemy and is_instance_valid(enemy):
			label.text = "%d / %d" % [enemy.health, enemy.max_health]
			label.show()
			_position_label_for_enemy(label, enemy, 4.0)
		else:
			label.text = ""
			label.hide()

func update_enemy_intent_label() -> void:
	for slot in ["left", "center", "right"]:
		var label: Label = enemy_intent_labels.get(slot)
		var enemy = enemies_by_slot[slot]

		if label == null:
			continue

		if enemy and is_instance_valid(enemy):
			if tutorial_active and tutorial_step < TUT_THIRD_FISH_PROMPT:
				label.text = ""
				label.hide()
				continue

			if enemy.has_method("get_intent_text"):
				label.text = enemy.get_intent_text()
			elif enemy.has_method("get_intent_display"):
				label.text = enemy.get_intent_display()
			elif enemy.has_method("get_intent"):
				label.text = str(enemy.get_intent())
			elif enemy.has("current_action") and enemy.current_action is Dictionary:
				label.text = String(enemy.current_action.get("intent_text", "?"))
			else:
				label.text = "?"
			label.show()
			_position_label_for_enemy(label, enemy, -50.0)
		else:
			label.text = ""
			label.hide()

func _position_label_for_enemy(label: Control, enemy: Node, y_offset: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return

	var label_width := 200.0
	label.size.x = label_width

	var center_x: float = enemy.global_position.x
	var anchor_y: float = enemy.global_position.y

	if enemy.has_node("BodyRect"):
		var body = enemy.get_node("BodyRect")
		center_x = body.global_position.x + body.size.x / 2.0
		anchor_y = body.global_position.y
		if y_offset >= 0.0:
			anchor_y = body.global_position.y + body.size.y

	label.position = Vector2(center_x - label_width / 2.0, anchor_y + y_offset)

func _setup_enemy_slot_labels() -> void:
	enemy_hp_labels["center"] = enemy_hp_label
	enemy_intent_labels["center"] = enemy_intent_label

	var left_hp: Label = enemy_hp_label.duplicate()
	left_hp.name = "EnemyHPLabelLeft"
	$BattleUI.add_child(left_hp)
	enemy_hp_labels["left"] = left_hp

	var right_hp: Label = enemy_hp_label.duplicate()
	right_hp.name = "EnemyHPLabelRight"
	$BattleUI.add_child(right_hp)
	enemy_hp_labels["right"] = right_hp

	var left_intent: Label = enemy_intent_label.duplicate()
	left_intent.name = "EnemyIntentLabelLeft"
	$BattleUI.add_child(left_intent)
	enemy_intent_labels["left"] = left_intent

	var right_intent: Label = enemy_intent_label.duplicate()
	right_intent.name = "EnemyIntentLabelRight"
	$BattleUI.add_child(right_intent)
	enemy_intent_labels["right"] = right_intent

func _update_enemy_slot_labels_only() -> void:
	update_enemy_hp_label()
	update_enemy_intent_label()
	update_enemy_name_label()

func _get_slot_for_enemy(enemy: Node) -> String:
	for slot in ["left", "center", "right"]:
		if enemies_by_slot[slot] == enemy:
			return slot
	return ""

func _start_new_run_state() -> void:
	PlayerData.ensure_run_state()
	_apply_player_state_to_ship()

func _restore_run_state(save_state: Dictionary) -> void:
	PlayerData.load_from_save_dict(Dictionary(save_state.get("player", {})))
	_apply_player_state_to_ship()

func _apply_player_state_to_ship() -> void:
	player_ship.max_health = PlayerData.max_hull
	player_ship.health = clampi(PlayerData.current_hull, 1, player_ship.max_health)
	player_ship.block = 0
	player_ship.bleed = 0
	PlayerData.sync_ship_state(player_ship.health, player_ship.max_health)

func _setup_new_battle_sequence() -> void:
	encounter_queue = EnemyRunConfig.get_default_run_order()
	plunder_screen.plunder_index = 0
	waiting_for_tutorial_start = true
	_store_current_hand_back_into_deck()
	_show_tutorial(
		"Welcome",
		"Welcome aboard.\n\nLet's learn the basics before we set sail."
	)

func _setup_restored_battle_sequence(save_state: Dictionary) -> void:
	var battle_state: Dictionary = Dictionary(save_state.get("battle", {}))
	var saved_encounter: Dictionary = Dictionary(battle_state.get("current_encounter", {}))

	encounter_queue.clear()
	for encounter in battle_state.get("remaining_encounters", []):
		encounter_queue.append(Dictionary(encounter))

	plunder_screen.plunder_index = int(battle_state.get("plunder_index", 0))

	if saved_encounter.is_empty():
		spawn_enemy()
	else:
		spawn_enemy(saved_encounter)

func _save_pre_battle_state() -> void:
	if current_encounter.is_empty():
		return

	SaveManager.save_pre_battle({
		"version": 3,
		"player": PlayerData.to_save_dict(),
		"battle": {
			"current_encounter": current_encounter.duplicate(true),
			"remaining_encounters": encounter_queue.duplicate(true),
			"plunder_index": plunder_screen.plunder_index
		}
	})

func _on_tutorial_continue_pressed() -> void:
	match tutorial_step:
		TUT_WELCOME:
			tutorial_step = TUT_DRAW_HAND
			_show_tutorial(
				"First Step",
				"First, let's draw a hand.\n\nYour hand size matches your crew size."
			)

		TUT_DRAW_HAND:
			_force_tutorial_hand(["cannon_shot", "cannon_shot", "cannon_shot", "chain_shot"])
			tutorial_step = TUT_QUEUE_INFO
			_show_tutorial(
				"Cards",
				"Queue cards load into your cannons.\n\nWe'll keep this simple for now."
			)

		TUT_QUEUE_INFO:
			spawn_enemy(TUTORIAL_CHAIN_ENCOUNTER)
			tutorial_step = TUT_FIRST_FISH_PROMPT
			_show_tutorial(
				"Enemy Ahead",
				"Load two Cannon Shots and sink the first fish."
			)

		TUT_FIRST_FISH_PROMPT:
			tutorial_overlay.hide()
			waiting_for_tutorial_start = false
			tutorial_step = TUT_FIRST_COMBAT
			log_message("Load both Cannon Shots.")

		TUT_FIRST_FIRE_PROMPT:
			tutorial_overlay.hide()
			tutorial_step = TUT_FIRST_FIRE_ACTION
			log_message("Now click Fire.")

		TUT_SECOND_FISH_PROMPT:
			tutorial_overlay.hide()
			tutorial_step = TUT_SECOND_WRONG_ORDER
			log_message("Load Cannon Shot first, then Chain Shot.")

		TUT_SECOND_WRONG_ORDER_PROMPT:
			tutorial_overlay.hide()
			tutorial_step = TUT_SECOND_UNLOAD
			log_message("Now click Unload.")

		TUT_SECOND_FIRE_PROMPT:
			tutorial_overlay.hide()
			tutorial_step = TUT_SECOND_FIRE_ACTION
			log_message("Now click Fire.")

		TUT_THIRD_FISH_PROMPT:
			DeckManager.draw_cards(4 - DeckManager.hand.size())
			tutorial_overlay.hide()
			tutorial_step = TUT_THIRD_COMBAT
			log_message("The fish attacks for 6. Use Brace to survive this turn.")

		_:
			tutorial_overlay.hide()

	update_hud()

func can_play_card_for_tutorial(card: Node) -> bool:
	if not tutorial_active:
		return true

	if tutorial_overlay.visible:
		log_message("Click Continue on the tutorial first.")
		return false

	var card_id: String = String(card.get_meta("card_id", ""))

	match tutorial_step:
		TUT_FIRST_COMBAT:
			if card_id != "cannon_shot":
				log_message("Only Cannon Shot for this step.")
				return false
			return true

		TUT_FIRST_FIRE_ACTION:
			log_message("Click Fire.")
			return false

		TUT_SECOND_WRONG_ORDER:
			if _queue_ids_match_prefix(["cannon_shot", "chain_shot"], card_id):
				return true
			log_message("Load Cannon Shot first, then Chain Shot.")
			return false

		TUT_SECOND_UNLOAD:
			log_message("Unload the cannons first.")
			return false

		TUT_SECOND_RELOAD_CORRECT:
			if _queue_ids_match_prefix(["chain_shot", "cannon_shot"], card_id):
				return true
			log_message("Now reverse it: Chain Shot first, then Cannon Shot.")
			return false

		TUT_SECOND_FIRE_ACTION:
			log_message("Click Fire.")
			return false

		TUT_THIRD_COMBAT:
			return true

		_:
			log_message("Not yet.")
			return false

func _update_tutorial_progress() -> void:
	if not tutorial_active:
		return
	if tutorial_overlay.visible:
		return

	if tutorial_step == TUT_FIRST_COMBAT and _get_queue_ids() == ["cannon_shot", "cannon_shot"]:
		tutorial_step = TUT_FIRST_FIRE_PROMPT
		_show_tutorial(
			"Ready",
			"Your cannons are loaded.\n\nNow click Fire."
		)
		return

	if tutorial_step == TUT_SECOND_WRONG_ORDER and _get_queue_ids() == ["cannon_shot", "chain_shot"]:
		tutorial_step = TUT_SECOND_WRONG_ORDER_PROMPT
		_show_tutorial(
			"Lower Damage",
			"This order only shows 4 dmg.\n\nUnload the cannons, then put Chain Shot first to make it 5 dmg."
		)
		return

	if tutorial_step == TUT_SECOND_RELOAD_CORRECT and _get_queue_ids() == ["chain_shot", "cannon_shot"]:
		tutorial_step = TUT_SECOND_FIRE_PROMPT
		_show_tutorial(
			"Better",
			"Now it shows 5 dmg instead of 4 dmg.\n\nClick Fire."
		)
		return

func _show_tutorial(title_text: String, body_text: String) -> void:
	tutorial_title.text = title_text
	tutorial_body.text = body_text
	tutorial_overlay.show()

func _store_current_hand_back_into_deck() -> void:
	var hand_ids: Array[String] = []

	for card in DeckManager.hand:
		if card != null and is_instance_valid(card):
			hand_ids.append(String(card.get_meta("card_id", "")))
			card.queue_free()

	DeckManager.hand.clear()

	while not hand_ids.is_empty():
		var card_id: String = hand_ids.pop_back()
		DeckManager.deck.push_front(card_id)

	UIManager.update_deck_ui(DeckManager.deck.size(), DeckManager.discard_pile.size())

func _clear_hand_only() -> void:
	for card in DeckManager.hand:
		if card != null and is_instance_valid(card):
			card.queue_free()
	DeckManager.hand.clear()
	UIManager.update_deck_ui(DeckManager.deck.size(), DeckManager.discard_pile.size())

func _force_tutorial_hand(card_ids: Array[String]) -> void:
	_clear_hand_only()
	for card_id in card_ids:
		TurnEffects.add_card_to_hand(card_id)
	UIManager.update_deck_ui(DeckManager.deck.size(), DeckManager.discard_pile.size())

func _setup_third_fish_tutorial_draw() -> void:
	_clear_hand_only()
	DeckManager.deck.clear()
	DeckManager.discard_pile.clear()

	DeckManager.deck = [
		"brace",
		"brace"
	]

	DeckManager.discard_pile = [
		"cannon_shot",
		"cannon_shot",
		"cannon_shot",
		"chain_shot"
	]

	UIManager.update_deck_ui(DeckManager.deck.size(), DeckManager.discard_pile.size())

func _prepare_third_fish_intent(damage: int) -> void:
	var enemy = get_current_enemy()
	if enemy == null or not is_instance_valid(enemy):
		return

	enemy.current_action = {
		"key": "tutorial_attack_%d" % damage,
		"type": "attack",
		"damage": damage,
		"hits": 1,
		"intent_text": "%d ⚔" % damage
	}

func should_skip_draw_after_fire() -> bool:
	if skip_draw_after_fire_once:
		skip_draw_after_fire_once = false
		return true
	return false

func _get_queue_ids() -> Array[String]:
	var ids: Array[String] = []
	for card_data in TurnManager.action_queue:
		ids.append(String(card_data.get("id", "")))
	return ids

func _queue_ids_match_prefix(expected_order: Array[String], next_card_id: String) -> bool:
	var current_ids: Array[String] = _get_queue_ids()

	if current_ids.size() >= expected_order.size():
		return false

	for i in range(current_ids.size()):
		if current_ids[i] != expected_order[i]:
			return false

	return expected_order[current_ids.size()] == next_card_id

func _count_card_id_in_queue(card_id: String) -> int:
	var total: int = 0
	for queued_id in _get_queue_ids():
		if queued_id == card_id:
			total += 1
	return total

func _count_cards_in_hand(card_id: String) -> int:
	var total: int = 0
	for card in DeckManager.hand:
		if card != null and is_instance_valid(card):
			if String(card.get_meta("card_id", "")) == card_id:
				total += 1
	return total
