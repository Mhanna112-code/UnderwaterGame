class_name OpeningPrologueTrigger
extends RefCounted

const MOVEMENT_DISTANCE := 3.0
const IDLE_SECONDS := 7.0

var _origin := Vector3.ZERO
var _elapsed := 0.0
var _fired := false

func reset(origin: Vector3) -> void:
	_origin = origin
	_elapsed = 0.0
	_fired = false

func update(position: Vector3, delta: float) -> bool:
	if _fired:
		return false
	_elapsed += maxf(0.0, delta)
	var horizontal_distance := Vector2(position.x, position.z).distance_to(
		Vector2(_origin.x, _origin.z)
	)
	if horizontal_distance < MOVEMENT_DISTANCE and _elapsed < IDLE_SECONDS:
		return false
	_fired = true
	return true

func has_fired() -> bool:
	return _fired
