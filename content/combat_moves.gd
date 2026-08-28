class_name CombatMoves
extends RefCounted

# Group_StatsV2's first complete playable kit. Formulas are data rather than
# branches in Battle: each coefficient multiplies the named stat on whoever
# uses the move, which lets the same definition work for a diver or an enemy.
const SCUBA := [
	{
		"name": "Electric Touch", "formula": {"strength": 1},
		"target": "one_enemy", "effects": [
			{"kind": "reduce_evasion", "amount": {"accuracy": 1}},
		],
		"hint": "1 STR damage; strips EVA by ACC",
		"text": "Electric Touch shocks the target",
	},
	{
		"name": "Scuba Stabbing", "formula": {"strength": 1},
		"target": "one_enemy", "effects": [
			{"kind": "status", "status": "bleed", "level": {"flat": 1, "strength": 1}},
		],
		"hint": "1 STR damage; applies 1 + STR Bleed",
		"text": "Scuba Stabbing opens a wound",
	},
	{
		"name": "Flash Blast", "formula": {},
		"target": "all_enemies", "effects": [
			{"kind": "status", "status": "blindness", "level": {"flat": 2}, "duration": {"accuracy": 1}},
		],
		"hint": "All foes; Blindness 2 for ACC turns",
		"text": "Flash Blast blinds the enemy line",
	},
	{
		"name": "Multiple Knee Combo", "formula": {"strength": 1},
		"target": "all_enemies", "effects": [
			{"kind": "self_temporary", "accuracy": -1, "evasion": -1},
		],
		"hint": "All foes; -1 ACC/EVA until next turn",
		"text": "Multiple Knee Combo sweeps the enemy line",
	},
	{
		"name": "Axe Kick", "formula": {"strength": 1, "accuracy": 1},
		"target": "one_enemy", "effects": [
			{"kind": "self_temporary", "evasion": -3},
		],
		"hint": "STR + ACC damage; -3 EVA until next turn",
		"text": "Axe Kick crashes down",
	},
]

static func for_model(model_name: String) -> Array:
	return SCUBA if model_name == "Staff_Diver" else []

