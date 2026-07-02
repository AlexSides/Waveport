extends Node

var selected_captain: String = ""
var run_mode: String = "main"
var selected_drill: int = 1
var sandbox_encounter: Dictionary = {}
var sandbox_enemy_index: int = 0
var sandbox_enemy_page: int = 0

func start_main_run() -> void:
	run_mode = "main"
	selected_drill = 1
	sandbox_encounter.clear()
	sandbox_enemy_index = 0
	sandbox_enemy_page = 0

func start_drill(drill_number: int) -> void:
	run_mode = "drill"
	selected_drill = clampi(drill_number, 1, 5)
	sandbox_encounter.clear()
	sandbox_enemy_index = 0
	sandbox_enemy_page = 0

func start_sandbox_encounter(encounter: Dictionary, enemy_index: int = 0, enemy_page: int = 0) -> void:
	run_mode = "sandbox"
	selected_drill = 1
	sandbox_encounter = encounter.duplicate(true)
	sandbox_enemy_index = maxi(enemy_index, 0)
	sandbox_enemy_page = maxi(enemy_page, 0)

func is_drill_mode() -> bool:
	return run_mode == "drill"

func is_sandbox_mode() -> bool:
	return run_mode == "sandbox"

func get_sandbox_encounter() -> Dictionary:
	return sandbox_encounter.duplicate(true)

func clear_sandbox() -> void:
	sandbox_encounter.clear()
	sandbox_enemy_index = 0
	sandbox_enemy_page = 0
	if run_mode == "sandbox":
		run_mode = "main"
