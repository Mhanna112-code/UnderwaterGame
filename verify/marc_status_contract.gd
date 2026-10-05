extends SceneTree
## M99-S1..3: authored Bleed persists, capped, failure-safe; duration is readable.
var findings: Array[String] = []

func _initialize() -> void:
	var stabbing: Dictionary = {}
	for move in CombatMoves.SCUBA:
		if move.name == "Scuba Stabbing":
			stabbing = move
	var attacker := _stats(1, 3, 0)
	var target := _stats(1, 1, 0)
	CombatRules.resolve(attacker, target, stabbing)
	var hp_after_hit := target.hp
	for _turn in range(4):
		target.begin_turn()
		target.end_turn()
	_expect(target.status_level("bleed") == 2 and target.hp == hp_after_hit - 8,
		"M99-S1 authored Stabbing did not deal four persistent 2-damage ticks")
	target.fill()
	_expect(target.status_level("bleed") == 0, "M99-S1 Bleed carried into the next fight after refill")
	if not findings.is_empty():
		_finish()
		return
	for strength in range(13):
		for outcome in ["hit", "miss", "dodge"]:
			attacker = _stats(strength, 3, 0)
			target = _stats(1, 1, 3 if outcome == "miss" else 0)
			CombatRules.resolve(attacker, target, stabbing, true, outcome == "dodge")
			var expected_level := mini(10, strength + 1) if outcome == "hit" else 0
			_expect(target.status_level("bleed") == expected_level,
				"M99-S2 initial bleed cap/failure isolation: STR %d %s" % [strength, outcome])
			if outcome == "hit":
				for _repeat in range(12):
					CombatRules.resolve(attacker, target, stabbing)
				# Only 3 stack increases per fight after the first wound: the next
				# Stabbing's hit (+1) and Bleed (+STR+1), then one more hit (+1).
				_expect(target.status_level("bleed") == mini(10, 2 * strength + 4), "M99-S2 repeated landed Bleed ignores the 3-stack/10 cap")
	# Timed controls: do not accidentally make Poison/Blindness persistent too.
	target = _stats(1, 1, 0)
	target.add_status("poison", 2, 3)
	target.add_status("blindness", 2, 3)
	for _turn in range(3):
		target.end_turn()
	_expect(target.status_level("poison") == 0 and target.status_level("blindness") == 0,
		"M99-S1 unrelated timed statuses no longer expire")
	for status in ["bleed", "poison", "blindness", "stun"]:
		for level in range(1, 11):
			for duration in range(6):
				target.fill()
				target.add_status(status, level, duration)
				var summary := target.status_summary()
				_expect(status.capitalize() in summary, "M99-S3 summary lost status identity")
				if duration > 0:
					_expect(("%d turn" % duration) in summary and "left" in summary,
						"M99-S3 remaining duration has no readable units: " + summary)
				if status != "stun":
					_expect(("%s %d" % [status.capitalize(), level]) in summary,
						"M99-S3 status amount confused with its duration: " + summary)
	# Public resolver result is consumed by the log and floating feedback.
	# A readable card alone does not verify that separate consumer path.
	for duration in range(1, 7):
		for level in range(1, 7):
			attacker = _stats(1, 3, 0)
			target = _stats(1, 1, 0)
			var result := CombatRules.resolve(attacker, target, {
				"formula": {"flat": 1},
				"effects": [{"kind": "status", "status": "poison", "level": level, "duration": duration}],
			})
			var feedback := " ".join(result.effects)
			_expect(("Poison %d" % level) in feedback and ("%d turn" % duration) in feedback and "left" in feedback,
				"M99-S5 timed move feedback disagrees with remaining-turn contract: " + feedback)
	_finish()

func _stats(strength: int, accuracy: int, evasion: int) -> CombatantStats:
	var stats := CombatantStats.new()
	stats.hp_max = 1000
	stats.strength = strength
	stats.defense = 0
	stats.accuracy = accuracy
	stats.evasion = evasion
	stats.fill()
	return stats

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING ", finding)
	print("MARC STATUS CONTRACT: clean" if findings.is_empty() else "MARC STATUS CONTRACT: failed")
	quit(0 if findings.is_empty() else 1)
