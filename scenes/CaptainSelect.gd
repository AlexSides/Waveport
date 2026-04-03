extends Control

const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

var selected_captain: String = ""

@onready var continue_button: Button = $ContinueButton
@onready var back_button: Button = $BackButton

@onready var select_button_1: Button = $HBoxContainer/CaptainPanel1/SelectButton1
@onready var select_button_2: Button = $HBoxContainer/CaptainPanel2/SelectButton2
@onready var select_button_3: Button = $HBoxContainer/CaptainPanel3/SelectButton3

func _ready() -> void:
	continue_button.disabled = true

	_disconnect_captain_signals()
	_connect_captain_signals()
	_setup_available_captains()

func _setup_available_captains() -> void:
	select_button_2.disabled = true
	select_button_2.text = "Coming Soon"

	select_button_3.disabled = true
	select_button_3.text = "Coming Soon"

func _disconnect_captain_signals() -> void:
	if select_button_1.pressed.is_connected(_on_select_captain_1):
		select_button_1.pressed.disconnect(_on_select_captain_1)
	if select_button_2.pressed.is_connected(_on_select_captain_2):
		select_button_2.pressed.disconnect(_on_select_captain_2)
	if select_button_3.pressed.is_connected(_on_select_captain_3):
		select_button_3.pressed.disconnect(_on_select_captain_3)

	if continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.disconnect(_on_continue_pressed)
	if back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)

func _connect_captain_signals() -> void:
	select_button_1.pressed.connect(_on_select_captain_1)
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _on_select_captain_1() -> void:
	_select_captain("captain_1")

func _on_select_captain_2() -> void:
	_select_captain("captain_2")

func _on_select_captain_3() -> void:
	_select_captain("captain_3")

func _select_captain(captain_id: String) -> void:
	selected_captain = captain_id
	continue_button.disabled = false

func _on_continue_pressed() -> void:
	RunData.selected_captain = selected_captain
	PlayerData.apply_captain_starting_deck(selected_captain)
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
