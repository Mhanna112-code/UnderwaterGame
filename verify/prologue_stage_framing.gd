# OPEN-012 / OPEN-AUDIT-008: valid imported bounds can still make the boss
# unreadably small in the real short battle stage. Run at 720x480 and wide.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await world._on_title_new_game(918306)
	var swim := InputEventKey.new()
	swim.keycode = KEY_W
	swim.physical_keycode = KEY_W
	swim.pressed = true
	Input.parse_input_event(swim)
	var deadline := Time.get_ticks_msec() + 10000
	while not world.battling and Time.get_ticks_msec() < deadline:
		await physics_frame
	swim.pressed = false
	Input.parse_input_event(swim)
	await process_frame
	var fight := world.battle
	if fight == null:
		push_error("OPEN-035 physical swim failed to start the framing fixture")
		quit(1)
		return
	await fight.reveal_prologue_octopus()
	await create_timer(0.1).timeout
	var actor := fight.enemies[0].actor as PrologueOctopus
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for vertex in actor.current_pose_points():
		var point := fight._stage_cam.unproject_position(vertex)
		low = low.min(point)
		high = high.max(point)
	var size := Vector2(fight._stage_vp.size)
	print("Observed viewport: ", root.get_visible_rect().size, " stage: ", size)
	var fraction := (high.y - low.y) / size.y
	print("Cordys projected stage-height fraction: %.3f" % fraction)
	if size.y < 500.0 and fraction < 0.45:
		findings.append("OPEN-012 narrow-stage boss reads miniature (below 45% stage height)")
	# A tall view is width-limited; filling 45% of its height would crop the
	# action horizontally. Retain a concrete readable pixel floor there.
	if high.y - low.y < 90.0:
		findings.append("OPEN-012 boss reads miniature (below 90 visible pixels)")
	if low.x < 0.0 or high.x > size.x or low.y < 0.0 or high.y > size.y:
		findings.append("OPEN-012 boss framing clips the idle silhouette")
	# Idle bounds alone cannot prove the authored finishing pose fits. Sample
	# the actual moving skin against the unchanged production camera.
	for key in ["idle", "reveal", "hurt", "finish"]:
		var length := actor.play(key)
		for sample in range(21):
			var fraction_value := float(sample) / 20.0
			actor.anim.seek(length * fraction_value, true)
			var pose_low := Vector2(INF, INF)
			var pose_high := Vector2(-INF, -INF)
			for vertex in actor.current_pose_points():
				if fight._stage_cam.is_position_behind(vertex):
					findings.append("OPEN-012 %s passes behind the camera" % key)
					break
				var point := fight._stage_cam.unproject_position(vertex)
				pose_low = pose_low.min(point)
				pose_high = pose_high.max(point)
			print("Cordys pose %s %.1f screen bounds %s %s" % [key, fraction_value, pose_low, pose_high])
			if pose_low.x < 0.0 or pose_high.x > size.x or pose_low.y < 0.0 or pose_high.y > size.y:
				findings.append("OPEN-012 %s %.1f clips the moving silhouette" % [key, fraction_value])
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(918306)))
	for finding in findings:
		print("FINDING  " + finding)
	quit(0 if findings.is_empty() else 1)
