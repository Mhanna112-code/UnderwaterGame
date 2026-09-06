# Contract test for Glassgoat's Angler Fish replacement.  The gameplay class
# remains Goblin for compatibility with existing battle/save/balance code; its
# visible actor must nevertheless be the Angler, with the authored motions and
# embedded material actually usable at runtime.
extends SceneTree

var findings: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var angler := Goblin.new()
	root.add_child(angler)
	await process_frame
	await process_frame

	_expect(angler.anim != null, "ANGLER GRUNT: no AnimationPlayer — guards against an unimportable replacement FBX")
	_expect(absf(angler.height - Goblin.TARGET_HEIGHT) < 0.05,
		"ANGLER GRUNT: height %.2f is not the stage target %.2f — guards against a giant/tiny enemy" % [angler.height, Goblin.TARGET_HEIGHT])
	_expect(angler.radius >= 0.3, "ANGLER GRUNT: radius %.2f is unusably small — guards against framing a zero-width model" % angler.radius)

	var skeleton := _find_skeleton(angler)
	_expect(skeleton != null and skeleton.get_bone_count() >= 19,
		"ANGLER GRUNT: expected its non-humanoid 19-bone rig, found %d — guards against a static or wrong asset" % (skeleton.get_bone_count() if skeleton != null else 0))
	_expect(_has_textured_surface(angler),
		"ANGLER GRUNT: no rendered surface has an albedo texture — guards against the white/missing-texture delivery")

	# Each production key must select its authored action.  These checks use
	# Goblin.play(), the same public surface battle.gd uses, rather than reaching
	# into the import's private AnimationPlayer names.
	var required := {
		"idle": "idle",
		"swim": "swimming(mid)",
		"attack": "attack)bite",
		"hurt": "damaged",
		"death": "death",
	}
	for key_value in required:
		var key := String(key_value)
		angler.play(key)
		await process_frame
		var current := String(angler.anim.current_animation).to_lower() if angler.anim != null else ""
		_expect(String(required[key]).to_lower() in current,
			"ANGLER GRUNT: %s resolved '%s', not an authored %s clip — guards against a wrong/fallback animation" % [key, current, required[key]])

	# The retired Goblin used a guessed PI rotation. Angler's authored face is
	# local +Z, so battle must orient that axis toward the party rather than
	# retain the previous model's orientation assumption.
	var battle := Battle.new()
	root.add_child(battle)
	await process_frame
	await process_frame
	if battle.enemies.is_empty() or battle.party.is_empty():
		_expect(false, "ANGLER GRUNT: stage did not create party and enemy — guards against an untestable combat spawn")
	else:
		var enemy_actor := (battle.enemies[0] as Dictionary).actor as Node3D
		var party_centre := Vector3.ZERO
		for entry in battle.party:
			party_centre += (entry as Dictionary).actor.global_position
		party_centre /= float(battle.party.size())
		var toward_party := (party_centre - enemy_actor.global_position).normalized()
		_expect(enemy_actor.basis.z.normalized().dot(toward_party) > 0.95,
			"ANGLER GRUNT: starts facing away from combat (front dot %.3f) — guards against retaining the Goblin PI rotation" % enemy_actor.basis.z.normalized().dot(toward_party))
		# Enemy turns use Battle._step_toward(), a second orientation path that
		# used to assume every actor's front was -Z. Inflate the party only in
		# this gate so one production turn can finish and leave the Bite aimed at
		# at least one actual target.
		for entry in battle.party:
			var stats := (entry as Dictionary).stats as CombatantStats
			stats.hp_max = 500
			stats.hp = 500
			stats.evasion = 0
			stats.evasion_current = 0
		var enemy_entry := battle.enemies[0] as Dictionary
		(enemy_entry.stats as CombatantStats).accuracy = 99
		await battle._do_enemy_turn(enemy_entry)
		var best_attack_dot := -1.0
		for entry in battle.party:
			var toward_target: Vector3 = ((entry as Dictionary).actor.global_position - enemy_actor.global_position).normalized()
			best_attack_dot = maxf(best_attack_dot, enemy_actor.basis.z.normalized().dot(toward_target))
		_expect(best_attack_dot > 0.95,
			"ANGLER GRUNT: Bite faces away from every target (best front dot %.3f) — guards against diver-axis attack aiming" % best_attack_dot)
	battle.queue_free()

	angler.queue_free()
	await process_frame
	if findings.is_empty():
		print("ANGLER GRUNT: clean — textured 19-bone Angler, stage-sized, with idle/swim/bite/hurt/death mappings")
		quit(0)
		return
	for finding in findings:
		print("FINDING  " + finding)
	print("ANGLER GRUNT: %d finding(s)" % findings.size())
	quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _has_textured_surface(node: Node) -> bool:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface)
			if material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture != null:
				return true
	for child in node.get_children():
		if _has_textured_surface(child):
			return true
	return false
