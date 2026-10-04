# Opening prologue state and migration contract.
#
# Bugs caught:
# - OPEN-001: old PR #96 saves replay the new opening or new saves migrate as
#   already complete because missing fields and explicit false are conflated.
# - OPEN-002: interrupted phases restore into a transient/half-owned scene
#   instead of one of the three safe durable milestones.
# - OPEN-013: prologue encounter sources are rejected or contaminate campaign
#   Octopus state.
#
# Usage: godot --headless --path . --script verify/opening_prologue_state.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var route := RouteState.new()
	_test_new_save_contract(route)
	_test_phase_signal(route)
	_test_encounter_sources(route)
	_test_old_save_migration()
	_test_interrupted_state_normalization()
	_test_all_milestone_phase_round_trips()
	_finish()

# OPEN-002/024: live cinematic position/phase must never turn a persisted run
# into a half-owned scene. Cover every milestone combination at every phase.
func _test_all_milestone_phase_round_trips() -> void:
	var expected := ["opening_video", "spawn_exploration", "complete", "complete", "opening_video", "spawn_exploration", "complete", "complete"]
	for flags in range(8):
		for phase_value in RouteState.PROLOGUE_PHASES:
			var state := RouteState.new()
			state.opening_video_seen = (flags & 1) != 0
			state.prologue_complete = (flags & 2) != 0
			state.tutorial_complete = (flags & 4) != 0
			state.set_prologue_phase(String(phase_value))
			var serialized := state.to_save_data()
			if serialized.has("prologue_phase"):
				findings.append("OPEN-024 live cinematic phase was serialized")
			var restored := RouteState.new()
			restored.load_save_data(serialized)
			if restored.prologue_phase != expected[flags]:
				findings.append("OPEN-024 flags %d interrupted at %s restores unsafe %s" % [flags, phase_value, restored.prologue_phase])
			if restored.opening_video_seen != state.opening_video_seen or restored.prologue_complete != state.prologue_complete or restored.tutorial_complete != state.tutorial_complete:
				findings.append("OPEN-001 phase interruption lost independent milestones")

func _test_new_save_contract(route: RouteState) -> void:
	var data := route.to_save_data()
	for field in ["opening_video_seen", "prologue_complete", "tutorial_complete"]:
		if not data.has(field):
			findings.append("OPEN-001 new-save field missing: %s" % field)
		elif data[field] != false:
			findings.append("OPEN-001 new-save field %s must be explicit false" % field)
	if route.get("prologue_phase") != "title":
		findings.append("OPEN-002 new runtime phase must begin at title")

func _test_phase_signal(route: RouteState) -> void:
	if not route.has_signal("phase_changed") or not route.has_method("set_prologue_phase"):
		findings.append("OPEN-002 public phase signal/setter is absent")
		return
	var events: Array[String] = []
	route.phase_changed.connect(func(phase: String) -> void:
		events.append(phase)
	)
	route.set_prologue_phase("opening_video")
	route.set_prologue_phase("opening_video")
	route.set_prologue_phase("not_a_phase")
	if events != ["opening_video"]:
		findings.append("OPEN-002 phase signal must emit once for one valid change, got %s" % [events])
	if route.get("prologue_phase") != "opening_video":
		findings.append("OPEN-002 invalid phase must not replace the current public phase")

func _test_encounter_sources(route: RouteState) -> void:
	var original_octopus: String = String(route.octopus_state)
	for source in ["prologue_angler", "prologue_octopus"]:
		route.set_encounter_source(source)
		if route.encounter_source != source:
			findings.append("OPEN-013 semantic encounter source rejected: %s" % source)
		if route.octopus_state != original_octopus:
			findings.append("OPEN-013 prologue source mutated campaign Octopus state")

func _test_old_save_migration() -> void:
	var restored := RouteState.new()
	restored.load_save_data({
		"zone_id": "deep",
		"objective_id": "find_lab",
		"octopus_state": "unavailable",
		"encounter_source": "random",
	})
	var data := restored.to_save_data()
	for field in ["opening_video_seen", "prologue_complete", "tutorial_complete"]:
		if data.get(field, null) != true:
			findings.append("OPEN-001 old save must migrate %s to true" % field)
	if restored.get("prologue_phase") != "complete":
		findings.append("OPEN-001 old save must normalize directly to complete")
	if restored.octopus_state != "unavailable":
		findings.append("OPEN-013 old-save migration changed campaign Octopus state")

func _test_interrupted_state_normalization() -> void:
	var rows := [
		{
			"name": "before-or-during-video",
			"input": {"opening_video_seen": false, "prologue_complete": false, "tutorial_complete": false},
			"expected": "opening_video",
		},
		{
			"name": "after-video-or-during-combat",
			"input": {"opening_video_seen": true, "prologue_complete": false, "tutorial_complete": false},
			"expected": "spawn_exploration",
		},
		{
			"name": "after-atomic-recovery",
			"input": {"opening_video_seen": true, "prologue_complete": true, "tutorial_complete": false},
			"expected": "complete",
		},
	]
	for row_value in rows:
		var row := row_value as Dictionary
		var restored := RouteState.new()
		restored.load_save_data(row.input as Dictionary)
		if restored.get("prologue_phase") != row.expected:
			findings.append("OPEN-002 %s normalized to %s, expected %s" % [
				row.name, restored.get("prologue_phase"), row.expected,
			])

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING PROLOGUE STATE: clean" if findings.is_empty() else "OPENING PROLOGUE STATE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
