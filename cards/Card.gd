extends Button

var card_name = ""
var art_path = ""
var frame_path = ""
var hide_text = false
var card_type = ""
var value = 0
var description = ""
var is_selected = false
var card_id = ""
var card_category = "Queue"
var hover_slot: Control = null

const DROP_THRESHOLD_Y = 1000

var dragging = false
var drag_offset = Vector2.ZERO
var original_parent = null
var original_index = 0
var home_position = Vector2.ZERO

func _ready() -> void:
	home_position = position

	$CardFrame/DescLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$CardFrame/DescLabel.clip_text = true
	$CardFrame/DescLabel.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func update_card() -> void:
	$CardFrame/NameLabel.text = card_name
	$CardFrame/DescLabel.text = description.replace("X", str(value))
	$CardFrame/NameLabel.visible = not hide_text
	$CardFrame/DescLabel.visible = not hide_text

	if art_path != "":
		$CardFrame/ArtRect.texture = load(art_path)
	else:
		$CardFrame/ArtRect.texture = null

	if frame_path != "":
		$CardFrame/FrameRect.texture = load(frame_path)

func deselect() -> void:
	is_selected = false
	modulate = Color(1, 1, 1)

func _gui_input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		deselect()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		CardManager.select_card(self)
		is_selected = true
		modulate = Color(1, 1, 0.6)
		drag_offset = get_global_mouse_position() - global_position

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging:
			stop_drag()

func _process(_delta: float) -> void:
	if is_selected and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not dragging:
			start_drag()
		drag_card()
	elif dragging:
		stop_drag()

func start_drag() -> void:
	dragging = true
	original_parent = get_parent()
	original_index = get_index()

	var drag_layer = get_tree().current_scene
	original_parent.remove_child(self)
	drag_layer.add_child(self)

func drag_card() -> void:
	global_position = get_viewport().get_mouse_position() - drag_offset

	var new_hover: Control = null
	for node in get_tree().get_nodes_in_group("ModuleSlot"):
		if node is Control:
			var slot_node: Control = node
			var slot_pos: Vector2 = slot_node.global_position
			var slot_size: Vector2 = slot_node.size
			if Rect2(slot_pos, slot_size).has_point(get_viewport().get_mouse_position()):
				new_hover = slot_node
				break

	if new_hover != hover_slot:
		if hover_slot and hover_slot.has_method("unhighlight"):
			hover_slot.unhighlight()
		hover_slot = new_hover
		if hover_slot and hover_slot.has_method("highlight"):
			hover_slot.highlight()

func stop_drag() -> void:
	dragging = false

	if hover_slot and global_position.y < DROP_THRESHOLD_Y:
		if not _can_play_for_tutorial():
			return_to_hand()
			if hover_slot and hover_slot.has_method("unhighlight"):
				hover_slot.unhighlight()
			hover_slot = null
			return

		if hover_slot.has_method("fill"):
			hover_slot.fill(card_name)
		if not TurnManager.queue_card(self):
			return_to_hand()
		if hover_slot and hover_slot.has_method("unhighlight"):
			hover_slot.unhighlight()
		hover_slot = null
		return

	if global_position.y < DROP_THRESHOLD_Y:
		play_card()
	else:
		return_to_hand()

	if hover_slot and hover_slot.has_method("unhighlight"):
		hover_slot.unhighlight()
	hover_slot = null

func play_card() -> void:
	if not _can_play_for_tutorial():
		return_to_hand()
		return

	match card_category:
		"Queue":
			if not TurnManager.queue_card(self):
				return_to_hand()
				return
		"Instant":
			TurnManager.resolve_instant_card(self)
		_:
			print("Unknown card category:", card_category)

func return_to_hand() -> void:
	if get_parent():
		get_parent().remove_child(self)
	original_parent.add_child(self)
	original_parent.move_child(self, original_index)
	position = home_position
	modulate = Color(1, 1, 1)
	is_selected = false

func _can_play_for_tutorial() -> bool:
	var scene = get_tree().current_scene
	if scene and scene.has_method("can_play_card_for_tutorial"):
		return scene.can_play_card_for_tutorial(self)
	return true
