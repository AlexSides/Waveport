extends RefCounted

const TOTAL_VOYAGE_BATTLES: int = 8

const SEA_NORMAL_ENCOUNTER_BUILDERS: Array = [
	&"_make_opener_encounter",
	&"_make_fight_two_encounter",
	&"_make_piranha_swarm_encounter"
]

const PIRATE_NORMAL_ENCOUNTER_BUILDERS: Array = [
	&"_make_pirate_skiff_encounter",
	&"_make_raider_cutter_encounter",
	&"_make_smuggler_encounter",
	&"_make_twin_corsairs_encounter",
	&"_make_powder_skiff_encounter",
	&"_make_boarding_tender_encounter"
]

static func get_default_run_order() -> Array:
	var sea_encounters: Array = _build_shuffled_encounters(SEA_NORMAL_ENCOUNTER_BUILDERS, 3)
	var pirate_encounters: Array = _build_shuffled_encounters(PIRATE_NORMAL_ENCOUNTER_BUILDERS, 3)

	var route: Array = []
	route.append_array(sea_encounters)
	route.append(_make_sea_boss_encounter())
	route.append_array(pirate_encounters)
	route.append(_make_pirate_boss_encounter())

	for index in range(route.size()):
		var encounter: Dictionary = Dictionary(route[index])
		_apply_voyage_metadata(encounter, index + 1)
		route[index] = encounter

	return route

static func _build_shuffled_encounters(builders: Array, count: int) -> Array:
	var shuffled_builders: Array = builders.duplicate()
	shuffled_builders.shuffle()

	var encounters: Array = []
	var encounter_count: int = mini(count, shuffled_builders.size())
	for index in range(encounter_count):
		encounters.append(_make_encounter_from_builder(shuffled_builders[index]))

	return encounters

static func _make_encounter_from_builder(builder_name: StringName) -> Dictionary:
	match builder_name:
		&"_make_opener_encounter":
			return _make_opener_encounter()
		&"_make_fight_two_encounter":
			return _make_fight_two_encounter()
		&"_make_piranha_swarm_encounter":
			return _make_piranha_swarm_encounter()
		&"_make_pirate_skiff_encounter":
			return _make_pirate_skiff_encounter()
		&"_make_raider_cutter_encounter":
			return _make_raider_cutter_encounter()
		&"_make_smuggler_encounter":
			return _make_smuggler_encounter()
		&"_make_twin_corsairs_encounter":
			return _make_twin_corsairs_encounter()
		&"_make_powder_skiff_encounter":
			return _make_powder_skiff_encounter()
		&"_make_boarding_tender_encounter":
			return _make_boarding_tender_encounter()

	return {}

static func _apply_voyage_metadata(encounter: Dictionary, battle_number: int) -> void:
	var route_name: String = "Sea Route" if battle_number <= 4 else "Pirate Waters"
	var route_index: int = battle_number if battle_number <= 4 else battle_number - 4

	encounter["battle_number"] = battle_number
	encounter["total_battles"] = TOTAL_VOYAGE_BATTLES
	encounter["route_name"] = route_name
	encounter["route_index"] = route_index
	encounter["route_total"] = 4

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

static func _make_sea_boss_encounter() -> Dictionary:
	return {
		"wave_name": "Sea Boss: Reef Shark",
		"enemies": {
			"center": "reef_shark"
		}
	}

static func _make_pirate_skiff_encounter() -> Dictionary:
	return {
		"wave_name": "Pirate Skiff",
		"enemies": {
			"center": "pirate_skiff"
		}
	}

static func _make_raider_cutter_encounter() -> Dictionary:
	return {
		"wave_name": "Raider Cutter",
		"enemies": {
			"center": "raider_cutter"
		}
	}

static func _make_smuggler_encounter() -> Dictionary:
	return {
		"wave_name": "Smuggler",
		"enemies": {
			"center": "smuggler"
		}
	}

static func _make_twin_corsairs_encounter() -> Dictionary:
	return {
		"wave_name": "Twin Corsairs",
		"enemies": {
			"center": "twin_corsair_left",
			"right": "twin_corsair_right"
		}
	}

static func _make_powder_skiff_encounter() -> Dictionary:
	return {
		"wave_name": "Powder Skiff",
		"enemies": {
			"center": "powder_skiff"
		}
	}

static func _make_boarding_tender_encounter() -> Dictionary:
	return {
		"wave_name": "Boarding Tender",
		"enemies": {
			"center": "boarding_tender"
		}
	}

static func _make_pirate_boss_encounter() -> Dictionary:
	return {
		"wave_name": "Pirate Boss: Dread Corsair",
		"enemies": {
			"center": "dread_corsair"
		}
	}
