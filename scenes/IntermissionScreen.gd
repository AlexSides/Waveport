extends Control

const BATTLE_SCENE := "res://scenes/BattleScene.tscn"

@onready var title_label: Label = $Panel/CenterContainer/VBoxContainer/TitleLabel
@onready var summary_label: Label = $Panel/CenterContainer/VBoxContainer/SummaryLabel
@onready var status_label: Label = $Panel/CenterContainer/VBoxContainer/StatusLabel
@onready var shipyard_button: Button = $Panel/CenterContainer/VBoxContainer/ButtonsRow/ShipyardButton
@onready var sail_button: Button = $Panel/CenterContainer/VBoxContainer/ButtonsRow/SailButton
@onready var ship_preview: Control = $ShipPreview

var save_state: Dictionary = {}
var battle_state: Dictionary = {}

func _ready() -> void:
	save_state = SaveManager.load_save()
	if not save_state.is_empty():
		PlayerData.load_from_save_dict(Dictionary(save_state.get("player", {})))
		battle_state = Dictionary(save_state.get("battle", {}))
	else:
		battle_state = {
			"current_encounter": {},
			"remaining_encounters": [],
			"plunder_index": 0
		}

	ship_preview.hide()

	shipyard_button.pressed.connect(_on_shipyard_pressed)
	sail_button.pressed.connect(_on_sail_pressed)

	_refresh_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		if ship_preview and ship_preview.has_method("toggle_preview"):
			ship_preview.toggle_preview()
			get_viewport().set_input_as_handled()

func _refresh_ui() -> void:
	var remaining_battles: int = _get_remaining_battle_count()
	var cargo_text := "Cargo %d/%d" % [PlayerData.get_cargo_count(), PlayerData.get_cargo_capacity()]
	var hull_text := "Hull %d/%d" % [PlayerData.current_health, PlayerData.current_max_health]
	var gold_text := "Gold %d" % PlayerData.gold

	title_label.text = "Voyage Intermission"
	summary_label.text = "%s | %s | %s | %s | Battles Ahead %d" % [
		PlayerData.get_ship_name(),
		hull_text,
		gold_text,
		cargo_text,
		remaining_battles
	]
	status_label.text = "Open Shipyard to manage modules, then sail on when ready."

	if remaining_battles <= 0:
		sail_button.text = "Finish Voyage"
	else:
		sail_button.text = "Next Battle"

func _get_remaining_battle_count() -> int:
	return Array(battle_state.get("remaining_encounters", [])).size()

func _on_shipyard_pressed() -> void:
	if ship_preview and ship_preview.has_method("open_preview"):
		ship_preview.open_preview()
		status_label.text = "Shipyard open. Install or remove modules, then close it with Tab or Esc."

func _on_sail_pressed() -> void:
	_save_intermission_state()

	if _get_remaining_battle_count() <= 0:
		var result_scene = load("res://scenes/ResultScreen.tscn").instantiate()
		result_scene.is_victory = true
		get_tree().root.add_child(result_scene)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = result_scene
		return

	SaveManager.request_continue()
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _save_intermission_state() -> void:
	battle_state["current_encounter"] = {}
	save_state = {
		"version": 4,
		"scene": "intermission",
		"player": PlayerData.to_save_dict(),
		"battle": battle_state.duplicate(true)
	}
	SaveManager.save_pre_battle(save_state)
