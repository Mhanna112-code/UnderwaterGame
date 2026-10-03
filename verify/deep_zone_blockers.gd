# Actor/content contract for the authored laboratory blockers.
#
# Usage: godot --headless --path . --script verify/deep_zone_blockers.gd
extends SceneTree

const EXPECTED_BOMB_STATS := {
	"hp": 12, "strength": 3, "defense": 4, "agility": 1,
	"evasion": 1, "accuracy": 3,
}

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var script := load("res://game/bomb_bot.gd")
	_expect(script != null, "DZ-BLOCK-001: production Bomb Bot actor is missing")
	if script == null:
		_finish()
		return

	var actor := script.new() as Goblin
	_expect(actor != null, "DZ-BLOCK-001: Bomb Bot does not implement the stable Goblin battle contract")
	if actor == null:
		_finish()
		return
	root.add_child(actor)
	await process_frame
	await process_frame

	_expect(actor.enemy_id() == "bomb_bot" and actor.display_name() == "Bomb Bot",
		"DZ-BLOCK-001: Bomb Bot actor identity drifted")
	var spawned := actor.make_stats(_stats(99, 9, 9, 9, 9, 9), 5)
	_expect(_stat_block(spawned) == EXPECTED_BOMB_STATS,
		"DZ-BLOCK-001: Bomb Bot must use its fixed provisional 12/3/4/1/1/3 tuning block")

	var expected := {
		"lightning_blast": {"name": "Lightning Blast", "clip": "lightingblast", "target": "all", "formula": {"strength": 1}},
		"sling_punch": {"name": "Sling Punch", "clip": "slingpunch", "target": "single", "formula": {"strength": 1, "defense": 1}},
		"sonic_bump": {"name": "Sonic Bump", "clip": "sonic_bump", "target": "single", "formula": {"strength": 1}},
	}
	var by_id := {}
	for move_value in actor.enemy_catalogue():
		var move := move_value as Dictionary
		by_id[String(move.get("id", ""))] = move
	_expect(by_id.size() == expected.size(),
		"DZ-BLOCK-002: Bomb Bot must expose exactly its three delivered attacks")

	var starting_pose := _skeleton_pose(actor)
	for id_value in expected:
		var id := String(id_value)
		var wanted := expected[id] as Dictionary
		var move := by_id.get(id, {}) as Dictionary
		_expect(bool(move.get("enabled", false)), "DZ-BLOCK-002: %s is not enabled" % wanted.name)
		_expect(String(move.get("name", "")) == wanted.name and String(move.get("target", "")) == wanted.target,
			"DZ-BLOCK-002: %s player-facing identity or target scope drifted" % wanted.name)
		_expect(String(move.get("clip", "")).to_lower().contains(wanted.clip),
			"DZ-BLOCK-002: %s is not mapped to delivered clip fragment %s" % [wanted.name, wanted.clip])
		_expect((move.get("combat", {}) as Dictionary).get("formula", {}) == wanted.formula,
			"DZ-BLOCK-002: %s does not retain its provisional combat role" % wanted.name)
		_expect(actor.has_clip_fragment(String(move.get("clip", ""))),
			"DZ-BLOCK-002: %s cannot resolve its delivered FBX clip" % wanted.name)
		_expect(actor.play_move(move) > 0.0,
			"DZ-BLOCK-003: %s resolves no playable animation duration" % wanted.name)

	var lightning := by_id.get("lightning_blast", {}) as Dictionary
	actor.play_move(lightning)
	actor.anim.advance(0.35)
	var attack_pose := _skeleton_pose(actor)
	_expect(not starting_pose.is_equal_approx(attack_pose),
		"DZ-BLOCK-003: Lightning Blast plays by name but does not visibly move the rig")
	var sonic_effects := ((by_id.get("sonic_bump", {}) as Dictionary).get("combat", {}) as Dictionary).get("effects", []) as Array
	_expect(sonic_effects.any(func(effect: Dictionary) -> bool:
		return String(effect.get("kind", "")) == "status" and String(effect.get("status", "")) == "blindness" and effect.get("duration", {}) == {"flat": 1}),
		"DZ-BLOCK-002: Sonic Bump must apply one-turn Blindness through the current live status API")
	var effect_target := _stats(20, 2, 2, 2, 0, 2)
	CombatRules.resolve(spawned, effect_target, (by_id.sonic_bump as Dictionary).combat as Dictionary)
	_expect(effect_target.status_level("blindness") == 1 and effect_target.status_turns("blindness") == 1,
		"DZ-BLOCK-002: Sonic Bump's advertised control effect does not function in CombatRules")

	var bounds := _visible_bounds(actor)
	_expect(bounds.size.y >= 1.5 and bounds.size.y <= 1.7,
		"DZ-BLOCK-004: normalized Bomb Bot height must remain near 1.6m, observed %s" % bounds.size.y)
	_expect(bounds.size.x <= 5.5 and bounds.size.z <= 5.5,
		"DZ-BLOCK-004: normalized Bomb Bot footprint is too wide for battle staging: %s" % bounds.size)
	_expect(bounds.position.y >= -0.05,
		"DZ-BLOCK-004: Bomb Bot is sunk below its actor origin: %s" % bounds.position.y)

	var battle := Battle.new()
	var mapped := battle._actor_for_enemy_id("bomb_bot")
	_expect(mapped != null and mapped.enemy_id() == "bomb_bot",
		"DZ-BLOCK-001: Battle actor factory still falls back to Angler for bomb_bot")
	mapped.free()
	battle.free()
	actor.queue_free()
	await process_frame
	_finish()

func _stats(hp: int, strength: int, defense: int, agility: int, evasion: int, accuracy: int) -> CombatantStats:
	var stats := CombatantStats.new()
	stats.hp_max = hp
	stats.strength = strength
	stats.defense = defense
	stats.agility = agility
	stats.evasion = evasion
	stats.accuracy = accuracy
	stats.fill()
	return stats

func _stat_block(stats: CombatantStats) -> Dictionary:
	return {
		"hp": stats.hp_max, "strength": stats.strength, "defense": stats.defense,
		"agility": stats.agility, "evasion": stats.evasion, "accuracy": stats.accuracy,
	}

func _skeleton_pose(node: Node) -> Transform3D:
	var skeleton := _find_skeleton(node)
	if skeleton == null or skeleton.get_bone_count() == 0:
		return Transform3D()
	var index := mini(1, skeleton.get_bone_count() - 1)
	return skeleton.get_bone_global_pose(index)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _visible_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh_value in _meshes(node):
		var mesh := mesh_value as MeshInstance3D
		if mesh.mesh == null or not mesh.visible:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds

func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("DEEP ZONE BLOCKERS: clean" if findings.is_empty() else "DEEP ZONE BLOCKERS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
