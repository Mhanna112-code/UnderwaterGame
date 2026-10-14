extends SceneTree

# QT1/QT9: the starter must finish after one real move and one live dodge,
# not quietly continue through the five-move lecture. No injected win/HP.
var failures: Array[String] = []
var moves := 0
var qtes := 0
var captions := 0
var results: Array[String] = []
var _captured := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--narrow"):
		root.size = Vector2i(360, 640)
	elif OS.get_cmdline_user_args().has("--short-window"):
		root.size = Vector2i(720, 480)
	var sources: Array[Diver] = []
	for model_name in Cast.model_names():
		var diver := Diver.new()
		diver.model_name = String(model_name)
		root.add_child(diver)
		sources.append(diver)
	var fight := Battle.new()
	fight.party_source = sources
	fight.tutorial_encounter = true
	root.add_child(fight)
	fight.finished.connect(func(result: String) -> void: results.append(result))
	fight.player_swing_staged.connect(func(_a: Node3D, _t: Node3D) -> void: moves += 1)
	var was_qte := false
	var prior_caption := ""
	var deadline := Time.get_ticks_msec() + 65000
	while results.is_empty() and failures.is_empty() and Time.get_ticks_msec() < deadline:
		if fight._qte_active:
			await _capture(fight, "dodge")
			if not was_qte:
				qtes += 1
			was_qte = true
			# Timeout variant intentionally supplies no X input.
			if not OS.get_cmdline_user_args().has("--miss-dodge"):
				var center := fight.qte_indicator.position.x + fight.qte_indicator.size.x * 0.5
				if center >= fight.qte_zone.position.x and center <= fight.qte_zone.position.x + fight.qte_zone.size.x:
					var press := InputEventKey.new()
					press.keycode = KEY_X
					press.pressed = true
					Input.parse_input_event(press)
		else:
			was_qte = false
		if fight._tutorial_awaiting_enter:
			var text := fight._tutorial_caption.get_parsed_text()
			await _capture(fight, "finish" if text.begins_with("Practice complete") else "instruction")
			if text != prior_caption:
				captions += 1
				print("STARTER_CAPTION|", text)
				prior_caption = text
				if text.split(" ", false).size() > 60:
					failures.append("QT1: starter still blocks play with a long lecture caption")
			if fight._tutorial_continue_btn.is_visible_in_tree():
				fight._tutorial_continue_btn.emit_signal("pressed")
			else:
				var enter := InputEventKey.new()
				enter.pressed = true
				enter.keycode = KEY_ENTER
				Input.parse_input_event(enter)
		elif fight.target_menu.visible and not fight.target_buttons.is_empty():
			await _capture(fight, "target")
			var target := fight.target_buttons[0] as Button
			if target.disabled or target.button_mask == 0:
				target.emit_signal("mouse_entered")
			else:
				target.emit_signal("pressed")
		elif not fight._busy and fight.move_menu.visible:
			await _capture(fight, "move")
			for choice in fight.move_buttons:
				if (choice as Button).is_visible_in_tree() and not choice.disabled:
					(choice as Button).emit_signal("pressed")
					break
		elif not fight._busy and fight.main_menu.visible and not fight.attack_btn.disabled:
			fight.attack_btn.emit_signal("pressed")
		if moves > 1:
			failures.append("QT1: starter requires more than one attack before returning to play")
		await create_timer(0.03).timeout
	if failures.is_empty():
		if results != ["won"] or moves != 1 or qtes != 1:
			failures.append("QT9: starter did not finish one real move and dodge: results=%s moves=%d qtes=%d" % [str(results), moves, qtes])
		if captions > 3:
			failures.append("QT1: starter requires too many narration confirmations: %d" % captions)
	for failure in failures:
		push_error(failure)
	print("QUICK COMBAT LESSON|moves=%d|qtes=%d|captions=%d|results=%s|failures=%d" % [moves, qtes, captions, str(results), failures.size()])
	fight.queue_free()
	for diver in sources:
		diver.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	quit(0 if failures.is_empty() else 1)

func _capture(fight: Battle, beat: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or _captured.has(beat):
		return
	_captured[beat] = true
	if DisplayServer.get_name() == "headless":
		failures.append("QT VISUAL: captures need a real renderer")
		return
	await RenderingServer.frame_post_draw
	var viewport := root.get_visible_rect()
	print("STARTER_LAYOUT|", beat, "|viewport=", viewport.size, "|stage_height=", fight._stage_container.size.y)
	if fight._stage_container.size.y < 80:
		failures.append("QT VISUAL: %s collapses the visible battle stage" % beat)
	if not viewport.encloses(fight.skip_tutorial_btn.get_global_rect()):
		failures.append("QT VISUAL: %s clips Skip Tutorial" % beat)
	var image := root.get_texture().get_image()
	var label := "narrow" if OS.get_cmdline_user_args().has("--narrow") else ("short" if OS.get_cmdline_user_args().has("--short-window") else "wide")
	image.save_png("res://docs/evidence/quick-tutorial-oct14/starter-%s-%s.png" % [label, beat])
