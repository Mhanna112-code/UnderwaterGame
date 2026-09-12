# Regression: the first deliberate Angler fight is the one place the combat
# tutorial runs. It must stay a real one-enemy battle, show a non-modal hint,
# keep Run unavailable, and guarantee a QTE only after the player has tried
# Electric Touch. This catches the integration failure where a world-opening
# tutorial and a combat-opening tutorial became two unrelated first runs.
#
# Usage: godot --headless --path . --script verify/combat_tutorial.gd
extends SceneTree

var findings: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var battle := Battle.new()
	battle.tutorial_encounter = true
	battle.boss_intro_enabled = false
	root.add_child(battle)
	for _frame in range(6):
		await process_frame

	if battle.enemies.size() != 1:
		findings.append("CT-01: tutorial battle did not build exactly one Angler")
	if battle.tutorial_hint == null:
		findings.append("CT-02: tutorial battle has no persistent hint card")
	# Start a known Staff_Diver turn directly. This checks the teaching layer
	# without depending on a random turn-order roll.
	var staff := battle.party[0] as Dictionary
	battle._start_party_turn(staff)
	if battle.tutorial_hint == null or not battle.tutorial_hint.visible or not battle.tutorial_hint.text.contains("Electric Touch"):
		findings.append("CT-03: first combat turn does not explain the Electric Touch opener")
	if battle.run_btn == null or not battle.run_btn.disabled:
		findings.append("CT-04: first combat can be fled, bypassing its only combat lesson")

	# The QTE gate must be deterministic after the opener rather than relying
	# on the usual 25% random chance. A high-accuracy harmless move reaches the
	# QTE path. Letting its short timing window expire is enough to prove the
	# prompt was actually offered; this test is about dispatch, not reflexes.
	battle._tutorial_move_seen = true
	battle._tutorial_force_next_qte = true
	var attacker := CombatantStats.new()
	attacker.accuracy = 20
	attacker.strength = 0
	var defender := CombatantStats.new()
	defender.evasion = 0
	defender.evasion_current = 0
	await battle._resolve_attack(attacker, defender, {"power": 0, "acc_mod": 0, "quick_time_bool": true})
	if not battle._tutorial_qte_seen:
		findings.append("CT-05: first post-opener enemy attack did not show the guaranteed QTE")

	for finding in findings:
		print("FINDING  " + finding)
	print("COMBAT TUTORIAL: clean" if findings.is_empty() else "COMBAT TUTORIAL: %d finding(s)" % findings.size())
	battle.queue_free()
	quit(0 if findings.is_empty() else 1)
