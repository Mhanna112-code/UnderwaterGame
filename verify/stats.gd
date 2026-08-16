# Glass_Goat's worked examples, as tests.
#
# He wrote the rules out in Discord with numbers attached. Those numbers are
# the specification, so they are checked here rather than paraphrased into
# code and hoped about. If a rule ever changes, this file fails first and
# says which example it broke.
#
# Usage: godot --headless --path . --script verify/stats.gd
extends SceneTree

var findings: Array = []

func _init() -> void:
	# "5 Damage vs 3 Defense = Pierce 2"
	_expect(Stats.resolve(5, 3, 0).dealt, 2, "5 damage vs 3 defence gets 2 through")
	# "1 defense vs 5 damage = 4"
	_expect(Stats.resolve(5, 1, 0).dealt, 4, "5 damage vs 1 defence gets 4 through")
	# "5 Damage vs 3 armor = 2 damage"
	_expect(Stats.resolve(5, 3, 0).dealt, 2, "armour reads the same as defence")
	# "5 Damage vs barrier 5 = 0 damage"
	_expect(Stats.resolve(5, 0, 5).dealt, 0, "a barrier of 5 eats 5 damage")
	# "5 Damage vs barrier 0 = 5 damage"
	_expect(Stats.resolve(5, 0, 0).dealt, 5, "a barrier of 0 eats nothing")
	# a barrier is spent by what it soaks
	_expect(int(Stats.resolve(5, 0, 5).barrier_left), 0, "soaking 5 empties a barrier of 5")
	_expect(int(Stats.resolve(2, 0, 5).barrier_left), 3, "soaking 2 leaves 3 of a barrier of 5")
	# defence applies before the barrier has to
	_expect(Stats.resolve(5, 3, 5).dealt, 0, "defence first, then the barrier")
	_expect(int(Stats.resolve(5, 3, 5).barrier_left), 3, "the barrier only spends what defence let through")
	# damage never goes negative
	_expect(Stats.resolve(2, 9, 0).dealt, 0, "heavy armour cannot heal you")

	# "Strength/Power (Damage that gets added to physical attacks)"
	_expect(Stats.outgoing(5, 3), 8, "strength adds to the swing")
	_expect(Stats.outgoing(5, 0), 5, "no strength changes nothing")

	# "Dodge (avoid damage completely)" and
	# "Accuracy (Subtracts the dodge count so your attack will bypass)"
	_bool(Stats.evades(2, 0), true, "dodge 2 against no accuracy avoids")
	_bool(Stats.evades(2, 2), false, "accuracy 2 cancels dodge 2")
	_bool(Stats.evades(2, 1), true, "accuracy 1 leaves one dodge standing")
	_bool(Stats.evades(0, 0), false, "no dodge never avoids")
	_bool(Stats.evades(1, 5), false, "accuracy past the dodge count still just bypasses")

	# ailments land when they beat resistance, and clear after their turns
	_bool(Stats.ailment_lands(3, 2), true, "a stronger ailment than resistance lands")
	_bool(Stats.ailment_lands(2, 2), false, "resistance that matches it shrugs it off")
	_expect(Stats.heal_turns(3), 3, "healing capacity is turns to clear")
	_expect(Stats.heal_turns(0), 1, "clearing takes at least a turn")

	# a neutral block changes nothing, which is what lets the system land
	# before any character is tuned
	var n := Stats.neutral()
	_expect(Stats.outgoing(5, int(n.str)), 5, "neutral strength is no strength")
	_expect(Stats.resolve(5, int(n.def), int(n.barrier)).dealt, 5, "neutral defence is no defence")
	_bool(Stats.evades(int(n.dodge), 0), false, "neutral dodge never avoids")

	for f in findings:
		print("FINDING  " + f)
	print("STATS: clean, %d rules hold" % 22 if findings.is_empty() else "STATS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _expect(got: int, want: int, what: String) -> void:
	if got != want:
		findings.append("%s: expected %d, got %d" % [what, want, got])

func _bool(got: bool, want: bool, what: String) -> void:
	if got != want:
		findings.append("%s: expected %s, got %s" % [what, want, got])
