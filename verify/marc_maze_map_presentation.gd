extends SceneTree
## MAP-5: map/help must remain readable, not merely respond to hidden keys.
var findings: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	maze.set_physics_process(false)
	maze.key_items.append("maze_nav_map") # Post-acquisition layout fixture.
	maze._diver.global_position = maze.get_node("MapChest").global_position + Vector3(0, 1.5, 1.8)
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	var discovery := {"walls": [], "rooms": [0, 1, 2, 3], "corridors": [], "halls": [], "count": 0, "pois": [], "intro_seen": true}
	for wall in maze.wall_boxes:
		discovery.walls.append(String(wall.name))
	for corridor in maze.corridors:
		discovery.corridors.append(String(corridor.name))
	map.restore_campaign_discovery(discovery)
	var event := InputEventKey.new()
	event.keycode = KEY_L
	event.pressed = true
	Input.parse_input_event(event)
	var shapes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(803, 893), Vector2i(720, 480), Vector2i(360, 640)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 970410
	for i in 8:
		shapes.append(Vector2i(rng.randi_range(360, 1280), rng.randi_range(480, 900)))
	for shape in shapes:
		root.size = shape
		for frame in 16:
			await process_frame
		var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1)
		var diagram := map.main_map.get_global_rect()
		var help := maze.get_node("HUD/MazeMapHelp") as PanelContainer
		var copy := help.get_child(0) as RichTextLabel
		var legend := maze.get_node("HUD/MazeMapSideLegend") as Control
		var title := map.main_map.get_node("MazeMapTitle") as Label
		_expect(map.main_map.visible and help.visible, "MAP-5 actual L did not open map and instructions")
		# The map replaces the radar in the top-right corner; exploration controls stay visible.
		_expect(not map.visible and maze.get_node("HUD/MazeExplorationControls").visible,
			"MAP-5 map must replace the radar and keep the exploration controls visible")
		_expect(not diagram.intersects((maze.get_node("HUD/MazeExplorationControls") as Control).get_global_rect()),
			"MAP-5 map covers the exploration controls at " + str(shape))
		_expect(bounds.encloses(diagram) and bounds.encloses(help.get_global_rect()), "MAP-5 map/help outside viewport at " + str(shape))
		_expect(not diagram.intersects(help.get_global_rect()), "MAP-5 help covers maze diagram at " + str(shape))
		_expect(bounds.encloses(legend.get_global_rect()) and diagram.encloses(title.get_global_rect()), "MAP-5 legend/title clipped at " + str(shape))
		_expect(not diagram.intersects(legend.get_global_rect()) and not help.get_global_rect().intersects(legend.get_global_rect()), "MAP-5 external discovery legend covers map/help at " + str(shape))
		_expect(copy.get_content_width() <= copy.size.x + 1 and copy.get_content_height() <= copy.size.y + 1, "MAP-5 help text overflows its panel at " + str(shape))
		# Encounters (R) live in the always-visible exploration controls, not the map help.
		_expect(copy.get_parsed_text().contains("Ctrl") and not copy.get_parsed_text().contains("Encounters"), "MAP-5 help omits current keys or still lists encounters")
		_expect(copy.get_parsed_text().contains("Left") and copy.get_parsed_text().contains("Right")
			and not copy.get_parsed_text().contains("←") and not copy.get_parsed_text().contains("→"),
			"MAP-8 help relies on nonportable arrow glyphs instead of named keys")
		if not capture_dir.is_empty():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_dir.path_join("map-%dx%d.png" % [shape.x, shape.y]))
		print("MAP PRESENTATION|", shape, "|diagram=", diagram, "|help=", help.get_global_rect())
	var close := InputEventKey.new()
	close.keycode = KEY_L
	close.pressed = true
	Input.parse_input_event(close)
	await process_frame
	_expect(not map.main_map.visible and not maze.get_node("HUD/MazeMapHelp").visible and map.visible
		and maze.get_node("HUD/MazeExplorationControls").visible, "MAP-5 L does not restore exploration HUD")
	maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC MAP PRESENTATION: clean" if findings.is_empty() else "MARC MAP PRESENTATION: failed")
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
