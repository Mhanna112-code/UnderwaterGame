extends SceneTree
var findings: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var battle := Battle.new()
	var divers: Array[Diver] = []
	var spells: Array[String] = []
	var owner := Diver.new()
	owner.model_name = "Staff_Diver"
	root.add_child(owner)
	divers.append(owner)
	for branch in SpellTree.tree_for(owner.model_name).values():
		for id in branch:
			spells.append(String(id))
	battle.party_source = divers
	for count in [0, ceili(float(spells.size()) * 0.5), spells.size()]:
		owner.known_spells.assign(spells.slice(0, count))
		var expected := Battle.UNLOCK_BONUS_SOME if count == 0 else (Battle.UNLOCK_BONUS_ALL if count == spells.size() else Battle.UNLOCK_BONUS_HALF)
		if not is_equal_approx(battle._unlock_bonus(), expected):
			findings.append("SCALE-1 wrong learned tier")
		var stats := CombatantStats.new()
		stats.hp_max = 100
		stats.strength = 100
		stats.evasion = 7
		battle._with_unlock_bonus(stats)
		if stats.hp_max != roundi(100.0 * (1.0 + expected)) or stats.strength != stats.hp_max or stats.evasion != 7 or stats.hp != stats.hp_max:
			findings.append("SCALE-1 wrong rounding/EVA/fill")
	battle.tutorial_encounter = true
	var untouched := CombatantStats.new()
	untouched.hp_max = 100
	battle._with_unlock_bonus(untouched)
	if untouched.hp_max != 100:
		findings.append("SCALE-1 tutorial scaled")
	battle.free()
	owner.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC UNLOCK SCALING: clean" if findings.is_empty() else "MARC UNLOCK SCALING: findings")
	quit(0 if findings.is_empty() else 1)
