extends SceneTree
const SLOT := 918501
var world: World
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if SaveManager.slot_exists(SLOT):
		print("FINDING ROCK-3 reserved slot already exists; refusing overwrite")
		quit(1)
		return
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	world.get_node("HUD").visible = true
	paused = false
	world.route_state.prologue_complete = true
	# Post-tutorial play: an unfinished tutorial now forces the light-beam
	# walk-over on Load, which locks abilities (F) until the tutorial fight.
	world.route_state.tutorial_complete = true
	world.route_state.set_prologue_phase("complete")
	world.random_encounters_enabled = false
	world.yaw = 0.0
	var diver := world.divers[world.active] as Diver
	diver.global_position = Vector3(6, 2, -12)
	await _hold(KEY_W, 1.1)
	_expect(diver.global_position.distance_to(Vector3(6, 1, -7)) < 3.0, "ROCK-1 actual W did not reach early reward rock: %s" % diver.global_position)
	var text := world.route_objective_label.text.to_lower()
	# The "Break rocks for items" prompt was removed on request; reward rocks
	# are now signposted only by their Sonar minimap marker.
	_expect(not ("break" in text and "rock" in text),
		"ROCK-1 removed rock-loot prompt is still shown near an early reward rock: " + text)
	if OS.get_cmdline_user_args().has("--extended"):
		await _extended()
	await _finish()

func _extended() -> void:
	var diver := world.divers[0] as Diver
	var rng := RandomNumberGenerator.new()
	rng.seed = 72501
	for id in ["rock_0", "rock_1", "rock_2"]:
		var rock := world._cracked_walls[id] as CrackedWall
		for sample in 12:
			var offset := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.5, 1.2), rng.randf_range(-1, 1)).normalized() * 2.25
			diver.global_position = rock.global_position + offset
			diver.velocity = Vector3.ZERO
			await _frames(3)
			_expect(not _loot_hint(), "ROCK-2 removed rock-loot prompt reappeared at %s" % diver.global_position)
	for point in [Vector3(6, 12, -7), Vector3(-30, 2, 30), Vector3(-38, 19, -30), Vector3(10, 19, 46)]:
		diver.global_position = point
		diver.velocity = Vector3.ZERO
		await _frames(3)
		_expect(not _loot_hint(), "ROCK-2 distant/high/scenery/ambush location promises rock loot")
	diver.global_position = Vector3(6, 2, -9)
	await _frames(3)
	var completed := world._serialize_state()
	# An interrupted opening uses the World checkpoint contract, not a
	# completed campaign envelope with contradictory milestone fields.
	var unfinished := world._serialize_world_state()
	unfinished.route_state.prologue_complete = false
	unfinished.route_state.opening_video_seen = true
	_expect(SaveManager.write_slot(SLOT, unfinished) == OK, "ROCK-2 unfinished fixture write failed")
	world.title_screen.load_game_chosen.emit(SLOT)
	await _frames(3)
	_expect(not world.route_objective_panel.visible, "ROCK-2 item prompt interrupts unfinished prologue")
	_expect(SaveManager.write_slot(SLOT, completed) == OK, "ROCK-2 completed fixture write failed")
	world.title_screen.load_game_chosen.emit(SLOT)
	await _frames(3)
	await _capture()
	# Inactive diver's proximity cannot leak into the selected one's guidance.
	await _hold(KEY_TAB, 0.05)
	_expect(not _loot_hint(), "ROCK-2 Tab away retains inactive diver's rock prompt")
	(world.divers[2] as Diver).global_position = Vector3(6, 2, -12)
	await _hold(KEY_TAB, 0.05)
	await _hold(KEY_W, 1.1)
	_expect(not _loot_hint(), "ROCK-3 removed rock-loot prompt reappeared for active Bucky")
	var inventory_before := 0
	for count in world.inventory.values():
		inventory_before += int(count)
	await _hold(KEY_F, 0.05)
	await _frames(4)
	_expect(world.consumed_world_ids.has("rock_0"), "ROCK-3 actual F did not break nearby rock")
	_expect(not _loot_hint(), "ROCK-3 broken target keeps reward hint")
	var orb: ItemOrb
	for child in world.get_children():
		if child is ItemOrb:
			orb = child as ItemOrb
			break
	if orb == null:
		# A reward may already overlap a real nearby diver on its first frame.
		var inventory_after := 0
		for count in world.inventory.values():
			inventory_after += int(count)
		_expect(inventory_after == inventory_before + 1, "ROCK-3 Shockwave spawned neither collectible nor collected item")
	else:
		var item_id := orb.item_id
		var before := int(world.inventory.get(item_id, 0))
		var bucky := world.divers[2] as Diver
		bucky.global_position = orb.global_position - Vector3(0, bucky.height * 0.5, 0)
		bucky.velocity = Vector3.ZERO
		await _frames(8)
		_expect(int(world.inventory.get(item_id, 0)) == before + 1, "ROCK-3 actual overlap failed to collect rock reward into inventory")
	var saved := world._serialize_state()
	_expect(SaveManager.write_slot(SLOT, saved) == OK, "ROCK-3 disposable checkpoint write failed")
	world.queue_free()
	await process_frame
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.load_game_chosen.emit(SLOT)
	await _frames(6)
	_expect(world.consumed_world_ids.has("rock_0") and not _loot_hint(), "ROCK-3 cold Title Load resurrected consumed-rock prompt")

func _loot_hint() -> bool:
	return world.route_objective_panel.visible and "item" in world.route_objective_label.text.to_lower() and "shockwave" in world.route_objective_label.text.to_lower()

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _capture() -> void:
	if not "--capture" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	for size in [Vector2i(1280, 720), Vector2i(720, 480), Vector2i(360, 640)]:
		root.size = size
		await _frames(35)
		await RenderingServer.frame_post_draw
		var panel := world.route_objective_panel.get_global_rect()
		var label := world.route_objective_label
		_expect(root.get_visible_rect().encloses(panel) and panel.encloses(label.get_global_rect()), "ROCK-4 reward prompt clips at %s" % size)
		_expect(label.size.y >= label.get_minimum_size().y, "ROCK-4 wrapped item hint lacks text height at %s" % size)
		_expect(not panel.intersects(Rect2(Vector2(size.x - 166, 0), Vector2(166, 166))), "ROCK-4 minimap covers item prompt at %s" % size)
		root.get_texture().get_image().save_png("/tmp/reward-rock-hint-%dx%d.png" % [size.x, size.y])

func _hold(code: Key, seconds: float) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(seconds).timeout
	event.pressed = false
	Input.parse_input_event(event)
	await physics_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	if SaveManager.slot_exists(SLOT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(SLOT)))
	for finding in findings:
		print("FINDING ", finding)
	print("REWARD ROCK GUIDANCE: clean" if findings.is_empty() else "REWARD ROCK GUIDANCE: findings=%d" % findings.size())
	quit(0 if findings.is_empty() else 1)
