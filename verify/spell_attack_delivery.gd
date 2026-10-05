extends SceneTree
## SPELL-ANIM-05: a delivered attack must not vanish behind an idle teammate.
var findings: Array[String] = []
var capture_done := false
var case_name := "Swift Strike"
var phase := 0.65
const CASES := {
	"Swift Strike": "Staff_Diver", "Riptide Slash": "Staff_Diver",
	"Blinding Silt": "Prototype_1(1910)", "Exploit Opening": "Prototype_1(1910)",
	"Precise Jab": "Prototype_1(1910)", "Guard Break": "Prototype_V(1922)",
	"Heavy Slam": "Prototype_V(1922)",
}
class OldApproachBattle extends Battle:
	func _step_toward(entry: Dictionary, target: Dictionary, face_only: bool = false, _camera_flank: bool = false) -> void:
		await super._step_toward(entry, target, face_only, false)
	func _frame_stage_camera() -> void:
		for entry in party:
			if is_instance_valid(entry.get("actor")) and entry.actor is Diver and not (entry.actor as Diver).framing_clip.is_empty():
				return # Original camera retained its pre-cast idle framing.
		super._frame_stage_camera()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var only := ""
	var checked := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--move="):
			only = argument.trim_prefix("--move=")
		if argument.begins_with("--phase="):
			phase = float(argument.trim_prefix("--phase="))
	for move_name in CASES:
		if only.is_empty() or only == move_name:
			checked += 1
			case_name = move_name
			capture_done = false
			await _case()
			if not findings.is_empty():
				break
	if checked == 0 or phase <= 0.0 or phase >= 1.0:
		findings.append("SPELL-ANIM-05 invalid review case/phase; no valid inspection")
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("SPELL ATTACK DELIVERY: ", "clean" if findings.is_empty() else "failed")
	quit(0 if findings.is_empty() else 1)

func _case() -> void:
	var sources: Array[Diver] = []
	for model in ["Staff_Diver", "Prototype_1(1910)", "Prototype_V(1922)"]:
		var source := Diver.new()
		source.model_name = model
		root.add_child(source)
		sources.append(source)
	for source in sources:
		if source.model_name == CASES[case_name]:
			source.stats.spell_points = 30
			SpellTree.learn_all_available(source, ["abyssal_lens", "current_pearl", "sunken_core", "reef_plate"])
	# Explicit fault injection: reproduce the original occluding approach
	# without altering production code or accepting the resulting failure.
	var battle := OldApproachBattle.new() if "--old-approach-control" in OS.get_cmdline_user_args() else Battle.new()
	battle.party_source = sources
	battle.ordinary_enemy_ids = ["frilled_shark"]
	battle.player_swing_staged.connect(func(actor: Node3D, target: Node3D) -> void:
		if (actor as Diver).model_name == CASES[case_name]:
			print("SPELL STAGED|", case_name, "|", (actor as Diver).anim.current_animation)
			_capture(actor as Diver, battle)
	)
	root.add_child(battle)
	var deadline := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if battle._busy or not battle.main_menu.is_visible_in_tree() or battle.attack_btn.disabled:
			continue
		if String(battle._acting.model_name) == CASES[case_name]:
			break
		battle.attack_btn.pressed.emit()
		await process_frame
		for button in battle.move_buttons:
			if String(button.text).get_slice("\n", 0) in ["Electric Touch", "Precise Tap"]:
				button.pressed.emit()
				break
		await process_frame
		if battle.target_buttons.is_empty():
			findings.append("SPELL-ANIM-05 companion attack has no target: " + case_name)
			break
		(battle.target_buttons[0] as Button).pressed.emit()
	battle.attack_btn.pressed.emit()
	await process_frame
	var selected: Button
	for button in battle.move_buttons:
		if String(button.text).get_slice("\n", 0) == case_name:
			selected = button
	while selected != null and not selected.is_visible_in_tree() and not battle._move_down_btn.disabled:
		battle._move_down_btn.pressed.emit()
		await process_frame
	if selected == null or not selected.is_visible_in_tree():
		findings.append("SPELL-ANIM-05 learned attack inaccessible")
	else:
		selected.pressed.emit()
		await process_frame
		if battle.target_buttons.is_empty():
			findings.append("SPELL-ANIM-05 no real enemy target")
		else:
			(battle.target_buttons[0] as Button).pressed.emit()
			while not capture_done and Time.get_ticks_msec() < deadline:
				await process_frame
			if not capture_done:
				findings.append("SPELL-ANIM-05 actual cast was never inspected: %s, busy=%s, turn=%s" % [case_name, battle._busy, battle._acting.get("model_name", "none")])
	var runtime_caster: Diver
	for entry in battle.party:
		if entry.model_name == CASES[case_name]:
			runtime_caster = entry.actor as Diver
	# A winning battle deliberately stays busy while reporting its result;
	# cast completion is the actor's released camera ownership, not _busy.
	while runtime_caster != null and not runtime_caster.framing_clip.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if Time.get_ticks_msec() >= deadline:
		findings.append("SPELL-ANIM-05 cast/return failed to finish: " + case_name)
	for entry in battle.party:
		if entry.model_name == CASES[case_name] and not (entry.actor as Diver).framing_clip.is_empty():
			findings.append("SPELL-ANIM-05 attack camera never releases: " + case_name)
	battle.queue_free()
	for source in sources:
		source.queue_free()
	await process_frame

func _capture(actor: Diver, battle: Battle) -> void:
	var duration := actor.anim.get_animation(actor.anim.current_animation).length
	DirAccess.make_dir_recursive_absolute("/tmp/spell-delivery-native")
	# One fresh public-menu fight per phase. Measuring skinned vertices is
	# deliberately independent but expensive; three captures in one cast
	# let the first measurement make a later screenshot miss the gesture.
	for fraction in [phase]:
		await create_timer(maxf(0.01, duration * fraction - actor.anim.current_animation_position)).timeout
		await RenderingServer.frame_post_draw
		if not String(actor.anim.current_animation).begins_with("spells/"):
			findings.append("SPELL-ANIM-05 requested phase missed the actual cast: " + case_name)
		var captured_image := root.get_texture().get_image()
		if battle._turn_cursor.visible:
			findings.append("SPELL-ANIM-05 cast leaves an origin-anchored cursor clipping the turn bar")
		var time_scale := Engine.time_scale
		Engine.time_scale = 0.0
		var actor_rect := _skin_rect(actor, battle)
		var stage := battle._stage_container.get_global_rect()
		var visible_fraction := actor_rect.intersection(stage).get_area() / maxf(1.0, actor_rect.get_area())
		print("SPELL CAST FRAME|%.2f|visible=%.2f" % [fraction, visible_fraction])
		if visible_fraction < 0.95:
			findings.append("SPELL-ANIM-05 camera-facing attack leaves the visible stage")
		for entry in battle.party:
			if entry.actor == actor:
				continue
			var other_rect := _skin_rect(entry.actor as Diver, battle)
			var overlap := actor_rect.intersection(other_rect).get_area()
			var smaller := minf(actor_rect.get_area(), other_rect.get_area())
			print("SPELL SILHOUETTE|%s|%s|%.2f|overlap=%.2f" % [case_name, entry.display_name, fraction, overlap / maxf(1.0, smaller)])
			if overlap > smaller * 0.25:
				# A telescoping/doubled-over pose has large empty areas inside
				# its bounding rectangle. Rect overlap is a broad phase, not
				# proof that another diver covers the actual moving skin.
				var occlusion := await _rendered_occlusion(actor, battle)
				print("SPELL PIXEL OCCLUSION|%s|%.2f|%.3f" % [case_name, fraction, occlusion])
				if occlusion > 0.25:
					findings.append("SPELL-ANIM-05 moving attack skin is hidden by idle party")
				break
		var suffix := "-old-control" if "--old-approach-control" in OS.get_cmdline_user_args() else ""
		captured_image.save_png("/tmp/spell-delivery-native/full-party-%s-%d-%dx%d%s.png" % [case_name.to_snake_case(), int(fraction * 100), root.size.x, root.size.y, suffix])
		Engine.time_scale = time_scale
	capture_done = true

func _rendered_occlusion(actor: Diver, battle: Battle) -> float:
	# Freeze the already-observed live pose only for the independent depth
	# measurement. This does not inject a pose or make any combat decision.
	var changed: Array[Dictionary] = []
	var other_meshes: Array[MeshInstance3D] = []
	for entry in battle.party:
		for mesh in _meshes(entry.actor):
			if not mesh.is_visible_in_tree():
				continue
			changed.append({"mesh": mesh, "material": mesh.material_override})
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color.RED if entry.actor == actor else Color.BLACK
			mesh.material_override = material
			if entry.actor != actor:
				other_meshes.append(mesh)
	await process_frame
	await RenderingServer.frame_post_draw
	var with_party := _red_pixels(battle._stage_vp.get_texture().get_image())
	for mesh in other_meshes:
		mesh.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var alone := _red_pixels(battle._stage_vp.get_texture().get_image())
	for mesh in other_meshes:
		mesh.visible = true
	for record in changed:
		record.mesh.material_override = record.material
	await process_frame
	await RenderingServer.frame_post_draw
	if alone < 20:
		findings.append("SPELL-ANIM-05 rendered depth mask contains no readable caster")
	return 1.0 - float(with_party) / maxf(1.0, float(alone))

func _red_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.r > 0.8 and color.g < 0.2 and color.b < 0.2:
				count += 1
	return count

func _skin_rect(actor: Diver, battle: Battle) -> Rect2:
	var stage := battle._stage_container.get_global_rect()
	var viewport_size := Vector2(battle._stage_vp.size)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for mesh in _meshes(actor):
		if not mesh.is_visible_in_tree() or mesh.skin == null:
			continue
		var skeleton := mesh.get_node(mesh.skeleton) as Skeleton3D
		skeleton.force_update_all_bone_transforms()
		var bindings: Array[Transform3D] = []
		for index in range(mesh.skin.get_bind_count()):
			var bone := mesh.skin.get_bind_bone(index)
			if bone < 0:
				bone = skeleton.find_bone(mesh.skin.get_bind_name(index))
			bindings.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index))
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences := bones.size() / vertices.size()
			for index in range(0, vertices.size(), 3):
				var point := Vector3.ZERO
				for influence in range(influences):
					var offset := index * influences + influence
					point += (bindings[bones[offset]] * vertices[index]) * weights[offset]
				var projected := stage.position + battle._stage_cam.unproject_position(skeleton.global_transform * point) * stage.size / viewport_size
				low = low.min(projected)
				high = high.max(projected)
	return Rect2(low, high - low)

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_meshes(child))
	return result
