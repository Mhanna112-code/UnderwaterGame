# Actual menu-selected attacks on the production battle stage. Learned-kit
# fixtures speed review; this does not demonstrate earning these spells.
extends SceneTree
var captured := false
var cast_name := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/spell-delivery-native")
	for sample in [["Staff_Diver", "Riptide Slash"], ["Prototype_1(1910)", "Precise Jab"], ["Prototype_V(1922)", "Heavy Slam"]]:
		cast_name = sample[1]
		captured = false
		var source := Diver.new()
		source.model_name = sample[0]
		root.add_child(source)
		source.stats.spell_points = 30
		SpellTree.learn_all_available(source, ["abyssal_lens", "current_pearl", "sunken_core", "reef_plate"])
		var battle := Battle.new()
		battle.party_source = [source]
		battle.ordinary_enemy_ids = ["bomb_bot"]
		battle.player_swing_staged.connect(func(actor: Node3D, target: Node3D) -> void: _capture(actor as Diver))
		root.add_child(battle)
		var deadline := Time.get_ticks_msec() + 22000
		while (not battle.main_menu.is_visible_in_tree() or battle.attack_btn.disabled or battle._busy) and Time.get_ticks_msec() < deadline:
			await process_frame
		battle.attack_btn.pressed.emit()
		await process_frame
		var selected: Button
		for button in battle.move_buttons:
			if String(button.text).get_slice("\n", 0) == cast_name:
				selected = button
		while selected != null and not selected.is_visible_in_tree() and not battle._move_down_btn.disabled:
			battle._move_down_btn.pressed.emit()
			await process_frame
		if selected == null:
			push_error("Review fixture failed to learn " + cast_name)
			quit(1)
			return
		selected.pressed.emit()
		await process_frame
		(battle.target_buttons[0] as Button).pressed.emit()
		while not captured and Time.get_ticks_msec() < deadline:
			await process_frame
		if not captured:
			push_error("Actual cast was not captured: " + cast_name)
			quit(1)
			return
		# Let the real cast/queued return finish before discarding its scene.
		await create_timer(5.0).timeout
		battle.queue_free()
		source.queue_free()
		await process_frame
		await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	quit()

func _capture(actor: Diver) -> void:
	var name := cast_name
	var length := actor.anim.get_animation(actor.anim.current_animation).length
	await create_timer(length * 0.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/spell-delivery-native/battle-%s-%dx%d.png" % [name.to_snake_case(), root.size.x, root.size.y])
	print("ACTUAL CAST CAPTURE|", name, "|", actor.anim.current_animation)
	captured = true
