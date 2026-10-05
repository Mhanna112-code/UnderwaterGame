# `tutorial status layout: every combatant card remains above the long-caption
# HUD - guards against Bucky stats being covered`.
#
# Run windowed at each release-review shape:
#   godot --path . --resolution 1280x720 --script verify/tutorial_status_layout.gd
#   godot --path . --resolution 803x893 --script verify/tutorial_status_layout.gd
extends SceneTree

const TIMEOUT_MS := 12000
const SETTLE_FRAMES := 12

var findings: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	# This layout gate must never overwrite the player's real save slot 3.
	# Open the real world without New Game/save creation, then start practice.
	world.title_screen.close()
	world.get_node("HUD").visible = true
	paused = false
	await process_frame
	world._first_encounter_started = true
	world._intro_active = false
	world._transitioning_to_encounter = false
	world._start_battle("", false, "angler", world.divers, false, true)

	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while (world.battle == null or not world.battle._tutorial_awaiting_enter) and Time.get_ticks_msec() < deadline:
		await process_frame
	if world.battle == null:
		findings.append("TUTORIAL STATUS LAYOUT START: tutorial Battle was never created")
	else:
		var battle := world.battle as Battle
		var continue_button := battle.find_child("TutorialContinue", true, false) as Button
		if continue_button == null or not continue_button.visible:
			findings.append("TUTORIAL STATUS LAYOUT START: opening caption has no visible Continue action")
		else:
			continue_button.emit_signal("pressed")
			while (not battle._tutorial_awaiting_enter or not battle._tutorial_caption.text.contains("Turn order is shown")) and Time.get_ticks_msec() < deadline:
				await process_frame
			if not battle._tutorial_caption.text.contains("Turn order is shown"):
				findings.append("TUTORIAL STATUS LAYOUT START: real Combat Basics caption never appeared")
			else:
				for _frame in range(SETTLE_FRAMES):
					await process_frame
				_check_visible_cards(battle)
				if battle.log_label.visible:
					findings.append("M99-C1 TURN LOG OVER NARRATION: turn prompt is visible while Continue owns the lesson")
				if not capture_dir.is_empty():
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(capture_dir.path_join("tutorial-caption-%dx%d.png" % [root.size.x, root.size.y]))
				# Real player-visible Continue releases narration and returns to
				# the scripted attack-choice instruction; text wording is not a gate.
				continue_button.pressed.emit()
				for _frame in range(SETTLE_FRAMES):
					await process_frame
				if not battle._tutorial_awaiting_enter and not battle.log_label.visible:
					findings.append("M99-C1 TURN LOG LOST: instruction/action state still hides the turn line")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial status layout   every combatant card remains above the long-caption HUD")
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	quit(0 if findings.is_empty() else 1)

func _check_visible_cards(battle: Battle) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var panel_top := battle._bottom_panel.get_global_rect().position.y
	var card_rects: Array[Rect2] = []
	for entry in battle.party + battle.enemies:
		var card := entry.get("card") as Control
		if card == null or not card.is_visible_in_tree():
			continue
		# PanelContainer can report only the allocation its parent granted it
		# while labels/rows still draw past that allocation. The player sees the
		# descendants, so union every visible Control rather than accepting a
		# deceptively small parent rect (the wide hosted defect exposed exactly
		# that mismatch).
		var rect := _visible_control_bounds(card)
		card_rects.append(rect)
		var name := String(entry.get("display_name", "unknown combatant"))
		if rect.position.y < viewport_rect.position.y - 0.5 or rect.end.y > viewport_rect.end.y + 0.5:
			findings.append("STATUS CARD OUTSIDE VIEWPORT: %s rect %s in %s" % [name, str(rect), str(viewport_rect)])
		if rect.end.y > panel_top + 0.5:
			findings.append("STATUS CARD COVERED BY CAPTION HUD: %s ends at y=%.1f but panel starts at y=%.1f" % [name, rect.end.y, panel_top])
	for left_index in range(card_rects.size()):
		for right_index in range(left_index + 1, card_rects.size()):
			if card_rects[left_index].intersects(card_rects[right_index], true):
				findings.append("STATUS CARDS OVERLAP: %s and %s" % [str(card_rects[left_index]), str(card_rects[right_index])])

func _visible_control_bounds(root_control: Control) -> Rect2:
	var bounds := root_control.get_global_rect()
	var pending: Array[Node] = [root_control]
	while not pending.is_empty():
		var current := pending.pop_back() as Node
		for child in current.get_children():
			if child is Control and (child as Control).is_visible_in_tree():
				bounds = bounds.merge((child as Control).get_global_rect())
			pending.append(child)
	return bounds
