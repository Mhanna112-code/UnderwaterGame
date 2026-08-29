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
# How far a diver has to start from anything a site plants in the ground.
# Wide enough to clear the models, which are up to 2.7 m tall and about a
# metre across at the shoulders.
const SPAWN_CLEARANCE := 2.5

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

# Does anybody start the game inside the scenery?
#
# Glass_Goat opened the build and reported "this time I started impaled".
# The anchor site puts a 34 m chain to the surface through its own middle
# and the party spawns at that middle, so the first thing the first diver
# did was appear skewered on it. Nothing in the code was wrong; two correct
# coordinates were simply the same coordinate, which is the sort of thing
# that only shows up by looking, and now by this.
# Nothing on the map may single out a place because there is loot in it.
#
# Marc: "no i dont want the items shown, thats the whole point of consuming
# oxygen to use the sonar ability and having to find items yourself in the
# map." The build he said that about lit an amber trail straight to the
# unclaimed key item, which made sonar pointless. Beacons may say a route
# exists and may remember where you have been; they may not say what is at
# the end of one.
func _check_no_loot_signposts() -> void:
	for r in world.routes:
		var to_site: Dictionary = Sites.by_id(String(r.to))
		var has_unclaimed: bool = String(to_site.get("item", "")) != "" \
			and not world.key_items.has(String(to_site.item))
		var visited: bool = world.visited_sites.has(String(r.to))
		for b in r.beacons:
			var st: int = (b as Beacon).state
			if st == Beacon.State.ONWARD:
				findings.append("SIGNPOSTED LOOT: the route to '%s' is lit as the way onward" % String(r.to))
				break
			if st == Beacon.State.DONE and not visited:
				findings.append("SIGNPOSTED LOOT: the route to '%s' reads as walked and nobody has been there" % String(r.to))
				break
		if has_unclaimed and visited:
			continue

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
		_check_spawns()
		_check_no_loot_signposts()
		# The route out of the anchor, whatever colour it is.
		#
		# This used to look for the amber ONWARD chain, which is gone:
		# beacons no longer point at unclaimed items, on Marc's ruling, so
		# nothing is ever amber. The claim being tested is unchanged and is
		# the one that matters either way, that a player who can see only
		# these markers ends up somewhere rather than lost in open water.
		var anchor_id := String(Sites.start().id)
		for r in world.routes:
			if String(r.from) != anchor_id:
				continue
			for b in r.beacons:
				trail.append(b)
			target_site = String(r.to)
			break
		if trail.is_empty():
			findings.append("NO WAY ON: no route leaves the anchor, so there is nothing to follow")
			return _report()
		print("trail      %d beacon(s) out of '%s', leading to '%s'" % [trail.size(), anchor_id, target_site])
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
