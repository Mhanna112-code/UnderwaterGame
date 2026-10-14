# Moves one WaterCurrent between corridors, rotating its flow 90 degrees each move.
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

# 90 degrees clockwise from above: -Z -> -X -> +Z -> +X -> -Z.
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

# Reverse of _rotate_right(): -Z -> +X -> +Z -> -X -> -Z.
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

# Moves the current to `new_area`, rotating right (default) or left.
# setup() tears down the old area first, so only one corridor pushes at once.
func change_corridor(new_area: Area3D, turn_right: bool = true) -> void:
	_current_dir = _rotate_right(_current_dir) if turn_right else _rotate_left(_current_dir)
	_current.setup(new_area, WaterCurrent.direction_to_vector(_current_dir), 3.0, false)
