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
# > 0: the suction zone is a cylinder this tall (can't be swum over).
@export var suction_height := 0.0
# Divers within pull_radius (horizontally) get dragged toward the centre at
# up to pull_speed, strongest close in. 0 = no drag.
@export var pull_radius := 0.0
@export var pull_speed := 0.0
@export var pull_duration := 1.4
# The pull is a spiral: this many turns around the centre on the way in,
# the diver spinning and rolling as they go, sinking this far as they reach
# it ("spun down").
@export var spin_turns := 2.0
@export var sink_depth := 2.2
@export var vanish_duration := 0.35

var armed := true

# "Danger: Whirlpool ahead" - one shared orange caption at the bottom centre
# of the screen (World's banner style, one line above it), shown for as long as a
# diver is inside ANY whirlpool's warning_radius and hidden once none is.
# Owned by the whirlpools themselves so it behaves the same in every scene
# (the opening blockade, the maze, ...).
const WARNING_TEXT := "Danger: Whirlpool ahead"
const WARNING_COLOR := Color(1.0, 0.6, 0.45)
static var _warning_caption: Label
static var _warning_whirlpools: Dictionary = {}   # Whirlpool -> true while a diver is inside its warning radius
var _divers_in_warning: Dictionary = {}           # Diver -> true
# Optional: returns true when something (e.g. a current running through
# this whirlpool) carries the diver past it, so suction doesn't catch them.
var bypass: Callable
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
	if suction_height > 0.0:
		var cyl := CylinderShape3D.new()
		cyl.radius = suction_radius
		cyl.height = suction_height
		suck_shape.shape = cyl
	else:
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
	_divers_in_warning[body] = true
	_update_warning_caption()
	warned.emit()

func _on_warning_exited(body: Node3D) -> void:
	if body is Diver:
		_divers_in_warning.erase(body)
		_warned_now = not _divers_in_warning.is_empty()
		_update_warning_caption()

func _exit_tree() -> void:
	_divers_in_warning.clear()
	_update_warning_caption()

func _update_warning_caption() -> void:
	if _divers_in_warning.is_empty():
		_warning_whirlpools.erase(self)
	else:
		_warning_whirlpools[self] = true
	if _warning_caption == null or not is_instance_valid(_warning_caption):
		if _warning_whirlpools.is_empty() or not is_inside_tree():
			return
		_build_warning_caption()
	_warning_caption.visible = not _warning_whirlpools.is_empty()

func _build_warning_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var label := Label.new()
	label.text = WARNING_TEXT
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -320.0
	label.offset_right = 320.0
	# One line above World's banner slot (-170..-130), so an announcement
	# shown at the same time doesn't draw on top of this.
	label.offset_top = -210.0
	label.offset_bottom = -172.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", WARNING_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	# On the scene root so it outlives any one whirlpool; hidden whenever no
	# whirlpool has a diver nearby.
	get_tree().root.add_child.call_deferred(layer)
	_warning_caption = label

# The drag toward the centre, and a catch for anyone who ends up inside the
# suction zone without "entering" it (e.g. it was bypassed when they did).
func _physics_process(dt: float) -> void:
	if not armed or (bypass.is_valid() and bool(bypass.call())):
		return
	for body in _divers_in_warning.keys():
		var d := body as Diver
		if d == null or not is_instance_valid(d) or d.is_grappling() or d.is_suction_locked():
			continue
		var to_centre := global_position - d.global_position
		to_centre.y = 0.0
		var dist := to_centre.length()
		if dist <= suction_radius:
			_pull_in(d)
			continue
		if pull_radius <= 0.0 or dist > pull_radius:
			continue
		var strength := pull_speed * (0.35 + 0.65 * (1.0 - (dist - suction_radius) / maxf(pull_radius - suction_radius, 0.01)))
		d.move_and_collide(to_centre / dist * strength * dt)

func _on_suction_entered(body: Node3D) -> void:
	if not armed or not (body is Diver):
		return
	var d := body as Diver
	if d.is_grappling() or d.is_suction_locked():
		return
	if bypass.is_valid() and bool(bypass.call()):
		return
	_pull_in(d)

# Three visible beats, not one instant swap: pulled in (physically, the
# whole approach), vanish at the center (caught), then reappear at
# reset_to already flashing - "sucked in" as a real sequence rather than
# a hit that just teleports you.
func _pull_in(d: Diver) -> void:
	d.velocity = Vector3.ZERO
	d.set_suction_locked(true)
	var start := d.global_position
	var rel := start - global_position
	rel.y = 0.0
	var r0 := rel.length()
	var a0 := atan2(rel.z, rel.x)
	var yaw0 := d.rotation.y
	var tw := create_tween()
	tw.tween_method(func(f: float) -> void:
		var r := r0 * (1.0 - f)
		var a := a0 + f * spin_turns * TAU
		var p := global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.y = lerpf(start.y, global_position.y - sink_depth, f * f)
		d.global_position = p
		d.rotation.y = yaw0 + f * spin_turns * TAU * 2.0   # spinning
		if d.model != null:
			d.model.rotation.z = sin(f * PI * 4.0) * 0.7 * f   # twisting
		, 0.0, 1.0, pull_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: d.set_model_visible(false))
	tw.tween_interval(vanish_duration)
	tw.tween_callback(func() -> void:
		if d.model != null:
			d.model.rotation.z = 0.0
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
