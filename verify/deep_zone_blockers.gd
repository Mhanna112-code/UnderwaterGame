# Actor/content contract for the authored laboratory blockers.
#
# Usage: godot --headless --path . --script verify/deep_zone_blockers.gd
extends SceneTree

const EXPECTED_BOMB_STATS := {
	"hp": 12, "strength": 3, "defense": 4, "agility": 1,
	"evasion": 1, "accuracy": 3,
}
const EXPECTED_SLAYER_STATS := {
	"hp": 14, "strength": 3, "defense": 2, "agility": 5,
	"evasion": 3, "accuracy": 3,
}
const TEST_SLOT := 918279

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_save()
	await _test_bomb_bot_actor()
	await _test_sword_slayer_actor()
	await _test_bomb_bot_lifecycle()
	_remove_test_save()
	_finish()

func _test_bomb_bot_actor() -> void:
	var script := load("res://game/bomb_bot.gd")
	_expect(script != null, "DZ-BLOCK-001: production Bomb Bot actor is missing")
	if script == null:
		return

	var actor := script.new() as Goblin
	_expect(actor != null, "DZ-BLOCK-001: Bomb Bot does not implement the stable Goblin battle contract")
	if actor == null:
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

func _test_sword_slayer_actor() -> void:
	var script := load("res://game/sword_slayer.gd")
	_expect(script != null, "DZ-BLOCK-001: production Sword Slayer actor is missing")
	if script == null:
		return
	var actor := script.new() as Goblin
	_expect(actor != null, "DZ-BLOCK-001: Sword Slayer does not implement the stable Goblin battle contract")
	if actor == null:
		return
	root.add_child(actor)
	await process_frame
	await process_frame
	_expect(actor.enemy_id() == "sword_slayer" and actor.display_name() == "Sword Slayer",
		"DZ-BLOCK-001: Sword Slayer actor identity drifted")
	var spawned := actor.make_stats(_stats(99, 9, 9, 9, 9, 9), 5)
	_expect(_stat_block(spawned) == EXPECTED_SLAYER_STATS,
		"DZ-BLOCK-001: Sword Slayer must use its fixed provisional 14/3/2/5/3/3 tuning block")
	var moves := actor.available_moves()
	_expect(moves.size() == 3,
		"DZ-BLOCK-002: Sword Slayer must expose exactly Great Slash, Stabbing, and Spinning Drill")
	for fragment in ["greatslash", "stabbing", "spinning_drill"]:
		var move := _move_for_fragment(moves, fragment)
		_expect(not move.is_empty() and actor.has_clip_fragment(String(move.get("clip", ""))),
			"DZ-BLOCK-002: Sword Slayer cannot resolve delivered clip fragment %s" % fragment)
		_expect(actor.play_move(move) > 0.0,
			"DZ-BLOCK-003: Sword Slayer clip %s has no playable duration" % fragment)
	var starting_pose := _skeleton_pose(actor)
	var spinning := _move_for_fragment(moves, "spinning_drill")
	actor.play_move(spinning)
	actor.anim.advance(0.35)
	_expect(not starting_pose.is_equal_approx(_skeleton_pose(actor)),
		"DZ-BLOCK-003: Sword Slayer's Spinning Drill does not visibly move the rig")
	var bounds := _visible_bounds(actor)
	_expect(bounds.size.y >= 1.5 and bounds.size.y <= 1.7,
		"DZ-BLOCK-004: normalized Sword Slayer height must remain near 1.6m, observed %s" % bounds.size.y)
	_expect(bounds.size.x <= 4.5 and bounds.size.z <= 4.5,
		"DZ-BLOCK-004: normalized Sword Slayer footprint is too large for battle staging: %s" % bounds.size)
	var battle := Battle.new()
	var mapped := battle._actor_for_enemy_id("sword_slayer")
	_expect(mapped != null and mapped.enemy_id() == "sword_slayer",
		"DZ-BLOCK-001: Battle actor factory still falls back to Angler for sword_slayer")
	mapped.free()
	battle.free()
	actor.queue_free()
	await process_frame

func _test_bomb_bot_lifecycle() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	world._first_encounter_done = true
	_expect(not EnemyRoster.ORDINARY_IDS.has("bomb_bot") and not EnemyRoster.ORDINARY_IDS.has("sword_slayer"),
		"DZ-BLOCK-005: authored laboratory blockers leaked into the ordinary random roster")
	if not world.has_method("_update_deep_zone_blockers"):
		findings.append("DZ-BLOCK-006: World has no production authored-blocker trigger")
		world.queue_free()
		await process_frame
		return

	var slayer_point := world.deep_zone_layout.route_points().sword_slayer as Vector3
	var diver := world.divers[world.active] as Diver
	diver.global_position = slayer_point
	world._update_route_zone()
	world._update_deep_zone_blockers()
	await process_frame
	_expect(not world.battling and world.route_state.sword_slayer_state == "available",
		"DZ-BLOCK-006: Sword Slayer activated before Bomb Bot was defeated")
	var bomb_point := world.deep_zone_layout.route_points().bomb_bot as Vector3
	diver.global_position = bomb_point
	world._update_route_zone()
	world._update_deep_zone_blockers()
	await process_frame
	_expect(world.battling and world.battle != null,
		"DZ-BLOCK-006: entering Bomb Bot's authored site did not start a battle")
	_expect(world.route_state.bomb_bot_state == "in_progress" and world.route_state.encounter_source == "lab_blocker",
		"DZ-BLOCK-006: authored encounter did not enter in_progress with source lab_blocker")
	if world.battle != null:
		_expect(world.battle.guardian_encounter and world.battle.guardian_enemy_id == "bomb_bot",
			"DZ-BLOCK-006: authored trigger did not dispatch exactly Bomb Bot")
		_expect(world.battle.enemies.size() == 1 and String((world.battle.enemies[0] as Dictionary).display_name) == "Bomb Bot",
			"DZ-BLOCK-006: live battle stage did not build one Bomb Bot")

	# A loss must make the same authored fight available again and must never
	# advance the objective. The normal game-over/checkpoint UI may still own
	# party recovery; this gate targets the blocker lifecycle itself.
	world._on_battle_finished("lost")
	await process_frame
	paused = false
	_expect(world.route_state.bomb_bot_state == "available",
		"DZ-BLOCK-007: losing Bomb Bot left the blocker consumed or stuck in progress")
	_expect(world.route_state.objective_id == "defeat_bomb_bot",
		"DZ-BLOCK-007: losing Bomb Bot falsely advanced the route objective")
	_expect(world.route_state.encounter_source == "random",
		"DZ-BLOCK-007: finished blocker encounter leaked lab_blocker source into later battles")

	world._update_deep_zone_blockers()
	await process_frame
	_expect(not world.battling,
		"DZ-BLOCK-007: losing or fleeing retriggers the fight before the player exits its site")
	diver.global_position = bomb_point + Vector3(0.0, 0.0, 8.0)
	world._update_deep_zone_blockers()
	diver.global_position = bomb_point
	world._update_deep_zone_blockers()
	await process_frame
	_expect(world.battling and world.battle != null,
		"DZ-BLOCK-007: exiting and re-entering the authored site cannot retry Bomb Bot")
	if world.battle != null:
		world._on_battle_finished("won")
		await process_frame
		paused = false
	_expect(world.route_state.bomb_bot_state == "defeated",
		"DZ-BLOCK-008: winning Bomb Bot did not permanently retire it")
	_expect(world.route_state.objective_id == "defeat_sword_slayer",
		"DZ-BLOCK-008: Bomb Bot victory did not unlock the Sword Slayer objective")
	_expect(world.route_state.encounter_source == "random",
		"DZ-BLOCK-008: Bomb Bot victory did not restore ordinary encounter policy")

	world._update_deep_zone_blockers()
	await process_frame
	_expect(not world.battling,
		"DZ-BLOCK-008: defeated Bomb Bot immediately respawned at its site")
	var victory_snapshot := world._serialize_state()
	_expect(String((victory_snapshot.route_state as Dictionary).get("bomb_bot_state", "")) == "defeated",
		"DZ-BLOCK-008: production save snapshot does not preserve Bomb Bot victory")

	diver.global_position = slayer_point
	world._update_deep_zone_blockers()
	await process_frame
	_expect(world.battling and world.battle != null and world.battle.guardian_enemy_id == "sword_slayer",
		"DZ-BLOCK-006: entering the unlocked Sword Slayer site did not dispatch its exact authored fight")
	_expect(world.route_state.sword_slayer_state == "in_progress" and world.route_state.encounter_source == "lab_blocker",
		"DZ-BLOCK-006: Sword Slayer did not enter in_progress with source lab_blocker")
	if world.battle != null:
		world._on_battle_finished("fled")
		await process_frame
	paused = false
	_expect(world.route_state.sword_slayer_state == "available" and world.route_state.objective_id == "defeat_sword_slayer",
		"DZ-BLOCK-007: fleeing Sword Slayer falsely consumed it or advanced the route")
	world._update_deep_zone_blockers()
	await process_frame
	_expect(not world.battling,
		"DZ-BLOCK-007: fleeing Sword Slayer retriggered before exiting its site")
	diver.global_position = slayer_point + Vector3(0.0, 0.0, 8.0)
	world._update_deep_zone_blockers()
	diver.global_position = slayer_point
	world._update_deep_zone_blockers()
	await process_frame
	_expect(world.battling and world.battle != null,
		"DZ-BLOCK-007: exiting and re-entering cannot retry Sword Slayer")
	if world.battle != null:
		world._on_battle_finished("won")
		await process_frame
	paused = false
	_expect(world.route_state.sword_slayer_state == "defeated",
		"DZ-BLOCK-008: Sword Slayer victory did not permanently retire it")
	_expect(world.route_state.lab_state == "available" and world.route_state.objective_id == "enter_lab",
		"DZ-BLOCK-008: Sword Slayer victory did not unlock the laboratory objective")
	world._update_deep_zone_blockers()
	await process_frame
	_expect(not world.battling,
		"DZ-BLOCK-008: defeated Sword Slayer immediately respawned")

	# Simulate a future checkpoint/save arriving while the encounter is active.
	# A fresh World has no Battle node to resume immediately, so physical re-entry
	# must reconstruct the exact authored fight from its persisted provenance.
	var interrupted_snapshot := victory_snapshot.duplicate(true)
	(interrupted_snapshot.route_state as Dictionary).bomb_bot_state = "in_progress"
	(interrupted_snapshot.route_state as Dictionary).encounter_source = "lab_blocker"
	SaveManager.write_slot(TEST_SLOT, interrupted_snapshot)
	world.queue_free()
	await process_frame
	await process_frame

	var restored := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	restored.skip_intro_for_test = true
	restored.skip_tutorial_for_test = true
	root.add_child(restored)
	await process_frame
	restored._current_slot = TEST_SLOT
	restored._load_save()
	_expect(restored.route_state.bomb_bot_state == "in_progress" and restored.route_state.encounter_source == "lab_blocker",
		"DZ-BLOCK-008: interrupted blocker provenance did not survive the checkpoint contract")
	var restored_diver := restored.divers[restored.active] as Diver
	restored._first_encounter_done = true
	restored_diver.global_position = restored.deep_zone_layout.route_points().bomb_bot as Vector3
	restored._update_deep_zone_blockers()
	await process_frame
	_expect(restored.battling and restored.battle != null and restored.battle.guardian_enemy_id == "bomb_bot",
		"DZ-BLOCK-008: loading an interrupted blocker save cannot resume the exact authored fight")
	if restored.battle != null:
		restored._on_battle_finished("fled")
		await process_frame
	paused = false
	restored.queue_free()
	await process_frame
	await process_frame
	var audio_owner := root.get_node_or_null("GameAudio")
	if audio_owner != null:
		audio_owner.call("stop_music")
	await process_frame
	await process_frame

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

func _move_for_fragment(moves: Array, fragment: String) -> Dictionary:
	for move_value in moves:
		var move := move_value as Dictionary
		if String(move.get("clip", "")).to_lower().contains(fragment):
			return move
	return {}

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

func _remove_test_save() -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("DEEP ZONE BLOCKERS: clean" if findings.is_empty() else "DEEP ZONE BLOCKERS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
