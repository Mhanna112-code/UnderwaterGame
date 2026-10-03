# Public route-state contract and JSON-safe round trip.
#
# Usage: godot --headless --path . --script verify/route_state.gd
extends SceneTree

const TEST_SLOT := 918274

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

	route.set_zone("deep")
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
		"zone_id": "deep",
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

	_test_invalid_save_falls_back(route_script)
	await _test_world_checkpoint_round_trip(expected)
	_finish()

func _test_invalid_save_falls_back(route_script: Script) -> void:
	var restored = route_script.new()
	restored.load_save_data({
		"zone_id": "nowhere",
		"bomb_bot_state": "respawning_forever",
		"sword_slayer_state": "missing",
		"lab_state": "half_open",
		"tethys_state": "won_but_alive",
		"maze_door_state": "teleporting",
		"octopus_state": "playable",
		"encounter_source": "query_string",
	})
	var expected_defaults := {
		"zone_id": "shallows",
		"objective_id": "tutorial",
		"bomb_bot_state": "available",
		"sword_slayer_state": "available",
		"lab_state": "locked",
		"tethys_state": "locked",
		"maze_door_state": "locked",
		"octopus_state": "unavailable",
		"encounter_source": "random",
	}
	if restored.to_save_data() != expected_defaults:
		findings.append("INVALID SAVE: impossible route values did not fall back to safe defaults")

func _test_world_checkpoint_round_trip(expected: Dictionary) -> void:
	_remove_test_save()
	var world := await _fresh_world()
	var world_route: Variant = world.get("route_state")
	if world_route == null:
		findings.append("WORLD CONTRACT: World does not expose route_state")
		world.queue_free()
		await process_frame
		return
	world_route.load_save_data(expected)
	SaveManager.write_slot(TEST_SLOT, world._serialize_state())
	world.queue_free()
	await process_frame

	var restored := await _fresh_world()
	restored.set("_current_slot", TEST_SLOT)
	restored._load_save()
	var restored_route: Variant = restored.get("route_state")
	if restored_route == null or restored_route.to_save_data() != expected:
		findings.append("WORLD CHECKPOINT: authored progression did not survive World save/load")
	restored.queue_free()
	await process_frame

func _fresh_world() -> World:
	var packed := load("res://game/world.tscn") as PackedScene
	var world := packed.instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	return world

func _remove_test_save() -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)

func _finish() -> void:
	_remove_test_save()
	for finding in findings:
		print("FINDING  " + finding)
	print("ROUTE STATE: clean" if findings.is_empty() else "ROUTE STATE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
