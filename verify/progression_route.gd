# `progression route: tutorial win exposes one authored shallow objective and
# advances only through the declared encounter order — guards against a
# random, duplicated, or invisible critical path`.
#
# This is intentionally a public-contract test.  It exercises RouteProgression
# as World does rather than inspecting World private tutorial/encounter flags.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var route := RouteProgression.new()
	var restored_complete := RouteProgression.new()
	var observed_objectives: Array[String] = []
	route.objective_changed.connect(func(id: String) -> void:
		observed_objectives.append(id)
	)

	_expect(route.phase == RouteProgression.PHASE_TUTORIAL,
		"ROUTE CONTRACT: a fresh route did not begin in the tutorial phase")
	_expect(route.objective_id == "",
		"ROUTE CONTRACT: a fresh route exposed a critical objective before tutorial completion")
	_expect(route.encounter_policy == RouteProgression.ENCOUNTER_POLICY_AUTHORED_ONLY,
		"ROUTE SAFETY: a fresh tutorial allowed ordinary encounters")

	route.start_after_tutorial()
	_expect(route.phase == RouteProgression.PHASE_SHALLOWS,
		"TUTORIAL HANDOFF: route did not enter the shallows phase")
	_expect(route.objective_id == "shallow_angler",
		"TUTORIAL HANDOFF: the sole shallow objective was not the authored Angler")
	_expect(route.objective_text == "Shallows — follow the beacon.",
		"TUTORIAL HANDOFF: the player-facing first objective changed")
	_expect(route.active_roster() == ["angler"],
		"AUTHORED ROSTER: shallow Angler did not resolve to one Angler")

	# Losing cannot advance or consume a route fight.
	route.begin_active_encounter()
	route.resolve_active_encounter("lost")
	_expect(route.objective_id == "shallow_angler",
		"LOSS RECOVERY: losing an authored route fight advanced its objective")

	var expected := [
		["shallow_angler", ["angler"]],
		["shallow_frilled_shark", ["frilled_shark"]],
		["shallow_capstone", ["angler", "frilled_shark"]],
		["deep_swordfish", ["swordfish_duelist"]],
		["deep_sea_urchin", ["sea_urchin"]],
		["deep_capstone", ["swordfish_duelist", "sea_urchin"]],
		["lab_mermaid_freak", ["tethys"]],
	]
	for expected_beat_value in expected:
		var expected_beat: Array = expected_beat_value as Array
		_expect(route.objective_id == String(expected_beat[0]),
			"AUTHORED ORDER: expected %s, got %s" % [expected_beat[0], route.objective_id])
		_expect(route.active_roster() == expected_beat[1],
			"AUTHORED ROSTER: %s had %s instead of %s" % [route.objective_id, route.active_roster(), expected_beat[1]])
		var encounter := route.begin_active_encounter()
		_expect(not encounter.is_empty(), "AUTHORED START: %s could not begin" % route.objective_id)
		if bool(encounter.get("checkpoint_before", false)):
			_expect(route.checkpoint_id != "", "CHECKPOINT: capstone had no pre-fight checkpoint id")
		var result := route.resolve_active_encounter("won")
		if bool(result.get("checkpoint_after", false)):
			_expect(route.checkpoint_id != "", "CHECKPOINT: capstone did not retain its secured checkpoint")

	_expect(route.phase == RouteProgression.PHASE_COMPLETE,
		"ROUTE FINISH: Mermaid Freak victory did not complete the delivered route")
	_expect(route.objective_id == "",
		"ROUTE FINISH: a deferred Octopus encounter was incorrectly exposed as playable")
	restored_complete.restore_state(route.save_state())
	_expect(restored_complete.phase == RouteProgression.PHASE_COMPLETE and restored_complete.objective_id == "",
		"ROUTE SAVE: a completed lab route restored as a replayable Mermaid Freak fight")
	_expect(observed_objectives.has("shallow_angler") and observed_objectives.has("lab_mermaid_freak"),
		"OBJECTIVE SIGNAL: public handoff signal did not cover the route")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("progression route     public route contract and authored order hold")
	# These routes are intentionally bare Nodes rather than children of the
	# SceneTree. Dispose of both explicitly so a green contract gate also has a
	# clean engine shutdown instead of leaking temporary signal/Node objects.
	route.free()
	restored_complete.free()
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, finding: String) -> void:
	if not condition:
		findings.append(finding)
