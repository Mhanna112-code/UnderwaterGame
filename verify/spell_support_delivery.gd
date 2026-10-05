extends SceneTree
## SPELL-ANIM-04: delivered support clips must heal/revive via the real UI,
## face an ally without moving into its row, and leave the next turn usable.
var findings: Array[String] = []
var staged := false
var animation_seen := ""
var caster_start := Vector3.ZERO
var case_name := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 1.0 if "--capture-support" in OS.get_cmdline_user_args() else 8.0
	for move_name in ["Mending Current", "Tidal Revival"]:
		case_name = move_name
		staged = false
		animation_seen = ""
		var caster := Diver.new()
		caster.model_name = "Prototype_V(1922)"
		var recipient := Diver.new()
		root.add_child(caster)
		root.add_child(recipient)
		var companion: Diver
		if "--three-party" in OS.get_cmdline_user_args():
			companion = Diver.new()
			companion.model_name = "Prototype_1(1910)"
			root.add_child(companion)
		# Explicit learned-kit/injured-party fixtures, not an earned-run claim.
		caster.stats.spell_points = 20
		SpellTree.learn_all_available(caster, ["reef_plate", "sunken_core"])
		recipient.stats.hp = 0 if move_name == "Tidal Revival" else 1
		var battle := Battle.new()
		battle.party_source = [caster, recipient]
		if companion != null:
			battle.party_source.append(companion)
		battle.ordinary_enemy_ids = ["frilled_shark"]
		battle.player_swing_staged.connect(func(actor: Node3D, target: Node3D) -> void:
			if actor is Diver and (actor as Diver).model_name == "Prototype_V(1922)":
				staged = true
				animation_seen = String((actor as Diver).anim.current_animation)
				if actor.position.distance_to(caster_start) > 0.05:
					findings.append("SPELL-ANIM-04 support caster moved into the ally row")
				if "--capture-support" in OS.get_cmdline_user_args():
					_capture_cast(actor as Diver, move_name)
		)
		root.add_child(battle)
		var deadline := Time.get_ticks_msec() + (40000 if "--capture-support" in OS.get_cmdline_user_args() else 18000)
		# Let Maxilani take her actual earlier turn in the heal case.
		while Time.get_ticks_msec() < deadline:
			await process_frame
			if not battle.main_menu.is_visible_in_tree() or battle.attack_btn.disabled or battle._busy:
				continue
			if String(battle._acting.model_name) == "Prototype_V(1922)":
				break
			battle.attack_btn.pressed.emit()
			await process_frame
			for button in battle.move_buttons:
				if String(button.text).get_slice("\n", 0) in ["Electric Touch", "Precise Tap"]:
					button.pressed.emit()
					break
			await process_frame
			if battle.target_buttons.is_empty():
				findings.append("SPELL-ANIM-04 companion move did not expose a real target")
				break
			(battle.target_buttons[0] as Button).pressed.emit()
		if Time.get_ticks_msec() >= deadline:
			findings.append("SPELL-ANIM-04 support turn never became usable")
		else:
			var recipient_entry: Dictionary = battle.party[1]
			var hp_before := int(recipient_entry.stats.hp)
			var oxygen_before := float(battle.party[0].stats.oxygen)
			caster_start = (battle.party[0].actor as Node3D).position
			battle.attack_btn.pressed.emit()
			await process_frame
			var selected: Button
			for button in battle.move_buttons:
				if String(button.text).get_slice("\n", 0) == move_name:
					selected = button
			while selected != null and not selected.is_visible_in_tree() and not battle._move_down_btn.disabled:
				battle._move_down_btn.pressed.emit()
				await process_frame
			if selected == null or not selected.is_visible_in_tree():
				findings.append("SPELL-ANIM-04 learned support spell is inaccessible")
			else:
				selected.pressed.emit()
				await process_frame
				for button in battle.target_buttons:
					if String(button.text).contains("Maxilani"):
						button.pressed.emit()
						break
				while int(recipient_entry.stats.hp) <= hp_before and Time.get_ticks_msec() < deadline:
					await process_frame
				if int(recipient_entry.stats.hp) <= hp_before:
					findings.append("SPELL-ANIM-04 actual heal/revive never resolved")
				if not staged or animation_seen != (battle.party[0].actor as Diver).resolve(Cast.ability(caster.model_name, move_name)):
					findings.append("SPELL-ANIM-04 actual battle did not play the delivered support clip")
				if float(battle.party[0].stats.oxygen) >= oxygen_before:
					findings.append("SPELL-ANIM-04 support cast bypassed Oxygen cost")
				var runtime_caster := battle.party[0].actor as Diver
				while not String(runtime_caster.anim.current_animation).contains("(Idle)") and Time.get_ticks_msec() < deadline:
					await process_frame
				if Time.get_ticks_msec() >= deadline:
					findings.append("SPELL-ANIM-04 support caster never returned to idle")
				while (battle._busy or not battle.main_menu.is_visible_in_tree() or battle.attack_btn.disabled) and Time.get_ticks_msec() < deadline:
					await process_frame
				if Time.get_ticks_msec() >= deadline:
					findings.append("SPELL-ANIM-04 next turn never became usable")
				print("SUPPORT DELIVERY|%s|%s|HP=%d>%d|O2=%.1f>%.1f" % [move_name, animation_seen, hp_before, recipient_entry.stats.hp, oxygen_before, battle.party[0].stats.oxygen])
		battle.queue_free()
		caster.queue_free()
		recipient.queue_free()
		if companion != null:
			companion.queue_free()
		await process_frame
		await process_frame
	Engine.time_scale = 1.0
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("SPELL SUPPORT DELIVERY: ", "clean" if findings.is_empty() else "failed")
	quit(0 if findings.is_empty() else 1)

func _capture_cast(actor: Diver, move_name: String) -> void:
	var length := actor.anim.get_animation(actor.anim.current_animation).length
	await create_timer(length * 0.35).timeout
	await RenderingServer.frame_post_draw
	# Obtain the scene owner through the tree rather than assume viewport
	# helper nesting, which changes when the presentation is refactored.
	var owner_node: Node = actor
	while owner_node != null and not owner_node is Battle:
		owner_node = owner_node.get_parent()
	var battle := owner_node as Battle
	if battle != null:
		if root.size.y <= 500 and battle._turn_cursor.visible:
			findings.append("SPELL-ANIM-04 cast retains a clipped selection cursor above its information band")
		var stage := battle._stage_container.get_global_rect()
		if stage.size.y < 180.0:
			findings.append("SPELL-ANIM-04 hidden target menu still reserves space; cast stage only %.0fpx high" % stage.size.y)
		var rectangle := _skin_rect(actor, battle)
		for entry in battle.party:
			if (entry.card as Control).is_visible_in_tree():
				var overlap := rectangle.intersection((entry.card as Control).get_global_rect())
				if overlap.get_area() > rectangle.get_area() * 0.12:
					findings.append("SPELL-ANIM-04 support animation is covered by a party status card")
	DirAccess.make_dir_recursive_absolute("/tmp/spell-delivery-native")
	root.get_texture().get_image().save_png("/tmp/spell-delivery-native/battle-%s-%d-party-%dx%d.png" % [move_name.to_snake_case(), battle.party.size(), root.size.x, root.size.y])

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
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		meshes.append_array(_meshes(child))
	return meshes
