extends SceneTree
## DISC-1: a real first open must lay out discovered geometry before its lesson pauses.
var findings: Array[String] = []
var maze: MazeLevel
var map: MazeMiniMap

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	for frame in 12:
		await physics_frame
	# Explicit near-chest input/presentation fixture, not an earned swim claim.
	maze.set_physics_process(false)
	maze._diver.global_position = (maze.get_node("CurrentWall1") as Node3D).global_position + Vector3(3, 0, 0)
	for frame in 3:
		await process_frame
	maze._diver.global_position = maze.get_node("MapChest").global_position + Vector3(0, 1.0, 1.8)
	map = maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	await _key(KEY_E)
	await create_timer(2.3).timeout
	_expect(maze.key_items.count("maze_nav_map") == 1, "DISC-1 actual chest E did not grant map")
	await _key(KEY_ESCAPE)
	await _key(KEY_R)
	var unread_notice := maze._banner.text
	_expect(maze._banner.visible and not unread_notice.is_empty(), "DISC-8 active notice fixture is not readable before first L")
	# Input.parse_input_event is buffered until the next event dispatch. Observe
	# the first dispatched frame: the lesson pauses further map processing.
	var press := InputEventKey.new()
	press.keycode = KEY_L
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var popup := root.get_node("CharacterAbilityPopup")
	var panel := popup.get_node("%AbilityExplanationPanel") as Control
	_expect(map.main_map.visible and panel.visible and paused, "DISC-1 first L did not open the navigation lesson over a paused map")
	_expect(not maze._banner.visible, "DISC-8 unread orange notice draws through the paused first-open map")
	_expect(String((popup.get_node("%Title") as Label).text).contains("Navigation"), "DISC-1 first L presented a different lesson")
	var lines := map.main_map.find_children("*", "Line2D", false, false)
	_expect(not lines.is_empty(), "DISC-1 first-open map has no projected discovered walls before pause")
	var diagram := Rect2(Vector2(8, 50), map.main_map.size - Vector2(16, 58))
	for node in lines:
		for point in (node as Line2D).points:
			_expect(diagram.grow(5).has_point(point), "DISC-1 first-open wall is bunched into the title or outside map: " + str(point))
	if "--layout" in OS.get_cmdline_user_args() and findings.is_empty():
		await _paused_layout(panel)
	await _key(KEY_ESCAPE)
	await _capture_map()
	await _key(KEY_L)
	_expect(maze._banner.visible and maze._banner.text == unread_notice, "DISC-8 closing the map loses or fails to restore unread notice")
	await _key(KEY_L)
	_expect(not panel.visible and not paused, "DISC-1 navigation lesson repeats every L open")
	await _key(KEY_L)
	if "--legend" in OS.get_cmdline_user_args() and findings.is_empty():
		await _discovery_legend()
	if "--persistence" in OS.get_cmdline_user_args() and findings.is_empty():
		await _checkpoint_compat()
	if "--media-transition" in OS.get_cmdline_user_args() and findings.is_empty():
		await _media_transition()
	maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE MAP DISCOVERY: clean" if findings.is_empty() else "MAZE MAP DISCOVERY: failed")
	quit(0 if findings.is_empty() else 1)

func _media_transition() -> void:
	var popup := root.get_node("CharacterAbilityPopup")
	var panel := popup.get_node("%AbilityExplanationPanel") as Control
	root.size = Vector2i(360, 640)
	var pages: Array[Dictionary] = [{"title": "Maze Navigation", "body": "Text-only map lesson.", "slot": null}]
	popup.call("open", pages, maze)
	for frame in 12:
		await process_frame
	await _key(KEY_ESCAPE)
	root.size = Vector2i(1280, 720)
	pages = [{"title": "Grapple", "body": "Use F to aim at an anchor and move Musashi.", "media": "grapple", "slot": null}]
	popup.call("open", pages, maze)
	await create_timer(0.5, true).timeout
	var frame := popup.get_node("%MediaFrame") as Control
	_expect(frame.visible and panel.get_global_rect().encloses(frame.get_global_rect()), "DISC-7 subsequent authored media is clipped by text-page layout")
	_expect(absf(panel.get_global_rect().get_center().x - root.get_visible_rect().get_center().x) < 1,
		"DISC-7 narrow text-page offsets left the next desktop video lesson off-center")
	await _key(KEY_ESCAPE)
	print("MAP POPUP TRANSITION|text_narrow_to_desktop_grapple")

func _discovery_legend() -> void:
	# Isolated rendering/discovery composition, not normal traversal. Freeze
	# automatic reveal so generated saved discovery is the sole public input.
	map.set_process(false)
	maze._diver.global_position = maze.get_node("MapChest").global_position + Vector3(0, 1, 1.8)
	var pois := maze.map_points_of_interest()
	_expect(pois.any(func(poi): return poi.id == "boss_main" and poi.kind == "boss"), "DISC-2 no visited-boss POI exists")
	var identities := ["map_chest", "room_switch", "split_rock", "control_room", "boss_main", "boss_secret"]
	var expected_words := ["Chest", "Map Control switch", "Mysterious Rock", "Visited room", "Boss", "Boss"]
	await _key(KEY_L)
	var complete := {"walls": [], "rooms": [0, 1, 2, 3], "corridors": [], "halls": [], "count": 0, "pois": identities.duplicate(), "intro_seen": true}
	for wall in maze.wall_boxes:
		complete.walls.append(String(wall.name))
	map.restore_campaign_discovery(complete)
	_expect(not map.main_map.find_children("*", "Line2D", false, false).is_empty(), "DISC-4 full discovery fixture has no rendered walls")
	for mask in range(1 << identities.size()):
		var saved := {"walls": [], "rooms": [], "corridors": [], "halls": [], "count": 0, "pois": [], "intro_seen": true}
		var expected := {"You": true}
		for i in identities.size():
			if mask & (1 << i):
				saved.pois.append(identities[i])
				expected[expected_words[i]] = true
				if i >= 4:
					expected["Visited room"] = true
		map.restore_campaign_discovery(saved)
		_expect(map.main_map.find_children("*", "Line2D", false, false).is_empty(), "DISC-4 replaced discovery retains prior wall/room drawings")
		if not map.main_map.visible:
			await _key(KEY_L)
		await process_frame
		var legend := maze.get_node_or_null("HUD/MazeMapSideLegend") as Control
		_expect(legend != null and legend.visible, "DISC-2 discovery legend is missing")
		if legend == null:
			return
		var words: Array[String] = []
		for label in legend.find_children("*", "Label", true, false):
			if (label as Label).text != "LEGEND":
				words.append((label as Label).text)
		for word in expected:
			_expect(words.count(word) == 1, "DISC-2 discovered kind is absent/duplicated: " + word + " mask=" + str(mask))
		for word in words:
			_expect(expected.has(word), "DISC-2 legend reveals unknown kind: " + word + " mask=" + str(mask))
		if not findings.is_empty():
			return
	print("MAP DISCOVERY LEGEND|generated_subsets=64")
	await _key(KEY_L)

func _checkpoint_compat() -> void:
	var saved: Dictionary = JSON.parse_string(JSON.stringify(maze.campaign_snapshot()))
	_expect(CampaignCheckpoint.valid_maze(saved), "DISC-5 new intro history invalidates real JSON snapshot")
	maze.restore_campaign_snapshot(saved)
	await _key(KEY_L)
	_expect(not paused, "DISC-5 completed navigation lesson replays after JSON restore")
	await _key(KEY_L)
	var legacy := saved.duplicate(true)
	legacy.map.erase("intro_seen")
	_expect(CampaignCheckpoint.valid_maze(legacy), "DISC-5 old map saves without intro state are rejected")
	maze.restore_campaign_snapshot(legacy)
	await _key(KEY_L)
	_expect(paused, "DISC-5 old save cannot receive the newly available navigation lesson")
	await _key(KEY_ESCAPE)
	await _key(KEY_L)
	for invalid in [null, "true", 1, {}, []]:
		var bad := saved.duplicate(true)
		bad.map.intro_seen = invalid
		_expect(not CampaignCheckpoint.valid_maze(bad), "DISC-5 malformed intro history accepted: " + str(invalid))
	print("MAP INTRO SAVE|new=valid|legacy=valid|invalid=5")

func _capture_map() -> void:
	var capture_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	for shape in [Vector2i(1280, 720), Vector2i(720, 480), Vector2i(360, 640)]:
		root.size = shape
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join("map-%dx%d.png" % [shape.x, shape.y]))

func _paused_layout(panel: Control) -> void:
	var capture_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var shapes := [Vector2i(1280, 720), Vector2i(720, 480), Vector2i(360, 640)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 100510
	for i in 9:
		shapes.append(Vector2i(rng.randi_range(360, 1280), rng.randi_range(480, 900)))
	for shape in shapes:
		root.size = shape
		for frame in 12:
			await process_frame
		var viewport := root.get_visible_rect().grow(1)
		var help := maze.get_node("HUD/MazeMapHelp") as Control
		var legend := maze.get_node("HUD/MazeMapSideLegend") as Control
		_expect(paused and panel.visible, "DISC-3 viewport resize dismissed navigation lesson")
		_expect(viewport.encloses(panel.get_global_rect()), "DISC-3 first-open lesson clips viewport " + str(shape))
		for widget in [map.main_map, help, legend]:
			_expect(widget.visible and viewport.encloses(widget.get_global_rect()), "DISC-3 overview/help/legend clips viewport " + str(shape) + ": " + String(widget.name))
		_expect(not map.main_map.get_global_rect().intersects(help.get_global_rect())
			and not map.main_map.get_global_rect().intersects(legend.get_global_rect())
			and not help.get_global_rect().intersects(legend.get_global_rect()), "DISC-3 map/help/legend overlap " + str(shape))
		var copy := help.get_child(0) as RichTextLabel
		_expect(copy.get_content_width() <= copy.size.x + 1 and copy.get_content_height() <= copy.size.y + 1, "DISC-3 current keys don't fit help " + str(shape))
		if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_dir.path_join("first-open-%dx%d.png" % [shape.x, shape.y]))
		if not findings.is_empty():
			return
	print("MAP FIRST-OPEN LAYOUT|paused_generated_sizes=12")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
