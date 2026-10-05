# Does the production Tethys battle look like it happens inside the Broken
# Office, and does it remain readable in the smallest supported playtest
# window?
#
# Bug catalog: LAB-TETHYS-012 through LAB-TETHYS-017 in
# verify/lab_tethys_route.bug-catalog.md.
#
# This deliberately measures the rendered production scene rather than scale
# constants or a screenshot hash. A room can be large in model-space and still
# read as a detached prop after the real camera, viewport stretch, and HUD have
# all taken their share of the screen.
#
# MUST run windowed:
#   godot --path . --resolution 1280x720 --script verify/lab_battle_composition.gd
#   godot --path . --resolution 720x480  --script verify/lab_battle_composition.gd
extends SceneTree

const SETTLE_FRAMES := 24
const MODELS := ["Staff_Diver", "Prototype_1(1910)", "Prototype_V(1922)"]

var findings: Array[String] = []
var sources: Array[Diver] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for model in MODELS:
		var diver := Diver.new()
		diver.model_name = model
		root.add_child(diver)
		sources.append(diver)
	await process_frame

	var battle := Battle.new()
	battle.party_source = sources
	battle.boss_encounter = true
	battle.boss_intro_enabled = false
	root.add_child(battle)
	for _frame in range(SETTLE_FRAMES):
		await process_frame

	_expect(battle.party.size() == 3, "PRODUCTION PARTY: expected all three divers")
	_expect(battle.enemies.size() == 1 and battle.enemies[0].actor is TethysBoss,
		"PRODUCTION BOSS: expected one Tethys actor")
	var lab_nodes := get_nodes_in_group("boss_lab_stage")
	_expect(lab_nodes.size() == 1, "LAB OWNER: expected one Broken Office battle stage, got %d" % lab_nodes.size())
	if battle._stage_container == null or battle._stage_cam == null or lab_nodes.size() != 1:
		return _report()

	var screen := Vector2(root.get_visible_rect().size)
	var stage := battle._stage_container as Control
	var lab := lab_nodes[0] as Node3D
	var room_bounds: AABB = battle._boss_lab_room_bounds(lab)
	var actor_rect := _actor_rect(battle)
	var min_actor_height := _minimum_actor_height(battle)
	var wall := _find_mesh(lab, "Wall_Broken")
	_expect(wall != null, "LAB ART DIRECTION: Broken Office wall/floor shell is missing")
	if wall != null:
		var wall_color := _active_albedo(wall, 0)
		_expect(wall_color.get_luminance() <= 0.48,
			"LAB ART DIRECTION: wall/floor luminance %.2f leaves the boss room reading as a pale test box" % wall_color.get_luminance())
	var authored_lights := _colored_lab_lights(lab)
	_expect(authored_lights.size() >= 2,
		"LAB ART DIRECTION: expected at least two contrasting authored lab lights, got %d" % authored_lights.size())

	print("lab composition %dx%d: stage %.0fx%.0f, actors %.0fx%.0f, smallest actor %.0fpx" % [
		int(screen.x), int(screen.y), stage.size.x, stage.size.y,
		actor_rect.size.x, actor_rect.size.y,
		min_actor_height])

	# The stage must remain a useful play area, not the narrow strip left by a
	# wrapping three-button menu at 720x480. This is a legibility boundary, not
	# a request for a particular HUD implementation.
	var minimum_stage_height := 180.0 if screen.y <= 500.0 else screen.y * 0.42
	_expect(stage.size.y >= minimum_stage_height,
		"NARROW STAGE: only %.0fpx high; needs at least %.0fpx at %dx%d" % [
			stage.size.y, minimum_stage_height, int(screen.x), int(screen.y)])

	# A roughly human-sized diver below this height is not readable at the
	# supported browser size. Wide review gets a larger floor because it has
	# substantially more stage available.
	var minimum_actor_height := 72.0 if screen.y <= 500.0 else 105.0
	_expect(min_actor_height >= minimum_actor_height,
		"TINY TABLEAU: the smallest combatant is %.0fpx tall; needs at least %.0fpx" % [
			min_actor_height, minimum_actor_height])

	# The office is the arena, not background decoration. Every combatant's
	# grounded footprint must live inside the room with breathing room from its
	# outer bounds. Projection of a room-sized AABB is intentionally not used as
	# the assertion: corners above/behind a perspective camera can yield a huge
	# rectangle even while the visible room is a tiny box in the background.
	var room_margin := 0.35
	for entry in battle.party + battle.enemies:
		if not entry.has("actor") or not is_instance_valid(entry.actor):
			continue
		var actor := entry.actor as Node3D
		var radius := maxf(0.35, float(actor.get("radius")) * 0.5)
		var inside_x := actor.global_position.x - radius >= room_bounds.position.x + room_margin \
			and actor.global_position.x + radius <= room_bounds.end.x - room_margin
		var inside_z := actor.global_position.z - radius >= room_bounds.position.z + room_margin \
			and actor.global_position.z + radius <= room_bounds.end.z - room_margin
		_expect(inside_x and inside_z,
			"ROOM DOES NOT CONTAIN %s: position %s, radius %.2f, room %s" % [
				String(entry.display_name), actor.global_position, radius, room_bounds])

	# The exported room's floor is authored at the bottom of its visible bounds;
	# all grounded actors should share that floor rather than float above or sink
	# through it.
	var floor_y := room_bounds.position.y
	for entry in battle.party + battle.enemies:
		if not entry.has("actor") or not is_instance_valid(entry.actor):
			continue
		var bottom_y: float = battle._bottom_of(entry.actor as Node3D).y
		_expect(absf(bottom_y - floor_y) <= 0.12,
			"FLOOR ALIGNMENT: %s bottom %.2f vs room floor %.2f" % [
				String(entry.display_name), bottom_y, floor_y])

	# A green in-frame result is not enough if the boss is hidden behind the
	# front party row. Compare production projected body rectangles and reject
	# overlap covering more than a quarter of the smaller silhouette.
	if not battle.enemies.is_empty() and battle.enemies[0].has("actor"):
		var boss_rect := _actor_screen_rect(battle, battle.enemies[0].actor as Node3D)
		for entry in battle.party:
			if not entry.has("actor") or not is_instance_valid(entry.actor):
				continue
			var party_rect := _actor_screen_rect(battle, entry.actor as Node3D)
			var overlap := boss_rect.intersection(party_rect)
			var overlap_area := overlap.size.x * overlap.size.y
			var smaller_area := minf(boss_rect.size.x * boss_rect.size.y,
				party_rect.size.x * party_rect.size.y)
			_expect(overlap_area <= smaller_area * 0.25,
				"BOSS OCCLUDED BY %s: overlap covers %.0f%% of the smaller silhouette" % [
					String(entry.display_name), 100.0 * overlap_area / maxf(1.0, smaller_area)])

	# The previous gate checked only Tethys against each diver. The three party
	# silhouettes could still collapse into the furniture pile and each other,
	# leaving a technically contained but visually unfinished tableau.
	for first_index in range(battle.party.size()):
		var first_entry: Dictionary = battle.party[first_index]
		if not first_entry.has("actor") or not is_instance_valid(first_entry.actor):
			continue
		var first_rect := _actor_screen_rect(battle, first_entry.actor as Node3D)
		for second_index in range(first_index + 1, battle.party.size()):
			var second_entry: Dictionary = battle.party[second_index]
			if not second_entry.has("actor") or not is_instance_valid(second_entry.actor):
				continue
			var second_rect := _actor_screen_rect(battle, second_entry.actor as Node3D)
			var overlap := first_rect.intersection(second_rect)
			var overlap_area := overlap.size.x * overlap.size.y
			var smaller_area := minf(first_rect.size.x * first_rect.size.y,
				second_rect.size.x * second_rect.size.y)
			_expect(overlap_area <= smaller_area * 0.30,
				"PARTY SILHOUETTES MERGE: %s/%s overlap covers %.0f%% of the smaller silhouette" % [
					String(first_entry.display_name), String(second_entry.display_name),
					100.0 * overlap_area / maxf(1.0, smaller_area)])

	battle.queue_free()
	for diver in sources:
		diver.queue_free()
	await process_frame
	_report()

func _actor_rect(battle: Battle) -> Rect2:
	var points: Array[Vector2] = []
	for entry in battle.party + battle.enemies:
		if not entry.has("actor") or not is_instance_valid(entry.actor):
			continue
		var actor := entry.actor as Node3D
		var radius := maxf(0.7, float(actor.get("radius")))
		var low := battle._bottom_of(actor)
		var high := battle._top_of(actor) + Vector3(0, Battle.OVERHEAD_LIFT + Battle.OVERHEAD_HEADROOM, 0)
		for dx in [-radius, radius]:
			points.append(_project(battle, low + Vector3(dx, 0, 0)))
			points.append(_project(battle, high + Vector3(dx, 0, 0)))
	return _rect_for(points)

func _actor_screen_rect(battle: Battle, actor: Node3D) -> Rect2:
	var radius := maxf(0.7, float(actor.get("radius")))
	var low := battle._bottom_of(actor)
	var high := battle._top_of(actor)
	return _rect_for([
		_project(battle, low + Vector3(-radius, 0, 0)),
		_project(battle, low + Vector3(radius, 0, 0)),
		_project(battle, high + Vector3(-radius, 0, 0)),
		_project(battle, high + Vector3(radius, 0, 0)),
	])

func _minimum_actor_height(battle: Battle) -> float:
	var result := INF
	for entry in battle.party + battle.enemies:
		if not entry.has("actor") or not is_instance_valid(entry.actor):
			continue
		var actor := entry.actor as Node3D
		var top := _project(battle, battle._top_of(actor))
		var bottom := _project(battle, battle._bottom_of(actor))
		result = minf(result, top.distance_to(bottom))
	return 0.0 if is_inf(result) else result

func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and node.name == mesh_name:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child, mesh_name)
		if found != null:
			return found
	return null

func _active_albedo(mesh: MeshInstance3D, surface_index: int) -> Color:
	var material := mesh.get_active_material(surface_index)
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).albedo_color
	return Color.WHITE

func _colored_lab_lights(node: Node) -> Array[OmniLight3D]:
	var found: Array[OmniLight3D] = []
	if node is OmniLight3D:
		var light := node as OmniLight3D
		var color_range := maxf(light.light_color.r, maxf(light.light_color.g, light.light_color.b)) \
			- minf(light.light_color.r, minf(light.light_color.g, light.light_color.b))
		if color_range >= 0.20 and light.light_energy > 0.0:
			found.append(light)
	for child in node.get_children():
		found.append_array(_colored_lab_lights(child))
	return found

func _project(battle: Battle, point: Vector3) -> Vector2:
	var stage := battle._stage_container as Control
	var vp_size := Vector2(battle._stage_vp.size)
	var scale_to_screen := Vector2(
		stage.size.x / maxf(1.0, vp_size.x),
		stage.size.y / maxf(1.0, vp_size.y))
	return battle._stage_cam.unproject_position(point) * scale_to_screen + stage.position

func _rect_for(points: Array[Vector2]) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _report() -> void:
	for finding in findings:
		print("FINDING  %s" % finding)
	print("LAB BATTLE COMPOSITION: clean" if findings.is_empty() else
		"LAB BATTLE COMPOSITION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
