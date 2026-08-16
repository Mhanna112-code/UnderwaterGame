# Is the map navigable, and does the trail actually lead anywhere?
#
# The static half checks the graph: every site reachable, no two sites
# overlapping, beacons spaced inside what the fog lets you see. The moving
# half is the one that matters. It drives a diver that knows NOTHING about
# where the fight is and can only see beacons, follows the lit ones, and
# fails if that does not deliver it to the site.
#
# A trail that looks right from above and strands a player in open water is
# exactly the bug a screenshot cannot show.
#
# Usage: godot --headless --path . --script verify/sites.gd
extends SceneTree

var findings: Array = []
var world
var frames := 0
var trail: Array = []
var leg := 0
var walked := 0.0

func _initialize() -> void:
	_static_checks()
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)

# ---- the graph, before anything moves -----------------------------------

func _static_checks() -> void:
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
				findings.append("SITES OVERLAP: '%s' and '%s' are %.1fm apart and need %.1f" % [
					String(a.id), String(b.id), gap, need])

	for r in Sites.routes():
		var bs: Array = r.beacons
		if bs.size() < 2:
			findings.append("NO TRAIL: the route %s to %s has %d beacon(s)" % [
				String(r.from), String(r.to), bs.size()])
			continue
		for k in range(bs.size() - 1):
			var step: float = (bs[k] as Vector3).distance_to(bs[k + 1] as Vector3)
			if step > Sites.SIGHT_BUDGET:
				findings.append("GAP IN THE TRAIL: %s to %s has a %.1fm step, past the %.1fm you can see" % [
					String(r.from), String(r.to), step, Sites.SIGHT_BUDGET])
		# the first and last beacon must actually meet the places they join
		var from_site: Dictionary = Sites.by_id(String(r.from))
		var to_site: Dictionary = Sites.by_id(String(r.to))
		var head: float = (bs[0] as Vector3).distance_to(from_site.at as Vector3)
		var tail: float = (bs[bs.size() - 1] as Vector3).distance_to(to_site.at as Vector3)
		if head > float(from_site.radius) + Sites.SIGHT_BUDGET:
			findings.append("TRAIL STARTS NOWHERE: %s to %s begins %.1fm out" % [String(r.from), String(r.to), head])
		if tail > float(to_site.radius) + Sites.SIGHT_BUDGET:
			findings.append("TRAIL ENDS NOWHERE: %s to %s stops %.1fm short" % [String(r.from), String(r.to), tail])

# ---- follow the lights ---------------------------------------------------

func _process(_dt: float) -> bool:
	frames += 1
	if frames < 3:
		return false

	if trail.is_empty():
		for r in world.routes:
			for b in r.beacons:
				if (b as Beacon).state == Beacon.State.ONWARD:
					trail.append(b)
		if trail.is_empty():
			findings.append("NO WAY ON: nothing on the map is lit as the route onward")
			return _report()
		print("trail      %d lit beacon(s) from the anchor" % trail.size())
		world.scripted = true

	# a swimmer that can only see beacons: head for the next lit one, and
	# when it is reached, head for the one after
	if world.get("battle") != null or world.get("world") == null:
		pass
	var me: Vector3 = (world.divers[world.active] as Node3D).global_position
	if leg < trail.size():
		var target: Vector3 = (trail[leg] as Node3D).global_position
		var to := target - me
		to.y = 0.0
		if to.length() < 3.2:
			leg += 1
			return false
		world.scripted_dir = to.normalized()
		world.scripted_rise = clampf((1.6 - me.y) * 0.5, -1.0, 1.0)
	else:
		# past the last beacon, keep going the way the trail was pointing
		var last: Vector3 = (trail[trail.size() - 1] as Node3D).global_position
		var prev: Vector3 = (trail[maxi(0, trail.size() - 2)] as Node3D).global_position
		var onward := (last - prev)
		onward.y = 0.0
		world.scripted_dir = onward.normalized()

	if world._fired:
		print("arrived    followed the lights for %d frames and walked into the fight" % frames)
		return _report()
	if frames > 5000:
		findings.append("LOST: followed every lit beacon for %d frames and never reached the site" % frames)
		return _report()
	return false

func _report() -> bool:
	for f in findings:
		print("FINDING  " + f)
	print("SITES: clean" if findings.is_empty() else "SITES: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
