extends Control

const ModuleList = preload("res://data/ModuleList.gd")

static var texture_cache: Dictionary = {}

@onready var title_label: Label = $Title
@onready var hint_label: Label = $Hint
@onready var ship_image: TextureRect = $CenterContainer/ShipHolder/ShipImage
@onready var ship_holder: Control = $CenterContainer/ShipHolder

var slot_panels: Array[Panel] = []
var slot_labels: Array[Label] = []
var current_preview_data: Dictionary = {}
var selected_installed_slot_id: String = ""
var selected_cargo_index: int = -1
var status_message: String = ""

func _is_battle_context() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	return scene.name == "BattleScene"

func _is_shipyard_mode() -> bool:
	return not _is_battle_context()

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cache_slot_nodes()
	_refresh_preview()

func open_preview() -> void:
	_cancel_active_card_interaction()
	_clear_selection()
	_refresh_preview()
	visible = true

func close_preview() -> void:
	_clear_selection()
	visible = false

func toggle_preview() -> void:
	if visible:
		close_preview()
	else:
		open_preview()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_preview()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			close_preview()
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()

func _cache_slot_nodes() -> void:
	slot_panels.clear()
	slot_labels.clear()

	for i in range(1, 12):
		var panel_path: String = "CenterContainer/ShipHolder/Slot%02d" % i
		var label_path: String = "CenterContainer/ShipHolder/Slot%02d/Slot%02dLabel" % [i, i]

		var panel: Panel = get_node_or_null(panel_path)
		var label: Label = get_node_or_null(label_path)

		if panel:
			panel.mouse_filter = Control.MOUSE_FILTER_STOP
			panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if not panel.gui_input.is_connected(_on_slot_panel_gui_input.bind(slot_panels.size())):
				panel.gui_input.connect(_on_slot_panel_gui_input.bind(slot_panels.size()))
			slot_panels.append(panel)
		if label:
			slot_labels.append(label)

func _refresh_preview() -> void:
	PlayerData.ensure_run_state()
	current_preview_data = PlayerData.get_ship_preview_data()
	_validate_selection()

	_refresh_title(current_preview_data)
	_refresh_ship_image(current_preview_data)
	_refresh_slots(current_preview_data)
	_refresh_slot_highlights(current_preview_data)

func _refresh_title(preview_data: Dictionary) -> void:
	var ship_name: String = String(preview_data.get("ship_name", "Ship Preview"))
	var hull_text: String = "%d/%d" % [
		int(preview_data.get("current_hull", 0)),
		int(preview_data.get("max_hull", 0))
	]

	title_label.text = ship_name + "  |  Hull " + hull_text
	hint_label.text = _build_hint_text()

func _refresh_ship_image(preview_data: Dictionary) -> void:
	var art_path: String = String(preview_data.get("art_path", ""))

	if art_path != "" and ResourceLoader.exists(art_path):
		ship_image.texture = _load_texture(art_path)

	# Make the ship feel larger inside the overlay.
	ship_image.offset_left = 90.0
	ship_image.offset_top = 35.0
	ship_image.offset_right = -70.0
	ship_image.offset_bottom = -55.0

func _load_texture(path: String) -> Texture2D:
	var texture: Resource = texture_cache.get(path)
	if texture == null:
		texture = load(path)
		if texture is Texture2D:
			texture_cache[path] = texture
	return texture as Texture2D

func _refresh_slots(preview_data: Dictionary) -> void:
	var ship_slots: Array = preview_data.get("slots", [])
	var cargo_modules: Array = preview_data.get("cargo_modules", [])

	for i in range(slot_panels.size()):
		var panel: Panel = slot_panels[i]
		panel.visible = i < ship_slots.size()

	for i in range(slot_labels.size()):
		var label: Label = slot_labels[i]
		if i >= ship_slots.size():
			label.text = ""
			continue

		var slot_data: Dictionary = ship_slots[i]
		var slot_type: String = String(slot_data.get("slot_type", slot_data.get("type", "")))
		var module_id: String = String(slot_data.get("module_id", ""))

		label.text = _build_slot_label(i, slot_type, module_id, cargo_modules)

func _refresh_slot_highlights(preview_data: Dictionary) -> void:
	var ship_slots: Array = preview_data.get("slots", [])

	for i in range(slot_panels.size()):
		var panel: Panel = slot_panels[i]
		panel.self_modulate = Color(0.88, 0.88, 0.88, 1.0)

		if i >= ship_slots.size():
			continue

		var slot_data: Dictionary = ship_slots[i]
		var slot_id: String = String(slot_data.get("slot_id", ""))
		var slot_type: String = String(slot_data.get("slot_type", ""))

		if slot_type == "cargo":
			var cargo_index: int = _cargo_index_from_visual_slot(i)
			if cargo_index == selected_cargo_index:
				panel.self_modulate = Color(0.54, 0.86, 0.54, 1.0)
			elif _is_swap_target_slot(slot_data):
				panel.self_modulate = Color(0.92, 0.70, 1.0, 1.0)
			elif cargo_index >= 0 and cargo_index < int(preview_data.get("cargo_count", 0)):
				panel.self_modulate = Color(0.94, 0.94, 0.84, 1.0)
		else:
			var module_id: String = String(slot_data.get("module_id", ""))
			if slot_id == selected_installed_slot_id:
				panel.self_modulate = Color(1.0, 0.72, 0.35, 1.0)
			elif _is_swap_target_slot(slot_data):
				panel.self_modulate = Color(0.92, 0.70, 1.0, 1.0)
			elif _is_install_target_slot(slot_data):
				panel.self_modulate = Color(0.50, 0.92, 0.50, 1.0)
			elif module_id != "":
				panel.self_modulate = Color(0.96, 0.92, 0.78, 1.0)

func _build_slot_label(index: int, slot_type: String, module_id: String, cargo_modules: Array) -> String:
	match slot_type:
		"rear":
			return _format_ship_slot_label("R%d" % (index + 1), module_id, false)

		"cargo":
			var cargo_index: int = _cargo_index_from_visual_slot(index)
			var cargo_prefix: String = "G%d" % (cargo_index + 1)
			if cargo_index >= 0 and cargo_index < cargo_modules.size():
				var cargo_text: String = "%s\n%s" % [cargo_prefix, _get_module_short_name(String(cargo_modules[cargo_index]))]
				if cargo_index == selected_cargo_index:
					return "[Selected]\n" + cargo_text
				if _is_read_only_mode():
					return cargo_text
				return cargo_text
			return cargo_prefix

		"watch":
			return _format_ship_slot_label("W", module_id, false)

		"crew":
			return _format_ship_slot_label("CR", module_id, false)

		"front":
			return _format_ship_slot_label("F", module_id, false)

		"cannon":
			var cannon_index: int = _cannon_index_from_visual_slot(index)
			var prefix: String = "C%d" % (cannon_index + 1)
			if module_id != "":
				return _format_ship_slot_label(prefix, module_id, false)
			return _format_ship_slot_label(prefix, "", true)

		_:
			if module_id != "":
				return _get_module_short_name(module_id)
			return slot_type.capitalize()

func _cannon_index_from_visual_slot(index: int) -> int:
	match index:
		6:
			return 0
		7:
			return 1
		8:
			return 2
		_:
			return 0

func _cargo_index_from_visual_slot(index: int) -> int:
	match index:
		2:
			return 0
		3:
			return 1
		4:
			return 2
		_:
			return 0

func _get_module_short_name(module_id: String) -> String:
	if module_id == "":
		return ""

	var module_data: Dictionary = ModuleList.get_module(module_id)
	var module_name: String = String(module_data.get("name", module_id))

	match module_id:
		"basic_cannon":
			return "Cannon"
		_:
			return module_name

func _on_slot_panel_gui_input(event: InputEvent, visual_index: int) -> void:
	if not visible:
		return

	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	_handle_slot_click(visual_index)
	get_viewport().set_input_as_handled()

func _handle_slot_click(visual_index: int) -> void:
	var ship_slots: Array = current_preview_data.get("slots", [])
	if visual_index < 0 or visual_index >= ship_slots.size():
		return

	var slot_data: Dictionary = ship_slots[visual_index]
	var slot_type: String = String(slot_data.get("slot_type", ""))

	if slot_type == "cargo":
		_handle_cargo_click(visual_index)
	else:
		_handle_ship_slot_click(slot_data)

	_refresh_preview()

func _handle_cargo_click(visual_index: int) -> void:
	var cargo_modules: Array = current_preview_data.get("cargo_modules", [])
	var cargo_index: int = _cargo_index_from_visual_slot(visual_index)

	if cargo_index < 0 or cargo_index >= cargo_modules.size():
		selected_cargo_index = -1
		selected_installed_slot_id = ""
		status_message = "Empty cargo slot."
		return

	if not _is_shipyard_mode():
		selected_cargo_index = cargo_index
		selected_installed_slot_id = ""
		status_message = "Inspecting cargo %d: %s." % [
			cargo_index + 1,
			_get_module_short_name(String(cargo_modules[cargo_index]))
		]
		return

	selected_cargo_index = cargo_index
	selected_installed_slot_id = ""
	status_message = "Selected cargo %d: %s. Click a matching empty slot to install or a matching filled slot to swap." % [
		cargo_index + 1,
		_get_module_short_name(String(cargo_modules[cargo_index]))
	]

func _handle_ship_slot_click(slot_data: Dictionary) -> void:
	var slot_id: String = String(slot_data.get("slot_id", ""))
	var module_id: String = String(slot_data.get("module_id", ""))

	if not _is_shipyard_mode():
		selected_cargo_index = -1
		if module_id == "":
			selected_installed_slot_id = ""
			status_message = "%s is empty." % _get_slot_short_name(slot_id)
			return

		selected_installed_slot_id = slot_id
		status_message = "Inspecting %s: %s." % [
			_get_slot_short_name(slot_id),
			_get_module_short_name(module_id)
		]
		return

	if selected_installed_slot_id == slot_id and module_id != "":
		if int(current_preview_data.get("cargo_count", 0)) >= int(current_preview_data.get("cargo_capacity", 0)):
			status_message = "Cargo is full. Cannot uninstall %s." % _get_slot_short_name(slot_id)
			return

		if PlayerData.remove_installed_module(slot_id):
			status_message = "Uninstalled %s to cargo." % _get_slot_short_name(slot_id)
			_clear_selection()
		else:
			status_message = "Could not uninstall %s." % _get_slot_short_name(slot_id)
		return

	if selected_cargo_index != -1:
		var cargo_modules: Array = current_preview_data.get("cargo_modules", [])
		if selected_cargo_index < 0 or selected_cargo_index >= cargo_modules.size():
			_clear_selection()
			status_message = "That cargo module is no longer available."
			return

		var cargo_module_id: String = String(cargo_modules[selected_cargo_index])
		if module_id != "":
			if _can_swap_cargo_into_slot(slot_data):
				if PlayerData.swap_cargo_module_with_installed(slot_id, selected_cargo_index):
					status_message = "Swapped %s with %s." % [
						_get_module_short_name(cargo_module_id),
						_get_slot_short_name(slot_id)
					]
					_clear_selection()
				else:
					status_message = "Swap failed for %s." % _get_slot_short_name(slot_id)
			else:
				status_message = "%s is occupied. Pick an empty matching slot or a matching filled slot to swap." % _get_slot_short_name(slot_id)
			return

		if PlayerData.install_module_to_slot(slot_id, cargo_module_id):
			status_message = "Installed %s into %s." % [
				_get_module_short_name(cargo_module_id),
				_get_slot_short_name(slot_id)
			]
			_clear_selection()
		else:
			status_message = "Cannot install %s into %s." % [
				_get_module_short_name(cargo_module_id),
				_get_slot_short_name(slot_id)
			]
		return

	selected_cargo_index = -1
	if module_id == "":
		selected_installed_slot_id = ""
		status_message = "%s is empty." % _get_slot_short_name(slot_id)
		return

	selected_installed_slot_id = slot_id
	status_message = "Selected %s. Click any cargo slot to remove it to cargo." % _get_slot_short_name(slot_id)

func _is_install_target_slot(slot_data: Dictionary) -> bool:
	if not _is_shipyard_mode():
		return false
	if selected_cargo_index == -1:
		return false

	var cargo_modules: Array = current_preview_data.get("cargo_modules", [])
	if selected_cargo_index < 0 or selected_cargo_index >= cargo_modules.size():
		return false

	if String(slot_data.get("module_id", "")) != "":
		return false

	var cargo_module_id: String = String(cargo_modules[selected_cargo_index])
	var module_def: Dictionary = ModuleList.get_module(cargo_module_id)
	return String(module_def.get("slot_type", "")) == String(slot_data.get("slot_type", ""))

func _can_swap_cargo_into_slot(slot_data: Dictionary) -> bool:
	if not _is_shipyard_mode():
		return false
	if selected_cargo_index == -1:
		return false
	if String(slot_data.get("module_id", "")) == "":
		return false

	var cargo_modules: Array = current_preview_data.get("cargo_modules", [])
	if selected_cargo_index < 0 or selected_cargo_index >= cargo_modules.size():
		return false

	var cargo_module_id: String = String(cargo_modules[selected_cargo_index])
	var module_def: Dictionary = ModuleList.get_module(cargo_module_id)
	return String(module_def.get("slot_type", "")) == String(slot_data.get("slot_type", ""))

func _is_swap_target_slot(slot_data: Dictionary) -> bool:
	return _can_swap_cargo_into_slot(slot_data)

func _is_cargo_action_target() -> bool:
	return false

func _is_read_only_mode() -> bool:
	return not _is_shipyard_mode()

func _validate_selection() -> void:
	var cargo_modules: Array = current_preview_data.get("cargo_modules", [])
	if selected_cargo_index >= cargo_modules.size():
		selected_cargo_index = -1

	if selected_installed_slot_id == "":
		return

	var has_selected_slot: bool = false
	for slot_data_variant in current_preview_data.get("slots", []):
		var slot_data: Dictionary = slot_data_variant
		if String(slot_data.get("slot_id", "")) != selected_installed_slot_id:
			continue
		if String(slot_data.get("module_id", "")) != "":
			has_selected_slot = true
		break

	if not has_selected_slot:
		selected_installed_slot_id = ""

func _clear_selection() -> void:
	selected_installed_slot_id = ""
	selected_cargo_index = -1

func _build_hint_text() -> String:
	var cargo_text: String = "Cargo %d/%d" % [
		int(current_preview_data.get("cargo_count", 0)),
		int(current_preview_data.get("cargo_capacity", 0))
	]
	var summary: String = _build_selection_summary()
	var instructions: String = _build_action_instruction()
	var lines: Array[String] = [
		"Shipyard",
		cargo_text,
		summary,
		instructions
	]
	if status_message != "":
		lines.append("Status: " + status_message)
	lines.append("Tab or Esc to close")
	return "\n".join(lines)

func _build_selection_summary() -> String:
	if selected_installed_slot_id != "":
		var slot_module_id: String = _get_module_id_for_slot(selected_installed_slot_id)
		return "Selected: %s (%s)" % [
			_get_slot_short_name(selected_installed_slot_id),
			_get_module_short_name(slot_module_id)
		]

	if selected_cargo_index != -1:
		var cargo_modules: Array = current_preview_data.get("cargo_modules", [])
		if selected_cargo_index >= 0 and selected_cargo_index < cargo_modules.size():
			return "Selected: Cargo %d (%s)" % [
				selected_cargo_index + 1,
				_get_module_short_name(String(cargo_modules[selected_cargo_index]))
			]

	return "Selected: none"

func _build_action_instruction() -> String:
	if _is_read_only_mode():
		if selected_installed_slot_id != "" or selected_cargo_index != -1:
			return "Action: Read-only during combat. You can inspect modules, but not equip, remove, or swap them."
		return "Action: During combat this preview is inspect-only. Open it outside combat to manage modules."

	if selected_installed_slot_id != "":
		if int(current_preview_data.get("cargo_count", 0)) >= int(current_preview_data.get("cargo_capacity", 0)):
			return "Action: Cargo is full, so this module cannot be uninstalled."
		return "Action: Click this slot again to uninstall it to cargo."

	if selected_cargo_index != -1:
		var cargo_modules: Array = current_preview_data.get("cargo_modules", [])
		if selected_cargo_index >= 0 and selected_cargo_index < cargo_modules.size():
			var cargo_module_id: String = String(cargo_modules[selected_cargo_index])
			var module_def: Dictionary = ModuleList.get_module(cargo_module_id)
			var slot_type: String = String(module_def.get("slot_type", ""))
			return "Action: Click an empty %s slot to install, or a filled %s slot to swap." % [slot_type, slot_type]
		return "Action: Select a cargo module again."

	return "Action: Click a filled ship slot to select/uninstall it, or click a cargo module to install it."

func _format_ship_slot_label(prefix: String, module_id: String, is_empty: bool) -> String:
	var lines: Array[String] = []
	if selected_installed_slot_id != "" and prefix == _get_slot_short_name(selected_installed_slot_id):
		lines.append("[Selected]")
	elif _is_slot_prefix_valid_target(prefix):
		lines.append("[Install]")

	lines.append(prefix)

	if module_id != "":
		lines.append(_get_module_short_name(module_id))
	elif is_empty:
		lines.append("Empty")

	return "\n".join(lines)

func _is_slot_prefix_valid_target(prefix: String) -> bool:
	if selected_cargo_index == -1:
		return false

	for slot_data_variant in current_preview_data.get("slots", []):
		var slot_data: Dictionary = slot_data_variant
		if _get_slot_short_name(String(slot_data.get("slot_id", ""))) != prefix:
			continue
		return _is_install_target_slot(slot_data) or _is_swap_target_slot(slot_data)

	return false

func _get_module_id_for_slot(slot_id: String) -> String:
	for slot_data_variant in current_preview_data.get("slots", []):
		var slot_data: Dictionary = slot_data_variant
		if String(slot_data.get("slot_id", "")) == slot_id:
			return String(slot_data.get("module_id", ""))
	return ""

func _get_slot_short_name(slot_id: String) -> String:
	for slot_data_variant in current_preview_data.get("slots", []):
		var slot_data: Dictionary = slot_data_variant
		if String(slot_data.get("slot_id", "")) != slot_id:
			continue

		var slot_type: String = String(slot_data.get("slot_type", ""))
		match slot_type:
			"cannon":
				return "C%d" % (_cannon_index_from_slot_id(slot_id) + 1)
			"cargo":
				return "G%d" % (_cargo_index_from_slot_id(slot_id) + 1)
			"rear":
				return "Rear"
			"watch":
				return "Watch"
			"crew":
				return "Crew"
			"front":
				return "Front"
			_:
				return slot_type.capitalize()

	return slot_id

func _cannon_index_from_slot_id(slot_id: String) -> int:
	for i in range(current_preview_data.get("slots", []).size()):
		var slot_data: Dictionary = current_preview_data["slots"][i]
		if String(slot_data.get("slot_id", "")) == slot_id:
			return _cannon_index_from_visual_slot(i)
	return 0

func _cargo_index_from_slot_id(slot_id: String) -> int:
	for i in range(current_preview_data.get("slots", []).size()):
		var slot_data: Dictionary = current_preview_data["slots"][i]
		if String(slot_data.get("slot_id", "")) == slot_id:
			return _cargo_index_from_visual_slot(i)
	return 0

func _cancel_active_card_interaction() -> void:
	var selected_card: Node = CardManager.selected_card
	if selected_card == null or not is_instance_valid(selected_card):
		return

	if selected_card.has_method("stop_drag"):
		selected_card.stop_drag()
	if selected_card.has_method("deselect"):
		selected_card.deselect()

	CardManager.selected_card = null
