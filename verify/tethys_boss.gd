extends SceneTree

var findings: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var boss := TethysBoss.new()
	root.add_child(boss)
	await process_frame
	await process_frame

	_expect(boss.height >= 3.5, "BOSS SHRUNK: measured height is %.2f, expected a massive final boss" % boss.height)
	_expect(boss.radius >= 0.8, "BOSS TOO NARROW: measured radius is %.2f" % boss.radius)

	var required := [
		"idle", "swim_start", "swim_loop", "swim_end", "poison_breath",
		"spinning_death", "double_cratch", "tail_slam", "tail_sweep",
		"strong_hit", "weak_hit", "death", "tongue_slayer",
	]
	for key in required:
		_expect(boss.has_clip(String(key)), "MISSING CLIP: %s" % key)

	if boss.has_clip("idle"):
		var idle := boss.anim.get_animation(boss.clip_name("idle"))
		_expect(idle != null and idle.loop_mode == Animation.LOOP_LINEAR, "IDLE DOES NOT LOOP")
	if boss.has_clip("swim_loop"):
		var swim := boss.anim.get_animation(boss.clip_name("swim_loop"))
		_expect(swim != null and swim.loop_mode == Animation.LOOP_LINEAR, "SWIM LOOP DOES NOT LOOP")

	var move_by_id: Dictionary = {}
	for move_value in TethysBoss.MOVES:
		var move := move_value as Dictionary
		move_by_id[String(move.id)] = move
		_expect(boss.has_clip(String(move.clip)), "MOVE WITHOUT ANIMATION: %s -> %s" % [move.id, move.clip])
	_expect(int((move_by_id.double_scratch as Dictionary).hits) == 2,
		"DOUBLE SCRATCH: must attack twice to pressure the evasion pool")
	_expect(String((move_by_id.tail_sweep as Dictionary).target) == "all" and bool((move_by_id.tail_sweep as Dictionary).ignore_defense),
		"TAIL SWEEP: must hit the party and counter armour")
	_expect(String((move_by_id.poison_breath as Dictionary).target) == "all" and int((move_by_id.poison_breath as Dictionary).poison) > 0,
		"POISON BREATH: must poison the whole party")

	var material_count := 0
	var red_count := 0
	for mesh_value in _meshes(boss):
		var mesh := mesh_value as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface)
			if material is BaseMaterial3D:
				material_count += 1
				var color := (material as BaseMaterial3D).albedo_color
				if color.r > color.g * 1.5 and color.r > color.b * 1.3:
					red_count += 1
	_expect(material_count > 0 and red_count == material_count,
		"WHITE DELIVERY LEAKED THROUGH: %d/%d rendered materials are red" % [red_count, material_count])

	var poison_target := CombatantStats.new()
	poison_target.hp_max = 20
	poison_target.fill()
	poison_target.add_status("poison", 2, 3)
	var poison_tick := poison_target.end_turn()
	_expect(int(poison_tick.poison_damage) == 2 and poison_target.hp == 18 and poison_target.status_turns("poison") == 2,
		"POISON TICK: expected 2 damage and two turns remaining")

	var battle := Battle.new()
	battle.boss_encounter = true
	battle.boss_intro_enabled = false
	root.add_child(battle)
	await process_frame
	await process_frame
	_expect(battle.enemies.size() == 1, "BOSS ENCOUNTER: expected exactly one enemy, got %d" % battle.enemies.size())
	if battle.enemies.size() == 1:
		_expect(battle.enemies[0].actor is TethysBoss, "BOSS ENCOUNTER: enemy is not Tethys")
		_expect(String(battle.enemies[0].display_name) == "Tethys", "BOSS ENCOUNTER: canonical display name is missing")
	_expect(battle.enemies.all(func(entry: Dictionary) -> bool: return not (entry.actor is Goblin)),
		"BOSS ENCOUNTER: Mermaid Freak incorrectly replaced/added a grunt")

	# Exercise the production enemy-turn path for all six moves. Inflate HP
	# only inside this gate so the party survives long enough to observe the
	# complete deterministic animation cycle.
	var started_clips: Array[String] = []
	var battle_boss := battle.enemies[0].actor as TethysBoss
	battle_boss.anim.animation_started.connect(func(name: StringName) -> void: started_clips.append(String(name)))
	(battle.enemies[0].stats as CombatantStats).accuracy = 99
	for entry in battle.party:
		var stats := entry.stats as CombatantStats
		stats.hp_max = 500
		stats.hp = 500
		stats.evasion = 0
		stats.evasion_current = 0
	var hp_before_double := _party_hp(battle.party)
	await battle._do_boss_turn(battle.enemies[0], battle.party)
	_expect(hp_before_double - _party_hp(battle.party) > 0, "DOUBLE SCRATCH TURN: production path dealt no damage")
	var hp_before_sweep: Array[int] = _party_hps(battle.party)
	await battle._do_boss_turn(battle.enemies[0], battle.party)
	var hp_after_sweep: Array[int] = _party_hps(battle.party)
	_expect(range(battle.party.size()).all(func(i: int) -> bool: return hp_after_sweep[i] < hp_before_sweep[i]),
		"TAIL SWEEP TURN: did not damage every party member")
	await battle._do_boss_turn(battle.enemies[0], battle.party)
	_expect(battle.party.all(func(entry: Dictionary) -> bool: return (entry.stats as CombatantStats).status_level("poison") > 0),
		"POISON BREATH TURN: did not poison every party member")
	for _remaining in range(3):
		await battle._do_boss_turn(battle.enemies[0], battle.party)
	for move_value in TethysBoss.MOVES:
		var move := move_value as Dictionary
		var clip := battle_boss.clip_name(String(move.clip))
		_expect(started_clips.has(clip), "PRODUCTION TURN NEVER PLAYED: %s (%s)" % [move.name, clip])

	battle.queue_free()
	boss.queue_free()
	await process_frame
	if findings.is_empty():
		print("TETHYS BOSS: clean — native scale, red validation material, 13 required clips, six moves, isolated encounter")
		quit(0)
		return
	for finding in findings:
		print("FINDING  %s" % finding)
	print("TETHYS BOSS: %d finding(s)" % findings.size())
	quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out

func _party_hp(entries: Array) -> int:
	var total := 0
	for entry in entries:
		total += (entry.stats as CombatantStats).hp
	return total

func _party_hps(entries: Array) -> Array[int]:
	var out: Array[int] = []
	for entry in entries:
		out.append((entry.stats as CombatantStats).hp)
	return out
