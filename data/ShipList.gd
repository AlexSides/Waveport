extends Node

const SHIPS := {
	"starter_sloop": {
		"id": "starter_sloop",
		"name": "Starter Sloop",
		"art_path": "res://assets/ships/ShipPreview.png",
		"cargo_capacity": 3,
		"slots": [
			{"id": "slot_01", "type": "rear"},
			{"id": "slot_02", "type": "rear"},
			{"id": "slot_03", "type": "cargo"},
			{"id": "slot_04", "type": "cargo"},
			{"id": "slot_05", "type": "cargo"},
			{"id": "slot_06", "type": "watch"},
			{"id": "slot_07", "type": "cannon"},
			{"id": "slot_08", "type": "cannon"},
			{"id": "slot_09", "type": "cannon"},
			{"id": "slot_10", "type": "crew"},
			{"id": "slot_11", "type": "front"}
		],
		"starting_installed_modules": {
			"slot_07": "basic_cannon",
			"slot_08": "basic_cannon"
		}
	}
}

static func get_ship(ship_id: String) -> Dictionary:
	return SHIPS.get(ship_id, SHIPS["starter_sloop"]).duplicate(true)

static func get_ship_slots(ship_id: String) -> Array:
	var ship: Dictionary = get_ship(ship_id)
	return ship.get("slots", []).duplicate(true)

static func get_slot_count_by_type(ship_id: String, slot_type: String) -> int:
	return get_slots_of_type(ship_id, slot_type).size()

static func get_slots_of_type(ship_id: String, slot_type: String) -> Array:
	var matches: Array = []
	for slot in get_ship_slots(ship_id):
		if String(slot.get("type", "")) == slot_type:
			matches.append(slot)
	return matches

static func get_cargo_capacity(ship_id: String) -> int:
	var ship: Dictionary = get_ship(ship_id)
	return int(ship.get("cargo_capacity", 3))

static func get_starting_installed_modules(ship_id: String) -> Dictionary:
	var ship: Dictionary = get_ship(ship_id)
	return ship.get("starting_installed_modules", {}).duplicate(true)

static func get_default_installed_modules(ship_id: String) -> Dictionary:
	var installed: Dictionary = {}

	for slot in get_ship_slots(ship_id):
		var slot_id: String = String(slot.get("id", ""))
		var slot_type: String = String(slot.get("type", ""))
		if slot_id == "" or slot_type == "cargo":
			continue
		installed[slot_id] = ""

	for slot_id_variant in get_starting_installed_modules(ship_id).keys():
		var slot_id: String = String(slot_id_variant)
		if installed.has(slot_id):
			installed[slot_id] = String(get_starting_installed_modules(ship_id).get(slot_id_variant, ""))

	return installed

static func get_active_slot_count(ship_id: String) -> int:
	var count: int = 0
	for slot in get_ship_slots(ship_id):
		if String(slot.get("type", "")) != "cargo":
			count += 1
	return count

static func get_total_slot_count(ship_id: String) -> int:
	return get_ship_slots(ship_id).size()

static func has_ship(ship_id: String) -> bool:
	return SHIPS.has(ship_id)

static func get_ship_name(ship_id: String) -> String:
	var ship: Dictionary = get_ship(ship_id)
	return String(ship.get("name", ""))

static func get_ship_art_path(ship_id: String) -> String:
	var ship: Dictionary = get_ship(ship_id)
	return String(ship.get("art_path", ""))

static func get_slot_by_id(ship_id: String, slot_id: String) -> Dictionary:
	for slot in get_ship_slots(ship_id):
		if String(slot.get("id", "")) == slot_id:
			return slot.duplicate(true)
	return {}

static func get_slot_type(ship_id: String, slot_id: String) -> String:
	var slot: Dictionary = get_slot_by_id(ship_id, slot_id)
	return String(slot.get("type", ""))

static func get_slot_ids(ship_id: String) -> Array[String]:
	var ids: Array[String] = []
	for slot in get_ship_slots(ship_id):
		ids.append(String(slot.get("id", "")))
	return ids

static func get_non_cargo_slot_ids(ship_id: String) -> Array[String]:
	var ids: Array[String] = []
	for slot in get_ship_slots(ship_id):
		var slot_id: String = String(slot.get("id", ""))
		var slot_type: String = String(slot.get("type", ""))
		if slot_id != "" and slot_type != "cargo":
			ids.append(slot_id)
	return ids
