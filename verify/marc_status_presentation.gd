extends SceneTree
## M99-S4: readable status amounts must not make six real cards overlap/clip.
var findings: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var sources: Array[Diver] = []
	for model in Cast.ALL:
		var diver := Diver.new()
		diver.model_name = model
		root.add_child(diver)
		sources.append(diver)
	var battle := Battle.new()
	battle.party_source = sources
	battle.ordinary_enemy_ids.assign(["angler", "swordfish_duelist", "frilled_shark"])
	root.add_child(battle)
	await process_frame
	# Render fixture, not proof of inflicting four conditions simultaneously.
	# Pause real turns while presenting the supported status dictionary.
	paused = true
	for entry in battle.party + battle.enemies:
		var stats := entry.stats as CombatantStats
		stats.add_status("bleed", 4)
		stats.add_status("poison", 2, 3)
		stats.add_status("blindness", 2, 3)
		battle._refresh_bar(entry)
	for shape in [Vector2i(1280, 720), Vector2i(803, 893), Vector2i(720, 480)]:
		root.size = shape
		for _frame in range(16):
			await process_frame
		var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var panel_top := battle._bottom_panel.get_global_rect().position.y
		var cards: Array[Rect2] = []
		for entry in battle.party + battle.enemies:
			var rect := _visible_bounds(entry.card as Control)
			_expect(bounds.grow(1).encloses(rect) and rect.end.y <= panel_top + 1,
				"M99-S4 status card clipped/covered: %s at %s (%s)" % [entry.display_name, shape, rect])
			for other in cards:
				_expect(not rect.intersects(other), "M99-S4 status cards overlap at " + str(shape))
			cards.append(rect)
		if not capture_dir.is_empty():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_dir.path_join("status-%dx%d.png" % [shape.x, shape.y]))
	paused = false
	battle.queue_free()
	for diver in sources:
		diver.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC STATUS PRESENTATION: clean" if findings.is_empty() else "MARC STATUS PRESENTATION: failed")
	quit(0 if findings.is_empty() else 1)

func _visible_bounds(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	for child in control.find_children("*", "Control", true, false):
		if child.is_visible_in_tree():
			rect = rect.merge(child.get_global_rect())
	return rect

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
