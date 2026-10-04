extends SceneTree
const SLOT := 918361
var findings: Array[String] = []
var output := ""

func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		output = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await process_frame
	world.route_state.opening_video_seen = true
	world.route_state.prologue_complete = true
	world.route_state.tutorial_complete = false
	SaveManager.write_slot(SLOT, world._serialize_state())
	await world._on_title_load_game(SLOT)
	for _frame in range(20):
		await process_frame
	var label := world.find_child("OptionalTrainingLabel", true, false) as Label3D
	var camera := world.get_viewport().get_camera_3d()
	var diver := world.divers[world.active] as Diver
	var label_screen := camera.unproject_position(label.global_position)
	var head_screen := camera.unproject_position(diver.global_position + Vector3.UP * diver.head_offset())
	_expect(label_screen.distance_to(head_screen) >= root.size.y * 55.0 / 720.0,
		"OPEN-032 optional text lies behind recovered diver's head: label=%s head=%s" % [label_screen, head_screen])
	await _shot("recovered-training.png")
	world.random_encounters_enabled = false
	var points := world.deep_zone_layout.route_points()
	for id in ["bomb_bot", "sword_slayer"]:
		var actor := world._route_blocker_world_actors[id] as Node3D
		_expect(actor.is_visible_in_tree(), "GUARD-01 undefeated " + id + " is invisible before either fight")
		var bounds := world._route_actor_visible_bounds(actor)
		_expect(absf(bounds.get_center().z - (points[id] as Vector3).z) < 0.5,
			"GUARD-02 visible " + id + " is off the centre of its gate: " + str(bounds.get_center()))
	# Separate second-route fixture is disclosed: does not inject a battle win.
	for id in ["bomb_bot", "sword_slayer"]:
		if id == "sword_slayer":
			world.route_state.set_blocker_state("bomb_bot", "defeated")
			world._sync_deep_zone_blocker_staging()
		diver.position = (points[id] as Vector3) - Vector3(12, 0, 0)
		world.yaw = PI * 0.5
		world.pitch = -0.14
		world._inside_route_blocker_id = id
		await _settle_camera()
		var actor := world._route_blocker_world_actors[id] as Node3D
		var bounds := world._route_actor_visible_bounds(actor)
		var guard_top := camera.unproject_position(bounds.get_center() + Vector3.UP * bounds.size.y * 0.5)
		var diver_head := camera.unproject_position(diver.global_position + Vector3.UP * diver.head_offset())
		_expect(guard_top.y < diver_head.y - 25.0, "GUARD-03 " + id + " silhouette hidden behind diver on centreline approach")
		await _shot(id + "-approach.png")
		# A separate three-quarter human camera shows the actual silhouette,
		# not only the root-centering oracle. Keep the encounter/guard unchanged.
		world.yaw += 0.2
		await _settle_camera()
		await _shot(id + "-quarter-approach.png")
	# OPEN-046: camera foreground at the real save point, plus normal contact.
	diver.position = Vector3(13.0, 2.0, 10.0)
	diver.velocity = Vector3.ZERO
	world.yaw = PI * 0.5
	world.pitch = -0.14
	await _settle_camera()
	# SavePoint is a script class, not a built-in get_class() name. Filtering
	# find_children by it could silently inspect zero crystals and pass.
	var near_crystals := 0
	for node in world._save_points:
		var point := node as SavePoint
		for child in point.get_children():
			if child is MeshInstance3D and child.mesh is TorusMesh:
				var ring_bounds: AABB = child.global_transform * child.get_aabb()
				_expect(ring_bounds.size.y < 0.5,
					"OPEN-046b rest ring is upright and still hides the diver after crystal fade")
				_expect(ring_bounds.end.y < diver.global_position.y - 0.5,
					"OPEN-046b flat rest ring still lies across the approaching diver's torso")
		if camera.global_position.distance_to(point._crystal.global_position) < 5.0:
			near_crystals += 1
			_expect(not point._crystal.visible, "OPEN-046 near-camera crystal still opaque")
	_expect(near_crystals > 0, "OPEN-046 close-camera fixture did not actually test any crystal")
	await _shot("close-save-point.png")
	var save_point := world._save_points[0] as SavePoint
	for member in world.divers:
		member.stats.hp = 1
		member.stats.oxygen = 1.0
	diver.global_position = save_point.global_position
	diver.velocity = Vector3.ZERO
	for _frame in range(10):
		await physics_frame
	_expect(save_point.has_diver(diver), "OPEN-046 faded landmark no longer detects save-point contact")
	for member in world.divers:
		_expect(member.stats.hp == member.stats.hp_max and member.stats.oxygen == member.stats.oxygen_max,
			"OPEN-046 faded landmark no longer restores whole party")
	root.get_node("CharacterAbilityPopup").call("_close")
	world._toggle_save_menu()
	_expect(world.save_point_menu.visible, "OPEN-046 normal P action cannot reach Save menu")
	# Keep the disposable slot: normal save-request contract, real file write.
	world.save_point_menu.save_requested.emit(diver, SLOT)
	_expect(bool(SaveManager.read_slot(SLOT).get("route_state", {}).get("prologue_complete", false)),
		"OPEN-046 real save-point write lost completed opening")
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(SLOT)))
	for finding in findings:
		print("FINDING ", finding)
	print("OPENING DISCOVERABILITY: clean" if findings.is_empty() else "OPENING DISCOVERABILITY: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _shot(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name))

func _settle_camera() -> void:
	# Teleported setup is not physical swimming. Let the normal chase camera
	# reach the disclosed fixture before evaluating occlusion. Counting 20–30
	# render frames gave different poses at 60/120 Hz and when screenshots added
	# a GPU readback; a no-output aggregate falsely missed the crystal entirely.
	await create_timer(1.0).timeout
	for _frame in range(8):
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
