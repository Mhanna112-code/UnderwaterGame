# A rock formation that only Diver.use_ability()'s "shockwave" case can
# clear. Doesn't know about Diver or abilities at all - it just joins the
# "shockwave_breakable" group and reacts if on_shockwave() lands within
# range, the same call_group broadcast any future ability-reactive object
# would use.
#
# `span` sizes it as a solid box, not a fixed small sphere - a single
# CrackedWall spanning a whole corridor's width and height (see
# world.gd's entrance blockade) reads as a genuine "nobody passes without
# shockwave" barrier, the same solidity as the corridor's own walls,
# rather than a scatter of small rocks with gaps a diver can just swim
# around or over.
class_name CrackedWall
extends StaticBody3D

# Emitted the instant this breaks (right before queue_free()) - world.gd
# listens for the small scattered pickup rocks (see _build_breakable_rocks)
# to hand out a potion's worth of HP. The entrance blockade doesn't connect
# anything to this, so breaking it just does nothing extra, same as before.
signal broken

# 0 means "no reward, just a barrier" - what the entrance blockade is.
# Anything above 0 is healed onto whichever diver's shockwave broke this,
# applied by world.gd's broken-signal handler (this script has no idea
# what a Diver's HP even is, on purpose - see cracked_wall.gd's own
# header comment on staying ability-agnostic).
@export var reward_hp := 0

@export var span := Vector3(2.0, 2.0, 2.0)

# Divers rise/sink freely in 3D (this is underwater, not gravity-bound
# walking) - a blockade whose collision only matches its visible height
# is just as swimmable-over as the corridor's own side walls are. 0 means
# "no taller than what's visible" (the small standalone-rock default);
# world.gd's entrance blockade sets this well above what anyone would
# bother swimming up to clear. The extra height is invisible - only the
# collision extends up, not the mesh - and it breaks together with the
# visible rocks, since it's one StaticBody3D, not a separate object that
# could be left behind once the rocks are gone.
@export var collision_height := 0.0

# Same idea, sideways: the corridor's own side walls only run the
# corridor's length, with nothing capping their outer ends - a diver can
# swim wide around the outside of the whole corridor structure from the
# open dive site and cut back in past the entrance blockade entirely. 0
# means "no wider than what's visible."
@export var collision_width := 0.0

var _mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("shockwave_breakable")

	var box := BoxMesh.new()
	box.size = span
	_mesh = MeshInstance3D.new()
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	# Visibly different from the scenery rocks in world.gd - a player
	# should be able to tell "this one's a kind of thing" before they have
	# any ability that reacts to it.
	mat.albedo_color = Color(0.42, 0.22, 0.14)
	mat.roughness = 0.9
	_mesh.material_override = mat
	add_child(_mesh)

	var col_size: Vector3 = span
	if collision_height > span.y:
		col_size.y = collision_height
	if collision_width > span.z:
		col_size.z = collision_width

	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = col_size
	shape.shape = col
	# Extra height extends upward from the visible rocks, not centered on
	# them - centering would sink half the invisible extension underground
	# instead of putting all of it above where anyone could swim over. The
	# Z extension is centered, though - it should reach equally past both
	# sides of the corridor, not favor one.
	shape.position.y = (col_size.y - span.y) * 0.5
	add_child(shape)

# Distance to the closest point on the *visible* box, not the (possibly
# much taller) collision one - breaking should be about how close the
# blast lands to the rocks a player can actually see and aim at, not
# require reaching up into the invisible ceiling extension to register.
func on_shockwave(from_position: Vector3, radius: float) -> void:
	var half: Vector3 = span * 0.5
	var local_from: Vector3 = to_local(from_position)
	var closest := Vector3(
		clampf(local_from.x, -half.x, half.x),
		clampf(local_from.y, -half.y, half.y),
		clampf(local_from.z, -half.z, half.z)
	)
	if local_from.distance_to(closest) <= radius:
		broken.emit()
		queue_free()
