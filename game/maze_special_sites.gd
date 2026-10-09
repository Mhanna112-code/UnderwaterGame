extends Node3D
# Authored #97 4ec6598 radius sites; snapshots own new-run locations forever.
const DEFINITIONS := [
	{"item": "accuracy_up", "enemy": "swordfish_duelist"},
	{"item": "attack_up", "enemy": "angler"},
	{"item": "defense_up", "enemy": "swordfish_duelist"},
	{"item": "oxygen_cell", "enemy": "angler"},
	{"item": "evasion_up", "enemy": "angler"},
	{"item": "attack_up", "enemy": "swordfish_duelist"},
	{"item": "potion", "enemy": "angler"},
]
const CLEARANCE := 2.2
const RADIUS := 4.0
const SONAR_RADIUS := 14.0
# Sites sit ON the maze floor, but a diver's origin is mid-body (~1 above the
# floor when touching it), so the overworld's +/-1.5 marker window only fired
# when hugging the floor. Maze sites count from just below the floor up to
# SITE_RISE above it (same reach as the draft passages). The maze map's site
# circle uses the same test, so a site that isn't on the map can't trigger.
const SITE_RISE := 4.0

static func within_site_height(diver_y: float, site_y: float) -> bool:
	return diver_y >= site_y - 0.5 and diver_y <= site_y + SITE_RISE
var maze: MazeLevel
var initialized := false
var sites: Array[Dictionary] = []
var prompt: SpecialEncounterPrompt
var _pending_restore: Array = []
var _inside_id := ""
var _pending: Dictionary = {}
var _chosen: Diver
var _pre_hp := 0
var _pre_oxygen := 0.0
var _was_mouse_look := false
var _was_mouse_mode := Input.MOUSE_MODE_VISIBLE

func setup(owner_maze: MazeLevel) -> void:
	maze = owner_maze
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	prompt = SpecialEncounterPrompt.new()
	layer.add_child(prompt)
	prompt.diver_chosen.connect(_choose)
	prompt.cancelled.connect(cancel)
	# CSG collision is unavailable during construction. Readiness is a save
	# guard, not permission to omit an entry after colliding/unlucky placement.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not _pending_restore.is_empty():
		_apply_restore(_pending_restore)
		return
	var between := _between_points()
	var past_draft := _draft_points()
	if between.size() != 3 or past_draft.size() != 3:
		push_error("Maze special sites: cannot place all six open-water sites safely")
		return
	var points: Array = [Vector3(64, 0, 52) + maze.coordinate_origin]
	points.append_array(between)
	points.append_array(past_draft)
	for index in DEFINITIONS.size():
		var point := points[index] as Vector3
		sites.append({"id": "maze_special_%d" % index,
			"position": [point.x, maze._floor_top_y, point.z],
			"item": DEFINITIONS[index].item, "enemy": DEFINITIONS[index].enemy,
			"revealed": false, "consumed": false})
	initialized = true

func _between_points() -> Array:
	var current := maze.get_node("WindCorridorBreakRock") as Area3D
	var reward := maze.get_node("RewardChamberWestWall") as CSGBox3D
	var stub := maze.get_node("CSGBox3DConnectorStub") as CSGBox3D
	var line_x: float = maze._corridor_shape(current).global_position.x
	return _spaced_points(line_x + 14.0, line_x + 20.0,
		stub.global_position.z + 1.5 + CLEARANCE,
		reward.global_position.z - 0.5 - CLEARANCE, 10.0, 20.0)

func _draft_points() -> Array:
	var box7 := maze.get_node("CSGBox3D7") as CSGBox3D
	var cap := maze.get_node("Wall11EndCap") as CSGBox3D
	var geometry: Dictionary = maze._wall_geometry(cap)
	var z_start := maxf(geometry.negative_end.z, geometry.positive_end.z) + 4.0
	return _spaced_points(box7.global_position.x + box7.size.z * 0.5 + CLEARANCE + 0.8,
		cap.global_position.x - cap.size.z * 0.5 - 0.5,
		z_start, z_start + 25.0, 7.0, 10.0)

func _spaced_points(x_lo: float, x_hi: float, z_lo: float, z_hi: float, spacing_lo: float, spacing_hi: float) -> Array:
	if x_hi < x_lo or z_hi < z_lo:
		return []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for attempt in 80:
		var points: Array = []
		var z := z_lo + rng.randf_range(0.0, 2.0)
		for index in 3:
			var point := Vector3(rng.randf_range(x_lo, x_hi), maze._floor_top_y, z)
			if z > z_hi or not _clear(point):
				break
			points.append(point)
			z += rng.randf_range(spacing_lo, spacing_hi)
		if points.size() == 3:
			return points
	# Fallback remains within the SAME authored region and spacing bounds.
	for lane in 9:
		var x := lerpf(x_lo, x_hi, float(lane) / 8.0)
		for step in 12:
			var points: Array = []
			var z := z_lo + float(step) * 0.25
			for index in 3:
				var point := Vector3(x, maze._floor_top_y, z + index * spacing_lo)
				if point.z > z_hi or not _clear(point):
					break
				points.append(point)
			if points.size() == 3:
				return points
	return []

func _clear(point: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = CLEARANCE
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (CLEARANCE + 0.1))
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func modal_open() -> bool:
	return prompt != null and prompt.visible

func _point(site: Dictionary) -> Vector3:
	return CampaignSession.vector_from(site.position)

func update() -> void:
	# A shared lesson can pause during Maze's current physics callback.
	# Respect that owner even before the next paused frame suppresses physics.
	if get_tree().paused or not initialized or not maze.maze_active or maze._diver == null:
		return
	var actor := maze._diver
	var at := actor.global_position
	if actor.passive_id == "sonar" and actor.sonar_active:
		for site in sites:
			if not site.consumed and not site.revealed and at.distance_to(_point(site)) <= SONAR_RADIUS:
				site.revealed = true
				maze._announce("Sonar found something guarded nearby.")
	var inside: Dictionary = {}
	for site in sites:
		var point := _point(site)
		if not site.consumed and within_site_height(at.y, point.y) \
			and Vector2(at.x, at.z).distance_to(Vector2(point.x, point.z)) <= RADIUS:
			inside = site
			break
	# R suppresses ordinary travel fights, never authored site challenges.
	if inside.is_empty():
		_inside_id = ""
		return
	if _inside_id == String(inside.id) or maze._battling or maze.any_modal_open() \
		or maze._chest_reward_pending or maze._gate_cutscene or not maze._moving_wall_sets.is_empty():
		return
	# The open nav map no longer blocks this (it only fills a corner; the
	# site's prompt closes it like any menu).
	if maze.target_selector.selecting:
		return
	# Sonar may reveal through a wall, but entering its open water matters.
	var eye := at + Vector3.UP * actor.height * 0.4
	var destination := _point(inside) + Vector3.UP * maxf(actor.height * 0.4, 1.0)
	var query := PhysicsRayQueryParameters3D.create(eye, destination, 1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	_inside_id = String(inside.id)
	_pending = inside
	_was_mouse_look = maze._mouse_look
	_was_mouse_mode = Input.mouse_mode
	maze._cancel_aim()
	maze._mouse_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	prompt.open()
	maze._refresh_announcement_visibility()
	get_tree().paused = true

func _choose(model_name: String) -> void:
	if not modal_open() or _pending.is_empty() or not maze.maze_active:
		return
	var chosen: Diver
	for actor in maze.divers:
		if actor.model_name == model_name:
			chosen = actor
	if chosen == null or chosen.stats.hp <= 0:
		cancel()
		maze._announce("That diver needs recovery before entering a special encounter.")
		return
	_chosen = chosen
	_pre_hp = chosen.stats.hp
	_pre_oxygen = chosen.stats.oxygen
	prompt.close()
	get_tree().paused = false
	maze._start_battle("special")

func configure_battle(battle: Battle) -> void:
	battle.encounter_source = "maze_special"
	battle.special_encounter = true
	battle.guardian_encounter = true
	battle.guardian_enemy_id = String(_pending.enemy)
	battle.party_source = [_chosen]
	battle.reward_item_on_win = String(_pending.item)
	battle.encounter_intro_override = "An item guardian challenges %s." % Cast.display_name(_chosen.model_name)

func finish(result: String) -> void:
	if not is_instance_valid(_chosen) or _pending.is_empty():
		return
	if result == "won" and not _pending.consumed:
		# Authored Maze-special policy, NOT ordinary victory healing.
		_pending.consumed = true
		_chosen.stats.hp = _chosen.stats.hp_max
		_chosen.stats.oxygen = _chosen.stats.oxygen_max
		# Announced in the battle's combat log (Battle.reward_claim_text()).
		maze._on_secret_orb_collected(String(_pending.item), _chosen, false)
	else:
		_chosen.stats.hp = _pre_hp
		_chosen.stats.oxygen = _pre_oxygen
		maze._announce("The guardian holds its ground. Come back and try again.")
	_chosen = null
	_pending = {}
	maze._mouse_look = _was_mouse_look
	Input.mouse_mode = _was_mouse_mode

func cancel() -> void:
	if modal_open():
		prompt.close()
		get_tree().paused = false
		maze._mouse_look = _was_mouse_look
		Input.mouse_mode = _was_mouse_mode
	_pending = {}
	_chosen = null

func points_of_interest() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for site in sites:
		if site.revealed and not site.consumed:
			out.append({"id": site.id, "kind": "special", "pos": _point(site), "radius": INF})
	return out

func snapshot() -> Array:
	return sites.duplicate(true)

func restore(data: Array) -> void:
	cancel()
	_inside_id = ""
	if not initialized:
		_pending_restore = data.duplicate(true)
	else:
		_apply_restore(data)

func restore_legacy() -> void:
	cancel()
	_inside_id = ""
	_pending_restore.clear()
	for site in sites:
		site.revealed = false
		site.consumed = false

func _apply_restore(data: Array) -> void:
	sites.assign(data.duplicate(true))
	initialized = true
	_pending_restore.clear()

static func valid_snapshot(value: Variant) -> bool:
	if not value is Array or value.size() != DEFINITIONS.size():
		return false
	var ids: Array = []
	for site in value:
		if not site is Dictionary or not site.get("id") is String:
			return false
		var index := -1
		for candidate in DEFINITIONS.size():
			if site.id == "maze_special_%d" % candidate:
				index = candidate
		if index < 0 or ids.has(site.id) or site.get("item") != DEFINITIONS[index].item \
			or site.get("enemy") != DEFINITIONS[index].enemy or not site.get("revealed") is bool \
			or not site.get("consumed") is bool or not MazeCoordinateFrame.valid_origin(site.get("position")):
			return false
		ids.append(site.id)
	return true

func _exit_tree() -> void:
	cancel()
