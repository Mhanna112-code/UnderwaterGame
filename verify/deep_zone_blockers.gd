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
	await _test_blockers_physically_gate_lab()
	await _test_gate_width_dispatches_authored_fight()
	await _test_bomb_bot_lifecycle()
	_remove_test_save()
	_finish()

func _test_blockers_physically_gate_lab() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	await physics_frame
	await physics_frame

	var points: Dictionary = world.deep_zone_layout.route_points()
	var start := Vector3(94.0, 2.0, 16.0)
	var lab := points.lab as Vector3
	for elevation in [2.0, 20.0]:
		_expect(not _physical_route_reachable(world, start, lab, elevation),
			"DZ-BLOCK-010: the lab is physically reachable around Bomb Bot at swim elevation %.1f" % elevation)

	world.route_state.set_blocker_state("bomb_bot", "defeated")
	world.route_state.set_blocker_state("sword_slayer", "available")
	world._sync_deep_zone_blocker_staging()
	await physics_frame
	for elevation in [2.0, 20.0]:
		_expect(not _physical_route_reachable(world, start, lab, elevation),
			"DZ-BLOCK-010: the lab is physically reachable around Sword Slayer at swim elevation %.1f" % elevation)

	world.route_state.set_blocker_state("sword_slayer", "defeated")
	world.route_state.set_lab_state("available")
	world._sync_deep_zone_blocker_staging()
	await physics_frame
	_expect(_physical_route_reachable(world, start, lab, 2.0),
		"DZ-BLOCK-010: defeating both blockers does not open the physical lab route")
	_expect(not _physical_route_reachable(world, start, lab, 20.0),
		"DZ-BLOCK-010: the laboratory cave can still be bypassed above its visible rock roof")

	world.queue_free()
	await process_frame
	await process_frame

func _physical_route_reachable(world: World, start: Vector3, goal: Vector3, elevation: float) -> bool:
	# Flood the complete approach volume rather than checking only the authored
	# centre line. This reproduces the real exploit: leave the route, swim around
	# a four-metre encounter circle, then approach the lab from the side.
	const STEP := 2.0
	const MIN_X := 90.0
	const MAX_X := 177.0
	const MIN_Z := -58.0
	const MAX_Z := 58.0
	var width := int(floor((MAX_X - MIN_X) / STEP)) + 1
	var depth := int(floor((MAX_Z - MIN_Z) / STEP)) + 1
	var start_cell := Vector2i(
		clampi(int(round((start.x - MIN_X) / STEP)), 0, width - 1),
		clampi(int(round((start.z - MIN_Z) / STEP)), 0, depth - 1)
	)
	var goal_cell := Vector2i(
		clampi(int(round((goal.x - MIN_X) / STEP)), 0, width - 1),
		clampi(int(round((goal.z - MIN_Z) / STEP)), 0, depth - 1)
	)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	var excluded: Array[RID] = []
	for diver_value in world.divers:
		excluded.append((diver_value as CollisionObject3D).get_rid())
	var queue: Array[Vector2i] = [start_cell]
	var visited := {start_cell: true}
	var passable_cache := {}
	while not queue.is_empty():
		var cell := queue.pop_front() as Vector2i
		if cell == goal_cell:
			return true
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next_cell: Vector2i = cell + offset
			if next_cell.x < 0 or next_cell.x >= width or next_cell.y < 0 or next_cell.y >= depth or visited.has(next_cell):
				continue
			visited[next_cell] = true
			if not passable_cache.has(next_cell):
				var position := Vector3(MIN_X + float(next_cell.x) * STEP, elevation, MIN_Z + float(next_cell.y) * STEP)
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = sphere
				query.transform = Transform3D(Basis.IDENTITY, position)
				query.exclude = excluded
				query.collide_with_areas = false
				passable_cache[next_cell] = world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
			if bool(passable_cache[next_cell]):
				queue.append(next_cell)
	return false

func _test_gate_width_dispatches_authored_fight() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	world._first_encounter_done = true
	var diver := world.divers[world.active] as Diver
	var point := world.deep_zone_layout.route_points().bomb_bot as Vector3
	for lane_z in [7.0, 16.0, 25.0]:
		diver.global_position = Vector3(point.x - 3.0, 2.0, lane_z)
		await physics_frame
		await process_frame
		_expect(world.battling and world.battle != null
			and world.battle.guardian_enemy_id == "bomb_bot"
			and world.battle.encounter_source == "lab_blocker",
			"DZ-BLOCK-011: Bomb Bot field lane z=%.1f does not dispatch its authored fight" % lane_z)
		if world.battle != null:
			world._on_battle_finished("fled")
			await process_frame
			paused = false
		diver.global_position = Vector3(point.x - 8.0, 2.0, point.z)
		await physics_frame
		await process_frame
	world.queue_free()
	await process_frame
	await process_frame

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
	var staged := _staged_blockers(world)
	_expect(staged.has("bomb_bot") and staged.has("sword_slayer"),
		"DZ-BLOCK-009: production world does not visibly stage both authored blocker models")
	if staged.has("bomb_bot") and staged.has("sword_slayer"):
		var bomb_stage := staged.bomb_bot as Node3D
		var sword_stage := staged.sword_slayer as Node3D
		_expect(bomb_stage.visible and not sword_stage.visible,
			"DZ-BLOCK-009: initial world staging must show Bomb Bot and hold Sword Slayer until unlocked")
		var authored_point := world.deep_zone_layout.route_points().bomb_bot as Vector3
		_expect(Vector2(bomb_stage.global_position.x, bomb_stage.global_position.z).distance_to(Vector2(authored_point.x, authored_point.z)) <= 8.5,
			"DZ-BLOCK-009: visible Bomb Bot is detached from its encounter trigger")
		var bomb_world_bounds := _visible_bounds(bomb_stage)
		_expect(bomb_world_bounds.size.y >= 1.5 and bomb_world_bounds.position.y >= -0.05,
			"DZ-BLOCK-009: staged Bomb Bot is not visibly floor-aligned in the production world: %s" % bomb_world_bounds)
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
	diver.global_position = bomb_point + Vector3(-8.0, 0.0, 0.0)
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
	if staged.has("bomb_bot") and staged.has("sword_slayer"):
		_expect(not (staged.bomb_bot as Node3D).visible and (staged.sword_slayer as Node3D).visible,
			"DZ-BLOCK-009: Bomb Bot victory did not replace its world actor with the unlocked Sword Slayer")
		var sword_world_bounds := _visible_bounds(staged.sword_slayer as Node3D)
		_expect(sword_world_bounds.size.y >= 1.5 and sword_world_bounds.position.y >= -0.05,
			"DZ-BLOCK-009: staged Sword Slayer is not visibly floor-aligned in the production world: %s" % sword_world_bounds)

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
	diver.global_position = slayer_point + Vector3(-8.0, 0.0, 0.0)
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
	if staged.has("sword_slayer"):
		_expect(not (staged.sword_slayer as Node3D).visible,
			"DZ-BLOCK-009: defeated Sword Slayer remained staged in the world")
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
		audio_owner.call("release_streams_for_shutdown")
	await process_frame
	await process_frame
	await create_timer(0.15).timeout

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

func _staged_blockers(world: World) -> Dictionary:
	var out := {}
	for node_value in world.get_tree().get_nodes_in_group("deep_zone_blocker_staging"):
		var node := node_value as Node3D
		if node != null and world.is_ancestor_of(node):
			out[String(node.get_meta("blocker_id", ""))] = node
	return out

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
