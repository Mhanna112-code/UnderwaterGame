extends SceneTree
## END-1/3: real confirmed victory must become a visible durable ending.
## Supplied level5 kit/room/key fixture isolates ending, NOT earned balance.
const SLOT := 918425
var findings: Array[String] = []
var world: World
var owns_slot := false
var denied_staging := false

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
	if "--denied" in OS.get_cmdline_user_args():
		_expect(DirAccess.make_dir_recursive_absolute(path + ".pending") == OK, "END-2 denied staging fixture failed")
		denied_staging = true
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
	if denied_staging:
		_expect(FileAccess.get_file_as_bytes(path) == initial_bytes and world._current_slot == SLOT,
			"END-2 denied completion write destroyed previous bytes or selected slot")
		_expect(screen.retry_button.visible and screen.title_button.disabled and "could not be saved" in screen.status.text,
			"END-2 denied write falsely promises saved exit or offers no retry")
		await _capture("denied")
		_expect(DirAccess.remove_absolute(path + ".pending") == OK, "END-2 cannot release owned denied staging")
		denied_staging = false
		screen.retry_button.pressed.emit()
		for frame in 12:
			await process_frame
		_expect(not screen.title_button.disabled and not screen.retry_button.visible,
			"END-2 actual Retry cannot durably save the completed live party")
	var saved := SaveManager.read_slot(SLOT)
	_expect(saved.get("route_state", {}).get("octopus_state", "") == "defeated", "END-1 victory did not durably record completion")
	_expect(saved.get("campaign_checkpoint", {}).get("maze", {}).get("boss_triggers", []).has("main_boss") == false,
		"END-1 ending checkpoint retains the live boss station")
	_expect(world.route_state.tethys_state == "locked" and maze._boss_triggers.has("secret_boss"), "END-1 victory incorrectly completed lab or puppets")
	print("CAMPAIGN ENDING|actions=", actions, "|outcomes=", outcomes, "|visible_screens=", screens.size(), "|durable=", saved.get("route_state", {}).get("octopus_state", ""))
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
	# END-3: actual title button destroys World; chosen-slot Load must conserve
	# the exact earned state and show completion without writing/rewarding again.
	var completed_bytes := FileAccess.get_file_as_bytes(path)
	screen.title_button.pressed.emit()
	for frame in 16:
		await process_frame
	world = current_scene as World
	_expect(world != null and world.title_screen.visible and paused, "END-3 Return to Title failed actual scene boundary")
	world.title_screen.load_game_chosen.emit(SLOT)
	for frame in 16:
		await process_frame
	maze = world.embedded_maze
	screens = get_nodes_in_group("campaign_completion")
	_expect(screens.size() == 1 and paused and not world.title_screen.visible,
		"END-3 cold Title Load resumes gameplay instead of showing saved ending")
	_expect(not maze._boss_triggers.has("main_boss") and not maze._battling
		and world.route_state.prologue_complete and world.route_state.octopus_state == "defeated",
		"END-3 cold Load resurrects boss or rewinds opening")
	_expect(FileAccess.get_file_as_bytes(path) == completed_bytes, "END-3 loading ending rewrites checkpoint or duplicates rewards")
	for index in 3:
		var stats := world.divers[index].stats as CombatantStats
		var expected: Dictionary = saved.campaign_checkpoint.party[index].stats
		_expect(stats.hp == expected.hp and stats.xp == expected.xp and stats.level == expected.level
			and is_equal_approx(stats.oxygen, expected.oxygen), "END-3 Load refills or duplicates party resources/XP")
	print("CAMPAIGN ENDING|denied_retry=", "--denied" in OS.get_cmdline_user_args(), "|held_input=true|widths=1280,720,360|Title_Load=true|rewards_conserved=true")
	await _capture("loaded")
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
		if denied_staging:
			DirAccess.remove_absolute(SaveManager.slot_path(SLOT) + ".pending")
		for path in [SaveManager.slot_path(SLOT), SaveManager.slot_path(SLOT) + ".pending"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	for finding in findings:
		print("FINDING ", finding)
	print("CAMPAIGN COMPLETION: clean" if findings.is_empty() else "CAMPAIGN COMPLETION: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
