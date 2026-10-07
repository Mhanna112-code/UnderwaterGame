class_name OpeningPrologueTrigger
extends RefCounted

const MOVEMENT_DISTANCE := 3.0
const MIN_EXPLORATION_SECONDS := 4.0
var _origin := Vector3.ZERO
var _previous := Vector3.ZERO
var _swimming_seconds := 0.0
var _fired := false

func reset(origin: Vector3) -> void:
	_origin = origin
	_previous = origin
	_swimming_seconds = 0.0
	_fired = false

func update(position: Vector3, delta: float, movement_requested: bool) -> bool:
	if _fired:
		return false
	var moved := Vector2(position.x, position.z).distance_to(
		Vector2(_previous.x, _previous.z)
	)
	_previous = position
	# Count only swim input that actually moved the diver horizontally.
	if not movement_requested or moved <= 0.00001:
		return false
	_swimming_seconds += maxf(0.0, delta)
	if _swimming_seconds < MIN_EXPLORATION_SECONDS:
		return false
	var horizontal_distance := Vector2(position.x, position.z).distance_to(
		Vector2(_origin.x, _origin.z)
	)
	if horizontal_distance < MOVEMENT_DISTANCE:
		return false
	_fired = true
	return true

func has_fired() -> bool:
	return _fired
