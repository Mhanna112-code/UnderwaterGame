# Verifies the first playable vertical slice of Glassgoat's Group_StatsV2
# combat specification. Each assertion names the player-visible failure it
# prevents so changes to the rules cannot silently turn the system back into
# generic power-versus-defense combat.
#
# Usage: godot --headless --path . --script verify/glassgoat_combat.gd
extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	_test_scuba_stats_and_authored_moves()
	_test_evasion_is_spent_by_a_dodge_and_resets_on_turn()
	_test_evasion_wins_a_tie()
	_test_skill_formula_uses_the_wielder_stats()
	_test_minimum_damage_rule()
	_test_electric_touch_strips_evasion()
	_test_stabbing_applies_and_ticks_bleed()
	_test_flash_blast_applies_timed_blindness()
	_test_temporary_penalty_clears_on_next_turn()
	_test_all_target_self_cost_is_paid_once()
	_test_evasion_down_status_lowers_evasion_and_expires()
	_test_stun_status_blocks_a_whole_turn_and_expires()
	_test_bleed_duration_does_not_reset_on_reapplication()
	_test_tail_spin_strips_defense_by_the_wielders_own_defense()

	for failure in failures:
		push_error(failure)
	print("GLASSGOAT COMBAT: %s" % ("clean" if failures.is_empty() else "%d failure(s)" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _stats(hp: int, strength: int, defense: int, agility: int, evasion: int, accuracy: int) -> CombatantStats:
	var stats := CombatantStats.new()
	stats.hp_max = hp
	stats.strength = strength
	stats.defense = defense
	stats.agility = agility
	stats.evasion = evasion
	stats.accuracy = accuracy
	stats.fill()
	return stats

func _move(name: String) -> Dictionary:
	for move in CombatMoves.SCUBA:
		if String(move.name) == name:
			return move
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _test_scuba_stats_and_authored_moves() -> void:
	var scuba: Dictionary = Diver.BASE_STATS["Staff_Diver"]
	_expect([scuba.hp, scuba.strength, scuba.defense, scuba.agility, scuba.evasion, scuba.accuracy] == [10, 1, 0, 3, 3, 3],
		"SCUBA STATS DRIFT: expected Group_StatsV2's 10/1/0/3/3/3 block")
	_expect(CombatMoves.SCUBA.map(func(move: Dictionary) -> String: return String(move.name)) == [
		"Electric Touch", "Scuba Stabbing", "Flash Blast", "Multiple Knee Combo", "Axe Kick"],
		"SCUBA KIT INCOMPLETE: all five authored moves must be available")

func _test_evasion_is_spent_by_a_dodge_and_resets_on_turn() -> void:
	var attacker := _stats(10, 1, 0, 1, 0, 2)
	var defender := _stats(10, 1, 0, 1, 6, 1)
	var result := CombatRules.resolve(attacker, defender, {"name": "Test", "formula": {}, "effects": []})
	_expect(not result.hit, "DODGE INVISIBLE IN RULES: 2 accuracy must not hit 6 evasion")
	_expect(defender.evasion_current == 4, "EVASION NOT SPENT: dodging 2 accuracy must reduce 6 current evasion to 4")
	defender.begin_turn()
	_expect(defender.evasion_current == 6, "EVASION NOT RESET: current evasion must refill at the defender's next turn")

func _test_evasion_wins_a_tie() -> void:
	var attacker := _stats(10, 1, 0, 1, 0, 3)
	var defender := _stats(10, 1, 0, 1, 3, 1)
	var result := CombatRules.resolve(attacker, defender, {"name": "Test", "formula": {}, "effects": []})
	_expect(not result.hit, "TIE RULE DRIFT: Group_StatsV2 says evasion wins a tie")

func _test_skill_formula_uses_the_wielder_stats() -> void:
	var move := {"name": "Shared strike", "formula": {"flat": 2, "strength": 1}, "effects": []}
	var target_a := _stats(20, 1, 0, 1, 0, 0)
	var target_b := _stats(20, 1, 0, 1, 0, 0)
	var weak := _stats(10, 1, 0, 1, 0, 10)
	var strong := _stats(10, 4, 0, 1, 0, 10)
	var weak_result := CombatRules.resolve(weak, target_a, move)
	var strong_result := CombatRules.resolve(strong, target_b, move)
	_expect(weak_result.damage == 3 and strong_result.damage == 6,
		"SKILL/WIELDER COMPOSITION BROKEN: one shared 2+STR move must produce 3 and 6 for different wielders")

func _test_minimum_damage_rule() -> void:
	var attacker := _stats(10, 1, 0, 1, 0, 10)
	var lightly_armored := _stats(10, 1, 4, 1, 0, 0)
	var overmatched := _stats(10, 1, 8, 1, 0, 0)
	var move := {"name": "Tap", "formula": {"strength": 1}, "effects": []}
	_expect(CombatRules.resolve(attacker, lightly_armored, move).damage == 1,
		"MINIMUM DAMAGE BROKEN: defense may not reduce a hit below 1 when the difference is 5 or less")
	_expect(CombatRules.resolve(attacker, overmatched, move).damage == 0,
		"FULL ABSORB BROKEN: defense more than 5 above damage must be able to absorb the hit")

func _test_electric_touch_strips_evasion() -> void:
	var scuba := _stats(10, 1, 0, 3, 3, 3)
	var target := _stats(10, 1, 0, 1, 2, 0)
	var result := CombatRules.resolve(scuba, target, _move("Electric Touch"))
	_expect(result.damage == 1, "ELECTRIC TOUCH FORMULA WRONG: it deals Scuba's Strength")
	_expect(target.evasion == 0 and target.evasion_current == 0,
		"ELECTRIC TOUCH EFFECT MISSING: it lowers target evasion by Scuba's Accuracy")

func _test_stabbing_applies_and_ticks_bleed() -> void:
	var scuba := _stats(10, 1, 0, 3, 3, 3)
	var target := _stats(10, 1, 0, 1, 0, 0)
	var result := CombatRules.resolve(scuba, target, _move("Scuba Stabbing"))
	_expect(result.damage == 1 and target.status_level("bleed") == 2,
		"SCUBA STABBING EFFECT MISSING: Strength damage must apply 1+Strength bleed")
	CombatRules.resolve(scuba, target, {"name": "Follow-up", "formula": {"strength": 1}, "effects": []})
	_expect(target.status_level("bleed") == 3,
		"BLEED DOES NOT BUILD: later damaging hits must add one stack to an already bleeding target")
	var tick := target.end_turn()
	_expect(tick.bleed_damage == 3 and target.hp == 5,
		"BLEED TICK WRONG: three bleed must deal three damage after two one-damage hits")

func _test_flash_blast_applies_timed_blindness() -> void:
	var scuba := _stats(10, 1, 0, 3, 3, 3)
	var target := _stats(10, 1, 3, 4, 0, 4)
	CombatRules.resolve(scuba, target, _move("Flash Blast"))
	_expect(target.status_level("blindness") == 2 and target.status_turns("blindness") == 3,
		"FLASH BLAST STATUS WRONG: Blindness 2 must last for Scuba's 3 Accuracy turns")
	_expect(target.effective_accuracy() == 2 and target.effective_agility() == 2 and target.effective_defense() == 1,
		"BLINDNESS STATS WRONG: level 2 must lower accuracy, agility, and defense by 2")

func _test_temporary_penalty_clears_on_next_turn() -> void:
	var scuba := _stats(10, 1, 0, 3, 3, 3)
	var target := _stats(10, 1, 0, 1, 0, 0)
	CombatRules.resolve(scuba, target, _move("Axe Kick"))
	_expect(scuba.effective_evasion() == 0, "AXE KICK COST MISSING: Scuba must lose 3 evasion until her next turn")
	scuba.begin_turn()
	_expect(scuba.effective_evasion() == 3 and scuba.evasion_current == 3,
		"TEMPORARY PENALTY STUCK: Axe Kick evasion must return at Scuba's next turn")

func _test_all_target_self_cost_is_paid_once() -> void:
	var scuba := _stats(10, 1, 0, 3, 3, 3)
	var first := _stats(10, 1, 0, 1, 0, 0)
	var second := _stats(10, 1, 0, 1, 0, 0)
	var move := _move("Multiple Knee Combo")
	CombatRules.resolve(scuba, first, move, true)
	CombatRules.resolve(scuba, second, move, false)
	_expect(scuba.effective_accuracy() == 2 and scuba.effective_evasion() == 2,
		"ALL-TARGET COST MULTIPLIED: Multiple Knee Combo's -1 ACC/EVA applies once, not once per foe")

# Angler's Flash Blast (content/enemy_moves.gd) is the first move to use this
# status - a timed Evasion debuff shaped exactly like Blindness above, just
# scoped to one stat, so it decays through the same generic end_turn() sweep
# instead of needing its own expiry code.
func _test_evasion_down_status_lowers_evasion_and_expires() -> void:
	var angler := _stats(10, 1, 0, 1, 0, 3)
	var target := _stats(10, 1, 0, 1, 2, 0)
	var move := {
		"name": "Flash Blast", "formula": {}, "effects": [
			{"kind": "status", "status": "evasion_down", "level": {"accuracy": 1}, "duration": {"accuracy": 1}},
		],
	}
	CombatRules.resolve(angler, target, move)
	_expect(target.effective_evasion() == 0 and target.status_turns("evasion_down") == 3,
		"EVASION DOWN STATUS WRONG: Flash Blast must lower Evasion by the Angler's 3 Accuracy for 3 turns")
	for _tick in range(3):
		target.end_turn()
	_expect(target.status_level("evasion_down") == 0 and target.effective_evasion() == 2,
		"EVASION DOWN DOES NOT EXPIRE: Evasion must return once its 3-turn duration ends")

# Angler's Headbutt (content/enemy_moves.gd) is the first move to use Stun.
# Applying it is exactly the existing generic "status" effect path; the actual
# turn-skip is Battle._advance_turn()'s job (untested here, no scene tree),
# but consume_status_turn() is what makes that skip's clock ever reach zero,
# so its countdown contract is worth locking down on its own.
func _test_stun_status_blocks_a_whole_turn_and_expires() -> void:
	var angler := _stats(10, 2, 0, 1, 0, 3)
	var target := _stats(10, 1, 0, 1, 2, 0)
	var move := {
		"name": "Headbutt", "formula": {"strength": 1}, "effects": [
			{"kind": "status", "status": "stun", "level": {"flat": 1}, "duration": {"strength": 1}},
		],
	}
	var result := CombatRules.resolve(angler, target, move)
	_expect(result.damage == 2, "HEADBUTT FORMULA WRONG: it deals the Angler's Strength")
	_expect(target.is_stunned() and target.status_turns("stun") == 2,
		"HEADBUTT STUN MISSING: it must stun for the Angler's 2 Strength turns")
	target.consume_status_turn("stun")
	_expect(target.is_stunned() and target.status_turns("stun") == 1,
		"STUN DOES NOT COUNT DOWN: skipping one stunned turn must only tick the clock by one")
	target.consume_status_turn("stun")
	_expect(not target.is_stunned(), "STUN NEVER EXPIRES: it must clear once its turns run out")

# Bite (content/enemy_moves.gd) is the first move to give Bleed a real,
# capped duration instead of the persistent-for-the-fight duration Scuba
# Stabbing uses. add_status()'s existing "already bleeding" merge branch only
# ever touched level, never turns, so a repeat Bite stacks the level onto the
# existing clock rather than refreshing a fresh 3 turns on top of it - worth
# locking down explicitly since "shouldn't reapplying it also reset the
# timer?" is an easy, wrong assumption for a later change to make.
func _test_bleed_duration_does_not_reset_on_reapplication() -> void:
	var target := _stats(10, 1, 0, 1, 0, 0)
	target.add_status("bleed", 2, 3)
	target.end_turn()
	_expect(target.status_level("bleed") == 2 and target.status_turns("bleed") == 2,
		"BLEED TIMER WRONG: a 3-turn Bleed must have 2 turns left after one end_turn()")
	target.add_status("bleed", 2, 3)
	_expect(target.status_level("bleed") == 4 and target.status_turns("bleed") == 2,
		"BLEED REAPPLICATION WRONG: a second landed Bite must stack onto the existing level without resetting its remaining 2-turn clock")
	target.end_turn()
	target.end_turn()
	_expect(target.status_level("bleed") == 0,
		"BLEED NEVER EXPIRES: it must still clear once its original clock reaches zero, even after a mid-flight level increase")

# Frilled Shark's Tail Spin (content/enemy_moves.gd) is the first move to use
# reduce_defense() - Electric Touch's reduce_evasion() counterpart, but for
# Defense, and by the wielder's OWN Defense rather than anything the target
# has. Runs after this same hit's own damage (CombatRules.resolve() computes
# damage before walking the effects list), so this hit isn't softened by the
# Defense it strips - only every attack after it is.
func _test_tail_spin_strips_defense_by_the_wielders_own_defense() -> void:
	var shark := _stats(10, 2, 3, 1, 0, 3)
	var target := _stats(10, 1, 4, 1, 0, 0)
	var move := {
		"name": "Tail Spin", "formula": {"strength": 1}, "effects": [
			{"kind": "reduce_defense", "amount": {"defense": 1}},
		],
	}
	var result := CombatRules.resolve(shark, target, move)
	_expect(result.damage == 1, "TAIL SPIN FORMULA WRONG: it deals the Frilled Shark's Strength (2), floored at 1 by its own 4 Defense")
	_expect(target.defense == 1, "TAIL SPIN EFFECT MISSING: it must lower the target's Defense by the Frilled Shark's own 3 Defense")
