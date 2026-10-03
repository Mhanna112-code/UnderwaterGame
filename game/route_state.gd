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

const ZONE_IDS := ["shallows", "deep_zone", "lab", "maze"]
const BLOCKER_STATES := ["available", "in_progress", "defeated"]
const LAB_STATES := ["locked", "available", "cutscene", "boss", "cleared"]
const TETHYS_STATES := ["locked", "available", "in_progress", "defeated"]
const MAZE_DOOR_STATES := ["locked", "available", "entered"]
const OCTOPUS_STATES := ["unavailable", "available", "in_progress", "defeated"]
const ENCOUNTER_SOURCES := ["random", "lab_blocker", "lab_boss", "maze_door"]

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
	zone_id = _allowed_or(value, ZONE_IDS, ZONE_SHALLOWS)

func set_objective(value: String) -> void:
	if objective_id == value:
		return
	objective_id = value
	objective_changed.emit(objective_id)

func set_blocker_state(blocker_id: String, value: String) -> void:
	match blocker_id:
		"bomb_bot":
			bomb_bot_state = _allowed_or(value, BLOCKER_STATES, BLOCKER_AVAILABLE)
		"sword_slayer":
			sword_slayer_state = _allowed_or(value, BLOCKER_STATES, BLOCKER_AVAILABLE)

func set_lab_state(value: String) -> void:
	lab_state = _allowed_or(value, LAB_STATES, LAB_LOCKED)

func set_tethys_state(value: String) -> void:
	tethys_state = _allowed_or(value, TETHYS_STATES, TETHYS_LOCKED)

func set_maze_door_state(value: String) -> void:
	maze_door_state = _allowed_or(value, MAZE_DOOR_STATES, MAZE_DOOR_LOCKED)

func set_octopus_state(value: String) -> void:
	octopus_state = _allowed_or(value, OCTOPUS_STATES, OCTOPUS_UNAVAILABLE)

func set_encounter_source(value: String) -> void:
	encounter_source = _allowed_or(value, ENCOUNTER_SOURCES, ENCOUNTER_RANDOM)

func _allowed_or(value: String, allowed: Array, fallback: String) -> String:
	return value if allowed.has(value) else fallback

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
