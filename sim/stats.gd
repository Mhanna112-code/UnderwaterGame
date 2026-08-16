# The stat rules, exactly as Glass_Goat specified them.
#
#   Strength / Power      damage added to physical attacks
#   Defense / Armor       subtracts the damage
#   Dodge                 your ability to avoid damage completely
#   Accuracy              subtracts the dodge count so your attack bypasses
#   Barrier               absorbs damage: 5 vs barrier 5 is 0, 5 vs barrier 0 is 5
#   Ailment resistance    your ability to not be affected by ailments
#   Ailment healing       how many turns you take to heal from one
#
# Pure functions on plain numbers. No node, no scene, no randomness: the same
# inputs give the same answer every time, which is what lets verify/stats.gd
# hold his worked examples as tests and lets the bots measure a fight in
# thousands of runs without the numbers wandering.
#
# Everything here is deterministic on purpose. Dodge is a COUNT, not a
# percentage, because that is how he wrote it: "dodge 2", and accuracy
# "subtracts the dodge count". A pool that gets spent, not a coin flip.
class_name Stats
extends RefCounted

const KEYS := ["str", "def", "dodge", "acc", "barrier", "ail_res", "ail_heal"]

# a stat block with everything at zero: the rules present, changing nothing
static func neutral() -> Dictionary:
	return {"str": 0, "def": 0, "dodge": 0, "acc": 0, "barrier": 0, "ail_res": 0, "ail_heal": 1}

static func of(d: Dictionary) -> Dictionary:
	var out := neutral()
	for k in KEYS:
		if d.has(k):
			out[k] = int(d[k])
	return out

# What an attack is worth before the target is considered.
static func outgoing(base: int, strength: int) -> int:
	return maxi(0, base + strength)

# Does the target get out of the way entirely? Accuracy eats dodge one for
# one, so a dodge of 2 against an accuracy of 2 is no dodge at all.
static func evades(dodge: int, accuracy: int) -> bool:
	return (dodge - accuracy) > 0

# Armor subtracts every time. Barrier is a pool: it soaks what it can and is
# spent doing it. Returns what actually lands and what is left of the barrier.
static func resolve(raw: int, defense: int, barrier: int) -> Dictionary:
	var after_def: int = maxi(0, raw - maxi(0, defense))
	var soaked: int = mini(after_def, maxi(0, barrier))
	return {"dealt": after_def - soaked, "barrier_left": maxi(0, barrier) - soaked}

# An ailment lands when it is stronger than what the target can shrug off.
static func ailment_lands(power: int, resistance: int) -> bool:
	return power > resistance

# How long it clings once it has. Capacity is turns-to-clear, so a bigger
# number is a worse constitution, and one turn is the floor.
static func heal_turns(capacity: int) -> int:
	return maxi(1, capacity)
