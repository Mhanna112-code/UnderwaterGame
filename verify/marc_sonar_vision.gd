extends SceneTree
## SV-1..4: Q owns vision; legacy flags cannot disable it or leak across owners.
var findings: Array[String] = []
var capture_dir := ""
var cases := 0
var maze: MazeLevel
var room: SwirlRoom
var mesh: MultiMeshInstance3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await _settle()
	maze.random_encounters_enabled = false
	maze.room_encounters_enabled = false
	room = maze.get_node("SphereRoom") as SwirlRoom
	mesh = room.find_children("*", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D
	# Room/actor placement fixture, with no vision pickup or state grant.
	for i in maze.divers.size():
		maze.divers[i].global_position = room.center + Vector3(2, 0, i)
		maze.divers[i].velocity = Vector3.ZERO
	maze.divers[0].sonar_active = false
	# Let the chase camera settle after near-room fixture placement; the
	# comparison must not mistake a transition camera for normal presentation.
	for frame in 45:
		await physics_frame
	await _key(KEY_Q)
	await _settle()
	_expect(maze.divers[0].sonar_active and maze.sonar_vision_active() and mesh.visible,
		"SV-1 actual Q cannot reveal hazards without a separate vision pickup/G")
	if not findings.is_empty():
		await _finish()
		return
	_expect(maze.get_node_or_null("SonarVisionPickup") == null, "SV-1 obsolete vision pickup still claims a separate gate")
	_expect(not _hud_text().contains("G: Sonar Vision"), "SV-1 HUD still teaches obsolete G equipment")
	await _capture("fresh-q-on")
	await _key(KEY_Q)
	await _settle()
	_expect(not maze.sonar_vision_active() and not mesh.visible and maze.hidden_marker_positions().is_empty(), "SV-3 Q off retains hidden hazard reveal")
	_expect(_hud_text().split("\n").has("Sonar off."), "SV-5 latest Q off leaves an obsolete Sonar-on notice contradicting the HUD")
	await _capture("fresh-q-off")
	await _legacy_cases()
	await _owner_cases()
	await _finish()

func _legacy_cases() -> void:
	maze.keys_held = 2
	maze.inventory = {"potion": 3}
	maze.campaign_key_items.assign(["current_pearl"])
	for owned in [false, true]:
		for equipped in [false, true]:
			for i in maze.divers.size():
				maze.divers[i].stats.hp = 4 + i
				maze.divers[i].stats.oxygen = 17.5 + i * 2.5
			var session := CampaignSession.new()
			session.route_state = RouteState.new()
			session.route_state.prologue_complete = true
			session.capture_party(maze.divers, 0)
			session.inventory = maze.inventory.duplicate()
			session.campaign_key_items = maze.campaign_key_items.duplicate()
			session.maze_snapshot = maze.campaign_snapshot()
			session.maze_snapshot.flags.has_sonar_vision = owned
			session.maze_snapshot.flags.sonar_vision_equipped = equipped
			var decoded := CampaignCheckpoint.decode(JSON.parse_string(JSON.stringify(CampaignCheckpoint.encode(session))))
			_expect(decoded != null, "SV-2 valid legacy flag pair rejected by JSON checkpoint")
			if decoded == null:
				return
			decoded.restore_party(maze.divers)
			maze.restore_campaign_snapshot(decoded.maze_snapshot)
			for i in maze.divers.size():
				_expect(maze.divers[i].stats.hp == 4 + i and maze.divers[i].stats.oxygen == 17.5 + i * 2.5,
					"SV-2 legacy vision restore heals/refills a saved party member")
			_expect(maze.keys_held == 2 and decoded.inventory == {"potion": 3} and decoded.campaign_key_items == ["current_pearl"],
				"SV-2 legacy vision restore resets keys/items/relics")
			# Four pairs cycle through all three real Tab-selected actors.
			for selected in 3:
				_expect(maze.active == selected, "SV-2 actual Tab selects the wrong actor after restore")
				maze.divers[0].sonar_active = false
				maze.divers[0].stats.oxygen = 17.5
				var before: Array = maze.divers.map(func(d: Diver) -> int: return d.stats.hp)
				await _key(KEY_Q)
				await _settle()
				_expect(maze.sonar_vision_active() == (selected == 0) and mesh.visible == (selected == 0),
					"SV-2/3 legacy flags or non-sonar actor change Q reveal")
				_expect(maze.divers.map(func(d: Diver) -> int: return d.stats.hp) == before and maze.divers[0].stats.oxygen == 17.5,
					"SV-2 restore/Q silently refills HP/O2 or charges before its billing interval")
				var active := maze.sonar_vision_active()
				await _key(KEY_G)
				await _settle()
				_expect(maze.sonar_vision_active() == active and mesh.visible == active and not _hud_text().contains("G: Sonar Vision")
					and not _hud_text().contains("Sonar Vision equipped"), "SV-4 obsolete G changes vision or HUD")
				cases += 1
				await _key(KEY_TAB)
				await _settle()
			_expect(not mesh.visible, "SV-3 switching back to Maxilani with Q off leaks previous actor reveal")
			print("SONAR LEGACY|owned=", owned, "|equipped=", equipped, "|three_actors=true")

func _owner_cases() -> void:
	maze.divers[0].sonar_active = false
	await _key(KEY_Q)
	await _settle()
	_expect(mesh.visible, "SV-3 owner fixture cannot reveal with actual Q")
	await _key(KEY_ESCAPE)
	_expect(maze.inventory_menu.visible, "SV-4 Escape fails to open actual reading menu")
	await _key(KEY_Q)
	await _settle()
	_expect(maze.divers[0].sonar_active, "SV-4 Q acts through the reading menu")
	await _key(KEY_ESCAPE)
	maze.set_maze_active(false)
	await _settle()
	_expect(not maze.sonar_vision_active() and not mesh.visible and maze.hidden_marker_positions().is_empty(), "SV-3 inactive maze leaks 3D/marker vision")
	maze.set_maze_active(true)
	await _settle()
	_expect(mesh.visible, "SV-3 active maze fails to resume current Q reveal")
	maze.divers[0].global_position = room.room_min - Vector3(3, 0, 3)
	await _settle()
	_expect(not mesh.visible and maze.sonar_vision_active(), "SV-3 outside-room Q either leaks mesh or disables valid sonar")
	maze.divers[0].global_position = room.center + Vector3(2, 0, 0)
	await _key(KEY_Q)
	maze.divers[0].stats.oxygen = 0
	await _key(KEY_Q)
	await _settle()
	_expect(not maze.divers[0].sonar_active and not maze.sonar_vision_active() and not mesh.visible,
		"SV-4 zero Oxygen enables misleading hazard vision")

func _hud_text() -> String:
	var texts: Array[String] = []
	for label in maze.get_node("HUD").find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			texts.append(label.text)
	return "\n".join(texts)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _settle() -> void:
	for frame in 5:
		await physics_frame

func _capture(label: String) -> void:
	if not capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	maze.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("SONAR VISION: clean|legacy_actor_cases=%d" % cases if findings.is_empty() else "SONAR VISION: failed")
	quit(0 if findings.is_empty() else 1)
