# A grappleable version of maze_level.gd's golden energy orb - same
# glowing pickup, but a diver can lock onto it with the grapple ability
# (see diver.gd's _grapple()) and have IT travel to THEM, rather than the
# usual grapple_anchor.gd case of the diver traveling to a fixed target.
# _grapple() still pulls the diver toward this node's own position at the
# same time (that half is hardcoded there, not something this class can
# opt out of) - the two motions just happen in parallel, which reads fine
# for something small and light drifting the last stretch to meet you.
class_name GoldenOrbPickup
extends StaticBody3D

# Fired once, the frame this orb actually reaches whichever diver grappled
# it - maze_level.gd listens for this to spawn the ambush and show the
# reveal line, then this node frees itself right after emitting.
signal reached_diver(diver: Diver)

const TRAVEL_SPEED := 9.0
const ARRIVE_DIST := 0.4

var _diver: Diver
var _traveling := false
var _collision_shape: CollisionShape3D

func _ready() -> void:
	add_to_group("grapple_anchor")

	# Generous relative to the orb's own small visual size, same reasoning
	# as grapple_anchor.gd's own ring collider - a raycast is a single
	# line, so aiming "roughly at it" needs to still register as a hit.
	_collision_shape = CollisionShape3D.new()
	var col := SphereShape3D.new()
	col.radius = 0.6
	_collision_shape.shape = col
	add_child(_collision_shape)

# Called by diver.gd's _grapple() the instant a pull actually lands on
# this specific orb. Finds the diver by searching siblings rather than
# holding a reference up front - grapple_anchor.gd's own on_grappled_to()
# does the same, since this node is built long before it knows which
# Diver instances will exist alongside it.
func on_grappled_to() -> void:
	for sibling in get_parent().get_children():
		if sibling is Diver:
			_diver = sibling as Diver
			break
	_traveling = true
	# The raycast that found this orb needed a real solid CollisionShape3D
	# to hit (see _ready()) - but a StaticBody3D that stays solid while it
	# travels physically shoves the diver's CharacterBody3D out of the way
	# via move_and_slide() the moment their shapes touch, well before this
	# orb's own center gets anywhere near ARRIVE_DIST. That turned into a
	# feedback loop: the orb chases the diver's position, its collision
	# pushes the diver further away, the new position becomes the new
	# target, neither ever converges. The shape's only job was being
	# raycast-hittable at the moment of the grapple, which already
	# happened - disabling it now is what grapple_anchor.gd's anchors
	# avoid needing at all, since they never move.
	if _collision_shape != null:
		_collision_shape.disabled = true

func _process(dt: float) -> void:
	if not _traveling or _diver == null or not is_instance_valid(_diver):
		return
	var target: Vector3 = _diver.global_position + Vector3(0, _diver.height * 0.5, 0)
	global_position = global_position.move_toward(target, dt * TRAVEL_SPEED)
	if global_position.distance_to(target) < ARRIVE_DIST:
		reached_diver.emit(_diver)
		queue_free()
