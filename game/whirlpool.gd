# Whirlpool hazard guarding a grapple/swap gap: warning_radius announces it,
# suction_radius locks the diver, spirals them in, then returns them to reset_to with HP docked (never a knockout).
# Mid-grapple divers are exempt from suction.
class_name Whirlpool
extends Node3D

# Reading retains the pending catch; leaving exploration retires it.
enum Activity { EXPLORING, SUSPENDED, INACTIVE }

signal warned
signal diver_sucked_in(d: Diver, amount: int)

@export var reset_to := Vector3.ZERO
@export var damage_min := 5
@export var damage_max := 10
@export var warning_radius := 9.0
@export var suction_radius := 3.0
# > 0: the suction zone is a cylinder this tall (can't be swum over).
@export var suction_height := 0.0
# Horizontal drag toward the centre at up to pull_speed, strongest close in. 0 = none.
@export var pull_radius := 0.0
@export var pull_speed := 0.0
@export var pull_duration := 1.4
# Spiral pull: turns around the centre, sinking as the diver reaches it.
@export var spin_turns := 2.0
@export var sink_depth := 2.2
@export var vanish_duration := 0.35
@export var deep_hole_radius := 0.0
# Spit the diver out beside the whirlpool (random spot on the side they came
# from, clear of walls and every whirlpool's pull) instead of at reset_to.
# reset_to stays the fallback when no nearby spot is clear.
@export var return_nearby := true
# Draw the swirl on the seafloor (y≈0), clear of the grapple sightline.
@export var floor_visual := false
# Bouncing particle column inside the suction area (whirlpool_column.gd).
# Off for now: work in progress, whirlpools keep their original look.
@export var column_visual := false
const DEEP_SHAFT_DEPTH := 9.0

var armed := true

# Shared bottom-centre caption, shown while a diver is inside any whirlpool's warning_radius.
const WARNING_TEXT := "Danger: Whirlpool ahead"
const WARNING_COLOR := Color(1.0, 0.6, 0.45)
static var _warning_caption: Label
static var _battle_running := false

static func set_battle_running(on: bool) -> void:
	_battle_running = on
	if is_instance_valid(_warning_caption):
		_warning_caption.visible = not _warning_whirlpools.is_empty() and not on
static var _warning_whirlpools: Dictionary = {}   # Whirlpool -> true while a diver is inside its warning radius
var _divers_in_warning: Dictionary = {}           # Diver -> true
# Optional: returns true when something (e.g. a current) carries the diver past suction.
var bypass: Callable
var _warned_now := false
# Actors are shared with World; a tween dying with this node must not leave its lock behind.
var _motions: Dictionary = {} # instance ID -> weak actor and owned motion
var _released: Dictionary = {} # returned actor waits to leave the core
var _return_boxes: Array[Dictionary] = []
var _activity := Activity.EXPLORING

func _ready() -> void:
	add_to_group("whirlpool_hazards")
	# Watch ownership while paused; physical effects still require EXPLORING.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var warn_area := Area3D.new()
	var warn_shape := CollisionShape3D.new()
	var warn_col := SphereShape3D.new()
	warn_col.radius = warning_radius
	warn_shape.shape = warn_col
	warn_area.add_child(warn_shape)
	# Divers are on collision layer 2.
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
	if column_visual:
		var column := preload("res://game/whirlpool_column.gd").new()
		column.name = "WhirlpoolColumn"
		column.setup(suck_shape.shape)
		suck_area.add_child(column)

	_build_visual()

# Floor-aligned current ring; an upright torus would block the grapple aim view.
func _build_visual() -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "WhirlpoolVisual"
	var ring := TorusMesh.new()
	ring.inner_radius = suction_radius * 0.3
	ring.outer_radius = suction_radius * 0.95
	mesh_inst.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.32, 0.42, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.42, 0.55)
	mat.emission_energy_multiplier = 0.65
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	mesh_inst.position.y = 0.04
	if floor_visual:
		mesh_inst.position.y = 0.1 - position.y
		mat.albedo_color = Color(0.05, 0.42, 0.55, 0.95)
		mat.emission = Color(0.1, 0.6, 0.75)
		mat.emission_energy_multiplier = 1.4
		# Arms make the symmetric torus's rotation visible.
		var arm_mat := StandardMaterial3D.new()
		arm_mat.albedo_color = Color(0.7, 0.95, 1.0)
		arm_mat.emission_enabled = true
		arm_mat.emission = Color(0.55, 0.9, 1.0)
		arm_mat.emission_energy_multiplier = 1.6
		arm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for k in 3:
			for seg in 3:
				var arm := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(suction_radius * 0.3, 0.12, 0.14)
				arm.mesh = box
				arm.material_override = arm_mat
				var angle := TAU * k / 3.0 + seg * 0.45
				var r := suction_radius * (0.35 + seg * 0.22)
				arm.position = Vector3(cos(angle) * r, 0.08, sin(angle) * r)
				arm.rotation.y = -angle - PI * 0.35
				mesh_inst.add_child(arm)
	add_child(mesh_inst)

	var tw := create_tween().set_loops()
	tw.tween_property(mesh_inst, "rotation:y", TAU, 4.0).from(0.0)
	if deep_hole_radius > 0.0:
		ring.inner_radius = deep_hole_radius * 0.92
		ring.outer_radius = deep_hole_radius * 1.12
		tw.set_speed_scale(2.0)
		_build_deep_shaft()
		_build_down_current()

func _build_deep_shaft() -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = deep_hole_radius
	tube.bottom_radius = deep_hole_radius * 0.7
	tube.height = DEEP_SHAFT_DEPTH
	tube.cap_top = false
	tube.radial_segments = 24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.06, 0.11)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shaft := MeshInstance3D.new()
	shaft.mesh = tube
	shaft.material_override = mat
	shaft.position.y = -DEEP_SHAFT_DEPTH * 0.5
	add_child(shaft)

# Pale streaks spiralling down into the hole.
func _build_down_current() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = deep_hole_radius * 1.8
	pm.emission_ring_inner_radius = deep_hole_radius * 0.6
	pm.emission_ring_height = 1.6
	pm.direction = Vector3.DOWN
	pm.spread = 8.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, -4.0, 0)
	pm.radial_accel_min = -2.5   # drawn in toward the middle
	pm.radial_accel_max = -1.5
	pm.tangential_accel_min = 3.0   # and around it
	pm.tangential_accel_max = 4.5
	pm.particle_flag_align_y = true
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(0.75, 0.92, 1.0, 0.0))
	fade.set_color(1, Color(0.75, 0.92, 1.0, 0.0))
	fade.add_point(0.15, Color(0.75, 0.92, 1.0, 0.75))
	fade.add_point(0.75, Color(0.55, 0.8, 1.0, 0.5))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp

	var streak := BoxMesh.new()
	streak.size = Vector3(0.035, 0.45, 0.035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	streak.material = mat

	var current := GPUParticles3D.new()
	current.amount = 90
	current.lifetime = 1.8
	current.preprocess = 2.0
	current.process_material = pm
	current.draw_pass_1 = streak
	current.position.y = 0.9
	current.visibility_aabb = AABB(Vector3(-4, -DEEP_SHAFT_DEPTH - 1.0, -4), Vector3(8, DEEP_SHAFT_DEPTH + 4.0, 8))
	add_child(current)

func _on_warning_entered(body: Node3D) -> void:
	if not (body is Diver):
		return
	if not _within_radius(body as Diver, warning_radius, 0.0):
		return # A teleported body's cached physics overlap can be stale.
	_warned_now = true
	_divers_in_warning[body] = true
	refresh_activity()
	_update_warning_caption()
	if _activity == Activity.EXPLORING:
		warned.emit()

func _on_warning_exited(body: Node3D) -> void:
	if body is Diver:
		_divers_in_warning.erase(body)
		_warned_now = not _divers_in_warning.is_empty()
		_update_warning_caption()

func _exit_tree() -> void:
	cancel_motion()
	_divers_in_warning.clear()
	_update_warning_caption()

func busy() -> bool:
	return not _motions.is_empty()

static func cancel_in(scope: Node, preserve_positions := false) -> void:
	for hazard in scope.get_tree().get_nodes_in_group("whirlpool_hazards"):
		if scope.is_ancestor_of(hazard):
			(hazard as Whirlpool).cancel_motion(preserve_positions)

static func busy_in(scope: Node) -> bool:
	for hazard in scope.get_tree().get_nodes_in_group("whirlpool_hazards"):
		if scope.is_ancestor_of(hazard) and (hazard as Whirlpool).busy():
			return true
	return false

static func refresh_in(scope: Node) -> void:
	for hazard in scope.get_tree().get_nodes_in_group("whirlpool_hazards"):
		if scope.is_ancestor_of(hazard):
			(hazard as Whirlpool).refresh_activity()

func refresh_activity() -> void:
	var next := Activity.EXPLORING
	var owner := get_parent()
	while owner != null:
		if owner.has_method("whirlpool_activity"):
			next = owner.whirlpool_activity()
			break
		owner = owner.get_parent()
	if next == Activity.EXPLORING and get_tree().paused:
		next = Activity.SUSPENDED
	_activity = next
	if next == Activity.INACTIVE:
		cancel_motion()
	else:
		for record: Dictionary in _motions.values():
			var tween := record.tween as Tween
			if not tween.is_valid():
				continue
			if next == Activity.SUSPENDED and not bool(record.get("reading_pause", false)):
				tween.pause()
				record.reading_pause = true
			elif next == Activity.EXPLORING and bool(record.get("reading_pause", false)):
				tween.play()
				record.reading_pause = false
	_update_warning_caption()

# Call before applying loaded party poses or disabling the owning area.
# preserve_positions is for a caller that has already restored those poses.
func cancel_motion(preserve_positions := false) -> void:
	for id in _motions.keys():
		_cancel_motion(int(id), preserve_positions)

func _cancel_motion(id: int, preserve_positions := false) -> void:
	if not _motions.has(id):
		return
	var record: Dictionary = _motions[id]
	var tween := record.tween as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	var actor := (record.actor as WeakRef).get_ref() as Diver
	if is_instance_valid(actor):
		if not preserve_positions and actor.is_inside_tree():
			var landing: Variant = _clear_return(actor, record.start)
			if landing == null:
				push_error("Whirlpool cancellation has no clear recovery approach")
				return # Never advertise a buried actor as safely released.
			actor.global_position = landing
		_restore_actor(actor, record)
		_released[id] = weakref(actor)
	_motions.erase(id)

func _restore_actor(actor: Diver, record: Dictionary) -> void:
	actor.rotation = record.rotation
	if is_instance_valid(actor.model):
		actor.model.rotation = record.model_rotation
		actor.model.visible = bool(record.visible)
	actor.velocity = Vector3.ZERO
	actor.set_suction_locked(bool(record.locked))

# A clear spot just outside this whirlpool's reach, on the half the diver came
# from (so a whirlpool guarding a gap never lands you across it). Null if none.
func _nearby_landing(actor: Diver, came_from: Vector3) -> Variant:
	var reach := maxf(maxf(suction_radius, pull_radius), deep_hole_radius) + actor.radius + 1.0
	var away := came_from - global_position
	away.y = 0.0
	var base_angle := atan2(away.z, away.x) if away.length() > 0.05 else randf() * TAU
	var centre := Vector3(global_position.x, came_from.y, global_position.z)
	var space := get_world_3d().direct_space_state
	_refresh_return_boxes()
	for attempt in 32:
		var angle := base_angle + randf_range(-1.2, 1.2)
		var at := centre + Vector3(cos(angle), 0.0, sin(angle)) * (reach + randf_range(0.0, 1.5) + float(attempt) * 0.05)
		# Same room: nothing solid between the whirlpool and the spot.
		var ray := PhysicsRayQueryParameters3D.create(centre, at, 1)
		ray.exclude = [actor.get_rid()]
		if not space.intersect_ray(ray).is_empty():
			continue
		if _inside_any_whirlpool(at, actor.radius):
			continue
		if _fits_at(actor, at):
			return at
	return null

# True when `at` is within any whirlpool's suction, pull or hole (this one included).
func _inside_any_whirlpool(at: Vector3, margin: float) -> bool:
	for hazard in get_tree().get_nodes_in_group("whirlpool_hazards"):
		var w := hazard as Whirlpool
		var reach := maxf(maxf(w.suction_radius, w.pull_radius), w.deep_hole_radius) + margin + 0.3
		if Vector2(at.x - w.global_position.x, at.z - w.global_position.z).length() < reach:
			return true
	return false

# The diver's capsule fits at `at` without touching solids or being buried in a wall box.
func _fits_at(actor: Diver, at: Vector3) -> bool:
	var collision: CollisionShape3D
	for child in actor.get_children():
		if child is CollisionShape3D:
			collision = child
			break
	if collision == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	query.transform = Transform3D(actor.global_basis, at) * collision.transform
	return not _buried_in_box(query.transform.origin, actor) and actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _clear_return(actor: Diver, preferred: Vector3) -> Variant:
	var collision: CollisionShape3D
	for child in actor.get_children():
		if child is CollisionShape3D:
			collision = child
			break
	if collision == null:
		return null
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	var space := actor.get_world_3d().direct_space_state
	_refresh_return_boxes()
	# Recheck clearance; if blocked, prefer reset_to and nearby clear water.
	for origin in [preferred, reset_to]:
		for ring in range(21):
			for angle in range(1 if ring == 0 else 16):
				var at: Vector3 = origin + Vector3.RIGHT.rotated(Vector3.UP, TAU * angle / 16.0) * ring * 0.25
				query.transform = Transform3D(actor.global_basis, at) * collision.transform
				if not _buried_in_box(query.transform.origin, actor) and space.intersect_shape(query, 1).is_empty():
					return at
	return null

func _refresh_return_boxes() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var boxes := scene.find_children("*", "CSGBox3D", true, false)
	# An exiting maze's children may be off-tree; reuse the last live geometry.
	if boxes.any(func(box: Node) -> bool: return not box.is_inside_tree()):
		return
	_return_boxes.clear()
	for node in boxes:
		var box := node as CSGBox3D
		if not box.use_collision or box.operation != CSGShape3D.OPERATION_UNION or box.get_parent() is CSGShape3D:
			continue # Subtractive/composed children are not standalone solids.
		_return_boxes.append({"inverse": box.global_transform.affine_inverse(), "half": box.size * 0.5})

func _buried_in_box(center: Vector3, actor: Diver) -> bool:
	# Concave CSG misses a capsule wholly inside a box; test its volume too.
	var segment := maxf(actor.height * 0.5 - actor.radius, 0.0)
	for box in _return_boxes:
		var at: Vector3 = (box.inverse as Transform3D) * center
		var half: Vector3 = box.half
		var gap := Vector3(maxf(absf(at.x) - half.x, 0.0), maxf(absf(at.y) - half.y - segment, 0.0), maxf(absf(at.z) - half.z, 0.0))
		if gap.length_squared() < actor.radius * actor.radius:
			return true
	return false

func _update_warning_caption() -> void:
	for body in _divers_in_warning.keys():
		if not is_instance_valid(body) or not body.is_inside_tree() or not is_inside_tree() \
			or not _within_radius(body as Diver, warning_radius, 0.0):
			_divers_in_warning.erase(body)
	if _activity != Activity.EXPLORING or _divers_in_warning.is_empty():
		_warning_whirlpools.erase(self)
	else:
		_warning_whirlpools[self] = true
	if _warning_caption == null or not is_instance_valid(_warning_caption):
		if _warning_whirlpools.is_empty() or not is_inside_tree():
			return
		_build_warning_caption()
	_warning_caption.visible = not _warning_whirlpools.is_empty() and not _battle_running
	# Free the whole warning canvas when empty.
	var layer := _warning_caption.get_parent() as CanvasLayer
	if layer != null:
		layer.visible = _warning_caption.visible

func _build_warning_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var label := Label.new()
	label.text = WARNING_TEXT
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -320.0
	label.offset_right = 320.0
	# One line above World's banner slot (-170..-130).
	label.offset_top = -210.0
	label.offset_bottom = -172.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", WARNING_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	# On the scene root so it outlives any one whirlpool.
	get_tree().root.add_child.call_deferred(layer)
	_warning_caption = label

# Drag toward the centre, and catch anyone already inside the suction zone.
func _physics_process(dt: float) -> void:
	refresh_activity()
	if busy():
		_refresh_return_boxes()
	for id in _released.keys():
		var actor := (_released[id] as WeakRef).get_ref() as Diver
		if not is_instance_valid(actor) or Vector2(actor.global_position.x - global_position.x,
			actor.global_position.z - global_position.z).length() > suction_radius + actor.radius + 0.05:
			_released.erase(id)
	for id in _motions.keys():
		var record: Dictionary = _motions[id]
		var actor := (record.actor as WeakRef).get_ref() as Diver
		var tween := record.tween as Tween
		if not is_instance_valid(actor):
			if tween.is_valid():
				tween.kill()
			_motions.erase(id)
		elif not tween.is_valid():
			_cancel_motion(int(id)) # Killed scheduler, not a completed reset.
	if _activity != Activity.EXPLORING or not armed or (bypass.is_valid() and bool(bypass.call())):
		return
	for body in _divers_in_warning.keys():
		if not is_instance_valid(body):
			_divers_in_warning.erase(body)
			continue
		var d := body as Diver
		if d == null or not is_instance_valid(d) or d.exploration_paused or d.is_grappling() or d.is_suction_locked() or _released.has(d.get_instance_id()):
			continue
		if not _in_open_water_with(d):
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
	refresh_activity()
	if _activity != Activity.EXPLORING or not armed or not (body is Diver):
		return
	var d := body as Diver
	if not _within_radius(d, suction_radius, suction_height):
		return # Validate the current pose, not last frame's physics cache.
	if d.exploration_paused or d.is_grappling() or d.is_suction_locked() or _released.has(d.get_instance_id()):
		return
	if bypass.is_valid() and bool(bypass.call()):
		return
	if not _in_open_water_with(d):
		return
	_pull_in(d)

func _within_radius(d: Diver, zone_radius: float, zone_height: float) -> bool:
	var offset := d.global_position - global_position
	var horizontal := Vector2(offset.x, offset.z).length()
	var segment := maxf(d.height * 0.5 - d.radius, 0.0)
	var vertical := maxf(absf(offset.y) - segment, 0.0)
	if zone_height > 0.0:
		vertical = maxf(vertical - zone_height * 0.5, 0.0)
		return Vector2(maxf(horizontal - zone_radius, 0.0), vertical).length_squared() <= d.radius * d.radius
	return Vector2(horizontal, vertical).length_squared() <= pow(zone_radius + d.radius, 2)

# Only drag/catch a diver with open water to the centre at their own height.
func _in_open_water_with(d: Diver) -> bool:
	var centre := Vector3(global_position.x, d.global_position.y, global_position.z)
	var query := PhysicsRayQueryParameters3D.create(d.global_position, centre, 1)
	query.exclude = [d.get_rid()]
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

# Pulled in, vanish at the centre, reappear at reset_to flashing.
func _pull_in(d: Diver) -> void:
	_refresh_return_boxes()
	var id := d.get_instance_id()
	var record := {"actor": weakref(d), "start": d.global_position,
		"rotation": d.rotation, "model_rotation": d.model.rotation if is_instance_valid(d.model) else Vector3.ZERO,
		"visible": d.model.visible if is_instance_valid(d.model) else true,
		"locked": d.is_suction_locked()}
	d.velocity = Vector3.ZERO
	d.set_suction_locked(true)
	var start := d.global_position
	var rel := start - global_position
	rel.y = 0.0
	var r0 := rel.length()
	var a0 := atan2(rel.z, rel.x)
	var yaw0 := d.rotation.y
	var tw := create_tween()
	record.tween = tw
	_motions[id] = record
	tw.tween_method(func(f: float) -> void:
		var actor := (record.actor as WeakRef).get_ref() as Diver
		if not is_instance_valid(actor):
			return
		var r := r0 * (1.0 - f)
		var a := a0 + f * spin_turns * TAU
		var p := global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.y = lerpf(start.y, global_position.y - sink_depth, f * f)
		actor.global_position = p
		actor.rotation.y = yaw0 + f * spin_turns * TAU * 2.0   # spinning
		if is_instance_valid(actor.model):
			actor.model.rotation.z = sin(f * PI * 4.0) * 0.7 * f   # twisting
		, 0.0, 1.0, pull_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		var actor := (record.actor as WeakRef).get_ref() as Diver
		if is_instance_valid(actor):
			actor.set_model_visible(false)
	)
	tw.tween_interval(vanish_duration)
	tw.tween_callback(func() -> void:
		var actor := (record.actor as WeakRef).get_ref() as Diver
		if not is_instance_valid(actor):
			_motions.erase(id)
			return
		var landing: Variant = _nearby_landing(actor, record.start) if return_nearby else null
		if landing == null:
			landing = _clear_return(actor, reset_to)
		if landing == null:
			_cancel_motion(id)
			return
		var before: int = actor.stats.hp
		var dmg: int = randi_range(damage_min, damage_max)
		# Never revives a downed diver; floors living divers at 1 HP.
		actor.stats.hp = maxi(1, before - maxi(dmg, 0)) if before > 0 else 0
		var lost: int = before - actor.stats.hp
		actor.global_position = landing
		_restore_actor(actor, record)
		_motions.erase(id)
		# Let the returned actor leave the core before it can be caught again.
		_released[id] = weakref(actor)
		if lost > 0 and bool(record.visible):
			actor.flash_damage()
			BattleFx.flash(actor, BattleFx.DAMAGE_RED)   # red tint, as in battle
		diver_sucked_in.emit(actor, lost)
	)
