# INT-04: generated JSON round trips must preserve playable resources;
# corrupt records must be rejected before gameplay, not become New Game.
extends SceneTree

const SLOT := 918318
var findings: Array[String] = []
var owns_slot := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if SaveManager.slot_exists(SLOT):
		findings.append("INT-04 IO test slot exists; refusing overwrite")
		await _finish()
		return
	owns_slot = true
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	var session := CampaignSession.new()
	session.route_state = RouteState.new()
	session.route_state.prologue_complete = true
	session.route_state.opening_video_seen = true
	session.route_state.tutorial_complete = false
	session.route_state.set_zone("maze")
	session.maze_snapshot = maze.campaign_snapshot()
	# Bounded generated combinations cover every active diver and all eight
	# living/downed patterns. Actual stats/kit APIs, not oversized HP fixtures.
	for selected in range(3):
		for pattern in range(8):
			for i in range(3):
				var diver := maze.divers[i]
				diver.stats.hp = 0 if pattern & (1 << i) else 3 + i
				diver.stats.oxygen = 27.25 + i * 9.5
				diver.stats.evasion_current = i
				diver.stats.spell_points = 3
				SpellTree.learn_all_available(diver, [])
				diver.stats.statuses = {"blindness": {"level": 1 + i, "turns": 2}}
				diver.stats.temporary_modifiers = {"accuracy": -i, "evasion": i}
			session.capture_party(maze.divers, selected)
			session.inventory = {"potion": pattern + 1}
			session.campaign_key_items.assign(["current_pearl"])
			var plain := CampaignCheckpoint.encode(session)
			var decoded := CampaignCheckpoint.decode(JSON.parse_string(JSON.stringify(plain)))
			if decoded == null:
				findings.append("INT-04 valid generated checkpoint rejected: active=%d pattern=%d" % [selected, pattern])
				break
			_expect(decoded.active == selected and int(decoded.inventory.get("potion")) == pattern + 1,
				"INT-04 generated JSON loses active diver or inventory")
			for i in range(3):
				var stats := decoded.party[i].stats as CombatantStats
				_expect(stats.hp == (0 if pattern & (1 << i) else 3 + i) and absf(stats.oxygen - (27.25 + i * 9.5)) < 0.001,
					"INT-04 JSON refills/downed resources or loses fractional Oxygen")
				_expect(stats.evasion_current == i and stats.status_level("blindness") == 1 + i
					and stats.temporary_modifiers.accuracy == -i, "INT-04 JSON drops depleted EVA or active effects")
				_expect(decoded.party[i].known_spells == maze.divers[i].known_spells
					and decoded.party[i].equipped_spells == maze.divers[i].equipped_spells,
					"INT-04 JSON drops earned kit")
	var baseline := CampaignCheckpoint.encode(session)
	var invalid: Array[Dictionary] = []
	for field in ["party", "version", "maze"]:
		var broken := baseline.duplicate(true)
		broken.campaign_checkpoint.erase(field)
		invalid.append(broken)
	for flag in MazeLevel.CAMPAIGN_FLAGS:
		var broken := baseline.duplicate(true)
		broken.campaign_checkpoint.maze.flags[flag] = "false"
		invalid.append(broken)
	for field in CampaignCheckpoint.STAT_INTS + ["oxygen", "oxygen_max"]:
		var broken := baseline.duplicate(true)
		broken.campaign_checkpoint.party[1].stats[field] = "invalid"
		invalid.append(broken)
	for size in [0, 1, 2, 4, 5, 6]:
		var broken := baseline.duplicate(true)
		var position: Array = []
		position.resize(size)
		position.fill(0)
		broken.campaign_checkpoint.maze.positions[0] = position
		invalid.append(broken)
	for broken in invalid:
		_expect(CampaignCheckpoint.decode(JSON.parse_string(JSON.stringify(broken))) == null,
			"INT-04 malformed checkpoint is accepted by the JSON boundary")
	print("MAZE CHECKPOINT IO|valid_cases=24|invalid_cases=", invalid.size())
	maze.queue_free()
	await process_frame
	if not findings.is_empty():
		await _finish()
		return
	# Exercise the actual title consumer, not only the codec, including a
	# shape-valid but nonexistent geometry reference caught by Maze itself.
	var malformed := baseline.duplicate(true)
	malformed.campaign_checkpoint.maze.positions[1] = [0, 0]
	var reference_error := baseline.duplicate(true)
	reference_error.campaign_checkpoint.maze.walls["NonexistentPuzzleWall"] = reference_error.campaign_checkpoint.maze.walls.values()[0].duplicate(true)
	for broken in [malformed, reference_error]:
		SaveManager.write_slot(SLOT, broken)
		var before := FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT))
		var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
		root.add_child(world)
		current_scene = world
		await process_frame
		world.title_screen.load_game_chosen.emit(SLOT)
		for frame in range(20):
			await process_frame
		_expect(current_scene is World, "INT-04 corrupt maze Load leaves an unusable Maze scene")
		if current_scene is World:
			var rejected := current_scene as World
			_expect(paused and rejected.title_screen.visible and rejected.opening_video == null,
				"INT-04 corrupt maze Load releases play or replays opening")
			_expect(_load_error(rejected.title_screen), "INT-04 corrupt maze Load has no actionable explanation")
		_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT)) == before,
			"INT-04 rejected maze Load modifies its checkpoint")
		current_scene.queue_free()
		await process_frame
		paused = false
	await _finish()

func _load_error(node: Node) -> bool:
	if node is Label and (node as Label).is_visible_in_tree() and (node as Label).text.contains("Could not load"):
		return true
	for child in node.get_children():
		if _load_error(child):
			return true
	return false

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	if owns_slot:
		DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE CHECKPOINT IO: clean" if findings.is_empty() else "MAZE CHECKPOINT IO: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
