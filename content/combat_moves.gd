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
			# Bleed used to have no duration at all (persisted until the
			# fight ended). Capped at 3 turns to match Poison's own
			# duration - one shared "DoTs last 3 turns" rule instead of two
			# different expiry stories for the player to track. Repeat hits
			# still only stack the level, never reset this clock - see
			# CombatantStats.add_status()'s own bleed-specific branch.
			{"kind": "status", "status": "bleed", "level": {"flat": 1, "strength": 1}, "duration": 3},
		],
		"hint": "1 STR damage; applies 1 + STR Bleed",
		"text": "Scuba Stabbing opens a wound",
	},
	{
		"name": "Flash Blast", "formula": {},
		"target": "all_enemies", "effects": [
			{"kind": "status", "status": "blindness", "level": {"flat": 2}, "duration": {"accuracy": 1}},
			# Multiple Knee Combo (below) is the only other all-enemies move
			# in this kit, and it already pays a self_temporary cost for
			# hitting everyone at once - Flash Blast had none at all despite
			# a stronger, longer-lasting payoff (three stats down for
			# several turns, vs. two stats down for one), so recasting it
			# right as it expired was a free, essentially risk-free loop.
			# Matched to Multiple Knee Combo's own -1/-1 rather than set
			# higher, since Flash Blast already costs its own turn and deals
			# no damage - the point is a real tradeoff each cast, not making
			# the move not worth using at all.
			{"kind": "self_temporary", "accuracy": -1, "evasion": -1},
		],
		"hint": "All foes; Blindness 2 for ACC turns; -1 ACC/EVA for 1 turn",
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
		return _resolved_legacy_hint(stats, move)
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
				# "Status Effect" is intentional wording, not just flavor -
				# it's the visible cue a status-inflicting move carries one
				# (the hover tooltip itself is attached by move data, not by
				# parsing this string - see battle.gd's _move_tooltip_text()).
				# Duration is deliberately left off here: the fixed-width
				# move button has no room for "Status Effect: 2 Bleed for 3
				# turns" without clipping, and the exact number is already
				# one hover away in that same tooltip.
				var level := CombatRules.formula_value(stats, effect.get("level", {}))
				parts.append("Status Effect: %d %s" % [level, String(effect.get("status", "Effect")).capitalize()])
			"self_temporary":
				# "for 1 turn" dropped from here - self_temporary is always
				# exactly 1 turn by design, never variable, so it's constant
				# filler on the button. Fine alone (Axe Kick/Multiple Knee
				# Combo already fit either way), but combined with a
				# "status" line on the same move (Flash Blast) the two
				# together ran well past the button's width. The duration
				# itself isn't lost - it's in the "Self Cost" hover tooltip
				# (see TutorialContent.EFFECT_KIND_EXPLANATIONS).
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
	return " • ".join(parts)

# Prototype_1/Prototype_V's legacy power/debuff kits never had a "Show
# formulas" toggle to fall back on for a numeric preview - now that that
# control is gone entirely (removed, not just hidden), the default view has
# to be complete on its own here too, not just for the formula-based Scuba
# moves above. Mirrors _preview_raw_power()'s own power+Strength math and
# Battle._apply_debuff()'s flat amount, so the number shown here always
# matches what the move badge/actual hit will do. The authored flavor
# `hint` (accuracy/weight feel a bare number can't convey, e.g. "Very heavy,
# slow") is kept as a trailing detail rather than dropped.
static func _resolved_legacy_hint(stats: CombatantStats, move: Dictionary) -> String:
	var parts: Array[String] = []
	var debuff := String(move.get("debuff", ""))
	if debuff != "":
		parts.append("%s -%d" % [debuff.left(3).to_upper(), int(move.get("amount", 0))])
	elif int(move.get("power", 0)) > 0:
		parts.append("%d Damage" % (int(move.power) + stats.strength))
	var flavor := String(move.get("hint", ""))
	if flavor != "":
		parts.append(flavor)
	return " • ".join(parts)
