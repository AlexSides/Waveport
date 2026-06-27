extends Control

const EnemyList = preload("res://data/EnemyList.gd")

const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const DEFAULT_SANDBOX_CAPTAIN_ID := "captain_1"
const PAGE_SIZE := 6

@onready var enemy_list: VBoxContainer = $Panel/CenterContainer/MenuRoot/EnemyList
@onready var previous_button: Button = $Panel/CenterContainer/MenuRoot/NavRow/PreviousButton
@onready var page_label: Label = $Panel/CenterContainer/MenuRoot/NavRow/PageLabel
@onready var next_button: Button = $Panel/CenterContainer/MenuRoot/NavRow/NextButton
@onready var back_button: Button = $Panel/BackButton

var sandbox_entries: Array[Dictionary] = []
var enemy_buttons: Array[Button] = []
var current_page: int = 0

func _ready() -> void:
	sandbox_entries = EnemyList.get_sandbox_entries()
	_create_enemy_buttons()
	_connect_menu_signals()
	_render_page()

func _create_enemy_buttons() -> void:
	for child in enemy_list.get_children():
		child.queue_free()

	enemy_buttons.clear()
	for index in range(PAGE_SIZE):
		var button := Button.new()
		button.custom_minimum_size = Vector2(560.0, 56.0)
		button.add_theme_font_size_override("font_size", 32)
		button.pressed.connect(_on_enemy_button_pressed.bind(index))
		enemy_list.add_child(button)
		enemy_buttons.append(button)

func _connect_menu_signals() -> void:
	if not previous_button.pressed.is_connected(_on_previous_pressed):
		previous_button.pressed.connect(_on_previous_pressed)
	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

func _render_page() -> void:
	var total_pages: int = _get_total_pages()
	current_page = clampi(current_page, 0, max(total_pages - 1, 0))

	var first_index: int = current_page * PAGE_SIZE
	for button_index in range(enemy_buttons.size()):
		var entry_index: int = first_index + button_index
		var button: Button = enemy_buttons[button_index]

		if entry_index < sandbox_entries.size():
			var entry: Dictionary = sandbox_entries[entry_index]
			button.text = String(entry.get("name", "Enemy"))
			button.disabled = false
			button.show()
		elif sandbox_entries.is_empty() and button_index == 0:
			button.text = "No enemies available"
			button.disabled = true
			button.show()
		else:
			button.hide()

	page_label.text = "%d / %d" % [min(current_page + 1, total_pages), total_pages]
	previous_button.visible = total_pages > 1
	next_button.visible = total_pages > 1
	page_label.visible = total_pages > 1
	previous_button.disabled = current_page <= 0
	next_button.disabled = current_page >= total_pages - 1

func _get_total_pages() -> int:
	return max(1, int(ceil(float(sandbox_entries.size()) / float(PAGE_SIZE))))

func _on_enemy_button_pressed(button_index: int) -> void:
	var entry_index: int = current_page * PAGE_SIZE + button_index
	if entry_index < 0 or entry_index >= sandbox_entries.size():
		return

	var entry: Dictionary = sandbox_entries[entry_index]
	var enemies: Dictionary = Dictionary(entry.get("enemies", {}))
	if enemies.is_empty():
		enemies = {
			"center": String(entry.get("id", ""))
		}

	_start_sandbox_fight(_build_encounter(String(entry.get("name", "Sandbox Enemy")), enemies))

func _on_previous_pressed() -> void:
	current_page -= 1
	_render_page()

func _on_next_pressed() -> void:
	current_page += 1
	_render_page()

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
