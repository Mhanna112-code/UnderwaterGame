extends SceneTree

# QT4/QT7: no battle stat-help entry and broken modal ownership.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)

func _run() -> void:
	var sources: Array[Diver] = []
	for model_name in Cast.model_names():
		var diver := Diver.new()
		diver.model_name = String(model_name)
		root.add_child(diver)
		sources.append(diver)
	var fight := Battle.new()
	fight.party_source = sources
	fight.guardian_encounter = true
	root.add_child(fight)
	await process_frame
	await process_frame
	var deadline := Time.get_ticks_msec() + 20000
	while (fight._busy or not fight.main_menu.visible) and Time.get_ticks_msec() < deadline:
		await process_frame
	var help := fight.find_child("CombatHelpButton", true, false) as Button
	_expect(help != null, "QT4: live battle action menu has no Combat Help entry")
	if help != null:
		await _reference_contract(fight, help)
	fight.queue_free()
	for diver in sources:
		diver.queue_free()
	await process_frame
	var inventory := InventoryMenu.new()
	root.add_child(inventory)
	inventory.open()
	inventory._help_tab.emit_signal("pressed")
	await process_frame
	var inventory_text := ""
	for node in inventory.find_children("*", "Label", true, false):
		inventory_text += (node as Label).text + "\n"
	for stat in ["HP", "O2", "Strength", "Defense", "Agility", "Accuracy", "Evasion"]:
		_expect(inventory_text.contains(stat), "QT4: Inventory Combat Help omits %s" % stat)
	inventory.close()
	inventory.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	for failure in failures:
		push_error(failure)
	print("QUICK TUTORIAL REFERENCE: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _reference_contract(fight: Battle, help: Button) -> void:
	var before := []
	for entry in fight.party:
		before.append([entry.stats.hp, entry.stats.oxygen, entry.stats.evasion_current])
	var actor = fight._acting
	var queue = fight._queue.duplicate()
	for viewport in [Vector2i(1280, 720), Vector2i(720, 480), Vector2i(360, 640)]:
		root.size = viewport
		for prior_pause in [false, true]:
			paused = prior_pause
			help.emit_signal("pressed")
			await process_frame
			await process_frame
			var reference := fight.find_child("CombatReference", true, false) as Control
			_expect(reference != null and reference.is_visible_in_tree(), "QT4: Help action did not open visible definitions")
			if reference == null:
				continue
			_expect(paused, "QT7: reading combat reference does not pause combat")
			var close := reference.find_child("CloseReference", true, false) as Button
			if close != null and not root.get_visible_rect().encloses(close.get_global_rect()):
				print("REFERENCE_CLIP|viewport=", root.get_visible_rect(), "|close=", close.get_global_rect(), "|panel=", reference.get("_panel").get_global_rect())
			_expect(close != null and root.get_visible_rect().encloses(close.get_global_rect()), "QT7: Close is outside the viewport")
			var text := ""
			for node in reference.find_children("*", "Label", true, false):
				text += (node as Label).text + "\n"
			for stat in ["HP", "O2", "Strength", "Defense", "Agility", "Accuracy", "Evasion"]:
				_expect(text.contains(stat), "QT4: reference omits %s" % stat)
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			Input.parse_input_event(escape)
			await process_frame
			_expect(not reference.visible, "QT7: Escape does not close combat reference")
			_expect(paused == prior_pause, "QT7: reference overwrote parent pause ownership")
			_expect(fight._acting == actor and fight._queue == queue, "QT7: reading Help advanced the fight")
			for index in fight.party.size():
				var stats: CombatantStats = fight.party[index].stats
				_expect([stats.hp, stats.oxygen, stats.evasion_current] == before[index], "QT7: reading Help changed party resources")
	paused = false
