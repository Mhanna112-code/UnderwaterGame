# Integration contract for the two fixed artifact guardians. This deliberately
# observes the map, Battle's construction, and the second delivered rig rather
# than assuming a site data entry reaches each of those boundaries.
extends SceneTree

var findings: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var expected := {"current_pearl": "angler", "reef_plate": "swordfish_duelist"}
	var guarded := ItemGuardian.spots()
	_expect(guarded.size() == 2, "ARTIFACT GUARDIANS: expected exactly two guarded items — guards against an art change deleting a progression location")
	for spot_value in guarded:
		var spot := spot_value as Dictionary
		var item := String(spot.get("item", ""))
		_expect(String(spot.get("enemy", "")) == String(expected.get(item, "")),
			"ARTIFACT GUARDIANS: sites assign Angler to shallows and Swordfish Duelist to trench — guards against defaulting both sites to Angler (item %s has '%s')" % [item, String(spot.get("enemy", ""))])

	var duelist := SwordDuelist.new()
	root.add_child(duelist)
	await process_frame
	await process_frame
	_expect(duelist.enemy_id() == "swordfish_duelist", "ARTIFACT GUARDIANS: Duelist reports its stable identity — guards against an actor masquerading as Angler")
	_expect(absf(duelist.height - Goblin.TARGET_HEIGHT) < 0.05,
		"ARTIFACT GUARDIANS: Duelist is stage-sized, animated, and faces its target — guards against unusable second FBX (height %.2f)" % duelist.height)
	_expect(duelist.anim != null and duelist.has_clip_fragment("attack)greatslash"),
		"ARTIFACT GUARDIANS: Duelist is stage-sized, animated, and faces its target — guards against unusable second FBX (Great Slash missing)")
	var skeleton := _find_skeleton(duelist)
	_expect(skeleton != null and skeleton.get_bone_count() >= 19,
		"ARTIFACT GUARDIANS: Duelist has a live non-humanoid rig — guards against a static/wrong import")
	# Glassgoat supplied a later Swordfish export with its diffuse artwork
	# embedded. A material-only import leaves the real trench guardian flat
	# white, so renderability alone is not enough now.
	_expect(_has_renderable_surface(duelist),
		"ARTIFACT GUARDIANS: Duelist has no renderable material — guards against importing an invisible/wrong asset")
	_expect(_has_albedo_texture(duelist),
		"ARTIFACT GUARDIANS: Duelist has an imported albedo texture — guards against a flat-white Swordfish at the trench artifact")
	var move := duelist.available_moves()[0] as Dictionary if not duelist.available_moves().is_empty() else {}
	var length := duelist.play_move(move)
	await process_frame
	_expect(length > 0.0 and skeleton != null and await _moves_bones(duelist, skeleton),
		"ARTIFACT GUARDIANS: Duelist authored attack deforms its rig — guards against clip-name fallback")
	duelist.face_toward(Vector3(3.0, 0.0, 4.0))
	var toward := (Vector3(3.0, 0.0, 4.0) - duelist.global_position).normalized()
	_expect(duelist.basis.z.normalized().dot(toward) > 0.95,
		"ARTIFACT GUARDIANS: Duelist is stage-sized, animated, and faces its target — guards against unusable second FBX (front axis reversed)")
	duelist.queue_free()

	for spot_value in guarded:
		var spot := spot_value as Dictionary
		var battle := Battle.new()
		battle.guardian_encounter = true
		battle.guardian_enemy_id = String(spot.get("enemy", ""))
		root.add_child(battle)
		await process_frame
		await process_frame
		_expect(battle.enemies.size() == 1,
			"ARTIFACT GUARDIANS: each selected guardian battle has one enemy and preserves its item — guards against art changing progression (%s has %d enemies)" % [String(spot.item), battle.enemies.size()])
		if not battle.enemies.is_empty():
			var actor := (battle.enemies[0] as Dictionary).actor as Goblin
			_expect(actor != null and actor.enemy_id() == String(spot.enemy),
				"ARTIFACT GUARDIANS: trench decoy and battle are both Swordfish Duelist — guards against world/battle identity drift (%s battle has '%s')" % [String(spot.item), actor.enemy_id() if actor != null else "none"])
		battle.queue_free()
		await process_frame

	if findings.is_empty():
		print("ARTIFACT GUARDIANS: clean — current pearl Angler and reef plate Swordfish Duelist remain one-enemy guardian encounters")
		quit(0)
		return
	for finding in findings:
		print("FINDING  " + finding)
	quit(1)

func _moves_bones(actor: Goblin, skeleton: Skeleton3D) -> bool:
	var animation := actor.anim.get_animation(actor.anim.current_animation)
	if animation == null or animation.length <= 0.0:
		return false
	actor.anim.seek(0.0, true)
	await process_frame
	var before := skeleton.get_bone_global_pose(0)
	for fraction in [0.3, 0.6, 0.9]:
		actor.anim.seek(animation.length * fraction, true)
		await process_frame
		for bone in range(skeleton.get_bone_count()):
			var after := skeleton.get_bone_global_pose(bone)
			if before.origin.distance_to(after.origin) > 0.001 or before.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion()) > 0.001:
				return true
	return false

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _has_renderable_surface(node: Node) -> bool:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface)
			if material is Material:
				return true
	for child in node.get_children():
		if _has_renderable_surface(child):
			return true
	return false

func _has_albedo_texture(node: Node) -> bool:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface)
			if material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture != null:
				return true
	for child in node.get_children():
		if _has_albedo_texture(child):
			return true
	return false

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
