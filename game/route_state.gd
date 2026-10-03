class_name RouteState
extends RefCounted

signal objective_changed(objective_id: String)

const ZONE_SHALLOWS := "shallows"
const OBJECTIVE_TUTORIAL := "tutorial"
const BLOCKER_AVAILABLE := "available"
const LAB_LOCKED := "locked"
const TETHYS_LOCKED := "locked"
const MAZE_DOOR_LOCKED := "locked"
const OCTOPUS_UNAVAILABLE := "unavailable"
const ENCOUNTER_RANDOM := "random"

var zone_id := ZONE_SHALLOWS
var objective_id := OBJECTIVE_TUTORIAL
var bomb_bot_state := BLOCKER_AVAILABLE
var sword_slayer_state := BLOCKER_AVAILABLE
var lab_state := LAB_LOCKED
var tethys_state := TETHYS_LOCKED
var maze_door_state := MAZE_DOOR_LOCKED
var octopus_state := OCTOPUS_UNAVAILABLE
var encounter_source := ENCOUNTER_RANDOM

func set_zone(value: String) -> void:
	zone_id = value

func set_objective(value: String) -> void:
	if objective_id == value:
		return
	objective_id = value
	objective_changed.emit(objective_id)

func set_blocker_state(blocker_id: String, value: String) -> void:
	match blocker_id:
		"bomb_bot":
			bomb_bot_state = value
		"sword_slayer":
			sword_slayer_state = value

func set_lab_state(value: String) -> void:
	lab_state = value

func set_tethys_state(value: String) -> void:
	tethys_state = value

func set_maze_door_state(value: String) -> void:
	maze_door_state = value

func set_octopus_state(value: String) -> void:
	octopus_state = value

func set_encounter_source(value: String) -> void:
	encounter_source = value

func to_save_data() -> Dictionary:
	return {
		"zone_id": zone_id,
		"objective_id": objective_id,
		"bomb_bot_state": bomb_bot_state,
		"sword_slayer_state": sword_slayer_state,
		"lab_state": lab_state,
		"tethys_state": tethys_state,
		"maze_door_state": maze_door_state,
		"octopus_state": octopus_state,
		"encounter_source": encounter_source,
	}

func load_save_data(data: Dictionary) -> void:
	set_zone(String(data.get("zone_id", ZONE_SHALLOWS)))
	set_objective(String(data.get("objective_id", OBJECTIVE_TUTORIAL)))
	set_blocker_state("bomb_bot", String(data.get("bomb_bot_state", BLOCKER_AVAILABLE)))
	set_blocker_state("sword_slayer", String(data.get("sword_slayer_state", BLOCKER_AVAILABLE)))
	set_lab_state(String(data.get("lab_state", LAB_LOCKED)))
	set_tethys_state(String(data.get("tethys_state", TETHYS_LOCKED)))
	set_maze_door_state(String(data.get("maze_door_state", MAZE_DOOR_LOCKED)))
	set_octopus_state(String(data.get("octopus_state", OCTOPUS_UNAVAILABLE)))
	set_encounter_source(String(data.get("encounter_source", ENCOUNTER_RANDOM)))
