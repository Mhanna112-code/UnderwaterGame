extends SceneTree
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var enemy := Goblin.new()
	var reference := CombatantStats.new()
	var legacy := OS.get_cmdline_user_args().has("--legacy-enemy-scaling")
	for sample in 96:
		seed(72101 + sample)
		reference.evasion = sample % 31
		reference.hp_max = 30 + sample
		reference.strength = 7
		reference.defense = 6
		reference.agility = 9
		reference.accuracy = 11
		var stats := enemy.make_stats(reference, 2)
		if legacy:
			if stats.evasion != maxi(2, reference.evasion):
				findings.append("FOLLOW-2 legacy factory boosted EVA at sample %d: got %d expected %d" % [sample, stats.evasion, maxi(2, reference.evasion)])
		else:
			for field in ["hp_max", "strength", "defense", "agility", "accuracy"]:
				var base_value := 5 if field == "hp_max" else (3 if field == "accuracy" else (0 if field == "defense" else 2))
				var value := int(stats.get(field))
				if value < roundi(base_value * 1.05) or value > roundi(base_value * 1.10):
					findings.append("FOLLOW-1 ordinary %s outside 5-10 percent range at sample %d: %d" % [field, sample, value])
			if stats.evasion != 1 or stats.evasion_current != 1:
				findings.append("FOLLOW-2 ordinary factory changed authored EVA")
		if stats.hp != stats.hp_max or stats.oxygen != stats.oxygen_max:
			findings.append("FOLLOW-1 new enemy did not start with full resources")
	# Authored species overrides remain unscaled by the shared random factory.
	for actor in [SwordDuelist.new(), FrilledShark.new()]:
		var expected: Array = [8, 2, 1, 6, 4, 3] if actor is SwordDuelist else [5, 2, 2, 1, 2, 2]
		var stats: CombatantStats = actor.make_stats(reference, 2)
		var actual := [stats.hp_max, stats.strength, stats.defense, stats.agility, stats.evasion, stats.accuracy]
		if actual != expected:
			findings.append("FOLLOW-1 unrelated authored species balance changed")
		actor.free()
	enemy.free()
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings.slice(0, 8):
		print("FINDING ", finding)
	print("MARC ENEMY BOOSTS: clean|legacy=%s|samples=96" % legacy if findings.is_empty() else "MARC ENEMY BOOSTS: findings=%d" % findings.size())
	quit(0 if findings.is_empty() else 1)
