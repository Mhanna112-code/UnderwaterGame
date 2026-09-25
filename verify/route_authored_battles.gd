# `progression route: every declared encounter builds its exact roster —
# guards against ordinary pack rolls leaking into authored progression`.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for beat_value in RouteProgression.BEATS:
		var beat := beat_value as Dictionary
		var roster := beat.get("roster", []) as Array
		var battle := Battle.new()
		battle.forced_enemy_ids = roster.duplicate()
		battle.boss_encounter = bool(beat.get("boss", false))
		root.add_child(battle)
		await process_frame
		await process_frame
		var actual: Array[String] = []
		for entry_value in battle.enemies:
			var entry := entry_value as Dictionary
			var actor: Variant = entry.get("actor")
			if actor is Goblin:
				actual.append((actor as Goblin).enemy_id())
			elif actor is TethysBoss:
				actual.append("tethys")
			else:
				actual.append("missing")
		_expect(actual == roster,
			"AUTHORED ROSTER: %s built %s, expected %s" % [String(beat.id), actual, roster])
		battle.queue_free()
		await process_frame

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("route authored battles  all declared route rosters built exactly")
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
