extends SceneTree
## LAB-BAL-005: earned content must function, not merely appear as learned.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	Engine.time_scale = 8.0
	for sample in [{"move": "Heavy Slam", "eva": 0}, {"move": "Heavy Slam", "eva": 2},
		{"move": "Crushing Haymaker", "eva": 0}, {"move": "Crushing Haymaker", "eva": 2}]:
		var evasion := int(sample.eva)
		var move_name := String(sample.move)
		var diver := Diver.new()
		diver.model_name = "Prototype_V(1922)"
		root.add_child(diver)
		while diver.stats.level < 3:   # Bucky learns Mending Current at 2, Heavy Slam at 3
			diver.stats.gain_xp(10)
			SpellTree.learn_all_available(diver, [])
		var battle := Battle.new()
		battle.party_source = [diver]
		battle.ordinary_enemy_ids = ["angler"]
		root.add_child(battle)
		var deadline := Time.get_ticks_msec() + 15000
		while not battle.main_menu.is_visible_in_tree() or battle.attack_btn.disabled or battle._busy:
			if Time.get_ticks_msec() >= deadline:
				findings.append("LAB-BAL-005 no actual player turn")
				break
			await process_frame
		var enemy := battle.enemies[0].stats as CombatantStats
		# Disclosed exhausted/unprepared target fixtures; no player stats,
		# outcomes, damage or Oxygen are manufactured.
		enemy.evasion_current = evasion
		var hp_before := enemy.hp
		var oxygen_before := (battle._acting.stats as CombatantStats).oxygen
		battle.attack_btn.pressed.emit()
		await process_frame
		var selected: Button
		for value in battle.move_buttons:
			var button := value as Button
			if button.text.get_slice("\n", 0) == move_name:
				selected = button
		if selected == null:
			findings.append("LAB-BAL-005 earned Heavy Slam missing")
		else:
			var pages := 0
			while not selected.is_visible_in_tree() and pages < 6 and not battle._move_down_btn.disabled:
				battle._move_down_btn.pressed.emit()
				await process_frame
				pages += 1
			if not selected.is_visible_in_tree():
				findings.append("LAB-BAL-005 earned Heavy Slam inaccessible")
			else:
				selected.pressed.emit()
				await process_frame
				(battle.target_buttons[0] as Button).pressed.emit()
				# Read at resolution before the ordinary enemy can refill EVA.
				var result_text := "heavy slam" if move_name == "Heavy Slam" else "wind up and crush"
				while not battle._current_log_text().contains(result_text) and Time.get_ticks_msec() < deadline:
					await process_frame
				var damage := hp_before - enemy.hp
				var spent: int = evasion - enemy.evasion_current
				if evasion == 0 and damage <= 0:
					findings.append("LAB-BAL-005 earned Heavy Slam cannot hit exhausted EVA")
				if evasion == 2 and (damage != 0 or spent <= 0):
					findings.append("LAB-BAL-005 unprepared target no longer evades/spends EVA")
				if (battle.party[0].stats as CombatantStats).oxygen >= oxygen_before:
					findings.append("LAB-BAL-005 attack skipped its actual Oxygen cost")
				print("HEAVY PAYOFF|move=%s|eva=%d|damage=%d|spent=%d|oxygen=%.1f" % [move_name, evasion, damage, spent, battle.party[0].stats.oxygen])
		battle.queue_free()
		diver.queue_free()
		await process_frame
		await process_frame
	Engine.time_scale = 1.0
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	quit(0 if findings.is_empty() else 1)
