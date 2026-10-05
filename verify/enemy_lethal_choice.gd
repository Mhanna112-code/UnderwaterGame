# Ordinary enemies always take a guaranteed kill and skip divers that their
# own Bleed/Poison will finish.
#
# Bugs caught:
# - LETHAL-01: predicted landed damage drifts from what CombatRules.resolve()
#   actually deals (Evasion pool, ties, multi-hit, self cost, Defense Down).
# - LETHAL-02: a reachable kill is passed over, or a kill that cannot beat the
#   target's current Evasion is treated as guaranteed.
# - LETHAL-03: a diver already doomed by Bleed/Poison is chosen for the kill.
#
# Usage: godot --headless --path . --script verify/enemy_lethal_choice.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _stats(hp: int, strength: int, defense: int, evasion: int, accuracy: int) -> CombatantStats:
	var s := CombatantStats.new()
	s.hp_max = 10
	s.strength = strength
	s.defense = defense
	s.evasion = evasion
	s.accuracy = accuracy
	s.agility = 1
	s.fill()
	s.hp = hp
	return s

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
		print("FINDING  ", message)

func _run() -> void:
	_prediction_matches_resolution()
	_choice_rules()
	print("ENEMY LETHAL CHOICE: clean" if findings.is_empty() else "ENEMY LETHAL CHOICE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

# Every authored ordinary-enemy move against a spread of defenders: the
# prediction must equal the damage the real resolver deals.
func _prediction_matches_resolution() -> void:
	var catalogues := [
		EnemyMoves.angler_catalogue(),
		EnemyMoves.swordfish_duelist_catalogue(),
		EnemyMoves.frilled_shark_catalogue(),
		EnemyMoves.bomb_bot_catalogue(),
	]
	var checked := 0
	for catalogue in catalogues:
		for move_value in catalogue:
			var combat := (move_value as Dictionary).get("combat", {}) as Dictionary
			for defense in [0, 2, 4]:
				for evasion in [0, 2, 3, 5]:
					for accuracy in [1, 3, 5]:
						var attacker := _stats(10, 2, 2, 1, accuracy)
						var defender := _stats(10, 1, defense, evasion, 1)
						var predicted := Battle.predicted_landed_damage(attacker, defender, combat)
						if predicted < 0:
							continue
						var before := defender.hp
						Battle.resolve_formula_hits(attacker, defender, combat)
						_expect(before - defender.hp == predicted,
							"LETHAL-01 %s DEF%d EVA%d ACC%d predicted %d, dealt %d" % [String((move_value as Dictionary).get("name", "?")), defense, evasion, accuracy, predicted, before - defender.hp])
						checked += 1
	_expect(checked > 0, "LETHAL-01 no predictable authored enemy moves were checked")
	print("LETHAL PREDICTIONS|checked=", checked)

func _choice_rules() -> void:
	var slash := {"name": "Slash", "enabled": true, "target": "single", "combat": {"formula": {"strength": 1}, "acc_mod": 1}}
	var attacker := _stats(10, 3, 0, 0, 2)   # Slash: 3 Accuracy, 3 raw damage
	var low := {"display_name": "Low", "stats": _stats(2, 1, 0, 0, 1)}
	var healthy := {"display_name": "Healthy", "stats": _stats(10, 1, 0, 0, 1)}
	var pick := Battle.lethal_enemy_choice(attacker, [slash], [healthy, low])
	_expect(not pick.is_empty() and pick.target == low, "LETHAL-02 reachable kill on a 2 HP diver was not chosen")

	# Accuracy 3 vs Evasion 3 is a tie, and ties go to the defender.
	var evasive := {"display_name": "Evasive", "stats": _stats(2, 1, 0, 3, 1)}
	_expect(Battle.lethal_enemy_choice(attacker, [slash], [evasive]).is_empty(),
		"LETHAL-02 a hit that only ties the target's Evasion was treated as a guaranteed kill")

	var bleeding := {"display_name": "Bleeding", "stats": _stats(2, 1, 0, 0, 1)}
	(bleeding.stats as CombatantStats).add_status("bleed", 2, 0)
	_expect(Battle.doomed_by_damage_over_time(bleeding.stats), "LETHAL-03 2 Bleed on 2 HP was not recognised as doomed")
	_expect(Battle.lethal_enemy_choice(attacker, [slash], [bleeding]).is_empty(),
		"LETHAL-03 a diver Bleed will finish was chosen for the kill")
	var poisoned := {"display_name": "Poisoned", "stats": _stats(1, 1, 0, 0, 1)}
	(poisoned.stats as CombatantStats).add_status("poison", 1, 3)
	pick = Battle.lethal_enemy_choice(attacker, [slash], [poisoned, low])
	_expect(not pick.is_empty() and pick.target == low, "LETHAL-03 kill went to a diver Poison will finish instead of another lethal target")
