extends Control

const CannonLoadSlotScript = preload("res://ui/CannonLoadSlot.gd")
const CANNON_TEXTURE: Texture2D = preload("res://assets/backgrounds/cannon_overlay.png")

const REFERENCE_SCREEN_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const DESIGN_CANVAS_SIZE: Vector2 = Vector2(3840.0, 2160.0)
const SHOW_ALL_PLACEMENT_SLOTS: bool = false
const MAX_CANNON_SLOTS: int = 2
const REFERENCE_LAYOUT_CENTER: Vector2 = Vector2(960.0, 572.0)
const REFERENCE_SLOT_SPACING: float = 170.0
const REFERENCE_ARC_EDGE_DROP: float = 0.0
const CANNON_VISUAL_SIZE: Vector2 = Vector2(336.0, 378.0)
const CANNON_VISUAL_CENTER_OFFSET: Vector2 = Vector2(0.0, 101.0)

@export_range(-1, 2, 1) var debug_active_count_override: int = -1

var cannon_slots: Array[Control] = []
var cannon_visuals: Array[TextureRect] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_slots()
	TurnManager.register_cannon_load_slots(cannon_slots)
	refresh_slots()

func refresh_slots() -> void:
	var active_count: int = mini(PlayerData.get_installed_cannon_count(), cannon_slots.size())
	if OS.is_debug_build() and debug_active_count_override >= 0:
		active_count = clampi(debug_active_count_override, 0, cannon_slots.size())

	for index in range(cannon_slots.size()):
		var slot: Control = cannon_slots[index]
		var visual: TextureRect = cannon_visuals[index]
		var slot_is_active: bool = index < active_count
		var slot_center: Vector2 = _get_slot_center(index, active_count)
		_position_cannon_visual(visual, slot_center)
		visual.visible = slot_is_active
		if slot.has_method("set_center_position"):
			slot.call("set_center_position", slot_center)
		if slot.has_method("set_active"):
			slot.call("set_active", slot_is_active)
		if not slot_is_active and SHOW_ALL_PLACEMENT_SLOTS and slot.has_method("set_placement_preview_visible"):
			slot.call("set_placement_preview_visible", true)

	TurnManager.rebuild_cannon_queue_from_slots()

func get_slots() -> Array[Control]:
	return cannon_slots.duplicate()

func debug_set_slot_count(count: int) -> void:
	if not OS.is_debug_build():
		return
	debug_active_count_override = clampi(count, 0, cannon_slots.size())
	refresh_slots()

func debug_clear_slot_count_override() -> void:
	if not OS.is_debug_build():
		return
	debug_active_count_override = -1
	refresh_slots()

func _create_slots() -> void:
	if not cannon_slots.is_empty():
		return

	for index in range(MAX_CANNON_SLOTS):
		var visual: TextureRect = _create_cannon_visual(index)
		add_child(visual)
		cannon_visuals.append(visual)

	for index in range(MAX_CANNON_SLOTS):
		var slot: Control = CannonLoadSlotScript.new() as Control
		slot.z_index = 10
		add_child(slot)
		if slot.has_method("setup"):
			var slot_center: Vector2 = _get_slot_center(index, MAX_CANNON_SLOTS)
			slot.call("setup", index, slot_center)
		cannon_slots.append(slot)

func _create_cannon_visual(index: int) -> TextureRect:
	var visual: TextureRect = TextureRect.new()
	visual.name = "CannonVisual%d" % (index + 1)
	visual.texture = CANNON_TEXTURE
	visual.size = CANNON_VISUAL_SIZE
	visual.pivot_offset = CANNON_VISUAL_SIZE * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return visual

func _position_cannon_visual(visual: TextureRect, slot_center: Vector2) -> void:
	var visual_center: Vector2 = slot_center + CANNON_VISUAL_CENTER_OFFSET
	visual.position = visual_center - CANNON_VISUAL_SIZE * 0.5
	visual.size = CANNON_VISUAL_SIZE
	visual.pivot_offset = CANNON_VISUAL_SIZE * 0.5

func _get_slot_center(index: int, active_count: int) -> Vector2:
	if active_count <= 0:
		return _reference_to_canvas_position(REFERENCE_LAYOUT_CENTER)

	var half_active_width: float = float(active_count - 1) * 0.5
	var x_offset: float = (float(index) - half_active_width) * REFERENCE_SLOT_SPACING
	var max_arc_width: float = float(MAX_CANNON_SLOTS - 1) * REFERENCE_SLOT_SPACING * 0.5
	var arc_ratio: float = 0.0
	if max_arc_width > 0.0:
		arc_ratio = clampf(absf(x_offset) / max_arc_width, 0.0, 1.0)

	var reference_position: Vector2 = REFERENCE_LAYOUT_CENTER + Vector2(
		x_offset,
		arc_ratio * arc_ratio * REFERENCE_ARC_EDGE_DROP
	)
	return _reference_to_canvas_position(reference_position)

func _reference_to_canvas_position(reference_position: Vector2) -> Vector2:
	return Vector2(
		reference_position.x * (DESIGN_CANVAS_SIZE.x / REFERENCE_SCREEN_SIZE.x),
		reference_position.y * (DESIGN_CANVAS_SIZE.y / REFERENCE_SCREEN_SIZE.y)
	)
