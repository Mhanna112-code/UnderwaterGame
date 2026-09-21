# Ordinary-enemy moves are content data. Adding a delivered attack means adding
# one record here after its clip has passed the Angler import gate; Battle does
# not need a new branch for that animation. A move stays disabled until its
# combat role is agreed, so a newly delivered artist clip never alters balance
# by surprise.
class_name EnemyMoves
extends RefCounted

# `clip` is a case-insensitive fragment of the FBX animation take. Ramming
# Bite keeps its original 30/65 heavy-finisher weight and plain power+strength
# formula unchanged. Bite, Headbutt and Flash Blast are Glassgoat's Discord
# follow-up decision for the other three delivered clips: all three use the
# same wielder-stat "formula"/"effects" shape as content/combat_moves.gd's V2
# player kit (see CombatRules.resolve, which _resolve_attack() dispatches to
# whenever a move carries a "formula" key) rather than the old power/effect
# fields, so Bite's stacking Bleed, Headbutt's Stun and Flash Blast's timed
# Evasion drop all read the same way a player's Scuba Stabbing/Electric Touch/
# Flash Blast do.
#
# Bite's weight dropped from the pre-Bleed 70/30 split to 16/8 (see
# verify/balance.bug-catalog.md for this project's established practice of
# retuning ordinary-enemy numbers whenever new content shifts the math): Bite
# is the AI's default, no-cost pick on most turns, unlike a player's occasional
# Scuba Stabbing, so even a capped-duration Bleed stacks far more often than
# the same formula does in a human's hands. verify/balance.gd's route gate (a
# full two-guardian campaign, not just one isolated fight) is what actually
# caught this - the isolated per-fight win rate looked fine even at a much
# higher weight, but the campaign's 30%-victory-recovery model compounds a
# small per-fight HP cost increase into a much larger route-completion drop.
# Bite's Bleed itself is capped at 3 turns rather than persistent-for-the-fight
# (unlike the player's own Stabbing) for the same reason - a wound that closes
# on its own instead of only clearing at the fight's end. Headbutt and Flash
# Blast stay deliberately low-weight for the same reason; see their own
# comments below.
const ANGLER := [
	{
		"id": "bite", "name": "Bite", "clip": "attack)bite",
		"enabled": true, "target": "single", "roll_order": 1, "weight": 16.0,
		"finisher_weight": 8.0, "verb": "bites at",
		"combat": {
			"formula": {"strength": 1}, "acc_mod": 1,
			"effects": [
				{"kind": "status", "status": "bleed", "level": {"flat": 1, "strength": 1}, "duration": 3},
			],
		},
	},
	{
		"id": "heavy_bite", "name": "Ramming Bite", "clip": "attack)bite",
		"enabled": true, "target": "single", "roll_order": 0, "weight": 30.0,
		"finisher_weight": 65.0, "verb": "surges and slams into",
		"finisher_below_hp": 0.5,
		"combat": {
			"power": 0, "acc_mod": -1, "quick_time_bool": true,
			"effect": "heavy", "heavy_min": 0.25, "heavy_max": 0.5,
		},
	},
	{
		# Weight is a placeholder selection odd - Glassgoat's follow-up
		# specified the damage/stun formula, not how often the AI should reach
		# for it relative to Bite/Ramming Bite. Kept low and out of the
		# finisher roll entirely (0.0): losing a whole turn to Stun is a bigger
		# swing than any single hit, so verify/balance.gd's route gate is the
		# guardrail against over-tuning this one - see that gate for the
		# accepted casual/skilled band. No reason to also spend it on a target
		# about to die anyway, the way Ramming Bite's actual finisher does.
		#
		# Stun's duration is a flat 2, not a formula off the Angler's own
		# Strength - a deliberate choice so it stays exactly 2 turns regardless
		# of the per-fight edge/level scaling in Goblin.make_stats(), rather
		# than wobbling between 2 and 3 turns depending on that roll.
		"id": "headbutt", "name": "Headbutt", "clip": "attack)headbutt",
		"enabled": true, "target": "single", "roll_order": 2, "weight": 8.0,
		"finisher_weight": 0.0, "verb": "headbutts",
		"combat": {
			"formula": {"strength": 1}, "acc_mod": 1,
			"effects": [
				{"kind": "status", "status": "stun", "level": {"flat": 1}, "duration": 2},
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
