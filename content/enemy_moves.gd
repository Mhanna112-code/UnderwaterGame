# Ordinary-enemy moves are content data. Adding a delivered attack means adding
# one record here after its clip has passed the Angler import gate; Battle does
# not need a new branch for that animation. A move stays disabled until its
# combat role is agreed, so a newly delivered artist clip never alters balance
# by surprise.
class_name EnemyMoves
extends RefCounted

# `clip` is a case-insensitive fragment of the FBX animation take. The first
# two entries preserve the old normal/heavy probabilities exactly: 70/30 in a
# normal turn and 35/65 when a target is in heavy-finisher range. The two
# additional delivered clips are deliberately visible to the catalogue but
# disabled until Glassgoat/team select their intended mechanics.
const ANGLER := [
	{
		"id": "bite", "name": "Bite", "clip": "attack)bite",
		"enabled": true, "target": "single", "roll_order": 1, "weight": 70.0,
		"finisher_weight": 35.0, "verb": "bites at",
		"combat": {"power": 9, "acc_mod": 1, "quick_time_bool": false},
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
		"id": "headbutt", "name": "Headbutt", "clip": "attack)headbutt",
		"enabled": false, "target": "single", "roll_order": 2, "weight": 0.0,
		"finisher_weight": 0.0, "verb": "headbutts",
		"combat": {"power": 9, "acc_mod": 1, "quick_time_bool": false},
	},
	{
		"id": "shine", "name": "Lure Flash", "clip": "attack)shine",
		"enabled": false, "target": "single", "roll_order": 3, "weight": 0.0,
		"finisher_weight": 0.0, "verb": "flashes at",
		"combat": {"power": 9, "acc_mod": 1, "quick_time_bool": false},
	},
]

static func angler_catalogue() -> Array:
	return ANGLER.duplicate(true)
