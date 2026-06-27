extends Node

var selected_captain: String = ""
var run_mode: String = "main"
var selected_drill: int = 1
var sandbox_encounter: Dictionary = {}

func start_main_run() -> void:
	run_mode = "main"
	selected_drill = 1
	sandbox_encounter.clear()

func start_drill(drill_number: int) -> void:
	run_mode = "drill"
	selected_drill = clampi(drill_number, 1, 5)
	sandbox_encounter.clear()

func start_sandbox_encounter(encounter: Dictionary) -> void:
	run_mode = "sandbox"
	selected_drill = 1
	sandbox_encounter = encounter.duplicate(true)

func is_drill_mode() -> bool:
	return run_mode == "drill"

func is_sandbox_mode() -> bool:
	return run_mode == "sandbox"

func get_sandbox_encounter() -> Dictionary:
	return sandbox_encounter.duplicate(true)

func clear_sandbox() -> void:
	sandbox_encounter.clear()
	if run_mode == "sandbox":
		run_mode = "main"
