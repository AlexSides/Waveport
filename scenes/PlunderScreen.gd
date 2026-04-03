extends Control

signal reward_taken

const CardListData = preload("res://data/CardList.gd")
const RunConfig = preload("res://data/RunConfig.gd")

var selected_reward: String = ""
var plunder_index: int = 0
var showing_reward_result: bool = false
var current_cargo_sets: Array[String] = []

var set_selection_container: VBoxContainer
var sets_row: HBoxContainer

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var gold_label: Label = $Panel/VBoxContainer/GoldLabel
@onready var hull_label: Label = $Panel/VBoxContainer/HullLabel
@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton
@onready var treasure_button: Button = $Panel/VBoxContainer/TreasureButton
@onready var salvage_button: Button = $Panel/VBoxContainer/SalvageButton
@onready var cargo_button: Button = $Panel/VBoxContainer/CargoButton
@onready var main_vbox: VBoxContainer = $Panel/VBoxContainer

func _ready() -> void:
	visible = false
	continue_button.disabled = true

	treasure_button.pressed.connect(_on_treasure_pressed)
	salvage_button.pressed.connect(_on_salvage_pressed)
	cargo_button.pressed.connect(_on_cargo_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

	_build_set_selection_ui()
	_refresh_labels()
	_refresh_button_text()

func _build_set_selection_ui() -> void:
	set_selection_container = VBoxContainer.new()
	set_selection_container.visible = false
	set_selection_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_selection_container.add_theme_constant_override("separation", 12)

	var sets_title := Label.new()
	sets_title.text = "Choose a Set"
	sets_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sets_title.add_theme_font_size_override("font_size", 26)
	set_selection_container.add_child(sets_title)

	sets_row = HBoxContainer.new()
	sets_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sets_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sets_row.add_theme_constant_override("separation", 16)
	set_selection_container.add_child(sets_row)

	main_vbox.remove_child(continue_button)
	main_vbox.add_child(set_selection_container)
	main_vbox.add_child(continue_button)

func show_plunder() -> void:
	selected_reward = ""
	showing_reward_result = false
	current_cargo_sets.clear()
	visible = true
	title_label.text = "Plunder"
	status_label.text = "Choose one plunder reward."
	continue_button.text = "Continue"
	continue_button.disabled = true
	set_selection_container.visible = false
	_set_reward_choice_visible(true)
	_refresh_labels()
	_refresh_button_text()

func _refresh_labels() -> void:
	gold_label.text = "Gold: %d" % PlayerData.gold
	hull_label.text = "Hull: %d / %d" % [PlayerData.current_health, PlayerData.current_max_health]

func _refresh_button_text() -> void:
	treasure_button.text = "Plunder Treasure"
	salvage_button.text = "Salvage Scrap"
	cargo_button.text = "Steal Cargo"

	if selected_reward == "treasure":
		treasure_button.text += "  [Selected]"
	elif selected_reward == "salvage":
		salvage_button.text += "  [Selected]"
	elif selected_reward == "cargo":
		cargo_button.text += "  [Selected]"

func _set_reward_choice_visible(is_visible: bool) -> void:
	treasure_button.visible = is_visible
	salvage_button.visible = is_visible
	cargo_button.visible = is_visible

func _on_treasure_pressed() -> void:
	selected_reward = "treasure"
	status_label.text = "Selected: Treasure."
	continue_button.disabled = false
	set_selection_container.visible = false
	_refresh_button_text()

func _on_salvage_pressed() -> void:
	selected_reward = "salvage"
	status_label.text = "Selected: Scrap."
	continue_button.disabled = false
	set_selection_container.visible = false
	_refresh_button_text()

func _on_cargo_pressed() -> void:
	selected_reward = "cargo"
	status_label.text = "Choose a cargo set."
	continue_button.disabled = true
	_refresh_button_text()
	_show_cargo_sets()

func _get_treasure_reward() -> int:
	if plunder_index == 0:
		return 50
	elif plunder_index == 1:
		return 100
	return 100

func _get_salvage_reward() -> int:
	if plunder_index == 0:
		return 8
	elif plunder_index == 1:
		return 12
	return 12

func _get_player_ship_in_battle() -> Node:
	var scene := get_tree().current_scene
	if scene and scene.has_method("get_player_ship"):
		return scene.get_player_ship()
	return null

func _apply_hull_repair(amount: int) -> void:
	var player_ship := _get_player_ship_in_battle()

	if player_ship and is_instance_valid(player_ship) and player_ship.has_method("repair"):
		player_ship.repair(amount)
	else:
		PlayerData.repair_ship(amount)

func _resolve_selected_reward() -> String:
	if selected_reward == "treasure":
		var gold_amount := _get_treasure_reward()
		PlayerData.add_gold(gold_amount)
		return "You plundered %d gold." % gold_amount

	elif selected_reward == "salvage":
		var hull_amount := _get_salvage_reward()
		_apply_hull_repair(hull_amount)
		return "You restored %d hull." % hull_amount

	return "No reward selected."

func _show_cargo_sets() -> void:
	current_cargo_sets = RunConfig.get_random_cargo_set_ids()
	_set_reward_choice_visible(false)
	set_selection_container.visible = true

	for child in sets_row.get_children():
		child.queue_free()

	for i in range(current_cargo_sets.size()):
		var set_id := current_cargo_sets[i]
		sets_row.add_child(_create_set_panel(set_id, i))

func _create_set_panel(set_id: String, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 220)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = RunConfig.get_cargo_set_name(set_id)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	for card_id_variant in RunConfig.get_cargo_set_cards(set_id):
		var card_label := Label.new()
		card_label.text = _get_card_display_name(String(card_id_variant))
		card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_label.add_theme_font_size_override("font_size", 18)
		vbox.add_child(card_label)

	var choose_button := Button.new()
	choose_button.text = "Take Set"
	choose_button.pressed.connect(_on_cargo_set_chosen.bind(index))
	vbox.add_child(choose_button)

	return panel

func _on_cargo_set_chosen(index: int) -> void:
	if index < 0 or index >= current_cargo_sets.size():
		return

	var set_id := current_cargo_sets[index]
	var cards := RunConfig.get_cargo_set_cards(set_id)

	PlayerData.add_cards_to_deck(cards)
	PlayerData.queue_bonus_cards_for_next_battle(cards)

	_show_reward_result("You stole the %s set." % RunConfig.get_cargo_set_name(set_id))

func _get_card_display_name(card_id: String) -> String:
	var defs = CardListData.new().CARD_LIBRARY
	if defs.has(card_id):
		return str(defs[card_id].get("name", card_id))
	return card_id

func _show_reward_result(message: String) -> void:
	showing_reward_result = true
	title_label.text = "Haul Secured"
	status_label.text = message
	continue_button.text = "Continue"
	continue_button.disabled = false
	_set_reward_choice_visible(false)
	set_selection_container.visible = false
	_refresh_labels()

func _finish_plunder() -> void:
	plunder_index += 1
	visible = false
	reward_taken.emit()

func _on_continue_pressed() -> void:
	if showing_reward_result:
		_finish_plunder()
		return

	if selected_reward == "":
		return

	var result_message := _resolve_selected_reward()
	_show_reward_result(result_message)
