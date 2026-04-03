extends "res://enemies/Enemy.gd"

func _ready() -> void:
	printerr("PIRANHA READY")
	setup_from_enemy_id("piranha_swarm")
	super._ready()
