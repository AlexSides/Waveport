extends Button

static var texture_cache: Dictionary = {}

var card_name: String = ""
var art_path: String = ""
var frame_path: String = ""
var hide_text: bool = false
var card_type: String = ""
var value: int = 0
var cost: int = 0
var description: String = ""
var is_selected: bool = false
var card_id: String = ""
var card_category: String = "Queue"
var hover_slot: Control = null

const DROP_THRESHOLD_Y: float = 1000.0
const HOVER_RAISE_PIXELS: float = 36.0
const HOVER_SCALE: float = 1.1
const HOVER_TWEEN_SECONDS: float = 0.1
const LAYOUT_TWEEN_SECONDS: float = 0.12
const CANNON_SLOT_HOVER_SCALE: float = 0.67
const CANNON_SLOT_MAGNET_RADIUS: float = 280.0
const CANNON_SLOT_MAGNET_GAP: float = 18.0

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var drag_base_scale: Vector2 = Vector2.ONE
var original_parent: Node = null
var original_index: int = 0
var home_position: Vector2 = Vector2.ZERO
var hand_base_position: Vector2 = Vector2.ZERO
var hand_base_rotation: float = 0.0
var hand_base_scale: Vector2 = Vector2.ONE
var hand_base_z_index: int = 0
var is_hovered_in_hand: bool = false
var hover_tween: Tween = null
var source_cannon_slot: Control = null
var drag_cannon_slots: Array[Control] = []
var drag_module_slots: Array[Control] = []
var drag_slot_radii: Dictionary = {}

func _ready() -> void:
	set_process(dragging or is_selected)
	home_position = position
	hand_base_position = position

	$CardFrame/DescLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$CardFrame/DescLabel.clip_text = true
	$CardFrame/DescLabel.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func update_card() -> void:
	$CardFrame/NameLabel.text = card_name
	$CardFrame/DescLabel.text = description.replace("X", str(value))
	$CardFrame/CostLabel.text = str(cost)
	$CardFrame/NameLabel.visible = not hide_text
	$CardFrame/DescLabel.visible = not hide_text

	if art_path != "":
		$CardFrame/ArtRect.texture = _load_texture(art_path)
	else:
		$CardFrame/ArtRect.texture = null

	if frame_path != "":
		$CardFrame/FrameRect.texture = _load_texture(frame_path)

func deselect() -> void:
	is_selected = false
	modulate = Color(1, 1, 1)

func set_hand_base_transform(base_position: Vector2, base_rotation: float, base_scale: Vector2, base_z: int, animate: bool = true) -> void:
	hand_base_position = base_position
	hand_base_rotation = base_rotation
	hand_base_scale = base_scale
	hand_base_z_index = base_z
	home_position = base_position

	if dragging:
		return

	if is_hovered_in_hand:
		_animate_to_hover(animate)
	else:
		_animate_to_hand_base(animate)

func _gui_input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		deselect()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		CardManager.select_card(self)
		is_selected = true
		modulate = Color(1, 1, 0.6)
		drag_offset = get_global_mouse_position() - global_position
		set_process(true)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging:
			stop_drag()
		else:
			set_process(false)

func _process(_delta: float) -> void:
	if is_selected and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not dragging:
			start_drag()
		drag_card()
	elif dragging:
		stop_drag()
	else:
		set_process(false)

func start_drag() -> void:
	dragging = true
	is_hovered_in_hand = false
	source_cannon_slot = null
	_kill_hover_tween()
	original_parent = get_parent()
	original_index = get_index()
	var old_size: Vector2 = size
	if old_size.x <= 0.0 or old_size.y <= 0.0:
		old_size = _get_card_visual_size()

	var drag_layer: Node = get_tree().current_scene
	original_parent.remove_child(self)
	drag_layer.add_child(self)
	size = old_size
	pivot_offset = size * 0.5
	drag_offset = pivot_offset
	rotation = 0.0
	drag_base_scale = hand_base_scale
	scale = drag_base_scale
	_cache_drag_targets()
	global_position = _get_drag_position_for_mouse(get_viewport().get_mouse_position())
	z_index = 2000

func begin_drag_from_cannon_slot(source_slot: Control) -> void:
	source_cannon_slot = source_slot
	dragging = true
	is_selected = true
	set_process(true)
	is_hovered_in_hand = false
	_kill_hover_tween()

	var scene: Node = null
	if source_slot != null and source_slot.is_inside_tree():
		scene = source_slot.get_tree().current_scene
	elif DeckManager.battle_scene != null:
		scene = DeckManager.battle_scene

	if scene == null:
		dragging = false
		is_selected = false
		set_process(false)
		_clear_drag_targets()
		return

	if scene.has_node("BattleUI/CardHand"):
		original_parent = scene.get_node("BattleUI/CardHand")
	elif DeckManager.battle_scene != null and DeckManager.battle_scene.card_hand != null:
		original_parent = DeckManager.battle_scene.card_hand
	else:
		original_parent = scene

	original_index = original_parent.get_child_count() if original_parent != null else 0
	size = _get_card_visual_size()
	pivot_offset = size * 0.5
	drag_offset = pivot_offset

	if get_parent() != null:
		get_parent().remove_child(self)
	scene.add_child(self)

	var viewport: Viewport = scene.get_viewport()
	rotation = 0.0
	drag_base_scale = Vector2.ONE
	scale = drag_base_scale
	_cache_drag_targets()
	if viewport != null:
		global_position = _get_drag_position_for_mouse(viewport.get_mouse_position())
	z_index = 2000
	set_process(true)
	drag_card()

func drag_card() -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()

	var new_hover: Control = _find_hover_slot()

	if new_hover != hover_slot:
		if hover_slot and hover_slot.has_method("unhighlight"):
			hover_slot.call("unhighlight")
		hover_slot = new_hover
		if hover_slot and hover_slot.has_method("highlight"):
			hover_slot.call("highlight")

	_update_drag_slot_scale()
	global_position = _get_drag_position_for_mouse(mouse_position)

func stop_drag() -> void:
	dragging = false
	set_process(false)

	if hover_slot and hover_slot.has_method("load_card"):
		if not _can_play_for_tutorial():
			return_to_hand()
			if hover_slot and hover_slot.has_method("unhighlight"):
				hover_slot.call("unhighlight")
			hover_slot = null
			return

		if not _is_card_playable():
			_show_unplayable_message()
			return_to_hand()
			if hover_slot and hover_slot.has_method("unhighlight"):
				hover_slot.call("unhighlight")
			hover_slot = null
			return

		if bool(hover_slot.call("load_card", self, source_cannon_slot)):
			if hover_slot and hover_slot.has_method("unhighlight"):
				hover_slot.call("unhighlight")
			hover_slot = null
			source_cannon_slot = null
			_clear_drag_targets()
			return

		return_to_hand()
		if hover_slot and hover_slot.has_method("unhighlight"):
			hover_slot.call("unhighlight")
		hover_slot = null
		_clear_drag_targets()
		return

	if source_cannon_slot != null:
		return_to_hand()
		if hover_slot and hover_slot.has_method("unhighlight"):
			hover_slot.call("unhighlight")
		hover_slot = null
		return

	if hover_slot and global_position.y < DROP_THRESHOLD_Y:
		if not _can_play_for_tutorial():
			return_to_hand()
			if hover_slot and hover_slot.has_method("unhighlight"):
				hover_slot.call("unhighlight")
			hover_slot = null
			return

		if not _is_card_playable():
			_show_unplayable_message()
			return_to_hand()
			if hover_slot and hover_slot.has_method("unhighlight"):
				hover_slot.call("unhighlight")
			hover_slot = null
			return

		if hover_slot.has_method("fill"):
			hover_slot.call("fill", card_name)
		if not TurnManager.queue_card(self):
			return_to_hand()
		if hover_slot and hover_slot.has_method("unhighlight"):
			hover_slot.call("unhighlight")
		hover_slot = null
		return

	if global_position.y < DROP_THRESHOLD_Y:
		play_card()
	else:
		return_to_hand()

	if hover_slot and hover_slot.has_method("unhighlight"):
		hover_slot.call("unhighlight")
	hover_slot = null
	_clear_drag_targets()

func play_card() -> void:
	if not _can_play_for_tutorial():
		return_to_hand()
		return

	if not _is_card_playable():
		_show_unplayable_message()
		return_to_hand()
		return

	match card_category:
		"Queue":
			if not TurnManager.queue_card(self):
				return_to_hand()
				return
		"Instant":
			if not TurnManager.resolve_instant_card(self):
				return_to_hand()
				return
		_:
			print("Unknown card category:", card_category)
			return_to_hand()

func return_to_hand() -> void:
	var return_global_position: Vector2 = global_position
	var return_rotation: float = rotation
	var return_scale: Vector2 = scale

	if get_parent():
		get_parent().remove_child(self)
	original_parent.add_child(self)
	original_parent.move_child(self, original_index)
	if original_parent is Control:
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 0.0
		anchor_bottom = 0.0
		size = _get_card_visual_size()
		pivot_offset = size * 0.5
	global_position = return_global_position
	rotation = return_rotation
	scale = return_scale
	modulate = Color(1, 1, 1)
	is_selected = false
	is_hovered_in_hand = false
	source_cannon_slot = null
	_clear_drag_targets()

	if original_parent and original_parent.has_method("request_layout"):
		if not DeckManager.hand.has(self):
			DeckManager.hand.append(self)
		original_parent.call("request_layout")
		UIManager.update_deck_ui(DeckManager.deck.size(), DeckManager.discard_pile.size())
	else:
		position = home_position
		rotation = hand_base_rotation
		scale = hand_base_scale
		z_index = hand_base_z_index

func _can_play_for_tutorial() -> bool:
	var scene: Node = get_tree().current_scene
	if scene and scene.has_method("can_play_card_for_tutorial"):
		return bool(scene.call("can_play_card_for_tutorial", self))
	return true

func _is_card_playable() -> bool:
	if not DeckManager.card_defs.has(get_meta("card_id", "")):
		return true

	var def: Dictionary = DeckManager.card_defs.get(get_meta("card_id", ""), {})
	return bool(def.get("playable", true))

func _show_unplayable_message() -> void:
	var def: Dictionary = DeckManager.card_defs.get(get_meta("card_id", ""), {})
	var msg: String = String(def.get("unplayable_text", "Cannot be played."))
	var scene: Node = get_tree().current_scene

	if scene and scene.has_method("log_message"):
		scene.call("log_message", msg)
	else:
		UIManager.show_warning(msg)

func _on_mouse_entered() -> void:
	if dragging or not _is_in_hand():
		return

	is_hovered_in_hand = true
	var parent_node: Node = get_parent()
	if parent_node and parent_node.has_method("bring_card_to_front"):
		parent_node.call("bring_card_to_front", self)
	else:
		z_index = 1000

	_animate_to_hover(true)

func _on_mouse_exited() -> void:
	if dragging:
		return

	is_hovered_in_hand = false
	if _is_in_hand():
		_animate_to_hand_base(true)

func _animate_to_hover(animate: bool = true) -> void:
	var hover_position: Vector2 = hand_base_position + Vector2(0, -HOVER_RAISE_PIXELS)
	var hover_scale: Vector2 = hand_base_scale * HOVER_SCALE
	_animate_to_transform(hover_position, 0.0, hover_scale, 1000, animate, HOVER_TWEEN_SECONDS)

func _animate_to_hand_base(animate: bool = true) -> void:
	_animate_to_transform(hand_base_position, hand_base_rotation, hand_base_scale, hand_base_z_index, animate, LAYOUT_TWEEN_SECONDS)

func _update_drag_slot_scale() -> void:
	if not dragging:
		return

	var target_scale_ratio: float = _get_cannon_slot_scale_ratio()
	scale = drag_base_scale * target_scale_ratio

func _get_cannon_slot_scale_ratio() -> float:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var nearest_slot: Control = _get_nearest_cannon_slot(mouse_position)
	if nearest_slot == null:
		return 1.0

	var slot_center: Vector2 = _get_control_center(nearest_slot)
	var radius: float = _get_cannon_slot_radius(nearest_slot)
	if radius <= 0.0:
		return 1.0

	var distance_to_slot: float = mouse_position.distance_to(slot_center)
	if distance_to_slot >= radius:
		return 1.0

	var distance_ratio: float = clampf(distance_to_slot / radius, 0.0, 1.0)
	return lerpf(CANNON_SLOT_HOVER_SCALE, 1.0, distance_ratio)

func _animate_to_transform(target_position: Vector2, target_rotation: float, target_scale: Vector2, target_z_index: int, animate: bool, tween_seconds: float) -> void:
	_kill_hover_tween()
	z_index = target_z_index

	if not animate:
		position = target_position
		rotation = target_rotation
		scale = target_scale
		return

	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.set_trans(Tween.TRANS_QUAD)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "position", target_position, tween_seconds)
	hover_tween.tween_property(self, "rotation", target_rotation, tween_seconds)
	hover_tween.tween_property(self, "scale", target_scale, tween_seconds)

func _kill_hover_tween() -> void:
	if hover_tween != null:
		hover_tween.kill()
		hover_tween = null

func _is_in_hand() -> bool:
	var parent_node: Node = get_parent()
	return parent_node != null and parent_node.has_method("request_layout")

func _get_nearest_cannon_slot(mouse_position: Vector2) -> Control:
	var nearest_slot: Control = null
	var nearest_distance: float = INF

	for slot_node in _get_drag_cannon_slots():
		if not _can_use_cannon_slot_for_drag(slot_node):
			continue

		var distance_to_slot: float = mouse_position.distance_to(_get_control_center(slot_node))
		if distance_to_slot < nearest_distance:
			nearest_distance = distance_to_slot
			nearest_slot = slot_node

	if nearest_slot == null:
		return null

	if nearest_distance > _get_cannon_slot_radius(nearest_slot):
		return null

	return nearest_slot

func _get_cannon_slot_radius(slot: Control) -> float:
	if drag_slot_radii.has(slot):
		return float(drag_slot_radii[slot])

	var radius: float = CANNON_SLOT_MAGNET_RADIUS
	var slot_center: Vector2 = _get_control_center(slot)

	for other_slot in _get_drag_cannon_slots():
		if other_slot == slot or not _can_use_cannon_slot_for_drag(other_slot):
			continue

		var half_distance: float = slot_center.distance_to(_get_control_center(other_slot)) * 0.5
		radius = minf(radius, maxf(0.0, half_distance - CANNON_SLOT_MAGNET_GAP))

	return radius

func _can_use_cannon_slot_for_drag(slot: Control) -> bool:
	if slot == null or not slot.visible:
		return false
	if slot.has_method("can_accept_dragged_card") and not bool(slot.call("can_accept_dragged_card", self)):
		return false
	return slot.has_method("load_card")

func _get_control_center(control: Control) -> Vector2:
	return control.global_position + control.size * 0.5

func _get_card_visual_size() -> Vector2:
	var card_size: Vector2 = get_combined_minimum_size()
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = Vector2(400.0, 600.0)
	return card_size

func _get_drag_position_for_mouse(mouse_position: Vector2) -> Vector2:
	return mouse_position - Vector2(drag_offset.x * scale.x, drag_offset.y * scale.y)

func _find_hover_slot() -> Control:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()

	for slot_node in _get_drag_cannon_slots():
		if not _can_use_cannon_slot_for_drag(slot_node):
			continue
		if not Rect2(slot_node.global_position, slot_node.size).has_point(mouse_position):
			continue

		return slot_node

	for legacy_slot_node in _get_drag_module_slots():
		if Rect2(legacy_slot_node.global_position, legacy_slot_node.size).has_point(mouse_position):
			return legacy_slot_node

	return null

func _cache_drag_targets() -> void:
	drag_cannon_slots.clear()
	drag_module_slots.clear()
	drag_slot_radii.clear()

	for node in get_tree().get_nodes_in_group("CannonLoadSlot"):
		if node is Control:
			drag_cannon_slots.append(node as Control)

	for node in get_tree().get_nodes_in_group("ModuleSlot"):
		if node is Control:
			drag_module_slots.append(node as Control)

	for slot in drag_cannon_slots:
		if not _can_use_cannon_slot_for_drag(slot):
			continue
		drag_slot_radii[slot] = _calculate_cannon_slot_radius(slot)

func _clear_drag_targets() -> void:
	drag_cannon_slots.clear()
	drag_module_slots.clear()
	drag_slot_radii.clear()

func _get_drag_cannon_slots() -> Array[Control]:
	if drag_cannon_slots.is_empty():
		_cache_drag_targets()
	return drag_cannon_slots

func _get_drag_module_slots() -> Array[Control]:
	if drag_module_slots.is_empty():
		_cache_drag_targets()
	return drag_module_slots

func _calculate_cannon_slot_radius(slot: Control) -> float:
	var radius: float = CANNON_SLOT_MAGNET_RADIUS
	var slot_center: Vector2 = _get_control_center(slot)

	for other_slot in drag_cannon_slots:
		if other_slot == slot or not _can_use_cannon_slot_for_drag(other_slot):
			continue

		var half_distance: float = slot_center.distance_to(_get_control_center(other_slot)) * 0.5
		radius = minf(radius, maxf(0.0, half_distance - CANNON_SLOT_MAGNET_GAP))

	return radius

func _load_texture(path: String) -> Texture2D:
	var texture: Resource = texture_cache.get(path)
	if texture == null:
		texture = load(path)
		if texture is Texture2D:
			texture_cache[path] = texture
	return texture as Texture2D
