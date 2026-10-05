extends SceneTree
## EVA-1/2/3: immediate status cap, no refill/double subtraction, actual hit/miss.
var findings: Array[String] = []
var cases := 0

func _initialize() -> void:
	_authored_sequence()
	_missed_effect()
	for base in range(9):
		for spent in range(base + 1):
			for reduction in range(base + 4):
				for temporary in [-2, 0, 2]:
					_cap_case(base, spent, reduction, temporary)
	for finding in findings.slice(0, 20):
		print("FINDING ", finding)
	print("MARC EVASION POOL: clean|generated=%d" % cases if findings.is_empty() else "MARC EVASION POOL: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _stats(eva: int, acc := 0) -> CombatantStats:
	var stats := CombatantStats.new()
	stats.evasion = eva
	stats.accuracy = acc
	stats.hp_max = 20
	stats.defense = 0
	stats.fill()
	return stats

func _cap_case(base: int, spent: int, reduction: int, temporary: int) -> void:
	cases += 1
	var target := _stats(base)
	target.spend_evasion(spent)
	target.add_temporary_modifier("evasion", temporary)
	var before := mini(base - spent, maxi(0, base + temporary))
	target.add_status("evasion_down", reduction, 3)
	var expected := mini(before, maxi(0, base + temporary - reduction)) if reduction > 0 else before
	var id := "base=%d spent=%d down=%d temp=%d" % [base, spent, reduction, temporary]
	_expect(target.evasion_current == expected, "EVA-1 immediate pool disagrees with remaining weakened allowance: " + id)
	_expect(target.effective_evasion() == maxi(0, base + temporary - reduction), "EVA-2 effective value double-subtracts or ignores status: " + id)
	# A weaker repeat must neither refill spent EVA nor stack this status.
	target.add_status("evasion_down", maxi(0, reduction - 1), 1)
	_expect(target.evasion_current == expected, "EVA-2 weaker reapplication refills/overspends EVA: " + id)
	for turn in range(3):
		target.end_turn()
	_expect(target.status_level("evasion_down") == 0, "EVA-3 timed status failed expiry: " + id)
	_expect(target.evasion_current == expected, "EVA-2 expiry magically refills current pool before turn: " + id)
	target.begin_turn()
	_expect(target.evasion_current == base and target.effective_evasion() == base, "EVA-3 next turn fails to restore original allowance: " + id)
	target.add_status("evasion_down", 2, 0)
	target.end_turn()
	_expect(target.status_level("evasion_down") == 2, "EVA-3 persistent status invents an expiry: " + id)
	target.recover_after_victory()
	_expect(target.evasion_current == base and target.status_level("evasion_down") == 0, "EVA-3 battle-end cleanup leaves reduced pool: " + id)

func _flash() -> Dictionary:
	for move in EnemyMoves.angler_catalogue():
		if move.id == "flash_blast":
			return move.combat
	return {}

func _authored_sequence() -> void:
	var target := _stats(6)
	target.spend_evasion(2)
	var angler := _stats(0, 4)
	var result := CombatRules.resolve(angler, target, _flash())
	_expect(result.hit and target.status_level("evasion_down") == 4, "EVA-1 authored Flash Blast did not land its genuine status")
	_expect(target.evasion_current == 2, "EVA-1 actual Flash Blast leaves pool at 4 instead of immediately lowering to 2")
	var followup := _stats(0, 3)
	var attack := CombatRules.resolve(followup, target, {"formula": {"flat": 2}})
	_expect(attack.hit and attack.damage == 2 and target.hp == 18, "EVA-1 follow-up real attack dodges despite weakened live EVA")

func _missed_effect() -> void:
	var target := _stats(6)
	var result := CombatRules.resolve(_stats(0, 2), target, _flash())
	_expect(not result.hit and target.status_level("evasion_down") == 0 and target.evasion_current == 3, "EVA-3 missed Flash Blast applied a status or failed ordinary dodge spending")
	target.add_status("evasion_down", 0, 3)
	_expect(target.evasion_current == 3 and target.status_level("evasion_down") == 0, "EVA-3 zero-level effect changes pool/status")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
