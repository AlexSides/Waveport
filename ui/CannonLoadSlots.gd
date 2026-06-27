extends Control

const CannonLoadSlotScript = preload("res://ui/CannonLoadSlot.gd")

const REFERENCE_SCREEN_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const DESIGN_CANVAS_SIZE: Vector2 = Vector2(3840.0, 2160.0)
const SHOW_ALL_PLACEMENT_SLOTS: bool = false

const REFERENCE_SLOT_CENTERS: Array[Vector2] = [
	Vector2(360.0, 700.0),
	Vector2(520.0, 650.0),
	Vector2(695.0, 625.0),
	Vector2(880.0, 612.0),
	Vector2(1060.0, 612.0),
	Vector2(1235.0, 625.0),
	Vector2(1400.0, 650.0),
	Vector2(1550.0, 700.0)
]

var cannon_slots: Array[Control] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_slots()
	TurnManager.register_cannon_load_slots(cannon_slots)
	refresh_slots()

func refresh_slots() -> void:
	var active_count: int = mini(PlayerData.get_installed_cannon_count(), cannon_slots.size())

	for index in range(cannon_slots.size()):
		var slot: Control = cannon_slots[index]
		var slot_is_active: bool = index < active_count
		if slot.has_method("set_active"):
			slot.call("set_active", slot_is_active)
		if not slot_is_active and SHOW_ALL_PLACEMENT_SLOTS and slot.has_method("set_placement_preview_visible"):
			slot.call("set_placement_preview_visible", true)

	TurnManager.rebuild_cannon_queue_from_slots()

func get_slots() -> Array[Control]:
	return cannon_slots.duplicate()

func _create_slots() -> void:
	if not cannon_slots.is_empty():
		return

	for index in range(REFERENCE_SLOT_CENTERS.size()):
		var slot: Control = CannonLoadSlotScript.new() as Control
		add_child(slot)
		if slot.has_method("setup"):
			var slot_center: Vector2 = _reference_to_canvas_position(REFERENCE_SLOT_CENTERS[index])
			slot.call("setup", index, slot_center)
		cannon_slots.append(slot)

func _reference_to_canvas_position(reference_position: Vector2) -> Vector2:
	return Vector2(
		reference_position.x * (DESIGN_CANVAS_SIZE.x / REFERENCE_SCREEN_SIZE.x),
		reference_position.y * (DESIGN_CANVAS_SIZE.y / REFERENCE_SCREEN_SIZE.y)
	)
