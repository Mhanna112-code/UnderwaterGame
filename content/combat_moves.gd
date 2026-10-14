class_name CombatMoves
extends RefCounted

# Player kit. Formula coefficients multiply the user's named stats, so moves work for divers or enemies.
const SCUBA := [
	{
		"name": "Electric Touch", "formula": {"strength": 1},
		"target": "one_enemy", "effects": [
			# Flat -1 Evasion on hit.
			{"kind": "reduce_evasion", "amount": {"flat": 1}},
		],
		"hint": "1 STR damage; lowers EVA by 1",
		"text": "Electric Touch shocks the target",
	},
	{
		"name": "Scuba Stabbing", "formula": {"strength": 1},
		"target": "one_enemy", "effects": [
			# Bleed lasts the whole battle; only another Bleed move adds to it (cap 10). Poison is timed.
			{"kind": "status", "status": "bleed", "level": {"flat": 1}},
		],
		"hint": "1 STR damage; applies 1 Bleed",
		"text": "Scuba Stabbing opens a wound",
	},
	{
		"name": "Flash Blast", "formula": {},
		"target": "all_enemies", "effects": [
			{"kind": "status", "status": "blindness", "level": {"flat": 2}, "duration": {"accuracy": 1}},
			# Self cost matches Multiple Knee Combo so recasting isn't a free loop.
			{"kind": "self_temporary", "accuracy": -1, "evasion": -1},
		],
		"hint": "All foes; Blindness 2 for ACC turns; -1 ACC/EVA for 1 turn",
		"text": "Flash Blast blinds the enemy line",
	},
	{
		"name": "Multiple Knee Combo", "formula": {"strength": 1},
		"target": "all_enemies", "effects": [
			{"kind": "self_temporary", "evasion": -1},
		],
		"hint": "All foes; -1 EVA for 1 turn",
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
# Button text is result-first: formulas resolved against the actor. Damage is pre-mitigation.
static func resolved_hint(stats: CombatantStats, move: Dictionary) -> String:
	if not move.has("formula"):
		return _resolved_legacy_hint(stats, move)
	var parts: Array[String] = []
	var has_status := false
	var damage := CombatRules.formula_value(stats, move.get("formula", {}))
	if damage > 0:
		# Names the driving stat instead of a turn-dependent number; details are in the tooltip.
		parts.append("Strength Damage%s" % (" all" if String(move.get("target", "")) == "all_enemies" else ""))
	for effect_value in move.get("effects", []):
		var effect := effect_value as Dictionary
		match String(effect.get("kind", "")):
			"reduce_evasion":
				# Target Evasion loss lives in the tooltip; red "STAT -N" on a button means self cost.
				pass
			"status":
				# Duration omitted to fit the fixed-width button; it's in the tooltip.
				has_status = true
				var level := CombatRules.formula_value(stats, effect.get("level", {}))
				parts.append("%d %s" % [level, String(effect.get("status", "Effect")).capitalize()])
			"self_temporary":
				# Self cost is dropped when the move also has a status (Flash Blast) so the button doesn't clip.
				if has_status:
					continue
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
					parts.append(" / ".join(costs))
	return "  ".join(parts)

# Legacy kits: the button shows the flavor `hint`. Target debuffs aren't shown (red "STAT -N" = self cost).
static func _resolved_legacy_hint(_stats: CombatantStats, move: Dictionary) -> String:
	var parts: Array[String] = []
	var flavor := String(move.get("hint", ""))
	if flavor != "":
		parts.append(flavor)
	return "  ".join(parts)
