# FRAME-1: real restore must honor a saved frame, not move a checkpoint's
# actors/walls into another area. No writes to player save slots.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	maze.set_physics_process(false)
	for diver in maze.divers:
		diver.set_physics_process(false)
	var original := maze.campaign_snapshot()
	# A pending item, collected rock and open wall's home are durable state,
	# not just a party-position offset. Create through the existing snapshot
	# contract; normal acquisition/traversal is covered by separate gates.
	original.orbs = [{"item": "potion", "position": [12.0, 1.5, -8.0],
		"golden": false, "grappleable": true, "grapple_only": true}]
	original.loose_keys = [{"position": [13.0, 2.0, -9.0]}]
	original.broken_rocks = [[14.0, 0.5, -10.0]]
	original.rotation_homes.walls_14_15 = [{"wall": "CSGBox3D14",
		"position": original.walls.CSGBox3D14.position.duplicate(), "yaw": 0.25}]
	var origin := Vector3(130.0, -6.0, 240.0)
	var framed := _fixture_in_frame(original, origin)
	_expect(maze.snapshot_matches_runtime(framed), "FRAME-1 valid framed checkpoint rejected before restore")
	maze.restore_campaign_snapshot(framed)
	var restored := maze.campaign_snapshot()
	for field in ["positions", "walls", "rotation_homes", "broken_rocks"]:
		_expect(_equivalent(restored[field], original[field]),
			"FRAME-1 real restore leaves %s in saved frame instead of playable local frame" % field)
	_expect(restored.orbs.size() == 1 and _equivalent(restored.orbs[0].position, [12.0, 1.5, -8.0]),
		"FRAME-1 pending grapple reward restores outside its room")
	_expect(restored.loose_keys.size() == 1 and _equivalent(restored.loose_keys[0].position, [13.0, 2.0, -9.0]),
		"FRAME-1 pending consumable key restores outside its room")
	_expect(framed.positions != original.positions, "FRAME-1 fixture did not actually change saved coordinates")
	_generated_frames(original, maze)
	_reject_invalid_frames(original, maze)
	# A future embedded Load cannot depend on scene destruction to erase
	# unsaved rewards. Reapplying the same checkpoint is resource-idempotent.
	maze.restore_campaign_snapshot(framed)
	await process_frame
	var repeated := maze.campaign_snapshot()
	_expect(repeated.orbs.size() == 1 and repeated.loose_keys.size() == 1,
		"FRAME-4 repeated live restore duplicates pending orb/key rewards")
	var no_rewards := original.duplicate(true)
	no_rewards.orbs = []
	no_rewards.loose_keys = []
	maze.restore_campaign_snapshot(no_rewards)
	await process_frame
	var emptied := maze.campaign_snapshot()
	_expect(emptied.orbs.is_empty() and emptied.loose_keys.is_empty(),
		"FRAME-4 empty checkpoint leaves unsaved collectible rewards")
	maze.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE COORDINATE FRAME: clean" if findings.is_empty() else "MAZE COORDINATE FRAME: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _generated_frames(baseline: Dictionary, maze: MazeLevel) -> void:
	var origins := [Vector3.ZERO, Vector3(130, 0, 240), Vector3(-170, -8, 140),
		Vector3(47.25, 6.5, -34.75), Vector3(0, -12, 0), Vector3(-0.125, 0.25, 0.375)]
	var cases := 0
	for selected in range(3):
		for pattern in range(8):
			var session := CampaignSession.new()
			session.route_state = RouteState.new()
			session.route_state.prologue_complete = true
			session.route_state.tutorial_complete = pattern % 2 == 0
			session.route_state.set_zone("maze")
			session.route_state.set_lab_state("cleared" if pattern % 3 == 0 else "locked")
			session.inventory = {"potion": pattern}
			session.campaign_key_items.assign(["current_pearl"])
			for i in range(3):
				maze.divers[i].stats.hp = 0 if pattern & (1 << i) else 3 + i
				maze.divers[i].stats.oxygen = 0.0 if pattern % 2 else 17.25 + i
				maze.divers[i].stats.evasion_current = i
				maze.divers[i].stats.statuses = {"blindness": {"level": 1, "turns": 2}}
				maze.divers[i].stats.spell_points = 2
				SpellTree.learn_all_available(maze.divers[i], session.campaign_key_items)
			session.capture_party(maze.divers, selected)
			for index in range(origins.size()):
				var from := origins[index] as Vector3
				var to := origins[(index + 2) % origins.size()] as Vector3
				var source := _fixture_in_frame(baseline, from)
				var pristine := source.duplicate(true)
				var result := MazeCoordinateFrame.rebase(source, to)
				var expected := _fixture_in_frame(baseline, to)
				var label := "FRAME-2 active=%d downed=%d origin=%d" % [selected, pattern, index]
				_expect(_equivalent(result, expected), label + ": translated geometry/progress differs from independent oracle")
				_expect(_equivalent(source, pristine), label + ": migration mutates previous checkpoint")
				_expect(_equivalent(MazeCoordinateFrame.rebase(result, to), result), label + ": same-frame restore translates twice")
				var legacy := baseline.duplicate(true)
				legacy.erase("coordinate_origin")
				_expect(_equivalent(MazeCoordinateFrame.rebase(legacy, to), expected), label + ": old standalone save loses its origin")
				session.maze_snapshot = result
				var encoded := CampaignCheckpoint.encode(session)
				var decoded := CampaignCheckpoint.decode(JSON.parse_string(JSON.stringify(encoded)))
				_expect(decoded != null, label + ": valid framed JSON is rejected")
				if decoded != null:
					_expect(decoded.active == selected and decoded.inventory == session.inventory
						and decoded.route_state.to_save_data() == session.route_state.to_save_data(), label + ": migration changes campaign ownership/progress")
					_expect(_equivalent(MazeCoordinateFrame.rebase(decoded.maze_snapshot, from), source), label + ": JSON round trip drifts puzzle coordinates")
					var reencoded := CampaignCheckpoint.encode(decoded)
					_expect(_equivalent(reencoded.campaign_checkpoint.party, encoded.campaign_checkpoint.party), label + ": framed JSON refills or loses party resources/status/kit")
				cases += 1
	print("MAZE COORDINATE FRAME|generated_party_frame_cases=", cases)

func _reject_invalid_frames(baseline: Dictionary, maze: MazeLevel) -> void:
	var before := maze.campaign_snapshot()
	var session := CampaignSession.new()
	session.route_state = RouteState.new()
	session.route_state.prologue_complete = true
	session.capture_party(maze.divers, maze.active)
	var invalid: Array = [null, "legacy", [], [0, 0], [0, 0, 0, 0], ["0", 0, 0],
		[true, 0, 0], [NAN, 0, 0], [0, INF, 0], [0, 0, -1e9]]
	for origin in invalid:
		var source := baseline.duplicate(true)
		source.coordinate_origin = origin
		_expect(not CampaignCheckpoint.valid_maze(source), "FRAME-3 malformed frame accepted by codec")
		session.maze_snapshot = source
		_expect(CampaignCheckpoint.decode(CampaignCheckpoint.encode(session)) == null,
			"FRAME-3 malformed origin reconstructs a campaign at decode boundary")
		_expect(not maze.snapshot_matches_runtime(source), "FRAME-3 malformed frame accepted by live geometry boundary")
		_expect(MazeCoordinateFrame.rebase(source, Vector3.ZERO).is_empty(), "FRAME-3 migration accepts invalid source origin")
		maze.restore_campaign_snapshot(source)
		_expect(_equivalent(maze.campaign_snapshot(), before), "FRAME-3 invalid restore partly changes live scene")
	for destination in [Vector3(INF, 0, 0), Vector3(0, NAN, 0), Vector3(0, 0, 1e9)]:
		_expect(MazeCoordinateFrame.rebase(baseline, destination).is_empty(), "FRAME-3 migration accepts invalid destination")
	var extreme := baseline.duplicate(true)
	extreme.walls.CSGBox3D14.position = [1e8, 0, 0]
	_expect(MazeCoordinateFrame.rebase(extreme, Vector3(100, 0, 0)).is_empty(), "FRAME-3 translated coordinates escape codec range")
	extreme.coordinate_origin = [-100.0, 0.0, 0.0]
	_expect(CampaignCheckpoint.valid_maze(extreme), "FRAME-5 overflow fixture is not valid in its source frame")
	_expect(not maze.snapshot_matches_runtime(extreme),
		"FRAME-5 runtime preflight accepts an untranslatable frame and releases a failed restore")
	print("MAZE COORDINATE FRAME|invalid_frames=", invalid.size(), "|invalid_destinations=3|range_overflow=1")

# Independent recursive fixture oracle: position-shaped fields translate;
# directions, sizes, angles, flags, IDs and discovery never do.
func _fixture_in_frame(source: Dictionary, origin: Vector3) -> Dictionary:
	var result: Dictionary = _translate_named(source, origin)
	result.coordinate_origin = [origin.x, origin.y, origin.z]
	return result

func _translate_named(value: Variant, shift: Vector3, name := "") -> Variant:
	if name in ["position", "hallway_a", "hallway_b"]:
		return [float(value[0]) + shift.x, float(value[1]) + shift.y, float(value[2]) + shift.z]
	if name in ["positions", "rocks", "broken_rocks"]:
		var result: Array = []
		for point in value:
			result.append(_translate_named(point, shift, "position"))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = _translate_named(value[key], shift, String(key))
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_translate_named(entry, shift))
		return result
	return value

func _equivalent(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return absf(float(a) - float(b)) < 0.001
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _equivalent(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _equivalent(a[key], b[key]):
				return false
		return true
	return a == b

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
