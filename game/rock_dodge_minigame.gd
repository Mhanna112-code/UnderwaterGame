# Marine Man's special-encounter minigame (see battle.gd's _do_enemy_turn()
# special_encounter branch) - now the ONLY special-encounter minigame tied
# to the shockwave ability (blast_rocks_minigame.gd, the offensive
# counterpart played on Marine Man's own turn, was retired - this is the
# sole minigame shockwave plays now, always on the enemy's turn).
#
# Three lanes - left/middle/right - run in a straight line from the enemy
# to the player. Each wave sends one object down every lane at once: one
# breakable rock (a random lane each wave) and two solid walls in the
# other two. Hold Left/Right to strafe along that same line and line
# yourself up with the rock's lane, then press E to shockwave it before it
# lands - standing in a wall's lane when it arrives gets you hit exactly
# like an unbroken rock would.
#
# Self-contained: battle.gd just instantiates one, adds it as a child,
# calls run(), and awaits `finished`. Nothing here knows about
# CombatantStats/damage - that's battle.gd's job once it has the result,
# same ability-agnostic split cracked_wall.gd/grapple_anchor.gd use
# elsewhere in this project.
class_name RockDodgeMinigame
extends Control

signal finished(hits: int, total: int)

# Fired whenever anything reaches the player unbroken - an unbroken rock
# in the lane they're standing in, or a wall in that lane - so battle.gd
# can apply that hit's own damage live, the instant it happens, rather
# than a lump sum computed after the whole encounter ends. Kept separate
# from `finished` (which only ever carries the hits/waves tally, for the
# closing log line) - this script still doesn't know what a CombatantStats
# even is, only "something got past you," same ability-agnostic split as
# everywhere else.
signal rock_landed

const WAVE_COUNT := 10
const MIN_WAVE_GAP := 1
const MAX_WAVE_GAP := 2.5
const TRAVEL_TIME := 0.67

# Waves fire in randomly-sized clusters rather than always one at a time -
# MIN_WAVE_GAP/MAX_WAVE_GAP above is the breather BETWEEN clusters; waves
# inside one cluster fire back-to-back with no extra pause of their own
# (each wave's own TRAVEL_TIME already paces it, see _run_one_wave()),
# which is what makes a bigger batch read as a flurry instead of just a
# faster metronome. Batch size is capped to however many waves are left in
# WAVE_COUNT's pool, so the very last batch can't overshoot the total.
const MIN_WAVE_BATCH := 2
const MAX_WAVE_BATCH := 8

const LANES: Array[String] = ["left", "middle", "right"]
const LANE_SIGN := {"left": -1.0, "middle": 0.0, "right": 1.0}

# How far apart the three lanes sit, in world units, along the shared
# `_right` axis below. Needs to be comfortably wider than
# SHOCKWAVE_RADIUS/LANDING_HIT_RADIUS - otherwise a player standing in one
# lane could reach into a neighboring lane's object too, which would let a
# single shockwave break a rock from the wrong lane, or let a wall in an
# adjacent lane catch someone who correctly moved out of its way.
const LANE_SPACING := 2.4

# Same radius both for "close enough to shockwave the rock" and "close
# enough for a wall/unbroken rock to actually hit you" - one number for
# both keeps the rule simple to read off the screen: if you're close
# enough to break it, you're also close enough to be hit by it.
const HIT_RADIUS := 1.8

var thrower_position: Vector3
var stage_root: SubViewport
var target_actor: Node3D

var _hits := 0
var _resolved := 0
var _title_label: Label
var _progress_label: Label

# Computed once in run() - the shared world-space "sideways" axis both
# enemy_positions and player_positions below are built from. MUST be the
# same vector for both sides (not each actor's own local right, which
# would point opposite ways with the two actors facing each other) or the
# three lanes wouldn't actually run in a straight line from thrower to
# player - see thread with the user working through this exact bug before
# any code was written.
var _right := Vector3.RIGHT
var _player_base_pos: Vector3

# Index into LANES - which of the three the player is currently standing
# in. Re-derived from CURRENTLY HELD input every frame (see _process()
# below), not an accumulated value a press increments/decrements - that's
# what gives this the Chansey/egg-minigame feel: holding Left/Right leans
# into that lane and letting go snaps straight back to middle, rather than
# a press-to-hop-and-stay control. Whenever the derived lane differs from
# where the player's already tweening to, _snap_to_lane() kicks off a new
# move.
var _player_lane := 1   # 0=left, 1=middle, 2=right - see LANES
const MOVE_TIME := 0.18
var _move_tween: Tween

# Only a successful break starts this - a miss (nothing live, or the live
# rock out of range) leaves it untouched, so whiffing never costs the
# player the ability to try again on the very next wave.
const SHOCKWAVE_COOLDOWN_MS := 350
var _shockwave_ready_at := 0

# The wave currently in flight, lane -> {node, kind, landing_pos, broken}.
# kind is "rock" or "wall". Empty between waves.
var _current_wave: Dictionary = {}

# Guards _finish() against emitting `finished` twice - it's now reachable
# from two places (WAVE_COUNT actually being reached, and battle.gd's
# request_abort() below when the player's HP hits 0 mid-encounter), and a
# second emission would resume battle.gd's already-resumed `await
# minigame.finished` a second time.
var _did_finish := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # only individual rocks/labels catch clicks, not the whole overlay

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.35)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_title_label = Label.new()
	_title_label.text = "DODGE THE ROCKS"
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.offset_top = 40.0
	_title_label.offset_left = -160.0
	_title_label.offset_right = 160.0
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	add_child(_title_label)

	var hint := Label.new()
	hint.text = "Hold Left/Right to line up with the rock, E to shockwave it - the other two lanes are solid walls"
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.offset_top = 90.0
	hint.offset_left = -260.0
	hint.offset_right = 260.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	add_child(hint)

	_progress_label = Label.new()
	_progress_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progress_label.offset_top = 130.0
	_progress_label.offset_left = -80.0
	_progress_label.offset_right = 80.0
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	_progress_label.visible = false
	add_child(_progress_label)

# Held on screen alone for a beat (the "popup" - see battle.gd's own
# _log() call right before this runs, which is the in-fiction lead-in;
# this is the visual one) before waves start - a barrage that begins the
# instant the screen appears would read as starting mid-warning.
const TITLE_HOLD := 1.1

#DAMAGE FLASH
func flash_damage():
	$Sprite3D.modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	$Sprite3D.modulate = Color.WHITE
	
func run() -> void:
	if target_actor != null:
		_player_base_pos = target_actor.global_position
	# Horizontal-only, so a raised thrower_position (battle.gd offsets it
	# by the enemy's own height) doesn't tilt the lane axis - forward is
	# purely "which way the player is from the enemy" in the XZ plane.
	var forward := _player_base_pos - thrower_position
	forward.y = 0.0
	if forward.length() > 0.001:
		forward = forward.normalized()
		# MODIFIED: was forward.cross(Vector3.UP) - pointed the opposite way
		# from the dodge camera's own actual screen-right (see battle.gd's
		# _look_at_dodge_angle(), which offsets/looks at the stage from a
		# specific angle rather than a plain forward view), so Left/Right
		# were swapped: pressing Left visibly moved the player toward the
		# lane spawned on their right. Cross product is anti-commutative,
		# so swapping the operand order is exactly a sign flip and nothing
		# else - every lane offset built from _right (both here and
		# thrower-side in _run_one_wave()) mirrors together, which is what
		# keeps the lanes still running in a straight line, just now
		# correctly matching what's on screen.
		_right = Vector3.UP.cross(forward).normalized()

	await get_tree().create_timer(TITLE_HOLD).timeout
	_title_label.visible = false
	_progress_label.visible = true
	_update_progress()
	_wave_loop()

func _update_progress() -> void:
	_progress_label.text = "%d / %d" % [_hits, WAVE_COUNT]

# Polls held-key state every frame rather than reacting to individual
# press/release events - "what's held right now" is exactly the rule that
# gives letting go its automatic snap-back, with no separate "on release"
# case to write: nothing held (or both, which cancels out) always resolves
# to middle. Only actually moves anything when the derived lane changes,
# so this is a no-op most frames.
func _process(_delta: float) -> void:
	var desired := 1   # middle by default - also what holding both keys or neither resolves to
	if Input.is_key_pressed(KEY_LEFT) and not Input.is_key_pressed(KEY_RIGHT):
		desired = 0
	elif Input.is_key_pressed(KEY_RIGHT) and not Input.is_key_pressed(KEY_LEFT):
		desired = 2
	if desired != _player_lane:
		_snap_to_lane(desired)

# Tweened rather than an instant snap - same "swim the puppet into
# position" feel blast_rocks_minigame.gd's grid movement used. Kills any
# still-running move tween first so a quick Left-then-Right doesn't stack
# two tweens fighting over the same global_position at once.
func _snap_to_lane(index: int) -> void:
	if target_actor == null:
		return
	_player_lane = index
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	var target: Vector3 = _player_base_pos + _right * LANE_SIGN[LANES[_player_lane]] * LANE_SPACING
	_move_tween = target_actor.create_tween()
	_move_tween.tween_property(target_actor, "global_position", target, MOVE_TIME)

# Irregular, not metronomic - each gap is its own random roll rather than
# a fixed beat, same reasoning as the old per-rock stream this replaced:
# the player should be reacting to each wave, not counting a rhythm out in
# advance.
func _wave_loop() -> void:
	while _resolved < WAVE_COUNT:
		await get_tree().create_timer(randf_range(MIN_WAVE_GAP, MAX_WAVE_GAP)).timeout
		if not is_instance_valid(self):
			return
		var remaining := WAVE_COUNT - _resolved
		var batch_size: int = mini(randi_range(MIN_WAVE_BATCH, MAX_WAVE_BATCH), remaining)
		for i in range(batch_size):
			await _run_one_wave()
			if not is_instance_valid(self) or _resolved >= WAVE_COUNT:
				return

func _run_one_wave() -> void:
	var rock_lane: String = LANES.pick_random()
	var wave := {}
	for lane in LANES:
		var kind := "rock" if lane == rock_lane else "wall"
		var sideways: Vector3 = _right * LANE_SIGN[lane] * LANE_SPACING
		var spawn_pos: Vector3 = thrower_position + sideways
		var landing_pos: Vector3 = _player_base_pos + sideways
		var node: MeshInstance3D = _spawn_rock(spawn_pos) if kind == "rock" else _spawn_wall(spawn_pos)
		var tw := node.create_tween()
		tw.tween_property(node, "global_position", landing_pos, TRAVEL_TIME)
		wave[lane] = {"node": node, "kind": kind, "landing_pos": landing_pos, "broken": false, "tween": tw}

	_current_wave = wave
	# All three lanes travel for the same TRAVEL_TIME, so one shared timer
	# stands in for "wait until this wave's tweens are done" instead of
	# juggling three separate tween.finished signals - a broken rock kills
	# its own tween early (see _try_shockwave()) and is already gone by the
	# time this fires, so it's simply skipped below.
	await get_tree().create_timer(TRAVEL_TIME).timeout
	if not is_instance_valid(self):
		return
	_resolve_wave_arrival(wave)
	_current_wave = {}

func _resolve_wave_arrival(wave: Dictionary) -> void:
	for lane in LANES:
		var entry: Dictionary = wave[lane]
		if bool(entry.broken):
			continue
		var node: MeshInstance3D = entry.node
		if not is_instance_valid(node):
			continue
		var caught: bool = target_actor != null and target_actor.global_position.distance_to(entry.landing_pos) <= HIT_RADIUS
		if caught:
			_flash_hit_and_free(node)
			rock_landed.emit()
		else:
			node.queue_free()
	_resolved += 1
	_update_progress()
	if _resolved >= WAVE_COUNT:
		_finish()

func _finish() -> void:
	if _did_finish:
		return
	_did_finish = true
	if target_actor != null:
		# Swim back to exactly where this started - same reasoning as
		# blast_rocks_minigame.gd's own _maybe_finish() cleanup: the player
		# shouldn't be left standing in whichever lane the last wave happened
		# to end on for the rest of the battle. Kills any still-running
		# _move_tween first, same "don't fight the in-flight move" rule
		# _snap_to_lane() already follows.
		if _move_tween != null and _move_tween.is_valid():
			_move_tween.kill()
		var back := target_actor.create_tween()
		back.tween_property(target_actor, "global_position", _player_base_pos, MOVE_TIME)
	finished.emit(_hits, WAVE_COUNT)

# Called by battle.gd the instant the player's HP hits 0 mid-encounter -
# ends the barrage right away with whatever tally it has so far, instead
# of continuing to throw more waves at a diver who's already down. Just
# calls _finish() - _did_finish above is what makes that safe even if
# WAVE_COUNT was also about to be reached on its own.
func request_abort() -> void:
	_finish()

func _spawn_rock(at: Vector3) -> MeshInstance3D:
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	rock.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.22, 0.14)   # same brown as cracked_wall.gd's disguised rocks
	rock.material_override = mat
	stage_root.add_child(rock)
	rock.global_position = at
	return rock

# Visually distinct from the rock on purpose - the player has to be able
# to tell which of the three incoming lanes is safe to stand in from
# across the whole flight, not just at the last second.
func _spawn_wall(at: Vector3) -> MeshInstance3D:
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 1.8, 0.4)
	wall.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.42, 0.46)
	wall.material_override = mat
	stage_root.add_child(wall)
	wall.global_position = at
	return wall

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	if (event as InputEventKey).keycode == KEY_E:
		_try_shockwave()

# Only the rock can be broken - shockwaving a wall does nothing (walls
# aren't a hazard you fight, only one you avoid by not being there), so
# this only ever looks for "rock" entries in the current wave. Distance
# is checked against the rock's LIVE in-flight position, not its landing
# point, so timing still matters - pressing E while it's still far up the
# lane does nothing, same "free presses don't get punished" rule as
# before.
func _try_shockwave() -> void:
	if target_actor is Diver:
		(target_actor as Diver)._shockwave_vfx()
	if _current_wave.is_empty():
		return
	if Time.get_ticks_msec() < _shockwave_ready_at:
		return
	for lane in LANES:
		var entry: Dictionary = _current_wave[lane]
		if String(entry.kind) != "rock" or bool(entry.broken):
			continue
		var node: MeshInstance3D = entry.node
		if not is_instance_valid(node):
			continue
		if target_actor.global_position.distance_to(node.global_position) <= HIT_RADIUS:
			_break_rock(lane, entry)
			_shockwave_ready_at = Time.get_ticks_msec() + SHOCKWAVE_COOLDOWN_MS
		return   # at most one rock live per wave - found it or it's out of range either way

func _break_rock(lane: String, entry: Dictionary) -> void:
	entry.broken = true
	_current_wave[lane] = entry
	var travel_tw: Tween = entry.tween
	if travel_tw != null and travel_tw.is_valid():
		travel_tw.kill()
	_hits += 1
	_flash_and_free(entry.node)

# A quick scale-up-and-free "shattered" flash rather than an instant
# queue_free() - a hit needs to visibly register as a hit, same reason
# cracked_wall.gd's break isn't silent either. Bound to the node itself
# (node.create_tween()), not this minigame's own Control - the wave that
# pushes _resolved to WAVE_COUNT can fire `finished` and get queue_free()'d
# by battle.gd before a self-bound tween would have finished, which would
# leave that last hit's flash stuck mid-animation forever.
func _flash_and_free(node: MeshInstance3D) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 1.6, 0.12)
	tw.tween_callback(node.queue_free)

# A red emission flash rather than the shatter scale above - this is the
# "it hit you" case (an unbroken rock or a wall caught the player standing
# in its lane), which needs to read as bad, not as a successful break.
# Flashes via material emission the same mechanism _shockwave_vfx()
# already uses, same as the old per-rock miss flash this replaces. Bound
# to the node itself, not this Control, for the same queue_free-survival
# reason as _flash_and_free() above.
func _flash_hit_and_free(node: MeshInstance3D) -> void:
	var mat := node.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	var tw := node.create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 3.0, 0.15)
	tw.tween_callback(node.queue_free)
