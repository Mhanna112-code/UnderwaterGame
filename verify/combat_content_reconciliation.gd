# Focused executable contract for Slice 5. Run with:
#   godot --headless --path . --script verify/combat_content_reconciliation.gd
#
# These are intentionally direct, small contracts. The full fight/route gates
# cover integration; this script makes actor lifetime and calculation order
# deterministic enough to catch the intermittent freed-instance error.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _stats(hp: int = 10, strength: int = 1, defense: int = 0, agility: int = 2, evasion: int = 0, accuracy: int = 3) -> CombatantStats:
	var stats := CombatantStats.new()
	stats.hp_max = hp
	stats.strength = strength
	stats.defense = defense
	stats.agility = agility
	stats.evasion = evasion
	stats.accuracy = accuracy
	stats.fill()
	return stats

func _test_self_cost_is_next_turn_cost() -> void:
	var attacker := _stats(10, 1, 0, 2, 3, 3)
	var defender := _stats(10, 1, 0, 2, 0, 0)
	var move := {
		"formula": {},
		"effects": [
			{"kind": "status", "status": "blindness", "level": {"flat": 2}, "duration": {"accuracy": 1}},
			{"kind": "self_temporary", "accuracy": -1, "evasion": -1},
		],
	}
	var result := CombatRules.resolve(attacker, defender, move)
	_expect(bool(result.hit), "SELF-COST SETUP: the zero-evasion target should be hit")
	_expect(defender.status_turns("blindness") == 3,
		"SELF-COST TIMING: 3 Accuracy should create 3 turns before its -1 ACC cost, got %d" % defender.status_turns("blindness"))
	_expect(attacker.effective_accuracy() == 2 and attacker.effective_evasion() == 2,
		"SELF-COST MISSING: the -1 ACC/EVA cost must apply after this move resolves")

func _test_self_cost_is_paid_on_a_miss_or_qte_dodge() -> void:
	var move := {"formula": {}, "effects": [{"kind": "self_temporary", "accuracy": -1, "evasion": -1}]}
	var miss_attacker := _stats(10, 1, 0, 2, 3, 3)
	var evading_target := _stats(10, 1, 0, 2, 3, 0)
	var miss := CombatRules.resolve(miss_attacker, evading_target, move)
	_expect(not bool(miss.hit) and miss_attacker.effective_accuracy() == 2 and miss_attacker.effective_evasion() == 2,
		"SELF-COST MISS: a selected move still pays its next-turn cost when the target evades")

	var dodge_attacker := _stats(10, 1, 0, 2, 3, 3)
	var open_target := _stats(10, 1, 0, 2, 0, 0)
	var dodged := CombatRules.resolve(dodge_attacker, open_target, move, true, true)
	_expect(bool(dodged.dodged) and dodge_attacker.effective_accuracy() == 2 and dodge_attacker.effective_evasion() == 2,
		"SELF-COST DODGE: a QTE-dodged move still pays its next-turn cost")

func _test_party_actor_survives_for_revival() -> void:
	var battle := Battle.new()
	root.add_child(battle)
	await process_frame
	if battle.party.is_empty():
		_expect(false, "REVIVE SETUP: Battle did not build a party")
		battle.queue_free()
		return
	var entry := battle.party[0] as Dictionary
	var actor := entry.actor as Diver
	(entry.stats as CombatantStats).hp = 0
	actor.play_death_fade()
	await create_timer(1.1).timeout
	_expect(is_instance_valid(actor),
		"REVIVE ACTOR FREED: downed party actor must remain alive for Tidal Revival")
	if is_instance_valid(actor):
		_expect(actor.has_method("play_revive"),
			"REVIVE PRESENTATION MISSING: Diver has no play_revive() restoration")
		if actor.has_method("play_revive"):
			(entry.stats as CombatantStats).hp = 5
			actor.call("play_revive")
			await create_timer(0.7).timeout
			_expect(actor.visible and actor.scale.length() > 0.5,
				"REVIVE PRESENTATION BROKEN: restored diver is not visibly stage-sized")
	battle.queue_free()
	await process_frame

func _test_freed_return_home_is_quiet() -> void:
	var battle := Battle.new()
	root.add_child(battle)
	await process_frame
	var actor := Node3D.new()
	root.add_child(actor)
	var entry := {"actor": actor, "home_pos": Vector3.ZERO, "home_rot": 0.0}
	actor.queue_free()
	await process_frame
	await battle._send_home(entry, 0.0)
	_expect(true, "FREED HOME: gate wrapper also rejects any Godot script error")
	battle.queue_free()

func _run() -> void:
	_test_self_cost_is_next_turn_cost()
	_test_self_cost_is_paid_on_a_miss_or_qte_dodge()
	await _test_party_actor_survives_for_revival()
	await _test_freed_return_home_is_quiet()
	for finding in findings:
		print("FINDING  " + finding)
	print("COMBAT CONTENT RECONCILIATION: clean" if findings.is_empty() else "COMBAT CONTENT RECONCILIATION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
