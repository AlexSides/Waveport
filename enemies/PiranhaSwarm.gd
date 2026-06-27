extends "res://enemies/Enemy.gd"

func _ready() -> void:
	setup_from_enemy_id("piranha_swarm")
	super._ready()
