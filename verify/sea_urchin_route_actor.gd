# `progression combat: Sea Urchin is a real armored actor with a mechanical
# Weaken payoff — guards against a placeholder model that cannot teach its
# advertised counter`.
extends SceneTree

const UrchinActor = preload("res://game/sea_urchin.gd")

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_swordfish_electric_counter()
	var urchin := UrchinActor.new()
	root.add_child(urchin)
	await process_frame
	await process_frame
	_expect(urchin.enemy_id() == "sea_urchin" and urchin.display_name() == "Sea Urchin",
		"SEA URCHIN IDENTITY: route dispatch did not construct the delivered actor")
	_expect(urchin.get_node_or_null("Model") != null,
		"SEA URCHIN ASSET: delivered FBX did not instantiate on the encounter actor")
	var stats := urchin.make_stats(_stats(99, 9, 9, 9, 9, 9), 1)
	_expect([stats.hp_max, stats.strength, stats.defense, stats.agility, stats.evasion, stats.accuracy] == [8, 1, 4, 1, 0, 1],
		"SEA URCHIN STATS: armored counter target drifted from its explicit 8/1/4/1/0/1 route profile")

	var bucky := _stats(10, 4, 4, 1, 0, 6)
	var guard_bash := {"power": 6, "acc_mod": 4}
	var without_weaken := Battle.apply_damage_roll(bucky, stats, guard_bash, 1.0)
	stats.fill()
	var reduced := stats.reduce_defense(2) # Battle's real legacy Weaken amount.
	var with_weaken := Battle.apply_damage_roll(bucky, stats, guard_bash, 1.0)
	_expect(reduced == 2 and stats.defense == 2,
		"SEA URCHIN COUNTER: Weaken's real -2 DEF did not alter the armored target")
	_expect(int(with_weaken.get("damage", 0)) > int(without_weaken.get("damage", 0)),
		"SEA URCHIN COUNTER: Weaken did not improve actual follow-up damage")
	urchin.queue_free()
	await process_frame
	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("sea urchin route     delivered actor and Weaken payoff hold")
	quit(0 if findings.is_empty() else 1)

func _test_swordfish_electric_counter() -> void:
	var swordfish := SwordDuelist.new()
	var sword_stats := swordfish.make_stats(_stats(99, 9, 9, 9, 9, 9), 1)
	var scuba := _stats(10, 1, 0, 3, 3, 3)
	var electric := (CombatMoves.for_model("Staff_Diver")[0] as Dictionary).duplicate(true)
	var touch := CombatRules.resolve(scuba, sword_stats, electric)
	_expect(bool(touch.get("hit", false)) and sword_stats.evasion == 1,
		"SWORDFISH COUNTER: Electric Touch must land on the 4-EVA Swordfish and lower it by Scuba's 3 ACC")
	var stab := (CombatMoves.for_model("Staff_Diver")[1] as Dictionary).duplicate(true)
	var follow_up := CombatRules.resolve(scuba, sword_stats, stab)
	_expect(bool(follow_up.get("hit", false)),
		"SWORDFISH COUNTER: Electric Touch must turn Scuba's follow-up into a real hit")
	swordfish.free()

func _stats(hp: int, strength: int, defense: int, agility: int, evasion: int, accuracy: int) -> CombatantStats:
	var stats := CombatantStats.new()
	stats.hp_max = hp
	stats.strength = strength
	stats.defense = defense
	stats.agility = agility
	stats.evasion = evasion
	stats.accuracy = accuracy
	stats.fill()
	return stats

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
