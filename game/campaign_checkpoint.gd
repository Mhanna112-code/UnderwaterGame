# The versioned JSON boundary for a maze checkpoint. Live CampaignSession
# resources are never written directly. Legacy flat World checkpoints remain
# readable; the flat root retains title summaries and the outer-world context.
class_name CampaignCheckpoint
extends RefCounted

const STAT_INTS := ["hp_max", "strength", "defense", "agility", "accuracy", "evasion",
	"evasion_current", "level", "xp", "xp_to_next", "spell_points", "hp"]
const STAT_DICTS := ["statuses", "temporary_modifiers", "stat_floor"]
const MODELS := ["Staff_Diver", "Prototype_1(1910)", "Prototype_V(1922)"]

static func encode(session: CampaignSession, scene := "maze") -> Dictionary:
	var data := session.outer_world_checkpoint.duplicate(true)
	# A World checkpoint can retain maze history. Never nest its previous
	# checkpoint envelope recursively on repeated branch visits.
	data.erase("campaign_checkpoint")
	data.erase("campaign_scene")
	var members: Array = []
	for member in session.party:
		var plain := member.duplicate(true)
		var stats := member.stats as CombatantStats
		var numbers: Dictionary = {}
		for field in STAT_INTS + ["oxygen", "oxygen_max"] + STAT_DICTS:
			numbers[field] = stats.get(field)
		plain.stats = numbers.duplicate(true)
		members.append(plain)
	data.campaign_scene = scene
	data.campaign_checkpoint = {"version": 1, "party": members, "maze": session.maze_snapshot.duplicate(true)}
	data.active = session.active
	data.inventory = session.inventory.duplicate(true)
	data.key_items = session.campaign_key_items.duplicate()
	data.random_encounters_enabled = session.random_encounters_enabled
	data.route_state = session.route_state.to_save_data()
	# The positions remain the last outer-world positions, not maze coordinates.
	if not data.has("divers"):
		data.divers = []
		for i in range(members.size()):
			data.divers.append({"position": CampaignSession.vector_data(World.CAST[i].at),
				"stats": {}, "known_spells": [], "equipped_spells": []})
	for i in range(members.size()):
		var snapshot: Dictionary = data.divers[i]
		snapshot.stats = members[i].stats.duplicate(true)
		snapshot.known_spells = members[i].known_spells.duplicate()
		snapshot.equipped_spells = members[i].equipped_spells.duplicate()
		snapshot.sonar_active = members[i].sonar_active
	return data

static func decode(data: Dictionary) -> CampaignSession:
	if data.get("campaign_scene") not in ["world", "maze"] or not data.get("campaign_checkpoint") is Dictionary:
		return null
	if not data.get("route_state") is Dictionary or data.route_state.get("prologue_complete") != true:
		return null
	var checkpoint: Dictionary = data.campaign_checkpoint
	if checkpoint.get("version") != 1 or not checkpoint.get("party") is Array or checkpoint.party.size() != 3:
		return null
	if not _integer(data.get("active"), 0, 2) or not _counts(data.get("inventory")) \
		or not _strings(data.get("key_items")) or not data.get("random_encounters_enabled") is bool \
		or not data.get("route_state") is Dictionary or not valid_maze(checkpoint.get("maze")):
		return null
	var session := CampaignSession.new()
	for i in range(3):
		var value: Variant = checkpoint.party[i]
		if not value is Dictionary or value.get("model") != MODELS[i] or not value.get("stats") is Dictionary:
			return null
		for field in ["sonar_active", "ability_locked"]:
			if not value.get(field) is bool:
				return null
		for field in ["sonar_drain_timer", "sonar_timer"]:
			if not _number(value.get(field)):
				return null
		for field in ["known_spells", "equipped_spells"]:
			if not _strings(value.get(field)):
				return null
			for spell in value[field]:
				if SpellTree.find_def(MODELS[i], String(spell)).is_empty():
					return null
		var numbers: Dictionary = value.stats
		for field in STAT_INTS:
			if not _integer(numbers.get(field), 0, 1_000_000):
				return null
		if int(numbers.hp_max) < 1 or int(numbers.hp) > int(numbers.hp_max) or int(numbers.level) < 1 \
			or int(numbers.xp_to_next) < 1 or not _number(numbers.get("oxygen_max"), 1, 1_000_000) \
			or not _number(numbers.get("oxygen"), 0, float(numbers.oxygen_max)):
			return null
		if not _effects(numbers):
			return null
		var member: Dictionary = value.duplicate(true)
		var stats := CombatantStats.new()
		for field in STAT_INTS + ["oxygen", "oxygen_max"]:
			stats.set(field, numbers[field])
		for field in STAT_DICTS:
			stats.set(field, (numbers[field] as Dictionary).duplicate(true))
		member.stats = stats
		session.party.append(member)
	session.active = int(data.active)
	for item in data.inventory:
		session.inventory[item] = int(data.inventory[item])
	session.campaign_key_items.assign(data.key_items)
	session.random_encounters_enabled = data.random_encounters_enabled
	session.route_state = RouteState.new()
	session.route_state.load_save_data(data.route_state)
	session.outer_world_checkpoint = data.duplicate(true)
	session.outer_world_checkpoint.erase("campaign_scene")
	session.outer_world_checkpoint.erase("campaign_checkpoint")
	session.maze_snapshot = checkpoint.maze.duplicate(true)
	return session

static func valid_maze(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not value.get("flags") is Dictionary:
		return false
	# Optional for old standalone saves; present metadata must be checked before
	# any live restore can translate part of the maze into a different frame.
	if value.has("coordinate_origin") and not MazeCoordinateFrame.valid_origin(value.coordinate_origin):
		return false
	for flag in MazeLevel.CAMPAIGN_FLAGS:
		if not value.flags.get(flag) is bool:
			return false
	if not _integer(value.get("keys_held"), 0, 1_000_000) or not _strings(value.get("key_items")) \
		or not _strings(value.get("boss_triggers")) or not _number(value.get("yaw")) or not _number(value.get("pitch")):
		return false
	if not value.get("walls") is Dictionary or value.walls.size() > 256 or value.walls.is_empty():
		return false
	for name in value.walls:
		var wall: Variant = value.walls[name]
		if not _node_name(name) or not wall is Dictionary or not _vector(wall.get("position")) \
			or not _vector(wall.get("rotation")) or not _vector(wall.get("size"), 0.001) \
			or not wall.get("visible") is bool or not wall.get("collision") is bool:
			return false
	for field in ["currents", "doors", "rocks", "orbs", "loose_keys", "posters", "positions", "levers", "broken_rocks"]:
		if not value.get(field) is Array or value[field].size() > 256:
			return false
	for spot in value.rocks + value.broken_rocks + value.positions:
		if not _vector(spot):
			return false
	if value.positions.size() != 3 or value.posters.size() != 3 or not _strings(value.doors):
		return false
	for current in value.currents:
		if not current is Dictionary or not _node_name(current.get("area")) \
			or not _vector(current.get("orientation")) or not _number(current.get("strength"), 0, 1000):
			return false
	for orb in value.orbs:
		if not orb is Dictionary or not orb.get("item") is String or not Items.ITEMS.has(orb.item) or not _vector(orb.get("position")):
			return false
		for flag in ["golden", "grappleable", "grapple_only"]:
			if not orb.get(flag) is bool:
				return false
	for key in value.loose_keys:
		if not key is Dictionary or not _vector(key.get("position")):
			return false
	var seen_divers: Array = []
	for poster in value.posters:
		if not poster is Dictionary or not _integer(poster.get("diver"), 0, 2) \
			or not _integer(poster.get("number"), 1, 3) or not poster.get("seen") is bool \
			or not _integer(poster.get("seed"), 0, 9_007_199_254_740_991):
			return false
		if not SwitchMinigameModal.POOLS[int(poster.diver)].has(poster.get("portrait")) or seen_divers.has(int(poster.diver)):
			return false
		seen_divers.append(int(poster.diver))
	for lever in value.levers:
		if not lever is Dictionary or not _integer(lever.get("lever"), 0, 1) or not _integer(lever.get("diver"), 0, 2):
			return false
	var homes: Variant = value.get("rotation_homes")
	if not homes is Dictionary or not _vector(homes.get("hallway_a")) or not _vector(homes.get("hallway_b")) \
		or not _number(homes.get("hallway_yaw_a")) or not _number(homes.get("hallway_yaw_b")):
		return false
	for field in ["walls_14_15", "walls_10_11"]:
		if not homes.get(field) is Array or homes[field].size() > 2:
			return false
		for home in homes[field]:
			if not home is Dictionary or not _node_name(home.get("wall")) or not value.walls.has(home.wall) \
				or not _vector(home.get("position")) or not _number(home.get("yaw")):
				return false
	if value.flags._walls_14_15_open and homes.walls_14_15.size() != 2:
		return false
	if value.flags._walls_10_11_swung and homes.walls_10_11.size() != 2:
		return false
	var map: Variant = value.get("map")
	if map is Dictionary and map.has("intro_seen") and not map.intro_seen is bool:
		return false
	if not map is Dictionary or not _strings(map.get("walls")) or not _strings(map.get("corridors")) \
		or not _strings(map.get("pois")) or not _integer(map.get("count"), 0, 256) \
		or not map.get("rooms") is Array or not map.get("halls") is Array or map.halls.size() > 256:
		return false
	for room in map.rooms:
		if not _integer(room, 0, MazeMiniMap.SECRET_ROOMS.size() - 1):
			return false
	for hall in map.halls:
		if not hall is Dictionary or not hall.get("name") is String or not _strings(hall.get("walls")) or not hall.get("corridor") is String:
			return false
	return true

static func _effects(stats: Dictionary) -> bool:
	for field in STAT_DICTS:
		if not stats.get(field) is Dictionary or stats[field].size() > 64:
			return false
	for status in stats.statuses:
		var entry: Variant = stats.statuses[status]
		if not status is String or not entry is Dictionary or not _integer(entry.get("level"), 1, 1_000_000) \
			or not _integer(entry.get("turns"), 0, 1_000_000):
			return false
	for field in ["accuracy", "evasion"]:
		if not _integer(stats.temporary_modifiers.get(field), -1_000_000, 1_000_000):
			return false
	return _counts(stats.stat_floor)

static func _number(value: Variant, lo := -1e8, hi := 1e8) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= lo and float(value) <= hi

static func _integer(value: Variant, lo: float, hi: float) -> bool:
	return _number(value, lo, hi) and float(value) == floorf(float(value))

static func _vector(value: Variant, lo := -1e8) -> bool:
	return value is Array and value.size() == 3 and value.all(func(n: Variant) -> bool: return _number(n, lo))

static func _strings(value: Variant) -> bool:
	return value is Array and value.size() <= 512 and value.all(func(v: Variant) -> bool: return v is String)

static func _counts(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 512:
		return false
	for key in value:
		if not key is String or not _integer(value[key], 0, 1_000_000):
			return false
	return true

static func _node_name(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 80 \
		and not value.contains("/") and not value.contains(".") and not value.contains(":")
