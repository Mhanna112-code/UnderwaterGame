# REVEAL-02: actual Battle preserves preselected packs across species/counts.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var diver := Diver.new()
	diver.model_name = "Staff_Diver"
	root.add_child(diver)
	var findings: Array[String] = []
	var cases := 0
	for level in [1, 2, 3, 6]:
		for sample in range(8):
			diver.stats.level = level
			var selected := Battle.select_ordinary_enemies(level)
			if selected.is_empty() or selected.size() > 3 or (level == 1 and selected.size() > 2) or (level == 2 and selected.size() != 1):
				findings.append("REVEAL-02 selected roster changes authored formation bands at level %s: %s" % [level, selected])
			var fight := Battle.new()
			fight.party_source = [diver]
			fight.ordinary_enemy_ids = selected.duplicate()
			root.add_child(fight)
			var actual: Array[String] = []
			for enemy in fight.enemies:
				actual.append(enemy.actor.enemy_id())
			if selected != actual:
				findings.append("REVEAL-02 selected %s / fought %s" % [selected, actual])
			cases += 1
			fight.queue_free()
			await process_frame
	for finding in findings:
		push_error(finding)
	diver.queue_free()
	root.get_node("GameAudio").release_streams_for_shutdown()
	await process_frame
	print("RANDOM REVEAL ROSTER: ", cases, " real Battles: ", "PASS" if findings.is_empty() else "FAIL")
	quit(0 if findings.is_empty() else 1)
