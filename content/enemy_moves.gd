# Ordinary-enemy moves are content data. Adding a delivered attack means adding
# one record here after its clip has passed the Angler import gate; Battle does
# not need a new branch for that animation. A move stays disabled until its
# combat role is agreed, so a newly delivered artist clip never alters balance
# by surprise.
class_name EnemyMoves
extends RefCounted

# `clip` is a case-insensitive fragment of the FBX animation take. Ramming
# Bite (the old heavy finisher, "heavy_bite") has been removed entirely -
# Bite is now the Angler's only enabled move, so `weight`/`finisher_weight`
# no longer do anything (finisher mode never triggers without any enabled
# move declaring finisher_below_hp) and aren't set here any more either.
# Normal move power uses the same 1-4 authored-stat scale as Glassgoat's
# 10-HP party; the two additional delivered clips are deliberately visible
# to the catalogue but disabled until Glassgoat/team select their intended
# mechanics.
const ANGLER := [
	{
		"id": "bite", "name": "Bite", "clip": "attack)bite",
		"enabled": true, "target": "single", "roll_order": 1, "weight": 100.0,
		"verb": "bites at",
		"combat": {"power": 3, "acc_mod": 1, "quick_time_bool": false},
	},
	{
		"id": "headbutt", "name": "Headbutt", "clip": "attack)headbutt",
		"enabled": false, "target": "single", "roll_order": 2, "weight": 0.0,
		"finisher_weight": 0.0, "verb": "headbutts",
		"combat": {"power": 3, "acc_mod": 1, "quick_time_bool": false},
	},
	{
		"id": "shine", "name": "Lure Flash", "clip": "attack)shine",
		"enabled": false, "target": "single", "roll_order": 3, "weight": 0.0,
		"finisher_weight": 0.0, "verb": "flashes at",
		"combat": {"power": 3, "acc_mod": 1, "quick_time_bool": false},
	},
]

static func angler_catalogue() -> Array:
	return ANGLER.duplicate(true)

# The second guardian keeps the proven ordinary-enemy damage/accuracy math.
# Great Slash carries the former normal Bite slot; Stabbing carries the former
# low-HP heavy slot. The delivered spinning drill is visible but disabled until
# the team chooses whether it is a single-target drill or a multi-target move.
const SWORDFISH_DUELIST := [
	{
		"id": "great_slash", "name": "Great Slash", "clip": "attack)greatslash",
		"enabled": true, "target": "single", "roll_order": 1, "weight": 70.0,
		"finisher_weight": 35.0, "verb": "slashes at",
		"combat": {"power": 3, "acc_mod": 1, "quick_time_bool": false},
	},
	{
		"id": "stabbing", "name": "Stabbing Lunge", "clip": "attack)stabbing",
		"enabled": true, "target": "single", "roll_order": 0, "weight": 30.0,
		"finisher_weight": 65.0, "verb": "lunges at",
		"finisher_below_hp": 0.5,
		"combat": {
			"power": 0, "acc_mod": -1, "quick_time_bool": true,
			"effect": "heavy", "heavy_min": 0.25, "heavy_max": 0.5,
		},
	},
	{
		"id": "spinning_drill", "name": "Spinning Drill", "clip": "attack)spinning_drill",
		"enabled": false, "target": "single", "roll_order": 2, "weight": 0.0,
		"finisher_weight": 0.0, "verb": "spins toward",
		"combat": {"power": 3, "acc_mod": 1, "quick_time_bool": false},
	},
]

static func swordfish_duelist_catalogue() -> Array:
	return SWORDFISH_DUELIST.duplicate(true)
