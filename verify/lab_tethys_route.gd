# Normal-play laboratory entry and Tethys lifecycle.
#
# Catches LAB-TETHYS-001/002/003/010 from the adjacent bug catalog without
# using the isolated boss query-string shortcut.
# Usage: godot --headless --path . --script verify/lab_tethys_route.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	world.skip_boss_intro_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	world._first_encounter_done = true
	world.route_state.set_zone("deep")
	world.route_state.set_blocker_state("bomb_bot", "defeated")
	world.route_state.set_blocker_state("sword_slayer", "defeated")
	world.route_state.set_lab_state("available")
	world.route_state.set_tethys_state("locked")
	# The maze is an already-open independent Deep branch. Lab victory may
	# guide the next objective there, but must not be what unlocks it.
	world.route_state.set_maze_door_state("available")
	world.route_state.set_objective("find_lab")
	world._sync_deep_zone_blocker_staging()
	await physics_frame

	_expect(world.has_method("_update_lab_route"),
		"LAB-TETHYS-001: production World has no normal-play laboratory route owner")
	if world.has_method("_update_lab_route"):
		var diver := world.divers[world.active] as Diver
		diver.global_position = world.deep_zone_layout.route_points().lab as Vector3
		world._update_lab_route()
		await process_frame
		_expect(world.route_state.lab_state == "cutscene",
			"LAB-TETHYS-001: entering the unlocked laboratory did not begin the cutscene")
		var cutscenes := _owned_group(world, "lab_video_cutscene")
		_expect(cutscenes.size() == 1 and bool((cutscenes[0] as CanvasLayer).visible),
			"LAB-TETHYS-001: unlocked lab entry has no single visible Mermaid cutscene")
		world._update_lab_route()
		await process_frame
		_expect(_owned_group(world, "lab_video_cutscene").size() == 1,
			"LAB-TETHYS-010: remaining in the lab trigger duplicated the cutscene")
		if cutscenes.size() == 1:
			var cutscene := cutscenes[0] as Node
			_expect(cutscene.has_signal("completed"),
				"LAB-TETHYS-002: Mermaid cutscene exposes no completion contract")
			if cutscene.has_signal("completed"):
				cutscene.call("_complete", true)
				await process_frame
				await process_frame
				_expect(world.battling and world.battle != null,
					"LAB-TETHYS-002: skipping the Mermaid cutscene did not start Tethys")
				if world.battle != null:
					_expect(world.battle.boss_encounter,
						"LAB-TETHYS-002: lab handoff started a non-boss battle")
					_expect(world.battle.encounter_source == "lab_boss",
						"LAB-TETHYS-002: lab handoff lost its authored encounter source")
					_expect(not world.battle.get_tree().get_nodes_in_group("boss_lab_stage").filter(
						func(node: Node) -> bool: return world.battle.is_ancestor_of(node)).is_empty(),
						"LAB-TETHYS-006: Tethys battle still uses the generic empty-water stage")
					_expect(world.route_state.lab_state == "boss" and world.route_state.tethys_state == "in_progress",
						"LAB-TETHYS-002: route contract did not enter the Tethys fight")
					var interiors := _owned_group(world, "lab_interior")
					_expect(interiors.size() == 1 and (interiors[0] as Node3D).visible,
						"LAB-TETHYS-006: Tethys battle did not reveal the concealed Broken Office stage")
					world._on_battle_finished("won")
					await process_frame
					_expect(world.route_state.lab_state == "cleared" and world.route_state.tethys_state == "defeated",
						"LAB-TETHYS-005: victory did not persist laboratory/Tethys completion")
					_expect(world.route_state.maze_door_state == "available" and world.route_state.objective_id == "enter_maze",
						"LAB-TETHYS-005: victory did not preserve the separate maze branch and guide the next objective")

	# LAB-TETHYS-004: neither a decoder nor a live battle can be restored.
	for transient in [
		{"lab": "cutscene", "tethys": "available"},
		{"lab": "boss", "tethys": "in_progress"},
	]:
		world.route_state.set_lab_state(String(transient.lab))
		world.route_state.set_tethys_state(String(transient.tethys))
		world.route_state.set_encounter_source("lab_boss")
		world._normalize_loaded_route_state()
		_expect(world.route_state.lab_state == "available"
			and world.route_state.tethys_state == "available"
			and world.route_state.objective_id == "find_lab"
			and world.route_state.encounter_source == "random",
			"LAB-TETHYS-004: transient %s/%s save did not normalize to a retryable entrance" % [transient.lab, transient.tethys])

	if world.battle != null:
		world.battle.queue_free()
		world.battle = null
	world.queue_free()
	await process_frame
	await process_frame
	var audio_owner := root.get_node_or_null("GameAudio")
	if audio_owner != null:
		audio_owner.call("release_streams_for_shutdown")
	await process_frame
	await create_timer(0.15).timeout
	for finding in findings:
		print("FINDING  " + finding)
	print("LAB TETHYS ROUTE: clean" if findings.is_empty() else "LAB TETHYS ROUTE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _owned_group(world: World, group_name: String) -> Array:
	return root.get_tree().get_nodes_in_group(group_name).filter(
		func(node: Node) -> bool: return world.is_ancestor_of(node))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
