# Musashi's special-encounter defense: mouse-look aims a first-person
# camera at the enemy himself, who drifts between two random points
# 30-50m out (ENEMY_START/ENEMY_END, both within the aim cone) rather
# than standing still. A single yellow weak spot hops to a new random
# point on his body after every hit (or after WEAK_SPOT_TIMEOUT with no
# hit) - land TARGET_COUNT hits to clear the encounter.
#
# MODIFIED: this used to be "the enemy launches rocks at the diver, shoot
# them down before they land" - object_hit/the battle-owned damage path
# that went with unshot rocks reaching the diver is still declared and
# connected in battle.gd, but nothing in this file emits it anymore now
# that there's nothing incoming to dodge. Worth a real decision, not
# assumed here: should something else put the diver at risk during this
# encounter (a timer, an occasional counter-swing), or is this now a
# pure-offense encounter with the follow-up swing afterward as the only
# risk, same as a flawless run already guarantees dodging entirely?
class_name GrappleInterceptMinigame
extends Control

signal finished(hits: int, total: int)
signal object_hit

# MODIFIED: was 5 (one hit per thrown rock, all in a single wave) - now
# the number of correct-color spheres that clear ONE vortex wave (2
# yellow + 2 green spawn each launch, exactly TARGET_COUNT of them being
# the safe color - see launch_vortex()). The encounter runs
# TOTAL_VORTEX_WAVES of these back to back, so the true overall total is
# TARGET_COUNT * TOTAL_VORTEX_WAVES, not TARGET_COUNT alone - see
# _update_progress()/_finish_now()'s own use of that product.
const TARGET_COUNT := 2
# How many vortex waves the encounter runs before it's over - same idea
# as the other special encounters' own fixed round counts.
const TOTAL_VORTEX_WAVES := 3
const TITLE_HOLD := 0.8
# MODIFIED: was 3.2 - still felt like the rocks crossed the whole
# distance too fast to comfortably aim and grapple twice. Doubled (halving
# actual travel speed) rather than touching the distance itself.
const FLIGHT_TIME := 9
const HIT_ANGLE := deg_to_rad(7.0)
const LOOK_SENSITIVITY := 0.0035
# MODIFIED: was 0.75/0.48 - with GRID_SPACING at 2.7, the outer spawn
# ring sits ~38.5 degrees off-center (atan(2.7*2/6.8), where 6.8 is the
# diver-to-enemy stage distance) but the old MAX_PITCH only allowed
# looking 27.5 degrees - those rocks were not hard to hit, they were
# mathematically impossible to ever look at, for their whole flight (see
# _fly_rock()'s own comment for why a straight-line rock's angle from the
# camera never changes). Widened past the worst case with margin; the
# _fly_rock() curve below does most of the real work by shrinking that
# angle over time, this is just headroom for the first instant of flight.
const MAX_YAW := 0.85
const MAX_PITCH := 0.63

# How far _grapple()'s raycast reaches. MUST stay comfortably past
# ENEMY_MOVE_MAX_DIST (50, see below) - the enemy himself is the target
# now, and a raycast shorter than his farthest possible drift distance
# would make him literally unhittable whenever he's out past it, not
# just hard to hit.
const GRAPPLE_RANGE := 60.0

# MODIFIED: was 0.16 - still hard to pick out at typical viewing distance
# even with no_depth_test/the color pulse. Bumped up; see _spawn_weak_
# spot()'s own pixel_size line, which derives the sprite's actual size
# from this, so the hitbox stays in sync automatically.
const WEAK_SPOT_RADIUS := 0.24

var stage_root: SubViewport
var stage_camera: Camera3D
var target_actor: Node3D
var source_position := Vector3.ZERO

# Set by battle.gd (_do_grapple_intercept_encounter()) - the actual enemy
# Goblin, so run() below can physically move it, not just the abstract
# source_position rocks spawn relative to. Optional: null is a valid,
# harmless value (see run()'s own guard) for anything that builds this
# minigame without an enemy to move, e.g. tools/shoot_grapple_intercept.gd.
var enemy_actor: Node3D = null

# How far out the enemy repositions to - same distance band, reachable
# from ANY point inside it since both endpoints are generated within the
# yaw/pitch cone (see _random_cone_position()). Well past GRAPPLE_RANGE
# on purpose: the enemy's own body was never a grapple target (only rocks
# have weak spots), so there's nothing to actually hit out here - this is
# purely "can the player still see and track where the threat is coming
# from," not "can the raycast reach it."
const ENEMY_MOVE_MIN_DIST := 30.0
const ENEMY_MOVE_MAX_DIST := 50.0

# The two ends of the enemy's back-and-forth drift - computed once in
# run() (needs _base_forward/eye to exist first) and re-read by
# _drift_enemy() each time it starts a new leg, so both stay fixed for
# the whole encounter rather than re-rolling every trip.
var ENEMY_START := Vector3.ZERO
var ENEMY_END := Vector3.ZERO

# Where enemy_actor actually stood before this minigame moved it -
# _exit_tree() below sends it back here and kills the drift tween, since
# that tween lives on enemy_actor itself (create_tween() ties a tween's
# lifetime to the node it's called on, not to this Control) and would
# otherwise keep running - and the enemy kept wandering 30-50m away -
# straight through the follow-up swing and into whatever comes after,
# long after this encounter is actually over.
var _enemy_home_position := Vector3.ZERO
var _enemy_drift_tween: Tween = null
# Guards _exit_tree()'s restore below against run()'s own early-return
# (stage_camera/target_actor/stage_root missing) - in that path
# enemy_actor's position is never actually touched in the first place,
# so snapping it to _enemy_home_position's untouched Vector3.ZERO default
# would be a real (if rare) regression, not a no-op.
var _enemy_was_moved := false

# MODIFIED: was Array[MeshInstance3D] of live rocks, each with its own
# _rock_hits count - replaced entirely now that the grapple target IS
# the enemy himself rather than a group of thrown rocks. Only one thing
# is ever grappled now, so there's no "which one" to track at all - just
# whether the current weak spot (always somewhere on enemy_actor) has
# been hit yet.
#
# ONE weak spot exists at a time, same shape as the old rock version -
# _assign_next_weak_spot() below picks a new random point on the enemy's
# body after every hit (and after WEAK_SPOT_TIMEOUT with no hit), rather
# than hopping between different targets, since there's only ever the one.
var _active_weak_spot: Area3D = null

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
# MODIFIED (added): was a local in _ready() - promoted to a member so
# launch_vortex() can repoint it at the round's yellow/green rule.
var _hint: Label

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

    _hint = Label.new()
    _hint.text = "Grapple the glowing weak spot on the enemy before it moves"
    _hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _hint.offset_top = 78.0
    _hint.offset_left = -330.0
    _hint.offset_right = 330.0
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_hint)

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
    # MODIFIED (added): enemy_actor to the required list - the grapple
    # target IS the enemy now (see _random_point_on_enemy()), not a group
    # of thrown rocks that could exist independently of him, so this
    # minigame is meaningless without a real enemy to aim at.
    if stage_camera == null or target_actor == null or stage_root == null or enemy_actor == null or not is_instance_valid(enemy_actor):
        push_error("GrappleInterceptMinigame requires stage_root, stage_camera, target_actor, and enemy_actor")
        finished.emit(0, TARGET_COUNT * TOTAL_VORTEX_WAVES)
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
    # MODIFIED: this used to also set up ENEMY_START/ENEMY_END and call
    # _assign_next_weak_spot() to start the enemy-body weak-spot cycle -
    # the encounter is vortex-only now. A three-times-in-a-row loop
    # briefly sat here calling launch_vortex() with no wait between
    # calls; since launch_vortex() starts by clearing whatever the
    # previous call just spawned (_clear_vortex()), that discarded the
    # first two calls' spheres instantly and only ever kept the third -
    # not a real repeat, just two wasted spawns. Restored to one working
    # launch, after the same TITLE_HOLD pause the old ending used.
    await get_tree().create_timer(TITLE_HOLD).timeout
    launch_vortex()


# A random direction inside the same yaw/pitch cone the player can
# actually look into (MAX_YAW/MAX_PITCH), built with the exact same
# rotation order _update_camera() uses to aim the camera - so "a random
# reachable direction" and "wherever the player is currently looking" are
# always measured the same way. Yaw first (around world UP), then pitch
# around the yawed forward's own right vector.
func _random_cone_direction() -> Vector3:
    var yaw := randf_range(-MAX_YAW, MAX_YAW)
    var pitch := randf_range(-MAX_PITCH, MAX_PITCH)
    var dir := _base_forward.rotated(Vector3.UP, yaw)
    var right := dir.cross(Vector3.UP).normalized()
    return dir.rotated(right, pitch).normalized()

# Ping-pongs enemy_actor between ENEMY_START and ENEMY_END for as long as
# the minigame runs - queue_free()/_exit_tree() implicitly kills this
# along with everything else parented under this Control when the
# encounter ends, so there's no separate stop() to call.
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
    # Safety net for any exit path that skipped _finish_now() (there
    # isn't one today, but this costs nothing and _restore_enemy_home()
    # is a no-op the second time either way).
    _restore_enemy_home()

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

# A random LOCAL offset (relative to enemy_actor's own origin, feet at
# y=0) on the rough capsule his body occupies - Goblin.height/radius are
# the same rough bounding numbers battle.gd's own framing math already
# trusts elsewhere, not new geometry invented here. Biased toward
# whichever side currently faces the camera ("in front", per the
# request) with some side-to-side jitter rather than a fully random
# angle, both so the marker reads as being ON the visible surface (not
# tucked around back) and so it doesn't sit dead-center on the chest
# every single time. Pushed out by `radius + 0.05` so it sits just proud
# of the body surface rather than exactly on/inside it.
#
# Computed in WORLD-axis terms (UP for height, a horizontal direction
# independent of enemy_actor's own rotation) rather than the enemy's own
# local basis - correct for as long as enemy_actor's rotation stays fixed
# during the encounter (true today: _drift_enemy() only ever tweens
# global_position, never rotation). If the enemy ever starts turning to
# face something mid-encounter, this would need to account for that
# rotation too, or the marker could drift toward the wrong side.
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

# MODIFIED: was a Sprite3D showing icons/target.png, then a yellow sphere
# parented to whichever ROCK held it - now parented to enemy_actor
# directly (see _random_point_on_enemy() above), since the grapple
# target IS him now, not a group of thrown rocks. Being a CHILD is what
# makes it track enemy_actor's own drift tween for free, the same trick
# the rock version used for its own flight tween - this needs no per-
# frame repositioning of its own.
func _spawn_weak_spot() -> Area3D:
    var spot := Area3D.new()
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
    # MODIFIED (added): the spot sits ON the enemy's own body (see
    # _random_point_on_enemy() above), which means his own mesh is
    # exactly as likely to be BETWEEN the camera and the spot as not
    # (especially from the side, or once he's drifted off-angle) - normal
    # depth testing would just hide it behind him from those angles.
    # no_depth_test makes it draw regardless of what's in front of it -
    # visible THROUGH his body, per the request - and render_priority
    # keeps it drawing above other unshaded/no-depth-test overlays too
    # (the grapple beam), not just him.
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

# MODIFIED: was a modulate/scale pulse on the old Sprite3D - modulate is
# a CanvasItem property Sprite3D happened to expose, but MeshInstance3D
# isn't a CanvasItem at all, so a plain mesh's "color" pulse has to run
# through its material's emission strength instead. Scale still pulses
# the same way as before (actual size change reads as "flashing" far
# more than a color/brightness shift alone, especially at this small an
# on-screen footprint).
func _pulse_weak_spot(mesh_inst: MeshInstance3D) -> void:
    var mat := mesh_inst.material_override as StandardMaterial3D
    var tw := mesh_inst.create_tween()
    tw.set_loops()
    # set_parallel(true) applies to every Tweener appended after it until
    # chain() breaks out again - so each pair below runs together (glow
    # AND scale moving as one beat), and chain() is what sequences those
    # two pairs one after the other rather than all four running at once.
    tw.set_parallel(true)
    tw.tween_property(mesh_inst, "scale", Vector3.ONE * 1.6, 0.3)
    tw.tween_property(mat, "emission_energy_multiplier", 2.5, 0.3)
    tw.chain()
    tw.set_parallel(true)
    tw.tween_property(mesh_inst, "scale", Vector3.ONE, 0.3)
    tw.tween_property(mat, "emission_energy_multiplier", 0.7, 0.3)
    
# Picks ONE random rock out of whatever's still alive in _targets and
# gives it a fresh weak spot at a new random surface point - called once
# after the initial burst (_spawn_loop()) and again after every single
# hit (_hit_weak_spot(), win or lose), and also from _land() if the rock
# that just reached the player was the one holding the spot. Freeing the
# OLD spot here handles the "rock survived, moving to a new point"
# case; if the previous holder was just destroyed/freed instead, its
# child spot is already gone with it and is_instance_valid() below simply
# skips the redundant free.
# MODIFIED: used to pick a random ROCK out of whichever were still alive
# and give IT the marker - now there's only ever the one target
# (enemy_actor himself), so this just moves the spot to a fresh random
# point on his body. Still re-runs on the same three triggers as before:
# after a hit, after WEAK_SPOT_TIMEOUT with no hit, and the very first
# time (called once from run() after TITLE_HOLD).
func _assign_next_weak_spot() -> void:
    if _active_weak_spot != null and is_instance_valid(_active_weak_spot):
        _active_weak_spot.queue_free()
    _active_weak_spot = null
    if not is_instance_valid(enemy_actor):
        return
    _active_weak_spot = _spawn_weak_spot()
    _start_weak_spot_timeout(_active_weak_spot)

# No penalty for missing the window - per the user's own earlier call,
# nothing should cost the player here except an actual hit landing on
# them. This just moves the spot to a new random point after
# WEAK_SPOT_TIMEOUT seconds if nobody's hit it yet, same as a hit would,
# just without the score/flash side effects.
#
# `spot` is captured by value at the moment this starts, not read fresh
# off _active_weak_spot later - by the time this timer fires, a hit may
# have ALREADY reassigned _active_weak_spot to a new point. Comparing the
# current _active_weak_spot against this specific captured `spot` is what
# tells this timeout "is the thing I was timing still even the active
# one," so a stale timer can't stomp on a reassignment that already
# happened for a real reason.
const WEAK_SPOT_TIMEOUT := 2.0

func _start_weak_spot_timeout(spot: Area3D) -> void:
    await get_tree().create_timer(WEAK_SPOT_TIMEOUT).timeout
    if not is_instance_valid(self):
        return
    if _active_weak_spot == spot:
        _assign_next_weak_spot()

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
# mesh in _spawn_weak_spot()) IS the "did this land on the weak spot"
# check; no separate distance/angle math needed once the shape is sized
# correctly; whether the ray reached that shape is the whole answer.
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
        _hit_weak_spot()
        return
    # MODIFIED (added): also checks the vortex ring (see launch_vortex())
    # when it's active - a linear scan over at most 5 spheres, cheap
    # enough to just do every shot rather than needing its own spatial
    # lookup.
    if _vortex_active:
        for entry in _vortex_spheres:
            if result.collider == entry.node:
                _resolve_vortex_hit(entry)
                return

# MODIFIED: used to track a per-rock hit count toward HITS_TO_DESTROY,
# with the rock only actually leaving play once that count was reached -
# there's only the one target now (enemy_actor), and nothing about him
# should ever "destroy"/disappear mid-encounter, so every hit here counts
# directly: +1 toward TARGET_COUNT, a red flash to confirm the hit
# landed, then the spot moves on to a fresh random point on his body.
func _hit_weak_spot() -> void:
    _flash_enemy_red()
    _hits += 1
    _resolved += 1
    _update_progress()
    if _resolved >= TARGET_COUNT:
        _maybe_finish()
    else:
        _assign_next_weak_spot()

# A quick red emission pulse on the enemy's OWN material - this is the
# "you hit it" confirmation. Settles back to whatever his material's
# emission was doing before (read fresh each call, not a hardcoded
# resting value the way the old rock version had ROCK_EMISSION_COLOR/
# ENERGY to fall back to) since Goblin owns its own idle/hurt-flash
# material state and this shouldn't need to know or guess at it.
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

func _update_progress() -> void:
    # MODIFIED: TARGET_COUNT alone is now just ONE wave's worth (2) - the
    # real total across the whole encounter is TARGET_COUNT *
    # TOTAL_VORTEX_WAVES (6), same product _finish_now()'s own final
    # report uses.
    if _progress != null:
        _progress.text = "%d / %d hits" % [_hits, TARGET_COUNT * TOTAL_VORTEX_WAVES]

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
    # MODIFIED (added): has to happen HERE, synchronously, before
    # finished.emit() below - not left to _exit_tree(). battle.gd calls
    # minigame.queue_free() and then IMMEDIATELY _restore_stage_camera()
    # in the same function, on the same frame; queue_free() only
    # SCHEDULES removal, so _exit_tree() doesn't actually run until later
    # that frame at the earliest - too late to matter for a camera framing
    # call that already happened. Restoring the enemy's real position
    # right here means it's back home before battle.gd ever gets a chance
    # to frame the camera around wherever the drift left it.
    _restore_enemy_home()
    # Vortex spheres are children of stage_root (same as the enemy's own
    # weak spot's rendering needs stage_root's World3D), NOT children of
    # this Control - queue_free()-ing the minigame later would never take
    # them with it, so this is the only thing that ever cleans them up.
    # Also stops _process()'s per-frame simulation from running against a
    # now-empty/stale _vortex_spheres for no reason.
    _clear_vortex()
    # MODIFIED: was TARGET_COUNT alone (5, back when one wave was the
    # whole encounter) - now TARGET_COUNT is just one wave's worth (2),
    # so the real total the caller should judge "how well did they do"
    # against is every wave's worth combined.
    finished.emit(_hits, TARGET_COUNT * TOTAL_VORTEX_WAVES)

func _restore_enemy_home() -> void:
    if _enemy_drift_tween != null and _enemy_drift_tween.is_valid():
        _enemy_drift_tween.kill()
    _enemy_drift_tween = null
    if _enemy_was_moved and enemy_actor != null and is_instance_valid(enemy_actor):
        enemy_actor.global_position = _enemy_home_position
        _enemy_was_moved = false

# Verification hook: aim directly at the active weak spot and fire
# through the exact same hit-selection path used by mouse input.
#
# MODIFIED: used to find the geometrically closest of several PER-ROCK
# weak spots - now there's only ever one active spot total (somewhere on
# enemy_actor), so this just aims at it directly.
func auto_intercept_closest() -> bool:
    if stage_camera == null:
        return false
    if _active_weak_spot != null and is_instance_valid(_active_weak_spot):
        stage_camera.look_at(_active_weak_spot.global_position, Vector3.UP)
        _grapple()
        return true
    # MODIFIED (added): the enemy-body weak spot is dormant now that
    # run() only launches the vortex (see its own comment) - falls
    # through to aiming at whichever live vortex sphere is the SAFE
    # color, so this still exercises the real raycast/aim path
    # (_grapple()) rather than resolving directly. Never aims at a
    # dangerous-color sphere - this is testing "can the aim path land a
    # good hit," not deliberately taking the penalty.
    for entry in _vortex_spheres:
        if bool(entry.is_yellow) == _vortex_safe_is_yellow:
            var node := entry.node as Area3D
            if is_instance_valid(node):
                stage_camera.look_at(node.global_position, Vector3.UP)
                _grapple()
                return true
    return false

# =====================================================================
# VORTEX: an alternate/escalation attack - a ring of yellow/green spheres
# bouncing inside a fixed disc 30m dead ahead, one color safe to grapple
# and one to avoid this round. NOT wired into run() yet - launch_vortex()
# is ready to call, but WHEN it fires relative to the enemy-body weak
# spot (replaces it, runs alongside it, or triggers as an escalation
# after N hits) is still an open call.
# =====================================================================

# Real-world-unit conversion since the travel distance was specified in
# feet - nothing else in this file uses feet, everything else here
# (GRAPPLE_RANGE, ENEMY_MOVE_MIN/MAX_DIST) is already in meters.
const FEET_TO_METERS := 0.3048
# How far short of the enemy/player the vortex starts/ends - not AT
# either one, so it visibly launches from near him and arrives near you
# rather than starting/ending exactly on top of a model.
const VORTEX_LAUNCH_OFFSET := 10.0 * FEET_TO_METERS
# How long the whole disc takes to travel from its start point to its end
# point - separate from how fast the SPHERES move within the disc
# (VORTEX_SPEED_MIN/MAX below); this is "slowly launch," that is the
# swirling once it's already moving.
const VORTEX_TRAVEL_TIME := 5.0
const VORTEX_BOUNDARY_RADIUS := 3.0
const VORTEX_SPHERE_RADIUS := 0.35
const VORTEX_MIN_SPHERES := 3
const VORTEX_MAX_SPHERES := 5
const VORTEX_SAFE_COLOR := Color(1.0, 0.9, 0.15)
const VORTEX_SAFE_EMISSION := Color(1.0, 0.85, 0.1)
const VORTEX_DANGER_COLOR := Color(0.15, 0.95, 0.35)
const VORTEX_DANGER_EMISSION := Color(0.1, 0.9, 0.3)

# MODIFIED: back to the deterministic semicircular-leg system (see
# _arc_point()/_random_bulge_axis(), both restored below) for the FIRST
# approach to center - every sphere still converges along the same
# curved, perfectly-timed arc as before, which is what guarantees they
# all reach it at the same instant (every leg takes exactly this long
# regardless of how far that sphere's own arc spans). What changed is
# what decides a leg is "done": not t>=1.0 anymore, but REAL collision
# detection between the spheres' own Area3D/CollisionShape3D nodes (see
# _update_vortex()'s use of get_overlapping_areas(), not a manual
# distance formula against an arbitrary "near center" radius) - see
# _apply_vortex_bounce(). The instant two spheres actually touch, each
# one's CURRENT velocity is calculated on the spot from its own arc
# formula (the tangent direction/speed it genuinely had at that exact
# point on the curve - see _apply_vortex_bounce()'s derivative math),
# reversed as the bounce, and handed off to real integration + collision
# physics for the rest of the wave. A sphere never goes back to the arc
# formula once it's made that switch.
const VORTEX_ARC_LEG_TIME := 1.4

# How many waves have been launched so far - incremented at the top of
# launch_vortex() itself (not by its callers), since it's called from
# both run() (the first wave) and _advance_or_finish_vortex() (every
# wave after), and this only needs counting in the one place that
# actually happens.
var vortex_count := 0

var _vortex_active := false
# Tracks the current wave's travel tween so _clear_vortex() can kill it
# outright - without this, a wave cleared EARLY (all correct spheres
# already shot down) would leave its old travel tween still running in
# the background, and when it eventually finished on its own later, its
# `finished` signal would fire _on_vortex_reached_player() against
# whatever the NEXT wave's state happens to be by then, applying a bogus
# damage hit that has nothing to do with how that next wave is actually
# going.
var _vortex_travel_tween: Tween = null
var _vortex_center := Vector3.ZERO
# The disc's own local axes, fixed once at launch from _base_forward (not
# the player's LIVE aim direction) - so the ring holds still in world
# space and doesn't spin/reorient as the player looks around.
var _vortex_right := Vector3.RIGHT
var _vortex_up := Vector3.UP
# Which color is safe to grapple this round - "safe" reads as the bright
# yellow used elsewhere in this file for "aim here" (the enemy's own weak
# spot, the old rock target), so the vocabulary stays consistent: yellow
# always means "hit this."
var _vortex_safe_is_yellow := true
# Array[Dictionary], each {node: Area3D, pos2d: Vector2, is_yellow: bool,
# using_physics: bool, vel2d: Vector2, leg_start: Vector2,
# leg_end: Vector2, leg_t: float, bulge_axis: Vector2}. Every field lives
# in the disc's own 2D local plane (see _vortex_world_pos()), not world
# space. `using_physics` splits each sphere's life into exactly two
# phases (see _update_vortex()): false means it's still governed by the
# leg_start/leg_end/leg_t/bulge_axis arc fields (_arc_point()); once a
# real collision flips it to true, those arc fields are never read again
# and vel2d takes over completely instead.
var _vortex_spheres: Array[Dictionary] = []

# "instance_id_a_instance_id_b" (lower id first) -> bool, whether that
# specific pair was touching as of the last _update_vortex() check - see
# 2b's own comment in _update_vortex() for why this rising-edge tracking
# exists (a real observed double-bounce bug without it).
var _vortex_touching: Dictionary = {}

# MODIFIED (added): the disc used to sit at one fixed point 30m dead
# ahead - now it launches from near the enemy and travels to near the
# player over VORTEX_TRAVEL_TIME. `start`/`end` are both measured along
# _base_forward (the same fixed "dead ahead" direction _vortex_right/
# _vortex_up are already built from, not the player's LIVE aim), pulled
# in from each end by VORTEX_LAUNCH_OFFSET so it visibly leaves the
# enemy's side and arrives at the player's rather than starting/ending
# exactly on top of either model. enemy_actor.global_position is read
# ONCE here, at launch - if he's mid-drift (_drift_enemy()) this just
# takes wherever he happens to be at that instant as the launch point,
# it doesn't track him afterward.
func launch_vortex() -> void:
    vortex_count += 1
    var start := enemy_actor.global_position - _base_forward * VORTEX_LAUNCH_OFFSET
    var end := stage_camera.global_position + _base_forward * VORTEX_LAUNCH_OFFSET
    _vortex_center = start
    _vortex_right = _base_forward.cross(Vector3.UP).normalized()
    _vortex_up = _vortex_right.cross(_base_forward).normalized()
    _vortex_safe_is_yellow = randf() < 0.5
    if _hint != null:
        _hint.text = "Grapple YELLOW, avoid GREEN (wave %d/%d)" % [vortex_count, TOTAL_VORTEX_WAVES] if _vortex_safe_is_yellow else "Grapple GREEN, avoid YELLOW (wave %d/%d)" % [vortex_count, TOTAL_VORTEX_WAVES]

    _clear_vortex()
    # Each new launch starts the cardinal-direction cycle fresh (see
    # _random_vortex_spawn_point()) - otherwise a second vortex launched
    # later in the same encounter would pick up mid-rotation from
    # wherever the last one left off instead of starting at 0 degrees.
    _vortex_next_angle_index = 0
    # MODIFIED: was 4 independent 50/50 coin flips, which could (rarely)
    # land all 4 on the same color with nothing left to hit - now always
    # exactly 2 yellow and 2 green, one at each of the 4 fixed halfway
    # points, with a shuffle deciding WHICH points get which color so the
    # layout isn't the same every launch.
    var colors: Array[bool] = [true, true, false, false]
    colors.shuffle()
    for is_yellow in colors:
        _spawn_vortex_sphere(is_yellow)
    _vortex_active = true

    # Tweens the plain _vortex_center Vector3 directly - tween_property()
    # works on any property reachable through the object's own get/set,
    # not just a Node's exposed ones, so this needs nothing fancier than
    # pointing it at `self`. _vortex_world_pos() already re-reads
    # _vortex_center fresh every frame (see _update_vortex()'s last pass),
    # so the whole disc - and every sphere swirling inside it - rides
    # along automatically; nothing else needs to know this is happening.
    #
    # MODIFIED (added): tracked in _vortex_travel_tween (see its own
    # comment) and its finished signal now drives the "reached the player
    # without clearing it" damage check - _on_vortex_reached_player()
    # only actually does anything if this wave is STILL active by the
    # time the disc arrives, i.e. the player never cleared it early.
    _vortex_travel_tween = create_tween()
    _vortex_travel_tween.tween_property(self, "_vortex_center", end, VORTEX_TRAVEL_TIME)
    _vortex_travel_tween.finished.connect(_on_vortex_reached_player)

# The four quarter-circle directions - spaced a quarter turn (90
# degrees/PI*0.5 radians) apart, not a fraction of the radius. East,
# North, West, South in standard unit-circle terms (cos/sin of each).
const VORTEX_CARDINAL_ANGLES: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]

# Cycles through VORTEX_CARDINAL_ANGLES so every sphere spawned (the one
# initial batch in launch_vortex() - nothing respawns mid-wave anymore,
# see _resolve_vortex_hit()) lands on one of the four fixed directions in
# turn, rather than each spawn call picking independently and possibly
# landing on the same direction twice in a row (or skipping one of the
# four entirely).
var _vortex_next_angle_index := 0

# MODIFIED: was a random distance between center and boundary, with a
# reject-and-retry loop to avoid overlap. Now a FIXED halfway point (per
# direct request) - exactly VORTEX_BOUNDARY_RADIUS*0.5 out along whichever
# cardinal is next in the cycle. No retry needed for overlap anymore: the
# 4 cardinal points at a shared fixed radius sit ~1.4x that radius apart
# from each other (adjacent points on a circle, 90 degrees apart), which
# is always comfortably more than 2*VORTEX_SPHERE_RADIUS - they can't
# overlap at spawn regardless of how the 4 colors get shuffled across them.
func _random_vortex_spawn_point() -> Vector2:
    var angle: float = VORTEX_CARDINAL_ANGLES[_vortex_next_angle_index % VORTEX_CARDINAL_ANGLES.size()]
    _vortex_next_angle_index += 1
    var direction := Vector2(cos(angle), sin(angle))
    return direction * (VORTEX_BOUNDARY_RADIUS * 0.5)

# A point along a SEMICIRCLE from leg_start to leg_end, t fraction of the
# way through (0 = leg_start, 1 = leg_end) - a true arc traced with
# sin/cos. `mid` is the CENTER of the arc's own circle (the midpoint of
# the straight line connecting the two endpoints), and `radius` is half
# that line's length, so a circle of that radius centered on `mid` passes
# through both leg_start and leg_end exactly. `axis1` points from mid
# toward leg_start (so t=0 lands exactly on leg_start); `bulge_axis` is
# perpendicular to axis1 and picked once per leg with a random sign (see
# _random_bulge_axis()) - that sign is what makes the arc curve to one
# side or the other, which is the "random" part, since a semicircle
# between two fixed points could bulge either way.
#
# At t=0: theta=0, cos=1/sin=0, so pos = mid + radius*axis1 = leg_start.
# At t=1: theta=PI, cos=-1/sin=0, so pos = mid - radius*axis1 = leg_end
# (since mid is the midpoint, mid - (leg_start - mid) = leg_end exactly).
func _arc_point(leg_start: Vector2, leg_end: Vector2, bulge_axis: Vector2, t: float) -> Vector2:
    var mid := (leg_start + leg_end) * 0.5
    var radius := leg_start.distance_to(leg_end) * 0.5
    if radius < 0.001:
        return leg_end
    var axis1 := (leg_start - mid) / radius
    var theta := t * PI
    return mid + axis1 * (radius * cos(theta)) + bulge_axis * (radius * sin(theta))

# The perpendicular reference direction for one leg's arc, with a random
# sign - see _arc_point()'s own comment for why the sign is what actually
# makes each individual arc "random" (which side it bulges toward)
# despite always connecting the same two fixed endpoints.
func _random_bulge_axis(leg_start: Vector2, leg_end: Vector2) -> Vector2:
    var diff := leg_start - leg_end
    if diff.length() < 0.001:
        return Vector2.RIGHT
    var perp := diff.normalized().rotated(PI * 0.5)
    return perp if randf() < 0.5 else -perp

# MODIFIED: color used to be an independent 50/50 roll made inside this
# function - now passed in explicitly by launch_vortex(), which shuffles
# a fixed [yellow, yellow, green, green] set beforehand so every wave
# spawns exactly 2 of each regardless of chance. NOTE: GDScript function
# parameters are declared as `name: Type`, never `var name: Type` - the
# latter is a parse error.
func _spawn_vortex_sphere(is_yellow: bool) -> void:
    var pos2d := _random_vortex_spawn_point()
    # Every sphere's first phase is the scripted arc leg toward the exact
    # center (Vector2.ZERO in the disc's own local space) - leg_end is
    # always the center, never a wall point, because there's no scripted
    # "leg back out" anymore: the instant real collision detection fires
    # (see _apply_vortex_bounce()), this sphere switches to using_physics
    # permanently and these arc fields stop being read at all. vel2d
    # starts at ZERO and is meaningless until that switch happens.
    var leg_end := Vector2.ZERO

    var area := Area3D.new()
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

# MODIFIED: was _process() - get_overlapping_areas() (see _update_vortex())
# only reflects newly-updated overlap state once per PHYSICS tick, not
# once per rendered frame. Checking it from _process() meant that
# whenever the render rate outpaced the physics tick rate, several
# consecutive _process() calls could all see the exact same stale
# "still touching" answer (physics hadn't recomputed anything between
# them) and each one independently fired _apply_vortex_bounce() again -
# a real, observed double (or triple) bounce for what should have been
# one collision event. _physics_process() runs exactly once per physics
# tick, the same cadence the physics server itself updates on, so this
# check now only ever runs once per real update.
func _physics_process(delta: float) -> void:
    if _vortex_active:
        _update_vortex(delta)

# Two-phase per-frame update. Phase 1 (using_physics == false): position
# comes straight from the scripted arc formula, exactly as before -
# leg_t advances by delta/VORTEX_ARC_LEG_TIME (same denominator for every
# sphere regardless of its own arc length), which is what guarantees
# every surviving sphere reaches the shared leg_end (center) at the same
# wall-clock moment. Phase 2 (using_physics == true): position is
# integrated from vel2d each frame instead - no formula, just real motion.
#
# The switch from phase 1 to phase 2 is driven by REAL collision
# detection between the spheres' own Area3D nodes (get_overlapping_areas()
# below) rather than by leg_t reaching 1.0, or by a manual distance
# formula against an arbitrary "near center" radius - if the physics
# server says two spheres are actually touching, wherever that happens to
# be, that's the meeting, full stop. It's an ALL-AT-ONCE event, not per
# pair, though: the instant any two still-scripted spheres are genuinely
# touching, every surviving still-scripted sphere switches together, not
# just that one pair (see 2a's own comment for why a per-pair release
# left a straggler waiting alone).
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

    # Write this frame's positions to the real Area3D nodes BEFORE
    # checking for overlaps below - get_overlapping_areas() answers "what
    # is this Area3D touching right now," so the physics server needs
    # this frame's actual position in place first, not last frame's.
    for entry in _vortex_spheres:
        var node := entry.node as Area3D
        if is_instance_valid(node):
            node.global_position = _vortex_world_pos(entry.pos2d)

    # 2a) The shared center-meet event, driven by REAL collision
    # detection - if any two still-scripted spheres' Area3D nodes are
    # actually overlapping (per Godot's own physics server, not a manual
    # distance formula), release every still-scripted sphere into physics
    # together, each deriving its own velocity from wherever it currently
    # sits on its OWN curve (see _apply_vortex_bounce()). Releasing only
    # the one colliding pair would leave any other still-scripted sphere
    # waiting alone for its own individual partner - which, if that
    # partner already peeled off into physics and wandered away, might
    # not come back around for a long, unpredictable stretch (this was an
    # actual observed bug: a straggler sphere took 5+ real seconds to
    # finally get released, well past the ~1.4s the whole meeting should
    # take).
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

    # 2b) Ongoing sphere-sphere collision for spheres already in physics
    # mode - same real Area3D overlap check, keeping them bouncing off
    # each other for the rest of the wave. get_overlapping_areas() only
    # tells us THAT two spheres are touching, not by how much or which
    # way - separating them cleanly and picking a bounce direction still
    # needs their actual pos2d values, same as any collision response
    # would (see _apply_vortex_bounce()'s physics-mode branch for the
    # velocity side of this).
    #
    # MODIFIED (added): _vortex_touching gates the actual bounce to the
    # RISING EDGE of contact (wasn't touching last check, is touching
    # now) - a real, observed bug otherwise: get_overlapping_areas()'s
    # underlying state only updates once per physics tick, and can keep
    # reporting "still touching" for several consecutive ticks after a
    # bounce already separated the pair (whether from a genuine one-tick
    # lag or the physics engine's own small collision margin around each
    # shape), and a plain "if touching, bounce" check would re-fire every
    # one of those ticks - each firing negates velocity again, so an even
    # number of extra re-fires cancels straight back to the ORIGINAL
    # pre-bounce direction, which read as the pair bouncing over and over
    # in place instead of separating cleanly. Tracking "was this exact
    # pair already touching as of the last check" and only bouncing when
    # that flips from false to true makes one real contact fire exactly
    # once, no matter how many extra ticks the overlap state lags behind.
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
            var key: String = _vortex_pair_key(a_node, b_node)
            var now_touching: bool = b_node in a_node.get_overlapping_areas()
            var was_touching: bool = bool(_vortex_touching.get(key, false))
            _vortex_touching[key] = now_touching
            if not now_touching:
                continue
            var diff: Vector2 = a.pos2d - b.pos2d
            var dist: float = diff.length()
            var normal: Vector2 = diff / dist if dist > 0.001 else Vector2.RIGHT
            # Separation runs every tick the pair is still touching (cheap,
            # and keeps nudging them apart even across a laggy multi-tick
            # overlap report) - only the bounce itself is gated to the
            # rising edge below.
            var overlap: float = maxf(VORTEX_SPHERE_RADIUS * 2.0 - dist, 0.0)
            a.pos2d = a.pos2d + normal * (overlap * 0.5)
            b.pos2d = b.pos2d - normal * (overlap * 0.5)
            if was_touching:
                continue
            _apply_vortex_bounce(a)
            _apply_vortex_bounce(b)

    # 3) Wall collision: only meaningful once a sphere is in physics mode
    # (a phase-1 sphere is still converging toward center along its arc,
    # comfortably inside the boundary the whole time) - reflect off the
    # boundary circle's inward normal whenever it would otherwise cross
    # it, the same velocity-across-a-surface-normal reflection a light
    # ray or a billiard ball bouncing off a flat wall uses. The boundary
    # itself isn't a real collision object (there's nothing to overlap-
    # detect against), so this stays a plain geometric check.
    for entry in _vortex_spheres:
        if not entry.using_physics:
            continue
        if entry.pos2d.length() + VORTEX_SPHERE_RADIUS <= VORTEX_BOUNDARY_RADIUS:
            continue
        var normal: Vector2 = entry.pos2d.normalized()
        entry.vel2d = entry.vel2d - 2.0 * entry.vel2d.dot(normal) * normal
        entry.pos2d = normal * (VORTEX_BOUNDARY_RADIUS - VORTEX_SPHERE_RADIUS)

    # Re-sync every node's world position after any separation/wall
    # correction the passes above may have applied to pos2d.
    for entry in _vortex_spheres:
        var node := entry.node as Area3D
        if is_instance_valid(node):
            node.global_position = _vortex_world_pos(entry.pos2d)

# The bounce response for one sphere in a detected collision - branches
# on whether this sphere has already made the arc-to-physics switch.
#
# Already in physics mode: a plain velocity reversal (not full elastic
# normal-exchange) per direct request - correct for a head-on collision,
# an approximation for others, but keeps subsequent bounces predictable
# rather than deflecting off at odd angles.
#
# Still on the scripted arc (the FIRST collision this sphere is ever
# part of): "reverse its velocity" first requires actually HAVING a
# velocity, which the arc formula alone never tracks - so this derives
# one, on the spot, from the arc's own analytic derivative at the sphere's
# current leg_t. Differentiating _arc_point()'s formula with respect to
# t (chain-ruled through theta = t*PI, and again through leg_t's own
# real-time rate delta/VORTEX_ARC_LEG_TIME) gives the sphere's true
# instantaneous velocity along the curve at this exact instant - not a
# fresh made-up value, the actual speed and direction it already had.
# That gets reversed as the bounce, exactly like the physics-mode branch,
# and using_physics flips true: this sphere never touches the arc formula
# again after this call.
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
        # d(pos)/d(leg_t) = PI * (-axis1*radius*sin(theta) + bulge_axis*radius*cos(theta)),
        # then / VORTEX_ARC_LEG_TIME converts from "per unit of leg_t" to
        # "per second of real time" (since leg_t itself advances by
        # delta/VORTEX_ARC_LEG_TIME every second of real time).
        var d_pos_d_leg_t: Vector2 = PI * (-axis1 * radius * sin(theta) + bulge_axis * radius * cos(theta))
        current_velocity = d_pos_d_leg_t / VORTEX_ARC_LEG_TIME
    entry.vel2d = -current_velocity
    entry.using_physics = true

# Called from _grapple() when the raycast hits one of these spheres
# instead of the enemy's own weak spot - see the hookup there.
#
# A correct-color hit counts the same as a weak-spot hit (contributes to
# TARGET_COUNT) and respawns a fresh sphere to keep the ring's count
# steady; a wrong-color hit costs a point back (floored at 0) rather than
# just being a no-op - this mechanic is ABOUT discrimination, so getting
# it wrong should sting a little, not just fail to help.
# MODIFIED: a wrong-color hit used to remove the sphere, dock a point,
# and spawn a random-colored replacement - now (per direct request) it
# ONLY flashes red and leaves the sphere exactly where it was, on
# whatever arc leg it's already mid-flight through. Nothing about it
# changes except the color pulse it's already doing gets briefly
# interrupted by the flash tween. A correct-color hit is the only thing
# that ever removes a sphere now, which is also why _ensure_vortex_has_
# safe_color() (the old softlock guard) is gone entirely - launch_vortex()
# already guarantees exactly 2 safe-color spheres exist every wave, and
# since wrong hits never remove or replace anything, that guarantee can't
# be violated mid-wave the way it could when hits caused random respawns.
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
    # The wave clears the instant no safe-color spheres remain - checked
    # directly against what's actually still alive, not a counter,
    # because a correct hit is the ONLY thing that ever removes a sphere
    # now: "none of the safe color left" and "both of this wave's safe
    # spheres hit" are exactly the same condition.
    for remaining in _vortex_spheres:
        if bool(remaining.is_yellow) == _vortex_safe_is_yellow:
            return
    _advance_or_finish_vortex()

# Fires when a wave's travel tween completes on its own - i.e. the disc
# actually reached the player. If the wave is still active at that point,
# the player never cleared both safe-color spheres in time, so this
# counts as the vortex hitting them (object_hit - battle.gd already
# applies real damage through this exact signal, same path the old
# thrown-rock version used for an unshot rock landing). If the wave was
# already cleared early (_advance_or_finish_vortex() already ran from
# _resolve_vortex_hit() and set _vortex_active false), this is a no-op -
# though in practice it should never even fire for an early-cleared wave,
# since _clear_vortex() kills this exact tween.
func _on_vortex_reached_player() -> void:
    if not _vortex_active:
        return
    object_hit.emit()
    _advance_or_finish_vortex()

# Shared by both ways a wave can end - cleared early (every safe-color
# sphere shot down) or timed out (the disc reached the player first).
# Either way: tear down this wave's spheres/tween, then either start the
# next wave or, once TOTAL_VORTEX_WAVES have run, end the whole encounter.
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
    var tw := node.create_tween()
    tw.tween_property(mat, "albedo_color", color, 0.06)

func _remove_vortex_sphere(entry: Dictionary) -> void:
    _vortex_spheres.erase(entry)
    var node := entry.node as Area3D
    if is_instance_valid(node):
        node.queue_free()

func _clear_vortex() -> void:
    _vortex_active = false
    # MODIFIED (added): critical when a wave clears EARLY - without
    # killing this wave's own travel tween here, it would keep running in
    # the background and eventually fire _on_vortex_reached_player()
    # against whatever wave happens to be active by the time it finishes,
    # applying a damage hit that has nothing to do with how that later
    # wave actually went. Tween.kill() stops it outright and does not
    # itself fire `finished`, so this can't cause the exact bug it exists
    # to prevent.
    if _vortex_travel_tween != null and _vortex_travel_tween.is_valid():
        _vortex_travel_tween.kill()
    _vortex_travel_tween = null
    for entry in _vortex_spheres:
        var node := entry.node as Area3D
        if is_instance_valid(node):
            node.queue_free()
    _vortex_spheres.clear()
    _vortex_touching.clear()

# A stable, order-independent key for one pair of sphere nodes - sorted
# by instance id so (a, b) and (b, a) always produce the identical string,
# regardless of which one _update_vortex()'s loop happens to visit first.
func _vortex_pair_key(a: Area3D, b: Area3D) -> String:
    var id_a := a.get_instance_id()
    var id_b := b.get_instance_id()
    return "%d_%d" % [mini(id_a, id_b), maxi(id_a, id_b)]

# Battle-lifecycle verification uses direct resolution so its assertions
# isolate HP/camera/visibility wiring from the separate aim-selection test.
#
# MODIFIED: used to pick the geometrically closest of several live rocks
# and destroy it - there's nothing left to pick between now (the only
# target is enemy_actor himself, and he never leaves play mid-encounter),
# so this is just _hit_weak_spot() directly, skipping the raycast/aim
# _grapple() would otherwise require.
func verification_resolve_closest() -> bool:
    if _active_weak_spot != null and is_instance_valid(_active_weak_spot):
        _hit_weak_spot()
        return true
    # MODIFIED (added): same fallback as auto_intercept_closest() - the
    # enemy-body weak spot is dormant now that run() only launches the
    # vortex. Resolves the first SAFE-color sphere directly, bypassing
    # aim, same "isolate lifecycle from aim-selection" reasoning as
    # before.
    for entry in _vortex_spheres:
        if bool(entry.is_yellow) == _vortex_safe_is_yellow:
            _resolve_vortex_hit(entry)
            return true
    return false
