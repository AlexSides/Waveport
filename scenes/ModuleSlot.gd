extends Control

var slot_label: Label

func _ready() -> void:
	add_to_group("ModuleSlot")
	unhighlight()

	slot_label = Label.new()
	slot_label.text = ""
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_label.anchor_right = 1.0
	slot_label.anchor_bottom = 1.0
	slot_label.offset_left = 0
	slot_label.offset_top = 0
	slot_label.offset_right = 0
	slot_label.offset_bottom = 0
	add_child(slot_label)

func highlight():
	$ColorRect.color = Color(1, 1, 0, 0.5)

func unhighlight():
	$ColorRect.color = Color(0.3, 0.3, 0.3, 0.5)

func fill(card_text: String) -> void:
	if slot_label:
		slot_label.text = card_text

func clear() -> void:
	if slot_label:
		slot_label.text = ""
