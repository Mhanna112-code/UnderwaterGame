extends SceneTree
## END-1/3: real victory must show completion and retain its pre-boss restart.
## Supplied level5 kit/room/key fixture isolates ending, NOT earned balance.
const SLOT := 918425
var findings: Array[String] = []
var world: World
var owns_slot := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := SaveManager.slot_path(SLOT)
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".pending") or DirAccess.dir_exists_absolute(path + ".pending"):
		print("Refusing existing completion fixture: ", path)
		quit(1)
		return
	owns_slot = true
	Engine.time_scale = 10.0
	seed(77124)
	root.size = Vector2i(1280, 720)
	world = load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world._current_slot = SLOT
	world.random_encounters_enabled = false
	for diver in world.divers:
		while diver.stats.level < 5:
			diver.stats.gain_xp(10)
		SpellTree.learn_all_available(diver, [])
	world._set_maze_ownership(true)
	var maze := world.embedded_maze
	var door := maze.get_node("MazeDoorMainBoss") as KeyDoor
	maze.keys_held = 1
	maze._diver.global_position = door.global_position + Vector3(-1.5, 1.2, 0)
	await _key(KEY_E)
	await create_timer(1.5).timeout
	_expect(door.is_open() and maze.keys_held == 0, "END-1 room fixture failed real key interaction")
	_expect(SaveManager.write_slot(SLOT, world._serialize_state()) == OK, "END-1 initial disposable checkpoint failed")
	var initial_bytes := FileAccess.get_file_as_bytes(path)
	var station := maze._boss_triggers.get("main_boss") as Node3D
	maze._diver.global_position = station.global_position + Vector3(-4, 1.2, 0)
	for frame in 20:
		await physics_frame
		if maze.any_modal_open():
			break
	_expect(maze.any_modal_open() and not maze._battling, "END-1 approach bypasses confirmation")
	await _key(KEY_Y)
	var battle := maze._battle as Battle
	if battle == null:
		findings.append("END-1 confirmed approach did not start battle")
		await _finish()
		return
	_expect((battle.enemies[0].stats as CombatantStats).hp_max == 75, "END-1 fixture changed authored boss HP")
	var outcomes: Array[String] = []
	battle.finished.connect(func(result: String) -> void: outcomes.append(result))
	var actions := 0
	var deadline := Time.get_ticks_msec() + 90000
	while outcomes.is_empty() and Time.get_ticks_msec() < deadline and actions < 90:
		if battle._tutorial_awaiting_enter:
			await _key(KEY_ENTER)
		if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
			var model := String(battle._acting.model_name)
			var move := "Swift Strike" if model == "Staff_Diver" else "Precise Jab" if model == "Prototype_1(1910)" else "Guard Bash"
			var target := "Cordys"
			for entry in battle.party:
				var stats := entry.stats as CombatantStats
				if model == "Staff_Diver" and stats.hp > 0 and stats.hp <= 6 and (battle._acting.stats as CombatantStats).oxygen >= 16:
					move = "Healing Current"
					target = String(entry.display_name)
					break
			if not await _choose(battle, move, target):
				findings.append("END-1 legal move unavailable: " + move)
				break
			actions += 1
		await process_frame
	_expect(outcomes == ["won"], "END-1 no actual legal-kit victory: " + str(outcomes))
	for frame in 12:
		await process_frame
	var screens := get_nodes_in_group("campaign_completion")
	_expect(screens.size() == 1 and (screens[0] as CanvasLayer).visible,
		"END-1 real victory has no single visible game-completion screen")
	_expect(paused, "END-1 victory leaves exploration running instead of completing")
	if screens.size() != 1:
		await _finish()
		return
	var screen := screens[0] as CanvasLayer
	# Miguel confirmed Marc's pre-boss-only contract on October 5:
	# the ending writes no completion save; it offers the
	# autosave taken the moment the Cordys fight was confirmed.
	_expect(not screen.restart_button.disabled and "autosaved right before" in screen.status.text,
		"END-1 ending offers no Restart from Auto Save")
	var auto := SaveManager.read_autosave(SLOT)
	_expect(not auto.is_empty() and auto.get("route_state", {}).get("octopus_state", "") != "defeated",
		"END-1 pre-boss autosave missing or already records the win")
	_expect(auto.get("campaign_checkpoint", {}).get("maze", {}).get("boss_triggers", []).has("main_boss"),
		"END-1 pre-boss autosave lost the Cordys station")
	_expect(SaveManager.read_slot(SLOT).get("route_state", {}).get("octopus_state", "") != "defeated",
		"END-1 ending still wrote a completion save")
	_expect(FileAccess.get_file_as_bytes(path) == initial_bytes,
		"END-1 ending changed the player's existing manual checkpoint")
	_expect(world.route_state.tethys_state == "locked" and maze._boss_triggers.has("secret_boss"), "END-1 victory incorrectly completed lab or puppets")
	print("CAMPAIGN ENDING|actions=", actions, "|outcomes=", outcomes, "|visible_screens=", screens.size(), "|pre_boss_autosave=", not auto.is_empty())
	# END-4: actual held movement/selection/menu keys cannot change the frozen party.
	var positions := world.divers.map(func(d: Diver) -> Vector3: return d.global_position)
	var active_before := world.active
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	await _key(KEY_TAB)
	await _key(KEY_P)
	for frame in 20:
		await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	_expect(world.active == active_before and not world.save_point_menu.visible,
		"END-4 completion input changes selection or opens world menus")
	for index in 3:
		_expect(world.divers[index].global_position.is_equal_approx(positions[index]), "END-4 swimming leaks behind ending")
	for width in [1280, 720, 360]:
		root.size = Vector2i(width, 720)
		for frame in 4:
			await process_frame
		var bounds: Rect2 = screen.title_button.get_global_rect()
		_expect(bounds.position.x >= 0 and bounds.end.x <= width and bounds.end.y <= 720,
			"END-4 title choice clips viewport width " + str(width))
		await _capture("saved-%d" % width)
	# END-3: Restart from Auto Save reloads the scene and resumes right before
	# the Cordys fight - station back, not defeated, exploration running.
	screen.restart_button.pressed.emit()
	for frame in 30:
		await process_frame
	world = current_scene as World
	_expect(world != null and not world.title_screen.visible and not paused, "END-3 restart did not resume gameplay")
	maze = world.embedded_maze if world != null else null
	_expect(maze != null and maze.maze_active and maze._boss_triggers.has("main_boss")
		and world.route_state.octopus_state != "defeated",
		"END-3 restart did not return to just before the Cordys fight")
	_expect(get_nodes_in_group("campaign_completion").is_empty(), "END-3 restart left the ending screen up")
	await _capture("loaded")
	# Destroy the scene again and Load the selected slot's actual autosave.
	# This must work without the just-used in-memory restart envelope.
	var auto_bytes := FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT))
	world._on_game_over_title()
	for frame in 20:
		await process_frame
	world = current_scene as World
	world.title_screen.load_autosave_chosen.emit(SLOT)
	for frame in 30:
		await process_frame
	_expect(not paused and not world.title_screen.visible and world.embedded_maze.maze_active
		and world.embedded_maze._boss_triggers.has("main_boss") and world.route_state.octopus_state != "defeated",
		"END-3 fresh title autosave Load does not return before Cordys")
	var loaded := world._serialize_state()
	for index in 3:
		var expected: Dictionary = auto.campaign_checkpoint.party[index].stats
		var actual: Dictionary = loaded.campaign_checkpoint.party[index].stats
		for field in ["hp", "oxygen", "xp", "level"]:
			_expect(actual[field] == expected[field], "END-3 pre-boss Load changes party resource " + field)
	_expect(FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT)) == auto_bytes,
		"END-3 reading the pre-boss autosave rewrites its bytes")
	await _finish()

func _capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var folder := "/private/tmp/campaign-ending-visual-oct5"
	DirAccess.make_dir_recursive_absolute(folder)
	_expect(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK,
		"END-4 cannot capture rendered ending " + label)

func _choose(battle: Battle, move: String, target: String) -> bool:
	battle.attack_btn.pressed.emit()
	await process_frame
	var chosen: Button
	for button in battle.move_buttons:
		if (button as Button).text.get_slice("\n", 0) == move and not (button as Button).disabled:
			chosen = button as Button
	if chosen == null:
		return false
	var pages := 0
	while not chosen.is_visible_in_tree() and pages < 8 and not battle._move_down_btn.disabled:
		battle._move_down_btn.pressed.emit()
		await process_frame
		pages += 1
	if not chosen.is_visible_in_tree():
		return false
	chosen.pressed.emit()
	await process_frame
	for button in battle.target_buttons:
		if (button as Button).text.begins_with(target) and not (button as Button).disabled:
			(button as Button).pressed.emit()
			return true
	return false

func _key(key: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	Engine.time_scale = 1.0
	if owns_slot:
		for path in [SaveManager.slot_path(SLOT), SaveManager.slot_path(SLOT) + ".pending", SaveManager.autosave_path(SLOT)]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	for finding in findings:
		print("FINDING ", finding)
	print("CAMPAIGN COMPLETION: clean" if findings.is_empty() else "CAMPAIGN COMPLETION: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
