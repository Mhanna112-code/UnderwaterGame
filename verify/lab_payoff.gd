extends SceneTree
## LAB-1: real Tethys victory must acknowledge computer/controller payoff.
## Supplied legal kit/cleared blockers isolate result presentation, not balance.
const SLOT := 918426
var world: World
var findings: Array[String] = []
var owns_slot := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := SaveManager.slot_path(SLOT)
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".pending") or DirAccess.dir_exists_absolute(path + ".pending"):
		print("Refusing existing lab payoff fixture: ", path)
		quit(1)
		return
	owns_slot = true
	Engine.time_scale = 10.0
	seed(63004)
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
	world.route_state.set_lab_state("available")
	world.route_state.set_blocker_state("bomb_bot", "defeated")
	world.route_state.set_blocker_state("sword_slayer", "defeated")
	world.route_state.deep_warning_seen = true
	for diver in world.divers:
		while diver.stats.level < 5:
			diver.stats.gain_xp(10)
		SpellTree.learn_all_available(diver, [])
		diver.sonar_active = false
	_expect(SaveManager.write_slot(SLOT, world._serialize_state()) == OK, "LAB-1 fixture checkpoint failed")
	(world.divers[world.active] as Diver).global_position = world.deep_zone_layout.route_points().lab
	var deadline := Time.get_ticks_msec() + 20000
	while world.battle == null and Time.get_ticks_msec() < deadline:
		if not get_nodes_in_group("lab_video_cutscene").is_empty():
			await _key(KEY_ESCAPE)
		await process_frame
	var battle := world.battle as Battle
	if battle == null:
		findings.append("LAB-1 physical unlocked lab never starts actual fight")
		await _finish()
		return
	_expect(battle.encounter_source == "lab_boss" and battle.boss_encounter, "LAB-1 fight is not laboratory Tethys")
	var outcomes: Array[String] = []
	battle.finished.connect(func(result: String) -> void: outcomes.append(result))
	var actions := 0
	deadline = Time.get_ticks_msec() + 120000
	while outcomes.is_empty() and Time.get_ticks_msec() < deadline and actions < 90:
		if battle._tutorial_awaiting_enter:
			await _key(KEY_ENTER)
		if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
			var model := String(battle._acting.model_name)
			var enemy := battle.enemies[0].stats as CombatantStats
			var move := "Guard Bash"
			var target := "Tethys"
			if model == "Staff_Diver":
				move = "Flash Blast" if enemy.status_turns("blindness") <= 1 else "Swift Strike"
				for entry in battle.party:
					var stats := entry.stats as CombatantStats
					if stats.hp > 0 and stats.hp <= 6 and battle._acting.stats.oxygen >= 16:
						move = "Healing Current"
						target = String(entry.display_name)
						break
			elif model == "Prototype_1(1910)":
				move = "Weaken" if enemy.effective_defense() > 0 and battle._acting.stats.oxygen >= 10 else "Precise Jab"
			if not await _choose(battle, move, target):
				findings.append("LAB-1 legal move unavailable: " + move)
				break
			actions += 1
		await process_frame
	_expect(outcomes == ["won"], "LAB-1 actual legal-kit fight did not win: " + str(outcomes))
	for frame in 20:
		await process_frame
	var popup := root.get_node("CharacterAbilityPopup")
	var panel := popup.get_node("%AbilityExplanationPanel") as PanelContainer
	var heading := popup.get_node("%Title") as Label
	var body := panel.find_children("*", "RichTextLabel", true, false)
	var text := ""
	for item in body:
		text += (item as RichTextLabel).get_parsed_text().to_lower()
	_expect(panel.is_visible_in_tree() and paused and "computer" in heading.text.to_lower()
		and "controlling" in text and "maze" in text and "ramp" in text,
		"LAB-1 real victory has no visible computer/controller payoff and suggested maze ramp")
	_expect(not world.get_node("HUD").visible, "LAB-2 gameplay HUD/stale warning competes beneath payoff modal")
	_expect(world.route_state.lab_state == "cleared" and world.route_state.tethys_state == "defeated"
		and world.route_state.octopus_state != "defeated", "LAB-1 payoff falsely completes campaign boss")
	print("LAB PAYOFF|actual_actions=", actions, "|outcomes=", outcomes, "|visible=", panel.is_visible_in_tree(), "|text=", text)
	if panel.is_visible_in_tree():
		if "--visual" in OS.get_cmdline_user_args():
			for width in [1280, 720, 360]:
				root.size = Vector2i(width, 720)
				for frame in 4:
					await process_frame
				var bounds := panel.get_global_rect()
				_expect(bounds.position.x >= 0 and bounds.end.x <= width and bounds.end.y <= 720,
					"LAB-1 payoff modal clips viewport width " + str(width))
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("/private/tmp/campaign-goals-visual-oct5")
				root.get_texture().get_image().save_png("/private/tmp/campaign-goals-visual-oct5/lab-%d.png" % width)
		var before := world._serialize_state()
		(popup.get_node("%PopupClose") as Button).pressed.emit()
		for frame in 12:
			await process_frame
		_expect(not panel.visible and not paused and world.get_node("HUD").visible and "maze" in world.route_objective_label.text.to_lower(),
			"LAB-1 dismissing payoff cannot resume useful maze guidance")
		for index in 3:
			var stats := world.divers[index].stats as CombatantStats
			var expected: Dictionary = before.campaign_checkpoint.party[index].stats
			_expect(stats.hp == expected.hp and stats.xp == expected.xp and is_equal_approx(stats.oxygen, expected.oxygen),
				"LAB-1 payoff dismiss duplicates rewards or heals party")
	var saved_bytes := FileAccess.get_file_as_bytes(path)
	_expect(SaveManager.read_slot(SLOT).get("route_state", {}).get("lab_state") == "cleared", "LAB-1 victory checkpoint loses payoff milestone")
	world.queue_free()
	await process_frame
	world = load("res://game/world.tscn").instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.load_game_chosen.emit(SLOT)
	for frame in 16:
		await process_frame
	_expect(not paused and not panel.visible and world.route_state.lab_state == "cleared"
		and world.route_state.tethys_state == "defeated" and "maze" in world.route_objective_label.text.to_lower(),
		"LAB-1 cold Title Load replays payoff/fight or loses suggested maze direction")
	_expect(FileAccess.get_file_as_bytes(path) == saved_bytes, "LAB-1 Load rewrites victory or duplicates reward")
	print("LAB PAYOFF|Title_Load=true|save_bytes_conserved=true|no_repeat_popup=true")
	await _finish()

func _choose(battle: Battle, move: String, target: String) -> bool:
	battle.attack_btn.pressed.emit()
	await process_frame
	var chosen: Button
	for button in battle.move_buttons:
		if (button as Button).text.get_slice("\n", 0) == move and not (button as Button).disabled:
			chosen = button as Button
	if chosen == null:
		print("LAB UI WITNESS|moves=", battle.move_buttons.map(func(b: Button) -> String: return b.text.get_slice("\n", 0) + ":disabled=" + str(b.disabled)))
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
		if (button as Button).text.contains(target) and not (button as Button).disabled:
			(button as Button).pressed.emit()
			return true
	print("LAB UI WITNESS|targets=", battle.target_buttons.map(func(b: Button) -> String: return b.text + ":disabled=" + str(b.disabled)))
	return false

func _key(key: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	world.queue_free()
	await process_frame
	paused = false
	Engine.time_scale = 1.0
	root.get_node("GameAudio").release_streams_for_shutdown()
	if owns_slot:
		for path in [SaveManager.slot_path(SLOT), SaveManager.slot_path(SLOT) + ".pending"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	for finding in findings:
		print("FINDING ", finding)
	print("LAB PAYOFF: clean" if findings.is_empty() else "LAB PAYOFF: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
