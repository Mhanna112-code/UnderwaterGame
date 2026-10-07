# Musashi's special-encounter defense. Each vortex wave has two yellow and two
# green spheres; grapple both safe-color ones before the wave arrives or object_hit fires.
class_name GrappleInterceptMinigame
extends Control

signal finished(hits: int, total: int)
signal object_hit
# battle.gd logs this; the minigame also shows a central callout.
signal wave_started(safe_is_yellow: bool, wave_index: int, total_waves: int)

# Safe-color spheres per wave. Overall total is TARGET_COUNT * TOTAL_VORTEX_WAVES.
const TARGET_COUNT := 2
const TOTAL_VORTEX_WAVES := 3
const TITLE_HOLD := 0.8
const WAVE_CALLOUT_GRAPPLE_TIME := 0.16
const WAVE_CALLOUT_COLOR_TIME := 0.42
const WAVE_CALLOUT_NOW_TIME := 0.16

const FLIGHT_TIME := 6
const HIT_ANGLE := deg_to_rad(7.0)
const LOOK_SENSITIVITY := 0.0035
# Wide enough that every spawn direction is reachable by mouse-look.
const MAX_YAW := 1.0
const MAX_PITCH := 1.0

# Must stay past ENEMY_MOVE_MAX_DIST so the enemy is always in range.
const GRAPPLE_RANGE := 60.0
# Dedicated layers so the grapple ray only hits weak spots / vortex spheres.
const WEAK_SPOT_COLLISION_LAYER := 1 << 19
const VORTEX_COLLISION_LAYER := 1 << 20
# Sizes both the weak spot's mesh and its hitbox.
const WEAK_SPOT_RADIUS := 0.24

var stage_root: SubViewport
var stage_camera: Camera3D
var target_actor: Node3D
var source_position := Vector3.ZERO

# Set by battle.gd to _stage_container's rect (siblings, same coordinate space).
var stage_rect := Rect2()

# Set by battle.gd: the enemy Goblin, moved during the minigame. Required by run().
var enemy_actor: Node3D = null

# Enemy reposition distance band.
const ENEMY_MOVE_MIN_DIST := 30.0
const ENEMY_MOVE_MAX_DIST := 50.0

# Endpoints of the enemy's drift, fixed for the encounter.
var ENEMY_START := Vector3.ZERO
var ENEMY_END := Vector3.ZERO

# Enemy's original position. The drift tween lives on enemy_actor, so it must be
# killed and the enemy restored explicitly (_restore_enemy_home()).
var _enemy_home_position := Vector3.ZERO
var _enemy_drift_tween: Tween = null
# True only once run() has moved the enemy, so restore never snaps it to ZERO.
var _enemy_was_moved := false

# The single active weak spot on enemy_actor (dormant; run() is vortex-only).
var _active_weak_spot: Area3D = null

# Guards against emitting `finished` twice (natural finish and request_abort()).
var _did_finish := false

var _spawned := 0
var _resolved := 0
var _hits := 0
var _yaw := 0.0
var _pitch := 0.0
var _base_forward := Vector3.FORWARD
var _old_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _target_was_visible := true
var _start_button: Button
var _crosshair: Label
var _wave_callout: Label
var _wave_callout_tween: Tween
# Public so the regression harness can check the prompt matches the hit resolver.
var wave_instruction := ""
var _wave_callout_generation := 0
var _grapple_controls_active := false

func _ready() -> void:
	if stage_rect.size != Vector2.ZERO:
		# Match the 3D stage's rendered rect.
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = stage_rect.position
		size = stage_rect.size
	elif get_parent() is Control:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		size = get_viewport_rect().size
	# PASS so the web start button gets clicks; set to IGNORE once started.
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Safe color shown as steady text across the top of the stage for the whole wave.
	_wave_callout = Label.new()
	_wave_callout.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wave_callout.offset_left = -360.0
	_wave_callout.offset_top = 16.0
	_wave_callout.offset_right = 360.0
	_wave_callout.offset_bottom = 84.0
	_wave_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_callout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_callout.add_theme_font_size_override("font_size", 44)
	_wave_callout.add_theme_color_override("font_outline_color", Color(0.0, 0.04, 0.08, 1.0))
	_wave_callout.add_theme_constant_override("outline_size", 9)
	_wave_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_callout.z_index = 4096
	_wave_callout.z_as_relative = false
	_wave_callout.visible = false
	add_child(_wave_callout)

	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -22.0
	_crosshair.offset_top = -30.0
	_crosshair.offset_right = 22.0
	_crosshair.offset_bottom = 30.0
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.add_theme_font_size_override("font_size", 42)
	_crosshair.add_theme_color_override("font_color", Color(1.0, 0.95, 0.25))
	_crosshair.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 1.0))
	_crosshair.add_theme_constant_override("outline_size", 4)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Draw above the other Battle HUD controls.
	_crosshair.z_index = 4095
	_crosshair.z_as_relative = false
	add_child(_crosshair)

	_start_button = Button.new()
	_start_button.text = "CLICK TO START PLAYTEST"
	_start_button.set_anchors_preset(Control.PRESET_CENTER)
	_start_button.offset_left = -170.0
	_start_button.offset_top = 70.0
	_start_button.offset_right = 170.0
	_start_button.offset_bottom = 122.0
	_start_button.add_theme_font_size_override("font_size", 20)
	_start_button.visible = false
	add_child(_start_button)

func run() -> void:
	if stage_camera == null or target_actor == null or stage_root == null or enemy_actor == null or not is_instance_valid(enemy_actor):
		push_error("GrappleInterceptMinigame requires stage_root, stage_camera, target_actor, and enemy_actor")
		finished.emit(0, TARGET_COUNT * TOTAL_VORTEX_WAVES)
		return
	_old_mouse_mode = Input.mouse_mode
	# Web: wait for a real click and keep the cursor visible (targets stay in a
	# reachable cone, so no Pointer Lock needed).
	if OS.has_feature("web"):
		_start_button.visible = true
		await _start_button.pressed
		_start_button.visible = false
		_crosshair.visible = false # browser pointer is the reticle
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_was_visible = target_actor.visible
	target_actor.visible = false
	var eye := target_actor.global_position + Vector3(0.0, (target_actor as Diver).height * 0.4, 0.0)
	_base_forward = (source_position - eye).normalized()
	stage_camera.global_position = eye
	# Stage the attacker far away for a visible approach, keeping the source offset;
	# restored when the minigame ends.
	_enemy_home_position = enemy_actor.global_position
	var enemy_source_offset := source_position - _enemy_home_position
	var horizontal_forward := Vector3(_base_forward.x, 0.0, _base_forward.z).normalized()
	if horizontal_forward.length_squared() < 0.001:
		horizontal_forward = Vector3.FORWARD
	_enemy_was_moved = true
	enemy_actor.global_position = target_actor.global_position + horizontal_forward * VORTEX_ENEMY_DISTANCE
	source_position = enemy_actor.global_position + enemy_source_offset
	_base_forward = (source_position - eye).normalized()
	stage_camera.look_at(eye + _base_forward * 10.0, Vector3.UP)
	await get_tree().create_timer(TITLE_HOLD).timeout
	_grapple_controls_active = true
	launch_vortex()


# Random direction in the reachable yaw/pitch cone, using _update_camera()'s rotation order.
func _random_cone_direction() -> Vector3:
	var yaw := randf_range(-MAX_YAW, MAX_YAW)
	var pitch := randf_range(-MAX_PITCH, MAX_PITCH)
	var dir := _base_forward.rotated(Vector3.UP, yaw)
	var right := dir.cross(Vector3.UP).normalized()
	return dir.rotated(right, pitch).normalized()

# Leg time for _drift_enemy()'s ping-pong between ENEMY_START and ENEMY_END.
const ENEMY_DRIFT_LEG_TIME := 3.5

func _drift_enemy() -> void:
	if enemy_actor == null or not is_instance_valid(enemy_actor):
		return
	_enemy_drift_tween = enemy_actor.create_tween()
	_enemy_drift_tween.set_loops()
	_enemy_drift_tween.tween_property(enemy_actor, "global_position", ENEMY_END, ENEMY_DRIFT_LEG_TIME)
	_enemy_drift_tween.tween_property(enemy_actor, "global_position", ENEMY_START, ENEMY_DRIFT_LEG_TIME)

func _exit_tree() -> void:
	Input.mouse_mode = _old_mouse_mode
	if target_actor != null and is_instance_valid(target_actor):
		target_actor.visible = _target_was_visible
	# Safety net; _restore_enemy_home() is idempotent.
	_restore_enemy_home()

func _input(event: InputEvent) -> void:
	if not _grapple_controls_active:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not OS.has_feature("web"):
			_yaw = clampf(_yaw - motion.relative.x * LOOK_SENSITIVITY, -MAX_YAW, MAX_YAW)
			_pitch = clampf(_pitch - motion.relative.y * LOOK_SENSITIVITY, -MAX_PITCH, MAX_PITCH)
			_update_camera()
		# Web uses the cursor as reticle (no camera rotation). Consume the event so HUD
		# controls don't; only active during this minigame.
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		# Misses still belong to the minigame; don't let clicks reach controls behind it.
		get_viewport().set_input_as_handled()
		if OS.has_feature("web"):
			_grapple_at_web_pointer((event as InputEventMouseButton).position)
		else:
			_grapple()

func _grapple_at_web_pointer(pointer_position: Vector2) -> void:
	var rect := stage_rect
	if rect.size == Vector2.ZERO:
		rect = get_global_rect()
	if not rect.has_point(pointer_position) or stage_root == null:
		return
	# Map the on-screen stage coordinate into the SubViewport's render resolution.
	var local := pointer_position - rect.position
	var viewport_point := Vector2(
		local.x / rect.size.x * stage_root.size.x,
		local.y / rect.size.y * stage_root.size.y
	)
	_grapple_with_ray(stage_camera.project_ray_origin(viewport_point), stage_camera.project_ray_normal(viewport_point))

func _update_camera() -> void:
	var forward := _base_forward.rotated(Vector3.UP, _yaw)
	var right := forward.cross(Vector3.UP).normalized()
	forward = forward.rotated(right, _pitch).normalized()
	stage_camera.look_at(stage_camera.global_position + forward * 10.0, Vector3.UP)

# Random local point just outside the enemy's capsule, biased toward the camera.
# Uses world axes, assuming the enemy doesn't rotate during the encounter.
func _random_point_on_enemy() -> Vector3:
	var g := enemy_actor as Goblin
	var h: float = g.height if g != null else 1.6
	var r: float = g.radius if g != null else 0.4
	var y := randf_range(h * 0.15, h * 0.95)
	var to_camera := stage_camera.global_position - enemy_actor.global_position
	to_camera.y = 0.0
	var facing := to_camera.normalized() if to_camera.length() > 0.01 else Vector3.FORWARD
	var dir := facing.rotated(Vector3.UP, randf_range(-PI * 0.35, PI * 0.35))
	return Vector3(dir.x, 0.0, dir.z) * (r + 0.05) + Vector3.UP * y

# Weak spot parented to enemy_actor so it follows his drift.
func _spawn_weak_spot() -> Area3D:
	var spot := Area3D.new()
	spot.collision_layer = WEAK_SPOT_COLLISION_LAYER
	spot.collision_mask = 0
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = WEAK_SPOT_RADIUS
	sphere.height = WEAK_SPOT_RADIUS * 2.0
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.92, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Draw through the enemy's body and above other overlays (the beam).
	mat.no_depth_test = true
	mat.render_priority = 1
	mesh_inst.material_override = mat
	spot.add_child(mesh_inst)
	_pulse_weak_spot(mesh_inst)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = WEAK_SPOT_RADIUS
	collision.shape = shape
	spot.add_child(collision)

	enemy_actor.add_child(spot)
	spot.position = _random_point_on_enemy()

	return spot

# Pulse scale and emission (MeshInstance3D has no modulate).
func _pulse_weak_spot(mesh_inst: MeshInstance3D) -> void:
	var mat := mesh_inst.material_override as StandardMaterial3D
	var tw := mesh_inst.create_tween()
	tw.set_loops()
	# Each parallel pair (scale + glow) runs together; chain() sequences the pairs.
	tw.set_parallel(true)
	tw.tween_property(mesh_inst, "scale", Vector3.ONE * 1.6, 0.3)
	tw.tween_property(mat, "emission_energy_multiplier", 2.5, 0.3)
	tw.chain()
	tw.set_parallel(true)
	tw.tween_property(mesh_inst, "scale", Vector3.ONE, 0.3)
	tw.tween_property(mat, "emission_energy_multiplier", 0.7, 0.3)
	
# Move the weak spot to a fresh point on the enemy and restart its timeout.
func _assign_next_weak_spot() -> void:
	if _active_weak_spot != null and is_instance_valid(_active_weak_spot):
		_active_weak_spot.queue_free()
	_active_weak_spot = null
	if not is_instance_valid(enemy_actor):
		return
	_active_weak_spot = _spawn_weak_spot()
	_start_weak_spot_timeout(_active_weak_spot)

# No penalty for timing out; the spot just moves. `spot` is captured so a stale
# timer can't override a newer reassignment.
const WEAK_SPOT_TIMEOUT := 2.0

func _start_weak_spot_timeout(spot: Area3D) -> void:
	await get_tree().create_timer(WEAK_SPOT_TIMEOUT).timeout
	if not is_instance_valid(self):
		return
	if _active_weak_spot == spot:
		_assign_next_weak_spot()

# Ray from stage_camera (this is a Control, so 3D access goes through the camera).
func _grapple() -> void:
	if not is_instance_valid(stage_camera):
		return
	_grapple_with_ray(stage_camera.global_position, -stage_camera.global_transform.basis.z.normalized())

func _grapple_with_ray(from: Vector3, dir: Vector3) -> void:
	if not is_instance_valid(stage_camera):
		return
	var to: Vector3 = from + dir * GRAPPLE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# Only target Areas; bodies (diver, enemy, stage) would block visible spheres.
	query.collision_mask = VORTEX_COLLISION_LAYER if _vortex_active else WEAK_SPOT_COLLISION_LAYER
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var space := stage_camera.get_world_3d().direct_space_state
	var result := space.intersect_ray(query)

	# Beam ends where the ray stopped, or at max range.
	var beam_end: Vector3 = to if result.is_empty() else (result.position as Vector3)
	_grapple_beam(from, beam_end)

	if result.is_empty():
		return
	if result.collider == _active_weak_spot and is_instance_valid(_active_weak_spot):
		_hit_weak_spot()
		return
	if _vortex_active:
		for entry in _vortex_spheres:
			if result.collider == entry.node:
				_resolve_vortex_hit(entry)
				return

# Each weak-spot hit counts toward TARGET_COUNT, then the spot moves.
func _hit_weak_spot() -> void:
	_flash_enemy_red()
	_hits += 1
	_resolved += 1
	_update_progress()
	if _resolved >= TARGET_COUNT:
		_maybe_finish()
	else:
		_assign_next_weak_spot()

# Red emission pulse on the enemy, restoring his prior emission state afterwards.
func _flash_enemy_red() -> void:
	var mesh := enemy_actor.find_children("*", "MeshInstance3D", true, false)
	for m in mesh:
		var mat := (m as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if mat == null:
			continue
		var before_emission := mat.emission
		var before_enabled := mat.emission_enabled
		var before_energy := mat.emission_energy_multiplier
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.1, 0.05)
		var tw := (m as MeshInstance3D).create_tween()
		tw.tween_property(mat, "emission_energy_multiplier", 3.0, 0.08)
		tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)
		tw.tween_callback(func() -> void:
			if is_instance_valid(m):
				mat.emission = before_emission
				mat.emission_enabled = before_enabled
				mat.emission_energy_multiplier = before_energy
		)

func _grapple_beam(from: Vector3, to: Vector3) -> void:
	var distance := from.distance_to(to)
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = distance
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.035
	beam.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.9, 0.25)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = material
	stage_root.add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var fade := beam.create_tween()
	fade.tween_property(beam, "scale", Vector3(1.0, 1.0, 0.0), 0.16)
	fade.tween_callback(beam.queue_free)

# No-op kept for existing call sites.
func _update_progress() -> void:
	pass

func _maybe_finish() -> void:
	if _resolved < TARGET_COUNT:
		return
	_finish_now()

# Called by battle.gd when the player's HP hits 0 mid-encounter.
func request_abort() -> void:
	_finish_now()

func _finish_now() -> void:
	if _did_finish:
		return
	_did_finish = true
	_grapple_controls_active = false
	_hide_wave_callout()
	Input.mouse_mode = _old_mouse_mode
	if target_actor != null and is_instance_valid(target_actor):
		target_actor.visible = _target_was_visible
	# Restore synchronously: battle.gd frames the camera right after queue_free(),
	# before _exit_tree() would run.
	_restore_enemy_home()
	# Vortex spheres live under stage_root, not this Control, so free them here.
	_clear_vortex()
	finished.emit(_hits, TARGET_COUNT * TOTAL_VORTEX_WAVES)

func _restore_enemy_home() -> void:
	if _enemy_drift_tween != null and _enemy_drift_tween.is_valid():
		_enemy_drift_tween.kill()
	_enemy_drift_tween = null
	if _enemy_was_moved and enemy_actor != null and is_instance_valid(enemy_actor):
		enemy_actor.global_position = _enemy_home_position
		_enemy_was_moved = false

# Verification hook: aim at a target and fire through the real hit path.
func auto_intercept_closest() -> bool:
	if stage_camera == null:
		return false
	if _active_weak_spot != null and is_instance_valid(_active_weak_spot):
		stage_camera.look_at(_active_weak_spot.global_position, Vector3.UP)
		_grapple()
		return true
	# Otherwise aim at a safe-color vortex sphere (never a dangerous one).
	for entry in _vortex_spheres:
		if bool(entry.is_yellow) == _vortex_safe_is_yellow:
			var node := entry.node as Area3D
			if is_instance_valid(node):
				stage_camera.look_at(node.global_position, Vector3.UP)
				_grapple()
				return true
	return false

# =====================================================================
# VORTEX: a disc of yellow/green spheres travelling toward the player; one
# color is safe to grapple each wave.
# =====================================================================

# Meters. The attacker is staged 16 m out; _vortex_reachable_radius() keeps
# every sphere aimable throughout the approach.
const VORTEX_ENEMY_DISTANCE := 16.0
const VORTEX_ENEMY_LAUNCH_OFFSET := 0.6
const VORTEX_PLAYER_STANDOFF := 3.5
const VORTEX_MIN_TRAVEL_DISTANCE := 1.0
# Time for the whole disc to travel from start to end.
const VORTEX_TRAVEL_TIME := 4.5
# Maximum boundary; narrowed as the wave approaches (_vortex_reachable_radius()).
const VORTEX_BOUNDARY_RADIUS := 3.5
const VORTEX_SPHERE_RADIUS := 0.35
const VORTEX_MIN_SPHERES := 3
const VORTEX_MAX_SPHERES := 5
const VORTEX_SAFE_COLOR := Color(1.0, 0.9, 0.15)
const VORTEX_SAFE_EMISSION := Color(1.0, 0.85, 0.1)
const VORTEX_DANGER_COLOR := Color(0.15, 0.95, 0.35)
const VORTEX_DANGER_EMISSION := Color(0.1, 0.9, 0.3)

# Duration of each sphere's arc leg to the center (same for all, so they meet together).
# Also sets post-bounce speed, since bounce velocity derives from the arc rate.
const VORTEX_ARC_LEG_TIME := 0.95

# Waves launched so far; incremented in launch_vortex().
var vortex_count := 0

var _vortex_active := false
# Killed by _clear_vortex() so an early-cleared wave's tween can't fire a stale hit.
var _vortex_travel_tween: Tween = null
var _vortex_center := Vector3.ZERO
# Disc axes fixed at launch from _base_forward, so the ring doesn't follow the aim.
var _vortex_right := Vector3.RIGHT
var _vortex_up := Vector3.UP
# Safe color this wave (yellow means "hit this" throughout).
var _vortex_safe_is_yellow := true
# Each {node, pos2d, is_yellow, using_physics, vel2d, leg_start, leg_end, leg_t,
# bulge_axis} in disc-local 2D. Arc fields drive motion until using_physics flips true.
var _vortex_spheres: Array[Dictionary] = []

# The disc travels along the fixed player-enemy axis from just ahead of the
# attacker to a bounded standoff, so there's always a visible approach.
func launch_vortex() -> void:
	vortex_count += 1
	var start := enemy_actor.global_position - _base_forward * VORTEX_ENEMY_LAUNCH_OFFSET
	var start_distance := start.distance_to(stage_camera.global_position)
	var end_distance := maxf(0.0, minf(VORTEX_PLAYER_STANDOFF, start_distance - VORTEX_MIN_TRAVEL_DISTANCE))
	var end := stage_camera.global_position + _base_forward * end_distance
	_vortex_center = start
	_vortex_right = _base_forward.cross(Vector3.UP).normalized()
	_vortex_up = _vortex_right.cross(_base_forward).normalized()
	_vortex_safe_is_yellow = randf() < 0.5
	wave_instruction = "YELLOW" if _vortex_safe_is_yellow else "GREEN"
	_show_wave_callout(_vortex_safe_is_yellow)
	wave_started.emit(_vortex_safe_is_yellow, vortex_count, TOTAL_VORTEX_WAVES)

	_clear_vortex()
	# Restart the cardinal spawn cycle each wave.
	_vortex_next_angle_index = 0
	# Always exactly 2 yellow and 2 green, shuffled across the spawn points.
	var colors: Array[bool] = [true, true, false, false]
	colors.shuffle()
	for is_yellow in colors:
		_spawn_vortex_sphere(is_yellow)
	_vortex_active = true

	# Tween _vortex_center; spheres ride along via _vortex_world_pos(). Finishing
	# means the wave reached the player (_on_vortex_reached_player()).
	_vortex_travel_tween = create_tween()
	_vortex_travel_tween.tween_property(self, "_vortex_center", end, VORTEX_TRAVEL_TIME)
	_vortex_travel_tween.finished.connect(_on_vortex_reached_player)

# Steady callout in the safe color (as text too, not color-only) until the next
# wave or the end.
func _show_wave_callout(safe_is_yellow: bool) -> void:
	_wave_callout_generation += 1
	if _wave_callout_tween != null and _wave_callout_tween.is_valid():
		_wave_callout_tween.kill()
	_wave_callout.text = "GRAPPLE %s" % wave_instruction
	_wave_callout.add_theme_color_override("font_color", VORTEX_SAFE_COLOR if safe_is_yellow else VORTEX_DANGER_COLOR)
	_wave_callout.modulate = Color.WHITE
	_wave_callout.scale = Vector2.ONE
	_wave_callout.visible = true

func _hide_wave_callout() -> void:
	_wave_callout_generation += 1
	if _wave_callout_tween != null and _wave_callout_tween.is_valid():
		_wave_callout_tween.kill()
	if is_instance_valid(_wave_callout):
		_wave_callout.visible = false

# East, North, West, South.
const VORTEX_CARDINAL_ANGLES: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]

# Cycles spawns through the four cardinal directions.
var _vortex_next_angle_index := 0

# Spawn at half the boundary radius on the next cardinal; the spacing prevents overlap.
func _random_vortex_spawn_point() -> Vector2:
	var angle: float = VORTEX_CARDINAL_ANGLES[_vortex_next_angle_index % VORTEX_CARDINAL_ANGLES.size()]
	_vortex_next_angle_index += 1
	var direction := Vector2(cos(angle), sin(angle))
	return direction * (VORTEX_BOUNDARY_RADIUS * 0.5)

# Point t (0..1) along a semicircle from leg_start to leg_end; bulge_axis's sign
# picks which side it curves toward.
func _arc_point(leg_start: Vector2, leg_end: Vector2, bulge_axis: Vector2, t: float) -> Vector2:
	var mid := (leg_start + leg_end) * 0.5
	var radius := leg_start.distance_to(leg_end) * 0.5
	if radius < 0.001:
		return leg_end
	var axis1 := (leg_start - mid) / radius
	var theta := t * PI
	return mid + axis1 * (radius * cos(theta)) + bulge_axis * (radius * sin(theta))

# Perpendicular to the leg with a random sign (which side the arc bulges).
func _random_bulge_axis(leg_start: Vector2, leg_end: Vector2) -> Vector2:
	var diff := leg_start - leg_end
	if diff.length() < 0.001:
		return Vector2.RIGHT
	var perp := diff.normalized().rotated(PI * 0.5)
	return perp if randf() < 0.5 else -perp

# Color comes from launch_vortex()'s shuffled set.
func _spawn_vortex_sphere(is_yellow: bool) -> void:
	var pos2d := _random_vortex_spawn_point()
	# First phase: arc leg to the disc center. vel2d is unused until the first collision.
	var leg_end := Vector2.ZERO

	var area := Area3D.new()
	area.collision_layer = VORTEX_COLLISION_LAYER
	area.collision_mask = VORTEX_COLLISION_LAYER
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = VORTEX_SPHERE_RADIUS
	sphere.height = VORTEX_SPHERE_RADIUS * 2.0
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.albedo_color = VORTEX_SAFE_COLOR if is_yellow else VORTEX_DANGER_COLOR
	mat.emission = VORTEX_SAFE_EMISSION if is_yellow else VORTEX_DANGER_EMISSION
	mesh_inst.material_override = mat
	area.add_child(mesh_inst)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = VORTEX_SPHERE_RADIUS
	collision.shape = shape
	area.add_child(collision)

	stage_root.add_child(area)
	area.global_position = _vortex_world_pos(pos2d)

	_vortex_spheres.append({
		"node": area, "pos2d": pos2d, "is_yellow": is_yellow,
		"using_physics": false, "vel2d": Vector2.ZERO,
		"leg_start": pos2d, "leg_end": leg_end, "leg_t": 0.0,
		"bulge_axis": _random_bulge_axis(pos2d, leg_end),
	})

func _vortex_world_pos(p2: Vector2) -> Vector3:
	return _vortex_center + _vortex_right * p2.x + _vortex_up * p2.y

# True while every sphere is on screen and inside the reachable yaw/pitch cone
# (with margin). Used by regression tests.
func vortex_targets_are_aimable() -> bool:
	if not _vortex_active:
		return true
	for entry in _vortex_spheres:
		var node := entry.node as Area3D
		if node == null or not is_instance_valid(node):
			continue
		var local := stage_camera.to_local(node.global_position)
		if local.z >= -0.01 or not stage_camera.is_position_in_frustum(node.global_position):
			return false
		var forward_distance := -local.z
		# Check the sphere's outer edge, not just its center.
		var yaw := atan2(absf(local.x) + VORTEX_SPHERE_RADIUS, forward_distance)
		var pitch := atan2(absf(local.y) + VORTEX_SPHERE_RADIUS, sqrt(local.x * local.x + local.z * local.z))
		var aim_limits := _vortex_aim_limits()
		var allowed_yaw := aim_limits.x
		var allowed_pitch := aim_limits.y
		if yaw > allowed_yaw or pitch > allowed_pitch:
			return false
	return true

# Smaller of the view and mouse-look cones, minus a comfort margin.
func _vortex_aim_limits() -> Vector2:
	var viewport_size := stage_root.size
	var half_vertical_fov := deg_to_rad(stage_camera.fov) * 0.5
	var half_horizontal_fov := atan(tan(half_vertical_fov) * viewport_size.x / maxf(1.0, viewport_size.y))
	return Vector2(minf(MAX_YAW, half_horizontal_fov) - 0.08, minf(MAX_PITCH, half_vertical_fov) - 0.08)

# Largest disc radius keeping a full sphere inside the reachable cone, capped at
# VORTEX_BOUNDARY_RADIUS.
func _vortex_reachable_radius() -> float:
	var distance := _vortex_center.distance_to(stage_camera.global_position)
	var narrowest_limit := minf(_vortex_aim_limits().x, _vortex_aim_limits().y)
	var allowed_radius := distance * tan(narrowest_limit) - VORTEX_SPHERE_RADIUS
	return clampf(allowed_radius, VORTEX_SPHERE_RADIUS, VORTEX_BOUNDARY_RADIUS)

# Physics tick, not _process(): overlap state only updates per physics tick, so
# per-frame checks double-bounce.
func _physics_process(delta: float) -> void:
	if _vortex_active:
		_update_vortex(delta)

# Phase 1: spheres follow their arcs (same leg time, so they meet together).
# Phase 2: integrate vel2d. The first real overlap releases all arc spheres at once.
func _update_vortex(delta: float) -> void:
	# 1a) Phase-1 spheres: advance along the scripted arc.
	for entry in _vortex_spheres:
		if entry.using_physics:
			continue
		var t: float = minf(float(entry.leg_t) + delta / VORTEX_ARC_LEG_TIME, 1.0)
		entry.leg_t = t
		entry.pos2d = _arc_point(entry.leg_start, entry.leg_end, entry.bulge_axis, t)

	# 1b) Phase-2 spheres: integrate from their own velocity instead.
	for entry in _vortex_spheres:
		if entry.using_physics:
			entry.pos2d = entry.pos2d + entry.vel2d * delta

	# Write positions before overlap checks so the physics server sees this frame's.
	for entry in _vortex_spheres:
		var node := entry.node as Area3D
		if is_instance_valid(node):
			node.global_position = _vortex_world_pos(entry.pos2d)

	# 2a) Any overlap between arc spheres releases ALL of them into physics together,
	# so no straggler waits for a partner.
	var center_meet_happened := false
	for i in range(_vortex_spheres.size()):
		if center_meet_happened:
			break
		var a: Dictionary = _vortex_spheres[i]
		if bool(a.using_physics):
			continue
		var a_node := a.node as Area3D
		if not is_instance_valid(a_node):
			continue
		for j in range(i + 1, _vortex_spheres.size()):
			var b: Dictionary = _vortex_spheres[j]
			if bool(b.using_physics):
				continue
			var b_node := b.node as Area3D
			if not is_instance_valid(b_node):
				continue
			if b_node in a_node.get_overlapping_areas():
				center_meet_happened = true
				break
	if center_meet_happened:
		for entry in _vortex_spheres:
			if not entry.using_physics:
				_apply_vortex_bounce(entry)

	# 2b) Physics-mode contacts. The helper separates and applies an impulse only when
	# approaching, so repeated overlap reports don't re-reverse them.
	for i in range(_vortex_spheres.size()):
		var a: Dictionary = _vortex_spheres[i]
		if not bool(a.using_physics):
			continue
		var a_node := a.node as Area3D
		if not is_instance_valid(a_node):
			continue
		for j in range(i + 1, _vortex_spheres.size()):
			var b: Dictionary = _vortex_spheres[j]
			if not bool(b.using_physics):
				continue
			var b_node := b.node as Area3D
			if not is_instance_valid(b_node):
				continue
			if not (b_node in a_node.get_overlapping_areas()):
				continue
			var contact := VortexCollision.resolve_sphere_contact(
				a.pos2d, a.vel2d, b.pos2d, b.vel2d, VORTEX_SPHERE_RADIUS)
			a.pos2d = contact.first_position as Vector2
			a.vel2d = contact.first_velocity as Vector2
			b.pos2d = contact.second_position as Vector2
			b.vel2d = contact.second_velocity as Vector2

	# 3) Reflect physics-mode spheres off the (shrinking) boundary circle.
	var reachable_radius := _vortex_reachable_radius()
	for entry in _vortex_spheres:
		if not entry.using_physics:
			continue
		if entry.pos2d.length() + VORTEX_SPHERE_RADIUS <= reachable_radius:
			continue
		var normal: Vector2 = entry.pos2d.normalized()
		entry.vel2d = entry.vel2d - 2.0 * entry.vel2d.dot(normal) * normal
		entry.pos2d = normal * (reachable_radius - VORTEX_SPHERE_RADIUS)

	# Re-sync node positions after corrections.
	for entry in _vortex_spheres:
		var node := entry.node as Area3D
		if is_instance_valid(node):
			node.global_position = _vortex_world_pos(entry.pos2d)

# Physics mode: reverse velocity. Arc mode: derive velocity from the arc's
# derivative at leg_t, reverse it, and switch to physics permanently.
func _apply_vortex_bounce(entry: Dictionary) -> void:
	if entry.using_physics:
		entry.vel2d = -entry.vel2d
		return
	var leg_start: Vector2 = entry.leg_start
	var leg_end: Vector2 = entry.leg_end
	var radius: float = leg_start.distance_to(leg_end) * 0.5
	var current_velocity: Vector2
	if radius < 0.001:
		current_velocity = Vector2.ZERO
	else:
		var mid: Vector2 = (leg_start + leg_end) * 0.5
		var axis1: Vector2 = (leg_start - mid) / radius
		var bulge_axis: Vector2 = entry.bulge_axis
		var theta: float = float(entry.leg_t) * PI
		# d(pos)/d(leg_t) = PI * (-axis1*r*sin(theta) + bulge_axis*r*cos(theta));
		# divide by VORTEX_ARC_LEG_TIME for per-second velocity.
		var d_pos_d_leg_t: Vector2 = PI * (-axis1 * radius * sin(theta) + bulge_axis * radius * cos(theta))
		current_velocity = d_pos_d_leg_t / VORTEX_ARC_LEG_TIME
	entry.vel2d = -current_velocity
	entry.using_physics = true

# Correct color removes the sphere and scores; wrong color only flashes red.
func _resolve_vortex_hit(entry: Dictionary) -> void:
	var node := entry.node as Area3D
	var correct: bool = bool(entry.is_yellow) == _vortex_safe_is_yellow
	_flash_vortex_sphere(node, Color(0.4, 1.0, 0.6) if correct else Color(1.0, 0.2, 0.15))
	if not correct:
		return
	_remove_vortex_sphere(entry)
	_hits += 1
	_resolved += 1
	_update_progress()
	# The wave clears once no safe-color spheres remain.
	for remaining in _vortex_spheres:
		if bool(remaining.is_yellow) == _vortex_safe_is_yellow:
			return
	_advance_or_finish_vortex()

# The disc reached the player: if the wave is still active, it hits (object_hit).
func _on_vortex_reached_player() -> void:
	if not _vortex_active:
		return
	object_hit.emit()
	_advance_or_finish_vortex()

# Ends a wave (cleared or timed out): next wave, or finish after TOTAL_VORTEX_WAVES.
func _advance_or_finish_vortex() -> void:
	_clear_vortex()
	if vortex_count >= TOTAL_VORTEX_WAVES:
		_finish_now()
	else:
		launch_vortex()

func _flash_vortex_sphere(node: Area3D, color: Color) -> void:
	if not is_instance_valid(node):
		return
	var mesh_inst := node.get_child(0) as MeshInstance3D
	if mesh_inst == null:
		return
	var mat := mesh_inst.material_override as StandardMaterial3D
	if mat == null:
		return
	var original_color := mat.albedo_color
	var tw := node.create_tween()
	tw.tween_property(mat, "albedo_color", color, 0.06)
	# Flash, then restore; wrong-color spheres stay in the wave.
	tw.tween_property(mat, "albedo_color", original_color, 0.16)

func _remove_vortex_sphere(entry: Dictionary) -> void:
	_vortex_spheres.erase(entry)
	var node := entry.node as Area3D
	if is_instance_valid(node):
		node.queue_free()

func _clear_vortex() -> void:
	_vortex_active = false
	# Kill the travel tween so it can't fire a stale hit (kill() doesn't emit finished).
	if _vortex_travel_tween != null and _vortex_travel_tween.is_valid():
		_vortex_travel_tween.kill()
	_vortex_travel_tween = null
	for entry in _vortex_spheres:
		var node := entry.node as Area3D
		if is_instance_valid(node):
			node.queue_free()
	_vortex_spheres.clear()


# Verification: resolve a hit directly, bypassing aim.
func verification_resolve_closest() -> bool:
	if _active_weak_spot != null and is_instance_valid(_active_weak_spot):
		_hit_weak_spot()
		return true
	# Fallback: resolve the first safe-color vortex sphere.
	for entry in _vortex_spheres:
		if bool(entry.is_yellow) == _vortex_safe_is_yellow:
			_resolve_vortex_hit(entry)
			return true
	return false
