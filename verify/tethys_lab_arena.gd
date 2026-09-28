# Tethys's room is visual stage geometry, so the important verification is
# composition with Battle's real actor positions—not a unit test that merely
# counts nodes on an isolated room.
extends SceneTree

var findings: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var direct := TethysLabArena.new()
	root.add_child(direct)
	await process_frame
	_expect(direct.get_node_or_null("TallCeilingShell") != null,
		"LAB SHELL MISSING: the delivered tall-ceiling FBX was not instantiated")
	var collision_count := 0
	for node in direct.find_children("*", "CollisionShape3D", true, false):
		if node is CollisionShape3D and (node as CollisionShape3D).shape is BoxShape3D:
			collision_count += 1
	_expect(collision_count == 6,
		"LAB BOUNDARIES INCOMPLETE: expected floor, ceiling, and four walls; found %d box collisions" % collision_count)
	_expect(not direct.contains_combatant(Vector3.ZERO, 0.5, TethysLabArena.INTERIOR_SIZE.y + 0.01),
		"LAB CEILING OPEN: an actor taller than the room still fits")
	direct.queue_free()

	var battle := Battle.new()
	battle.boss_encounter = true
	battle.boss_intro_enabled = false
	root.add_child(battle)
	for _frame in 4:
		await process_frame
	var arena := battle._stage_vp.get_node_or_null("TethysLabArena") as TethysLabArena
	_expect(arena != null,
		"BOSS STAGE MISSING ROOM: Tethys battle did not install the tall-ceiling arena")
	if arena != null:
		for entry in battle.party + battle.enemies:
			if not entry.has("actor") or not is_instance_valid(entry.actor):
				continue
			var actor := entry.actor as Node3D
			var foot_offset := float(actor.call("foot_offset")) if actor.has_method("foot_offset") else 0.0
			_expect(is_zero_approx(actor.position.y + foot_offset),
				"LAB FLOOR CLIP: %s's visible feet are at y=%.3f instead of the room floor" % [String(entry.display_name), actor.position.y + foot_offset])
			var radius := maxf(0.0, float(actor.get("radius")))
			var height := maxf(0.0, float(actor.get("height")))
			_expect(arena.contains_combatant(actor.position, radius, height),
				"LAB FORMATION OUT OF BOUNDS: %s at %s (radius %.2f, height %.2f) does not fit the boss room" % [String(entry.display_name), actor.position, radius, height])
		var boss_entry := battle.enemies[0] as Dictionary if not battle.enemies.is_empty() else {}
		if boss_entry.has("actor"):
			for entry in battle.party:
				if not entry.has("actor"):
					continue
				var actor := entry.actor as Node3D
				var toward := (boss_entry.actor as Node3D).position - actor.position
				var stand := (boss_entry.actor as Node3D).position - toward.normalized() * (Battle.SWING_REACH + float((boss_entry.actor as Node3D).get("radius")))
				stand.y = actor.position.y
				_expect(arena.contains_combatant(stand, maxf(0.0, float(actor.get("radius"))), maxf(0.0, float(actor.get("height")))),
					"LAB ATTACK LANE OUT OF BOUNDS: %s's normal swing position %s leaves the room" % [String(entry.display_name), stand])
	battle.queue_free()
	await process_frame
	var ordinary := Battle.new()
	ordinary.tutorial_encounter = true
	root.add_child(ordinary)
	for _frame in 3:
		await process_frame
	_expect(ordinary._stage_vp.get_node_or_null("TethysLabArena") == null,
		"ROOM LEAKED: an ordinary encounter installed Tethys's lab arena")
	ordinary.queue_free()
	await process_frame
	if findings.is_empty():
		print("TETHYS LAB ARENA: clean — delivered shell, six boundaries, party, boss, and all party swing lanes fit")
		quit(0)
		return
	for finding in findings:
		print("FINDING  ", finding)
	print("TETHYS LAB ARENA: %d finding(s)" % findings.size())
	quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
