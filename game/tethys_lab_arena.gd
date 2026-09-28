# Glass Goat's tall-ceiling room, assembled as a battle-stage environment.
#
# The source FBX is deliberately used only for the room shell. Broken_Office
# was delivered as a separate prop layout with a low roof and offsets that do
# not compose into Battle's centred coordinate system. Do not quietly add it
# here: that would put the boss back through a ceiling and scatter furniture
# into the combat lanes. Props belong in a separately reviewed layout pass.
class_name TethysLabArena
extends Node3D

const SHELL_PATH := "res://art/environments/Tallceiling.fbx"

# Tallceiling's imported footprint is offset from its FBX origin. This offset
# centres its measured interior on Battle's actor formation, whose boss and
# three divers are arranged around world origin.
const SHELL_OFFSET := Vector3(4.296, 0.0, 3.909)
const INTERIOR_SIZE := Vector3(13.42197, 7.05397, 10.94639)
const INTERIOR_HALF := Vector3(INTERIOR_SIZE.x * 0.5, INTERIOR_SIZE.y, INTERIOR_SIZE.z * 0.5)
const BOUNDARY_THICKNESS := 0.16

var _interior := AABB(
	Vector3(-INTERIOR_HALF.x, 0.0, -INTERIOR_HALF.z),
	INTERIOR_SIZE,
)

func _ready() -> void:
	name = "TethysLabArena"
	_build_shell()
	_build_boundaries()

# Public contract for battle verification and future encounter staging. The
# floor is at y=0; callers provide an actor origin, horizontal radius, and
# model height rather than guessing from an FBX's local axes.
func contains_combatant(origin: Vector3, radius: float, height: float) -> bool:
	var margin := maxf(0.0, radius)
	return origin.x - margin >= _interior.position.x \
		and origin.x + margin <= _interior.end.x \
		and origin.z - margin >= _interior.position.z \
		and origin.z + margin <= _interior.end.z \
		and origin.y >= _interior.position.y \
		and origin.y + maxf(0.0, height) <= _interior.end.y

func interior_bounds() -> AABB:
	return _interior

func _build_shell() -> void:
	# Runtime loading matters here: a new checkout imports a newly delivered
	# FBX after scripts are parsed. A preload made first open fail before the
	# importer had registered an FBX resource loader for this path.
	var packed := load(SHELL_PATH) as PackedScene
	if packed == null:
		push_error("TETHYS LAB ASSET MISSING: %s" % SHELL_PATH)
		return
	var shell := packed.instantiate() as Node3D
	shell.name = "TallCeilingShell"
	shell.position = SHELL_OFFSET
	add_child(shell)

func _build_boundaries() -> void:
	_add_boundary("FloorCollision", Vector3(INTERIOR_SIZE.x, BOUNDARY_THICKNESS, INTERIOR_SIZE.z), Vector3(0.0, -BOUNDARY_THICKNESS * 0.5, 0.0))
	_add_boundary("CeilingCollision", Vector3(INTERIOR_SIZE.x, BOUNDARY_THICKNESS, INTERIOR_SIZE.z), Vector3(0.0, INTERIOR_SIZE.y + BOUNDARY_THICKNESS * 0.5, 0.0))
	_add_boundary("WestWallCollision", Vector3(BOUNDARY_THICKNESS, INTERIOR_SIZE.y, INTERIOR_SIZE.z), Vector3(-INTERIOR_HALF.x - BOUNDARY_THICKNESS * 0.5, INTERIOR_SIZE.y * 0.5, 0.0))
	_add_boundary("EastWallCollision", Vector3(BOUNDARY_THICKNESS, INTERIOR_SIZE.y, INTERIOR_SIZE.z), Vector3(INTERIOR_HALF.x + BOUNDARY_THICKNESS * 0.5, INTERIOR_SIZE.y * 0.5, 0.0))
	_add_boundary("NorthWallCollision", Vector3(INTERIOR_SIZE.x, INTERIOR_SIZE.y, BOUNDARY_THICKNESS), Vector3(0.0, INTERIOR_SIZE.y * 0.5, -INTERIOR_HALF.z - BOUNDARY_THICKNESS * 0.5))
	_add_boundary("SouthWallCollision", Vector3(INTERIOR_SIZE.x, INTERIOR_SIZE.y, BOUNDARY_THICKNESS), Vector3(0.0, INTERIOR_SIZE.y * 0.5, INTERIOR_HALF.z + BOUNDARY_THICKNESS * 0.5))

func _add_boundary(boundary_name: String, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = boundary_name
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
