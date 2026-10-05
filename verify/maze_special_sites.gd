extends SceneTree
## SITE-1: actual Q must discover the authored secret-item-room site.
var findings: Array[String] = []
var cases := 0
var maze: MazeLevel
var captures := ""
var placement_only := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			captures = argument.trim_prefix("--capture-dir=")
		elif argument == "--placement-only":
			placement_only = true
	maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	maze.random_encounters_enabled = false
	maze.room_encounters_enabled = false
	for frame in 8:
		await physics_frame
	if placement_only:
		await _placement_cases()
	else:
		var maxilani := maze.divers[0] as Diver
		maxilani.global_position = Vector3(64, maze._floor_top_y + 1.5, 52)
		maxilani.velocity = Vector3.ZERO
		await _key(KEY_Q)
		for frame in 4:
			await physics_frame
		var found := false
		for poi in maze.map_points_of_interest():
			if String(poi.kind) == "special" and (poi.pos as Vector3).distance_to(Vector3(64, maze._floor_top_y, 52)) < 0.1:
				found = true
		_expect(found, "SITE-1 actual Q reveals no special site at the authored secret-item-room point")
		if findings.is_empty():
			await _key(KEY_Q)
			await _trigger_cases(maxilani)
			if findings.is_empty():
				await _outcome_cases()
			if findings.is_empty():
				await _reward_matrix()
			if findings.is_empty():
				_persistence_cases()
	maze.queue_free()
	for frame in 3:
		await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE SPECIAL SITES: clean" if findings.is_empty() else "MAZE SPECIAL SITES: failed")
	quit(0 if findings.is_empty() else 1)

func _settle(frames := 3) -> void:
	for frame in frames:
		await physics_frame

func _trigger_cases(actor: Diver) -> void:
	var point := Vector3(64, maze._floor_top_y, 52)
	var chooser := maze.special_sites.prompt as SpecialEncounterPrompt
	# Radius through a wall or from far above must not steal control.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 8, 0.4)
	shape.shape = box
	wall.add_child(shape)
	maze.add_child(wall)
	wall.global_position = point + Vector3(0, 2, 2)
	actor.global_position = point + Vector3(0, 1.5, 3.5)
	await _settle()
	await _key(KEY_R)
	await _settle()
	_expect(not chooser.visible and not paused, "SITE-2 radius prompts through a solid wall")
	await _key(KEY_R)
	wall.queue_free()
	actor.global_position = point + Vector3.UP * 7
	await _settle()
	await _key(KEY_R)
	await _settle()
	_expect(not chooser.visible, "SITE-2 horizontal radius prompts from far above")
	await _key(KEY_R)
	actor.global_position = point + Vector3.UP * 1.5
	await _settle()
	maze.set_maze_active(false)
	maze.random_encounters_enabled = true
	await _settle()
	_expect(not chooser.visible, "SITE-2 inactive Maze opens a site chooser")
	maze.random_encounters_enabled = false
	maze.set_maze_active(true)
	# A lesson can pause halfway through Maze's physics callback. Exercise
	# the component's public frame entry after that real shared owner opens.
	var lesson := root.get_node("CharacterAbilityPopup")
	var lesson_pages: Array[Dictionary] = [{"title": "Site ownership probe", "body": "Read before entering.", "slot": null}]
	lesson.open(lesson_pages, maze)
	maze.random_encounters_enabled = true
	maze.special_sites.update()
	_expect(paused and not chooser.visible, "SITE-2 site stacks a chooser after the shared lesson has paused the frame")
	if chooser.visible:
		chooser.cancelled.emit()
	# Closing the lesson resumes ordinary radius triggering. Disable the
	# fixture preference BEFORE closing, rather than racing native physics.
	maze.random_encounters_enabled = false
	await _key(KEY_ESCAPE)
	_expect(not paused and not chooser.visible, "SITE-2 lesson cannot relinquish exclusive ownership")
	await _settle()
	await _key(KEY_ESCAPE)
	await _key(KEY_R)
	await _settle()
	_expect(maze.inventory_menu.visible and not chooser.visible,
		"SITE-2 site steals the inventory owner")
	await _key(KEY_ESCAPE)
	await _key(KEY_R)
	await _settle()
	_expect(chooser.visible and paused and not maze.can_capture_campaign_snapshot(),
		"SITE-1/2 actual R-on inside the open radius does not open an exclusive chooser")
	if not captures.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(captures.path_join("special-site-confirm.png"))
	await _prompt_layout_cases(chooser)
	chooser.cancelled.emit()
	await _settle(8)
	_expect(not chooser.visible and not paused, "SITE-3 canceled chooser reopens without leaving")
	for player in chooser.find_children("*", "VideoStreamPlayer", true, false):
		_expect(not (player as VideoStreamPlayer).is_playing(), "SITE-7 hidden chooser video keeps decoding after cancel")
	# Real W motion leaves the radius, then S returns; no private trigger call.
	maze._yaw = 0
	await _hold(KEY_W, 80)
	_expect(actor.global_position.z > point.z + 4.1,
		"SITE-3 real capsule cannot leave authored radius")
	await _hold(KEY_S, 80)
	await _settle()
	_expect(chooser.visible and paused, "SITE-3 actual leave/re-entry does not reoffer canceled site")
	chooser.cancelled.emit()
	maze.random_encounters_enabled = false
	print("MAZE SITE TRIGGERS|wall_blocked=true|height_blocked=true|inactive_blocked=true|modal_blocked=true|R_inside=true|actual_reentry=true")

func _prompt_layout_cases(chooser: SpecialEncounterPrompt) -> void:
	for size in [Vector2i(1280, 720), Vector2i(720, 480), Vector2i(360, 640)]:
		root.size = size
		await _ui_settle()
		_check_visible_buttons(chooser, size)
		await _key(KEY_ENTER)
		await _ui_settle()
		_check_visible_buttons(chooser, size)
		if not captures.is_empty():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(captures.path_join("special-site-select-%dx%d.png" % [size.x, size.y]))
		await _key(KEY_ESCAPE)
		await _ui_settle()
	root.size = Vector2i(1280, 720)

func _ui_settle() -> void:
	for frame in 5:
		await process_frame

func _button(chooser: SpecialEncounterPrompt, text: String) -> Button:
	for button in chooser.find_children("*", "Button", true, false):
		if button.text == text:
			return button as Button
	return null

func _check_visible_buttons(chooser: SpecialEncounterPrompt, size: Vector2i) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(size)).grow(1)
	for button in chooser.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			_expect(bounds.encloses(button.get_global_rect()),
				"SITE-7 special chooser action is outside viewport %s: %s %s" % [size, button.text, button.get_global_rect()])

func _hold(code: Key, frames: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	for frame in frames:
		await physics_frame
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()

func _outcome_cases() -> void:
	var baseline := maze.campaign_snapshot()
	var chooser := maze.special_sites.prompt as SpecialEncounterPrompt
	for selected in 3:
		for outcome in ["lost", "fled", "won", "downed"]:
			maze.random_encounters_enabled = false
			maze.restore_campaign_snapshot(JSON.parse_string(JSON.stringify(baseline)))
			for index in 3:
				maze.divers[index].global_position = Vector3(2000 + index * 3, 1.5, 2000)
				maze.divers[index].stats.hp = 4 + index
				maze.divers[index].stats.oxygen = 9.0 + index
			maze.divers[0].global_position = Vector3(64, maze._floor_top_y + 1.5, 52)
			var actor := maze.divers[selected] as Diver
			if outcome == "downed":
				actor.stats.hp = 0
			var hp := actor.stats.hp
			var oxygen := actor.stats.oxygen
			var stats := actor.stats
			var quantity := int(maze.inventory.get("accuracy_up", 0))
			await _settle()
			await _key(KEY_R)
			await _settle()
			_expect(chooser.visible and paused, "SITE-4 actual R-on fails chooser for " + outcome)
			chooser.diver_chosen.emit(actor.model_name)
			await process_frame
			if outcome == "downed":
				_expect(not maze._battling and not chooser.visible and not paused and actor.stats.hp == 0,
					"SITE-4 downed choice creates a battle, grants revival or traps pause")
			else:
				var battle := maze._battle
				_expect(battle != null and battle.special_encounter and battle.guardian_encounter
					and battle.encounter_source == "maze_special" and battle.party.size() == 1
					and battle.party[0].diver == actor and battle.party[0].stats == stats
					and battle.guardian_enemy_id == "swordfish_duelist",
					"SITE-4 chosen actor is replaced or dispatched as ordinary/multi-party/boss combat")
				if battle == null:
					return
				# Public result signals pin ownership/reward lifecycle, not proof of
				# a combat win. Minigame completion is verified by separate gates.
				actor.stats.hp = 1
				actor.stats.oxygen = 2
				battle.finished.emit(outcome)
				await process_frame
				await _settle()
				_expect(actor.stats == stats and actor.stats.hp == (actor.stats.hp_max if outcome == "won" else hp)
					and is_equal_approx(actor.stats.oxygen, actor.stats.oxygen_max if outcome == "won" else oxygen),
					"SITE-4 result changes actor/resource identity or authored win/loss policy")
				_expect(int(maze.inventory.get("accuracy_up", 0)) == quantity + (1 if outcome == "won" else 0),
					"SITE-3 result loses or duplicates reward")
				_expect(maze.campaign_snapshot().special_sites[0].consumed == (outcome == "won"),
					"SITE-3 outcome loses consumed state")
				_expect(not maze._battling and not paused and not maze._game_over.visible,
					"SITE-4 special result traps ordinary game over/input")
				for index in 3:
					if index != selected:
						_expect(maze.divers[index].stats.hp == 4 + index and maze.divers[index].stats.oxygen == 9 + index,
							"SITE-4 solo result resets an uninvolved party member")
			cases += 1
	print("MAZE SITE OUTCOMES|generated=", cases, "|public_result_fixture=true|three_actual_actors=true")

func _reward_matrix() -> void:
	var baseline := maze.campaign_snapshot()
	var items := ["accuracy_up", "attack_up", "defense_up", "oxygen_cell", "evasion_up", "attack_up", "potion"]
	var enemies := ["swordfish_duelist", "angler", "swordfish_duelist", "angler", "angler", "swordfish_duelist", "angler"]
	var chooser := maze.special_sites.prompt as SpecialEncounterPrompt
	for site_index in 7:
		maze.random_encounters_enabled = false
		maze.restore_campaign_snapshot(JSON.parse_string(JSON.stringify(baseline)))
		var at := CampaignSession.vector_from(baseline.special_sites[site_index].position)
		for actor in maze.divers:
			actor.global_position = Vector3(2000, 2, 2000)
		maze.divers[0].global_position = at + Vector3.UP * 1.5
		var before := maze.inventory.duplicate(true)
		await _settle()
		await _key(KEY_R)
		await _settle()
		_expect(chooser.visible and paused, "SITE-1/3 authored site does not open: %d" % site_index)
		if not chooser.visible:
			return
		chooser.diver_chosen.emit(maze.divers[0].model_name)
		await process_frame
		var battle := maze._battle
		_expect(battle != null and battle.guardian_enemy_id == enemies[site_index]
			and battle.reward_item_on_win == items[site_index], "SITE-1/3 site dispatches the wrong enemy/reward")
		if battle == null:
			return
		battle.finished.emit("won") # Reward lifecycle fixture, not minigame completion.
		await _settle()
		var expected := before.duplicate(true)
		expected[items[site_index]] = int(expected.get(items[site_index], 0)) + 1
		_expect(maze.inventory == expected and not chooser.visible,
			"SITE-3 site reward is wrong, duplicated or immediately retriggered")
		var won := maze.campaign_snapshot()
		_expect(won.special_sites[site_index].consumed, "SITE-3 winning site remains available")
		maze.restore_campaign_snapshot(JSON.parse_string(JSON.stringify(won)))
		await _settle()
		_expect(not chooser.visible and maze.inventory == expected, "SITE-3 consumed site reopens or rewards again after restore")
	maze.random_encounters_enabled = false
	print("MAZE SITE REWARDS|authored_items_and_enemies=7|public_result_fixture=true|consumed_reentry=true")

func _persistence_cases() -> void:
	var original := maze.campaign_snapshot()
	_expect(original.has("special_sites") and original.special_sites.size() == 7,
		"SITE-5/6 snapshot omits one or more authored sites")
	if not original.has("special_sites"):
		return
	var generated := 0
	var session := CampaignSession.new()
	session.route_state = RouteState.new()
	session.route_state.prologue_complete = true
	session.route_state.set_zone("maze")
	session.capture_party(maze.divers, maze.active)
	session.inventory = maze.inventory.duplicate(true)
	session.campaign_key_items.assign(maze.campaign_key_items)
	for mask in 128:
		var saved := original.duplicate(true)
		for index in 7:
			saved.special_sites[index].revealed = mask & (1 << index) != 0
			saved.special_sites[index].consumed = (mask + index) % 3 == 0
		var source := JSON.parse_string(JSON.stringify(saved)) as Dictionary
		var untouched := source.duplicate(true)
		for origin in [Vector3.ZERO, Vector3(130, -6, 240), Vector3(-47.25, 2.5, -8.125)]:
			var rebased := MazeCoordinateFrame.rebase(source, origin)
			_expect(not rebased.is_empty(), "SITE-5 valid site JSON/frame rejected")
			if rebased.is_empty():
				return
			for index in 7:
				var at: Array = saved.special_sites[index].position
				_expect(CampaignSession.vector_from(rebased.special_sites[index].position).distance_to(Vector3(at[0], at[1], at[2]) + origin) < 0.001
					and rebased.special_sites[index].revealed == saved.special_sites[index].revealed
					and rebased.special_sites[index].consumed == saved.special_sites[index].consumed,
					"SITE-5 rebase loses randomized placement/discovery/consumed state")
			_expect(source == untouched, "SITE-5 rebase mutates previous checkpoint")
			session.maze_snapshot = rebased
			var encoded := CampaignCheckpoint.encode(session)
			var decoded := CampaignCheckpoint.decode(JSON.parse_string(JSON.stringify(encoded)))
			_expect(decoded != null, "SITE-5 valid site state rejected by full checkpoint codec")
			if decoded != null:
				_expect(_sites_equal(decoded.maze_snapshot.special_sites, rebased.special_sites),
					"SITE-5 full checkpoint JSON loses positions/discovery/consumption")
				_expect(decoded.inventory == session.inventory and decoded.active == session.active,
					"SITE-5 special-site codec changes shared inventory or active actor")
			generated += 1
	maze.random_encounters_enabled = false
	var completed := original.duplicate(true)
	completed.special_sites[0].consumed = true
	completed.special_sites[0].revealed = true
	maze.restore_campaign_snapshot(JSON.parse_string(JSON.stringify(completed)))
	_expect(maze.campaign_snapshot().special_sites == completed.special_sites,
		"SITE-5 actual public restore rerolls or resets saved sites")
	maze.restore_campaign_snapshot(JSON.parse_string(JSON.stringify(completed)))
	_expect(maze.campaign_snapshot().special_sites == completed.special_sites,
		"SITE-5 repeated restore loses consumed state")
	for invalid in [null, [], {}, original.special_sites.slice(0, 6)]:
		var malformed := original.duplicate(true)
		malformed.special_sites = invalid
		_expect(not CampaignCheckpoint.valid_maze(malformed), "SITE-5 malformed optional site field accepted")
	for field in ["id", "item", "enemy", "position", "revealed", "consumed"]:
		var malformed := original.duplicate(true)
		malformed.special_sites[0][field] = "invalid"
		_expect(not CampaignCheckpoint.valid_maze(malformed), "SITE-5 invalid site " + field + " accepted")
	var legacy := original.duplicate(true)
	legacy.erase("special_sites")
	_expect(CampaignCheckpoint.valid_maze(legacy), "SITE-5 old checkpoint without new site field rejected")
	maze.restore_campaign_snapshot(legacy)
	_expect(not maze.campaign_snapshot().special_sites[0].consumed,
		"SITE-5 legacy restore keeps unsaved consumed state")
	print("MAZE SITE PERSISTENCE|generated_frames=", generated, "|full_checkpoint_JSON=384|invalid_optional=10|legacy=true|live_restore=true")

func _placement_cases() -> void:
	var stored := maze.campaign_snapshot()
	stored.special_sites[0].revealed = true
	stored.special_sites[0].consumed = true
	var layouts: Array = []
	var approaches := 0
	var scenes := 0
	for run in 12:
		if run > 0:
			maze.queue_free()
			for frame in 3:
				await process_frame
			maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
			root.add_child(maze)
			current_scene = maze
			maze.random_encounters_enabled = false
			maze.room_encounters_enabled = false
			_expect(not maze.can_capture_campaign_snapshot(), "SITE-6 uninitialized collision placement is stable-save eligible")
			if run % 4 == 3:
				maze.restore_campaign_snapshot(JSON.parse_string(JSON.stringify(stored)))
			await _settle(5)
		maze.set_physics_process(false)
		scenes += 1
		var saved := maze.campaign_snapshot()
		_expect(saved.has("special_sites") and saved.special_sites.size() == 7,
			"SITE-6 generated new-run layout omits authored entries")
		if not saved.has("special_sites"):
			return
		if run % 4 == 3:
			if not _sites_equal(saved.special_sites, stored.special_sites):
				print("SITE COLD COMPARE|saved=", JSON.stringify(saved.special_sites), "|expected=", JSON.stringify(stored.special_sites))
			_expect(_sites_equal(saved.special_sites, stored.special_sites), "SITE-5 cold constructor overwrites persisted positions/discovery/consumption")
		else:
			layouts.append(saved.special_sites)
		for actor in maze.divers:
			actor.global_position = Vector3(2000, 2, 2000)
		for index in 7:
			var point := CampaignSession.vector_from(saved.special_sites[index].position)
			if index > 1 and index != 4:
				var prior := CampaignSession.vector_from(saved.special_sites[index - 1].position)
				var low := 10.0 if index < 4 else 7.0
				var high := 20.0 if index < 4 else 10.0
				_expect(point.z - prior.z >= low - 0.01 and point.z - prior.z <= high + 0.01,
					"SITE-6 generated locations violate authored spacing")
			for actor in maze.divers:
				# Independent real capsules, not the generator's clearance helper.
				var target := point + Vector3.UP * (actor.height * 0.5 + 0.1)
				# The entire capsule must START inside the promised 2.2 m open
				# radius. A centre at 2 m put Bucky's rim outside that contract.
				var approach := 2.2 - actor.radius - 0.1
				actor.global_position = target + Vector3.RIGHT * approach
				var collision := actor.move_and_collide(Vector3.LEFT * approach)
				if actor.global_position.distance_to(target) >= 0.05:
					print("SITE CAPSULE BLOCK|run=", run, "|site=", index, "|point=", point,
						"|actor=", actor.model_name, "|height=", actor.height,
						"|end=", actor.global_position, "|collider=", collision.get_collider().get_path() if collision != null else "none")
					print("SITE FAILED LAYOUT|", JSON.stringify(saved.special_sites))
				_expect(actor.global_position.distance_to(target) < 0.05,
					"SITE-6 actual capsule cannot approach site %d in generated layout %d" % [index, run])
				actor.global_position = Vector3(2000, 2, 2000)
				approaches += 1
		if not findings.is_empty():
			break
	_expect(layouts.size() > 1 and layouts[0] != layouts[1], "SITE-6 fresh runs are not randomized independently")
	print("MAZE SITE PLACEMENT|fresh_and_cold_scenes=", scenes, "|actual_capsule_approaches=", approaches, "|cold_restores=3")

func _sites_equal(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for wanted in expected:
		var found := false
		for candidate in actual:
			if candidate.id == wanted.id:
				found = true
				for field in ["item", "enemy", "revealed", "consumed"]:
					if candidate[field] != wanted[field]:
						return false
				# Compare serialized doubles directly. Converting both through
				# float32 Vector3 can round opposite ways at a midpoint after JSON.
				for axis in 3:
					if absf(float(candidate.position[axis]) - float(wanted.position[axis])) > 0.00000001:
						return false
		if not found:
			return false
	return true

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
