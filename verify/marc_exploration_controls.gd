extends SceneTree

var failures: Array[String] = []
var checks := 0

class ShockwaveObserver extends Node:
	var hits := 0
	func _ready() -> void:
		add_to_group("shockwave_breakable")
	func on_shockwave(_origin: Vector3, _radius: float) -> void:
		hits += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = false
	world.set_physics_process(false)
	world.active = 0
	world.divers[0].stats.oxygen = 0.0
	await _tap(KEY_F)
	_check(world.target_selector.selecting, "CTL-1: actual F starts zero-Oxygen World Swap")
	await _tap(KEY_ESCAPE)
	await _help_contract(world)
	await _ability_controls(world, true)
	world.queue_free()
	await process_frame
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	for frame in 12:
		await physics_frame
	maze.room_encounters_enabled = false
	maze.random_encounters_enabled = false
	maze.set_physics_process(false)
	for i in maze.divers.size():
		maze.divers[i].global_position = Vector3(2000 + i * 4, 2, 2000)
		maze.divers[i].stats.oxygen = 0.0
	await _tap(KEY_E)
	_check(not maze.target_selector.selecting, "CTL-2: empty-context E does not fire Maze Swap")
	if maze.target_selector.selecting:
		maze.target_selector.cancel_selection()
	await _tap(KEY_F)
	_check(maze.target_selector.selecting, "CTL-1: actual F starts zero-Oxygen Maze Swap")
	await _tap(KEY_ESCAPE)
	await _ability_controls(maze, false)
	maze.queue_free()
	await process_frame
	_finish()

func _tap(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _check(ok: bool, description: String) -> void:
	if ok:
		checks += 1
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func _finish() -> void:
	paused = false
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	print("MARC EXPLORATION CONTROLS: clean|checks=%d" % checks if failures.is_empty() else "MARC EXPLORATION CONTROLS: %s" % str(failures))
	quit(0 if failures.is_empty() else 1)

func _ability_controls(owner: Node, is_world: bool) -> void:
	var roster: Array = owner.divers
	var area := "World" if is_world else "Maze"
	var probe := ShockwaveObserver.new()
	owner.add_child(probe)
	for selected in 3:
		_check(owner.active == selected, "CTL-1: actual Tab selects %s diver %d" % [area, selected])
		for i in roster.size():
			roster[i].global_position = Vector3(2000 + selected * 40 + i * 4, 2, 2000)
			# Grapple/Swap stay free at zero Oxygen; Shockwave now costs
			# Diver.SHOCKWAVE_OXYGEN_COST, so give Bucky enough for two uses.
			roster[i].stats.oxygen = Diver.SHOCKWAVE_OXYGEN_COST * 2.0 if roster[i].ability_id == "shockwave" else 0.0
		var diver := roster[selected] as Diver
		var start := diver.global_position
		var before := probe.hits
		var anchor := GrappleAnchor.new()
		owner.add_child(anchor)
		anchor.global_position = start + Vector3(0, diver.height * 0.4, 6)
		if is_world:
			owner.yaw = 0.0
			owner.pitch = 0.0
		else:
			var camera := owner.get_node("Camera3D") as Camera3D
			camera.look_at(camera.global_position + Vector3(0, 0, 1), Vector3.UP)
			owner._yaw = 0.0
			owner._pitch = 0.0
		await physics_frame
		await _tap(KEY_E)
		_check(not owner.target_selector.selecting and not diver.is_grappling() and probe.hits == before
			and diver.global_position.is_equal_approx(start) and diver.can_use_ability()
			and (not is_world or not owner.aiming),
			"CTL-2: empty-context E cannot use %s %s" % [area, diver.ability_id])
		await _key_event(KEY_F, false)
		await _key_event(KEY_F, true, true)
		await _key_event(KEY_F, false)
		_check(not owner.target_selector.selecting and not diver.is_grappling() and probe.hits == before
			and diver.can_use_ability() and (not is_world or not owner.aiming),
			"CTL-1: release/echo cannot fire %s %s" % [area, diver.ability_id])
		await _tap(KEY_F)
		match diver.ability_id:
			"swap":
				_check(owner.target_selector.selecting, "CTL-1: F selects zero-Oxygen %s Swap" % area)
				var first: Node3D = owner.target_selector.current_target()
				await _tap(KEY_F)
				await _tap(KEY_E)
				_check(owner.target_selector.current_target() == first and owner.active == selected,
					"CTL-3: F/E cannot restart or consume %s Swap selection" % area)
				await _tap(KEY_RIGHT)
				var target := owner.target_selector.current_target() as Diver
				_check(target != null and target != first, "CTL-1: actual arrow selects another %s Swap target" % area)
				if target != null:
					var destination := target.global_position
					await _tap(KEY_ENTER)
					_check(not owner.target_selector.selecting and diver.global_position.is_equal_approx(destination)
						and target.global_position.is_equal_approx(start) and diver.stats.oxygen == 0,
						"CTL-1: confirmed %s Swap trades real positions at zero Oxygen" % area)
			"grapple":
				_check(owner.aiming and not diver.is_grappling(), "CTL-1: %s F enters aim without firing" % area)
				await _tap(KEY_ESCAPE)
				_check(not owner.aiming and not owner.inventory_menu.visible and diver.can_use_ability(),
					"CTL-3: %s aim Escape cancels without stacking pause or cooldown" % area)
				await _tap(KEY_F)
				await _click(MOUSE_BUTTON_LEFT)
				_check(diver.is_grappling(), "CTL-1: %s F flow hits actual anchor at zero Oxygen" % area)
				await create_timer(0.5).timeout
				_check(diver.global_position.distance_to(start) > 4.0 and not diver.is_grappling() and diver.stats.oxygen == 0,
					"CTL-1: %s anchor completes actual traversal without Oxygen" % area)
			"shockwave":
				_check(probe.hits == before + 1 and is_equal_approx(diver.stats.oxygen, Diver.SHOCKWAVE_OXYGEN_COST),
					"CTL-1: %s F delivers one real Shockwave and spends its Oxygen" % area)
				await _tap(KEY_F)
				_check(probe.hits == before + 1, "CTL-1: %s Shockwave cooldown prevents repeated F" % area)
		anchor.queue_free()
		# Recovery of cooldown is a real clock boundary, not a reset fixture.
		await create_timer(2.6).timeout
		_check(diver.can_use_ability(), "CTL-1: %s %s cooldown eventually releases" % [area, diver.ability_id])
		var pos := diver.global_position
		await _tap(KEY_ESCAPE)
		_check(owner.inventory_menu.visible, "CTL-3: actual %s Escape acquires menu ownership" % area)
		for code in [KEY_F, KEY_E, KEY_TAB]:
			await _tap(code)
			_check(owner.inventory_menu.visible and owner.active == selected and not owner.target_selector.selecting
				and diver.can_use_ability() and diver.global_position.is_equal_approx(pos)
				and (not is_world or not owner.aiming),
				"CTL-3: %s pause blocks real %s ability/diver leakage" % [area, OS.get_keycode_string(code)])
		await _tap(KEY_ESCAPE)
		_check(not paused and not owner.inventory_menu.visible and diver.can_use_ability(),
			"CTL-3: closing %s pause restores usable ability without firing" % area)
		if selected < 2:
			await _tap(KEY_TAB)
	probe.queue_free()
	await process_frame

func _key_event(code: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await process_frame

func _click(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.button_index = button
	Input.parse_input_event(event)
	await process_frame

func _help_contract(world: World) -> void:
	# Public help content must name the human-approved key, not reuse a
	# production key constant that could be wrong in exactly the same way.
	var slot := Slot.new()
	for body in [slot.maxilaniSwapBody, slot.musashiGrappleBody, slot.buckyShockwaveBody]:
		_check(String(body).contains(" F [/color]") and not String(body).contains(" E [/color]"),
			"CTL-4: exploration popup keycap teaches F, not E")
	slot.free()
	for ability in ["swap", "grapple", "shockwave"]:
		var body := String(TutorialContent.WORLD_ABILITY_BLURBS[ability]).to_lower()
		_check(body.contains("press f") and not body.contains("press e"),
			"CTL-4: exploration reference teaches F for " + ability)
	var onboarding := AbilityOnboarding.new()
	world.add_child(onboarding)
	onboarding.open_for_world(world)
	for page_index in 4:
		var page := onboarding.current_page_data()
		if not String(page.ability_id).is_empty():
			var keys: Array = page.keys
			var teaches_f := false
			var teaches_e := false
			for key in keys:
				teaches_f = teaches_f or String(key).begins_with("F ")
				teaches_e = teaches_e or String(key).begins_with("E ")
			_check(teaches_f and not teaches_e and String(page.body).contains("]F[/color]"),
				"CTL-4: paged lesson body and badges agree on F for " + String(page.ability_id))
		onboarding.advance_page()
	_check(not paused, "CTL-3: optional lesson relinquishes pause ownership")
	onboarding.queue_free()
	await process_frame
	_check(String(TutorialContent.ABILITY_BLURBS.swap).contains(" E ")
		and String(TutorialContent.ABILITY_BLURBS.shockwave).contains(" E "),
		"CTL-5: special minigame E instructions remain distinct")
