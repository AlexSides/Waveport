extends Control

signal reward_taken

const CardListData = preload("res://data/CardList.gd")
const ModuleList = preload("res://data/ModuleList.gd")
const RunConfig = preload("res://data/RunConfig.gd")

const MODE_MAIN := "main"
const MODE_REWARD_CHOICE := "reward_choice"
const MODE_REPLACE_CARGO := "replace_cargo"

var plunder_index: int = 0
var current_mode: String = MODE_MAIN
var current_plunder: Dictionary = {}
var pending_replace_choice_index: int = -1
var main_status_message: String = ""
var overlay_status_message: String = ""

@onready var main_panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var gold_label: Label = $Panel/VBoxContainer/GoldLabel
@onready var hull_label: Label = $Panel/VBoxContainer/HullLabel
@onready var gold_button: Button = $Panel/VBoxContainer/TreasureButton
@onready var reward_button: Button = $Panel/VBoxContainer/SalvageButton
@onready var hidden_extra_button: Button = $Panel/VBoxContainer/CargoButton
@onready var continue_button: Button = $ContinueButton
@onready var back_button: Button = $BackButton

@onready var reward_overlay: Control = $RewardOverlay
@onready var overlay_title_label: Label = $RewardOverlay/Panel/VBoxContainer/TitleLabel
@onready var overlay_status_label: Label = $RewardOverlay/Panel/VBoxContainer/StatusLabel
@onready var choice_row: HBoxContainer = $RewardOverlay/Panel/VBoxContainer/ChoiceRow
@onready var left_choice_button: Button = $RewardOverlay/Panel/VBoxContainer/ChoiceRow/LeftChoiceButton
@onready var right_choice_button: Button = $RewardOverlay/Panel/VBoxContainer/ChoiceRow/RightChoiceButton
@onready var replacement_options: VBoxContainer = $RewardOverlay/Panel/VBoxContainer/ReplacementOptions

func _ready() -> void:
	visible = false
	reward_overlay.visible = false
	back_button.visible = false

	gold_button.pressed.connect(_on_gold_pressed)
	reward_button.pressed.connect(_on_reward_pressed)
	left_choice_button.pressed.connect(_on_choice_pressed.bind(0))
	right_choice_button.pressed.connect(_on_choice_pressed.bind(1))
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)

	hidden_extra_button.visible = false
	_refresh_view()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if current_mode == MODE_REPLACE_CARGO:
			_return_to_reward_choice()
			get_viewport().set_input_as_handled()
		elif current_mode == MODE_REWARD_CHOICE:
			_return_to_main_screen()
			get_viewport().set_input_as_handled()

func show_plunder() -> void:
	current_plunder = {
		"gold_amount": RunConfig.get_plunder_gold_reward(plunder_index),
		"gold_claimed": false,
		"reward_claimed": false,
		"choices": RunConfig.generate_plunder_reward_choices()
	}
	current_mode = MODE_MAIN
	pending_replace_choice_index = -1
	main_status_message = ""
	overlay_status_message = ""
	visible = true
	_refresh_view()

func _refresh_view() -> void:
	_refresh_main_panel()
	_refresh_overlay()
	continue_button.visible = current_mode == MODE_MAIN
	back_button.visible = current_mode != MODE_MAIN

func _refresh_main_panel() -> void:
	title_label.text = "Plunder"
	gold_label.visible = false
	hull_label.visible = false
	hidden_extra_button.visible = false

	var gold_claimed: bool = bool(current_plunder.get("gold_claimed", false))
	var reward_claimed: bool = bool(current_plunder.get("reward_claimed", false))

	gold_button.visible = not gold_claimed
	gold_button.text = "Gold  +%d" % int(current_plunder.get("gold_amount", 0))
	gold_button.disabled = gold_claimed

	reward_button.visible = not reward_claimed
	reward_button.text = "Reward"
	reward_button.disabled = reward_claimed

	if main_status_message != "":
		status_label.text = main_status_message
	else:
		status_label.text = "Claim gold, open Reward, or continue sailing."

	main_panel.modulate = Color(1, 1, 1, 0) if current_mode != MODE_MAIN else Color(1, 1, 1, 1)

func _refresh_overlay() -> void:
	reward_overlay.visible = current_mode != MODE_MAIN
	if not reward_overlay.visible:
		return

	match current_mode:
		MODE_REWARD_CHOICE:
			_refresh_reward_choice_view()
		MODE_REPLACE_CARGO:
			_refresh_replace_cargo_view()

func _refresh_reward_choice_view() -> void:
	choice_row.visible = true
	replacement_options.visible = false
	overlay_title_label.text = "Choose Reward"
	overlay_status_label.text = overlay_status_message if overlay_status_message != "" else "Choose one reward."

	left_choice_button.disabled = false
	right_choice_button.disabled = false
	left_choice_button.text = _get_choice_button_text(_get_choice(0))
	right_choice_button.text = _get_choice_button_text(_get_choice(1))

func _refresh_replace_cargo_view() -> void:
	choice_row.visible = false
	replacement_options.visible = true

	var choice: Dictionary = _get_pending_replace_choice()
	var module_id: String = String(choice.get("module_id", ""))
	var module_name: String = _get_module_display_name(module_id)
	overlay_title_label.text = "Cargo Full"
	overlay_status_label.text = "Choose a cargo module to replace with %s. Esc or Back to return." % module_name

	for child in replacement_options.get_children():
		child.queue_free()

	var cargo_modules: Array[String] = PlayerData.get_cargo_modules()
	for i in range(cargo_modules.size()):
		replacement_options.add_child(_create_replace_button(i, String(cargo_modules[i]), module_name))

func _create_replace_button(index: int, current_module_id: String, new_module_name: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	button.text = "Replace Cargo %d: %s  ->  %s" % [
		index + 1,
		_get_module_display_name(current_module_id),
		new_module_name
	]
	button.pressed.connect(_on_replace_cargo_pressed.bind(index))
	return button

func _on_gold_pressed() -> void:
	if current_mode != MODE_MAIN or bool(current_plunder.get("gold_claimed", false)):
		return

	var gold_amount: int = int(current_plunder.get("gold_amount", 0))
	PlayerData.add_gold(gold_amount)
	current_plunder["gold_claimed"] = true
	main_status_message = "Claimed %d gold." % gold_amount
	_refresh_view()

func _on_reward_pressed() -> void:
	if current_mode != MODE_MAIN or bool(current_plunder.get("reward_claimed", false)):
		return

	current_mode = MODE_REWARD_CHOICE
	overlay_status_message = ""
	_refresh_view()

func _on_choice_pressed(choice_index: int) -> void:
	if current_mode != MODE_REWARD_CHOICE:
		return

	var choice: Dictionary = _get_choice(choice_index)
	match String(choice.get("kind", "")):
		"card_pack":
			_claim_card_pack(choice)
		"module":
			_claim_module_choice(choice_index, choice)

func _claim_card_pack(choice: Dictionary) -> void:
	var cards: Array = Array(choice.get("cards", []))
	PlayerData.add_cards_to_deck(cards)
	PlayerData.queue_bonus_cards_for_next_battle(cards)
	current_plunder["reward_claimed"] = true
	current_mode = MODE_MAIN
	pending_replace_choice_index = -1
	main_status_message = "Claimed the %s pack and gained all 3 cards." % String(choice.get("pack_name", "Card"))
	overlay_status_message = ""
	_refresh_view()

func _claim_module_choice(choice_index: int, choice: Dictionary) -> void:
	var module_id: String = String(choice.get("module_id", ""))
	if PlayerData.add_module_to_cargo(module_id):
		current_plunder["reward_claimed"] = true
		current_mode = MODE_MAIN
		pending_replace_choice_index = -1
		main_status_message = "Claimed %s to cargo." % _get_module_display_name(module_id)
		overlay_status_message = ""
		_refresh_view()
		return

	pending_replace_choice_index = choice_index
	current_mode = MODE_REPLACE_CARGO
	_refresh_view()

func _on_replace_cargo_pressed(cargo_index: int) -> void:
	var choice: Dictionary = _get_pending_replace_choice()
	if choice.is_empty():
		_return_to_reward_choice()
		return

	var module_id: String = String(choice.get("module_id", ""))
	if not PlayerData.replace_cargo_module(cargo_index, module_id):
		overlay_status_message = "Could not replace that cargo module."
		_return_to_reward_choice()
		return

	current_plunder["reward_claimed"] = true
	current_mode = MODE_MAIN
	main_status_message = "Replaced cargo %d with %s." % [
		cargo_index + 1,
		_get_module_display_name(module_id)
	]
	overlay_status_message = ""
	pending_replace_choice_index = -1
	_refresh_view()

func _on_back_pressed() -> void:
	if current_mode == MODE_REPLACE_CARGO:
		_return_to_reward_choice()
	elif current_mode == MODE_REWARD_CHOICE:
		_return_to_main_screen()

func _return_to_reward_choice() -> void:
	current_mode = MODE_REWARD_CHOICE
	pending_replace_choice_index = -1
	overlay_status_message = "Reward not claimed."
	_refresh_view()

func _return_to_main_screen() -> void:
	current_mode = MODE_MAIN
	pending_replace_choice_index = -1
	overlay_status_message = ""
	main_status_message = "Reward skipped."
	_refresh_view()

func _get_choice(choice_index: int) -> Dictionary:
	var choices: Array = Array(current_plunder.get("choices", []))
	if choice_index < 0 or choice_index >= choices.size():
		return {}
	return Dictionary(choices[choice_index])

func _get_pending_replace_choice() -> Dictionary:
	return _get_choice(pending_replace_choice_index)

func _get_choice_button_text(choice: Dictionary) -> String:
	match String(choice.get("kind", "")):
		"card_pack":
			var cards: Array = Array(choice.get("cards", []))
			var card_names: Array[String] = []
			for card_id_variant in cards:
				card_names.append(_get_card_display_name(String(card_id_variant)))
			return "%s Card Pack\nGain all 3: %s" % [
				String(choice.get("pack_name", "Card")),
				", ".join(card_names)
			]
		"module":
			return "Module\nGain %s to cargo" % _get_module_display_name(String(choice.get("module_id", "")))
		_:
			return "Reward"

func _get_card_display_name(card_id: String) -> String:
	var defs = CardListData.new().CARD_LIBRARY
	if defs.has(card_id):
		return str(defs[card_id].get("name", card_id))
	return card_id

func _get_module_display_name(module_id: String) -> String:
	if module_id == "":
		return "Module"
	var module_data: Dictionary = ModuleList.get_module(module_id)
	return String(module_data.get("name", module_id))

func _finish_plunder() -> void:
	plunder_index += 1
	visible = false
	reward_taken.emit()

func _on_continue_pressed() -> void:
	if current_mode != MODE_MAIN:
		return
	_finish_plunder()
