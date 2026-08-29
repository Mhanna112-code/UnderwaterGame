# The dive site as a GRAPH: places, and the routes between them.
#
# Marc's condition on encounters was that they happen at dedicated locations
# you swim to, because otherwise the 3D terrain does no work. This is that,
# as data. Adding an area is an entry here and nothing else: no scene to
# edit, and verify/sites.gd re-checks the whole map every time one changes.
#
# The coordinates are not chosen by eye. Each one was checked against the
# actual level geometry for a site-sized clearing (the middle and ten points
# around the rim, all clear) and for an unobstructed line from the anchor.
# 317 positions on this map qualify; these are two of them, far enough apart
# that their berms cannot touch.
#
# Navigation is diegetic. Dark water limits sight to roughly 25m, so instead
# of fighting that with a compass or an arrow on the HUD, the route between
# two sites is a line of lit beacons spaced inside visible range. You can
# always see the next one or two, and following them IS the navigation.
# Amber and pulsing means the way onward, dim green means a road already
# walked. That is the entire legend and it needs no words.
class_name Sites
extends RefCounted

# how far apart beacons sit. Must stay under what the fog lets you see, or
# the trail has gaps and the player is lost between them; verify/sites.gd
# fails if this ever drifts past the budget.
const BEACON_SPACING := 9.0
const SIGHT_BUDGET := 14.0

const ALL := [
	{
		"id": "anchor", "kind": "anchor",
		# 6.5 rather than the 8.0 this had on the branch it came from. The
		# party spawns here and Marc's opening geometry sits closer in on
		# this map: at 8.0 and at 7.0 there is rock through the rim, at 144
		# degrees. Probed at the exact angles verify/sites.gd samples rather
		# than nudged down until a screenshot looked right.
		"at": Vector3(0.0, 2.0, 0.0), "radius": 6.5,
		"links": ["shallows"],
	},
	{
		# first fight: close enough to find by accident, open enough to see
		# what you are swimming into
		"id": "shallows", "kind": "combat",
		"at": Vector3(-24.0, 2.6, -12.0), "radius": 9.5,
		"item": "current_pearl", "look": "urchin",
		"links": ["trench"],
	},
	{
		# further out and darker
		"id": "trench", "kind": "combat",
		"at": Vector3(12.0, 2.6, -42.0), "radius": 10.0,
		"item": "reef_plate", "look": "salvage",
		"links": [],
	},
]

static func by_id(id: String) -> Dictionary:
	for s in ALL:
		if String(s.id) == id:
			return s
	return {}

static func start() -> Dictionary:
	return ALL[0] as Dictionary

# Which item is guarded here, for the combat sites. One list, so the site,
# the guardian standing on its plinth, sonar and the minimap cannot disagree
# about where a thing is. See ItemGuardian.spots().
# "look" is what is actually standing on the plinth. Two sites with the
# same thing on them is two of the same fetch quest wearing one coat of
# paint, which is exactly how it read in the build: verify/sites.gd fails
# if any two guarded sites share a look.
static func guarded() -> Array:
	var out: Array = []
	for s in ALL:
		if String(s.get("item", "")) != "":
			out.append({
				"item": String(s.item), "at": s.at as Vector3,
				"site": String(s.id), "look": String(s.get("look", "urchin")),
			})
	return out

# Every beacon on the map: one chain per link, laid between the two sites and
# stopping short of each so the posts never stand inside the ring they lead to.
static func routes() -> Array:
	var out: Array = []
	for s in ALL:
		for other in s.links:
			var b: Dictionary = by_id(String(other))
			if b.is_empty():
				continue
			out.append({"from": String(s.id), "to": String(b.id),
				"beacons": _chain(s, b)})
	return out

static func _chain(a: Dictionary, b: Dictionary) -> Array:
	var p: Vector3 = a.at
	var q: Vector3 = b.at
	var span: Vector3 = q - p
	var length: float = span.length()
	var start_at: float = float(a.radius)
	var end_at: float = length - float(b.radius)
	var out: Array = []
	if end_at <= start_at:
		return out
	var run: float = end_at - start_at
	var n: int = maxi(1, int(ceil(run / BEACON_SPACING)))
	var dir: Vector3 = span / maxf(0.001, length)
	for i in range(n + 1):
		var t: float = start_at + run * float(i) / float(n)
		out.append(p + dir * t)
	return out

# reachable from the anchor by following links, which is the only definition
# of "the player can get there" that means anything
static func reachable() -> Array:
	var seen: Array = [String(start().id)]
	var queue: Array = [String(start().id)]
	while not queue.is_empty():
		var id: String = String(queue.pop_front())
		for l in (by_id(id).get("links", []) as Array):
			if not (String(l) in seen):
				seen.append(String(l))
				queue.append(String(l))
	return seen
