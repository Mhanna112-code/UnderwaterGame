extends SceneTree
## M99-01/02: actual reward identity, first playable turn and responsive layout.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(99001)
	for reward in ["current_pearl", ""]:
		var battle := Battle.new()
		battle.guardian_encounter = true
		battle.guardian_enemy_id = "bomb_bot" if reward.is_empty() else "angler"
		battle.encounter_source = "lab_blocker" if reward.is_empty() else "item_site"
		battle.reward_item_on_win = reward
		root.add_child(battle)
		for _frame in range(12):
			await process_frame
		var log_text := battle.log_label.get_parsed_text()
		_expect(("carrying an item" in log_text) == not reward.is_empty(),
			"M99-01 actual item reward must determine the visible carrier message: " + log_text)
		if not reward.is_empty():
			_expect("turn" in log_text, "M99-01 item message hides the first playable turn")
			_expect(battle.main_menu.visible and not battle.attack_btn.disabled,
				"M99-01 carrier message blocks real player controls")
			_expect(battle.log_label.get_global_rect().size.y >= battle.log_label.get_content_height(),
				"M99-02 two-line combat message has no allocated space")
			_expect(battle.log_label.get_global_rect().end.y <= battle.main_menu.get_global_rect().position.y + 1.0,
				"M99-02 message overlaps action buttons")
		battle.queue_free()
		await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC REWARD LAYOUT: clean" if findings.is_empty() else "MARC REWARD LAYOUT: failed")
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
