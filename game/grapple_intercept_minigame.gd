# Diver Boy's special-encounter defense: the enemy launches targets from
# random points in front of the diver, mouse-look aims a first-person camera,
# and left-click fires a grapple line. Unshot targets damage the diver when
# they arrive; the battle owns the actual damage calculation via object_hit.
class_name GrappleInterceptMinigame
extends Control

signal finished(hits: int, total: int)
signal object_hit

# MODIFIED: was 8, spawned one at a time via a staggered loop - now 5 of
# the 8 grid squares (_grid_spawn_positions()) launch in the same burst
# (see _spawn_loop()), one rock per chosen square, so TARGET_COUNT
# matches how many rocks actually spawn rather than needing several
# waves to use it up.
const TARGET_COUNT := 5
const TITLE_HOLD := 0.8
const FLIGHT_TIME := 3.2
const HIT_ANGLE := deg_to_rad(7.0)
const LOOK_SENSITIVITY := 0.0035
const MAX_YAW := 0.75
const MAX_PITCH := 0.48

# How far _grapple()'s raycast reaches - generous relative to how close
# rocks/the camera actually get to each other in this stage (a handful of
# GRID_SPACING units), so a correctly-aimed shot never falls short.
const GRAPPLE_RANGE := 40.0

# Big rocks that take a few hits rather than one - see _spawn_target()/
# _hit_weak_spot(). BIG_ROCK_RADIUS is also read by _spawn_weak_spot() to
# place the weak spot ON the rock's surface, so the two stay in sync if
# this is ever retuned.
const BIG_ROCK_RADIUS := 1.5
const WEAK_SPOT_RADIUS := 0.16
const ROCK_RESTITUTION := 1.0
const ROCK_CONTACT_EPSILON := 0.001
# MODIFIED: was randi_range(MIN_HITS_TO_DESTROY, MAX_HITS_TO_DESTROY) * an
# HP pool reduced by DAMAGE_PER_HIT each hit (2-3 hits' worth, randomized
# per rock) - simplified to a flat hit counter, exactly 2 weak-spot hits
# destroys any rock, no randomization or HP abstraction needed for that.
const HITS_TO_DESTROY := 2

var stage_root: SubViewport
var stage_camera: Camera3D
var target_actor: Node3D
var source_position := Vector3.ZERO

var _targets: Array[MeshInstance3D] = []
# Rock transforms must have one owner. Tweening them toward the camera and
# also trying to push them apart means the Tween writes the old trajectory
# back on the next frame, which is exactly how one contact turns into a
# visible double bounce. The manual velocity/time maps below own motion from
# launch to landing, while collision resolution only changes velocity.
var _target_velocities: Dictionary = {}
var _target_time_left: Dictionary = {}

# Each rock's weak-spot hit count so far, keyed by the same rock
# MeshInstance3D _targets already tracks. Starts at 0 in _spawn_target(),
# incremented by _hit_weak_spot() - destroyed once it reaches
# HITS_TO_DESTROY.
var _rock_hits: Dictionary = {}   # rock -> int

# ONE weak spot exists across the whole group of live rocks at a time -
# not one per rock. _assign_next_weak_spot() picks a random rock out of
# whatever's still in _targets (already-destroyed/landed rocks can't be
# picked, since they're gone from that array by the time this runs) and
# gives IT the marker, so the thing to aim at hops unpredictably between
# rocks - hit rock 1, the next spot might land back on rock 1 again, or
# jump to rock 5, then rock 4, same rock never guaranteed to repeat or
# rotate in order.
# MODIFIED: was MeshInstance3D - _spawn_weak_spot() returns an Area3D now
# (a real collidable node the beam's raycast can hit, with a Sprite3D and
# CollisionShape3D as its own children), not a bare mesh.
var _active_weak_spot: Area3D = null
var _active_weak_spot_rock: MeshInstance3D = null

# Guards _finish_now() against emitting `finished` twice - it's reachable
# from both _maybe_finish() (the natural TARGET_COUNT completion) and
# request_abort() (battle.gd, the instant the player's HP hits 0
# mid-encounter).
var _did_finish := false

var _spawned := 0
var _resolved := 0
var _hits := 0
var _yaw := 0.0
var _pitch := 0.0
var _base_forward := Vector3.FORWARD
var _old_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _target_was_visible := true
var _progress: Label
var _start_button: Button

func _ready() -> void:
	if get_parent() is Control:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.18)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := Label.new()
	title.text = "GRAPPLE INTERCEPT"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 35.0
	title.offset_left = -220.0
	title.offset_right = 220.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.3))
	add_child(title)

	var hint := Label.new()
	hint.text = "Grapple the glowing weak spot before the rocks reach you"
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.offset_top = 78.0
	hint.offset_left = -330.0
	hint.offset_right = 330.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	_progress = Label.new()
	_progress.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progress.offset_top = 110.0
	_progress.offset_left = -100.0
	_progress.offset_right = 100.0
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_progress)
	_update_progress()

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -16.0
	crosshair.offset_top = -25.0
	crosshair.offset_right = 16.0
	crosshair.offset_bottom = 25.0
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 34)
	crosshair.add_theme_color_override("font_color", Color(0.95, 0.9, 0.45))
	add_child(crosshair)

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
	if stage_camera == null or target_actor == null or stage_root == null:
		push_error("GrappleInterceptMinigame requires stage_root, stage_camera, and target_actor")
		finished.emit(0, TARGET_COUNT)
		return
	_old_mouse_mode = Input.mouse_mode
	# Browsers reject pointer lock unless it is requested from a user gesture.
	# The dedicated web playtest therefore waits on a real click; desktop keeps
	# the immediate start used by automated/local playtests.
	if OS.has_feature("web"):
		_start_button.visible = true
		await _start_button.pressed
		_start_button.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_target_was_visible = target_actor.visible
	target_actor.visible = false
	var eye := target_actor.global_position + Vector3(0.0, (target_actor as Diver).height * 0.4, 0.0)
	_base_forward = (source_position - eye).normalized()
	stage_camera.global_position = eye
	stage_camera.look_at(eye + _base_forward * 10.0, Vector3.UP)
	await get_tree().create_timer(TITLE_HOLD).timeout
	_spawn_loop()

func _exit_tree() -> void:
	Input.mouse_mode = _old_mouse_mode
	if target_actor != null and is_instance_valid(target_actor):
		target_actor.visible = _target_was_visible

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_yaw = clampf(_yaw - motion.relative.x * LOOK_SENSITIVITY, -MAX_YAW, MAX_YAW)
		_pitch = clampf(_pitch - motion.relative.y * LOOK_SENSITIVITY, -MAX_PITCH, MAX_PITCH)
		_update_camera()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_grapple()

func _update_camera() -> void:
	var forward := _base_forward.rotated(Vector3.UP, _yaw)
	var right := forward.cross(Vector3.UP).normalized()
	forward = forward.rotated(right, _pitch).normalized()
	stage_camera.look_at(stage_camera.global_position + forward * 10.0, Vector3.UP)

# Spawns exactly 5 rocks across 5 DIFFERENT squares out of the 8 total
# candidates (_grid_spawn_positions()) - shuffled once, then the first 5
# are used, guaranteeing no square is picked twice. All 5 launch in the
# same pass (no delay between them) rather than trickling in, then
# _assign_next_weak_spot() hands the first weak spot to one random rock
# out of that group.
func _spawn_loop() -> void:
	var positions := _grid_spawn_positions()
	positions.shuffle()
	for spawn_pos in positions.slice(0, TARGET_COUNT):
		_spawn_target(spawn_pos)
		_spawned += 1
	_assign_next_weak_spot()

# MODIFIED: radius was 0.3 (one-hit) - bumped to BIG_ROCK_RADIUS now that
# a rock takes several hits to actually break (see _hit_weak_spot()).
func _spawn_rock(at: Vector3) -> MeshInstance3D:
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BIG_ROCK_RADIUS
	rock.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.22, 0.14)   # same brown as cracked_wall.gd's disguised rocks
	rock.material_override = mat
	stage_root.add_child(rock)
	rock.global_position = at
	return rock

# A small glowing marker parented to whichever rock currently holds it -
# being a CHILD is what makes it track that rock's own flight tween for
# free, without this script needing to re-position it every frame by
# hand. Placed at a random point on the rock's own surface (a random unit
# vector scaled by BIG_ROCK_RADIUS).
func _random_point_on_sphere(radius: float) -> Vector3:
	var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if dir.length() < 0.001:
		dir = Vector3.UP
	return dir.normalized() * radius

# MODIFIED: was res://assets/target.png, which doesn't exist anywhere in
# the project - the real file is at res://icons/target.png (already
# imported, see its own .import file). Also parents `spot` to `rock` now
# (never actually added anywhere before - an Area3D that isn't in the
# tree neither renders its Sprite3D nor gets seen by any physics query,
# no matter how correctly its shape is sized), and positions it at a
# random point on the rock's own surface instead of dead center, the same
# way the old sphere-mesh weak spot did.
const WEAK_SPOT_TEXTURE: Texture2D = preload("res://icons/target.png")

# MODIFIED (added): sprite.pixel_size was never set, so Sprite3D used its
# own default (0.01 world units/pixel) - target.png is 512x512, so that
# rendered as a 5.12-unit sprite regardless of anything in this scene,
# dwarfing a rock that's only BIG_ROCK_RADIUS*2 units across. Set
# explicitly here so the sprite's actual on-screen size is
# WEAK_SPOT_RADIUS*2 (its intended diameter) no matter what resolution
# the source texture happens to be - the collision shape below already
# derives from texture_size * pixel_size, so fixing pixel_size here
# automatically fixes the hitbox size too, no separate change needed there.
func _spawn_weak_spot(rock: MeshInstance3D) -> Area3D:
	var spot := Area3D.new()
	var sprite := Sprite3D.new()
	sprite.texture = WEAK_SPOT_TEXTURE
	var texture_size := WEAK_SPOT_TEXTURE.get_size()
	sprite.pixel_size = (WEAK_SPOT_RADIUS * 2.0) / texture_size.x
	spot.add_child(sprite)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		texture_size.x * sprite.pixel_size,
		texture_size.y * sprite.pixel_size,
		0.1
	)
	collision.shape = shape
	spot.add_child(collision)

	rock.add_child(spot)
	spot.position = _random_point_on_sphere(BIG_ROCK_RADIUS)

	return spot
	
# Picks ONE random rock out of whatever's still alive in _targets and
# gives it a fresh weak spot at a new random surface point - called once
# after the initial burst (_spawn_loop()) and again after every single
# hit (_hit_weak_spot(), win or lose), and also from _land() if the rock
# that just reached the player was the one holding the spot. Freeing the
# OLD spot here handles the "rock survived, moving to a new point"
# case; if the previous holder was just destroyed/freed instead, its
# child spot is already gone with it and is_instance_valid() below simply
# skips the redundant free.
func _assign_next_weak_spot() -> void:
	if _active_weak_spot != null and is_instance_valid(_active_weak_spot):
		_active_weak_spot.queue_free()
	_active_weak_spot = null
	_active_weak_spot_rock = null
	if _targets.is_empty():
		return
	var rock: MeshInstance3D = _targets.pick_random()
	_active_weak_spot_rock = rock
	_active_weak_spot = _spawn_weak_spot(rock)
	_start_weak_spot_timeout(_active_weak_spot)

# No penalty for missing the window - per the user's own call, nothing
# should cost the player here except a rock actually landing on them
# (object_hit, handled entirely by _land()/battle.gd). This just moves
# the spot on to a new random rock after WEAK_SPOT_TIMEOUT seconds if
# nobody's hit it yet, same as a hit or a landed rock would, just without
# either of those side effects.
#
# `spot` is captured by value at the moment this starts, not read fresh
# off _active_weak_spot later - by the time this timer fires, a hit or a
# landed rock may have ALREADY reassigned _active_weak_spot to something
# else entirely (or to null, if every rock's gone). Comparing the current
# _active_weak_spot against this specific captured `spot` is what tells
# this timeout "is the thing I was timing still even the active one," so
# a stale timer can't stomp on a reassignment that already happened for a
# real reason.
const WEAK_SPOT_TIMEOUT := 2.0

func _start_weak_spot_timeout(spot: Area3D) -> void:
	await get_tree().create_timer(WEAK_SPOT_TIMEOUT).timeout
	if not is_instance_valid(self):
		return
	if _active_weak_spot == spot:
		_assign_next_weak_spot()

# Eight fixed candidate squares positioned right in front of the enemy
# (source_position) - four at one spacing and four at double that
# spacing, along the up/down/left/right axes. _spawn_loop() only ever
# uses 5 of these 8 per encounter (shuffled, first 5 taken), so which
# five squares actually get a rock varies run to run even though the
# candidate set itself is fixed. `right` reuses _base_forward the same
# way _spawn_target()'s own flight math does, so this grid is oriented
# consistently with everything else this minigame spawns.
# A 1.5 m radius means a visible diameter of 3 m. The old 1.6 m spacing put
# every neighbouring launch sphere inside the next one before the player had
# control. Keep a small gap even before collision handling starts.
const GRID_SPACING := BIG_ROCK_RADIUS * 2.2

func _grid_spawn_positions() -> Array[Vector3]:
	var right := _base_forward.cross(Vector3.UP).normalized()
	return [
		source_position + Vector3.UP * GRID_SPACING,
		source_position - Vector3.UP * GRID_SPACING,
		source_position + right * GRID_SPACING,
		source_position - right * GRID_SPACING,
		source_position + Vector3.UP * GRID_SPACING * 2.0,
		source_position - Vector3.UP * GRID_SPACING * 2.0,
		source_position + right * GRID_SPACING * 2.0,
		source_position - right * GRID_SPACING * 2.0,
	]

func _spawn_target(spawn: Vector3) -> void:
	var eye := stage_camera.global_position
	var rock := _spawn_rock(spawn)
	_targets.append(rock)
	_rock_hits[rock] = 0
	_target_velocities[rock] = (eye - spawn) / FLIGHT_TIME
	_target_time_left[rock] = FLIGHT_TIME

func _process(delta: float) -> void:
	if _targets.is_empty():
		return
	# Move every live rock first, then resolve each unordered pair exactly
	# once. A separate "bounce" callback per rock would process A/B and B/A
	# as two impacts; i + 1 prevents that duplicate impulse.
	for target in _targets:
		if is_instance_valid(target):
			var velocity: Vector3 = _target_velocities.get(target, Vector3.ZERO)
			target.global_position += velocity * delta
			_target_time_left[target] = float(_target_time_left.get(target, FLIGHT_TIME)) - delta
	_resolve_target_collisions()
	var landed: Array[MeshInstance3D] = []
	for target in _targets:
		if float(_target_time_left.get(target, 0.0)) <= 0.0:
			landed.append(target)
	for target in landed:
		_land(target)

# Returns corrected positions and velocities for two equal-mass spheres.
# `impulse` is false for a pair already separating, which is the essential
# guard against the reported second bounce on the following frame.
static func resolve_sphere_contact(
		first_position: Vector3, first_velocity: Vector3,
		second_position: Vector3, second_velocity: Vector3,
		radius: float) -> Dictionary:
	var separation := second_position - first_position
	var distance := separation.length()
	var minimum_distance := radius * 2.0
	if distance >= minimum_distance:
		return {"first_position": first_position, "first_velocity": first_velocity,
			"second_position": second_position, "second_velocity": second_velocity, "impulse": false}
	var normal := separation / distance if distance > ROCK_CONTACT_EPSILON else (first_velocity - second_velocity).normalized()
	if normal.length_squared() < ROCK_CONTACT_EPSILON:
		normal = Vector3.RIGHT
	# Correct overlap before considering velocity, so an approaching pair is
	# visibly separate immediately and a separating pair cannot stay embedded.
	var correction := normal * ((minimum_distance - distance + ROCK_CONTACT_EPSILON) * 0.5)
	var corrected_first := first_position - correction
	var corrected_second := second_position + correction
	var closing_speed := (first_velocity - second_velocity).dot(normal)
	if closing_speed <= 0.0:
		return {"first_position": corrected_first, "first_velocity": first_velocity,
			"second_position": corrected_second, "second_velocity": second_velocity, "impulse": false}
	var impulse := normal * (closing_speed * (1.0 + ROCK_RESTITUTION) * 0.5)
	return {"first_position": corrected_first, "first_velocity": first_velocity - impulse,
		"second_position": corrected_second, "second_velocity": second_velocity + impulse, "impulse": true}

func _resolve_target_collisions() -> void:
	for first_index in range(_targets.size()):
		var first := _targets[first_index]
		if not is_instance_valid(first):
			continue
		for second_index in range(first_index + 1, _targets.size()):
			var second := _targets[second_index]
			if not is_instance_valid(second):
				continue
			var contact := resolve_sphere_contact(
				first.global_position, _target_velocities.get(first, Vector3.ZERO),
				second.global_position, _target_velocities.get(second, Vector3.ZERO),
				BIG_ROCK_RADIUS)
			first.global_position = contact.first_position as Vector3
			second.global_position = contact.second_position as Vector3
			_target_velocities[first] = contact.first_velocity as Vector3
			_target_velocities[second] = contact.second_velocity as Vector3

# MODIFIED: this used to try to get 3D-space methods (get_world_3d(),
# global_position, basis) off `self` - but this class extends Control,
# not Node3D, and GDScript has no multiple inheritance (a script is
# always exactly one base class; Control and Node3D are unrelated
# siblings under Node, not something you can combine). There's no version
# of this class that has its own 3D transform - the fix is to get 3D-space
# access through a real Node3D this script already holds a reference to
# instead: stage_camera, which already lives in the same 3D world as the
# rocks and already anchors every other aim calculation in this file (see
# _shoot()'s old angle check, _update_camera()).
#
# Replaces the old angle-cone check entirely - a real physics raycast
# against the weak spot's own CollisionShape3D (sized to match its
# Sprite3D in _spawn_weak_spot()) IS the "did this land within the target
# icon's area" check; no separate distance/angle math needed once the
# shape is sized correctly; whether the ray reached that shape is the
# whole answer.
func _grapple() -> void:
	var from: Vector3 = stage_camera.global_position
	var dir: Vector3 = -stage_camera.global_transform.basis.z.normalized()
	var to: Vector3 = from + dir * GRAPPLE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# Area3D (what the weak spot is - see _spawn_weak_spot()) isn't checked
	# by a ray query unless this is explicitly turned on - it defaults to
	# false, only PhysicsBody3D is checked by default.
	query.collide_with_areas = true
	var space := stage_camera.get_world_3d().direct_space_state
	var result := space.intersect_ray(query)

	# Beam end is wherever the ray actually stopped - the max range if it
	# hit nothing at all, or whatever it struck.
	var beam_end: Vector3 = to if result.is_empty() else (result.position as Vector3)
	_grapple_beam(from, beam_end)

	if result.is_empty():
		return
	if result.collider == _active_weak_spot and is_instance_valid(_active_weak_spot):
		_hit_weak_spot(_active_weak_spot_rock)

func _hit_weak_spot(rock: MeshInstance3D) -> void:
	var hits: int = int(_rock_hits.get(rock, 0)) + 1
	_rock_hits[rock] = hits
	_flash_rock_red(rock)
	if hits >= HITS_TO_DESTROY:
		_destroy_target(rock)
	_assign_next_weak_spot()

# A quick red emission pulse on the rock's OWN material - this is the
# "you hit it" confirmation regardless of whether that hit was lethal;
# _destroy_target()'s own shatter (scale to zero) plays right alongside
# this for a lethal hit rather than replacing it.
func _flash_rock_red(rock: MeshInstance3D) -> void:
	var mat := rock.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.1)
	var tw := rock.create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 3.0, 0.08)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)

# MODIFIED: used to draw its own _grapple_beam() at the rock's own
# center - now that every hit (lethal or not) already draws one at the
# actual weak spot via _hit_weak_spot(), a second beam here for the
# killing hit specifically would just overlap the first. Cleans up
# _rock_hits - freeing `target` below frees its weak-spot CHILD node
# automatically if it still had one, but the hit-count dictionary entry
# would otherwise dangle. Does NOT touch _active_weak_spot/
# _active_weak_spot_rock itself - the caller (_hit_weak_spot(), or
# verification_resolve_closest()) is responsible for calling
# _assign_next_weak_spot() afterward, since only it knows whether `target`
# was even the rock currently holding the spot.
func _destroy_target(target: MeshInstance3D) -> void:
	_targets.erase(target)
	_target_velocities.erase(target)
	_target_time_left.erase(target)
	_rock_hits.erase(target)
	_hits += 1
	_resolved += 1
	var flash := target.create_tween()
	flash.tween_property(target, "scale", Vector3.ONE * 1.8, 0.10)
	flash.tween_property(target, "scale", Vector3.ZERO, 0.10)
	flash.tween_callback(target.queue_free)
	_update_progress()
	_maybe_finish()

func _land(target: MeshInstance3D) -> void:
	if not _targets.has(target):
		return
	_targets.erase(target)
	_target_velocities.erase(target)
	_target_time_left.erase(target)
	_rock_hits.erase(target)
	_resolved += 1
	object_hit.emit()
	target.queue_free()
	# An unshot rock reaching the player can still have been the one
	# holding the active weak spot - if so, hand it to a new rock the same
	# way a hit would, rather than leaving the spot pointing at a node
	# that's about to be freed.
	if _active_weak_spot_rock == target:
		_assign_next_weak_spot()
	_update_progress()
	_maybe_finish()

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

func _update_progress() -> void:
	if _progress != null:
		_progress.text = "%d / %d intercepted" % [_hits, TARGET_COUNT]

func _maybe_finish() -> void:
	if _resolved < TARGET_COUNT:
		return
	_finish_now()

# Called by battle.gd the instant the player's HP hits 0 mid-encounter -
# ends the intercept run right away with whatever tally it has so far,
# instead of continuing to launch more targets at a diver who's already
# down. _finish_now()'s own _did_finish guard makes this safe even if the
# natural TARGET_COUNT completion above was also about to fire on its own.
func request_abort() -> void:
	_finish_now()

func _finish_now() -> void:
	if _did_finish:
		return
	_did_finish = true
	Input.mouse_mode = _old_mouse_mode
	if target_actor != null and is_instance_valid(target_actor):
		target_actor.visible = _target_was_visible
	finished.emit(_hits, TARGET_COUNT)

# Verification hook: aim directly at the active weak spot and fire
# through the exact same hit-selection path used by mouse input.
#
# MODIFIED: used to find the geometrically closest of several PER-ROCK
# weak spots - now there's only ever one active spot total, shared across
# the group, so this just aims at it directly instead of searching
# _targets.
#
# NOTE: one call now only lands ONE hit (+1 toward one rock's
# HITS_TO_DESTROY count), not a full destroy - any verification script
# that assumed "one auto_intercept_closest() call = one rock gone" will
# need to call this multiple times (or check _rock_hits) to still pass.
func auto_intercept_closest() -> bool:
	if _active_weak_spot == null or not is_instance_valid(_active_weak_spot) or stage_camera == null:
		return false
	stage_camera.look_at(_active_weak_spot.global_position, Vector3.UP)
	_grapple()
	return true

# Battle-lifecycle verification uses direct resolution so its assertions
# isolate HP/camera/visibility wiring from the separate aim-selection test.
func verification_resolve_closest() -> bool:
	if _targets.is_empty():
		return false
	var closest := _targets[0]
	for target in _targets:
		if stage_camera.global_position.distance_to(target.global_position) < stage_camera.global_position.distance_to(closest.global_position):
			closest = target
	var was_active := _active_weak_spot_rock == closest
	_destroy_target(closest)
	if was_active:
		_assign_next_weak_spot()
	return true
