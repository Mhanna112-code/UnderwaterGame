extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var approaching := VortexCollision.resolve_sphere_contact(
		Vector2(-0.2, 0.0), Vector2(1.0, 0.0),
		Vector2(0.2, 0.0), Vector2(-1.0, 0.0), 0.35)
	_check(bool(approaching.impulse), "vortex_collision: approaching spheres exchange outward velocity — guards against in-place overlap")
	_check((approaching.first_velocity as Vector2).x < 0.0 and (approaching.second_velocity as Vector2).x > 0.0, "vortex_collision: contact separates opposing spheres — guards against repeated reversal")
	_check((approaching.first_position as Vector2).distance_to(approaching.second_position as Vector2) >= 0.7, "vortex_collision: contact correction removes penetration — guards against sticky spheres")

	var separating := VortexCollision.resolve_sphere_contact(
		Vector2(-0.2, 0.0), Vector2(-1.0, 0.0),
		Vector2(0.2, 0.0), Vector2(1.0, 0.0), 0.35)
	_check(not bool(separating.impulse), "vortex_collision: separating overlap keeps outward velocity — guards against false bounce reversal")
	_check((separating.first_velocity as Vector2).is_equal_approx(Vector2(-1.0, 0.0)) and (separating.second_velocity as Vector2).is_equal_approx(Vector2(1.0, 0.0)), "vortex_collision: duplicate overlap tick does not cancel motion — guards against rotating in place")

	if failures.is_empty():
		print("VORTEX COLLISION: clean")
		quit()
	else:
		print("VORTEX COLLISION: failures %s" % str(failures))
		quit(1)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		push_error("FAIL: %s" % description)
		failures.append(description)
