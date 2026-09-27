class_name CombatMoves
extends RefCounted

# Group_StatsV2's first complete playable kit. Formulas are data rather than
# branches in Battle: each coefficient multiplies the named stat on whoever
# uses the move, which lets the same definition work for a diver or an enemy.
const SCUBA := [
	{
		# Scuba's 3 Accuracy is deliberately one point below Swordfish's
		# authored 4 Evasion. The shock is the dedicated counter move, so its
		# small reliability bonus lets the listed EVA reduction actually land
		# instead of asking the player to first waste a turn on an unrelated
		# miss that merely drains the transient evasion pool.
		"name": "Electric Touch", "formula": {"strength": 1}, "acc_mod": 2,
		"target": "one_enemy", "effects": [
			{"kind": "reduce_evasion", "amount": {"accuracy": 1}},
		],
		"hint": "Reliable shock; strips EVA by ACC",
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
		"hint": "All foes; -1 ACC/EVA for 1 turn",
		"text": "Multiple Knee Combo sweeps the enemy line",
	},
	{
		"name": "Axe Kick", "formula": {"strength": 1, "accuracy": 1},
		"target": "one_enemy", "effects": [
			{"kind": "self_temporary", "evasion": -3},
		],
		"hint": "STR + ACC damage; -3 EVA for 1 turn",
		"text": "Axe Kick crashes down",
	},
]

static func for_model(model_name: String) -> Array:
	return SCUBA if model_name == "Staff_Diver" else []
# The move table keeps formulas because the rules need them, but Glassgoat's
# player-facing contract is result-first: resolve those symbols against the
# acting character before putting them on an ordinary choice button. Target
# defense is not known until the next screen, so "Damage" here is the move's
# authored output before the selected target mitigates it.
static func resolved_hint(stats: CombatantStats, move: Dictionary) -> String:
	if not move.has("formula"):
		return String(move.get("hint", ""))
	var parts: Array[String] = []
	var damage := CombatRules.formula_value(stats, move.get("formula", {}))
	if damage > 0:
		parts.append("%d Damage%s" % [damage, " all" if String(move.get("target", "")) == "all_enemies" else ""])
	for effect_value in move.get("effects", []):
		var effect := effect_value as Dictionary
		match String(effect.get("kind", "")):
			"reduce_evasion":
				parts.append("EVA -%d" % CombatRules.formula_value(stats, effect.get("amount", {})))
			"status":
				var level := CombatRules.formula_value(stats, effect.get("level", {}))
				var duration := CombatRules.formula_value(stats, effect.get("duration", {}))
				var label := "%d %s" % [level, String(effect.get("status", "Effect")).capitalize()]
				if duration > 0:
					label += " for %d turns" % duration
				parts.append(label)
			"self_temporary":
				var costs: Array[String] = []
				var accuracy := int(effect.get("accuracy", 0))
				var evasion := int(effect.get("evasion", 0))
				if accuracy != 0 and accuracy == evasion:
					costs.append("ACC/EVA %s%d" % ["+" if accuracy > 0 else "", accuracy])
				else:
					for stat in ["accuracy", "evasion"]:
						var amount := int(effect.get(stat, 0))
						if amount != 0:
							costs.append("%s %s%d" % [stat.left(3).to_upper(), "+" if amount > 0 else "", amount])
				if not costs.is_empty():
					parts.append("%s for 1 turn" % " / ".join(costs))
	return " • ".join(parts)
