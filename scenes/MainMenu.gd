extends Control

const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const CAPTAIN_SELECT_SCENE := "res://scenes/CaptainSelect.tscn"

@onready var play_button: Button = $Panel/CenterContainer/VBoxContainer/PlayButton
@onready var continue_button: Button = $Panel/CenterContainer/VBoxContainer/ContinueButton
@onready var abandon_button: Button = $Panel/CenterContainer/VBoxContainer/AbandonButton
@onready var options_button: Button = $Panel/CenterContainer/VBoxContainer/OptionButton
@onready var quit_button: Button = $Panel/CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	options_button.disabled = true

	_disconnect_menu_signals()
	_connect_menu_signals()
	_refresh_menu()

func _disconnect_menu_signals() -> void:
	if play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.disconnect(_on_play_pressed)
	if play_button.pressed.is_connected(_on_continue_pressed):
		play_button.pressed.disconnect(_on_continue_pressed)
	if play_button.pressed.is_connected(_on_abandon_pressed):
		play_button.pressed.disconnect(_on_abandon_pressed)
	if play_button.pressed.is_connected(_on_quit_pressed):
		play_button.pressed.disconnect(_on_quit_pressed)

	if continue_button.pressed.is_connected(_on_play_pressed):
		continue_button.pressed.disconnect(_on_play_pressed)
	if continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.disconnect(_on_continue_pressed)
	if continue_button.pressed.is_connected(_on_abandon_pressed):
		continue_button.pressed.disconnect(_on_abandon_pressed)
	if continue_button.pressed.is_connected(_on_quit_pressed):
		continue_button.pressed.disconnect(_on_quit_pressed)

	if abandon_button.pressed.is_connected(_on_play_pressed):
		abandon_button.pressed.disconnect(_on_play_pressed)
	if abandon_button.pressed.is_connected(_on_continue_pressed):
		abandon_button.pressed.disconnect(_on_continue_pressed)
	if abandon_button.pressed.is_connected(_on_abandon_pressed):
		abandon_button.pressed.disconnect(_on_abandon_pressed)
	if abandon_button.pressed.is_connected(_on_quit_pressed):
		abandon_button.pressed.disconnect(_on_quit_pressed)

	if quit_button.pressed.is_connected(_on_play_pressed):
		quit_button.pressed.disconnect(_on_play_pressed)
	if quit_button.pressed.is_connected(_on_continue_pressed):
		quit_button.pressed.disconnect(_on_continue_pressed)
	if quit_button.pressed.is_connected(_on_abandon_pressed):
		quit_button.pressed.disconnect(_on_abandon_pressed)
	if quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.disconnect(_on_quit_pressed)

func _connect_menu_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	abandon_button.pressed.connect(_on_abandon_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _refresh_menu() -> void:
	var has_save: bool = SaveManager.has_save()
	play_button.visible = not has_save
	continue_button.visible = has_save
	abandon_button.visible = has_save

func _on_play_pressed() -> void:
	PlayerData.reset_run()
	get_tree().change_scene_to_file(CAPTAIN_SELECT_SCENE)

func _on_continue_pressed() -> void:
	SaveManager.request_continue()
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _on_abandon_pressed() -> void:
	SaveManager.clear_save()
	PlayerData.reset_run()
	_refresh_menu()

func _on_quit_pressed() -> void:
	get_tree().quit()
