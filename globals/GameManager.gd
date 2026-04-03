extends Node

const CardListScript = preload("res://data/CardList.gd")
const RunConfig = preload("res://data/RunConfig.gd")

var battle_scene = null

func begin_battle(scene_ref) -> void:
	battle_scene = scene_ref
	var defs = CardListScript.new().CARD_LIBRARY
	DeckManager.setup_battle(scene_ref, defs)

func get_default_enemy_paths() -> Array[String]:
	return RunConfig.get_default_enemy_paths()
