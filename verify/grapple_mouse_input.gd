extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var diver := Diver.new()
	diver.model_name = "Prototype_1(1910)"
	viewport.add_child(diver)
	var enemy := Goblin.new()
	viewport.add_child(enemy)
	enemy.global_position = Vector3(0.0, 1.5, -8.0)

	# Match battle.gd's split layout: the 3D SubViewport only owns the upper
	# playfield while combat controls sit below it. This guards the browser
	# regression where full-window UI coordinates and 3D aim coordinates drifted
	# apart after a layout change.
	var stage_frame := Control.new()
	stage_frame.position = Vector2(0.0, 58.0)
	stage_frame.size = Vector2(1280.0, 410.0)
	root.add_child(stage_frame)
	var minigame := GrappleInterceptMinigame.new()
	minigame.stage_root = viewport
	minigame.stage_camera = camera
	minigame.target_actor = diver
	minigame.enemy_actor = enemy
	minigame.source_position = enemy.global_position
	minigame.stage_rect = Rect2(stage_frame.position, stage_frame.size)
	# Battle keeps the overlay in its HUD layer, not as a child of the 3D
	# stage frame. Keeping it a sibling makes stage_rect a global UI rectangle.
	root.add_child(minigame)
	minigame.run()
	await process_frame
	_check(minigame.get_global_rect().is_equal_approx(Rect2(Vector2(0.0, 58.0), Vector2(1280.0, 410.0))), "grapple_mouse_input: overlay exactly follows the battle stage rectangle — guards against full-window aim/UI drift")

	var deadline := Time.get_ticks_msec() + 4000
	while not minigame._vortex_active and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(minigame._vortex_active, "grapple_mouse_input: vortex becomes controllable — guards against input starting before a wave exists")
	if not minigame._vortex_active:
		_finish()
		return
	var expected_instruction := "YELLOW" if minigame._vortex_safe_is_yellow else "GREEN"
	_check(minigame.wave_instruction == expected_instruction, "grapple_mouse_input: central prompt names this wave's safe color — guards against log-only or mismatched instructions")
	_check(minigame._wave_callout.visible and minigame._wave_callout.text == "GRAPPLE " + expected_instruction, "grapple_mouse_input: top callout names GRAPPLE plus the safe color - guards against forcing players to scan the battle log")
	var callout_rect := minigame._wave_callout.get_global_rect()
	var stage_rect := minigame.get_global_rect()
	_check(absf(callout_rect.get_center().x - stage_rect.get_center().x) < 1.0 and callout_rect.position.y < stage_rect.position.y + stage_rect.size.y * 0.3, "grapple_mouse_input: instruction sits at the top center of the playable stage")
	await create_timer(1.0).timeout
	_check(minigame._wave_callout.visible and minigame._wave_callout.text == "GRAPPLE " + expected_instruction and minigame._wave_callout.scale == Vector2.ONE, "grapple_mouse_input: callout stays steady (no flashing sequence) for the wave")
	await physics_frame
	_check(minigame.vortex_targets_are_aimable(), "grapple_mouse_input: generated target fits bounded mouse look — guards against off-cone targets")
	var web_safe := _first_target(minigame, true)
	_check(web_safe != null, "grapple_mouse_input: safe target exists for web direct-click ray — guards against empty browser objective")
	if web_safe != null:
		var web_safe_id := web_safe.get_instance_id()
		await _web_point_and_click(minigame, web_safe)
		_check(not _contains_target_id(minigame, web_safe_id), "grapple_mouse_input: rendered web point resolves its safe sphere — guards against stage-to-ray coordinate drift")
		_check(minigame._hits == 1, "grapple_mouse_input: rendered web point increments the safe-hit score — guards against visual-only browser clicks")

	var wrong := _first_target(minigame, false)
	_check(wrong != null, "grapple_mouse_input: wrong-color target exists — guards against invalid wave composition")
	var hits_before_wrong := minigame._hits
	var resolved_before_wrong := minigame._resolved
	if wrong != null:
		var wrong_mesh := wrong.get_child(0) as MeshInstance3D
		var wrong_material := wrong_mesh.material_override as StandardMaterial3D
		var wrong_original_color := wrong_material.albedo_color
		await _aim_and_click(minigame, wrong)
		_check(_contains_target(minigame, wrong), "grapple_mouse_input: wrong-color left click leaves target — guards against color-choice bypass")
		_check(minigame._hits == hits_before_wrong and minigame._resolved == resolved_before_wrong, "grapple_mouse_input: wrong-color left click leaves score unchanged — guards against accidental scoring")
		await create_timer(0.08).timeout
		var flash_color := wrong_material.albedo_color
		_check(flash_color.r > flash_color.g and flash_color.r > flash_color.b, "grapple_mouse_input: wrong-color sphere flashes red — guards against invisible rejection feedback")
		await create_timer(0.24).timeout
		_check(wrong_material.albedo_color.is_equal_approx(wrong_original_color), "grapple_mouse_input: wrong-color sphere restores its original color — guards against permanent red tint")

	var safe_first := _first_target(minigame, true)
	_check(safe_first != null, "grapple_mouse_input: first safe target exists — guards against empty safe set")
	if safe_first != null:
		var safe_first_id := safe_first.get_instance_id()
		await _aim_and_click(minigame, safe_first)
		_check(not _contains_target_id(minigame, safe_first_id), "grapple_mouse_input: real mouse motion and left click acquire generated safe sphere — guards against auto-aim-only input")
		_check(minigame._hits == hits_before_wrong + 1, "grapple_mouse_input: safe click increments score once — guards against click ray misrouting")

	var safe_second := _first_target(minigame, true)
	_check(safe_second != null, "grapple_mouse_input: second safe target remains after first — guards against unintended list mutation")
	if safe_second != null:
		var safe_second_id := safe_second.get_instance_id()
		await _aim_and_click(minigame, safe_second)
		_check(not _contains_target_id(minigame, safe_second_id), "grapple_mouse_input: second safe sphere is clickable via mouse — guards against follow-up aim drift")
		_check(minigame._hits == hits_before_wrong + 2, "grapple_mouse_input: both safe clicks score exactly twice — guards against incomplete mouse resolution")

	minigame.request_abort()
	_finish()

func _first_target(minigame: GrappleInterceptMinigame, safe: bool) -> Area3D:
	for entry in minigame._vortex_spheres:
		if (bool(entry.is_yellow) == minigame._vortex_safe_is_yellow) == safe:
			var target := entry.node as Area3D
			if is_instance_valid(target):
				return target
	return null

func _contains_target(minigame: GrappleInterceptMinigame, target: Area3D) -> bool:
	for entry in minigame._vortex_spheres:
		if entry.node == target:
			return true
	return false

func _contains_target_id(minigame: GrappleInterceptMinigame, target_id: int) -> bool:
	for entry in minigame._vortex_spheres:
		var node := entry.node as Area3D
		if is_instance_valid(node) and node.get_instance_id() == target_id:
			return true
	return false

func _aim_and_click(minigame: GrappleInterceptMinigame, target: Area3D) -> void:
	# Work from the camera's current local frame, then correct yaw and pitch
	# separately. `Input.parse_input_event()` sends those events through Godot's
	# normal input dispatch rather than calling the minigame handler directly.
	# This deliberately uses the same relative deltas a player would generate,
	# never `look_at()` or a test-only hit helper.
	# Yaw is inverted because a positive local X is right of the crosshair,
	# while this camera's positive yaw turns left around world UP.
	var local := minigame.stage_camera.to_local(target.global_position)
	var yaw_delta := -atan2(local.x, -local.z)
	var yaw_motion := InputEventMouseMotion.new()
	yaw_motion.relative = Vector2(-yaw_delta / GrappleInterceptMinigame.LOOK_SENSITIVITY, 0.0)
	Input.parse_input_event(yaw_motion)
	await physics_frame
	local = minigame.stage_camera.to_local(target.global_position)
	var flat_distance := sqrt(local.x * local.x + local.z * local.z)
	var pitch_delta := atan2(local.y, flat_distance)
	var pitch_motion := InputEventMouseMotion.new()
	pitch_motion.relative = Vector2(0.0, -pitch_delta / GrappleInterceptMinigame.LOOK_SENSITIVITY)
	Input.parse_input_event(pitch_motion)
	await physics_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await physics_frame

func _web_point_and_click(minigame: GrappleInterceptMinigame, target: Area3D) -> void:
	# Reconstruct the exact pointer coordinate a browser user sees, then call
	# the production web handler. This is the inverse stage-rect transform in
	# _grapple_at_web_pointer(), and catches a visual target that is not actually
	# raycastable because the SubViewport has been stretched or repositioned.
	var projected := minigame.stage_camera.unproject_position(target.global_position)
	var rect := minigame.stage_rect
	var pointer := rect.position + Vector2(
		projected.x / minigame.stage_root.size.x * rect.size.x,
		projected.y / minigame.stage_root.size.y * rect.size.y
	)
	minigame._grapple_at_web_pointer(pointer)
	await physics_frame

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		push_error("FAIL: %s" % description)
		failures.append(description)

func _finish() -> void:
	if failures.is_empty():
		print("GRAPPLE MOUSE INPUT: clean")
		quit()
	else:
		print("GRAPPLE MOUSE INPUT: failures %s" % str(failures))
		quit(1)
