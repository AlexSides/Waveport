extends Node

const SAVE_PATH := "user://save_slot_1.json"

var _restore_requested: bool = false

func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	return not load_save().is_empty()

func request_continue() -> void:
	_restore_requested = true

func consume_requested_save() -> Dictionary:
	if not _restore_requested:
		return {}
	_restore_requested = false
	return load_save()

func save_pre_battle(state: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save file for writing.")
		return

	file.store_string(JSON.stringify(state))
	file.close()

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open save file for reading.")
		return {}

	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		return parsed

	return {}

func clear_save() -> void:
	_restore_requested = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
