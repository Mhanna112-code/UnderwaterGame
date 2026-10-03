class_name DeepZoneLayout
extends RefCounted

# Shared spatial contract for the route beyond the existing ability puzzle.
# World placement, collision gates, encounter policy, and review tools read
# these values rather than growing separate coordinate lists.
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
const MAZE_TRANSITION := Vector3(125.0, 2.0, -34.0)

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
		MAZE_TRANSITION,
	])

func zone_for_position(position: Vector3) -> String:
	return "deep" if position.x >= DEEP_START_X else "shallows"
