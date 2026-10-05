extends SceneTree
## GOAL-1: restored milestones and real area handoff must replace stale goals.
## Checkpoint/position fixtures isolate presentation, NOT an earned journey.
var findings: Array[String] = []
var world: World
var cases := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
					_expect(maze.maze_active and not world.get_node("HUD").visible,
						"GOAL-1 physical early entry rejected or World HUD still owns maze: " + label)
					var goal := maze.get_node("HUD/GoalLabel") as Label
					var text := goal.text.to_lower()
					_expect(goal.is_visible_in_tree() and not "laboratory" in text and not "tethys" in text,
						"GOAL-1 early maze has hidden/stale laboratory goal: " + label)
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
	var folder := "/private/tmp/campaign-goals-visual-oct5"
	DirAccess.make_dir_recursive_absolute(folder)
	_expect(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK,
		"GOAL-1/2 cannot capture actual rendered goal " + label)
