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

	# Tethys: classify the import as thirteen character motions plus four
	# explicitly excluded base/helper takes — guards against overclaiming all
	# seventeen raw AnimationPlayer entries as usable character animation.
	var gameplay_clips: Array[String] = []
	for key in required:
		if boss.has_clip(String(key)):
			gameplay_clips.append(boss.clip_name(String(key)))
	var imported_clips: Array = boss.anim.get_animation_list()
	var excluded_clips: Array = imported_clips.filter(
		func(clip: StringName) -> bool: return not gameplay_clips.has(String(clip)))
	var expected_excluded := [
		"Aquaticus_rig|Base_pose", "Aquaticus_rig|CameraAction",
		"Aquaticus_rig|LightAction", "Aquaticus_rig|Plane_032Action",
	]
	_expect(imported_clips.size() == 17,
		"RAW TAKE INVENTORY: expected the delivered 17 takes, imported %d" % imported_clips.size())
	_expect(excluded_clips.size() == expected_excluded.size(),
		"TAKE CLASSIFICATION: expected four base/helper takes, observed %s" % str(excluded_clips))
	for clip in expected_excluded:
		_expect(excluded_clips.has(clip),
			"HELPER MISCLASSIFIED: expected '%s' outside the thirteen gameplay motions" % clip)

	# Tethys: every gameplay take changes at least one skeleton bone — guards
	# against a non-humanoid import producing valid names and a rigid model.
	var skeleton := _find_skeleton(boss)
	var skeleton_bone_count := skeleton.get_bone_count() if skeleton != null else 0
	_expect(skeleton != null, "NO DRIVEN SKELETON: the non-humanoid rig has nothing for its clips to deform")
	if skeleton != null:
		var pose_signatures: Dictionary = {}
		for key in required:
			if not boss.has_clip(String(key)):
				continue
			var movement: Dictionary = await _measure_clip_deformation(boss, skeleton, String(key))
			_expect(bool(movement.changed),
				"STATIC NON-HUMANOID CLIP: %s started but moved none of %d bones (max delta %.6f)" % [
					key, skeleton.get_bone_count(), float(movement.max_delta)])
			pose_signatures[String(key)] = movement.pose
		# Tethys: no two named motions may resolve to the same sampled pose —
		# guards against an FBX export/action assignment error duplicating one
		# take under several plausible names.
		for left_index in range(required.size()):
			var left := String(required[left_index])
			if not pose_signatures.has(left):
				continue
			for right_index in range(left_index + 1, required.size()):
				var right := String(required[right_index])
				if not pose_signatures.has(right):
					continue
				var pose_delta := _max_pose_delta(pose_signatures[left], pose_signatures[right])
				_expect(pose_delta > 0.001,
					"DUPLICATE NON-HUMANOID MOTION: %s and %s have the same sampled bone pose" % [left, right])

	# Tethys: every rendered mesh is skinned to the driven skeleton — guards
	# against animated bones existing beside a rigid visible model.
	var skinned_meshes := 0
	for mesh_value in _meshes(boss):
		var mesh := mesh_value as MeshInstance3D
		if mesh.skin == null:
			continue
		skinned_meshes += 1
		var resolved := mesh.get_node_or_null(mesh.skeleton)
		_expect(resolved == skeleton,
			"DETACHED SKIN: %s resolves '%s' to %s instead of the driven skeleton" % [
				mesh.name, mesh.skeleton, resolved])
	_expect(skinned_meshes > 0, "RIGID VISIBLE MODEL: no rendered mesh carries a Skin resource")

	if boss.has_clip("idle"):
		var idle := boss.anim.get_animation(boss.clip_name("idle"))
		_expect(idle != null and idle.loop_mode == Animation.LOOP_LINEAR, "IDLE DOES NOT LOOP")
	if boss.has_clip("swim_loop"):
		var swim := boss.anim.get_animation(boss.clip_name("swim_loop"))
		_expect(swim != null and swim.loop_mode == Animation.LOOP_LINEAR, "SWIM LOOP DOES NOT LOOP")

	# Tethys: encounter entrance starts Swim Start, Loop, End, then Idle —
	# guards against the direct idle/loop transition Glassgoat reported.
	var intro_sequence: Array[String] = []
	boss.anim.animation_started.connect(
		func(name: StringName) -> void: intro_sequence.append(String(name)))
	await boss.play_swim_intro()
	var expected_intro := [
		boss.clip_name("swim_start"), boss.clip_name("swim_loop"),
		boss.clip_name("swim_end"), boss.clip_name("idle"),
	]
	_expect(intro_sequence.size() >= expected_intro.size(),
		"SWIM INTRO INCOMPLETE: expected four clips, observed %s" % str(intro_sequence))
	if intro_sequence.size() >= expected_intro.size():
		for i in range(expected_intro.size()):
			_expect(intro_sequence[i] == expected_intro[i],
				"SWIM INTRO ORDER: step %d expected '%s', observed '%s'" % [
					i + 1, expected_intro[i], intro_sequence[i]])

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
	var battle_boss := battle.enemies[0].actor as TethysBoss
	var party_centre := _party_centre(battle.party)
	var toward_party := (party_centre - battle_boss.global_position).normalized()
	# Tethys: her imported face points along local +Z, unlike the humanoid
	# actors. At encounter start her visible front must face the party.
	_expect(battle_boss.basis.z.normalized().dot(toward_party) > 0.95,
		"BOSS FACING: Tethys starts with her back to the party (front %s, party %s, dot %.3f)" % [
			battle_boss.basis.z.normalized(), toward_party,
			battle_boss.basis.z.normalized().dot(toward_party)])

	# Exercise the production enemy-turn path for all six moves. Inflate HP
	# only inside this gate so the party survives long enough to observe the
	# complete deterministic animation cycle.
	var started_clips: Array[String] = []
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
	_expect(_best_party_facing_dot(battle_boss, battle.party) > 0.95,
		"BOSS ATTACK FACING: production turn points Tethys away from every party member (best dot %.3f)" %
			_best_party_facing_dot(battle_boss, battle.party))
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
		print("TETHYS BOSS: clean — 13 distinct character motions deform a %d-bone skinned rig; six attacks production-called; four base/helper takes excluded" % skeleton_bone_count)
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

func _party_centre(entries: Array) -> Vector3:
	var centre := Vector3.ZERO
	for entry in entries:
		centre += (entry.actor as Node3D).global_position
	return centre / maxf(1.0, float(entries.size()))

func _best_party_facing_dot(actor: Node3D, entries: Array) -> float:
	var best := -1.0
	for entry in entries:
		var toward := ((entry.actor as Node3D).global_position - actor.global_position).normalized()
		best = maxf(best, actor.basis.z.normalized().dot(toward))
	return best

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _measure_clip_deformation(boss: TethysBoss, skeleton: Skeleton3D, key: String) -> Dictionary:
	var clip := boss.clip_name(key)
	var animation := boss.anim.get_animation(clip)
	if animation == null or animation.length <= 0.0:
		return {"changed": false, "max_delta": 0.0, "pose": []}
	boss.anim.play(clip)
	boss.anim.seek(0.0, true)
	await process_frame
	var baseline := _bone_snapshot(skeleton)
	var max_delta := 0.0
	var signature: Array = []
	for fraction in [0.2, 0.4, 0.6, 0.8]:
		boss.anim.seek(animation.length * fraction, true)
		await process_frame
		var current := _bone_snapshot(skeleton)
		max_delta = maxf(max_delta, _max_pose_delta(baseline, current))
		if is_equal_approx(float(fraction), 0.6):
			signature = current
	return {"changed": max_delta > 0.001, "max_delta": max_delta, "pose": signature}

func _max_pose_delta(left: Array, right: Array) -> float:
	var max_delta := 0.0
	for bone in range(mini(left.size(), right.size())):
		var start := left[bone] as Transform3D
		var sample := right[bone] as Transform3D
		var delta := start.origin.distance_to(sample.origin)
		delta += start.basis.get_rotation_quaternion().angle_to(sample.basis.get_rotation_quaternion())
		max_delta = maxf(max_delta, delta)
	return max_delta

func _bone_snapshot(skeleton: Skeleton3D) -> Array:
	var poses: Array = []
	for bone in range(skeleton.get_bone_count()):
		poses.append(skeleton.get_bone_global_pose(bone))
	return poses
