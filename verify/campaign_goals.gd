extends SceneTree
## GOAL-1: restored milestones and real area handoff must replace stale goals.
## Checkpoint/position fixtures isolate presentation, NOT an earned journey.
var findings: Array[String] = []
var world: World
var cases := 0
var capture_folder := "/private/tmp/campaign-goals-visual-oct5"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--narrow" in OS.get_cmdline_user_args():
		root.size = Vector2i(360, 640)
	elif "--short" in OS.get_cmdline_user_args():
		root.size = Vector2i(720, 480)
	else:
		# Headless SceneTree's default viewport is not the game's desktop
		# window. Give the desktop bounds oracle its declared 1280x720 size.
		root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_folder = arg.trim_prefix("--capture-dir=")
	world = load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = false
	var base := world._serialize_state()
	for lab_done in [false, true]:
		for has_map in [false, true]:
			for has_relic in [false, true]:
				for stale in ["find_lab", "enter_lab", "defeat_tethys", "enter_maze", ""]:
					var data: Dictionary = JSON.parse_string(JSON.stringify(base))
					data.route_state.lab_state = "cleared" if lab_done else "locked"
					data.route_state.tethys_state = "defeated" if lab_done else "locked"
					data.route_state.zone_id = "deep"
					data.route_state.objective_id = stale
					data.route_state.deep_warning_seen = true
					data.campaign_checkpoint.maze.flags._completed = has_relic
					data.campaign_checkpoint.maze.key_items = ["maze_nav_map"] if has_map else []
					if has_relic:
						data.campaign_checkpoint.maze.key_items.append("ancient_relic")
					for member in data.divers:
						member.position = [205, 2, -20]
						member.sonar_active = false
					for member in data.campaign_checkpoint.party:
						member.sonar_active = false
					_expect(world.restore_checkpoint(data), "GOAL-1 valid checkpoint fixture rejected")
					world.get_node("HUD").show()
					await physics_frame
					await process_frame
					var label := "lab=%s map=%s relic=%s stale=%s" % [lab_done, has_map, has_relic, stale]
					_expect_deep(lab_done, label + " before entry")
					if stale == "" and not has_map and not has_relic:
						await _capture("deep-cleared" if lab_done else "deep-before-lab")
					(world.divers[world.active] as Diver).global_position = Vector3(263, 1.8, 16)
					for frame in 4:
						await physics_frame
						await process_frame
					var maze := world.embedded_maze
					# Marc's current HUD deliberately retains shared HP/O2 in the
					# maze. Its World destination/controls must still relinquish
					# ownership; hiding the entire HUD would discard that feature.
					_expect(maze.maze_active and world.hp_bar.is_visible_in_tree()
						and world.oxygen_bar.is_visible_in_tree()
						and not world.route_objective_panel.is_visible_in_tree()
						and not world.get_node("HUD/Controls").is_visible_in_tree(),
						"GOAL-1 maze loses shared health or retains World guidance/controls: " + label)
					var goal := maze.get_node("HUD/GoalLabel") as Label
					var text := goal.text.to_lower()
					_expect(goal.is_visible_in_tree() and not "laboratory" in text and not "tethys" in text,
						"GOAL-1 early maze has hidden/stale laboratory goal: " + label)
					for bar in [world.hp_bar, world.oxygen_bar]:
						_expect(not goal.get_global_rect().intersects((bar.get_parent() as Control).get_global_rect()),
							"GOAL-8 shared health/Oxygen covers the restored maze destination: " + label)
					for row in world._party_bars_box.get_children():
						if row is Control and row.is_visible_in_tree():
							_expect(not goal.get_global_rect().intersects(row.get_global_rect()),
								"GOAL-8 side party bars cover the restored maze destination: " + label)
					_expect(root.get_visible_rect().encloses(goal.get_global_rect()),
						"GOAL-8 destination extends outside viewport: " + label)
					if not has_map:
						_expect("control room" in text and "map" in text, "GOAL-1 missing-map maze offers no actionable map goal: " + label)
						_expect(not "find the navigation map" in (maze.get_node("HUD/Controls") as Label).text.to_lower(),
							"GOAL-3 duplicate map instructions compete across status/goal surfaces: " + label)
					elif has_relic:
						_expect("cordys" in text and not "to the relic" in text,
							"GOAL-1 acquired relic leaves stale relic goal instead of Cordys: " + label)
					else:
						_expect("relic" in text and "cordys" in text,
							"GOAL-1 earned-map guidance omits exploration/final destination: " + label)
					if stale == "" and not lab_done and (has_map or not has_relic):
						await _capture("maze-relic" if has_relic else "maze-map" if has_map else "maze-before-map")
					_expect(world.route_state.lab_state == ("cleared" if lab_done else "locked"),
						"GOAL-1 maze entrance falsely advances laboratory: " + label)
					(world.divers[world.active] as Diver).global_position = Vector3(205, 2, -20)
					for frame in 4:
						await physics_frame
						await process_frame
					_expect(not maze.maze_active and world.get_node("HUD").visible,
						"GOAL-1 physical return retains maze HUD: " + label)
					_expect_deep(lab_done, label + " after return")
					cases += 1
	if findings.is_empty() and "--ownership" in OS.get_cmdline_user_args():
		await _goal_ownership()
	if "--shallows" in OS.get_cmdline_user_args():
		var data: Dictionary = JSON.parse_string(JSON.stringify(base))
		data.route_state.objective_id = "find_lab"
		data.route_state.deep_warning_seen = true
		for member in data.divers:
			member.position = [-30, 2, 30]
			member.sonar_active = false
		for member in data.campaign_checkpoint.party:
			member.sonar_active = false
		_expect(world.restore_checkpoint(data), "GOAL-2 recovered Shallows checkpoint rejected")
		await physics_frame
		await process_frame
		var text := world.route_objective_label.text.to_lower()
		_expect(world.route_objective_panel.is_visible_in_tree() and "shallows" in text and "stronger" in text
			and "laboratory" in text and "deeper water" in text,
			"GOAL-2 recovered Shallows offers no wider laboratory direction: " + text)
		await _capture("shallows")
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings.slice(0, 12):
		print("FINDING ", finding)
	print("CAMPAIGN GOALS|generated_cases=", cases, "|findings=", findings.size(), "|no_save_files=true")
	quit(0 if findings.is_empty() else 1)

func _expect_deep(lab_done: bool, label: String) -> void:
	var text := world.route_objective_label.text.to_lower()
	_expect(world.route_objective_panel.is_visible_in_tree(), "GOAL-1 Deep guidance is absent: " + label)
	if lab_done:
		_expect("maze" in text and "ramp" in text and not "confront tethys" in text and not "find the laboratory" in text,
			"GOAL-1 cleared laboratory gives stale/no maze-ramp direction: " + label + " => " + text)
	else:
		_expect("laboratory" in text and "maze" in text,
			"GOAL-1 independent destinations lost to stale objective: " + label + " => " + text)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_folder)
	_expect(root.get_texture().get_image().save_png(capture_folder + "/" + label + ".png") == OK,
		"GOAL-1/2 cannot capture actual rendered goal " + label)

func _goal_ownership() -> void:
	# This is an isolated caption fixture, not earned acquisition/travel.
	# Use the authored entry, which is inside the earned-map navigation region.
	# A generic maze-boundary position cannot open L even with the map acquired.
	# All three positions stay inside so actual Tab cannot hand back to World.
	var maze := world.embedded_maze
	var entry: Vector3 = maze.get_node("DiverEntry").global_position
	for index in 3:
		world.divers[index].global_position = entry + Vector3(0, 0, index * 0.3)
		world.divers[index].velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
	_expect(maze.nav_map_area().has_point(Vector2(maze._diver.global_position.x, maze._diver.global_position.z))
		and maze.key_items.has("maze_nav_map"), "GOAL-4 fixture lacks earned-map region access")
	var goal := maze.get_node("HUD/GoalLabel") as Label
	var controls := maze.get_node("HUD/Controls") as Label
	var purpose := goal.text
	_expect(maze.maze_active and goal.is_visible_in_tree() and not controls.visible
		and not "E:" in purpose and not "F:" in purpose,
		"GOAL-4 restored destination is hidden or restores retired generic hints")
	await _capture("goal-before-owners")
	await _key(KEY_R)
	_expect(maze._banner.is_visible_in_tree() and not goal.is_visible_in_tree(),
		"GOAL-4 destination competes with actual R notice")
	await create_timer(4.3).timeout
	_expect(goal.is_visible_in_tree() and goal.text == purpose and not controls.visible,
		"GOAL-4 drained notice loses destination or revives generic controls")
	await _key(KEY_ESCAPE)
	_expect(maze.inventory_menu.visible and not goal.is_visible_in_tree(),
		"GOAL-4 destination competes with actual Inventory reading")
	_expect(not world.hp_bar.is_visible_in_tree() and not world.oxygen_bar.is_visible_in_tree()
		and not world._party_bars_box.is_visible_in_tree(),
		"GOAL-9 shared health paints above embedded Inventory reading")
	await _key(KEY_ESCAPE)
	_expect(not maze.inventory_menu.visible and goal.is_visible_in_tree(),
		"GOAL-4 closing Inventory loses destination")
	_expect(world.hp_bar.is_visible_in_tree() and world.oxygen_bar.is_visible_in_tree(),
		"GOAL-9 closing embedded Inventory loses shared exploration health")
	await _key(KEY_L)
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	_expect(map.main_map.visible and not goal.is_visible_in_tree(),
		"GOAL-4 first map/lesson overlays the destination")
	var panel := root.get_node("CharacterAbilityPopup/%AbilityExplanationPanel") as Control
	if panel.visible:
		await _key(KEY_ESCAPE)
	_expect(not paused and map.main_map.visible and not goal.is_visible_in_tree(),
		"GOAL-4 lesson dismissal reveals destination behind still-open overview")
	await _capture("goal-map-owner")
	await _key(KEY_L)
	_expect(not map.main_map.visible and goal.is_visible_in_tree() and not controls.visible,
		"GOAL-4 closing overview loses goal or restores generic controls")
	for row in world._party_bars_box.get_children():
		if row is Control and row.is_visible_in_tree():
			_expect(not goal.get_global_rect().intersects(row.get_global_rect()),
				"GOAL-8 first earned-map close overlaps side party labels")
	await _key(KEY_TAB)
	_expect(maze._diver.ability_id == "grapple", "GOAL-4 actual Tab did not select grapple diver")
	# Switching divers legitimately owns the caption with 'Now playing'. Let
	# that real notice drain before isolating aim/cancel destination ownership.
	await create_timer(4.3).timeout
	_expect(goal.is_visible_in_tree(), "GOAL-4 diver-switch notice never returns destination")
	await _key(KEY_F)
	for frame in 3:
		await physics_frame
	_expect(maze.aiming and not goal.is_visible_in_tree(),
		"GOAL-4 destination competes with actual grapple aim")
	var controls_column := maze.get_node("HUD/MazeExplorationControls") as Control
	_expect(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(controls_column.get_global_rect()),
		"GOAL-5 actual aim instructions expand beyond the viewport and clip fire/cancel controls")
	await _capture("goal-aim-owner")
	await _key(KEY_ESCAPE)
	_expect(not maze.aiming and not maze.inventory_menu.visible and goal.is_visible_in_tree()
		and goal.text == purpose and not controls.visible,
		"GOAL-4 aim cancel loses goal, stacks Inventory or restores retired controls")
	await _capture("goal-after-owners")
	print("CAMPAIGN GOAL OWNERSHIP|actual_R_Escape_L_Tab_F=", findings.is_empty(),
		"|retired_hints=false|no_save_files=true")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)
	for frame in 3:
		await physics_frame
		await process_frame
