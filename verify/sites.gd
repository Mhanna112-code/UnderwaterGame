# Are the authored encounter sites reachable without leaking their item
# locations through navigation markers?
#
# Checks that sites do not overlap, each sits in a clear reachable space,
# nobody spawns in their furniture, and neither route beacons nor site lamps
# are built. Maxilani's sonar is the sole deliberate item-finding aid.
#
# Usage: godot --headless --path . --script verify/sites.gd
extends SceneTree

# How far a diver has to start from anything a site plants in the ground.
# Wide enough to clear the models, which are up to 2.7 m tall and about a
# metre across at the shoulders.
const SPAWN_CLEARANCE := 2.5

var world: Node3D
var findings: Array = []
var frames := 0
var _finishing := false

func _initialize() -> void:
	_check_graph()
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)

# ---- the graph, before anything moves ------------------------------------

func _check_graph() -> void:
	for i in range(Sites.ALL.size()):
		for j in range(i + 1, Sites.ALL.size()):
			var a: Dictionary = Sites.ALL[i]
			var b: Dictionary = Sites.ALL[j]
			var gap: float = (a.at as Vector3).distance_to(b.at as Vector3)
			var need: float = float(a.radius) + float(b.radius)
			if gap < need:
				findings.append("SITES OVERLAP: '%s' and '%s' are %.1f m apart and need %.1f" % [
					String(a.id), String(b.id), gap, need])

	# Two guarded sites showing the same object is one fetch quest done
	# twice. Reported as "we just have 2 of the same in the build", and it
	# is not something a screenshot of either one on its own would show.
	var looks: Dictionary = {}
	for g in Sites.guarded():
		var look := String(g.look)
		if looks.has(look):
			findings.append("SAME AGAIN: '%s' and '%s' both present a '%s', so the two places look like the same errand" % [
				String(looks[look]), String(g.site), look])
		looks[look] = String(g.site)

# Coordinates that read fine in the source and sit inside a rock. Both of
# this map's previous guarded-item positions did exactly that, so the map is
# asked rather than trusted.
func _check_clearings() -> void:
	var space := (world.get_viewport() as Viewport).world_3d.direct_space_state
	var anchor: Vector3 = Sites.start().at as Vector3
	for d in Sites.ALL:
		var at: Vector3 = d.at as Vector3
		var blocked: Array = []
		if not _clear(space, at):
			blocked.append("its middle")
		for i in range(10):
			var a := TAU * float(i) / 10.0
			if not _clear(space, at + Vector3(cos(a), 0.0, sin(a)) * float(d.radius)):
				blocked.append("its rim")
				break
		if not blocked.is_empty():
			findings.append("NO ROOM: '%s' has level geometry through %s (%s)" % [String(d.id), ", ".join(blocked), _blocker_summary(space, at)])
		if String(d.id) == String(Sites.start().id) or bool(d.get("deep", false)):
			continue
		if not _first_environment_hit(space, anchor, at).is_empty():
			findings.append("WALLED OFF: nothing can swim straight from the anchor to '%s'" % String(d.id))

func _clear(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	q.shape = sph
	q.transform = Transform3D(Basis(), Vector3(at.x, 2.6, at.z))
	q.collision_mask = 1
	for hit_value in space.intersect_shape(q, 8):
		var collider := (hit_value as Dictionary).get("collider") as Node
		# Ordinary guarded sites intentionally place an invisible grapple target
		# at their centre. It is an interaction affordance, not level geometry
		# that blocks a diver-sized clearing.
		if collider == null or not collider.is_in_group("grapple_anchor"):
			return false
	return true

func _first_environment_hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var excluded: Array[RID] = []
	for node_value in get_nodes_in_group("grapple_anchor"):
		var node := node_value as CollisionObject3D
		if node != null:
			excluded.append(node.get_rid())
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1)
	ray.exclude = excluded
	return space.intersect_ray(ray)

func _blocker_summary(space: PhysicsDirectSpaceState3D, at: Vector3) -> String:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	q.shape = sph
	q.transform = Transform3D(Basis(), Vector3(at.x, 2.6, at.z))
	q.collision_mask = 1
	var labels: Array[String] = []
	for hit_value in space.intersect_shape(q, 8):
		var hit := hit_value as Dictionary
		var collider := hit.get("collider") as Node
		if collider != null and collider.is_in_group("grapple_anchor"):
			continue
		labels.append("%s@%s" % [collider.name if collider != null else "unknown", collider.global_position if collider is Node3D else Vector3.ZERO])
	return ", ".join(labels)

# Does anybody start the game inside the scenery?
#
# Glass_Goat opened the build and reported "this time I started impaled".
# The anchor site puts a 34 m chain to the surface through its own middle
# and the party spawns at that middle, so the first thing the first diver
# did was appear skewered on it. Nothing in the code was wrong; two correct
# coordinates were simply the same coordinate, which is the sort of thing
# that only shows up by looking, and now by this.
# Nothing on the map may single out a place because there is loot in it.
# Marc's follow-up was explicit: remove any and all markers guiding players
# to items, not merely recolour them. That means no route Beacon nodes and
# no standalone Site lamps. The guardian/item's own model remains content,
# while sonar remains the intentional locating system.
func _check_no_loot_signposts() -> void:
	var route_markers := _count_beacons(world)
	var site_markers := 0
	for id in world.site_nodes.keys():
		for child in (world.site_nodes[id] as Site).get_children():
			if child is OmniLight3D:
				site_markers += 1
	if route_markers > 0 or site_markers > 0:
		findings.append("ITEM GUIDANCE REMAINS: found %d route beacon(s) and %d site lamp(s); Marc asked for all item-guiding markers removed" % [
			route_markers, site_markers])

func _count_beacons(node: Node) -> int:
	var total := 1 if node is Beacon else 0
	for child in node.get_children():
		total += _count_beacons(child)
	return total

func _check_spawns() -> void:
	for c in World.CAST:
		var at: Vector3 = c.at as Vector3
		for id in world.site_nodes.keys():
			var site: Site = world.site_nodes[id]
			for f in site.furniture_points():
				var gap: float = Vector2(at.x - (f as Vector3).x, at.z - (f as Vector3).z).length()
				if gap < SPAWN_CLEARANCE:
					findings.append("SPAWNED INSIDE THE SCENERY: %s starts %.1f m from '%s' furniture, needs %.1f" % [
						String(c.model), gap, String(id), SPAWN_CLEARANCE])

# ---- build the real world and inspect it --------------------------------

func _process(_dt: float) -> bool:
	if _finishing:
		return false
	frames += 1
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames < 4:
		return false

	_check_clearings()
	_check_spawns()
	_check_no_loot_signposts()
	return _report()

func _report() -> bool:
	_finishing = true
	for f in findings:
		print("FINDING  " + f)
	print("SITES: clean" if findings.is_empty() else "SITES: %d finding(s)" % findings.size())
	world.queue_free()
	call_deferred("_finish_report")
	return true

func _finish_report() -> void:
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	quit(0 if findings.is_empty() else 1)
