extends Control

const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var drill_1_button: Button = $Panel/CenterContainer/VBoxContainer/Drill1Button
@onready var drill_2_button: Button = $Panel/CenterContainer/VBoxContainer/Drill2Button
@onready var drill_3_button: Button = $Panel/CenterContainer/VBoxContainer/Drill3Button
@onready var drill_4_button: Button = $Panel/CenterContainer/VBoxContainer/Drill4Button
@onready var drill_5_button: Button = $Panel/CenterContainer/VBoxContainer/Drill5Button
@onready var back_button: Button = $Panel/CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	drill_1_button.pressed.connect(func() -> void: _start_drill(1))
	drill_2_button.pressed.connect(func() -> void: _start_drill(2))
	drill_3_button.pressed.connect(func() -> void: _start_drill(3))
	drill_4_button.pressed.connect(func() -> void: _start_drill(4))
	drill_5_button.pressed.connect(func() -> void: _start_drill(5))
	back_button.pressed.connect(_on_back_pressed)

func _start_drill(drill_number: int) -> void:
	SaveManager.clear_save()
	RunData.start_drill(drill_number)
	RunData.selected_captain = "captain_1"
	PlayerData.apply_captain_starting_deck("captain_1")
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
