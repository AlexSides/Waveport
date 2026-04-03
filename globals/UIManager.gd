extends Node

var battle_scene = null

func update_deck_ui(deck_count: int, discard_count: int) -> void:
	if not _ensure_battle_scene():
		return

	if battle_scene.deck_label:
		battle_scene.deck_label.text = "Deck: %d" % deck_count

	if battle_scene.discard_label:
		battle_scene.discard_label.text = "Discard: %d" % discard_count

func show_warning(message: String) -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("log_message"):
		scene.log_message("[Warning] %s" % message)
	else:
		print("[Warning] %s" % message)

func _ensure_battle_scene() -> bool:
	if battle_scene and is_instance_valid(battle_scene):
		return true

	battle_scene = GameManager.battle_scene
	return battle_scene != null and is_instance_valid(battle_scene)
