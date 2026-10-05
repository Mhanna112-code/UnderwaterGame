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
	maze._diver.global_position = Vector3(2000, 0, 2000)
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	var discovery := {"walls": [], "rooms": [0, 1, 2, 3], "corridors": [], "halls": [], "count": 0, "pois": []}
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
		var legend := map.main_map.get_node("MazeMapLegend") as Control
		var title := map.main_map.get_node("MazeMapTitle") as Label
		_expect(map.main_map.visible and help.visible, "MAP-5 actual L did not open map and instructions")
		_expect(not map.visible and not maze.get_node("HUD/MazeExplorationControls").visible,
			"MAP-5 exploration controls/radar draw through the overview")
		_expect(bounds.encloses(diagram) and bounds.encloses(help.get_global_rect()), "MAP-5 map/help outside viewport at " + str(shape))
		_expect(not diagram.intersects(help.get_global_rect()), "MAP-5 help covers maze diagram at " + str(shape))
		_expect(diagram.encloses(legend.get_global_rect()) and diagram.encloses(title.get_global_rect()), "MAP-5 legend/title clipped at " + str(shape))
		_expect(copy.get_content_width() <= copy.size.x + 1 and copy.get_content_height() <= copy.size.y + 1, "MAP-5 help text overflows its panel at " + str(shape))
		_expect(copy.get_parsed_text().contains("Ctrl") and copy.get_parsed_text().contains("Encounters"), "MAP-5 help omits current/encounter keys")
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
