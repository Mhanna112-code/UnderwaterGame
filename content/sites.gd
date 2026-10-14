# The dive site as a graph of places and routes; verify/sites.gd re-checks it.
# Coordinates were probed against level geometry for clear site rings and anchor lines of sight.
# Routes are lit beacon trails within fog range: amber pulsing = onward, dim green = walked.
class_name Sites
extends RefCounted

# Must stay under fog visibility range; verify/sites.gd enforces it.
const BEACON_SPACING := 9.0
const SIGHT_BUDGET := 14.0

const ALL := [
	{
		"id": "anchor", "kind": "anchor",
		# 6.5, not larger: rock intrudes on the rim at 7.0+ (probed at verify/sites.gd's angles).
		"at": Vector3(0.0, 2.0, 0.0), "radius": 6.5,
		"links": ["shallows"],
	},
	{
		# first fight: close enough to find by accident, open enough to see
		# what you are swimming into
		"id": "shallows", "kind": "combat",
		"at": Vector3(-24.0, 2.6, -12.0), "radius": 9.5,
		"item": "current_pearl", "look": "urchin", "enemy": "angler",
		"links": ["trench"],
	},
	{
		# further out and darker
		"id": "trench", "kind": "combat",
		"at": Vector3(12.0, 2.6, -42.0), "radius": 10.0,
		"item": "reef_plate", "look": "salvage", "enemy": "swordfish_duelist",
		"links": [],
	},
	# Special-encounter sites: no beacon trail; entering the radius starts the solo minigame.
	{
		"id": "reef", "kind": "combat",
		"at": Vector3(-45.0, 2.6, 15.0), "radius": 9.0,
		"item": "attack_up", "look": "coral_case", "enemy": "angler",
		"special": true,
		"links": [],
	},
	{
		"id": "grotto", "kind": "combat",
		"at": Vector3(-15.0, 2.6, -44.0), "radius": 9.0,
		"item": "defense_up", "look": "shell_vault", "enemy": "swordfish_duelist",
		"special": true,
		"links": [],
	},
	# Deep Zone special sites; "deep" exempts them from the anchor line-of-sight check.
	{
		# open water just north of the Deep hub, before the lab cave
		"id": "deep_vents", "kind": "combat",
		"at": Vector3(84.0, 2.6, 32.0), "radius": 7.0,
		# Replayable sites give common boosts; Focus Tonic and Slipstream Oil stay rare.
		"item": "attack_up", "look": "vent_shrine", "enemy": "angler",
		"special": true, "deep": true,
		"links": [],
	},
	{
		# inside the lab cave, between Bomb Bot's exit (x<=126) and Sword
		# Slayer's trigger (x>=141)
		"id": "deep_cave", "kind": "combat",
		"at": Vector3(133.5, 2.6, 16.0), "radius": 5.5,
		"item": "defense_up", "look": "kelp_cache", "enemy": "swordfish_duelist",
		"special": true, "deep": true,
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

# Guarded items per combat site, shared by site, sonar and minimap (see ItemGuardian.spots()).
static func guarded() -> Array:
	var out: Array = []
	for s in ALL:
		if String(s.get("item", "")) != "":
			out.append({
				"item": String(s.item), "at": s.at as Vector3,
				"radius": float(s.get("radius", 0.0)),
				"site": String(s.id), "look": String(s.get("look", "urchin")),
				"enemy": String(s.get("enemy", "angler")),
				"special": bool(s.get("special", false)),
				"deep": bool(s.get("deep", false)),
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

# Sites reachable from the anchor by following links.
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
