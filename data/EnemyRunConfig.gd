extends RefCounted

static func get_default_run_order() -> Array:
	return [
		_make_opener_encounter(),
		_make_fight_two_encounter(),
		_make_piranha_swarm_encounter(),
		{
			"wave_name": "Reef Shark",
			"enemies": {
				"center": "reef_shark"
			}
		}
	]

static func _make_opener_encounter() -> Dictionary:
	var opener_ids: Array[String] = ["shellback_crab", "eel"]
	opener_ids.shuffle()
	var chosen_enemy_id: String = opener_ids[0]
	var wave_name: String = "Shellback Crab" if chosen_enemy_id == "shellback_crab" else "Reef Eel"

	return {
		"wave_name": wave_name,
		"enemies": {
			"center": chosen_enemy_id
		}
	}

static func _make_fight_two_encounter() -> Dictionary:
	if randi() % 2 == 0:
		return _make_jellyfish_pair_encounter()
	return _make_starfish_encounter()

static func _make_jellyfish_pair_encounter() -> Dictionary:
	return {
		"wave_name": "Jellyfish Pair",
		"enemies": {
			"center": "jellyfish",
			"right": "jellyfish"
		}
	}

static func _make_starfish_encounter() -> Dictionary:
	return {
		"wave_name": "Starfish",
		"enemies": {
			"center": "starfish"
		}
	}

static func _make_piranha_swarm_encounter() -> Dictionary:
	var piranha_ids: Array[String] = ["piranha_a", "piranha_b", "piranha_c"]
	piranha_ids.shuffle()

	return {
		"wave_name": "Piranha Swarm",
		"enemies": {
			"left": piranha_ids[0],
			"center": piranha_ids[1],
			"right": piranha_ids[2]
		}
	}
