class_name RouteState
extends RefCounted

signal objective_changed(objective_id: String)
signal phase_changed(phase: String)

const ZONE_SHALLOWS := "shallows"
const OBJECTIVE_TUTORIAL := "tutorial"
const BLOCKER_AVAILABLE := "available"
const LAB_LOCKED := "locked"
const TETHYS_LOCKED := "locked"
const MAZE_DOOR_LOCKED := "locked"
const OCTOPUS_UNAVAILABLE := "unavailable"
const ENCOUNTER_RANDOM := "random"
const PROLOGUE_PHASE_TITLE := "title"
const PROLOGUE_PHASE_OPENING_VIDEO := "opening_video"
const PROLOGUE_PHASE_SPAWN_EXPLORATION := "spawn_exploration"
const PROLOGUE_PHASE_COMPLETE := "complete"

const ZONE_IDS := ["shallows", "deep", "maze"]
const BLOCKER_STATES := ["available", "in_progress", "defeated"]
const LAB_STATES := ["locked", "available", "cutscene", "boss", "cleared"]
const TETHYS_STATES := ["locked", "available", "in_progress", "defeated"]
const MAZE_DOOR_STATES := ["locked", "available", "entered"]
const OCTOPUS_STATES := ["unavailable", "available", "in_progress", "defeated"]
const ENCOUNTER_SOURCES := [
	"random", "lab_blocker", "lab_boss", "maze_door",
	"prologue_angler", "prologue_octopus",
	"maze_puppets", "maze_cordys",
]
const PROLOGUE_PHASES := [
	"title",
	"opening_video",
	"opening_handoff",
	"spawn_exploration",
	"angler",
	"angler_victory",
	"octopus_notice",
	"octopus_omen",
	"octopus_introduction",
	"octopus_reveal",
	"octopus_response",
	"scripted_defeat",
	"octopus_aftermath",
	"recovery",
	"complete",
]

var zone_id := ZONE_SHALLOWS
var objective_id := OBJECTIVE_TUTORIAL
var bomb_bot_state := BLOCKER_AVAILABLE
var sword_slayer_state := BLOCKER_AVAILABLE
var lab_state := LAB_LOCKED
var tethys_state := TETHYS_LOCKED
var maze_door_state := MAZE_DOOR_LOCKED
var octopus_state := OCTOPUS_UNAVAILABLE
var encounter_source := ENCOUNTER_RANDOM
var deep_warning_seen := false
var prologue_phase := PROLOGUE_PHASE_TITLE
var opening_video_seen := false
var prologue_complete := false
var tutorial_complete := false

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

func set_prologue_phase(value: String) -> void:
	if not PROLOGUE_PHASES.has(value) or prologue_phase == value:
		return
	prologue_phase = value
	phase_changed.emit(prologue_phase)

# Live video, Battle, timers and actors are intentionally not persisted. The
# three durable milestones decide which safe public phase a loaded run enters.
func normalize_prologue_phase() -> void:
	if prologue_complete:
		set_prologue_phase(PROLOGUE_PHASE_COMPLETE)
	elif opening_video_seen:
		set_prologue_phase(PROLOGUE_PHASE_SPAWN_EXPLORATION)
	else:
		set_prologue_phase(PROLOGUE_PHASE_OPENING_VIDEO)

func mark_deep_warning_seen() -> void:
	deep_warning_seen = true

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
		"deep_warning_seen": deep_warning_seen,
		"opening_video_seen": opening_video_seen,
		"prologue_complete": prologue_complete,
		"tutorial_complete": tutorial_complete,
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
	deep_warning_seen = data.get("deep_warning_seen", false) == true
	# All three fields were introduced together. A save with none of them is an
	# existing PR #96 run and must never be forced back through a new opening.
	# Once any field exists, missing siblings are treated as false so an
	# interrupted write cannot silently skip unfinished prologue work.
	var legacy_save := (
		not data.has("opening_video_seen")
		and not data.has("prologue_complete")
		and not data.has("tutorial_complete")
	)
	if legacy_save:
		opening_video_seen = true
		prologue_complete = true
		tutorial_complete = true
	else:
		opening_video_seen = data.get("opening_video_seen", false) == true
		prologue_complete = data.get("prologue_complete", false) == true
		tutorial_complete = data.get("tutorial_complete", false) == true
	normalize_prologue_phase()
