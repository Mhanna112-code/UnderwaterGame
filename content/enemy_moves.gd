# Ordinary-enemy moves as content data. New moves stay disabled until their combat role is agreed.
class_name EnemyMoves
extends RefCounted

# Defense Down duration for Spinning Slayer / Tail Spin, in the target's own turns.
const DEFENSE_DOWN_TURNS := 3

# `clip` is a case-insensitive fragment of the FBX take name. Moves use the same formula/effects
# shape as combat_moves.gd (see CombatRules.resolve); selection weights are balance policy.
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
		# Fixed two-turn stun (not Strength-scaled) for balance; consume_status_turn() owns the countdown.
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
		# No finisher_weight: a party-wide debuff isn't a closing blow.
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

# Swordfish kit; odds are provisional. "two" = weighted primary target plus one other living diver.
# Triple Combo is three sequential normal hits, each spending the defender's Evasion pool.
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
			# Timed status, not a permanent Defense cut.
			"effects": [
				{"kind": "status", "status": "defense_down", "level": {"defense": 1}, "duration": DEFENSE_DOWN_TURNS},
			],
		},
	},
]

static func swordfish_duelist_catalogue() -> Array:
	return SWORDFISH_DUELIST.duplicate(true)

# Frilled Shark. Bite = Strength + Defense; Tail Spin then strips target Defense by the shark's Defense.
# Weights are placeholder odds.
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
			# Timed status, not a permanent Defense cut.
			"effects": [
				{"kind": "status", "status": "defense_down", "level": {"defense": 1}, "duration": DEFENSE_DOWN_TURNS},
			],
		},
	},
]

static func frilled_shark_catalogue() -> Array:
	return FRILLED_SHARK.duplicate(true)

# Bomb Bot: first-pass kit (no numeric sheet supplied). Single-target moves are weighted higher.
# The FBX misspells `LightingBlast`; keep the typo only in `clip`.
const BOMB_BOT := [
	{
		"id": "lightning_blast", "name": "Lightning Blast", "clip": "lightingblast",
		"enabled": true, "target": "all", "roll_order": 0, "weight": 0.25,
		"finisher_weight": 0.15, "verb": "electrifies",
		"combat": {"formula": {"strength": 1}, "acc_mod": 1},
	},
	{
		"id": "sling_punch", "name": "Sling Punch", "clip": "slingpunch",
		"enabled": true, "target": "single", "roll_order": 1, "weight": 0.45,
		"finisher_weight": 0.60, "verb": "slams",
		"combat": {"formula": {"strength": 1, "defense": 1}, "acc_mod": 0},
	},
	{
		"id": "sonic_bump", "name": "Sonic Bump", "clip": "sonic_bump",
		"enabled": true, "target": "single", "roll_order": 2, "weight": 0.30,
		"finisher_weight": 0.25, "verb": "disorients",
		"combat": {
			"formula": {"strength": 1}, "acc_mod": 1,
			"effects": [
				{"kind": "status", "status": "blindness", "level": {"flat": 1}, "duration": {"flat": 1}},
			],
		},
	},
]

static func bomb_bot_catalogue() -> Array:
	return BOMB_BOT.duplicate(true)
