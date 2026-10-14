# Opening video -> Cordys introduction -> Cordys battle integration.
#
# Bugs caught:
# - OPEN-007: New Game after the opening still waits for free swimming, starts
#   an Angler, or creates duplicate prologue Battles.
# - OPEN-008: the retired mandatory tutorial beam, random encounters, route
#   systems, or camera capture compete before recovery.
# - OPEN-042: the Angler (fight, victory bridge or actor) is still part of the
#   prologue; the Cordys battle must start right after the cinematic intro.
# - OPEN-043: a run saved before Cordys (including old free-swim/Angler-era
#   saves) does not resume at the cinematic introduction and Cordys battle.
#
# Usage: godot --headless --path . --script verify/opening_prologue_world.gd
extends SceneTree

const TEST_SLOT := 918298
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_save()
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var phases: Array[String] = []
	world.route_state.phase_changed.connect(func(phase: String) -> void: phases.append(phase))
	await world._on_title_new_game(TEST_SLOT)
	await process_frame
	await _check_introduction_to_cordys(world, "new game")
	_expect(phases == ["spawn_exploration", "octopus_introduction", "octopus_reveal", "octopus_response"],
		"OPEN-042 new-game phases are not opening -> introduction -> Cordys: %s" % [phases])
	world.queue_free()
	await process_frame
	paused = false

	# OPEN-043: an incomplete-prologue save written after the opening (the old
	# free-swim/Angler era wrote the same milestones, plus a stale source).
	var fixture := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(fixture)
	current_scene = fixture
	await process_frame
	await process_frame
	var checkpoint := fixture._serialize_state()
	checkpoint.route_state = {"opening_video_seen": true, "prologue_complete": false, "tutorial_complete": false, "encounter_source": "prologue_angler"}
	_expect(SaveManager.write_slot(TEST_SLOT, checkpoint) == OK, "OPEN-043 could not write the owned test checkpoint")
	fixture.title_screen.load_game_chosen.emit(TEST_SLOT)
	for _i in range(4):
		await process_frame
	# The Cordys introduction shares the opening_video owner group; only it may exist.
	_expect(get_nodes_in_group("opening_video").all(func(node: Node) -> bool: return node.is_in_group("prologue_cinematic")),
		"OPEN-043 loaded pre-Cordys save replays the opening video")
	await _check_introduction_to_cordys(fixture, "load")
	fixture.queue_free()
	await process_frame
	paused = false

	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	_remove_test_save()
	_finish()

func _check_introduction_to_cordys(world: World, label: String) -> void:
	_expect(world.route_state.prologue_phase == "octopus_introduction", "OPEN-007 %s did not go straight to the Cordys introduction (phase %s)" % [label, world.route_state.prologue_phase])
	_expect(not world.route_state.prologue_complete, "OPEN-008 %s incorrectly completed the prologue" % label)
	_expect(not world._intro_active, "OPEN-008 %s: mandatory tutorial capture remains active" % label)
	_expect(not is_instance_valid(world.light_beam), "OPEN-008 %s: mandatory tutorial beam remains" % label)
	_expect(not is_instance_valid(world._intro_arrow), "OPEN-008 %s: mandatory tutorial arrow remains" % label)
	_expect(world._camera_look_override == null, "OPEN-008 %s: prologue still captures the camera" % label)
	_expect(not world.has_method("_update_prologue_trigger"), "OPEN-042 %s: World still has the free-swim Angler trigger" % label)
	var movie := get_first_node_in_group("prologue_cinematic") as CanvasLayer
	_expect(movie != null and movie.visible, "OPEN-042 %s: no visible Cordys introduction movie" % label)
	_expect(paused and not world.battling and world.battle == null, "OPEN-042 %s: a battle started under the introduction" % label)
	_expect(root.get_node("GameAudio").get_music_state().phase == "stopped", "OPEN-005 %s: music overlaps the Cordys introduction" % label)

	# A random-encounter signal under the movie must be ignored.
	world._on_encounter_triggered(world.divers[world.active] as Diver)
	_expect(not world.battling, "OPEN-008 %s: random encounter preempted the prologue" % label)
	# Holding swim input under the movie must not start anything either.
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.5).timeout
	key.pressed = false
	Input.parse_input_event(key)
	_expect(world.battle == null and world.route_state.prologue_phase == "octopus_introduction", "OPEN-042 %s: swimming under the introduction changed the prologue" % label)
	if movie == null:
		return

	movie.call("pause_introduction_for_test")
	await process_frame
	_expect(world.battling and world.battle != null, "OPEN-042 %s: introduction did not start the Cordys battle" % label)
	if world.battle == null:
		return
	var fight := world.battle
	_expect(world.route_state.encounter_source == "prologue_octopus" and fight.encounter_source == "prologue_octopus", "OPEN-042 %s: battle source is not prologue_octopus" % label)
	_expect(fight.prologue_octopus_encounter, "OPEN-042 %s: World started an ordinary battle instead of Cordys" % label)
	_expect(fight.enemies.size() == 1 and String(fight.enemies[0].display_name) == "Cordys" and fight.enemies[0].actor is PrologueOctopus,
		"OPEN-042 %s: the first battle frame is not Cordys alone: %s" % [label, fight.enemies.map(func(e: Dictionary) -> String: return String(e.display_name))])
	_expect(_stage_has_no_grunt(fight), "OPEN-042 %s: an Angler/grunt actor is on the prologue stage" % label)
	_expect(get_nodes_in_group("prologue_victory_bridge").is_empty(), "OPEN-042 %s: Angler victory bridge appeared" % label)
	_expect(not paused, "OPEN-042 %s: tree stayed paused after the introduction" % label)
	var deadline := Time.get_ticks_msec() + 10000
	while world.route_state.prologue_phase != "octopus_response" and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(world.route_state.prologue_phase == "octopus_response", "OPEN-042 %s: Cordys reveal never handed the player a turn" % label)
	_expect(not fight.attack_btn.disabled and fight.attack_btn.is_visible_in_tree(), "OPEN-014 %s: Cordys response has no usable Attack" % label)
	_expect(not fight.run_btn.visible and not fight.items_btn.visible, "OPEN-014 %s: scripted prologue offers Run/Items" % label)
	_expect(root.get_node("GameAudio").get_music_state().cue_id == "cordys", "OPEN-005 %s: Cordys battle did not start the Cordys cue" % label)
	_expect(is_instance_valid(movie) and not movie.visible, "OPEN-023 %s: introduction owner was not retained hidden for the aftermath" % label)
	await physics_frame
	await physics_frame
	_expect(world.battle == fight, "OPEN-007 %s: repeated frames replaced/duplicated the prologue Battle" % label)

func _stage_has_no_grunt(fight: Battle) -> bool:
	for node in fight._stage_vp.find_children("*", "", true, false):
		if node is Goblin:
			return false
	return true

func _remove_test_save() -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	for path in [absolute, absolute + ".pending"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	SaveManager.clear_autosave(TEST_SLOT)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING PROLOGUE WORLD: clean" if findings.is_empty() else "OPENING PROLOGUE WORLD: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
