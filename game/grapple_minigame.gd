# Diver Boy's special-encounter minigame (see battle.gd's _do_enemy_turn()
# special_encounter branch, ability_id == "grapple") - SCAFFOLDING, not yet
# tuned/playtested the way rock_dodge_minigame.gd's numbers were.
#
# MODIFIED: was a blast_rocks_minigame.gd-style grid - WASD swam the diver
# into a telegraphed cell, matching where the rock would land. Replaced
# with aiming: the diver stays put, a mouse-driven reticle is what moves,
# and a rock's landing CELL no longer matters - only whether the reticle
# is on the rock itself when E is pressed. Closer to what grapple actually
# is everywhere else in this project (diver.gd's ability_needs_aim()/
# aim_dir - grapple is the one aimed ability) than a positioning puzzle
# was.
#
# What makes this one different from a plain dodge: a MISS still costs you
# (the rock lands on the player, same as an unbroken rock in
# rock_dodge_minigame.gd) but a HIT deals real damage to the ENEMY instead
# of just neutralizing the rock - grapple turns defense into a counter-
# attack, which is the whole identity of the ability. That's why this
# reports two separate per-event signals instead of rock_dodge_minigame.gd's
# one: counter_landed (enemy took damage) and rock_landed (player took
# damage) - exactly one of the two fires per rock, never both.
#
# Self-contained: battle.gd just instantiates one, adds it as a child,
# calls run(), and awaits `finished`. Nothing here knows about
# CombatantStats/damage - that's battle.gd's job once it has the result,
# same ability-agnostic split cracked_wall.gd/grapple_anchor.gd use
# elsewhere in this project.
class_name GrappleMinigame
extends Control

signal finished(hits: int, total: int)

# Fired the instant a successful grapple's counter-flight actually lands
# on the enemy - not the instant E is pressed (see _counter_rock()'s own
# flight). battle.gd applies that hit's damage live and shows a popup
# right as this fires, same "per-event signal, timed to the real moment it
# should count" shape every other minigame's own signals already use.
signal counter_landed

# Fired whenever a rock's window expires with nobody grappling it - it
# just lands on the player, same shape as rock_dodge_minigame.gd's own
# rock_landed.
signal rock_landed

# Set by battle.gd before run().
var stage_root: SubViewport
var diver_actor: Node3D
var enemy_actor: Node3D

const ROCK_COUNT := 8
const MIN_SPAWN_GAP := 0.6
const MAX_SPAWN_GAP := 1.4
const INCOMING_FLIGHT_TIME := 0.9   # enemy -> near the diver, doubles as the telegraph/aim window
const LIVE_WINDOW := 0.9            # how long a landed rock stays grapple-able before it counts as a miss
const COUNTER_FLIGHT_TIME := 0.7    # landing point -> enemy, once successfully grappled

var _diver_base_pos: Vector3
var _hits := 0
var _resolved := 0
var _active_rock: MeshInstance3D = null

# Screen-space, not world-space - aiming compares the reticle's position
# against each rock's CURRENT position projected through the stage
# camera (see _rock_screen_pos()), not anything in 3D. Radius is in
# pixels for the same reason.
const AIM_RADIUS_PX := 48.0
var _reticle: Control
var _reticle_pos := Vector2.ZERO

# Only a successful grapple starts this - a miss (nothing live, or the
# live rock out of aim) leaves it untouched, so whiffing never costs the
# ability to try again on the very next rock.
const GRAPPLE_COOLDOWN_MS := 350
var _grapple_ready_at := 0

var _title_label: Label
var _prompt_label: Label
var _progress_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# MODIFIED: was MOUSE_FILTER_IGNORE, matching every other minigame's
	# overlay - those never need the mouse at all (E/WASD only). This one
	# needs to see InputEventMouseMotion to move the reticle, which
	# MOUSE_FILTER_IGNORE would swallow before _unhandled_input ever sees
	# it (an ignored Control doesn't consume the event, but its presence
	# full-rect over the stage was never actually the blocker for mouse
	# motion specifically - PASS is used anyway to be explicit that this
	# Control is deliberately mouse-aware, unlike its siblings).
	mouse_filter = Control.MOUSE_FILTER_PASS

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.35)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_title_label = Label.new()
	_title_label.text = "GRAPPLE THE ROCKS"
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.offset_top = 40.0
	_title_label.offset_left = -160.0
	_title_label.offset_right = 160.0
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	add_child(_title_label)

	_prompt_label = Label.new()
	_prompt_label.text = "Aim (mouse) at the incoming rock, E to grapple it back at the enemy before it lands"
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_prompt_label.offset_top = 90.0
	_prompt_label.offset_left = -260.0
	_prompt_label.offset_right = 260.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_prompt_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_prompt_label.visible = false
	add_child(_prompt_label)

	_progress_label = Label.new()
	_progress_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progress_label.offset_top = 130.0
	_progress_label.offset_left = -80.0
	_progress_label.offset_right = 80.0
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	_progress_label.visible = false
	add_child(_progress_label)

	_reticle = _build_reticle()
	add_child(_reticle)

const TITLE_HOLD := 1.1

func run() -> void:
	if diver_actor != null:
		_diver_base_pos = diver_actor.global_position
	_reticle_pos = size * 0.5
	_reticle.position = _reticle_pos - _reticle.size * 0.5
	await get_tree().create_timer(TITLE_HOLD).timeout
	_title_label.visible = false
	_prompt_label.visible = true
	_progress_label.visible = true
	_update_progress()
	_spawn_loop()

func _update_progress() -> void:
	_progress_label.text = "%d / %d" % [_hits, ROCK_COUNT]

# A plain ring drawn with _draw() rather than a texture - nothing in this
# project ships a crosshair asset, and a drawn ring is trivial to recolor
# per-frame later (e.g. flashing when a rock's actually in range) without
# needing a second texture for that state.
func _build_reticle() -> Control:
	var r := Control.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(28, 28)
	r.size = Vector2(28, 28)
	r.draw.connect(func() -> void:
		r.draw_arc(Vector2(14, 14), 12.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, 0.9), 2.0)
		r.draw_line(Vector2(2, 14), Vector2(8, 14), Color(1.0, 0.85, 0.3, 0.9), 2.0)
		r.draw_line(Vector2(20, 14), Vector2(26, 14), Color(1.0, 0.85, 0.3, 0.9), 2.0)
		r.draw_line(Vector2(14, 2), Vector2(14, 8), Color(1.0, 0.85, 0.3, 0.9), 2.0)
		r.draw_line(Vector2(14, 20), Vector2(14, 26), Color(1.0, 0.85, 0.3, 0.9), 2.0)
	)
	return r

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_reticle_pos = (event as InputEventMouseMotion).position.clamp(Vector2.ZERO, size)
		_reticle.position = _reticle_pos - _reticle.size * 0.5
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	if (event as InputEventKey).keycode == KEY_E:
		_try_grapple()

# Projects a rock's current 3D position through the stage camera into
# THIS Control's own local coordinate space. unproject_position() returns
# coordinates sized to the CAMERA's own viewport (stage_root), which isn't
# necessarily the same pixel size as this full-rect overlay Control (the
# SubViewport can render at a different resolution than the window) - the
# size-ratio scale corrects for that mismatch rather than assuming the two
# always match.
func _rock_screen_pos(rock: Node3D) -> Vector2:
	var cam := stage_root.get_camera_3d()
	if cam == null or stage_root.size.x <= 0 or stage_root.size.y <= 0:
		return Vector2(-9999, -9999)
	var raw := cam.unproject_position(rock.global_position)
	return raw * (size / Vector2(stage_root.size))

# Needs BOTH a live rock AND the reticle actually being close enough to it
# on screen right now - same "off-target presses don't get punished" rule
# every other minigame's own trigger follows.
func _try_grapple() -> void:
	if _active_rock == null or not is_instance_valid(_active_rock):
		return
	if Time.get_ticks_msec() < _grapple_ready_at:
		return
	if _reticle_pos.distance_to(_rock_screen_pos(_active_rock)) > AIM_RADIUS_PX:
		return
	_grapple_ready_at = Time.get_ticks_msec() + GRAPPLE_COOLDOWN_MS
	_counter_rock(_active_rock)

func _spawn_loop() -> void:
	while _resolved < ROCK_COUNT:
		await get_tree().create_timer(randf_range(MIN_SPAWN_GAP, MAX_SPAWN_GAP)).timeout
		if not is_instance_valid(self):
			return
		await _run_one_rock()

func _run_one_rock() -> void:
	# Slight jitter around the diver's own spot rather than a fixed grid
	# cell - the diver never moves in this version, so an identical
	# landing point every time would make every rock trivially easy to
	# find once you know where to look, rather than something the reticle
	# actually has to track.
	var landing_pos: Vector3 = _diver_base_pos + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 1.3), randf_range(-0.2, 0.2))
	var spawn_pos: Vector3 = _diver_base_pos
	if enemy_actor != null:
		spawn_pos = enemy_actor.global_position + Vector3.UP * 1.0

	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	rock.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.22, 0.14)
	rock.material_override = mat
	stage_root.add_child(rock)
	rock.global_position = spawn_pos

	var in_tw := rock.create_tween()
	in_tw.tween_property(rock, "global_position", landing_pos, INCOMING_FLIGHT_TIME)
	await in_tw.finished
	if not is_instance_valid(self):
		return

	_active_rock = rock

	await get_tree().create_timer(LIVE_WINDOW).timeout
	if not is_instance_valid(self):
		return
	if _active_rock == rock:
		_miss_rock(rock)

# The payoff - grappled rocks fly on to the ENEMY instead of just being
# neutralized, which is what makes this a counter-attack rather than a
# plain dodge. Damage doesn't apply until this second flight actually
# arrives (counter_landed, below), not the instant E is pressed.
func _counter_rock(rock: MeshInstance3D) -> void:
	_active_rock = null
	_hits += 1
	_resolved += 1
	_update_progress()
	# rock.create_tween(), not create_tween() (bound to self) - whichever
	# rock happens to push _resolved to ROCK_COUNT calls _maybe_finish()
	# below in this same function, which emits `finished` synchronously;
	# battle.gd calls minigame.queue_free() the instant that await
	# resumes, and Godot auto-kills any tween bound to a node the moment
	# that node is freed. Bound to the rock itself so the flight always
	# finishes and actually applies its damage, even for the very last hit
	# - same fix blast_rocks_minigame.gd/rock_dodge_minigame.gd both
	# needed for their own equivalent tweens.
	var tw := rock.create_tween()
	if enemy_actor != null:
		tw.tween_property(rock, "global_position", enemy_actor.global_position, COUNTER_FLIGHT_TIME)
	tw.tween_callback(func() -> void:
		counter_landed.emit()
		rock.queue_free()
	)
	_maybe_finish()

# The window expired with nobody grappling it - unlike
# blast_rocks_minigame.gd's old _miss_rock() (which just faded the rock
# away, since a miss there only ever cost a missed OPPORTUNITY), this is a
# genuinely defensive encounter: an ungrappled rock actually lands on the
# player, same as rock_dodge_minigame.gd's own unbroken-rock case.
func _miss_rock(rock: MeshInstance3D) -> void:
	_active_rock = null
	_resolved += 1
	_update_progress()
	var mat := rock.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	var tw := rock.create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 3.0, 0.15)
	tw.tween_callback(func() -> void:
		rock_landed.emit()
		rock.queue_free()
	)
	_maybe_finish()

func _maybe_finish() -> void:
	if _resolved >= ROCK_COUNT:
		finished.emit(_hits, ROCK_COUNT)
