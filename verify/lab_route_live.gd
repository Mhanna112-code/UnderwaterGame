extends SceneTree
## LAB-BAL-004: actual World dispatch, three real fights, earned progression.
## Completed-opening fixture only; no supplied win, healing, XP or battle stats.
const SLOT := 918363
var findings: Array[String] = []
var output := ""

func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		output = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 12.0 if output.is_empty() else 2.0
	seed(63004)
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	world._current_slot = SLOT
	world.random_encounters_enabled = false
	var points := world.deep_zone_layout.route_points()
	for id in ["bomb_bot", "sword_slayer", "lab"]:
		var diver := world.divers[world.active] as Diver
		diver.global_position = points[id] as Vector3
		diver.velocity = Vector3.ZERO
		var deadline := Time.get_ticks_msec() + 60000
		# Real route owner must consume position and finish the actual lab film.
		while world.battle == null and Time.get_ticks_msec() < deadline:
			for node in get_nodes_in_group("lab_video_cutscene"):
				var cutscene := node as LabVideoCutscene
				if cutscene._finished_playing and cutscene._action_button.text == "Continue":
					cutscene._action_button.pressed.emit()
			await process_frame
		_expect(world.battle != null, "LAB-BAL-004 " + id + " physical entry never exposes combat")
		if world.battle == null:
			print("LAB ROUTE DIAGNOSTIC|lab=%s|tethys=%s|position=%s|paused=%s" % [world.route_state.lab_state, world.route_state.tethys_state, str(diver.global_position), str(paused)])
			for node in get_nodes_in_group("lab_video_cutscene"):
				var player := node.find_child("MermaidVideo", true, false) as VideoStreamPlayer
				if player != null:
					print("LAB FILM DIAGNOSTIC|playing=%s|position=%.2f" % [str(player.is_playing()), player.stream_position])
			break
		var battle := world.battle as Battle
		_expect(battle.encounter_source == ("lab_boss" if id == "lab" else "lab_blocker"),
			"LAB-BAL-004 wrong authored encounter provenance at " + id)
		var outcomes: Array[String] = []
		battle.finished.connect(func(result: String) -> void: outcomes.append(result))
		var actions := 0
		deadline = Time.get_ticks_msec() + 180000
		while outcomes.is_empty() and Time.get_ticks_msec() < deadline and actions < 80:
			if battle._tutorial_awaiting_enter:
				var event := InputEventKey.new()
				event.keycode = KEY_ENTER
				event.pressed = true
				Input.parse_input_event(event)
			if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
				var name := _choice(battle)
				_expect(await _choose(battle, name), "LAB-BAL-004 real move not accessible: " + name)
				actions += 1
			await process_frame
		var result := outcomes[0] if not outcomes.is_empty() else "timeout"
		print("LAB LIVE ROUTE|fight=%s|result=%s|actions=%d" % [id, result, actions])
		_expect(result == "won", "LAB-BAL-004 reachable continuous " + id + " ended " + result)
		for _frame in range(15):
			await process_frame
		if not output.is_empty():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(id + "-returned-world.png"))
		for member in world.divers:
			print("LAB CARRIED PARTY|after=%s|name=%s|level=%d|xp=%d|hp=%d|o2=%.1f|spells=%s" % [id, member.model_name, member.stats.level, member.stats.xp, member.stats.hp, member.stats.oxygen, str(member.known_spells)])
		if result != "won":
			break
	_expect(world.route_state.bomb_bot_state == "defeated" and world.route_state.sword_slayer_state == "defeated" and world.route_state.tethys_state == "defeated", "LAB-BAL-004 actual victories did not complete route state")
	var saved := SaveManager.read_slot(SLOT)
	_expect(not saved.is_empty() and bool(saved.get("route_state", {}).get("prologue_complete", false)), "LAB-BAL-004 guard/boss saves lost completed opening")
	world.queue_free()
	await process_frame
	paused = false
	Engine.time_scale = 1.0
	root.get_node("GameAudio").release_streams_for_shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(SLOT)))
	for finding in findings:
		print("FINDING ", finding)
	print("LAB LIVE ROUTE: clean" if findings.is_empty() else "LAB LIVE ROUTE: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _choice(battle: Battle) -> String:
	var entry := battle._acting
	var enemy := battle.enemies[0].stats as CombatantStats
	match String(entry.model_name):
		"Staff_Diver":
			if enemy.status_turns("blindness") <= 1:
				return "Flash Blast"
			return "Swift Strike" if entry.equipped_spells.has("swift_strike") and entry.stats.oxygen >= 8.0 else "Axe Kick"
		"Prototype_1(1910)":
			if enemy.effective_defense() > 0 and entry.stats.oxygen >= 10.0:
				return "Weaken"
			return "Precise Jab" if entry.equipped_spells.has("precise_jab") and entry.stats.oxygen >= 8.0 else "Precise Tap"
	return "Guard Bash"

func _choose(battle: Battle, move_name: String) -> bool:
	battle.attack_btn.pressed.emit()
	await process_frame
	var selected: Button
	for value in battle.move_buttons:
		var button := value as Button
		if button.text.get_slice("\n", 0) == move_name and not button.disabled:
			selected = button
			break
	if selected == null:
		return false
	var pages := 0
	while not selected.is_visible_in_tree() and pages < 6 and not battle._move_down_btn.disabled:
		battle._move_down_btn.pressed.emit()
		await process_frame
		pages += 1
	if not selected.is_visible_in_tree():
		return false
	selected.pressed.emit()
	await process_frame
	if battle.target_buttons.is_empty():
		return false
	(battle.target_buttons[0] as Button).pressed.emit()
	return true

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
