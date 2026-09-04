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

# Big rocks that take a few hits rather than one - see _spawn_target()/
# _hit_weak_spot(). BIG_ROCK_RADIUS is also read by _spawn_weak_spot() to
# place the weak spot ON the rock's surface, so the two stay in sync if
# this is ever retuned.
const BIG_ROCK_RADIUS := 0.9
const WEAK_SPOT_RADIUS := 0.16
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
var _target_tweens: Dictionary = {}

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
var _active_weak_spot: MeshInstance3D = null
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
		_shoot()

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

func _spawn_weak_spot(rock: MeshInstance3D) -> MeshInstance3D:
	var spot := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = WEAK_SPOT_RADIUS
	mesh.height = WEAK_SPOT_RADIUS * 2.0
	spot.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.1)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spot.material_override = mat
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

# Eight fixed candidate squares positioned right in front of the enemy
# (source_position) - four at one spacing and four at double that
# spacing, along the up/down/left/right axes. _spawn_loop() only ever
# uses 5 of these 8 per encounter (shuffled, first 5 taken), so which
# five squares actually get a rock varies run to run even though the
# candidate set itself is fixed. `right` reuses _base_forward the same
# way _spawn_target()'s own flight math does, so this grid is oriented
# consistently with everything else this minigame spawns.
const GRID_SPACING := 1.6

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

	var tween := rock.create_tween()
	_target_tweens[rock] = tween
	tween.tween_property(rock, "global_position", eye, FLIGHT_TIME)
	tween.finished.connect(func() -> void: _land(rock))

# MODIFIED: used to check every live rock's OWN weak spot (one per rock)
# for the closest one to the aim, plus every decoy - now there's only
# ever ONE active weak spot total (_active_weak_spot), shared across the
# whole group, and decoys are gone entirely, so this just checks that
# single point.
func _shoot() -> void:
	if _active_weak_spot == null or not is_instance_valid(_active_weak_spot):
		return
	var aim := -stage_camera.global_transform.basis.z.normalized()
	var angle := aim.angle_to((_active_weak_spot.global_position - stage_camera.global_position).normalized())
	if angle <= HIT_ANGLE:
		_hit_weak_spot(_active_weak_spot_rock)
func _grapple(aim_dir: Vector3) -> void:
	var dir: Vector3 = aim_dir.normalized() if aim_dir.length() > 0.01 else -target_actor.basis.z
	var space := get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3(0, height * 0.4, 0)
	var to: Vector3 = from + dir * GRAPPLE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space.intersect_ray(query)

	# Beam end is wherever the ray actually stopped - the max range if it
	# hit nothing at all, or whatever it struck (anchor or not).
	var beam_end: Vector3 = to if result.is_empty() else (result.position as Vector3)
	_grapple_beam_vfx(from, beam_end)

	if result.is_empty() or not (result.collider as Node).is_in_group("grapple_anchor"):
		return

	_ability_cooldown = GRAPPLE_COOLDOWN
	_is_grappling = true
	var target: Vector3 = (result.collider as Node3D).global_position

	# The anchor gets a chance to react to being reached, independent of
	# the pull itself - grapple_anchor.gd's on_grappled_to() is what
	# unlocks Staff_Diver's signal ability for the gap sequence. Diver
	# doesn't know or care what the anchor does with this; it just offers.
	if (result.collider as Node).has_method("on_grappled_to"):
		(result.collider as Node).call("on_grappled_to")

	velocity = Vector3.ZERO
	var tw := create_tween()
	# Stop a short step short of the anchor's own center, not on top of it.
	var stop_at: Vector3 = target - dir * 1.0
	tw.tween_property(self, "global_position", stop_at, GRAPPLE_PULL_DURATION)
	tw.tween_callback(func() -> void: _is_grappling = false)

# Throwaway visual: a thin beam from where the diver fired to wherever the
# shot actually ended (hit or not), fading out over the pull's own
# duration regardless of whether a pull happens. Fixed in place once
# spawned (doesn't track the diver mid-pull) - "you fired a line" reads
# fine without the beam continuously updating.
func _grapple_beam_vfx(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.01:
		return
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = dist
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.85, 0.3, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = mat

	get_parent().add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, PI / 2.0)   # CylinderMesh's long axis is local Y, look_at faces -Z

	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, GRAPPLE_PULL_DURATION)
	tw.tween_callback(beam.queue_free)


# One hit on the CURRENT weak spot - always +1 toward that rock's
# HITS_TO_DESTROY count, flashed red so a hit reads as a hit regardless
# of whether it's lethal this time. Not lethal until the count actually
# reaches HITS_TO_DESTROY - short of that the rock stays alive and
# flying. Either way, a hit always moves the weak spot on to a new random
# rock (_assign_next_weak_spot()) - that "always advance, whether or not
# this one died" is what makes which rock is live next feel unpredictable
# instead of a fixed rotation.
func _hit_weak_spot(rock: MeshInstance3D) -> void:
	var hits: int = int(_rock_hits.get(rock, 0)) + 1
	_rock_hits[rock] = hits
	if _active_weak_spot != null and is_instance_valid(_active_weak_spot):
		_grapple_beam(stage_camera.global_position, _active_weak_spot.global_position)
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
	var flight: Tween = _target_tweens.get(target, null)
	if flight != null and flight.is_valid():
		flight.kill()
	_target_tweens.erase(target)
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
	_target_tweens.erase(target)
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
	_shoot()
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
