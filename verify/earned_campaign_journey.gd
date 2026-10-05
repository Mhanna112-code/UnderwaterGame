extends SceneTree
## EARN-1/2/3: genuine New Game and earned lab-first physical/real-fight slice.
## No supplied milestones, stats, XP, keys, victory, healing or teleports.
const SLOT := 918431
const ARRIVAL := 0.55
var world: World
var findings: Array[String] = []
var policy := "skilled"
var run_seed := 64000
var recovery_policy := "none"
var owned_slot := false
var fight_count := 0
var action_count := 0
var rng := RandomNumberGenerator.new()
var lab_party_receipt: Array[Dictionary] = []
var lab_payoff_seen := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--policy="):
			policy = arg.trim_prefix("--policy=")
		if arg.begins_with("--seed="):
			run_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--recovery="):
			recovery_policy = arg.trim_prefix("--recovery=")
	call_deferred("_run")

func _run() -> void:
	if policy not in ["casual", "skilled"]:
		findings.append("EARN observer: unsupported policy")
	if recovery_policy not in ["none", "existing-save-point", "existing-save-point-safe-return"]:
		findings.append("EARN observer: unsupported recovery policy")
	for file in _owned_paths():
		if FileAccess.file_exists(file) or DirAccess.dir_exists_absolute(file):
			findings.append("EARN observer: slot file already exists; refusing overwrite: " + file)
	if not findings.is_empty():
		await _finish()
		return
	seed(run_seed)
	rng.seed = run_seed + 1000000
	Engine.time_scale = 4.0
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	for diver in world.divers:
		_expect(diver.stats.level == 1 and diver.stats.xp == 0 and diver.known_spells.is_empty(),
			"EARN-1 New Game starts with supplied progression")
	owned_slot = true
	world.title_screen.new_game_chosen.emit(SLOT)
	var deadline := Time.get_ticks_msec() + 150000
	while world.route_state.prologue_phase != "spawn_exploration" and Time.get_ticks_msec() < deadline:
		await _ack_visible_reading()
		await process_frame
	_expect(world.route_state.prologue_phase == "spawn_exploration", "EARN-3 real opening never released quiet swimming")
	if not findings.is_empty():
		await _finish()
		return
	print("EARN NEW GAME|policy=%s|recovery=%s|seed=%d|real_opening_seen=%s" % [policy, recovery_policy, run_seed, world.route_state.opening_video_seen])
	await _hold(KEY_W, true)
	deadline = Time.get_ticks_msec() + 20000
	while world.battle == null and Time.get_ticks_msec() < deadline:
		await physics_frame
	await _hold(KEY_W, false)
	_expect(world.battle != null and world.route_state.encounter_source == "prologue_angler", "EARN-1 actual swim did not trigger initial Angler")
	# Encounter-source labels can be transient during a direct boss handoff.
	# Observe the actual visible roster; a Cordys-only opener must not count
	# as the explicitly retained initial Angler merely because dispatch still
	# used the old prologue_angler source for one frame.
	if world.battle != null:
		var roster := world.battle.enemies.map(func(e: Dictionary) -> String: return String(e.display_name))
		print("EARN INITIAL ROSTER|actual=%s|required_initial_angler=true" % [roster])
		_expect(roster == ["Angler"], "EARN-1 initial Angler missing; actual opening roster: " + str(roster))
	if not findings.is_empty():
		await _finish()
		return
	if findings.is_empty():
		await _play_fight()
	deadline = Time.get_ticks_msec() + 150000
	while not world.route_state.prologue_complete or world.battling:
		if Time.get_ticks_msec() >= deadline or not findings.is_empty():
			break
		await _ack_visible_reading()
		await process_frame
	_expect(world.route_state.prologue_complete and not world.battling and not paused,
		"EARN-3 real scripted defeat/recovery did not release ordinary play")
	_expect(world.random_encounters_enabled, "EARN-1 genuine recovery left random encounters disabled")
	for diver in world.divers:
		_expect(diver.stats.level == 1 and diver.stats.xp == 0 and diver.known_spells.is_empty(),
			"EARN-1 opening improperly grants earned kit")
	_record_party("real-recovery")
	# Normal free-water approach beside the old shallow puzzle; no compulsory
	# lab/maze access gate is invented. Keep actual random encounters enabled.
	for goal in [Vector3(55, 2, -5), DeepZoneLayout.DEEP_ENTRY, DeepZoneLayout.DEEP_HUB,
		DeepZoneLayout.BOMB_BOT - Vector3(3, 0, 0),
		DeepZoneLayout.SWORD_SLAYER - Vector3(3, 0, 0)]:
		if not findings.is_empty():
			break
		await _navigate(goal)
		await _service_gameplay()
	if findings.is_empty() and recovery_policy != "none":
		await _visit_existing_recovery()
	if findings.is_empty():
		await _navigate(DeepZoneLayout.LAB - Vector3(3, 0, 0))
		await _service_gameplay()
	# Let the normal lab entry/movie/Battle consumer run after physical arrival.
	deadline = Time.get_ticks_msec() + 15000
	while findings.is_empty() and world.route_state.tethys_state != "defeated" and Time.get_ticks_msec() < deadline:
		await _service_gameplay()
		await physics_frame
	_expect(world.route_state.bomb_bot_state == "defeated" and world.route_state.sword_slayer_state == "defeated"
		and world.route_state.lab_state == "cleared" and world.route_state.tethys_state == "defeated",
		"EARN-2 earned lab-first route did not finish actual blockers/Tethys")
	_expect(world.route_state.octopus_state != "defeated", "EARN-1 lab route falsely completes independent Cordys")
	_record_party("lab-terminal")
	if findings.is_empty():
		_expect(lab_payoff_seen, "EARN-4 real earned lab victory never presented the computer payoff")
		await _cold_load_earned_lab()
	print("EARNED LAB-FIRST SLICE|policy=%s|recovery=%s|seed=%d|fights=%d|actions=%d|lab=%s|NOT_FULL_CAMPAIGN" % [policy, recovery_policy, run_seed, fight_count, action_count, world.route_state.lab_state])
	await _finish()

func _service_gameplay() -> void:
	if not findings.is_empty():
		return
	if world.game_over_screen.is_visible_in_tree():
		findings.append("EARN-2 actual earned party lost at " + world.route_state.encounter_source)
		return
	if world.battle != null:
		await _release_movement()
		await _play_fight()
	else:
		await _ack_visible_reading()

func _play_fight() -> void:
	var battle := world.battle as Battle
	fight_count += 1
	var result: Array[String] = []
	battle.finished.connect(func(value: String) -> void:
		result.append(value)
		if value == "won" and battle.encounter_source == "lab_boss":
			lab_party_receipt = _observe_party())
	print("EARN FIGHT START|index=%d|source=%s|enemy=%s" % [fight_count, battle.encounter_source, battle.enemies.map(func(e: Dictionary) -> String: return String(e.display_name))])
	_record_party("fight-%d-entry" % fight_count)
	var deadline := Time.get_ticks_msec() + 150000
	var turns := 0
	while result.is_empty() and Time.get_ticks_msec() < deadline and turns < 100:
		await _ack_visible_reading()
		if (is_instance_valid(battle) and battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled
			and not battle._busy and battle._acting.has("model_name")):
			var choice := _choice(battle)
			if not await _choose(battle, choice):
				findings.append("EARN observer: chosen real move/target not accessible: " + String(choice.move))
				break
			turns += 1
			action_count += 1
		await process_frame
	var terminal := result[0] if not result.is_empty() else "timeout"
	print("EARN FIGHT END|index=%d|result=%s|actions=%d|phase=%s" % [fight_count, terminal, turns, world.route_state.prologue_phase])
	_expect(terminal in ["won", "prologue_defeat"], "EARN-2 actual earned fight ended " + terminal)
	for frame in range(10):
		await process_frame
	_record_party("fight-%d-exit" % fight_count)

func _choice(battle: Battle) -> Dictionary:
	var entry := battle._acting
	var who := String(entry.model_name)
	var enemy := battle.enemies.filter(func(e: Dictionary) -> bool: return e.stats.hp > 0)[0] as Dictionary
	var move := "Scuba Stabbing" if who == "Staff_Diver" else "Precise Tap" if who == "Prototype_1(1910)" else "Guard Bash"
	var target := String(enemy.display_name)
	if battle.prologue_angler_encounter or battle.prologue_octopus_encounter:
		return {"move": move, "target": target}
	if policy == "skilled":
		if who == "Staff_Diver":
			if enemy.stats.status_turns("blindness") <= 1:
				move = "Flash Blast"
			elif entry.equipped_spells.has("swift_strike") and entry.stats.oxygen >= 8.0:
				move = "Swift Strike"
			else:
				move = "Axe Kick"
		elif who == "Prototype_1(1910)":
			move = "Precise Jab" if entry.equipped_spells.has("precise_jab") and entry.stats.oxygen >= 8.0 else "Precise Tap"
		elif entry.equipped_spells.has("mending_current") and entry.stats.oxygen >= 8.0:
			for ally in battle.party:
				if ally.stats.hp > 0 and ally.stats.hp <= 5:
					move = "Mending Current"
					target = String(ally.display_name)
					break
	else:
		# Casual usually uses the first damaging base move, occasionally trying
		# another visible affordable base attack. No perfect timing assumption.
		var choices := (Battle.BASE_MOVES[who] as Array).filter(func(m: Dictionary) -> bool:
			return (float(m.get("oxygen_cost", 0)) <= entry.stats.oxygen
				and (CombatRules.formula_value(entry.stats, m.formula) > 0 if m.has("formula") else int(m.get("power", 0)) > 0)))
		if not choices.is_empty() and rng.randf() >= 0.7:
			move = String(choices[rng.randi_range(0, choices.size() - 1)].name)
	if move in ["Flash Blast", "Multiple Knee Combo"]:
		target = "All enemies"
	return {"move": move, "target": target}

func _choose(battle: Battle, choice: Dictionary) -> bool:
	battle.attack_btn.pressed.emit()
	await process_frame
	var selected: Button
	for button in battle.move_buttons:
		if button.text.get_slice("\n", 0) == choice.move and not button.disabled:
			selected = button
			break
	if selected == null:
		return false
	for page in range(10):
		if selected.is_visible_in_tree():
			break
		if battle._move_down_btn.disabled:
			return false
		battle._move_down_btn.pressed.emit()
		await process_frame
	if not selected.is_visible_in_tree():
		return false
	selected.pressed.emit()
	await process_frame
	for button in battle.target_buttons:
		if (button.is_visible_in_tree() and not button.disabled
			and button.text.begins_with(choice.target)):
			print("EARN ACTION|fight=%d|actor=%s|move=%s|target=%s" % [fight_count,
				battle._acting.display_name, choice.move, choice.target])
			button.pressed.emit()
			return true
	return false

func _ack_visible_reading() -> void:
	# A reading acknowledgment is not an X timing success. Never force video
	# completion, skip the non-skippable opening or mutate phase/turn flags.
	for group in ["opening_video", "prologue_recovery", "lab_video_cutscene"]:
		for owner in get_nodes_in_group(group):
			if not is_instance_valid(owner):
				continue
			for text in ["Continue", "Skip Cutscene"]:
				var button := _visible_button(owner, text)
				if button != null:
					button.pressed.emit()
					await process_frame
					# The acknowledgment may free its entire modal owner.
					return
	if world.battle != null and world.battle._tutorial_awaiting_enter:
		await _key(KEY_ENTER)
	var popup := root.find_child("CharacterAbilityPopup", true, false)
	if popup != null:
		var title := popup.get_node_or_null("%Title") as Label
		if title != null and title.is_visible_in_tree() and title.text == "Computer recovered":
			lab_payoff_seen = true
		var close := _visible_button(popup, "Close")
		if close != null:
			close.pressed.emit()
			await process_frame

func _visible_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == text and child.is_visible_in_tree() and not child.disabled:
			return child
		var found := _visible_button(child, text)
		if found != null:
			return found
	return null

func _navigate(goal: Vector3) -> void:
	var diver := world.divers[world.active] as Diver
	var shape: CollisionShape3D
	for child in diver.get_children():
		if child is CollisionShape3D:
			shape = child
	_expect(shape != null, "EARN observer: missing diver collision")
	if shape == null:
		return
	var start := Vector2i(roundi(diver.global_position.x), roundi(diver.global_position.z))
	var queue: Array[Vector2i] = [start]
	var parents := {start: start}
	var head := 0
	var found := Vector2i(999999, 999999)
	var space := world.get_world_3d().direct_space_state
	while head < queue.size() and head < 30000:
		var cell := queue[head]
		head += 1
		if Vector3(cell.x, goal.y, cell.y).distance_to(goal) < 0.8:
			found = cell
			break
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if parents.has(next) or absf(next.x - goal.x) > 70 or absf(next.y - goal.z) > 70:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape.shape
			query.transform = Transform3D(Basis.IDENTITY, Vector3(next.x, goal.y, next.y)) * shape.transform
			query.collision_mask = diver.collision_mask
			query.collide_with_areas = false
			query.exclude = [diver.get_rid()]
			if not space.intersect_shape(query, 1).is_empty():
				continue
			parents[next] = cell
			queue.append(next)
	if found.x == 999999:
		findings.append("EARN-3 no physical collision-valid route from %s to %s" % [diver.global_position, goal])
		return
	var route: Array[Vector3] = [goal]
	var cursor := found
	while cursor != start:
		route.append(Vector3(cursor.x, goal.y, cursor.y))
		cursor = parents[cursor]
	route.reverse()
	for waypoint in route:
		await _swim(waypoint)
		if not findings.is_empty():
			break
	if findings.is_empty():
		print("EARN PHYSICAL ARRIVAL|goal=%s|actual=%s" % [goal, world.divers[world.active].global_position])

func _swim(goal: Vector3) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and findings.is_empty():
		var service_started := Time.get_ticks_msec()
		await _service_gameplay()
		# A legitimate fight/movie is not time spent trying to swim through a wall.
		deadline += Time.get_ticks_msec() - service_started
		if not findings.is_empty():
			break
		var diver := world.divers[world.active] as Diver
		var delta := goal - diver.global_position
		delta.y = 0
		if delta.length() < ARRIVAL:
			await _release_movement()
			return
		# Scene/camera/player transform is not assigned: ordinary click/motion/W.
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		Input.parse_input_event(click)
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-angle_difference(world.yaw, atan2(delta.x, delta.z)) / 0.004, 0)
		Input.parse_input_event(motion)
		await _hold(KEY_W, true)
		await physics_frame
	await _release_movement()
	if findings.is_empty():
		findings.append("EARN-3 normal swimming blocked at %s before %s" % [world.divers[world.active].global_position, goal])

func _hold(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func _key(code: Key) -> void:
	await _hold(code, true)
	await _hold(code, false)

func _release_movement() -> void:
	await _hold(KEY_W, false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(click)
	await physics_frame

func _record_party(stage: String) -> void:
	for diver in world.divers:
		print("EARN PARTY|stage=%s|name=%s|level=%d|xp=%d|hp=%d|o2=%.1f|spells=%s" % [stage, diver.model_name, diver.stats.level, diver.stats.xp, diver.stats.hp, diver.stats.oxygen, str(diver.known_spells)])

func _visit_existing_recovery() -> void:
	var safe_return := recovery_policy == "existing-save-point-safe-return"
	var needs_rest := world.divers.any(func(d: Diver) -> bool:
		return d.stats.hp <= d.stats.hp_max / 2 or d.stats.oxygen < 16)
	# The explicit safe-return probe schedules one pre-boss visit even if
	# random attacks happen not to cross the conditional emergency threshold.
	if not needs_rest and not safe_return:
		print("EARN RECOVERY|policy=%s|needed=false" % recovery_policy)
		return
	var points := world.get_children().filter(func(node: Node) -> bool: return node is SavePoint)
	_expect(not points.is_empty(), "EARN-5 no actual World recovery point exists")
	if points.is_empty():
		return
	var point := points[0] as SavePoint
	_record_party("recovery-detour-start")
	var sonar_was_on := (world.divers[world.active] as Diver).sonar_active
	if sonar_was_on:
		await _key(KEY_Q)
		_expect(not (world.divers[world.active] as Diver).sonar_active,
			"EARN-5 actual Q did not suspend Sonar drain for recovery")
		print("EARN RECOVERY SONAR|actual_Q=true|sonar=false|restore_before_lab=true")
	if safe_return:
		await _key(KEY_R)
		_expect(not world.random_encounters_enabled, "EARN-5 actual R could not protect emergency return")
		print("EARN RECOVERY TOGGLE|actual_R=true|random_encounters=false|emergency_round_trip_only=true")
	for waypoint in [DeepZoneLayout.DEEP_HUB, DeepZoneLayout.DEEP_ENTRY, point.global_position]:
		await _navigate(waypoint)
		if not findings.is_empty():
			return
	for frame in 8:
		await _service_gameplay()
		await physics_frame
	_expect(point.has_diver(world.divers[world.active]), "EARN-5 swimming never contacts the existing rest point")
	for diver in world.divers:
		_expect(diver.stats.hp == diver.stats.hp_max and is_equal_approx(diver.stats.oxygen, diver.stats.oxygen_max),
			"EARN-5 actual rest contact failed to restore " + diver.model_name)
	_record_party("actual-rest-contact")
	for waypoint in [Vector3(55, 2, -5), DeepZoneLayout.DEEP_ENTRY, DeepZoneLayout.DEEP_HUB,
		DeepZoneLayout.SWORD_SLAYER - Vector3(3, 0, 0)]:
		if not findings.is_empty():
			return
		await _navigate(waypoint)
	_expect(world.route_state.bomb_bot_state == "defeated" and world.route_state.sword_slayer_state == "defeated",
		"EARN-5 recovery detour reset defeated guards")
	if safe_return:
		await _key(KEY_R)
		_expect(world.random_encounters_enabled, "EARN-5 actual R did not restore On before the boss")
		print("EARN RECOVERY TOGGLE|actual_R=true|random_encounters=true|before_lab=true")
	if sonar_was_on:
		await _key(KEY_Q)
		_expect((world.divers[world.active] as Diver).sonar_active,
			"EARN-5 actual Q did not restore Sonar before lab")
		print("EARN RECOVERY SONAR|actual_Q=true|sonar=true|before_lab=true")
	print("EARN RECOVERY|policy=%s|needed=true|actual_contact=true|return_complete=%s" % [recovery_policy, findings.is_empty()])

func _observe_party() -> Array[Dictionary]:
	var receipt: Array[Dictionary] = []
	for diver in world.divers:
		receipt.append({"model": diver.model_name, "level": diver.stats.level,
			"xp": diver.stats.xp, "hp": diver.stats.hp, "oxygen": diver.stats.oxygen,
			"known_spells": diver.known_spells.duplicate(),
			"equipped_spells": diver.equipped_spells.duplicate()})
	return receipt

func _cold_load_earned_lab() -> void:
	var path := SaveManager.slot_path(SLOT)
	var saved := SaveManager.read_slot(SLOT)
	var saved_party: Array = saved.get("campaign_checkpoint", {}).get("party", [])
	_expect(lab_party_receipt.size() == 3 and saved_party.size() == 3,
		"EARN-4 victory checkpoint omitted the actual earned party")
	if not findings.is_empty():
		return
	for index in 3:
		var earned: Dictionary = lab_party_receipt[index]
		var member: Dictionary = saved_party[index]
		for field in ["level", "xp", "hp", "oxygen"]:
			_expect(is_equal_approx(float(member.get("stats", {}).get(field, -1)), float(earned[field])),
				"EARN-4 earned victory checkpoint lost %s for %s" % [field, earned.model])
		for field in ["known_spells", "equipped_spells"]:
			_expect(member.get(field, []) == earned[field],
				"EARN-4 earned victory checkpoint lost %s for %s" % [field, earned.model])
	if not findings.is_empty():
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	await _release_movement()
	world.queue_free()
	await process_frame
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.load_game_chosen.emit(SLOT)
	for frame in 12:
		await process_frame
	_expect(_observe_party() == lab_party_receipt, "EARN-4 real cold Title Load lost or repaid the earned party")
	_expect(world.route_state.lab_state == "cleared" and world.route_state.tethys_state == "defeated"
		and world.route_state.octopus_state != "defeated" and world.route_state.prologue_complete,
		"EARN-4 cold Load lost or falsely completed earned campaign milestones")
	_expect(not paused and world.battle == null and world.random_encounters_enabled,
		"EARN-4 cold Load replays the opening/lab fight or loses ordinary exploration")
	var popup := root.get_node("CharacterAbilityPopup")
	_expect(not (popup.get_node("%AbilityExplanationPanel") as Control).visible,
		"EARN-4 cold Load repeats the recovered computer payoff")
	_expect(FileAccess.get_file_as_bytes(path) == bytes, "EARN-4 cold Load rewrites or duplicates earned rewards")
	_record_party("earned-cold-load")
	print("EARN COLD LOAD|actual_earned_party=true|native_checkpoint=true|bytes_conserved=%s|NOT_BROWSER" % [FileAccess.get_file_as_bytes(path) == bytes])

func _owned_paths() -> Array[String]:
	return [SaveManager.slot_path(SLOT), SaveManager.slot_path(SLOT) + ".pending",
		SaveManager.autosave_path(SLOT), SaveManager.autosave_path(SLOT) + ".pending"]

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	if is_instance_valid(world):
		await _release_movement()
		world.queue_free()
	await process_frame
	paused = false
	Engine.time_scale = 1.0
	if owned_slot:
		for file in _owned_paths():
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(file)
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING " + finding)
	print("EARNED LAB-FIRST SLICE: " + ("clean (not full campaign)" if findings.is_empty() else "failed"))
	quit(0 if findings.is_empty() else 1)
