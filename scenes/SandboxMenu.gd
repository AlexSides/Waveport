extends Control

const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const DEFAULT_SANDBOX_CAPTAIN_ID := "captain_1"

@onready var crab_button: Button = $Panel/CenterContainer/VBoxContainer/CrabButton
@onready var eel_button: Button = $Panel/CenterContainer/VBoxContainer/EelButton
@onready var jellyfish_button: Button = $Panel/CenterContainer/VBoxContainer/JellyfishButton
@onready var starfish_button: Button = $Panel/CenterContainer/VBoxContainer/StarfishButton
@onready var piranha_button: Button = $Panel/CenterContainer/VBoxContainer/PiranhaButton
@onready var shark_button: Button = $Panel/CenterContainer/VBoxContainer/SharkButton
@onready var back_button: Button = $Panel/CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	_disconnect_menu_signals()
	_connect_menu_signals()

func _disconnect_menu_signals() -> void:
	if crab_button.pressed.is_connected(_on_crab_pressed):
		crab_button.pressed.disconnect(_on_crab_pressed)
	if eel_button.pressed.is_connected(_on_eel_pressed):
		eel_button.pressed.disconnect(_on_eel_pressed)
	if jellyfish_button.pressed.is_connected(_on_jellyfish_pressed):
		jellyfish_button.pressed.disconnect(_on_jellyfish_pressed)
	if starfish_button.pressed.is_connected(_on_starfish_pressed):
		starfish_button.pressed.disconnect(_on_starfish_pressed)
	if piranha_button.pressed.is_connected(_on_piranha_pressed):
		piranha_button.pressed.disconnect(_on_piranha_pressed)
	if shark_button.pressed.is_connected(_on_shark_pressed):
		shark_button.pressed.disconnect(_on_shark_pressed)
	if back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)

func _connect_menu_signals() -> void:
	crab_button.pressed.connect(_on_crab_pressed)
	eel_button.pressed.connect(_on_eel_pressed)
	jellyfish_button.pressed.connect(_on_jellyfish_pressed)
	starfish_button.pressed.connect(_on_starfish_pressed)
	piranha_button.pressed.connect(_on_piranha_pressed)
	shark_button.pressed.connect(_on_shark_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _on_crab_pressed() -> void:
	_start_sandbox_fight(_build_encounter("Shellback Crab", {
		"center": "shellback_crab"
	}))

func _on_eel_pressed() -> void:
	_start_sandbox_fight(_build_encounter("Reef Eel", {
		"center": "eel"
	}))

func _on_jellyfish_pressed() -> void:
	_start_sandbox_fight(_build_encounter("Jellyfish Pair", {
		"center": "jellyfish",
		"right": "jellyfish"
	}))

func _on_starfish_pressed() -> void:
	_start_sandbox_fight(_build_encounter("Starfish", {
		"center": "starfish"
	}))

func _on_piranha_pressed() -> void:
	_start_sandbox_fight(_build_encounter("Piranha Swarm", {
		"left": "piranha_a",
		"center": "piranha_b",
		"right": "piranha_c"
	}))

func _on_shark_pressed() -> void:
	_start_sandbox_fight(_build_encounter("Reef Shark", {
		"center": "reef_shark"
	}))

func _on_back_pressed() -> void:
	RunData.clear_sandbox()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _start_sandbox_fight(encounter: Dictionary) -> void:
	RunData.selected_captain = DEFAULT_SANDBOX_CAPTAIN_ID
	PlayerData.apply_captain_starting_deck(DEFAULT_SANDBOX_CAPTAIN_ID)
	RunData.start_sandbox_encounter(encounter)
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _build_encounter(wave_name: String, enemies: Dictionary) -> Dictionary:
	return {
		"wave_name": wave_name,
		"enemies": enemies.duplicate(true)
	}
