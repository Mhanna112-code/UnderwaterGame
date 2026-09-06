extends SceneTree

const VortexCollision = preload("res://game/vortex_collision.gd")

func _initialize() -> void:
	var radius := 0.35
	var first := VortexCollision.resolve_sphere_contact(
		Vector2(-0.2, 0.0), Vector2(2.0, 0.0),
		Vector2(0.2, 0.0), Vector2(-2.0, 0.0), radius)
	var second := VortexCollision.resolve_sphere_contact(
		Vector2(-0.2, 0.0), Vector2(-2.0, 0.0),
		Vector2(0.2, 0.0), Vector2(2.0, 0.0), radius)
	var separation := (first.second_position as Vector2) - (first.first_position as Vector2)
	var relative_velocity := (first.second_velocity as Vector2) - (first.first_velocity as Vector2)
	var first_clean := bool(first.impulse) and separation.length() >= radius * 2.0 and relative_velocity.dot(separation.normalized()) > 0.0
	var second_clean := not bool(second.impulse) and (second.first_velocity as Vector2).is_equal_approx(first.first_velocity as Vector2) and (second.second_velocity as Vector2).is_equal_approx(first.second_velocity as Vector2)
	if not first_clean:
		push_error("vortex contact: approaching pair receives one outward response — guards against pass-through")
		quit(1)
		return
	if not second_clean:
		push_error("vortex contact: separating overlap does not receive a second impulse — guards against double bounce")
		quit(1)
		return
	print("VORTEX COLLISION: clean")
	quit()
