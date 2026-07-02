extends Control

const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const DESTINATION_RATIOS := [Vector2(0.61, 0.33), Vector2(0.78, 0.58)]
const SHIP_START_RATIO := Vector2(0.26, 0.68)
const DESIGN_CANVAS_SIZE := Vector2(3840.0, 2160.0)
const SHIP_ROUTE_SPEED := 560.0
const SHIP_MIN_TRAVEL_DURATION := 2.55
const SHIP_MAX_TRAVEL_DURATION := 5.2
const MAP_FADE_DURATION := 0.45
const INK_SPLASH_DURATION := 1.6
const DESTINATION_CIRCLE_LEAD_TIME := 0.22
const ROUTE_STYLE_WAVY := 0
const ROUTE_STYLE_ZIGZAG := 1
const ROUTE_STYLE_LOOP := 2
const ROUTE_STYLE_STAIRCASE := 3

@onready var title_label: Label = $TitleLabel
@onready var summary_label: Label = $SummaryLabel
@onready var progress_label: Label = $ProgressLabel
@onready var status_label: Label = $StatusLabel
@onready var shipyard_button: Button = $InspectShipButton
@onready var destination_marker_a: Button = $DestinationMarkerA
@onready var destination_marker_b: Button = $DestinationMarkerB
@onready var ship_preview: Control = $ShipPreview
@onready var fade_overlay: ColorRect = $FadeOverlay

var save_state: Dictionary = {}
var battle_state: Dictionary = {}
var selected_destination_index: int = -1
var hovered_destination_index: int = -1
var destination_locked: bool = false
var marker_size: Vector2 = Vector2(108.0, 108.0)
var route_points: PackedVector2Array = PackedVector2Array()
var route_length: float = 0.0
var route_random_seed: int = 0
var route_style: int = ROUTE_STYLE_WAVY
var ship_rotation: float = 0.0
var ripple_destination_index: int = -1
var ink_splash_tween: Tween = null

var hover_ripple_progress: float = 0.0:
	set(value):
		hover_ripple_progress = wrapf(value, 0.0, 1.0)
		queue_redraw()

var hover_ripple_alpha: float = 0.0:
	set(value):
		hover_ripple_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()

var ink_splash_progress: float = 0.0:
	set(value):
		ink_splash_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

var ink_splash_alpha: float = 0.0:
	set(value):
		ink_splash_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()

var route_reveal: float = 0.0:
	set(value):
		route_reveal = clampf(value, 0.0, 1.0)
		queue_redraw()

var selection_alpha: float = 0.0:
	set(value):
		selection_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()

var ship_travel: float = 0.0:
	set(value):
		var previous_ship_travel: float = ship_travel
		ship_travel = clampf(value, 0.0, 1.0)
		_update_ship_rotation(previous_ship_travel)
		queue_redraw()

var fade_alpha: float = 0.0:
	set(value):
		fade_alpha = clampf(value, 0.0, 1.0)
		_update_fade_overlay()

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

	_style_map_ui()
	shipyard_button.pressed.connect(_on_shipyard_pressed)
	destination_marker_a.pressed.connect(_on_destination_pressed.bind(0))
	destination_marker_b.pressed.connect(_on_destination_pressed.bind(1))
	destination_marker_a.mouse_entered.connect(_on_destination_hovered.bind(0))
	destination_marker_b.mouse_entered.connect(_on_destination_hovered.bind(1))
	destination_marker_a.mouse_exited.connect(_on_destination_unhovered.bind(0))
	destination_marker_b.mouse_exited.connect(_on_destination_unhovered.bind(1))

	_refresh_ui()
	_layout_map_ui()
	_update_fade_overlay()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		if ship_preview and ship_preview.has_method("toggle_preview"):
			ship_preview.toggle_preview()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and title_label != null:
		_layout_map_ui()
		queue_redraw()

func _process(delta: float) -> void:
	if hovered_destination_index >= 0 and ripple_destination_index >= 0 and not destination_locked:
		hover_ripple_progress = hover_ripple_progress + delta * 0.72
		hover_ripple_alpha = move_toward(hover_ripple_alpha, 1.0, delta * 4.0)
	elif hover_ripple_alpha > 0.0:
		hover_ripple_alpha = move_toward(hover_ripple_alpha, 0.0, delta * 5.0)
		if hover_ripple_alpha <= 0.0:
			ripple_destination_index = -1

func _draw() -> void:
	var map_rect: Rect2 = _get_map_rect()
	_draw_table_background()
	_draw_parchment(map_rect)
	_draw_map_ink(map_rect)

	if ripple_destination_index >= 0 and hover_ripple_alpha > 0.0:
		_draw_hover_ripple(_get_destination_center(ripple_destination_index))

	if selected_destination_index >= 0:
		var destination: Vector2 = _get_destination_center(selected_destination_index)
		_draw_ink_splash(destination)
		_draw_dashed_route(route_reveal)
		_draw_selected_destination(destination)

	_draw_ship_marker(_get_current_ship_position(), ship_rotation)

func _refresh_ui() -> void:
	var cargo_text: String = "Cargo %d/%d" % [PlayerData.get_cargo_count(), PlayerData.get_cargo_capacity()]
	var hull_text: String = "Hull %d/%d" % [PlayerData.current_health, PlayerData.current_max_health]
	var gold_text: String = "Gold %d" % PlayerData.gold
	var voyage_text: String = _get_next_voyage_progress_text()

	title_label.text = "Chart Your Course"
	summary_label.text = "%s | %s | %s | %s | %s" % [
		PlayerData.get_ship_name(),
		hull_text,
		gold_text,
		cargo_text,
		voyage_text
	]
	progress_label.text = _get_voyage_progress_label_text()
	status_label.text = _get_default_status_text()

func _get_remaining_battle_count() -> int:
	return Array(battle_state.get("remaining_encounters", [])).size()

func _get_next_voyage_progress_text() -> String:
	var remaining_encounters: Array = Array(battle_state.get("remaining_encounters", []))
	if remaining_encounters.is_empty():
		return "Voyage Complete"

	var next_encounter: Dictionary = Dictionary(remaining_encounters.front())
	var battle_number: int = int(next_encounter.get("battle_number", 0))
	var total_battles: int = int(next_encounter.get("total_battles", 0))
	var route_name: String = String(next_encounter.get("route_name", "Voyage"))
	var route_index: int = int(next_encounter.get("route_index", 0))
	var route_total: int = int(next_encounter.get("route_total", 0))

	if battle_number <= 0 or total_battles <= 0:
		return "Battles Ahead %d" % remaining_encounters.size()

	return "%s %d/%d | Voyage %d/%d" % [
		route_name,
		route_index,
		route_total,
		battle_number,
		total_battles
	]

func _get_voyage_progress_label_text() -> String:
	var remaining_encounters: Array = Array(battle_state.get("remaining_encounters", []))
	if remaining_encounters.is_empty():
		return "Voyage Complete"

	var next_encounter: Dictionary = Dictionary(remaining_encounters.front())
	var battle_number: int = int(next_encounter.get("battle_number", 0))
	var total_battles: int = int(next_encounter.get("total_battles", 0))
	var route_name: String = String(next_encounter.get("route_name", "Voyage"))
	var route_index: int = int(next_encounter.get("route_index", 0))
	var route_total: int = int(next_encounter.get("route_total", 0))

	if battle_number <= 0 or total_battles <= 0:
		return "Battles Ahead: %d" % remaining_encounters.size()

	return "%s: %d / %d\nVoyage: %d / %d" % [
		route_name,
		route_index,
		route_total,
		battle_number,
		total_battles
	]

func _on_shipyard_pressed() -> void:
	if destination_locked:
		return

	if ship_preview and ship_preview.has_method("open_preview"):
		ship_preview.open_preview()
		status_label.text = "Shipyard open. Install or remove modules, then close it with Tab or Esc."

func _on_destination_hovered(index: int) -> void:
	if destination_locked:
		return

	hovered_destination_index = index
	ripple_destination_index = index
	status_label.text = "Unknown Waters"

func _on_destination_unhovered(index: int) -> void:
	if hovered_destination_index != index or destination_locked:
		return

	hovered_destination_index = -1
	status_label.text = _get_default_status_text()

func _on_destination_pressed(index: int) -> void:
	if destination_locked:
		return

	destination_locked = true
	selected_destination_index = index
	hovered_destination_index = -1
	ripple_destination_index = -1
	hover_ripple_alpha = 0.0
	route_random_seed = _make_route_seed()
	route_style = _choose_route_style()
	route_points = _build_route_points(_get_ship_start_position(), _get_destination_center(index))
	route_length = _measure_route_length(route_points)
	route_reveal = 0.0
	selection_alpha = 0.0
	ship_travel = 0.0
	_play_ink_splash()
	status_label.text = "Course charted. Sailing into unknown waters..."
	shipyard_button.disabled = true
	_set_destination_buttons_enabled(false)
	_update_destination_styles()
	queue_redraw()
	_play_course_animation()

func _make_route_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()

func _choose_route_style() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = route_random_seed
	return rng.randi_range(ROUTE_STYLE_WAVY, ROUTE_STYLE_STAIRCASE)

func _play_ink_splash() -> void:
	if ink_splash_tween != null:
		ink_splash_tween.kill()

	ink_splash_progress = 0.0
	ink_splash_alpha = 1.0
	ink_splash_tween = create_tween()
	ink_splash_tween.set_trans(Tween.TRANS_SINE)
	ink_splash_tween.set_ease(Tween.EASE_OUT)
	ink_splash_tween.tween_property(self, "ink_splash_progress", 1.0, INK_SPLASH_DURATION)
	ink_splash_tween.parallel().tween_property(self, "ink_splash_alpha", 0.0, INK_SPLASH_DURATION)

func _play_course_animation() -> void:
	var travel_duration: float = _get_ship_travel_duration()
	var circle_tween: Tween = create_tween()
	circle_tween.set_trans(Tween.TRANS_SINE)
	circle_tween.set_ease(Tween.EASE_OUT)
	circle_tween.tween_interval(maxf(travel_duration - DESTINATION_CIRCLE_LEAD_TIME, 0.0))
	circle_tween.tween_property(self, "selection_alpha", 1.0, 0.28)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "route_reveal", 1.0, travel_duration)
	tween.parallel().tween_property(self, "ship_travel", 1.0, travel_duration)
	tween.tween_interval(0.22)
	tween.tween_property(self, "fade_alpha", 1.0, MAP_FADE_DURATION)
	tween.tween_callback(Callable(self, "_on_sail_pressed"))

func _get_ship_travel_duration() -> float:
	if route_length <= 0.0:
		return SHIP_MIN_TRAVEL_DURATION

	return clampf(route_length / SHIP_ROUTE_SPEED, SHIP_MIN_TRAVEL_DURATION, SHIP_MAX_TRAVEL_DURATION)

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

func _style_map_ui() -> void:
	var ink_color := Color(0.16, 0.09, 0.035, 1.0)
	var faded_ink := Color(0.24, 0.13, 0.055, 0.92)

	for label in [title_label, summary_label, progress_label, status_label]:
		label.add_theme_color_override("font_color", ink_color)
		label.add_theme_color_override("font_outline_color", Color(0.88, 0.70, 0.42, 0.5))
		label.add_theme_constant_override("outline_size", 3)

	title_label.add_theme_font_size_override("font_size", 64)
	summary_label.add_theme_font_size_override("font_size", 26)
	progress_label.add_theme_font_size_override("font_size", 36)
	status_label.add_theme_font_size_override("font_size", 30)

	shipyard_button.text = "Inspect Ship"
	shipyard_button.add_theme_font_size_override("font_size", 30)
	shipyard_button.add_theme_color_override("font_color", ink_color)
	shipyard_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.86, 0.64, 0.34, 0.95), ink_color, 8, 3))
	shipyard_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.95, 0.73, 0.42, 0.98), ink_color, 8, 4))
	shipyard_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.76, 0.48, 0.22, 0.98), ink_color, 8, 4))
	shipyard_button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.58, 0.43, 0.27, 0.55), faded_ink, 8, 3))

	for marker in _get_destination_buttons():
		marker.text = "?"
		marker.tooltip_text = "Unknown Waters"
		marker.focus_mode = Control.FOCUS_NONE
		marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		marker.add_theme_font_size_override("font_size", 56)
		marker.add_theme_color_override("font_color", ink_color)
		marker.add_theme_color_override("font_hover_color", Color(0.28, 0.12, 0.045, 1.0))
		marker.add_theme_stylebox_override("normal", _make_marker_style(Color(0.91, 0.72, 0.42, 0.85), ink_color, 3))
		marker.add_theme_stylebox_override("hover", _make_marker_style(Color(0.98, 0.82, 0.50, 0.95), Color(0.34, 0.12, 0.04, 1.0), 5))
		marker.add_theme_stylebox_override("pressed", _make_marker_style(Color(0.80, 0.52, 0.25, 0.96), ink_color, 5))
		marker.add_theme_stylebox_override("disabled", _make_marker_style(Color(0.73, 0.57, 0.35, 0.55), faded_ink, 3))

func _make_button_style(bg_color: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.08, 0.035, 0.015, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	return style

func _make_marker_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := _make_button_style(bg_color, border_color, 48, border_width)
	style.shadow_size = 5
	return style

func _layout_map_ui() -> void:
	var map_rect: Rect2 = _get_map_rect()
	marker_size = Vector2.ONE * clampf(map_rect.size.y * 0.062, 84.0, 116.0)

	title_label.position = map_rect.position + Vector2(0.0, 48.0)
	title_label.size = Vector2(map_rect.size.x, 84.0)

	summary_label.position = map_rect.position + Vector2(map_rect.size.x * 0.14, 138.0)
	summary_label.size = Vector2(map_rect.size.x * 0.72, 48.0)

	progress_label.position = map_rect.position + Vector2(map_rect.size.x * 0.065, map_rect.size.y * 0.18)
	progress_label.size = Vector2(map_rect.size.x * 0.34, 110.0)

	status_label.position = map_rect.position + Vector2(map_rect.size.x * 0.16, map_rect.size.y - 138.0)
	status_label.size = Vector2(map_rect.size.x * 0.68, 80.0)

	var inspect_size := Vector2(clampf(map_rect.size.x * 0.14, 280.0, 360.0), 76.0)
	shipyard_button.size = inspect_size
	shipyard_button.position = map_rect.position + Vector2(map_rect.size.x - inspect_size.x - 96.0, 76.0)

	for index in range(_get_destination_buttons().size()):
		var marker: Button = _get_destination_buttons()[index]
		marker.size = marker_size
		marker.position = _get_destination_position(index) - marker_size * 0.5

	if selected_destination_index >= 0:
		route_points = _build_route_points(_get_ship_start_position(), _get_destination_center(selected_destination_index))
		route_length = _measure_route_length(route_points)

func _get_destination_buttons() -> Array:
	return [destination_marker_a, destination_marker_b]

func _get_default_status_text() -> String:
	if _get_remaining_battle_count() <= 0:
		return "The voyage is complete. Mark the final course to make port."
	return "Select unknown waters to continue, or inspect the ship before sailing."

func _set_destination_buttons_enabled(enabled: bool) -> void:
	for marker in _get_destination_buttons():
		marker.disabled = not enabled
		marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW

func _update_destination_styles() -> void:
	var ink_color := Color(0.16, 0.09, 0.035, 1.0)
	var selected_color := Color(0.92, 0.60, 0.28, 0.96)

	for index in range(_get_destination_buttons().size()):
		var marker: Button = _get_destination_buttons()[index]
		if index == selected_destination_index:
			marker.add_theme_stylebox_override("disabled", _make_marker_style(selected_color, Color(0.40, 0.07, 0.025, 1.0), 6))
			marker.add_theme_color_override("font_disabled_color", ink_color)
		else:
			marker.add_theme_stylebox_override("disabled", _make_marker_style(Color(0.66, 0.52, 0.34, 0.42), Color(0.24, 0.13, 0.055, 0.6), 3))
			marker.add_theme_color_override("font_disabled_color", Color(0.24, 0.13, 0.055, 0.6))

func _update_fade_overlay() -> void:
	if fade_overlay == null:
		return

	fade_overlay.color = Color(0.035, 0.019, 0.011, fade_alpha)

func _get_map_rect() -> Rect2:
	var screen_size: Vector2 = size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		screen_size = DESIGN_CANVAS_SIZE

	var margin_x: float = clampf(screen_size.x * 0.068, 80.0, 260.0)
	var margin_y: float = clampf(screen_size.y * 0.065, 60.0, 150.0)
	return Rect2(Vector2(margin_x, margin_y), screen_size - Vector2(margin_x * 2.0, margin_y * 2.0))

func _get_destination_position(index: int) -> Vector2:
	var map_rect: Rect2 = _get_map_rect()
	var ratio: Vector2 = DESTINATION_RATIOS[index]
	return map_rect.position + Vector2(map_rect.size.x * ratio.x, map_rect.size.y * ratio.y)

func _get_destination_center(index: int) -> Vector2:
	var buttons: Array = _get_destination_buttons()
	if index >= 0 and index < buttons.size() and buttons[index] != null:
		return buttons[index].position + buttons[index].size * 0.5
	return _get_destination_position(index)

func _get_ship_start_position() -> Vector2:
	var map_rect: Rect2 = _get_map_rect()
	return map_rect.position + Vector2(map_rect.size.x * SHIP_START_RATIO.x, map_rect.size.y * SHIP_START_RATIO.y)

func _get_current_ship_position() -> Vector2:
	if selected_destination_index < 0 or route_points.size() < 2:
		return _get_ship_start_position()

	return _get_route_point_at_progress(ship_travel)

func _get_current_ship_rotation() -> float:
	if selected_destination_index < 0 or route_points.size() < 2:
		return 0.0

	var current: Vector2 = _get_route_point_at_progress(ship_travel)
	var next: Vector2 = _get_route_point_at_progress(ship_travel + 0.035)
	var direction: Vector2 = next - current
	if direction.length_squared() <= 0.01:
		current = _get_route_point_at_progress(ship_travel - 0.035)
		next = _get_route_point_at_progress(ship_travel)
		direction = next - current
	if direction.length_squared() <= 0.01:
		return 0.0

	return direction.angle()

func _update_ship_rotation(previous_ship_travel: float) -> void:
	if selected_destination_index < 0 or route_points.size() < 2:
		ship_rotation = 0.0
		return

	var target_rotation: float = _get_current_ship_rotation()
	if ship_travel <= 0.001 or absf(ship_travel - previous_ship_travel) <= 0.001:
		ship_rotation = target_rotation
		return

	ship_rotation = lerp_angle(ship_rotation, target_rotation, 0.24)

func _build_route_points(start: Vector2, destination: Vector2) -> PackedVector2Array:
	var route: PackedVector2Array = _build_horizontal_launch_points(start, destination)
	var route_start: Vector2 = start
	if route.size() > 0:
		route_start = route[route.size() - 1]

	var route_after_launch := PackedVector2Array()
	match route_style:
		ROUTE_STYLE_ZIGZAG:
			route_after_launch = _build_zigzag_route_points(route_start, destination)
		ROUTE_STYLE_LOOP:
			route_after_launch = _build_loop_route_points(route_start, destination)
		ROUTE_STYLE_STAIRCASE:
			route_after_launch = _build_staircase_route_points(route_start, destination)
		_:
			route_after_launch = _build_winding_route_points(route_start, destination)

	return _append_route_points(route, route_after_launch, true)

func _build_horizontal_launch_points(start: Vector2, destination: Vector2) -> PackedVector2Array:
	var route := PackedVector2Array()
	route.append(start)

	var horizontal_delta: float = destination.x - start.x
	if absf(horizontal_delta) <= 16.0:
		return route

	var horizontal_sign: float = signf(horizontal_delta)
	var direct_distance: float = start.distance_to(destination)
	var launch_length: float = clampf(direct_distance * 0.075, 64.0, 128.0)
	launch_length = minf(launch_length, minf(absf(horizontal_delta) * 0.42, direct_distance * 0.22))
	if launch_length <= 12.0:
		return route

	var bounds: Rect2 = _get_map_rect().grow(-80.0)
	var launch_end: Vector2 = _clamp_point_to_rect(start + Vector2(horizontal_sign * launch_length, 0.0), bounds)
	if launch_end.distance_to(start) <= 4.0:
		return route

	var launch_line := PackedVector2Array()
	launch_line.append(start)
	launch_line.append(launch_end)
	return _sample_polyline_anchors(launch_line, 8)

func _build_winding_route_points(start: Vector2, destination: Vector2) -> PackedVector2Array:
	var direction: Vector2 = destination - start
	var distance: float = direction.length()
	if distance <= 1.0:
		var short_route := PackedVector2Array()
		short_route.append(start)
		short_route.append(destination)
		return short_route

	var forward: Vector2 = direction / distance
	var perpendicular := Vector2(-forward.y, forward.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = route_random_seed
	var route_side: float = 1.0 if rng.randf() >= 0.5 else -1.0
	var bend: float = clampf(distance * 0.13, 72.0, 180.0)
	var bounds: Rect2 = _get_map_rect().grow(-80.0)
	var anchors := PackedVector2Array()
	anchors.append(start)
	anchors.append(_clamp_point_to_rect(
		start.lerp(destination, rng.randf_range(0.12, 0.18)) + perpendicular * bend * route_side * rng.randf_range(0.06, 0.16),
		bounds
	))
	anchors.append(_clamp_point_to_rect(
		start.lerp(destination, rng.randf_range(0.30, 0.39)) + perpendicular * bend * route_side * rng.randf_range(0.62, 0.92),
		bounds
	))
	anchors.append(_clamp_point_to_rect(
		start.lerp(destination, rng.randf_range(0.42, 0.53)) - perpendicular * bend * route_side * rng.randf_range(0.42, 0.78) + forward * rng.randf_range(-20.0, 32.0),
		bounds
	))
	anchors.append(_clamp_point_to_rect(
		start.lerp(destination, rng.randf_range(0.68, 0.79)) + perpendicular * bend * route_side * rng.randf_range(0.30, 0.70),
		bounds
	))
	anchors.append(destination)

	return _sample_route_anchors(anchors)

func _build_zigzag_route_points(start: Vector2, destination: Vector2) -> PackedVector2Array:
	var direction: Vector2 = destination - start
	var distance: float = direction.length()
	if distance <= 1.0:
		var short_route := PackedVector2Array()
		short_route.append(start)
		short_route.append(destination)
		return short_route

	var forward: Vector2 = direction / distance
	var perpendicular := Vector2(-forward.y, forward.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = route_random_seed + 1009
	var route_side: float = 1.0 if rng.randf() >= 0.5 else -1.0
	var bend: float = clampf(distance * rng.randf_range(0.075, 0.105), 48.0, 126.0)
	var bounds: Rect2 = _get_map_rect().grow(-80.0)
	var anchors := PackedVector2Array()
	anchors.append(start)

	for zig_index in range(5):
		var base_t: float = (float(zig_index) + 1.0) / 6.0
		var route_t: float = clampf(base_t + rng.randf_range(-0.022, 0.022), 0.10, 0.90)
		var side: float = route_side if zig_index % 2 == 0 else -route_side
		var taper: float = 0.64 + sin(route_t * PI) * 0.36
		anchors.append(_clamp_point_to_rect(
			start.lerp(destination, route_t) + perpendicular * bend * side * taper,
			bounds
		))

	anchors.append(destination)
	return _sample_polyline_anchors(anchors, 10)

func _build_staircase_route_points(start: Vector2, destination: Vector2) -> PackedVector2Array:
	var horizontal_delta: float = destination.x - start.x
	var vertical_delta: float = destination.y - start.y
	if absf(horizontal_delta) <= 1.0 or absf(vertical_delta) <= 1.0:
		var short_route := PackedVector2Array()
		short_route.append(start)
		short_route.append(destination)
		return _sample_polyline_anchors(short_route, 12)

	var rng := RandomNumberGenerator.new()
	rng.seed = route_random_seed + 3023
	var stair_count: int = rng.randi_range(1, 5)
	var horizontal_splits: Array = _make_random_axis_splits(horizontal_delta, stair_count + 1, rng)
	var vertical_splits: Array = _make_random_axis_splits(vertical_delta, stair_count, rng)
	var bounds: Rect2 = _get_map_rect().grow(-80.0)
	var anchors := PackedVector2Array()
	var current: Vector2 = start
	anchors.append(current)

	for stair_index in range(stair_count):
		current = Vector2(current.x + float(horizontal_splits[stair_index]), current.y)
		anchors.append(_clamp_point_to_rect(current, bounds))
		current = Vector2(current.x, current.y + float(vertical_splits[stair_index]))
		anchors.append(_clamp_point_to_rect(current, bounds))

	current = Vector2(destination.x, current.y)
	var final_corner: Vector2 = _clamp_point_to_rect(current, bounds)
	anchors.append(final_corner)
	if final_corner.distance_to(destination) > 0.5:
		anchors.append(destination)
	return _sample_polyline_anchors(anchors, 12)

func _build_loop_route_points(start: Vector2, destination: Vector2) -> PackedVector2Array:
	var direction: Vector2 = destination - start
	var distance: float = direction.length()
	if distance <= 1.0:
		var short_route := PackedVector2Array()
		short_route.append(start)
		short_route.append(destination)
		return short_route

	var forward: Vector2 = direction / distance
	var perpendicular := Vector2(-forward.y, forward.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = route_random_seed + 2017
	var route_side: float = 1.0 if rng.randf() >= 0.5 else -1.0
	var loop_side: float = route_side if rng.randf() >= 0.35 else -route_side
	var wave_amplitude: float = clampf(distance * rng.randf_range(0.045, 0.085), 42.0, 136.0)
	var wave_frequency_a: float = rng.randf_range(0.82, 1.22)
	var wave_frequency_b: float = rng.randf_range(1.65, 2.25)
	var wave_phase_a: float = rng.randf_range(0.0, TAU)
	var wave_phase_b: float = rng.randf_range(0.0, TAU)
	var loop_start_t: float = rng.randf_range(0.34, 0.48)
	var loop_duration: float = rng.randf_range(0.22, 0.38)
	loop_duration = minf(loop_duration, 0.88 - loop_start_t)
	var loop_end_t: float = loop_start_t + loop_duration
	var loop_span: float = distance * loop_duration
	var loop_push: float = loop_span * rng.randf_range(0.42, 0.68)
	var loop_height: float = clampf(distance * rng.randf_range(0.058, 0.132), 64.0, 210.0)
	var loop_wobble_phase_a: float = rng.randf_range(0.0, TAU)
	var loop_wobble_phase_b: float = rng.randf_range(0.0, TAU)
	var bounds: Rect2 = _get_map_rect().grow(-80.0)
	var route := PackedVector2Array()
	var sample_count: int = 116
	for sample_index in range(sample_count + 1):
		var t: float = float(sample_index) / float(sample_count)
		var path_x: float = distance * t
		var path_gate: float = pow(sin(t * PI), 2.0)
		var path_y: float = route_side * wave_amplitude * path_gate * (
			sin(t * TAU * wave_frequency_a + wave_phase_a) * 0.62
			+ sin(t * TAU * wave_frequency_b + wave_phase_b) * 0.24
		)

		if t >= loop_start_t and t <= loop_end_t:
			var loop_t: float = (t - loop_start_t) / loop_duration
			var loop_gate: float = pow(sin(loop_t * PI), 2.0)
			path_x += loop_push * sin(loop_t * TAU)
			path_x += loop_span * loop_gate * sin(loop_t * TAU * 3.0 + loop_wobble_phase_a) * 0.025
			path_y += loop_side * loop_height * (1.0 - cos(loop_t * TAU))
			path_y += loop_side * loop_height * loop_gate * sin(loop_t * TAU * 2.0 + loop_wobble_phase_b) * 0.11

		route.append(_clamp_point_to_rect(start + forward * path_x + perpendicular * path_y, bounds))

	return route

func _make_random_axis_splits(total: float, piece_count: int, rng: RandomNumberGenerator) -> Array:
	var splits: Array = []
	if piece_count <= 0:
		return splits

	var weights: Array = []
	var total_weight: float = 0.0
	for split_index in range(piece_count):
		var weight: float = rng.randf_range(0.68, 1.38)
		weights.append(weight)
		total_weight += weight

	var used_total: float = 0.0
	for split_index in range(piece_count):
		var split: float = total - used_total
		if split_index < piece_count - 1:
			split = total * float(weights[split_index]) / total_weight
			used_total += split
		splits.append(split)

	return splits

func _sample_route_anchors(anchors: PackedVector2Array) -> PackedVector2Array:
	var sampled_points := PackedVector2Array()
	if anchors.size() < 2:
		return anchors

	var samples_per_segment: int = 18
	for segment_index in range(anchors.size() - 1):
		var p0: Vector2 = anchors[maxi(segment_index - 1, 0)]
		var p1: Vector2 = anchors[segment_index]
		var p2: Vector2 = anchors[segment_index + 1]
		var p3: Vector2 = anchors[mini(segment_index + 2, anchors.size() - 1)]

		for sample_index in range(samples_per_segment):
			var t: float = float(sample_index) / float(samples_per_segment)
			sampled_points.append(_catmull_rom_point(p0, p1, p2, p3, t))

	sampled_points.append(anchors[anchors.size() - 1])
	return sampled_points

func _sample_polyline_anchors(anchors: PackedVector2Array, samples_per_segment: int) -> PackedVector2Array:
	var sampled_points := PackedVector2Array()
	if anchors.size() < 2:
		return anchors

	for segment_index in range(anchors.size() - 1):
		var segment_start: Vector2 = anchors[segment_index]
		var segment_end: Vector2 = anchors[segment_index + 1]
		for sample_index in range(samples_per_segment):
			var t: float = float(sample_index) / float(samples_per_segment)
			sampled_points.append(segment_start.lerp(segment_end, t))

	sampled_points.append(anchors[anchors.size() - 1])
	return sampled_points

func _sample_cubic_route(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, samples: int) -> PackedVector2Array:
	var sampled_points := PackedVector2Array()
	for sample_index in range(samples + 1):
		var t: float = float(sample_index) / float(samples)
		var inverse_t: float = 1.0 - t
		sampled_points.append(
			p0 * inverse_t * inverse_t * inverse_t
			+ p1 * 3.0 * inverse_t * inverse_t * t
			+ p2 * 3.0 * inverse_t * t * t
			+ p3 * t * t * t
		)
	return sampled_points

func _append_route_points(target: PackedVector2Array, points: PackedVector2Array, skip_first: bool) -> PackedVector2Array:
	var route := target
	var start_index: int = 1 if skip_first else 0
	for point_index in range(start_index, points.size()):
		route.append(points[point_index])
	return route

func _catmull_rom_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	var a: Vector2 = p1 * 2.0
	var b: Vector2 = (p2 - p0) * t
	var c: Vector2 = (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2
	var d: Vector2 = ((Vector2.ZERO - p0) + p1 * 3.0 - p2 * 3.0 + p3) * t3
	return (a + b + c + d) * 0.5

func _clamp_point_to_rect(point: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, rect.position.x, rect.position.x + rect.size.x),
		clampf(point.y, rect.position.y, rect.position.y + rect.size.y)
	)

func _measure_route_length(points: PackedVector2Array) -> float:
	var length: float = 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return length

func _get_route_point_at_progress(progress: float) -> Vector2:
	return _get_route_point_at_distance(route_length * clampf(progress, 0.0, 1.0))

func _get_route_point_at_distance(target_distance: float) -> Vector2:
	if route_points.size() < 2 or route_length <= 0.0:
		return _get_ship_start_position()

	var remaining_distance: float = clampf(target_distance, 0.0, route_length)
	for index in range(1, route_points.size()):
		var previous: Vector2 = route_points[index - 1]
		var current: Vector2 = route_points[index]
		var segment_length: float = previous.distance_to(current)
		if segment_length <= 0.0:
			continue
		if remaining_distance <= segment_length:
			return previous.lerp(current, remaining_distance / segment_length)
		remaining_distance -= segment_length

	return route_points[route_points.size() - 1]

func _draw_table_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.030, 0.020, 1.0), true)
	for index in range(8):
		var y: float = size.y * float(index) / 8.0
		draw_line(Vector2(0.0, y), Vector2(size.x, y + 32.0), Color(0.11, 0.065, 0.035, 0.28), 3.0)

func _draw_parchment(rect: Rect2) -> void:
	var points: PackedVector2Array = _get_parchment_points(rect)
	var shadow_points: PackedVector2Array = _offset_points(points, Vector2(18.0, 20.0))
	draw_colored_polygon(shadow_points, Color(0.02, 0.012, 0.006, 0.36))
	draw_colored_polygon(points, Color(0.80, 0.58, 0.31, 1.0))

	_draw_parchment_stain(rect, Vector2(0.30, 0.36), 0.12, Color(0.94, 0.76, 0.45, 0.18))
	_draw_parchment_stain(rect, Vector2(0.58, 0.56), 0.17, Color(0.35, 0.17, 0.06, 0.10))
	_draw_parchment_stain(rect, Vector2(0.77, 0.23), 0.09, Color(0.95, 0.78, 0.47, 0.16))
	_draw_parchment_stain(rect, Vector2(0.42, 0.78), 0.11, Color(0.20, 0.10, 0.04, 0.08))

	draw_rect(rect.grow(-42.0), Color(0.94, 0.74, 0.42, 0.14), false, 3.0)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.42, 0.20, 0.07, 0.70), 10.0, true)
	draw_polyline(outline, Color(0.18, 0.09, 0.035, 0.82), 3.0, true)

	var fold_color := Color(0.24, 0.12, 0.045, 0.13)
	draw_line(rect.position + Vector2(rect.size.x * 0.48, rect.size.y * 0.08), rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.90), fold_color, 3.0)
	draw_line(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.52), rect.position + Vector2(rect.size.x * 0.88, rect.size.y * 0.48), fold_color, 2.0)

func _get_parchment_points(rect: Rect2) -> PackedVector2Array:
	var ratios := [
		Vector2(0.03, 0.05), Vector2(0.10, 0.02), Vector2(0.21, 0.035), Vector2(0.32, 0.01),
		Vector2(0.45, 0.03), Vector2(0.56, 0.00), Vector2(0.69, 0.025), Vector2(0.82, 0.015),
		Vector2(0.96, 0.05), Vector2(0.985, 0.17), Vector2(0.97, 0.31), Vector2(0.99, 0.46),
		Vector2(0.965, 0.62), Vector2(0.985, 0.78), Vector2(0.95, 0.94), Vector2(0.84, 0.985),
		Vector2(0.70, 0.965), Vector2(0.58, 0.995), Vector2(0.45, 0.975), Vector2(0.31, 0.99),
		Vector2(0.18, 0.965), Vector2(0.06, 0.975), Vector2(0.015, 0.86), Vector2(0.035, 0.72),
		Vector2(0.01, 0.57), Vector2(0.03, 0.43), Vector2(0.015, 0.28), Vector2(0.04, 0.15)
	]
	var points := PackedVector2Array()
	for ratio in ratios:
		points.append(rect.position + Vector2(rect.size.x * ratio.x, rect.size.y * ratio.y))
	return points

func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var offset_points := PackedVector2Array()
	for point in points:
		offset_points.append(point + offset)
	return offset_points

func _draw_parchment_stain(rect: Rect2, ratio: Vector2, radius_ratio: float, color: Color) -> void:
	draw_circle(rect.position + Vector2(rect.size.x * ratio.x, rect.size.y * ratio.y), rect.size.y * radius_ratio, color)

func _draw_map_ink(rect: Rect2) -> void:
	var ink := Color(0.14, 0.075, 0.030, 0.76)
	_draw_island(rect, [
		Vector2(0.09, 0.27), Vector2(0.17, 0.22), Vector2(0.25, 0.30), Vector2(0.24, 0.42),
		Vector2(0.15, 0.46), Vector2(0.08, 0.40)
	], ink)
	_draw_island(rect, [
		Vector2(0.72, 0.70), Vector2(0.82, 0.65), Vector2(0.91, 0.72), Vector2(0.88, 0.87),
		Vector2(0.76, 0.89), Vector2(0.68, 0.80)
	], ink)
	_draw_island(rect, [
		Vector2(0.82, 0.20), Vector2(0.89, 0.23), Vector2(0.91, 0.34), Vector2(0.85, 0.42),
		Vector2(0.77, 0.37), Vector2(0.76, 0.26)
	], Color(0.14, 0.075, 0.030, 0.55))

	_draw_waves(rect, Vector2(0.24, 0.18), ink)
	_draw_waves(rect, Vector2(0.43, 0.25), ink)
	_draw_waves(rect, Vector2(0.21, 0.57), ink)
	_draw_waves(rect, Vector2(0.58, 0.76), ink)
	_draw_waves(rect, Vector2(0.66, 0.48), ink)
	_draw_compass(rect, ink)
	_draw_x_mark(rect.position + Vector2(rect.size.x * 0.82, rect.size.y * 0.80), ink)

func _draw_island(rect: Rect2, ratios: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for ratio in ratios:
		points.append(rect.position + Vector2(rect.size.x * ratio.x, rect.size.y * ratio.y))
	points.append(points[0])
	draw_polyline(points, color, 5.0, true)
	draw_colored_polygon(points, Color(0.33, 0.18, 0.07, 0.08))

func _draw_waves(rect: Rect2, ratio: Vector2, color: Color) -> void:
	var origin: Vector2 = rect.position + Vector2(rect.size.x * ratio.x, rect.size.y * ratio.y)
	for wave_index in range(4):
		var center := origin + Vector2(float(wave_index) * 42.0, 0.0)
		draw_arc(center, 17.0, 0.0, PI, 14, color, 3.0, true)

func _draw_compass(rect: Rect2, color: Color) -> void:
	var center: Vector2 = rect.position + Vector2(rect.size.x * 0.16, rect.size.y * 0.80)
	var radius: float = rect.size.y * 0.045
	draw_arc(center, radius, 0.0, TAU, 48, color, 3.0, true)
	draw_arc(center, radius * 0.62, 0.0, TAU, 40, color, 2.0, true)
	for index in range(8):
		var angle: float = TAU * float(index) / 8.0
		var long_radius: float = radius * (1.35 if index % 2 == 0 else 0.98)
		draw_line(center, center + Vector2(cos(angle), sin(angle)) * long_radius, color, 3.0)

func _draw_x_mark(center: Vector2, color: Color) -> void:
	var radius := 34.0
	draw_line(center - Vector2(radius, radius), center + Vector2(radius, radius), color, 7.0)
	draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), color, 7.0)

func _draw_hover_ripple(center: Vector2) -> void:
	var water_ink := Color(0.20, 0.27, 0.24, 0.0)
	for ring_index in range(3):
		var ring_progress: float = wrapf(hover_ripple_progress + float(ring_index) * 0.32, 0.0, 1.0)
		var radius: float = marker_size.x * (0.62 + ring_progress * 0.62)
		var alpha: float = hover_ripple_alpha * (1.0 - ring_progress) * 0.40
		water_ink.a = alpha
		if alpha > 0.01:
			draw_arc(center, radius, 0.0, TAU, 64, water_ink, 3.6, true)

func _draw_ink_splash(center: Vector2) -> void:
	if ink_splash_alpha <= 0.0:
		return

	var ink := Color(0.13, 0.055, 0.020, ink_splash_alpha * 0.82)
	var smear_ink := Color(0.13, 0.055, 0.020, ink_splash_alpha * 0.42)
	var eased_progress: float = 1.0 - pow(1.0 - ink_splash_progress, 2.0)
	var base_radius: float = marker_size.x * 0.42
	var burst_distance: float = marker_size.x * (0.08 + eased_progress * 0.42)

	for blot_index in range(12):
		var angle: float = TAU * float(blot_index) / 12.0 + 0.22 * sin(float(blot_index) * 1.7)
		var direction := Vector2(cos(angle), sin(angle))
		var fleck_distance: float = base_radius + burst_distance * (0.72 + float(blot_index % 4) * 0.12)
		var fleck_center: Vector2 = center + direction * fleck_distance
		var fleck_radius: float = 2.8 + float((blot_index * 3) % 5)
		draw_circle(fleck_center, fleck_radius, ink)

		if blot_index % 3 != 1:
			var smear_start: Vector2 = center + direction * (base_radius * 0.72 + burst_distance * 0.22)
			var smear_end: Vector2 = center + direction * (fleck_distance - fleck_radius * 0.5)
			draw_line(smear_start, smear_end, smear_ink, 3.2, true)

func _draw_dashed_route(progress: float) -> void:
	if route_points.size() < 2:
		return

	var ink := Color(0.19, 0.08, 0.025, 0.88)
	var reveal_distance: float = route_length * clampf(progress, 0.0, 1.0)
	var dot_spacing: float = 34.0
	var dot_distance: float = dot_spacing * 0.5
	var dot_index: int = 0

	while dot_distance <= reveal_distance:
		var dot_position: Vector2 = _get_route_point_at_distance(dot_distance)
		var dot_radius: float = 5.5 if dot_index % 3 != 1 else 4.25
		draw_circle(dot_position, dot_radius, ink)
		if dot_index % 4 == 0:
			draw_circle(dot_position + Vector2(2.0, -1.5), dot_radius * 0.42, Color(0.08, 0.035, 0.014, 0.40))
		dot_distance += dot_spacing
		dot_index += 1

func _draw_selected_destination(center: Vector2) -> void:
	if selection_alpha <= 0.0:
		return

	var circle_color := Color(0.34, 0.07, 0.025, selection_alpha)
	var radius: float = marker_size.x * 0.68
	draw_arc(center + Vector2(3.0, -2.0), radius, 0.18, TAU + 0.18, 72, circle_color, 6.0, true)
	draw_arc(center + Vector2(-4.0, 3.0), radius * 1.06, 0.0, TAU, 72, Color(circle_color.r, circle_color.g, circle_color.b, selection_alpha * 0.55), 3.0, true)

func _draw_ship_marker(position: Vector2, rotation: float = 0.0) -> void:
	var ink := Color(0.12, 0.065, 0.025, 0.95)
	var sail := Color(0.92, 0.76, 0.48, 0.96)
	var hull_points := PackedVector2Array([
		_ship_point(position, Vector2(-42.0, 19.0), rotation),
		_ship_point(position, Vector2(42.0, 19.0), rotation),
		_ship_point(position, Vector2(26.0, 39.0), rotation),
		_ship_point(position, Vector2(-26.0, 39.0), rotation)
	])
	draw_colored_polygon(hull_points, Color(0.20, 0.09, 0.025, 0.96))
	draw_polyline(PackedVector2Array([hull_points[0], hull_points[1], hull_points[2], hull_points[3], hull_points[0]]), ink, 4.0, true)
	draw_line(_ship_point(position, Vector2(0.0, 18.0), rotation), _ship_point(position, Vector2(0.0, -52.0), rotation), ink, 5.0, true)

	var sail_points := PackedVector2Array([
		_ship_point(position, Vector2(5.0, -48.0), rotation),
		_ship_point(position, Vector2(5.0, 8.0), rotation),
		_ship_point(position, Vector2(39.0, 9.0), rotation)
	])
	draw_colored_polygon(sail_points, sail)
	draw_polyline(PackedVector2Array([sail_points[0], sail_points[1], sail_points[2], sail_points[0]]), ink, 3.5, true)

	var small_sail := PackedVector2Array([
		_ship_point(position, Vector2(-5.0, -39.0), rotation),
		_ship_point(position, Vector2(-5.0, 9.0), rotation),
		_ship_point(position, Vector2(-32.0, 13.0), rotation)
	])
	draw_colored_polygon(small_sail, Color(0.83, 0.62, 0.35, 0.92))
	draw_polyline(PackedVector2Array([small_sail[0], small_sail[1], small_sail[2], small_sail[0]]), ink, 3.0, true)

func _ship_point(origin: Vector2, offset: Vector2, rotation: float) -> Vector2:
	return origin + offset.rotated(rotation)
