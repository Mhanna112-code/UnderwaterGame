# Ordinary encounter pack size: one, two or three enemies with equal odds at
# every level (the old level-1 cap of two was lifted). Guardians stay solo.
# This calls Battle's public roll helper, the same one _build_stage() uses.
# Usage: godot --headless --path . --script verify/opening_pack_tuning.gd
extends SceneTree

var findings: Array[String] = []

func _init() -> void:
	for level in [1, 2, 3, 10]:
		_expect(Battle.ordinary_enemy_count_for_roll(level, 0.01) == 1, "PACK SIZE: level %d low roll is not one enemy" % level)
		_expect(Battle.ordinary_enemy_count_for_roll(level, 0.40) == 2, "PACK SIZE: level %d middle roll is not two enemies" % level)
		_expect(Battle.ordinary_enemy_count_for_roll(level, 0.80) == 3, "PACK SIZE: level %d high roll is not three enemies" % level)
		_expect(Battle.max_enemies_for_level(level) == 3, "PACK SIZE: level %d cap is not three" % level)
	_expect(Battle.ordinary_enemy_count_for_roll(99, 0.99, true) == 1,
		"OPENING PACK: a guardian stopped being a one-enemy encounter")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("opening pack tuning  equal one/two/three packs at every level clean")
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, finding: String) -> void:
	if not condition:
		findings.append(finding)
