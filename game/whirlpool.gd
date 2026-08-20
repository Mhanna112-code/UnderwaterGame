# The actual teeth behind "a gap you must grapple (or swap) across": in a
# swimming game, an empty floor isn't a barrier - nothing stops a diver
# from just swimming over or through it in 3D. This replaces a plain
# instant-reset hazard with something that reads as a real place: a warned
# approach, a suction pull you can't swim against once caught, then the
# consequence - not just "bump an invisible wall and pop back."
#
# Two concentric zones, not one:
#   - warning_radius: crossing in announces the danger once, resets so it
#     can fire again if you leave and come back. Doesn't touch the diver.
#   - suction_radius: crossing in actually catches them - movement locks
#     (set_suction_locked, same mechanism grapple's own pull tween uses),
#     they're pulled to the whirlpool's center over pull_duration, then
#     swept back to reset_to, docked HP (floored, never a knockout, same
#     policy as before), and flashed.
# Mid-grapple divers are exempt at the suction radius (the intended
# crossing method shouldn't itself trigger the hazard it's supposed to
# bypass) - there's no equivalent check needed for swap, since swap moves
# a diver in a single instant frame rather than passing through space.
class_name Whirlpool
extends Node3D

signal warned
signal diver_sucked_in(d: Diver, amount: int)

@export var reset_to := Vector3.ZERO
@export var damage_min := 5
@export var damage_max := 10
@export var warning_radius := 9.0
@export var suction_radius := 3.0
@export var pull_duration := 0.7
@export var vanish_duration := 0.35

var armed := true
var _warned_now := false

func _ready() -> void:
	var warn_area := Area3D.new()
	var warn_shape := CollisionShape3D.new()
	var warn_col := SphereShape3D.new()
	warn_col.radius = warning_radius
	warn_shape.shape = warn_col
	warn_area.add_child(warn_shape)
	# Divers sit on collision layer 2 (see diver.gd - they don't collide
	# with each other, only the environment on layer 1). An Area3D's
	# default collision_mask only watches layer 1, so without this it
	# would never notice a diver at all.
	warn_area.collision_mask = 2
	warn_area.body_entered.connect(_on_warning_entered)
	warn_area.body_exited.connect(_on_warning_exited)
	add_child(warn_area)

	var suck_area := Area3D.new()
	var suck_shape := CollisionShape3D.new()
	var suck_col := SphereShape3D.new()
	suck_col.radius = suction_radius
	suck_shape.shape = suck_col
	suck_area.add_child(suck_shape)
	suck_area.collision_mask = 2
	suck_area.body_entered.connect(_on_suction_entered)
	add_child(suck_area)

	_build_visual()

# A dark, slowly spinning ring - distinct from the old flat "void" patch,
# reads as something actively dangerous rather than just an empty patch
# of floor.
func _build_visual() -> void:
	var mesh_inst := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = suction_radius * 0.3
	ring.outer_radius = suction_radius * 0.95
	mesh_inst.mesh = ring
	mesh_inst.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.08, 0.12)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	mesh_inst.position.y = 0.04
	add_child(mesh_inst)

	var tw := create_tween().set_loops()
	tw.tween_property(mesh_inst, "rotation:y", TAU, 4.0).from(0.0)

func _on_warning_entered(body: Node3D) -> void:
	if not (body is Diver):
		return
	_warned_now = true
	warned.emit()

func _on_warning_exited(body: Node3D) -> void:
	if body is Diver:
		_warned_now = false

func _on_suction_entered(body: Node3D) -> void:
	if not armed or not (body is Diver):
		return
	var d := body as Diver
	if d.is_grappling() or d.is_suction_locked():
		return
	_pull_in(d)

# Three visible beats, not one instant swap: pulled in (physically, the
# whole approach), vanish at the center (caught), then reappear at
# reset_to already flashing - "sucked in" as a real sequence rather than
# a hit that just teleports you.
func _pull_in(d: Diver) -> void:
	d.velocity = Vector3.ZERO
	d.set_suction_locked(true)
	var tw := create_tween()
	tw.tween_property(d, "global_position", global_position, pull_duration)
	tw.tween_callback(func() -> void: d.set_model_visible(false))
	tw.tween_interval(vanish_duration)
	tw.tween_callback(func() -> void:
		var before: int = d.stats.hp
		var dmg: int = randi_range(damage_min, damage_max)
		d.stats.hp = maxi(1, d.stats.hp - dmg)   # a scare, never a knockout
		var lost: int = before - d.stats.hp
		d.global_position = reset_to
		d.set_model_visible(true)
		d.set_suction_locked(false)
		d.flash_damage()
		diver_sucked_in.emit(d, lost)
	)
