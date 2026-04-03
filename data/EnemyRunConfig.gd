extends RefCounted

const DEFAULT_RUN_ORDER: Array = [
	{
		"wave_name": "Piranha Pack",
		"enemies": {
			"left": "piranha_swarm",
			"center": "piranha_swarm",
			"right": "piranha_swarm"
		}
	},
	{
		"wave_name": "Pirate Gunner",
		"enemies": {
			"center": "pirate_gunner"
		}
	},
	{
		"wave_name": "Pirate Brute",
		"enemies": {
			"center": "pirate_brute"
		}
	}
]

static func get_default_run_order() -> Array:
	return DEFAULT_RUN_ORDER.duplicate(true)
