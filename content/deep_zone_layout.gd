class_name DeepZoneLayout
extends RefCounted

# Shared coordinates for the route beyond the ability puzzle, read by placement, gates, encounters and tools.
const WORLD_MIN_X := -60.0
const WORLD_MAX_X := 230.0
const WORLD_HALF_Z := 60.0
const DEEP_START_X := 60.0

const ABILITY_EXIT := Vector3(49.0, 2.0, 10.0)
const DEEP_ENTRY := Vector3(68.0, 2.0, 10.0)
const DEEP_HUB := Vector3(90.0, 2.0, 10.0)
const BOMB_BOT := Vector3(120.0, 2.0, 16.0)
const SWORD_SLAYER := Vector3(145.0, 2.0, 16.0)
const LAB := Vector3(175.0, 2.0, 16.0)
# Rest stop inside the lab cave corridor: past Sword Slayer's exit volume
# (x<=151) and short of the lab entry trigger (x>=171).
const LAB_SAVE_POINT := Vector3(163.0, 2.0, 16.0)
# Maze approach beyond the lab; reaching it is not a victory gate.
const MAZE_TRANSITION := Vector3(215.0, 2.0, 16.0)
const MAZE_ORIGIN := Vector3(300.0, 0.0, 20.76271)
const MAZE_APPROACH_HALF_WIDTH := 4.0

func route_points() -> Dictionary:
	return {
		"ability_exit": ABILITY_EXIT,
		"deep_entry": DEEP_ENTRY,
		"bomb_bot": BOMB_BOT,
		"sword_slayer": SWORD_SLAYER,
		"lab": LAB,
		"maze_transition": MAZE_TRANSITION,
	}

func lab_route() -> PackedVector3Array:
	return PackedVector3Array([
		ABILITY_EXIT,
		Vector3(55.0, 2.0, 10.0),
		DEEP_ENTRY,
		DEEP_HUB,
		BOMB_BOT,
		SWORD_SLAYER,
		LAB,
	])

func maze_route() -> PackedVector3Array:
	return PackedVector3Array([
		ABILITY_EXIT,
		Vector3(55.0, 2.0, 10.0),
		DEEP_ENTRY,
		DEEP_HUB,
		Vector3(104.0, 2.0, -4.0),
		Vector3(200.0, 2.0, -4.0),
		MAZE_TRANSITION,
	])

func zone_for_position(position: Vector3) -> String:
	return "deep" if position.x >= DEEP_START_X else "shallows"

# 0..1 descent depth, shared by lighting/fog and verification.
func depth_factor_for_position(position: Vector3) -> float:
	return clampf(inverse_lerp(DEEP_START_X, LAB.x, position.x), 0.0, 1.0)

func allows_random_encounter(position: Vector3) -> bool:
	# Keep random enemies off progression beats and transition approaches.
	for area_value in _protected_areas():
		var area := area_value as Dictionary
		if _horizontal_distance(position, area.center as Vector3) <= float(area.radius):
			return false
	for corridor_value in _protected_corridors():
		var corridor := corridor_value as Dictionary
		if _distance_to_segment_xz(position, corridor.a as Vector3, corridor.b as Vector3) <= float(corridor.radius):
			return false
	return true

func _protected_areas() -> Array[Dictionary]:
	return [
		{"center": DEEP_ENTRY, "radius": 9.0},
		{"center": BOMB_BOT, "radius": 10.0},
		{"center": SWORD_SLAYER, "radius": 10.0},
		{"center": LAB, "radius": 18.0},
		{"center": MAZE_TRANSITION, "radius": 13.0},
	]

func _protected_corridors() -> Array[Dictionary]:
	return [
		{"a": ABILITY_EXIT, "b": DEEP_ENTRY, "radius": 7.0},
		{"a": DEEP_ENTRY, "b": DEEP_HUB, "radius": 7.0},
		{"a": DEEP_HUB, "b": BOMB_BOT, "radius": 7.0},
		{"a": BOMB_BOT, "b": LAB, "radius": 8.0},
		{"a": DEEP_HUB, "b": Vector3(104.0, 2.0, -4.0), "radius": 7.0},
		{"a": Vector3(104.0, 2.0, -4.0), "b": Vector3(200.0, 2.0, -4.0), "radius": 7.0},
		{"a": Vector3(200.0, 2.0, -4.0), "b": MAZE_TRANSITION, "radius": 7.0},
		{"a": MAZE_TRANSITION, "b": Vector3(270.0, 2.0, 16.0), "radius": 7.0},
	]

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _distance_to_segment_xz(point: Vector3, a: Vector3, b: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var start := Vector2(a.x, a.z)
	var finish := Vector2(b.x, b.z)
	var delta := finish - start
	if delta.length_squared() <= 0.0001:
		return p.distance_to(start)
	var t := clampf((p - start).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return p.distance_to(start + delta * t)
