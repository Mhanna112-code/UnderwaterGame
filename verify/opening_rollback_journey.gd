# OPEN-044: restoring the swimming/Angler entry must still reach saved recovery
# and not replay combat on fresh title Load. Movies only are fast-forwarded;
# all damage, enemy death and player choices use the existing real buttons.
extends "res://verify/opening_prologue_journey.gd"

func _run() -> void:
	var world := await _fresh_opening_world()
	world.skip_intro_for_test = true
	await world._on_title_new_game(SLOT)
	var swim := InputEventKey.new()
	swim.keycode = KEY_W
	swim.physical_keycode = KEY_W
	swim.pressed = true
	Input.parse_input_event(swim)
	await _wait_phase(world, "angler", 10.0)
	swim.pressed = false
	Input.parse_input_event(swim)
	await process_frame
	if world.battle == null or world.route_state.prologue_phase != "angler":
		findings.append("OPEN-044 movement did not start actual Angler combat")
		await _finish(world)
		return
	var original := world.battle
	_expect(original.enemies.size() == 1 and String(original.enemies[0].display_name) == "Angler", "OPEN-043 initial roster is not Angler")
	var deadline := Time.get_ticks_msec() + 45000
	var angler_actions := 0
	while world.route_state.prologue_phase == "angler" and Time.get_ticks_msec() < deadline:
		if original.attack_btn.is_visible_in_tree() and not original.attack_btn.disabled:
			await _attack(original)
			angler_actions += 1
		await create_timer(0.1).timeout
	await _wait_phase(world, "octopus_introduction", 15.0)
	_expect(angler_actions > 0 and (original.enemies[0].stats as CombatantStats).hp == 0, "OPEN-044 Cordys introduction did not follow an actual Angler defeat")
	var movie := await _wait_movie()
	if movie == null:
		findings.append("OPEN-044 Angler victory did not reach the existing later movie")
		await _finish(world)
		return
	movie.pause_introduction_for_test()
	await _wait_phase(world, "octopus_response", 15.0)
	_expect(world.battle == original and String(original.enemies[0].display_name) == "Cordys", "OPEN-044 later Cordys interruption lost the existing Battle owner")
	deadline = Time.get_ticks_msec() + 60000
	var cordys_actions := 0
	while world.route_state.prologue_phase != "octopus_aftermath" and Time.get_ticks_msec() < deadline:
		if original.attack_btn.is_visible_in_tree() and not original.attack_btn.disabled:
			await _attack(original)
			cordys_actions += 1
		await create_timer(0.1).timeout
	_expect(world.route_state.prologue_phase == "octopus_aftermath" and cordys_actions > 0, "OPEN-044 genuine Cordys responses never reached aftermath")
	if is_instance_valid(movie):
		movie.finish_for_test()
	await _wait_phase(world, "recovery", 20.0)
	var continued := _find_button(world, "Continue")
	var saved := SaveManager.read_slot(SLOT)
	_expect(continued != null and (saved.get("route_state", {}) as Dictionary).get("prologue_complete", false), "OPEN-044 recovery lacks Continue or saved completion")
	_expect(world.route_state.octopus_state == "unavailable", "OPEN-044 opening changed the real final-boss completion state")
	for value in world.divers:
		var diver := value as Diver
		_expect(diver.stats.hp == diver.stats.hp_max and diver.stats.oxygen >= diver.stats.oxygen_max - 0.1, "OPEN-044 recovery did not restore the party")
		_expect(diver.stats.xp == 0 and diver.known_spells.is_empty(), "OPEN-044 opening granted unearned progression")
	if continued != null:
		continued.emit_signal("pressed")
	await process_frame
	await process_frame
	_expect(not paused and not world.battling and world.route_state.prologue_phase == "complete", "OPEN-044 recovery Continue failed to return World")
	world.queue_free()
	await process_frame
	paused = false
	var loaded := await _fresh_opening_world()
	await loaded._on_title_load_game(SLOT)
	await create_timer(2.0).timeout
	_expect(loaded.route_state.prologue_complete and loaded.route_state.prologue_phase == "complete", "OPEN-044 title Load lost completed recovery")
	_expect(not loaded.battling and get_nodes_in_group("opening_video").is_empty() and get_nodes_in_group("prologue_cinematic").is_empty(), "OPEN-044 title Load replayed opening movies or boss combat")
	print("OPENING_ROLLBACK_JOURNEY|angler_actions=%d|cordys_actions=%d|completed_load=%s" % [angler_actions, cordys_actions, str(loaded.route_state.prologue_complete)])
	await _finish(loaded)

func _fresh_opening_world() -> World:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	return world
