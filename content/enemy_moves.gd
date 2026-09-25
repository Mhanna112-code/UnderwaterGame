# Ordinary-enemy moves are content data. Adding a delivered attack means adding
# one record here after its clip has passed the Angler import gate; Battle does
# not need a new branch for that animation. A move stays disabled until its
# combat role is agreed, so a newly delivered artist clip never alters balance
# by surprise.
class_name EnemyMoves
extends RefCounted

# `clip` is a case-insensitive fragment of the FBX animation take. Glassgoat's
# final Angler table names exactly Bite, Headbutt and Shine (Flash Blast); the
# legacy Ramming Bite is not an authored attack and is intentionally absent.
# The three delivered attacks use the same wielder-stat "formula"/"effects"
# shape as content/combat_moves.gd's V2 player kit (see CombatRules.resolve),
# so Bite's stacking Bleed, Headbutt's Strength-scaled Stun and Flash Blast's
# timed Evasion drop all resolve from the enemy's own stats.
#
# The relative selection weights predate this reconciliation and are a balance
# policy, not a fourth attack. The route simulator remains the guardrail after
# the authored persistent Bleed is restored; it exercises two guardian sites
# and random encounters rather than claiming a single isolated fight proves
# the campaign is fair.
const ANGLER := [
	{
		"id": "bite", "name": "Bite", "clip": "attack)bite",
		"enabled": true, "target": "single", "roll_order": 1, "weight": 16.0,
		"finisher_weight": 8.0, "verb": "bites at",
		"combat": {
			"formula": {"strength": 1}, "acc_mod": 1,
			"effects": [
				{"kind": "status", "status": "bleed", "level": {"flat": 1, "strength": 1}},
			],
		},
	},
	{
		# Headbutt's duration follows the Angler's own Strength exactly as the
		# authored table specifies. A stunned actor loses that many whole turns;
		# CombatantStats.consume_status_turn() owns the countdown.
		"id": "headbutt", "name": "Headbutt", "clip": "attack)headbutt",
		"enabled": true, "target": "single", "roll_order": 2, "weight": 8.0,
		"finisher_weight": 0.0, "verb": "headbutts",
		"combat": {
			"formula": {"strength": 1}, "acc_mod": 1,
			"effects": [
				{"kind": "status", "status": "stun", "level": {"flat": 1}, "duration": {"strength": 1}},
			],
		},
	},
	{
		# No finisher_weight above zero: a party-wide Evasion debuff isn't a
		# closing blow, so it stays out of the low-HP finisher roll entirely
		# (see Goblin.choose_move()'s finisher_below_hp scan).
		"id": "flash_blast", "name": "Flash Blast", "clip": "attack)shine",
		"enabled": true, "target": "all", "roll_order": 3, "weight": 15.0,
		"finisher_weight": 0.0, "verb": "flashes at",
		"combat": {
			"formula": {}, "acc_mod": 1,
			"effects": [
				{"kind": "status", "status": "evasion_down", "level": {"accuracy": 1}, "duration": {"accuracy": 1}},
			],
		},
	},
]

static func angler_catalogue() -> Array:
	return ANGLER.duplicate(true)

# Glassgoat's Swordfish kit is formula-driven like the V2 diver moves. The
# artist specified the mechanics and supplied one clip per attack, but not AI
# selection odds. The provisional initial odds make Arc Slash's two-target
# persistent Bleed a rare pressure move, Triple Combo an occasional Evasion
# counter, and Spinning Slayer the readable default. "two" means the weighted-picked
# primary target plus one other living diver (Battle.enemy_targets_for_scope),
# which makes Arc Slash's stated Target: 2 deterministic and never duplicates
# a target. Triple Combo intentionally has no legacy heavy/QTE fields: its
# authored counterplay is three sequential normal hits, each of which spends
# the defender's current Evasion pool before the next begins.
const SWORDFISH_DUELIST := [
	{
		"id": "arc_slash", "name": "Arc Slash", "clip": "attack)greatslash",
		"enabled": true, "target": "two", "roll_order": 0, "weight": 0.08,
		"finisher_weight": 0.08, "verb": "cuts through",
		"combat": {
			"formula": {"strength": 1, "defense": 1}, "acc_mod": 1,
			"effects": [
				{"kind": "status", "status": "bleed", "level": {"strength": 1}},
			],
		},
	},
	{
		"id": "triple_combo", "name": "Triple Combo", "clip": "attack)stabbing",
		"enabled": true, "target": "single", "roll_order": 1, "weight": 0.25,
		"finisher_weight": 0.25, "verb": "strikes",
		"combat": {
			"formula": {"strength": 1}, "acc_mod": 1, "hits": 3,
		},
	},
	{
		"id": "spinning_slayer", "name": "Spinning Slayer", "clip": "attack)spinning_drill",
		"enabled": true, "target": "single", "roll_order": 2, "weight": 0.67,
		"finisher_weight": 0.67, "verb": "drills into",
		"combat": {
			"formula": {"strength": 1, "defense": 1}, "acc_mod": 1,
			"effects": [
				{"kind": "reduce_defense", "amount": {"defense": 1}},
			],
		},
	},
]

static func swordfish_duelist_catalogue() -> Array:
	return SWORDFISH_DUELIST.duplicate(true)

# The third ordinary enemy. Bite deals Strength plus the Frilled Shark's own
# Defense ("Armor") - CombatRules.formula_value() already sums any named stat
# coefficient, so "Strength + Armor" needs no new engine support, just the
# {"strength": 1, "defense": 1} formula below. Tail Spin deals plain Strength
# damage and then (see CombatRules.resolve()'s effects loop running after
# damage, not before) strips the target's own Defense by the Frilled Shark's
# Defense - same "amount is the wielder's own stat" convention as Flash
# Blast's Evasion drop and Headbutt's Stun duration, both by the attacker's
# own Accuracy/Strength rather than anything belonging to the target.
# Weight/finisher_weight are placeholder selection odds, same disclaimer as
# Headbutt/Flash Blast's own comments in the Angler catalogue above.
const FRILLED_SHARK := [
	{
		"id": "bite", "name": "Bite", "clip": "attack)bite",
		"enabled": true, "target": "single", "roll_order": 0, "weight": 60.0,
		"finisher_weight": 60.0, "verb": "bites at",
		"combat": {"formula": {"strength": 1, "defense": 1}, "acc_mod": 1},
	},
	{
		"id": "tail_spin", "name": "Tail Spin", "clip": "attack)tailspin",
		"enabled": true, "target": "single", "roll_order": 1, "weight": 40.0,
		"finisher_weight": 40.0, "verb": "spins its tail into",
		"combat": {
			"formula": {"strength": 1}, "acc_mod": 1,
			"effects": [
				{"kind": "reduce_defense", "amount": {"defense": 1}},
			],
		},
	},
]

static func frilled_shark_catalogue() -> Array:
	return FRILLED_SHARK.duplicate(true)

# Sea Urchin is a delivered model, but Glassgoat has not yet supplied its
# authored attack names/clips.  This deliberately conservative placeholder
# exists only so the armored counter lesson is playable now.  Its neutral
# contact move has no clip requirement and must be replaced—not expanded—when
# the final urchin kit is delivered.
const SEA_URCHIN := [
	{
		"id": "contact_spines", "name": "Contact Spines", "clip": "",
		"enabled": true, "target": "single", "roll_order": 0, "weight": 1.0,
		"finisher_weight": 1.0, "verb": "scrapes against",
		"combat": {"formula": {"strength": 1}, "acc_mod": 0},
	},
]

static func sea_urchin_catalogue() -> Array:
	return SEA_URCHIN.duplicate(true)
