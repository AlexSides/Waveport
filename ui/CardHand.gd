extends Control

const MAX_FAN_ROTATION_DEGREES: float = 4.0
const EDGE_DROP: float = 32.0
const MAX_CARD_SPACING: float = 310.0
const MIN_CARD_SPACING: float = 72.0
const BOTTOM_PADDING: float = 26.0

var _layout_requested: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	request_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_CHILD_ORDER_CHANGED:
		request_layout()

func request_layout() -> void:
	if _layout_requested:
		return

	_layout_requested = true
	call_deferred("_layout_cards")

func bring_card_to_front(card: Control) -> void:
	if card == null or card.get_parent() != self:
		return

	card.z_index = 1000

func _layout_cards() -> void:
	_layout_requested = false

	var cards: Array[Control] = _get_cards()
	var card_count: int = cards.size()
	if card_count == 0:
		return

	var card_size: Vector2 = _get_card_size(cards[0])
	var spacing: float = _get_card_spacing(card_count, card_size.x)
	var half_index: float = float(card_count - 1) * 0.5
	var center_x: float = size.x * 0.5
	var bottom_y: float = size.y - BOTTOM_PADDING

	for index in range(card_count):
		var card: Control = cards[index]
		var index_offset: float = float(index) - half_index
		var normalized: float = 0.0
		if half_index > 0.0:
			normalized = index_offset / half_index

		var base_center: Vector2 = Vector2(
			center_x + index_offset * spacing,
			bottom_y - card_size.y * 0.5 + absf(normalized) * EDGE_DROP
		)
		var base_position: Vector2 = base_center - card_size * 0.5
		var base_rotation: float = deg_to_rad(normalized * MAX_FAN_ROTATION_DEGREES)

		card.anchor_left = 0.0
		card.anchor_top = 0.0
		card.anchor_right = 0.0
		card.anchor_bottom = 0.0
		card.size = card_size
		card.pivot_offset = card_size * 0.5

		if card.has_method("set_hand_base_transform"):
			card.call("set_hand_base_transform", base_position, base_rotation, Vector2.ONE, index, true)
		else:
			card.position = base_position
			card.rotation = base_rotation
			card.scale = Vector2.ONE
			card.z_index = index

func _get_cards() -> Array[Control]:
	var cards: Array[Control] = []
	for child in get_children():
		if child is Control:
			cards.append(child)
	return cards

func _get_card_size(card: Control) -> Vector2:
	var card_size: Vector2 = card.get_combined_minimum_size()
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = card.size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = Vector2(400, 600)
	return card_size

func _get_card_spacing(card_count: int, card_width: float) -> float:
	if card_count <= 1:
		return 0.0

	var available_spacing: float = (size.x - card_width) / float(card_count - 1)
	return maxf(MIN_CARD_SPACING, minf(available_spacing, MAX_CARD_SPACING))
