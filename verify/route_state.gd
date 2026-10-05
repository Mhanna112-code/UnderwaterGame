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
	route.set_objective("find_lab")
	route.set_blocker_state("bomb_bot", "defeated")
	route.set_blocker_state("sword_slayer", "in_progress")
	route.set_lab_state("available")
	route.set_tethys_state("in_progress")
	route.set_maze_door_state("available")
	route.set_octopus_state("unavailable")
	route.set_encounter_source("lab_boss")
	route.mark_deep_warning_seen()

	if objective_events != ["find_lab"]:
		findings.append("OBJECTIVE SIGNAL: expected one find_lab event, got %s" % [objective_events])

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
		"objective_id": "find_lab",
		"bomb_bot_state": "defeated",
		"sword_slayer_state": "in_progress",
		"lab_state": "available",
		"tethys_state": "in_progress",
		"maze_door_state": "available",
		"octopus_state": "unavailable",
		"encounter_source": "lab_boss",
		"deep_warning_seen": true,
		"opening_video_seen": false,
		"prologue_complete": false,
		"tutorial_complete": false,
	}
	if restored.to_save_data() != expected:
		findings.append("ROUND TRIP: expected %s, got %s" % [expected, restored.to_save_data()])

	_test_invalid_save_falls_back(route_script)
	await _test_world_checkpoint_round_trip(expected)
	await _test_legacy_deep_maze_migration()
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
		"deep_warning_seen": false,
		# This dictionary represents an old PR #96 save because none of the
		# prologue fields were supplied. Migration must bypass the new opening.
		"opening_video_seen": true,
		"prologue_complete": true,
		"tutorial_complete": true,
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
	var expected_world := expected.duplicate(true)
	# RouteState itself remains a lossless public data object, proven above.
	# World cannot resume a video decoder or a live Battle, so its checkpoint
	# boundary deliberately converts that transient state into a safe retry.
	expected_world.lab_state = "available"
	expected_world.tethys_state = "available"
	expected_world.objective_id = "find_lab"
	expected_world.encounter_source = "random"
	if restored_route == null or restored_route.to_save_data() != expected_world:
		findings.append("WORLD CHECKPOINT: transient boss state did not normalize to a retryable laboratory entrance")
	restored.queue_free()
	await process_frame

func _test_legacy_deep_maze_migration() -> void:
	var world := await _fresh_world()
	var save_data := world._serialize_state()
	var old_route := (world.route_state as RouteState).to_save_data()
	old_route.zone_id = "deep"
	old_route.objective_id = "defeat_bomb_bot"
	old_route.maze_door_state = "locked"
	old_route.lab_state = "locked"
	old_route.tethys_state = "locked"
	save_data.route_state = old_route
	SaveManager.write_slot(TEST_SLOT, save_data)
	world.queue_free()
	await process_frame

	var restored := await _fresh_world()
	restored.set("_current_slot", TEST_SLOT)
	restored._load_save()
	if (restored.route_state.maze_door_state != "available"
		or restored.route_state.tethys_state != "locked"
		or restored.route_state.lab_state != "locked"
		or restored.route_state.objective_id != "find_lab"):
		findings.append("WORLD CHECKPOINT: old Deep save did not open only the independent maze branch")
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
