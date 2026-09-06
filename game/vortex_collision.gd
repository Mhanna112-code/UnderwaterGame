# Stateless equal-mass contact math for Grapple Intercept's colored vortex.
# It deliberately knows nothing about Area3D: Godot identifies candidate
# overlaps, while this code decides whether that overlap represents a real
# approaching impact or a pair already moving apart.
class_name VortexCollision
extends RefCounted

const CONTACT_EPSILON := 0.001
const RESTITUTION := 1.0

static func resolve_sphere_contact(
		first_position: Vector2, first_velocity: Vector2,
		second_position: Vector2, second_velocity: Vector2,
		radius: float) -> Dictionary:
	var separation := second_position - first_position
	var distance := separation.length()
	var minimum_distance := radius * 2.0
	if distance >= minimum_distance:
		return {
			"first_position": first_position, "first_velocity": first_velocity,
			"second_position": second_position, "second_velocity": second_velocity,
			"impulse": false,
		}
	var normal := separation / distance if distance > CONTACT_EPSILON else (first_velocity - second_velocity).normalized()
	if normal.length_squared() < CONTACT_EPSILON:
		normal = Vector2.RIGHT
	var correction := normal * ((minimum_distance - distance + CONTACT_EPSILON) * 0.5)
	var corrected_first := first_position - correction
	var corrected_second := second_position + correction
	var closing_speed := (first_velocity - second_velocity).dot(normal)
	if closing_speed <= 0.0:
		return {
			"first_position": corrected_first, "first_velocity": first_velocity,
			"second_position": corrected_second, "second_velocity": second_velocity,
			"impulse": false,
		}
	var impulse := normal * (closing_speed * (1.0 + RESTITUTION) * 0.5)
	return {
		"first_position": corrected_first, "first_velocity": first_velocity - impulse,
		"second_position": corrected_second, "second_velocity": second_velocity + impulse,
		"impulse": true,
	}
