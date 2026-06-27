extends "res://enemies/Enemy.gd"

func _ready() -> void:
	setup_from_enemy_id("pirate_frigate")
	super._ready()
