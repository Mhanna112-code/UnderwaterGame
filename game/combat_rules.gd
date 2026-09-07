class_name CombatRules
extends RefCounted

# Resolves a Group_StatsV2 move without knowing whether its wielder is a
# player or enemy. The UI, animations and AI choose a move; this class owns
# the shared arithmetic and mutations.
static func resolve(attacker: CombatantStats, defender: CombatantStats, move: Dictionary, apply_self_effects: bool = true) -> Dictionary:
	if apply_self_effects:
		_apply_self_effects(attacker, move)

	var accuracy := attacker.effective_accuracy() + int(move.get("acc_mod", 0))
	if accuracy <= defender.evasion_current:
		var spent := defender.spend_evasion(accuracy)
		return _result(false, 0, spent)

	var had_bleed := defender.status_level("bleed") > 0
	var raw := formula_value(attacker, move.get("formula", {}))
	var defense := defender.effective_defense()
	var damage := 0
	if raw > 0:
		var difference := defense - raw
		damage = 0 if difference > 5 else maxi(1, raw - defense)
		defender.hp = maxi(0, defender.hp - damage)
		# Once bleeding, every later damaging hit adds another stack.
		if had_bleed and damage > 0:
			defender.add_status("bleed", 1, 0)

	var applied: Array[String] = []
	for effect in move.get("effects", []):
		var kind := String(effect.get("kind", ""))
		if kind == "self_temporary":
			continue
		if kind == "reduce_evasion":
			var amount := formula_value(attacker, effect.get("amount", {}))
			defender.reduce_evasion(amount)
			applied.append("EVA -%d" % amount)
		elif kind == "status":
			var status := String(effect.get("status", ""))
			var level := formula_value(attacker, effect.get("level", {}))
			var duration := formula_value(attacker, effect.get("duration", {}))
			defender.add_status(status, level, duration)
			applied.append(_status_text(status, level, duration))

	var result := _result(true, damage, 0)
	result.effects = applied
	return result

static func formula_value(wielder: CombatantStats, formula: Variant) -> int:
	if not formula is Dictionary:
		return int(formula)
	var data := formula as Dictionary
	return (
		int(data.get("flat", 0))
		+ wielder.strength * int(data.get("strength", 0))
		+ wielder.effective_defense() * int(data.get("defense", 0))
		+ wielder.effective_agility() * int(data.get("agility", 0))
		+ wielder.effective_evasion() * int(data.get("evasion", 0))
		+ wielder.effective_accuracy() * int(data.get("accuracy", 0))
	)

static func _apply_self_effects(attacker: CombatantStats, move: Dictionary) -> void:
	for effect in move.get("effects", []):
		if String(effect.get("kind", "")) != "self_temporary":
			continue
		attacker.add_temporary_modifier("accuracy", int(effect.get("accuracy", 0)))
		attacker.add_temporary_modifier("evasion", int(effect.get("evasion", 0)))

static func _result(hit: bool, damage: int, evasion_spent: int) -> Dictionary:
	return {
		"hit": hit, "damage": damage, "absorbed": 0, "debuff": "",
		"changed": 0, "dodged": false, "evasion_spent": evasion_spent,
		"effects": [],
	}

static func _status_text(status: String, level: int, duration: int) -> String:
	var label := status.capitalize() + " %d" % level
	return label if duration <= 0 else "%s (%d turns)" % [label, duration]
