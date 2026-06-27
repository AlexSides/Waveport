extends Control

const CaptainList = preload("res://data/CaptainList.gd")
const CardListData = preload("res://data/CardList.gd")
const EnemyRunConfig = preload("res://data/EnemyRunConfig.gd")
const ModuleListData = preload("res://data/ModuleList.gd")
const ShipList = preload("res://data/ShipList.gd")
const INTERMISSION_SCENE := "res://scenes/IntermissionScreen.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

const CARD_SIZE := Vector2(1260, 1030)
const ROTATION_SECONDS := 0.42

var selected_captain: String = ""
var focused_captain_index: int = 0
var captains: Array[Dictionary] = []
var captain_cards: Array[Control] = []
var card_defs: Dictionary = {}
var carousel_position: float = 0.0
var is_rotating := false
var carousel_tween: Tween = null

@onready var previous_button: Button = $RootMargin/ScreenRoot/CarouselRow/PreviousButton
@onready var next_button: Button = $RootMargin/ScreenRoot/CarouselRow/NextButton
@onready var continue_button: Button = $RootMargin/ScreenRoot/ButtonsRow/ContinueButton
@onready var back_button: Button = $RootMargin/ScreenRoot/ButtonsRow/BackButton
@onready var card_layer: Control = $RootMargin/ScreenRoot/CarouselRow/CarouselStage/CardLayer
@onready var card_template: PanelContainer = $RootMargin/ScreenRoot/CarouselRow/CarouselStage/CardLayer/CaptainCardTemplate
@onready var captain_index_label: Label = $RootMargin/ScreenRoot/CarouselIndex

func _ready() -> void:
	captains = CaptainList.get_all_captains()
	card_defs = CardListData.new().CARD_LIBRARY

	_disconnect_captain_signals()
	_connect_captain_signals()
	_set_initial_focus()
	_build_captain_cards()
	_refresh_focused_captain()
	_set_carousel_position(float(focused_captain_index))
	call_deferred("_set_carousel_position", carousel_position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not captain_cards.is_empty():
		_set_carousel_position(carousel_position)

func _disconnect_captain_signals() -> void:
	if previous_button.pressed.is_connected(_on_previous_pressed):
		previous_button.pressed.disconnect(_on_previous_pressed)
	if next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.disconnect(_on_next_pressed)
	if continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.disconnect(_on_continue_pressed)
	if back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)

func _connect_captain_signals() -> void:
	previous_button.pressed.connect(_on_previous_pressed)
	next_button.pressed.connect(_on_next_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _set_initial_focus() -> void:
	if captains.is_empty():
		return

	var preferred_captain_id := String(RunData.selected_captain)
	if preferred_captain_id == "":
		preferred_captain_id = CaptainList.DEFAULT_CAPTAIN_ID

	var preferred_index := _find_captain_index(preferred_captain_id)
	focused_captain_index = preferred_index if preferred_index != -1 else 0
	carousel_position = float(focused_captain_index)

func _find_captain_index(captain_id: String) -> int:
	for index in range(captains.size()):
		var captain := captains[index]
		if String(captain.get("id", "")) == captain_id:
			return index
	return -1

func _build_captain_cards() -> void:
	card_template.visible = false

	for card in captain_cards:
		if is_instance_valid(card):
			card.queue_free()
	captain_cards.clear()

	for index in range(captains.size()):
		var captain_card := card_template.duplicate() as Control
		card_layer.add_child(captain_card)
		captain_card.visible = true
		captain_card.size = CARD_SIZE
		captain_card.pivot_offset = CARD_SIZE * 0.5
		captain_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		captain_card.set_meta("captain_index", index)
		_populate_captain_card(captain_card, captains[index])
		captain_cards.append(captain_card)

func _populate_captain_card(card: Control, captain: Dictionary) -> void:
	var captain_id := String(captain.get("id", ""))
	var captain_name := String(captain.get("name", captain_id))
	var ship_id := PlayerData.get_captain_starting_ship_id(captain_id)
	var starter_deck := PlayerData.get_captain_starting_deck(captain_id)
	var visual_color = Color(0.22, 0.22, 0.22, 1)
	if captain.has("visual_color") and captain["visual_color"] is Color:
		visual_color = captain["visual_color"]

	var captain_visual := card.get_node("PanelMargin/CaptainContent/CaptainVisual") as ColorRect
	var visual_label := card.get_node("PanelMargin/CaptainContent/CaptainVisual/VisualLabel") as Label
	var captain_name_label := card.get_node("PanelMargin/CaptainContent/CaptainName") as Label
	var captain_desc_label := card.get_node("PanelMargin/CaptainContent/CaptainDesc") as Label
	var captain_focus_label := card.get_node("PanelMargin/CaptainContent/CaptainFocus") as Label
	var captain_deck_label := card.get_node("PanelMargin/CaptainContent/DetailsList/DeckLabel") as Label
	var captain_ship_label := card.get_node("PanelMargin/CaptainContent/DetailsList/ShipLabel") as Label
	var captain_modules_label := card.get_node("PanelMargin/CaptainContent/DetailsList/ModulesLabel") as Label
	var captain_stats_label := card.get_node("PanelMargin/CaptainContent/DetailsList/StatsLabel") as Label

	captain_visual.color = visual_color
	visual_label.text = String(captain.get("visual_label", captain_name))
	captain_name_label.text = captain_name
	captain_desc_label.text = String(captain.get("description", ""))
	captain_focus_label.text = "Focus: %s" % String(captain.get("focus", "Open seas"))
	captain_deck_label.text = "Starter Deck: %s" % _build_card_list_summary(starter_deck)
	captain_ship_label.text = "Starting Ship: %s" % ShipList.get_ship_name(ship_id)
	captain_modules_label.text = "Starting Modules: %s" % _build_starting_module_summary(ship_id)
	captain_stats_label.text = "Ship Stats: %s" % _build_ship_stats_summary(ship_id)

func _on_previous_pressed() -> void:
	_rotate_captain(-1)

func _on_next_pressed() -> void:
	_rotate_captain(1)

func _rotate_captain(direction: int) -> void:
	if captains.size() <= 1 or is_rotating:
		return

	var target_index := _wrap_index(focused_captain_index + direction)
	var from_position := carousel_position
	var target_position := carousel_position + float(direction)

	is_rotating = true
	_set_carousel_controls_disabled(true)

	if carousel_tween != null:
		carousel_tween.kill()

	carousel_tween = create_tween()
	carousel_tween.set_trans(Tween.TRANS_CUBIC)
	carousel_tween.set_ease(Tween.EASE_OUT)
	carousel_tween.tween_method(Callable(self, "_set_carousel_position"), from_position, target_position, ROTATION_SECONDS)
	carousel_tween.finished.connect(_on_rotation_finished.bind(target_index))

func _on_rotation_finished(target_index: int) -> void:
	focused_captain_index = target_index
	carousel_position = float(focused_captain_index)
	is_rotating = false
	_refresh_focused_captain()
	_set_carousel_position(carousel_position)
	_set_carousel_controls_disabled(false)

func _set_carousel_position(value: float) -> void:
	carousel_position = value
	if captain_cards.is_empty():
		return

	var layer_size := card_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		layer_size = Vector2(2200, 1320)

	var center := Vector2(layer_size.x * 0.5, layer_size.y * 0.55)
	var radius_x: float = minf(layer_size.x * 0.38, 1120.0)
	var radius_y: float = minf(layer_size.y * 0.12, 160.0)
	var count := captains.size()

	for card in captain_cards:
		var card_index := int(card.get_meta("captain_index", 0))
		var offset := _wrap_offset(float(card_index) - carousel_position, count)
		var angle := offset * TAU / float(count)
		var depth := cos(angle)
		var depth_factor := clampf((depth + 1.0) * 0.5, 0.0, 1.0)
		var focus_factor := clampf(1.0 - abs(offset), 0.0, 1.0)
		var card_scale := lerpf(0.56, 1.0, depth_factor)
		var alpha := lerpf(0.34, 1.0, depth_factor)
		var card_center := Vector2(
			center.x + sin(angle) * radius_x,
			center.y - depth_factor * radius_y + radius_y * 0.35
		)

		card.size = CARD_SIZE
		card.pivot_offset = CARD_SIZE * 0.5
		card.position = card_center - CARD_SIZE * 0.5
		card.scale = Vector2(card_scale, card_scale)
		card.rotation = 0.0
		card.z_index = int(depth_factor * 100.0)
		card.modulate = Color(1, 1, 1, alpha)
		_set_card_detail_visibility(card, focus_factor)

func _set_card_detail_visibility(card: Control, focus_factor: float) -> void:
	var captain_desc_label := card.get_node("PanelMargin/CaptainContent/CaptainDesc") as Label
	var captain_focus_label := card.get_node("PanelMargin/CaptainContent/CaptainFocus") as Label
	var details_list := card.get_node("PanelMargin/CaptainContent/DetailsList") as Control
	var detail_alpha := clampf(focus_factor, 0.0, 1.0)

	captain_desc_label.modulate = Color(1, 1, 1, lerpf(0.22, 1.0, detail_alpha))
	captain_focus_label.modulate = Color(1, 1, 1, detail_alpha)
	details_list.modulate = Color(1, 1, 1, detail_alpha)

func _refresh_focused_captain() -> void:
	if captains.is_empty():
		_show_empty_state()
		return

	var captain := _get_focused_captain()
	var captain_id := String(captain.get("id", ""))
	_select_captain(captain_id)
	captain_index_label.text = "%d / %d" % [focused_captain_index + 1, captains.size()]
	_set_carousel_controls_disabled(false)

func _show_empty_state() -> void:
	selected_captain = ""
	captain_index_label.text = "0 / 0"
	_set_carousel_controls_disabled(true)

func _get_focused_captain() -> Dictionary:
	if captains.is_empty():
		return {}
	return captains[focused_captain_index]

func _select_captain(captain_id: String) -> void:
	selected_captain = captain_id

func _set_carousel_controls_disabled(disabled: bool) -> void:
	var no_captains := captains.is_empty()
	var single_captain := captains.size() <= 1
	previous_button.disabled = disabled or no_captains or single_captain
	next_button.disabled = disabled or no_captains or single_captain
	continue_button.disabled = disabled or no_captains

func _wrap_index(index: int) -> int:
	if captains.is_empty():
		return 0

	var count := captains.size()
	return ((index % count) + count) % count

func _wrap_offset(offset: float, count: int) -> float:
	var wrapped_offset := offset
	var half_count := float(count) * 0.5

	while wrapped_offset > half_count:
		wrapped_offset -= float(count)
	while wrapped_offset < -half_count:
		wrapped_offset += float(count)

	return wrapped_offset

func _on_continue_pressed() -> void:
	if captains.is_empty() or is_rotating:
		return

	_select_captain(String(_get_focused_captain().get("id", "")))
	if selected_captain == "":
		return

	RunData.start_main_run()
	RunData.selected_captain = selected_captain
	PlayerData.apply_captain_starting_deck(selected_captain)
	PlayerData.ensure_run_state()
	SaveManager.save_pre_battle({
		"version": 4,
		"scene": "intermission",
		"player": PlayerData.to_save_dict(),
		"battle": {
			"current_encounter": {},
			"remaining_encounters": EnemyRunConfig.get_default_run_order(),
			"plunder_index": 0
		}
	})
	get_tree().change_scene_to_file(INTERMISSION_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _build_card_list_summary(card_ids: Array[String]) -> String:
	if card_ids.is_empty():
		return "None"

	var card_counts: Dictionary = {}
	var card_names: Array[String] = []
	for card_id in card_ids:
		var card_name := _get_card_display_name(card_id)
		if not card_counts.has(card_name):
			card_names.append(card_name)
		card_counts[card_name] = int(card_counts.get(card_name, 0)) + 1

	var summary_parts: Array[String] = []
	for card_name in card_names:
		var count := int(card_counts.get(card_name, 0))
		if count > 1:
			summary_parts.append("%dx %s" % [count, card_name])
		else:
			summary_parts.append(card_name)

	return ", ".join(summary_parts)

func _get_card_display_name(card_id: String) -> String:
	var card_def: Dictionary = card_defs.get(card_id, {})
	return String(card_def.get("name", card_id))

func _build_starting_module_summary(ship_id: String) -> String:
	var installed_modules := ShipList.get_starting_installed_modules(ship_id)
	if installed_modules.is_empty():
		return "None"

	var module_counts: Dictionary = {}
	var module_names: Array[String] = []
	for slot_id_variant in installed_modules.keys():
		var module_id := String(installed_modules.get(slot_id_variant, ""))
		if module_id == "":
			continue

		var module_name := _get_module_display_name(module_id)
		if not module_counts.has(module_name):
			module_names.append(module_name)
		module_counts[module_name] = int(module_counts.get(module_name, 0)) + 1

	if module_names.is_empty():
		return "None"

	var summary_parts: Array[String] = []
	for module_name in module_names:
		var count := int(module_counts.get(module_name, 0))
		if count > 1:
			summary_parts.append("%dx %s" % [count, module_name])
		else:
			summary_parts.append(module_name)

	return ", ".join(summary_parts)

func _get_module_display_name(module_id: String) -> String:
	var module_def: Dictionary = ModuleListData.get_module(module_id)
	return String(module_def.get("name", module_id))

func _build_ship_stats_summary(ship_id: String) -> String:
	var hull := 40 + _get_starting_hull_bonus(ship_id)
	var cargo_capacity := ShipList.get_cargo_capacity(ship_id)
	var active_slots := ShipList.get_active_slot_count(ship_id)
	return "%d Hull | %d Cargo | %d Active Slots" % [hull, cargo_capacity, active_slots]

func _get_starting_hull_bonus(ship_id: String) -> int:
	var total := 0
	var installed_modules := ShipList.get_starting_installed_modules(ship_id)
	for slot_id_variant in installed_modules.keys():
		var module_id := String(installed_modules.get(slot_id_variant, ""))
		var module_def: Dictionary = ModuleListData.get_module(module_id)
		total += int(module_def.get("hull_bonus", 0))
	return total
