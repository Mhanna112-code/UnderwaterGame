extends SceneTree

var failures: Array[String] = []
var checks := 0
var world: World
var slot := 0
var checkpoint_path := ""
var _used_practice_item := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	world.route_state.prologue_complete = true
	world.route_state.opening_video_seen = true
	world.route_state.tutorial_complete = true
	world.route_state.normalize_prologue_phase()
	world._first_encounter_started = true
	world._intro_active = false
	# This fixture stays in place; no world test trigger races the practice.
	world.set_physics_process(false)
	world.set_process(false)
	slot = 730000 + Time.get_ticks_msec() % 100000
	while SaveManager.slot_exists(slot):
		slot += 1
	checkpoint_path = ProjectSettings.globalize_path(SaveManager.slot_path(slot))
	world._current_slot = slot
	world.inventory = {"potion": 2, "accuracy_up": 1}
	for index in world.divers.size():
		if OS.get_cmdline_user_args().has("--loss"):
			(world.divers[index] as Diver).stats.hp_max = 1
		(world.divers[index] as Diver).stats.hp = mini(7 - index, (world.divers[index] as Diver).stats.hp_max)
		(world.divers[index] as Diver).stats.oxygen = 53 + index
	(world.divers[0] as Diver).toggle_sonar()
	# Valid older checkpoints preserve effects; optional practice must not
	# clear their original resources while cleaning its borrowed fight.
	(world.divers[1] as Diver).stats.add_status("bleed", 2, 2)
	(world.divers[1] as Diver).stats.temporary_modifiers = {"accuracy": 1, "evasion": 0}
	_expect(world._write_save() == OK, "QT6 fixture could not write its own checkpoint")
	var saved := FileAccess.get_file_as_bytes(checkpoint_path)
	# Load the recovered fixture through the real title path. Merely closing
	# Title leaves HUD hidden and would make synthetic button presses invalid.
	await world._on_title_load_game(slot)
	world.set_physics_process(false)
	world.set_process(false)
	if OS.get_cmdline_user_args().has("--maze"):
		world._enter_maze_scene(true)
		await process_frame
		await process_frame
		_expect(world.embedded_maze.maze_active, "QT11: maze fixture did not enter embedded maze")
	for profile in ["quick", "full"]:
		if OS.get_cmdline_user_args().has("--loss") and profile == "quick":
			continue
		var phases := ["intro", "move", "target", "dodge_instruction", "live_dodge", "finish"]
		if profile == "full":
			phases.append("hover_caption")
		if OS.get_cmdline_user_args().has("--complete"):
			phases = ["complete"]
		if OS.get_cmdline_user_args().has("--loss"):
			phases = ["loss_exit", "loss_retry"]
		for phase in phases:
			if not failures.is_empty():
				break
			await _case(profile, phase, saved)
	for failure in failures:
		push_error(failure)
	print("TUTORIAL SKIP LIFECYCLE|checks=%d|failures=%d" % [checks, failures.size()])
	world.queue_free()
	await process_frame
	# Only the unused fixture slot this script created; no player slots touched.
	DirAccess.remove_absolute(checkpoint_path)
	root.get_node("GameAudio").release_streams_for_shutdown()
	quit(0 if failures.is_empty() else 1)

func _case(profile: String, phase: String, saved: PackedByteArray) -> void:
	_used_practice_item = false
	var resources := []
	var effects := []
	# The checkpoint has crossed JSON: its numeric values may be floats.
	# Compare against the actual loaded inventory, not a differently typed literal.
	var inventory_before := world.inventory.duplicate(true)
	var members: Array[Dictionary] = []
	for diver in world.divers:
		var stats: CombatantStats = diver.stats
		resources.append([stats.hp, stats.oxygen, stats.xp, stats.evasion_current])
		effects.append([stats.statuses.duplicate(true), stats.temporary_modifiers.duplicate(true)])
		members.append((diver as Diver).campaign_member_state())
	world.inventory_menu.open()
	await process_frame
	await process_frame
	world.inventory_menu._help_tab.emit_signal("pressed")
	await process_frame
	await process_frame
	var name := "QuickCombatPractice" if profile == "quick" else "FullCombatLesson"
	var choice := world.inventory_menu.find_child(name, true, false) as Button
	if choice == null or not choice.is_visible_in_tree():
		print("PRACTICE_CHOICE_DIAGNOSTIC|", profile, "|viewport=", root.get_visible_rect(), "|choice=", choice)
		for node in world.inventory_menu._list.get_children():
			if node is Button:
				print("CHOICE|", node.name, "|", node.text, "|visible=", node.is_visible_in_tree())
	_expect(choice != null and choice.is_visible_in_tree() and not choice.disabled, "QT5: optional %s is not reachable in Inventory" % profile)
	if choice == null:
		world.inventory_menu.close()
		return
	choice.emit_signal("pressed")
	await process_frame
	var fight := world.battle
	_expect(fight != null, "QT2: %s did not construct the actual lesson" % profile)
	if fight == null:
		return
	if phase.begins_with("loss"):
		# Adversarial enemy fixture, not a balance claim about the practice
		# Angler. Use actual damage/turn resolution after the guarded stages,
		# never inject finished("lost") or set party HP to zero mid-fight.
		var enemy_stats := fight.enemies[0].stats as CombatantStats
		enemy_stats.hp_max = 200
		enemy_stats.hp = 200
		enemy_stats.strength = 5
		enemy_stats.accuracy = 20
	var results: Array[String] = []
	fight.finished.connect(func(result: String) -> void: results.append(result))
	var deadline := Time.get_ticks_msec() + 160000
	while results.is_empty() and Time.get_ticks_msec() < deadline and not _at_phase(fight, phase):
		await _drive(fight)
	if phase.begins_with("loss"):
		_expect(results == ["lost"], "QT6: actual practice attacks did not cause defeat: %s" % str(results))
		_expect(world.tutorial_result_popup.visible and paused, "QT6: practice defeat did not offer usable Retry/Exit")
		if phase == "loss_retry":
			world.tutorial_result_popup._on_retry_pressed()
			await process_frame
			_expect(world.battle != null and world.battle.tutorial_profile == profile and not paused, "QT6: Retry did not start the same full practice")
			if world.battle != null:
				world.battle.skip_tutorial_btn.emit_signal("pressed")
				var retry_deadline := Time.get_ticks_msec() + 15000
				while world.battle != null and Time.get_ticks_msec() < retry_deadline:
					await process_frame
		else:
			world.tutorial_result_popup._on_exit_pressed()
			await process_frame
	elif phase == "complete":
		_expect(results == ["won"], "QT2/QT6: %s practice did not complete actual moves: %s" % [profile, str(results)])
		if profile == "full" and OS.get_cmdline_user_args().has("--use-item"):
			_expect(_used_practice_item, "QT6: full practice fixture never actually consumed its temporary Focus Tonic")
	else:
		_expect(_at_phase(fight, phase), "QT10: could not reach %s/%s with actual actions" % [profile, phase])
		_expect(fight.skip_tutorial_btn.is_visible_in_tree() and not fight.skip_tutorial_btn.disabled, "QT10: Skip hidden/disabled at %s/%s" % [profile, phase])
		if not _at_phase(fight, phase):
			return
		fight.skip_tutorial_btn.emit_signal("pressed")
		var return_deadline := Time.get_ticks_msec() + 15000
		while world.battle != null and Time.get_ticks_msec() < return_deadline:
			await process_frame
		_expect(results == ["skipped"], "QT10: %s/%s emitted wrong or duplicate result: %s" % [profile, phase, str(results)])
	_expect(world.battle == null and not world.battling and not paused, "QT10: %s/%s did not release World" % [profile, phase])
	if OS.get_cmdline_user_args().has("--maze"):
		_expect(world.embedded_maze.maze_active and not world.cam.current, "QT11: practice did not restore the maze camera/owner")
	for index in members.size():
		var diver := world.divers[index] as Diver
		_expect(diver.stats == members[index].stats, "QT6: original earned stats not restored after %s/%s" % [profile, phase])
		_expect(diver.stats.statuses == effects[index][0] and diver.stats.temporary_modifiers == effects[index][1], "QT6/QT15: practice cleanup erased original campaign effects")
		_expect([diver.stats.hp, diver.stats.oxygen, diver.stats.xp, diver.stats.evasion_current] == resources[index], "QT6: restored resources changed after %s/%s" % [profile, phase])
		if [diver.stats.hp, diver.stats.oxygen, diver.stats.xp, diver.stats.evasion_current] != resources[index]:
			print("PRACTICE_RESOURCE_DIAGNOSTIC|", index, "|expected=", resources[index], "|actual=", [diver.stats.hp, diver.stats.oxygen, diver.stats.xp, diver.stats.evasion_current])
		_expect(diver.sonar_active == bool(members[index].sonar_active), "QT6: practice changed earned Sonar state")
	_expect(world.inventory == inventory_before, "QT6: practice consumed earned inventory")
	_expect(FileAccess.get_file_as_bytes(checkpoint_path) == saved, "QT6: %s/%s overwrote the real checkpoint" % [profile, phase])
	# Hold exploration with its real pause menu while awaiting delayed work;
	# otherwise restored Sonar legitimately bills O2 during this observation.
	world.inventory_menu.open()
	await create_timer(2.0).timeout
	_expect(world.battle == null and paused and world.inventory_menu.visible, "QT10: an interrupted callback reopened or unpaused %s/%s" % [profile, phase])
	world.inventory_menu.close()
	print("SKIP_CASE|", profile, "|", phase, "|results=", results)

func _at_phase(fight: Battle, phase: String) -> bool:
	if phase == "complete":
		return false
	var caption := fight._tutorial_caption.get_parsed_text()
	match phase:
		"intro":
			return fight._tutorial_awaiting_enter and fight._tutorial_step == 0 and not fight.target_menu.visible
		"move":
			return not fight._busy and not fight._tutorial_awaiting_enter and fight.move_menu.visible and not fight.move_buttons.is_empty() and not fight.move_buttons[0].disabled
		"target":
			return fight.target_menu.visible and not fight.target_buttons.is_empty() and not fight._tutorial_awaiting_enter
		"hover_caption":
			return fight.target_menu.visible and fight._tutorial_awaiting_enter
		"dodge_instruction":
			return fight._tutorial_awaiting_enter and (caption.begins_with("Dodge:") or fight._levelup_caption.visible)
		"live_dodge":
			return fight._qte_active
		"finish":
			return fight._tutorial_awaiting_enter and (caption.begins_with("Practice complete") or caption.begins_with("Now defeat the enemy"))
	return false

func _drive(fight: Battle) -> void:
	if int(world.inventory.get("accuracy_up", 0)) == 0:
		_used_practice_item = true
	if fight._tutorial_awaiting_enter:
		if fight._tutorial_continue_btn.is_visible_in_tree():
			fight._tutorial_continue_btn.emit_signal("pressed")
		else:
			var enter := InputEventKey.new()
			enter.keycode = KEY_ENTER
			enter.pressed = true
			Input.parse_input_event(enter)
	elif fight._qte_active:
		# Natural timeout exercises the failure path as well as the skip path.
		pass
	elif fight.target_menu.visible and not fight.target_buttons.is_empty():
		var button := fight.target_buttons[0] as Button
		if button.disabled or button.button_mask == 0:
			button.emit_signal("mouse_entered")
		else:
			button.emit_signal("pressed")
	elif not fight._busy and fight.move_menu.visible:
		for candidate in fight.move_buttons:
			if candidate.is_visible_in_tree() and not candidate.disabled:
				(candidate as Button).emit_signal("pressed")
				break
	elif not fight._busy and fight.item_menu.visible:
		for candidate in fight.item_buttons:
			if candidate.is_visible_in_tree() and not candidate.disabled and candidate.text.begins_with("Focus Tonic"):
				(candidate as Button).emit_signal("pressed")
				break
	elif not fight._busy and fight.main_menu.visible and not fight.attack_btn.disabled:
		if OS.get_cmdline_user_args().has("--use-item") and fight._tutorial_finale_shown and not _used_practice_item and not fight.items_btn.disabled:
			fight.items_btn.emit_signal("pressed")
		else:
			fight.attack_btn.emit_signal("pressed")
	await create_timer(0.03).timeout
