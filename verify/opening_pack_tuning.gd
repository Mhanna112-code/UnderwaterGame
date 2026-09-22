# Captured opening-formation contract. A party learning the mixed roster sees
# a material but minority chance of two enemies; the three-enemy formation is
# deliberately held until level 3. This calls Battle's public roll helper,
# the same method _build_stage() uses for ordinary encounters.
# Usage: godot --headless --path . --script verify/opening_pack_tuning.gd
extends SceneTree

var findings: Array[String] = []

func _init() -> void:
	_expect(Battle.ordinary_enemy_count_for_roll(1, 0.00) == 2,
		"OPENING PACK: a low level-1 roll did not retain the two-enemy challenge")
	_expect(Battle.ordinary_enemy_count_for_roll(1, Battle.OPENING_TWO_ENEMY_CHANCE - 0.001) == 2,
		"OPENING PACK: lower bound of the two-enemy band drifted")
	_expect(Battle.ordinary_enemy_count_for_roll(1, Battle.OPENING_TWO_ENEMY_CHANCE) == 1,
		"OPENING PACK: the solo majority does not begin at its documented boundary")
	_expect(Battle.ordinary_enemy_count_for_roll(2, 0.999) == 1,
		"OPENING PACK: level 2 unexpectedly unlocked three-enemy pressure")
	_expect(Battle.ordinary_enemy_count_for_roll(3, 0.01) == 1,
		"OPENING PACK: level 3 lost its low-roll solo formation")
	_expect(Battle.ordinary_enemy_count_for_roll(3, 0.40) == 2,
		"OPENING PACK: level 3 lost its middle two-enemy formation")
	_expect(Battle.ordinary_enemy_count_for_roll(3, 0.80) == 3,
		"OPENING PACK: level 3 did not unlock the three-enemy formation")
	_expect(Battle.ordinary_enemy_count_for_roll(99, 0.99, true) == 1,
		"OPENING PACK: a guardian stopped being a one-enemy encounter")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("opening pack tuning  solo-majority opening and level-3 three-pack clean")
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, finding: String) -> void:
	if not condition:
		findings.append(finding)
