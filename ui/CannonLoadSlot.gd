extends Control

const SLOT_SIZE: Vector2 = Vector2(108.0, 108.0)
const EMPTY_COLOR: Color = Color(0.12, 0.17, 0.18, 0.72)
const HOVER_COLOR: Color = Color(0.78, 0.63, 0.28, 0.82)
const LOADED_COLOR: Color = Color(0.48, 0.24, 0.09, 0.92)
const LOADED_HOVER_COLOR: Color = Color(0.72, 0.36, 0.12, 0.96)
const DAMAGE_LABEL_SIZE: Vector2 = Vector2(180.0, 46.0)
const DAMAGE_LABEL_OFFSET: Vector2 = Vector2(-36.0, -56.0)
const DRAG_START_DISTANCE: float = 8.0

var slot_index: int = 0
var is_active: bool = false
var is_placement_preview_visible: bool = false
var loaded_card_data: Dictionary = {}
var damage_preview: int = 0
var is_highlighted: bool = false
var drag_press_active: bool = false
var drag_press_position: Vector2 = Vector2.ZERO

var background_rect: ColorRect = null
var slot_label: Label = null
var damage_label: Label = null

func _ready() -> void:
	add_to_group("CannonLoadSlot")
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	pivot_offset = SLOT_SIZE * 0.5
	_build_children()
	_update_visuals()

func setup(index: int, center_position: Vector2) -> void:
	slot_index = index
	name = "CannonLoadSlot%d" % (slot_index + 1)
	set_center_position(center_position)

func set_center_position(center_position: Vector2) -> void:
	position = center_position - SLOT_SIZE * 0.5
	size = SLOT_SIZE
	pivot_offset = SLOT_SIZE * 0.5
	_update_visuals()

func set_active(active: bool) -> void:
	is_active = active
	is_placement_preview_visible = false
	visible = active
	mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	if not active:
		loaded_card_data.clear()
		is_highlighted = false
	_update_visuals()

func set_placement_preview_visible(show_preview: bool) -> void:
	if is_active:
		return

	is_placement_preview_visible = show_preview
	visible = show_preview
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_visuals()

func can_accept_dragged_card(_card: Node) -> bool:
	return is_active and visible

func load_card(card: Node, source_slot: Control = null) -> bool:
	if not can_accept_dragged_card(card):
		return false
	return TurnManager.load_card_into_cannon_slot(card, self, source_slot)

func highlight() -> void:
	if not is_active:
		return
	is_highlighted = true
	_update_visuals()

func unhighlight() -> void:
	is_highlighted = false
	_update_visuals()

func set_loaded_card_data(card_data: Dictionary) -> void:
	loaded_card_data = card_data.duplicate(true)
	_update_visuals()

func get_loaded_card_data() -> Dictionary:
	return loaded_card_data.duplicate(true)

func clear_loaded_card() -> void:
	loaded_card_data.clear()
	damage_preview = 0
	_update_visuals()

func is_loaded() -> bool:
	return not loaded_card_data.is_empty()

func set_damage_preview(damage: int) -> void:
	damage_preview = maxi(damage, 0)
	_update_visuals()

func _gui_input(event: InputEvent) -> void:
	if not is_active or not is_loaded():
		drag_press_active = false
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			drag_press_active = true
			drag_press_position = get_global_mouse_position()
			accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			drag_press_active = false
			accept_event()
		return

	if event is InputEventMouseMotion and _try_begin_loaded_card_drag():
		accept_event()

func _input(event: InputEvent) -> void:
	if not drag_press_active:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			drag_press_active = false
		return

	if event is InputEventMouseMotion:
		_try_begin_loaded_card_drag()

func _try_begin_loaded_card_drag() -> bool:
	if not drag_press_active:
		return false

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		drag_press_active = false
		return false

	var drag_distance: float = get_global_mouse_position().distance_to(drag_press_position)
	if drag_distance < DRAG_START_DISTANCE:
		return false

	drag_press_active = false
	TurnManager.begin_drag_loaded_cannon_card(self)
	return true

func _build_children() -> void:
	if background_rect == null:
		background_rect = ColorRect.new()
		background_rect.name = "Background"
		background_rect.anchor_right = 1.0
		background_rect.anchor_bottom = 1.0
		background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background_rect)

	if slot_label == null:
		slot_label = Label.new()
		slot_label.name = "Label"
		slot_label.anchor_right = 1.0
		slot_label.anchor_bottom = 1.0
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_label.add_theme_font_size_override("font_size", 18)
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot_label)

	if damage_label == null:
		damage_label = Label.new()
		damage_label.name = "DamageLabel"
		damage_label.position = DAMAGE_LABEL_OFFSET
		damage_label.size = DAMAGE_LABEL_SIZE
		damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		damage_label.add_theme_font_size_override("font_size", 30)
		damage_label.add_theme_constant_override("outline_size", 5)
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28, 1.0))
		damage_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 1.0))
		damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(damage_label)

func _update_visuals() -> void:
	if background_rect == null or slot_label == null or damage_label == null:
		return

	var color: Color = EMPTY_COLOR
	if not is_active:
		color = Color(EMPTY_COLOR.r, EMPTY_COLOR.g, EMPTY_COLOR.b, 0.5)
	elif is_loaded():
		color = LOADED_HOVER_COLOR if is_highlighted else LOADED_COLOR
	else:
		color = HOVER_COLOR if is_highlighted else EMPTY_COLOR

	background_rect.color = color

	if not is_active:
		slot_label.text = "%d" % (slot_index + 1)
		damage_label.hide()
		tooltip_text = "Cannon placement preview"
	elif is_loaded():
		var card_name: String = String(loaded_card_data.get("name", "Loaded"))
		slot_label.text = card_name
		damage_label.text = "%d⚔" % damage_preview
		damage_label.show()
		tooltip_text = _build_loaded_tooltip(card_name)
	else:
		slot_label.text = "%d" % (slot_index + 1)
		damage_label.hide()
		tooltip_text = "Empty Cannon"

func _build_loaded_tooltip(card_name: String) -> String:
	var description: String = String(loaded_card_data.get("description", ""))
	if description == "":
		return card_name
	return "%s\n%s" % [card_name, description]
