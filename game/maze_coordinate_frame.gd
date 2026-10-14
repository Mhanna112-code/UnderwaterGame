# Rebases maze snapshots between the legacy standalone origin and the embedded frame.
# The embedded layout translates children, not the root, so walls, party, rewards and homes share one frame.
class_name MazeCoordinateFrame
extends RefCounted

static func valid_origin(value: Variant) -> bool:
	return value is Array and value.size() == 3 and value.all(func(n: Variant) -> bool:
		return typeof(n) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(n)) and absf(float(n)) <= 1e8)

# Returns a validated copy, or {}; missing metadata means legacy origin. Only positions are translated.
static func rebase(source: Dictionary, destination: Vector3) -> Dictionary:
	var target := [destination.x, destination.y, destination.z]
	if not valid_origin(target) or not CampaignCheckpoint.valid_maze(source):
		return {}
	var prior: Array = source.get("coordinate_origin", [0.0, 0.0, 0.0])
	var shift := destination - Vector3(float(prior[0]), float(prior[1]), float(prior[2]))
	var data := source.duplicate(true)
	data.coordinate_origin = target
	for wall in data.walls.values():
		wall.position = _point(wall.position, shift)
	for field in ["positions", "rocks", "broken_rocks"]:
		for i in range(data[field].size()):
			data[field][i] = _point(data[field][i], shift)
	for field in ["orbs", "loose_keys"]:
		for reward in data[field]:
			reward.position = _point(reward.position, shift)
	if data.has("special_sites"):
		for site in data.special_sites:
			site.position = _point(site.position, shift)
	for field in ["hallway_a", "hallway_b"]:
		data.rotation_homes[field] = _point(data.rotation_homes[field], shift)
	for field in ["walls_14_15", "walls_10_11"]:
		for home in data.rotation_homes[field]:
			home.position = _point(home.position, shift)
	# Prevent otherwise-valid extreme offsets from producing an unusable save.
	return data if CampaignCheckpoint.valid_maze(data) else {}

static func _point(value: Array, shift: Vector3) -> Array:
	return [float(value[0]) + shift.x, float(value[1]) + shift.y, float(value[2]) + shift.z]
