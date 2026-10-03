# Public route-state contract and JSON-safe round trip.
#
# Usage: godot --headless --path . --script verify/route_state.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var route_script := load("res://game/route_state.gd")
	if route_script == null:
		findings.append("CONTRACT: game/route_state.gd does not exist")
		_finish()
		return

	var route = route_script.new()
	var objective_events: Array[String] = []
	route.objective_changed.connect(func(objective_id: String) -> void:
		objective_events.append(objective_id)
	)

	route.set_zone("deep_zone")
	route.set_objective("defeat_bomb_bot")
	route.set_blocker_state("bomb_bot", "defeated")
	route.set_blocker_state("sword_slayer", "in_progress")
	route.set_lab_state("available")
	route.set_tethys_state("in_progress")
	route.set_maze_door_state("available")
	route.set_octopus_state("unavailable")
	route.set_encounter_source("lab_boss")

	if objective_events != ["defeat_bomb_bot"]:
		findings.append("OBJECTIVE SIGNAL: expected one defeat_bomb_bot event, got %s" % [objective_events])

	var encoded: String = JSON.stringify(route.to_save_data())
	var decoded: Variant = JSON.parse_string(encoded)
	if not decoded is Dictionary:
		findings.append("SERIALIZATION: route state was not JSON-safe")
		_finish()
		return

	var restored = route_script.new()
	restored.load_save_data(decoded as Dictionary)
	var expected := {
		"zone_id": "deep_zone",
		"objective_id": "defeat_bomb_bot",
		"bomb_bot_state": "defeated",
		"sword_slayer_state": "in_progress",
		"lab_state": "available",
		"tethys_state": "in_progress",
		"maze_door_state": "available",
		"octopus_state": "unavailable",
		"encounter_source": "lab_boss",
	}
	if restored.to_save_data() != expected:
		findings.append("ROUND TRIP: expected %s, got %s" % [expected, restored.to_save_data()])

	_finish()

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("ROUTE STATE: clean" if findings.is_empty() else "ROUTE STATE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
