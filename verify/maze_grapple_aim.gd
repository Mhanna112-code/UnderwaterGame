extends SceneTree
## AIM-1: F must enter first-person aim without firing or spending resources.
var findings: Array[String] = []
var maze: MazeLevel
var diver: Diver
var cases := 0
var captures := ""
var items_collected: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			captures = arg.trim_prefix("--capture-dir=")
	maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	for frame in 8:
		await physics_frame
	maze.random_encounters_enabled = false
	maze.room_encounters_enabled = false
	await _key(KEY_TAB)
	diver = maze.divers[maze.active] as Diver
	_expect(diver.ability_id == "grapple", "AIM-1 actual Tab did not select Musashi")
	# Isolated open-water/input fixture, not physical maze progression.
	for i in maze.divers.size():
		maze.divers[i].global_position = Vector3(3000 + i * 4, 2, 3000)
		maze.divers[i].velocity = Vector3.ZERO
	diver.stats.oxygen = 0
	maze._yaw = 0
	maze._pitch = 0
	var start := diver.global_position
	var anchor := GrappleAnchor.new()
	maze.add_child(anchor)
	anchor.global_position = start + Vector3(0, diver.height * 0.4, 6)
	for frame in 5:
		await physics_frame
	await _key(KEY_F)
	_expect(not diver.model.visible and not diver.is_grappling() and diver.global_position.distance_to(start) < 0.05
		and diver.can_use_ability() and diver.stats.oxygen == 0,
		"AIM-1 real F fires/moves/spends cooldown instead of hiding the model for first-person aim")
	if findings.is_empty():
		for frame in 6:
			await physics_frame
		var eye := diver.global_position + Vector3(0, diver.height * 0.4, 0)
		var camera := maze.get_node("Camera3D") as Camera3D
		_expect(camera.global_position.distance_to(eye) < 0.05 and (-camera.global_basis.z).dot(Vector3(0, 0, 1)) > 0.999,
			"AIM-1 camera is not at the actual shot's eye/direction")
		_expect(_hud().contains("Left click") and _hud().contains("cancel"), "AIM-1 first-person view has no fire/cancel instructions")
		await _capture("anchor-aim")
		await _key(KEY_ESCAPE)
		await _cancel_cases()
		await _target_cases(start, anchor)
		await _owner_cases()
		await _save_owner_case()
		await _teardown_case()
	await _finish()

func _cancel_cases() -> void:
	for oxygen in [0.0, 11.0, 30.0]:
		for exit in ["escape", "right", "inactive"]:
			diver.stats.oxygen = oxygen
			var hp := diver.stats.hp
			await _key(KEY_F)
			_expect(not diver.model.visible and not maze.can_capture_campaign_snapshot(), "AIM-2/3 generated aim cannot start or is saveable")
			if exit == "escape":
				await _key(KEY_ESCAPE)
			elif exit == "right":
				await _click(MOUSE_BUTTON_RIGHT)
			else:
				maze.set_maze_active(false)
				maze.set_maze_active(true)
			_expect(diver.model.visible and diver.can_use_ability() and not diver.is_grappling()
				and not maze.inventory_menu.visible and diver.stats.oxygen == oxygen and diver.stats.hp == hp,
				"AIM-2 cancel/handoff hides model, spends resources/cooldown or stacks menu: " + exit)
			cases += 1
	print("MAZE AIM CANCEL|generated=", cases)

func _target_cases(start: Vector3, anchor: GrappleAnchor) -> void:
	diver.stats.oxygen = 0
	await _key(KEY_F)
	for frame in 5:
		await physics_frame
	var ring := maze.get_node("GrappleAimReticle") as MeshInstance3D
	var to_eye: Vector3 = ((maze.get_node("Camera3D") as Camera3D).global_position - ring.global_position).normalized()
	_expect(absf(ring.global_basis.y.dot(to_eye)) > 0.999,
		"AIM-4 torus reticle is edge-on rather than facing the camera")
	_expect(ring.visible and absf(ring.global_position.z - (anchor.global_position.z - anchor.target_radius)) < 0.1,
		"AIM-4 preview misses real anchor surface")
	await _click(MOUSE_BUTTON_LEFT)
	await create_timer(0.6).timeout
	_expect(diver.model.visible and not diver.is_grappling() and diver.global_position.distance_to(start) > 4
		and diver.stats.oxygen == 0 and not diver.can_use_ability(), "AIM-4 actual click fails free anchor travel/cooldown/model restoration")
	await _key(KEY_F)
	_expect(diver.model.visible, "AIM-3 cooldown allows another aim")
	await create_timer(0.8).timeout
	anchor.queue_free()
	await process_frame
	diver.global_position = start
	var orb := ItemOrb.new()
	orb.item_id = "potion"
	orb.grappleable = true
	orb.grapple_only = true
	orb.collected.connect(func(item: String, shooter: Diver) -> void: items_collected.append([item, shooter]))
	maze.add_child(orb)
	orb.global_position = start + Vector3(0, diver.height * 0.4, 6)
	for frame in 5:
		await physics_frame
	await _key(KEY_F)
	for frame in 5:
		await physics_frame
	_expect(ring.visible and absf(ring.global_position.z - (start.z + 5.4)) < 0.1, "AIM-4 preview excludes layer-5 orb")
	await _capture("item-aim")
	await _click(MOUSE_BUTTON_LEFT)
	await create_timer(0.7).timeout
	_expect(items_collected.size() == 1 and items_collected[0] == ["potion", diver]
		and diver.global_position.distance_to(start) < 0.05 and diver.model.visible and diver.stats.oxygen == 0,
		"AIM-4 actual item shot moves shooter or fails layer-5 reel ownership")
	await create_timer(0.6).timeout
	# A solid wall in front of a second item must occlude both preview/fire.
	orb = ItemOrb.new()
	orb.grappleable = true
	orb.grapple_only = true
	orb.collected.connect(func(_item: String, _shooter: Diver) -> void: items_collected.append(["wrong"]))
	maze.add_child(orb)
	orb.global_position = start + Vector3(0, diver.height * 0.4, 6)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.5)
	shape.shape = box
	wall.add_child(shape)
	maze.add_child(wall)
	wall.global_position = start + Vector3(0, diver.height * 0.4, 2)
	for frame in 5:
		await physics_frame
	await _key(KEY_F)
	for frame in 5:
		await physics_frame
	_expect(absf(ring.global_position.z - (start.z + 1.75)) < 0.1, "AIM-4 preview draws through solid wall")
	await _click(MOUSE_BUTTON_LEFT)
	await create_timer(0.7).timeout
	_expect(items_collected.size() == 1 and diver.can_use_ability() and diver.model.visible
		and diver.global_position.distance_to(start) < 0.05, "AIM-4 occluded miss reels item, moves shooter or spends cooldown")
	orb.queue_free()
	wall.queue_free()
	print("MAZE AIM TARGETS|anchor_travel=true|layer5_reel=true|wall_occlusion=true|zero_O2=true")

func _owner_cases() -> void:
	# Real Control Room location enables L; ownership grant is a modal-only
	# fixture, not map acquisition proof. E is in reach of the actual chest.
	maze.key_items.append("maze_nav_map")
	diver.global_position = maze.get_node("MapChest").global_position + Vector3(0, 1.5, 1.8)
	for frame in 5:
		await physics_frame
	_expect(maze.can_open_nav_map(), "AIM-3 location fixture cannot actually open navigation")
	var encounters := maze.random_encounters_enabled
	await _key(KEY_F)
	for key in [KEY_TAB, KEY_E, KEY_P, KEY_L, KEY_F, KEY_R, KEY_Q]:
		await _key(key)
		_expect(maze.active == 1 and not diver.model.visible and not maze.inventory_menu.visible
			and not maze.get_node("HUD/MazeMiniMap").main_map.visible
			and not maze.any_modal_open() and not maze.can_capture_campaign_snapshot()
			and maze.random_encounters_enabled == encounters,
			"AIM-3 input changes active owner or makes aim saveable: " + str(key))
	await _key(KEY_ESCAPE)
	await _key(KEY_L)
	_expect(maze.get_node("HUD/MazeMiniMap").main_map.visible and paused and diver.model.visible,
		"AIM-3 canceled aim strands the next legitimate map/lesson")
	await _key(KEY_ESCAPE)
	await _key(KEY_L)
	print("MAZE AIM OWNERS|blocked_keys=7|post_cancel_map=true")

func _hud() -> String:
	var labels: Array[String] = []
	for label in maze.get_node("HUD").find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			labels.append(label.text)
	return "\n".join(labels)

func _save_owner_case() -> void:
	var point := maze.get_node("MazeCheckpoint") as SavePoint
	diver.global_position = point.global_position + Vector3(0, 1.5, 0)
	diver.velocity = Vector3.ZERO
	for frame in 10:
		await physics_frame
	_expect(point.has_diver(diver), "AIM-3 checkpoint fixture is not in actual contact")
	await _key(KEY_F)
	await create_timer(4.2).timeout
	_expect(not _hud().contains("F: ability") and not _hud().contains("TAB switch") and not _hud().contains("R: Encounters"),
		"AIM-3 aim HUD advertises blocked ability/selection/encounter controls after notices drain")
	await _capture("maze-checkpoint-aim")
	await _key(KEY_P)
	_expect(not diver.model.visible and not maze.any_modal_open(), "AIM-3 real contact P stacks a Save menu on aim")
	await _key(KEY_ESCAPE)
	await _key(KEY_P)
	_expect(maze.any_modal_open() and diver.model.visible, "AIM-3 cancel strands real contact P")
	await _key(KEY_P)
	var saved := maze.campaign_snapshot()
	await _key(KEY_F)
	maze.restore_campaign_snapshot(JSON.parse_string(JSON.stringify(saved)))
	for frame in 3:
		await physics_frame
	_expect(diver.model.visible and diver.can_use_ability(), "AIM-2 public restore retains hidden previous shooter")
	print("MAZE AIM CHECKPOINT|no_file_write=true|contact_P_after_cancel=true|restore_cancels=true")

func _teardown_case() -> void:
	# Embedded actors belong to World, not the Maze subtree. Retain this actual
	# actor outside the subtree to exercise that lifecycle without freeing it
	# with the standalone fixture. This is not campaign traversal evidence.
	var stats := diver.stats
	var hp := stats.hp
	var oxygen := stats.oxygen
	await _key(KEY_F)
	_expect(not diver.model.visible, "AIM-2 teardown fixture never entered actual F aim")
	diver.reparent(root)
	maze.queue_free()
	for frame in 3:
		await process_frame
	_expect(is_instance_valid(diver) and diver.model.visible and diver.stats == stats
		and stats.hp == hp and stats.oxygen == oxygen and diver.can_use_ability(),
		"AIM-2 scene teardown leaves the surviving shared model hidden or changes its resources")
	print("MAZE AIM TEARDOWN|surviving_actor=true|model_restored=true|resources_unchanged=true")
	diver.queue_free()

func _click(button: MouseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _capture(label: String) -> void:
	if not captures.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(captures.path_join(label + ".png"))

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

func _finish() -> void:
	if is_instance_valid(maze):
		maze.queue_free()
	for frame in 3:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE GRAPPLE AIM: clean" if findings.is_empty() else "MAZE GRAPPLE AIM: failed")
	quit(0 if findings.is_empty() else 1)
