extends SceneTree
## INT-03: actual maze wins must learn from campaign relics, not maze door keys.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	Engine.time_scale = 12.0
	for sample in [
		["reef_plate", "tidal_revival", 2],
		["sunken_core", "guard_break", 2],
		["abyssal_lens", "riptide_slash", 0],
		["current_pearl", "tidal_burst", 0],
	]:
		for present in [true, false]:
			await _case(sample[0], sample[1], sample[2], present)
			if not findings.is_empty():
				break
		if not findings.is_empty():
			break
	Engine.time_scale = 1.0
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE RELIC CONSUMERS: clean" if findings.is_empty() else "MAZE RELIC CONSUMERS: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _case(relic: String, spell: String, owner: int, present: bool) -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = false
	world.route_state.set_zone("deep")
	world.route_state.set_maze_door_state("available")
	for diver in world.divers:
		while diver.stats.level < 8:
			diver.stats.gain_xp(10)
		SpellTree.learn_all_available(diver, [])
	if relic == "current_pearl":
		SpellTree.learn_all_available(world.divers[0], ["abyssal_lens"])
		# Earn the next point(s) normally; the fixture needs the pearl's cost
		# after its earlier prerequisite was learned, not impossible equipment.
		while world.divers[0].stats.spell_points < 3:
			world.divers[0].stats.gain_xp(10)
	if present:
		world.key_items.append(relic)
	world.divers[0].global_position = world.deep_zone_layout.route_points().maze_transition
	for frame in range(20):
		await physics_frame
		if current_scene is MazeLevel:
			break
	if not current_scene is MazeLevel:
		findings.append("INT-03 actual World entrance did not reach Maze")
		return
	var maze := current_scene as MazeLevel
	maze.keys_held = 1
	maze.key_items.assign(["vortex_key"] if present else [relic])
	var door := maze.get_node("MazeDoor16") as KeyDoor
	maze.divers[0].global_position = door.global_position + Vector3.UP
	_expect(door.interact(maze.divers[0]), "INT-03 real maze door refused its key")
	await create_timer(1.5).timeout
	_expect(maze.keys_held == 0 and maze.campaign_key_items.has(relic) == present,
		"INT-03 door consumed a campaign relic or retained spent maze key")
	# Placement is a disclosed fixture, not a navigation proof. Normal contact
	# still owns its warning; dismiss it before sending the public encounter event.
	var room: Rect2 = maze.strong_zone_for_map({})
	if room.size == Vector2.ZERO:
		room = maze._strong_room_rect()
	maze.divers[0].global_position = Vector3(room.get_center().x, 0, room.get_center().y)
	await physics_frame
	await process_frame
	var popup := root.get_node_or_null("CharacterAbilityPopup")
	if popup != null and paused:
		(popup.get_node("%PopupClose") as Button).pressed.emit()
		await process_frame
	seed(62117)
	EnemyRoster._rng.seed = 62117
	maze.divers[0].encounter_triggered.emit()
	await process_frame
	var battle: Battle
	for child in maze.get_children():
		if child is Battle:
			battle = child as Battle
	if battle == null:
		findings.append("INT-03 actual strong-room encounter did not start")
		maze.queue_free()
		await process_frame
		return
	maze.room_encounters_enabled = false
	var outcomes: Array[String] = []
	battle.finished.connect(func(result: String) -> void: outcomes.append(result))
	var deadline := Time.get_ticks_msec() + 40000
	var actions := 0
	while outcomes.is_empty() and Time.get_ticks_msec() < deadline and actions < 80:
		if battle._tutorial_awaiting_enter:
			var enter := InputEventKey.new()
			enter.keycode = KEY_ENTER
			enter.pressed = true
			Input.parse_input_event(enter)
		if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
			var model := String(battle._acting.model_name)
			var move := "Swift Strike" if model == "Staff_Diver" else "Precise Jab" if model == "Prototype_1(1910)" else "Guard Bash"
			_expect(await _choose(battle, move), "INT-03 actual move inaccessible: " + move)
			actions += 1
		await process_frame
	var result := outcomes[0] if not outcomes.is_empty() else "timeout"
	_expect(result == "won", "INT-03 consumer fixture did not win actual fight: " + result)
	_expect(maze.divers[owner].known_spells.has(spell) == present
		and maze.divers[owner].equipped_spells.has(spell) == present,
		"INT-03 actual maze victory missed owned relic spell or granted maze-key-only spell: " + spell)
	_expect(maze.campaign_key_items.has(relic) == present and maze.keys_held == 0,
		"INT-03 victory changed independent relic/key ownership")
	if spell == "tidal_revival":
		maze.inventory_menu.open()
		(maze.inventory_menu._spells_tab as Button).pressed.emit()
		await process_frame
		var offered := false
		for child in maze.inventory_menu._list.get_children():
			if child is Button and (child as Button).text.contains("Tidal Revival"):
				offered = not (child as Button).disabled
		_expect(offered == present, "INT-03 learned revival missing from actual Party Spells menu")
		maze.inventory_menu.close()
	root.size = Vector2i(360, 640)
	await process_frame
	for caption in maze._responsive_captions:
		_expect(caption.offset_left >= -164.1 and caption.offset_right <= 164.1,
			"INT-08 a second caption did not resize with the viewport")
	root.size = Vector2i(1280, 720)
	for diver in maze.divers:
		_expect(diver.stats.hp_max == 10, "INT-03 fixture inflated HP")
	print("MAZE RELIC CASE|relic=", relic, "|present=", present, "|result=", result, "|actions=", actions,
		"|known=", maze.divers[owner].known_spells, "|points=", maze.divers[owner].stats.spell_points)
	maze.queue_free()
	await process_frame
	await process_frame

func _choose(battle: Battle, name: String) -> bool:
	battle.attack_btn.pressed.emit()
	await process_frame
	var chosen: Button
	for button in battle.move_buttons:
		if (button as Button).text.get_slice("\n", 0) == name and not (button as Button).disabled:
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
	if battle.target_buttons.is_empty():
		return false
	(battle.target_buttons[0] as Button).pressed.emit()
	return true

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
