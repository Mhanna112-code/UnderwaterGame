# The dive site as a GRAPH: places, and the routes between them.
#
# Marc's condition on encounters was that they happen at dedicated locations
# you swim to, because otherwise the 3D terrain does no work. This is that,
# as data. Adding an area is an entry here and nothing else: no scene to
# edit, and verify/sites.gd re-checks the whole map every time one changes.
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
		"at": Vector3(0.0, 2.0, 0.0), "radius": 8.0,
		"links": ["shallows"],
	},
	{
		# first fight: shallow, open enough to see what you are walking into
		"id": "shallows", "kind": "combat",
		"at": Vector3(26.0, 1.7, -18.0), "radius": 9.5,
		"encounter": "goblin", "guard": "grunt_shallows",
		"links": ["trench"],
	},
	{
		# further out and darker. Same creature until there is a second one
		# to put here, which is a content gap and is written down as one
		# rather than dressed up as variety.
		"id": "trench", "kind": "combat",
		"at": Vector3(-14.0, 1.5, -48.0), "radius": 10.0,
		"encounter": "goblin", "guard": "grunt_trench",
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
