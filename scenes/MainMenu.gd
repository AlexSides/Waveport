extends Control

const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const CAPTAIN_SELECT_SCENE := "res://scenes/CaptainSelect.tscn"
const DRILLS_MENU_SCENE := "res://scenes/DrillsMenu.tscn"
const INTERMISSION_SCENE := "res://scenes/IntermissionScreen.tscn"
const SANDBOX_SCENE := "res://scenes/SandboxMenu.tscn"

@onready var play_button: Button = $Panel/CenterContainer/VBoxContainer/PlayButton
@onready var continue_button: Button = $Panel/CenterContainer/VBoxContainer/ContinueButton
@onready var abandon_button: Button = $Panel/CenterContainer/VBoxContainer/AbandonButton
@onready var drills_button: Button = $Panel/CenterContainer/VBoxContainer/DrillsButton
@onready var options_button: Button = $Panel/CenterContainer/VBoxContainer/OptionButton
@onready var quit_button: Button = $Panel/CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	options_button.disabled = false
	options_button.text = "Test Arena"

	_disconnect_menu_signals()
	_connect_menu_signals()
	_refresh_menu()

func _disconnect_menu_signals() -> void:
	if play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.disconnect(_on_play_pressed)
	if continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.disconnect(_on_continue_pressed)
	if abandon_button.pressed.is_connected(_on_abandon_pressed):
		abandon_button.pressed.disconnect(_on_abandon_pressed)
	if drills_button.pressed.is_connected(_on_drills_pressed):
		drills_button.pressed.disconnect(_on_drills_pressed)
	if options_button.pressed.is_connected(_on_sandbox_pressed):
		options_button.pressed.disconnect(_on_sandbox_pressed)
	if quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.disconnect(_on_quit_pressed)

func _connect_menu_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	abandon_button.pressed.connect(_on_abandon_pressed)
	drills_button.pressed.connect(_on_drills_pressed)
	options_button.pressed.connect(_on_sandbox_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _refresh_menu() -> void:
	var has_save: bool = SaveManager.has_save()
	play_button.visible = not has_save
	continue_button.visible = has_save
	abandon_button.visible = has_save

func _on_play_pressed() -> void:
	SaveManager.clear_save()
	RunData.start_main_run()
	RunData.selected_captain = ""
	get_tree().change_scene_to_file(CAPTAIN_SELECT_SCENE)

func _on_continue_pressed() -> void:
	RunData.start_main_run()
	var save_state: Dictionary = SaveManager.load_save()
	if String(save_state.get("scene", "battle")) == "intermission":
		get_tree().change_scene_to_file(INTERMISSION_SCENE)
		return

	SaveManager.request_continue()
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _on_abandon_pressed() -> void:
	SaveManager.clear_save()
	RunData.start_main_run()
	RunData.selected_captain = ""
	PlayerData.reset_run()
	_refresh_menu()

func _on_drills_pressed() -> void:
	get_tree().change_scene_to_file(DRILLS_MENU_SCENE)

func _on_sandbox_pressed() -> void:
	RunData.clear_sandbox()
	get_tree().change_scene_to_file(SANDBOX_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
