# Is the map navigable, and does the trail actually lead anywhere?
#
# The static half checks the graph: every site reachable by links, no two
# overlapping, beacons spaced inside what the fog lets you see, and every
# site standing in a site-sized clearing with a clear approach rather than
# inside the level geometry.
#
# The moving half is the one that matters. It drives a diver that knows
# NOTHING about where anything is and can only see beacons, follows the lit
# ones, and fails if that does not deliver it to the place they lead to.
#
# A trail that looks right from above and strands a player in open water is
# exactly the bug a screenshot cannot show, and the reason this half exists.
#
# Usage: godot --headless --path . --script verify/sites.gd
extends SceneTree

# How close counts as arrived at a beacon, and how long the walk may take.
const REACHED := 3.2
const MAX_FRAMES := 6000

var world: Node3D
var findings: Array = []
var frames := 0
var trail: Array = []
var leg := 0
var target_site := ""

func _initialize() -> void:
	_check_graph()
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)

# ---- the graph, before anything moves ------------------------------------

func _check_graph() -> void:
	var reach: Array = Sites.reachable()
	for d in Sites.ALL:
		if not (String(d.id) in reach):
			findings.append("STRANDED: '%s' is on the map and no route reaches it" % String(d.id))

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

	for r in Sites.routes():
		var bs: Array = r.beacons
		if bs.size() < 2:
			findings.append("NO TRAIL: the route %s to %s has %d beacon(s)" % [
				String(r.from), String(r.to), bs.size()])
			continue
		for k in range(bs.size() - 1):
			var step: float = (bs[k] as Vector3).distance_to(bs[k + 1] as Vector3)
			if step > Sites.SIGHT_BUDGET:
				findings.append("GAP IN THE TRAIL: %s to %s has a %.1f m step, past the %.1f m you can see" % [
					String(r.from), String(r.to), step, Sites.SIGHT_BUDGET])
		var from_site: Dictionary = Sites.by_id(String(r.from))
		var to_site: Dictionary = Sites.by_id(String(r.to))
		var head: float = (bs[0] as Vector3).distance_to(from_site.at as Vector3)
		var tail: float = (bs[bs.size() - 1] as Vector3).distance_to(to_site.at as Vector3)
		if head > float(from_site.radius) + Sites.SIGHT_BUDGET:
			findings.append("TRAIL STARTS NOWHERE: %s to %s begins %.1f m out" % [String(r.from), String(r.to), head])
		if tail > float(to_site.radius) + Sites.SIGHT_BUDGET:
			findings.append("TRAIL ENDS NOWHERE: %s to %s stops %.1f m short" % [String(r.from), String(r.to), tail])

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
			findings.append("NO ROOM: '%s' has level geometry through %s" % [String(d.id), ", ".join(blocked)])
		if String(d.id) == String(Sites.start().id):
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(anchor, at, 1)).is_empty():
			findings.append("WALLED OFF: nothing can swim straight from the anchor to '%s'" % String(d.id))

func _clear(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	q.shape = sph
	q.transform = Transform3D(Basis(), Vector3(at.x, 2.6, at.z))
	q.collision_mask = 1
	return space.intersect_shape(q, 1).is_empty()

# ---- follow the lights ---------------------------------------------------

func _process(_dt: float) -> bool:
	frames += 1
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames < 4:
		return false

	if trail.is_empty():
		_check_clearings()
		for r in world.routes:
			for b in r.beacons:
				if (b as Beacon).state == Beacon.State.ONWARD:
					trail.append(b)
			if not trail.is_empty():
				target_site = String(r.to)
				break
		if trail.is_empty():
			findings.append("NO WAY ON: nothing on the map is lit as the route onward")
			return _report()
		print("trail      %d lit beacon(s), leading to '%s'" % [trail.size(), target_site])
		world.scripted = true

	var goal: Vector3 = Sites.by_id(target_site).at as Vector3
	var me: Vector3 = (world.divers[world.active] as Node3D).global_position
	# Arrived means inside the place, not touching the thing in the middle:
	# whether the guardian's own trigger fires is verify/encounters.gd's job.
	if Vector2(me.x - goal.x, me.z - goal.z).length() <= float(Sites.by_id(target_site).radius):
		print("arrived    followed the lights for %d frames and swam into '%s'" % [frames, target_site])
		return _report()

	# A swimmer that can only see beacons: head for the next lit one, and
	# when it is reached, head for the one after.
	if leg < trail.size():
		var next: Vector3 = (trail[leg] as Node3D).global_position
		var to := next - me
		to.y = 0.0
		if to.length() < REACHED:
			leg += 1
			return false
		world.scripted_dir = to.normalized()
		world.scripted_rise = clampf((2.0 - me.y) * 0.5, -1.0, 1.0)
	else:
		# past the last lamp, keep going the way the trail was pointing
		var last: Vector3 = (trail[trail.size() - 1] as Node3D).global_position
		var prev: Vector3 = (trail[maxi(0, trail.size() - 2)] as Node3D).global_position
		var onward := last - prev
		onward.y = 0.0
		if onward.length() > 0.01:
			world.scripted_dir = onward.normalized()

	if frames > MAX_FRAMES:
		findings.append("LOST: followed every lit beacon for %d frames and never reached '%s', stopped %.1f m short" % [
			frames, target_site, Vector2(me.x - goal.x, me.z - goal.z).length()])
		return _report()
	return false

func _report() -> bool:
	for f in findings:
		print("FINDING  " + f)
	print("SITES: clean" if findings.is_empty() else "SITES: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
