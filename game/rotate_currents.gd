# Moves a single WaterCurrent between different corridors over time,
# rotating its flow direction 90 degrees each time it relocates - the
# same current visits several WindCorridors in turn rather than each
# corridor having its own fixed, permanent one (see maze_level.gd's own
# _setup_currents()/change_corridor_direction() for that separate,
# static, individually-addressable case).
class_name RotateCurrents
extends Node3D

var markers: Array[Marker3D] = []
var _current: WaterCurrent
var _current_dir: WaterCurrent.Direction = WaterCurrent.Direction.POSITIVE_Z

func _ready() -> void:
	for child in get_children():
		if child is Marker3D:
			markers.append(child)
	_current = WaterCurrent.new()
	add_child(_current)

# Rotates a flow direction 90 degrees clockwise (viewed from above) through
# this fixed cycle: NEGATIVE_Z -> NEGATIVE_X -> POSITIVE_Z -> POSITIVE_X ->
# back to NEGATIVE_Z. Four steps always returns to where it started.
static func _rotate_right(dir: WaterCurrent.Direction) -> WaterCurrent.Direction:
	match dir:
		WaterCurrent.Direction.NEGATIVE_Z:
			return WaterCurrent.Direction.NEGATIVE_X
		WaterCurrent.Direction.NEGATIVE_X:
			return WaterCurrent.Direction.POSITIVE_Z
		WaterCurrent.Direction.POSITIVE_Z:
			return WaterCurrent.Direction.POSITIVE_X
		WaterCurrent.Direction.POSITIVE_X:
			return WaterCurrent.Direction.NEGATIVE_Z
	return dir

# The exact reverse of _rotate_right() above - same four directions, same
# cycle, walked the other way around: NEGATIVE_Z -> POSITIVE_X ->
# POSITIVE_Z -> NEGATIVE_X -> back to NEGATIVE_Z.
static func _rotate_left(dir: WaterCurrent.Direction) -> WaterCurrent.Direction:
	match dir:
		WaterCurrent.Direction.NEGATIVE_Z:
			return WaterCurrent.Direction.POSITIVE_X
		WaterCurrent.Direction.POSITIVE_X:
			return WaterCurrent.Direction.POSITIVE_Z
		WaterCurrent.Direction.POSITIVE_Z:
			return WaterCurrent.Direction.NEGATIVE_X
		WaterCurrent.Direction.NEGATIVE_X:
			return WaterCurrent.Direction.NEGATIVE_Z
	return dir

# Moves the current to `new_area` - which corridor is always up to the
# caller, never picked automatically - rotating its own flow direction 90
# degrees in the same move via _rotate_right() (turn_right = true, the
# default) or _rotate_left() (turn_right = false).
#
# WaterCurrent.setup() calls teardown() on itself first, so the old
# Area3D's body_entered/body_exited get disconnected and its debug
# visual/bubble stream get freed automatically - this never leaves two
# corridors pushing divers at once.
func change_corridor(new_area: Area3D, turn_right: bool = true) -> void:
	_current_dir = _rotate_right(_current_dir) if turn_right else _rotate_left(_current_dir)
	_current.setup(new_area, WaterCurrent.direction_to_vector(_current_dir), 3.0, false)
