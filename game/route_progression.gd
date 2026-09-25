# Public, intentionally small state machine for the playable critical route.
#
# World owns presentation (beacon, arrow, cards, saves and battles); this
# node owns only the facts a player and verifier need to agree on: where the
# route is, what the one objective is, whether ordinary encounters are safe,
# and which authored fight comes next.  Keeping that boundary free of World
# implementation details prevents a future tutorial/maze change from quietly
# restoring random fights on the critical path.
class_name RouteProgression
extends Node

signal objective_changed(objective_id: String)
signal phase_changed(phase_id: String)
signal checkpoint_changed(checkpoint: String)

const PHASE_TUTORIAL := "tutorial"
const PHASE_SHALLOWS := "shallows"
const PHASE_DEEP := "deep"
const PHASE_LAB := "lab"
const PHASE_COMPLETE := "complete"

const ENCOUNTER_POLICY_AUTHORED_ONLY := "authored_only"

# Kept as data so the ordered roster is readable during review and can be
# tested independently of spawning/animation code.  Positions are World-space
# waypoints chosen away from the guardian sites and Marc's maze entrance.
const BEATS := [
	{
		"id": "shallow_angler", "phase": PHASE_SHALLOWS,
		"text": "Shallows — follow the beacon.", "at": Vector3(25.0, 2.0, -50.0),
		"encounter_label": "Route encounter — Shallows 1: Angler",
		"roster": ["angler"],
	},
	{
		"id": "shallow_frilled_shark", "phase": PHASE_SHALLOWS,
		"text": "Shallows — follow the beacon.", "at": Vector3(45.0, 2.0, -5.0),
		"encounter_label": "Route encounter — Shallows 2: Frilled Shark",
		"roster": ["frilled_shark"],
	},
	{
		"id": "shallow_capstone", "phase": PHASE_SHALLOWS,
		"text": "Shallows — secure the reef passage.", "at": Vector3(55.0, 2.0, 40.0),
		"encounter_label": "Route encounter — Shallows capstone: Angler + Frilled Shark",
		"roster": ["angler", "frilled_shark"], "capstone": true,
		# Encounter-only pressure, not a rewrite of either species' delivered
		# base block. This is the first coordinated pair, so both arrive in
		# their healthy capstone profile rather than as ordinary wandering fish.
		"enemy_modifiers": [{"hp_max": 15, "strength": 2}, {"hp_max": 15, "strength": 2}],
		"checkpoint": "shallows_capstone", "transition_after": "deep_descent",
	},
	{
		"id": "deep_swordfish", "phase": PHASE_DEEP,
		"text": "Deep water — follow the beacon.", "at": Vector3(5.0, 2.0, 50.0),
		"encounter_label": "Route encounter — Deep 1: Swordfish",
		"roster": ["swordfish_duelist"],
	},
	{
		"id": "deep_sea_urchin", "phase": PHASE_DEEP,
		"text": "Deep water — find the armored threat.", "at": Vector3(-40.0, 2.0, 35.0),
		"encounter_label": "Route encounter — Deep 2: Sea Urchin",
		"roster": ["sea_urchin"],
	},
	{
		"id": "deep_capstone", "phase": PHASE_DEEP,
		"text": "Deep water — break the final defense.", "at": Vector3(-50.0, 2.0, -10.0),
		"encounter_label": "Route encounter — Deep capstone: Swordfish + Sea Urchin",
		"roster": ["swordfish_duelist", "sea_urchin"], "capstone": true,
		# The coordinated deep pair is deliberately a counterplay check: the
		# Swordfish stays evasive and the Urchin's reinforced shell rewards
		# repeated Weaken before raw damage. Solo species encounters retain the
		# exact delivered base statistics above.
		"enemy_modifiers": [{"hp_max": 12, "strength": 3}, {"hp_max": 14, "strength": 2, "defense": 8}],
		"checkpoint": "deep_capstone", "transition_after": "lab_arrival",
	},
	{
		"id": "lab_mermaid_freak", "phase": PHASE_LAB,
		"text": "The drowned lab — confront Mermaid Freak.", "at": Vector3(-10.0, 2.0, -45.0),
		"encounter_label": "Route encounter — Lab: Mermaid Freak",
		"roster": ["tethys"], "boss": true, "transition_after": "route_complete",
	},
]

var phase := PHASE_TUTORIAL
var objective_id := ""
var objective_text := ""
var checkpoint_id := ""
var encounter_policy := ENCOUNTER_POLICY_AUTHORED_ONLY

var _beat_index := -1
var _encounter_active := false
var _pending_transition_id := ""

func start_after_tutorial() -> void:
	if _beat_index >= 0:
		return
	_set_beat(0)

func active_beat() -> Dictionary:
	if _beat_index < 0 or _beat_index >= BEATS.size():
		return {}
	return (BEATS[_beat_index] as Dictionary).duplicate(true)

func active_roster() -> Array:
	return (active_beat().get("roster", []) as Array).duplicate()

func active_enemy_modifiers() -> Array:
	return (active_beat().get("enemy_modifiers", []) as Array).duplicate(true)

func active_encounter_label() -> String:
	return String(active_beat().get("encounter_label", objective_id.replace("_", " ").capitalize()))

func active_position() -> Vector3:
	return active_beat().get("at", Vector3.ZERO) as Vector3

func is_capstone() -> bool:
	return bool(active_beat().get("capstone", false))

func begin_active_encounter() -> Dictionary:
	if objective_id == "" or _encounter_active:
		return {}
	_encounter_active = true
	var beat := active_beat()
	var is_checkpoint := bool(beat.get("capstone", false))
	if is_checkpoint:
		_set_checkpoint(String(beat.get("checkpoint", "")))
	return {
		"id": objective_id,
		"roster": active_roster(),
		"boss": bool(beat.get("boss", false)),
		"enemy_modifiers": active_enemy_modifiers(),
		"checkpoint_before": is_checkpoint,
	}

func resolve_active_encounter(result: String) -> Dictionary:
	if not _encounter_active:
		return {}
	_encounter_active = false
	if result != "won":
		return {"advanced": false, "checkpoint_after": false}
	var beat := active_beat()
	var was_capstone := bool(beat.get("capstone", false))
	_pending_transition_id = String(beat.get("transition_after", ""))
	if _beat_index + 1 >= BEATS.size():
		_beat_index = BEATS.size()
		phase = PHASE_COMPLETE
		phase_changed.emit(phase)
		objective_id = ""
		objective_text = ""
		objective_changed.emit(objective_id)
	else:
		_set_beat(_beat_index + 1)
	return {
		"advanced": true,
		"checkpoint_after": was_capstone,
		"transition_id": _pending_transition_id,
	}

func take_pending_transition() -> String:
	var result := _pending_transition_id
	_pending_transition_id = ""
	return result

func save_state() -> Dictionary:
	return {
		"beat_index": _beat_index,
		"checkpoint_id": checkpoint_id,
	}

# A save is always written outside a live battle.  Treating an in-progress
# battle as not active on restore guarantees a restart cannot reopen a half
# resolved enemy turn or consume an encounter merely because the game closed.
func restore_state(saved: Dictionary) -> void:
	if saved.is_empty():
		return
	var saved_index := int(saved.get("beat_index", -1))
	checkpoint_id = String(saved.get("checkpoint_id", ""))
	_encounter_active = false
	_pending_transition_id = ""
	if saved_index < 0:
		return
	if saved_index >= BEATS.size():
		_beat_index = BEATS.size()
		phase = PHASE_COMPLETE
		objective_id = ""
		objective_text = ""
		phase_changed.emit(phase)
		objective_changed.emit(objective_id)
		return
	_set_beat(saved_index)

func _set_beat(index: int) -> void:
	_beat_index = index
	var beat := active_beat()
	var next_phase := String(beat.get("phase", PHASE_COMPLETE))
	if phase != next_phase:
		phase = next_phase
		phase_changed.emit(phase)
	objective_id = String(beat.get("id", ""))
	objective_text = String(beat.get("text", ""))
	objective_changed.emit(objective_id)

func _set_checkpoint(id: String) -> void:
	if id == "" or checkpoint_id == id:
		return
	checkpoint_id = id
	checkpoint_changed.emit(checkpoint_id)
