extends Control

const EnemyList = preload("res://data/EnemyList.gd")
const EnemyRunConfig = preload("res://data/EnemyRunConfig.gd")
const TurnEffects = preload("res://globals/TurnEffects.gd")
const INTERMISSION_SCENE := "res://scenes/IntermissionScreen.tscn"
const SANDBOX_MENU_SCENE := "res://scenes/SandboxMenu.tscn"
const DEFAULT_SANDBOX_CAPTAIN_ID := "captain_1"

const ROTATE_STEP_DELAY := 0.45

const TUT_WELCOME := 0
const TUT_DRILL_1_PROMPT := 1
const TUT_DRILL_1_PLAY := 2
const TUT_DRILL_1_FIRE := 3
const TUT_DRILL_2_PROMPT := 4
const TUT_DRILL_2_PLAY := 5
const TUT_DRILL_2_FIRE := 6
const TUT_DRILL_3_PROMPT := 7
const TUT_DRILL_3_WRONG_ORDER := 8
const TUT_DRILL_3_WRONG_ORDER_DONE := 9
const TUT_DRILL_3_UNLOAD := 10
const TUT_DRILL_3_CORRECT_ORDER := 11
const TUT_DRILL_3_FIRE := 12
const TUT_DRILL_4_PROMPT := 13
const TUT_DRILL_4_BRACE := 14
const TUT_DRILL_4_SURVIVED := 15
const TUT_DRILL_4_FINISH := 16
const TUT_DRILL_5_PROMPT := 17
const TUT_DRILL_5_PLAY := 18
const TUT_DRILL_5_FIRE := 19
const TUT_PLUNDER_PROMPT := 20
const TUT_DONE := 21

const TUTORIAL_DRILL_1_ENCOUNTER := {
	"wave_name": "Tutorial Drill 1",
	"enemies": {
		"center": "piranha_swarm"
	},
	"health_overrides": {
		"center": 6
	}
}

const TUTORIAL_DRILL_2_ENCOUNTER := {
	"wave_name": "Tutorial Drill 2",
	"enemies": {
		"center": "piranha_swarm"
	},
	"health_overrides": {
		"center": 6
	}
}

const TUTORIAL_DRILL_3_ENCOUNTER := {
	"wave_name": "Tutorial Drill 3",
	"enemies": {
		"center": "piranha_swarm"
	},
	"health_overrides": {
		"center": 8
	}
}

const TUTORIAL_DRILL_4_ENCOUNTER := {
	"wave_name": "Tutorial Drill 4",
	"enemies": {
		"center": "piranha_swarm"
	},
	"health_overrides": {
		"center": 6
	}
}

const TUTORIAL_DRILL_5_ENCOUNTER := {
	"wave_name": "Tutorial Drill 5",
	"enemies": {
		"center": "piranha_swarm",
		"right": "piranha_swarm"
	},
	"health_overrides": {
		"center": 3,
		"right": 3
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
@onready var enemy_vitals = $BattleUI/EnemyVitals
@onready var fire_button = $BattleUI/ButtonsContainer/FireButton
@onready var unload_button = $BattleUI/ButtonsContainer/UnloadButton
@onready var plunder_screen = $PlunderScreen
@onready var enemy_name_label = $BattleUI/EnemyNameLabel
@onready var gold_label = $HUD/PanelContainer/VBoxContainer/GoldLabel
@onready var commands_label = $HUD/PanelContainer/VBoxContainer/CommandsLabel
@onready var module_slots_label = $HUD/PanelContainer/VBoxContainer/ModuleSlotsLabel
@onready var tutorial_overlay = $TutorialOverlay
@onready var tutorial_title = $TutorialOverlay/PanelContainer/VBoxContainer/TitleLabel
@onready var tutorial_body = $TutorialOverlay/PanelContainer/VBoxContainer/BodyLabel
@onready var tutorial_button = $TutorialOverlay/PanelContainer/VBoxContainer/ContinueButton
@onready var ship_preview: Control = $ShipPreview

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			if ship_preview and ship_preview.has_method("toggle_preview"):
				ship_preview.toggle_preview()
				_mark_input_handled()
				return

		if RunData.is_sandbox_mode():
			var preview_visible: bool = ship_preview != null and ship_preview.visible

			if event.keycode == KEY_R and not preview_visible:
				_mark_input_handled()
				_restart_sandbox_fight()
				return

			if event.keycode == KEY_ESCAPE and not preview_visible:
				_mark_input_handled()
				_return_to_sandbox_menu()
				return

var encounter_queue: Array = []
var current_encounter: Dictionary = {}
var current_enemy_id: String = ""
var current_enemy: Node = null
var enemies_by_slot := {
	"left": null,
	"center": null,
	"right": null
}

var enemy_vitals_containers := {}
var enemy_hp_bars := {}
var enemy_hp_text_labels := {}
var enemy_block_panels := {}
var enemy_block_labels := {}
var enemy_intent_labels := {}

var resolving_player_fire: bool = false
var pending_enemy_defeat_flow: bool = false
var formation_animating: bool = false
var waiting_for_tutorial_start: bool = false
var sandbox_result_pending: bool = false

var tutorial_active: bool = false
var tutorial_step: int = TUT_WELCOME
var tutorial_pause_after_fire: bool = false
var tutorial_waiting_for_enemy_turn_result: bool = false
var tutorial_plunder_demo_active: bool = false

func _ready() -> void:
	print("Captain is: ", RunData.selected_captain)
	player_ship.defeated.connect(_on_player_defeated)
	plunder_screen.reward_taken.connect(_on_plunder_finished)
	tutorial_button.pressed.connect(_on_tutorial_continue_pressed)
	_set_sandbox_result_pending(false)

	_setup_enemy_slot_labels()

	var restore_state: Dictionary = {}
	if not RunData.is_sandbox_mode():
		restore_state = SaveManager.consume_requested_save()
	if restore_state.is_empty():
		_start_new_run_state()
	else:
		_restore_run_state(restore_state)

	tutorial_active = false
	tutorial_step = TUT_DONE
	tutorial_pause_after_fire = false
	tutorial_waiting_for_enemy_turn_result = false
	tutorial_plunder_demo_active = false

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
	_activate_enemy_prepared_block()
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
		commands_label.text = "Commands: %d / %d" % [TurnManager.get_current_commands(), TurnManager.get_max_commands()]
		module_slots_label.text = "Modules: %d / %d" % [PlayerData.get_active_modules().size(), player_ship.max_module_slots]

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
		if enemy.has_method("setup_from_enemy_id"):
			enemy.setup_from_enemy_id(enemy_id)

		$BattleWorld/EnemyContainer.add_child(enemy)
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
	var left_pos := Vector2(600, 340)
	var right_pos := Vector2(1000, 340)

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
	if sandbox_result_pending:
		return

	if tutorial_active:
		if tutorial_overlay.visible:
			log_message("Click Continue on the tutorial first.")
			return

		match tutorial_step:
			TUT_DRILL_1_PLAY:
				log_message("Load both Cannon Shots first.")
				return
			TUT_DRILL_1_FIRE:
				if _get_queue_ids() != ["cannon_shot", "cannon_shot"]:
					log_message("Load both Cannon Shots first.")
					return
			TUT_DRILL_2_PLAY:
				log_message("Load two Cannon Shots first.")
				return
			TUT_DRILL_2_FIRE:
				if _get_queue_ids() != ["cannon_shot", "cannon_shot"]:
					log_message("You can only load as many cards as you have cannons.")
					return
			TUT_DRILL_3_WRONG_ORDER, TUT_DRILL_3_UNLOAD, TUT_DRILL_3_CORRECT_ORDER:
				log_message("Finish the order lesson first.")
				return
			TUT_DRILL_3_FIRE:
				if _get_queue_ids() != ["cannon_shot", "loaded_shot"]:
					log_message("Load Cannon Shot first, then Loaded Shot.")
					return
			TUT_DRILL_4_BRACE:
				if _count_card_id_in_queue("brace") > 0:
					log_message("Brace is an Instant card. Play it from your hand.")
				else:
					log_message("Play Brace first.")
				return
			TUT_DRILL_4_SURVIVED:
				if TurnManager.get_queue_size() > 0:
					log_message("Fire with an empty queue to let the fish attack.")
					return
			TUT_DRILL_4_FINISH:
				if _get_queue_ids() != ["cannon_shot", "cannon_shot"]:
					log_message("Load both Cannon Shots first.")
					return
			TUT_DRILL_5_PLAY:
				log_message("Load both Cannon Shots first.")
				return
			TUT_DRILL_5_FIRE:
				if _get_queue_ids() != ["cannon_shot", "cannon_shot"]:
					log_message("Load both Cannon Shots first.")
					return
			_:
				log_message("Not right now.")
				return

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
	if sandbox_result_pending:
		return

	if tutorial_active:
		if tutorial_overlay.visible:
			log_message("Click Continue on the tutorial first.")
			return

		if tutorial_step != TUT_DRILL_3_UNLOAD:
			log_message("Not right now.")
			return

	TurnManager.unload_queue()
	update_hud()

	if tutorial_active and tutorial_step == TUT_DRILL_3_UNLOAD:
		tutorial_step = TUT_DRILL_3_CORRECT_ORDER
		log_message("Now load Cannon Shot first, then Loaded Shot.")

func enemy_turn() -> void:
	_clean_enemy_refs()
	_ensure_center_enemy()
	_layout_enemies()
	_clear_enemy_active_block()

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

	if tutorial_active and tutorial_waiting_for_enemy_turn_result and tutorial_step == TUT_DRILL_4_SURVIVED:
		tutorial_waiting_for_enemy_turn_result = false
		TurnManager.unload_queue()
		_force_tutorial_hand(["cannon_shot", "cannon_shot", "crate", "crate", "crate"])
		tutorial_step = TUT_DRILL_4_FINISH
		_show_tutorial(
			"Good",
			"Brace works right away.\n\nNow load both Cannon Shots and sink the fish."
		)
		update_hud()
		return

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

	if tutorial_active and not _has_any_living_enemies():
		if resolving_player_fire:
			pending_enemy_defeat_flow = true
		else:
			_finish_enemy_defeat_flow()
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

	if RunData.is_sandbox_mode():
		_enter_sandbox_result_state("Sandbox enemy defeated. Press R to restart or ESC to return.")
		return

	if RunData.is_drill_mode():
		end_battle(true)
		return

	if tutorial_active:
		match tutorial_step:
			TUT_DRILL_1_FIRE:
				_prepare_empty_tutorial_screen()
				_force_tutorial_hand(["cannon_shot", "cannon_shot", "cannon_shot", "crate", "crate"])
				tutorial_step = TUT_DRILL_2_PROMPT
				_show_tutorial(
					"Drill 2",
					"You have 3 queue cards in hand, but only 2 cannons.\n\nLoad two Cannon Shots and sink the fish."
				)
				update_hud()
				return
			TUT_DRILL_2_FIRE:
				_prepare_empty_tutorial_screen()
				_force_tutorial_hand(["cannon_shot", "loaded_shot", "crate", "crate", "crate"])
				tutorial_step = TUT_DRILL_3_PROMPT
				_show_tutorial(
					"Drill 3",
					"Order matters.\n\nLoaded Shot deals 3 damage, but if it is last in your queue, it deals 2 more."
				)
				update_hud()
				return
			TUT_DRILL_3_FIRE:
				_prepare_empty_tutorial_screen()
				_force_tutorial_hand(["brace", "brace", "crate", "crate", "crate"])
				tutorial_step = TUT_DRILL_4_PROMPT
				_show_tutorial(
					"Drill 4",
					"This fish attacks for 6.\n\nPlay Brace before it hits."
				)
				update_hud()
				return
			TUT_DRILL_4_FINISH:
				_prepare_empty_tutorial_screen()
				_force_tutorial_hand(["cannon_shot", "cannon_shot", "crate", "crate", "crate"])
				tutorial_step = TUT_DRILL_5_PROMPT
				_show_tutorial(
					"Drill 5",
					"When the center enemy sinks, the formation shifts.\n\nLoad both Cannon Shots and watch the line collapse."
				)
				update_hud()
				return
			TUT_DRILL_5_FIRE:
				_prepare_empty_tutorial_screen()
				tutorial_step = TUT_PLUNDER_PROMPT
				tutorial_plunder_demo_active = true
				_show_tutorial(
					"Plunder",
					"After battles, you choose one reward set.\n\nLet's look at plunder once before the real fight."
				)
				update_hud()
				return

	if encounter_queue.is_empty():
		end_battle(true)
	else:
		hide_battle_ui()
		plunder_screen.show_plunder()

func _on_plunder_finished() -> void:
	if tutorial_plunder_demo_active:
		show_battle_ui()
		TurnManager.reset_for_battle()
		DeckManager.reset()
		tutorial_plunder_demo_active = false
		tutorial_active = false
		tutorial_step = TUT_DONE
		spawn_enemy()
		start_player_turn()
		update_hud()
		_save_pre_battle_state()
		return

	_save_intermission_state()
	get_tree().change_scene_to_file(INTERMISSION_SCENE)

func _on_player_defeated() -> void:
	log_message("Your ship has been destroyed!")
	end_battle(false)

func end_battle(victory: bool) -> void:
	if RunData.is_sandbox_mode():
		var sandbox_message: String = "Sandbox enemy defeated. Press R to restart or ESC to return."
		if not victory:
			sandbox_message = "Sandbox fight ended. Press R to restart or ESC to return."
		_enter_sandbox_result_state(sandbox_message)
		return

	if victory and player_ship and is_instance_valid(player_ship):
		var end_combat_heal: int = PlayerData.get_module_effect_total("end_of_combat_heal")
		if end_combat_heal > 0 and player_ship.health > 0:
			player_ship.repair(end_combat_heal)
			log_message("Modules restore %d HP after combat." % end_combat_heal)

	PlayerData.sync_ship_state(player_ship.health, player_ship.max_health)

	SaveManager.clear_save()

	var result_scene = load("res://scenes/ResultScreen.tscn").instantiate()
	result_scene.is_victory = victory

	get_tree().root.add_child(result_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = result_scene

func _save_intermission_state() -> void:
	SaveManager.save_pre_battle({
		"version": 4,
		"scene": "intermission",
		"player": PlayerData.to_save_dict(),
		"battle": {
			"current_encounter": {},
			"remaining_encounters": encounter_queue.duplicate(true),
			"plunder_index": plunder_screen.plunder_index
		}
	})

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
		var container: Control = enemy_vitals_containers.get(slot)
		var hp_bar: ProgressBar = enemy_hp_bars.get(slot)
		var hp_text: Label = enemy_hp_text_labels.get(slot)
		var block_panel: PanelContainer = enemy_block_panels.get(slot)
		var block_text: Label = enemy_block_labels.get(slot)
		var enemy = enemies_by_slot[slot]

		if container == null or hp_bar == null or hp_text == null or block_panel == null or block_text == null:
			continue

		if enemy and is_instance_valid(enemy):
			hp_bar.max_value = max(enemy.max_health, 1)
			hp_bar.value = clampi(enemy.health, 0, enemy.max_health)
			hp_text.text = "%d / %d" % [enemy.health, enemy.max_health]
			block_text.text = str(enemy.block)
			block_panel.visible = enemy.block > 0
			container.show()
			_position_label_for_enemy(container, enemy, 4.0)
		else:
			hp_text.text = ""
			block_text.text = ""
			block_panel.visible = false
			container.hide()

func update_enemy_intent_label() -> void:
	for slot in ["left", "center", "right"]:
		var label: Label = enemy_intent_labels.get(slot)
		var enemy = enemies_by_slot[slot]

		if label == null:
			continue

		if enemy and is_instance_valid(enemy):
			if tutorial_active and tutorial_step < TUT_DRILL_4_PROMPT:
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
	if label.custom_minimum_size.x > 0.0:
		label_width = label.custom_minimum_size.x
	elif label.size.x > 0.0:
		label_width = label.size.x
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
	_cache_enemy_vitals("center", enemy_vitals)
	enemy_intent_labels["center"] = enemy_intent_label

	var left_vitals: HBoxContainer = enemy_vitals.duplicate()
	left_vitals.name = "EnemyVitalsLeft"
	$BattleUI.add_child(left_vitals)
	_cache_enemy_vitals("left", left_vitals)

	var right_vitals: HBoxContainer = enemy_vitals.duplicate()
	right_vitals.name = "EnemyVitalsRight"
	$BattleUI.add_child(right_vitals)
	_cache_enemy_vitals("right", right_vitals)

	var left_intent: Label = enemy_intent_label.duplicate()
	left_intent.name = "EnemyIntentLabelLeft"
	$BattleUI.add_child(left_intent)
	enemy_intent_labels["left"] = left_intent

	var right_intent: Label = enemy_intent_label.duplicate()
	right_intent.name = "EnemyIntentLabelRight"
	$BattleUI.add_child(right_intent)
	enemy_intent_labels["right"] = right_intent

func _cache_enemy_vitals(slot: String, vitals: HBoxContainer) -> void:
	enemy_vitals_containers[slot] = vitals
	enemy_hp_bars[slot] = vitals.get_node("EnemyHPBar")
	enemy_hp_text_labels[slot] = vitals.get_node("EnemyHPBar/EnemyHPText")
	enemy_block_panels[slot] = vitals.get_node("EnemyBlockPanel")
	enemy_block_labels[slot] = vitals.get_node("EnemyBlockPanel/EnemyBlockLabel")

func _activate_enemy_prepared_block() -> void:
	for slot in ["left", "center", "right"]:
		var enemy = enemies_by_slot[slot]
		if enemy and is_instance_valid(enemy) and enemy.has_method("activate_prepared_block"):
			enemy.activate_prepared_block()

func _clear_enemy_active_block() -> void:
	for slot in ["left", "center", "right"]:
		var enemy = enemies_by_slot[slot]
		if enemy and is_instance_valid(enemy) and enemy.has_method("clear_active_block"):
			enemy.clear_active_block()

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
	encounter_queue.clear()
	plunder_screen.plunder_index = 0
	waiting_for_tutorial_start = false
	_store_current_hand_back_into_deck()
	_set_sandbox_result_pending(false)

	if RunData.is_sandbox_mode():
		_setup_sandbox_battle_sequence()
		return

	if RunData.is_drill_mode():
		_setup_selected_drill()
		return

	tutorial_active = false
	tutorial_step = TUT_DONE
	tutorial_pause_after_fire = false
	tutorial_waiting_for_enemy_turn_result = false
	tutorial_plunder_demo_active = false

	encounter_queue = EnemyRunConfig.get_default_run_order()
	spawn_enemy()
	DeckManager.resolve_fire_phase()

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

func _setup_selected_drill() -> void:
	tutorial_active = true
	tutorial_pause_after_fire = false
	tutorial_waiting_for_enemy_turn_result = false
	tutorial_plunder_demo_active = false
	_prepare_empty_tutorial_screen()

	match int(RunData.selected_drill):
		1:
			_force_tutorial_hand(["cannon_shot", "cannon_shot", "crate", "crate", "crate"])
			spawn_enemy(TUTORIAL_DRILL_1_ENCOUNTER)
			tutorial_step = TUT_DRILL_1_PLAY
			_show_tutorial("Drill 1", "Load both Cannon Shots, then click Fire.")
		2:
			_force_tutorial_hand(["cannon_shot", "cannon_shot", "cannon_shot", "crate", "crate"])
			spawn_enemy(TUTORIAL_DRILL_2_ENCOUNTER)
			tutorial_step = TUT_DRILL_2_PLAY
			_show_tutorial("Drill 2", "You have 3 queue cards, but only 2 cannon slots. Load two Cannon Shots and sink the fish.")
		3:
			_force_tutorial_hand(["cannon_shot", "loaded_shot", "crate", "crate", "crate"])
			spawn_enemy(TUTORIAL_DRILL_3_ENCOUNTER)
			tutorial_step = TUT_DRILL_3_WRONG_ORDER
			_show_tutorial("Drill 3", "Order matters. Try Loaded Shot first, then Cannon Shot.")
		4:
			_force_tutorial_hand(["brace", "brace", "crate", "crate", "crate"])
			spawn_enemy(TUTORIAL_DRILL_4_ENCOUNTER)
			_prepare_current_enemy_intent(6)
			tutorial_step = TUT_DRILL_4_BRACE
			_show_tutorial("Drill 4", "This fish attacks for 6. Play Brace before it hits.")
		5:
			_force_tutorial_hand(["cannon_shot", "cannon_shot", "crate", "crate", "crate"])
			spawn_enemy(TUTORIAL_DRILL_5_ENCOUNTER)
			tutorial_step = TUT_DRILL_5_PLAY
			_show_tutorial("Drill 5", "When the center enemy sinks, the formation shifts. Load both Cannon Shots and watch the line collapse.")
		_:
			_force_tutorial_hand(["cannon_shot", "cannon_shot", "crate", "crate", "crate"])
			spawn_enemy(TUTORIAL_DRILL_1_ENCOUNTER)
			tutorial_step = TUT_DRILL_1_PLAY
			_show_tutorial("Drill 1", "Load both Cannon Shots, then click Fire.")

func _save_pre_battle_state() -> void:
	if RunData.is_drill_mode() or RunData.is_sandbox_mode():
		return

	if current_encounter.is_empty():
		return

	SaveManager.save_pre_battle({
		"version": 3,
		"scene": "battle",
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
			_force_tutorial_hand(["cannon_shot", "cannon_shot", "crate", "crate", "crate"])
			spawn_enemy(TUTORIAL_DRILL_1_ENCOUNTER)
			tutorial_overlay.hide()
			waiting_for_tutorial_start = false
			tutorial_step = TUT_DRILL_1_PLAY
			log_message("Load both Cannon Shots.")

		TUT_DRILL_2_PROMPT:
			spawn_enemy(TUTORIAL_DRILL_2_ENCOUNTER)
			tutorial_overlay.hide()
			tutorial_step = TUT_DRILL_2_PLAY
			log_message("Load two Cannon Shots.")

		TUT_DRILL_3_PROMPT:
			spawn_enemy(TUTORIAL_DRILL_3_ENCOUNTER)
			tutorial_overlay.hide()
			tutorial_step = TUT_DRILL_3_WRONG_ORDER
			log_message("Try Loaded Shot first, then Cannon Shot.")

		TUT_DRILL_3_WRONG_ORDER_DONE:
			tutorial_overlay.hide()
			tutorial_step = TUT_DRILL_3_UNLOAD
			log_message("Now click Unload.")

		TUT_DRILL_4_PROMPT:
			spawn_enemy(TUTORIAL_DRILL_4_ENCOUNTER)
			_prepare_current_enemy_intent(6)
			tutorial_overlay.hide()
			tutorial_step = TUT_DRILL_4_BRACE
			log_message("Play Brace.")

		TUT_DRILL_5_PROMPT:
			spawn_enemy(TUTORIAL_DRILL_5_ENCOUNTER)
			tutorial_overlay.hide()
			tutorial_step = TUT_DRILL_5_PLAY
			log_message("Load both Cannon Shots.")

		TUT_PLUNDER_PROMPT:
			tutorial_overlay.hide()
			hide_battle_ui()
			plunder_screen.show_plunder()

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
		TUT_DRILL_1_PLAY:
			if card_id != "cannon_shot":
				log_message("Only Cannon Shot for this step.")
				return false
			return true

		TUT_DRILL_2_PLAY:
			if card_id != "cannon_shot":
				log_message("Only Cannon Shot for this step.")
				return false
			return true

		TUT_DRILL_3_WRONG_ORDER:
			if _queue_ids_match_prefix(["loaded_shot", "cannon_shot"], card_id):
				return true
			log_message("Try Loaded Shot first, then Cannon Shot.")
			return false

		TUT_DRILL_3_UNLOAD:
			log_message("Unload the queue first.")
			return false

		TUT_DRILL_3_CORRECT_ORDER:
			if _queue_ids_match_prefix(["cannon_shot", "loaded_shot"], card_id):
				return true
			log_message("Now load Cannon Shot first, then Loaded Shot.")
			return false

		TUT_DRILL_4_BRACE:
			if card_id != "brace":
				log_message("Play Brace first.")
				return false
			return true

		TUT_DRILL_4_SURVIVED:
			log_message("Fire with an empty queue to let the fish attack.")
			return false

		TUT_DRILL_4_FINISH:
			if card_id != "cannon_shot":
				log_message("Only Cannon Shot for this step.")
				return false
			return true

		TUT_DRILL_5_PLAY:
			if card_id != "cannon_shot":
				log_message("Only Cannon Shot for this step.")
				return false
			return true

		_:
			log_message("Not yet.")
			return false

func _update_tutorial_progress() -> void:
	if not tutorial_active:
		return
	if tutorial_overlay.visible:
		return

	if tutorial_step == TUT_DRILL_1_PLAY and _get_queue_ids() == ["cannon_shot", "cannon_shot"]:
		tutorial_step = TUT_DRILL_1_FIRE
		_show_tutorial(
			"Ready",
			"Your cannons are loaded.\n\nNow click Fire."
		)
		return

	if tutorial_step == TUT_DRILL_2_PLAY and _get_queue_ids() == ["cannon_shot", "cannon_shot"]:
		tutorial_step = TUT_DRILL_2_FIRE
		_show_tutorial(
			"Queue Limit",
			"You only have 2 cannons, so only 2 queue cards can be loaded.\n\nNow click Fire."
		)
		return

	if tutorial_step == TUT_DRILL_3_WRONG_ORDER and _get_queue_ids() == ["loaded_shot", "cannon_shot"]:
		tutorial_step = TUT_DRILL_3_WRONG_ORDER_DONE
		_show_tutorial(
			"Lower Damage",
			"Loaded Shot only deals 3 here because it is not last.\n\nLet's try the better order."
		)
		return

	if tutorial_step == TUT_DRILL_3_CORRECT_ORDER and _get_queue_ids() == ["cannon_shot", "loaded_shot"]:
		tutorial_step = TUT_DRILL_3_FIRE
		_show_tutorial(
			"Better",
			"Now Loaded Shot is last, so it deals 5 damage.\n\nClick Fire."
		)
		return

	if tutorial_step == TUT_DRILL_4_BRACE and _count_cards_in_hand("brace") == 0:
		tutorial_step = TUT_DRILL_4_SURVIVED
		tutorial_waiting_for_enemy_turn_result = true
		_show_tutorial(
			"Now Wait",
			"Brace works immediately.\n\nClick Fire with an empty queue to let the fish attack."
		)
		return

	if tutorial_step == TUT_DRILL_4_FINISH and _get_queue_ids() == ["cannon_shot", "cannon_shot"]:
		tutorial_overlay.hide()
		log_message("Your cannons are loaded. Now click Fire.")
		return

	if tutorial_step == TUT_DRILL_5_PLAY and _get_queue_ids() == ["cannon_shot", "cannon_shot"]:
		tutorial_step = TUT_DRILL_5_FIRE
		_show_tutorial(
			"Watch The Line",
			"When the center fish sinks, the next one slides forward.\n\nNow click Fire."
		)
		return

func _show_tutorial(title_text: String, body_text: String) -> void:
	tutorial_title.text = title_text
	tutorial_body.text = body_text
	tutorial_overlay.show()

func _prepare_empty_tutorial_screen() -> void:
	TurnManager.unload_queue()
	_clear_current_encounter()
	_clear_hand_only()
	TurnManager.reset_for_battle()
	update_hud()

func _prepare_current_enemy_intent(damage: int) -> void:
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

func should_skip_draw_after_fire() -> bool:
	return tutorial_active

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

func _setup_sandbox_battle_sequence() -> void:
	tutorial_active = false
	tutorial_step = TUT_DONE
	tutorial_pause_after_fire = false
	tutorial_waiting_for_enemy_turn_result = false
	tutorial_plunder_demo_active = false

	var sandbox_encounter: Dictionary = RunData.get_sandbox_encounter()
	if sandbox_encounter.is_empty():
		push_error("BattleScene: sandbox encounter missing.")
		_return_to_sandbox_menu()
		return

	spawn_enemy(sandbox_encounter)
	DeckManager.resolve_fire_phase()

func _restart_sandbox_fight() -> void:
	RunData.selected_captain = DEFAULT_SANDBOX_CAPTAIN_ID
	PlayerData.apply_captain_starting_deck(DEFAULT_SANDBOX_CAPTAIN_ID)
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")

func _return_to_sandbox_menu() -> void:
	get_tree().change_scene_to_file(SANDBOX_MENU_SCENE)

func _enter_sandbox_result_state(message: String) -> void:
	_set_sandbox_result_pending(true)
	tutorial_title.text = "Sandbox Complete"
	tutorial_body.text = message
	tutorial_button.hide()
	tutorial_overlay.show()
	log_message(message)
	update_hud()

func _set_sandbox_result_pending(active: bool) -> void:
	sandbox_result_pending = active
	fire_button.disabled = active
	unload_button.disabled = active
	if not active:
		tutorial_button.show()
		tutorial_overlay.hide()

func _mark_input_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
