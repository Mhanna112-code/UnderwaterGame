# Marine Man's OFFENSIVE special-encounter minigame - the "Blast Rocks"
# move (see battle.gd's BASE_MOVES/_do_blast_rocks_attack()), as opposed to
# rock_dodge_minigame.gd's defensive one that plays on the enemy's own
# turn. Same "self-contained, doesn't know about CombatantStats" split as
# that file and cracked_wall.gd/grapple_anchor.gd - this only ever reports
# a hit/total tally, battle.gd decides what that's worth in damage.
#
# MODIFIED: was a separate floating cursor marker the player steered while
# the diver's own puppet stood still - replaced with actually moving the
# diver (_move_actor_grid_location()) into the telegraphed cell instead.
# Rocks still telegraph their landing cell with a flashing marker same as
# before; what changed is what "lining up" means - the player now swims
# their own character into position rather than aiming a separate cursor
# at arm's length. The grid itself is asymmetric on request: horizontal is
# centered on the diver's own starting spot (2 cells either side), vertical
# only goes up from the ground they're already standing on (0..5, no
# diving below their own feet).
class_name BlastRocksMinigame
extends Control

signal finished(hits: int, total: int)

# Fired once a successfully-blasted rock's SECOND flight (landing point ->
# enemy) actually arrives - not the instant E is pressed. battle.gd
# applies that rock's damage and shows a popup right as this fires, same
# "per-event signal, timed to the real moment it should count" shape
# rock_dodge_minigame.gd's rock_landed already uses.
signal rock_blasted

# Set by battle.gd before run() - where the rocks fly toward (landing
# points are relative to this) and where a blasted rock flies onward to.
var stage_root: SubViewport
var diver_actor: Node3D
var enemy_actor: Node3D

const ROCK_COUNT := 6
const MIN_SPAWN_GAP := 0.5
const MAX_SPAWN_GAP := 1.3
const INCOMING_FLIGHT_TIME := 0.9   # side -> landing point, doubles as the telegraph window
const LIVE_WINDOW := 0.9            # a touch longer than the old timing-only version - swimming into position takes a beat the old version didn't need
const BLAST_FLIGHT_TIME := 0.8      # landing point -> enemy, once successfully blasted

# Horizontal: centered on the diver's own starting spot, 2 cells either
# side (5 columns total). Vertical: 0 is the ground they're already
# standing on, up to 5 cells of rise - no going below their own feet.
const COL_MIN := -2
const COL_MAX := 2
const ROW_MIN := 0
const ROW_MAX := 5
const COL_SPACING := 0.6
const ROW_SPACING := 0.45
const MOVE_TIME := 0.18

# Both a rock's landing cell and the diver's own current cell are read off
# this same function, relative to _diver_base_pos (the diver's position
# the instant this minigame started, captured once - NOT diver_actor's own
# live position, since that now changes as the player moves through the
# grid; the grid cells themselves have to stay fixed in space for a rock's
# telegraphed landing point to mean anything).
func _grid_offset(col: int, row: int) -> Vector3:
	return Vector3(float(col) * COL_SPACING, float(row) * ROW_SPACING, 0.0)

var _diver_base_pos: Vector3
var _grid_pos := Vector2i(0, 0)   # x = col, y = row - starts centered, on the ground
var _move_tween: Tween = null

var _hits := 0
var _resolved := 0
var _active_rock: MeshInstance3D = null
var _active_rock_cell := Vector2i(-99, -99)

# Only a successful blast starts this - a miss (no rock live, or one live
# but the diver isn't standing in its cell) leaves it untouched, so
# whiffing never costs you the ability to try again on the very next rock.
# Msec-based rather than a per-frame countdown since nothing here runs
# _process().
const SHOCKWAVE_COOLDOWN_MS := 350
var _shockwave_ready_at := 0

var _title_label: Label
var _prompt_label: Label
var _progress_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.35)   # lighter than the dodge minigame's - this one shouldn't hide the stage, the rocks/enemy are the whole point
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_title_label = Label.new()
	_title_label.text = "BLAST ROCKS"
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.offset_top = 40.0
	_title_label.offset_left = -160.0
	_title_label.offset_right = 160.0
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	add_child(_title_label)

	# "Above center" - anchored to the top of the screen rather than
	# dead-center, so it doesn't sit on top of the diver/rocks/enemy the
	# 3D stage is actually showing in the middle of the screen.
	_prompt_label = Label.new()
	_prompt_label.text = "WASD to swim into a telegraphed spot, E to shockwave it toward the enemy"
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

const TITLE_HOLD := 1.1

func run() -> void:
	if diver_actor != null:
		_diver_base_pos = diver_actor.global_position
	await get_tree().create_timer(TITLE_HOLD).timeout
	_title_label.visible = false
	_prompt_label.visible = true
	_progress_label.visible = true
	_update_progress()
	_spawn_loop()

func _update_progress() -> void:
	_progress_label.text = "%d / %d" % [_hits, ROCK_COUNT]

# MODIFIED: WASD, not arrow keys - the arrow keys already turn the free-swim
# camera outside battle (see world.gd), and E is already the shared
# shockwave-trigger key with rock_dodge_minigame.gd, so WASD is the one set
# left that reads as "movement" without colliding with either. Movement
# isn't echo-filtered (holding a key should keep nudging the diver along);
# E is, same as rock_dodge_minigame.gd's own trigger, so holding it doesn't
# spam repeated blast attempts off one press.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_W:
			_move_actor_grid_location(0, 1)
		KEY_S:
			_move_actor_grid_location(0, -1)
		KEY_A:
			_move_actor_grid_location(-1, 0)
		KEY_D:
			_move_actor_grid_location(1, 0)
		KEY_E:
			if not key.echo:
				_try_blast()

# Actually swims the diver's own puppet to the new cell (a short tween, not
# an instant snap) instead of moving a separate marker - clamped per axis
# to COL_MIN/MAX and ROW_MIN/MAX, so running into an edge just stops there
# rather than wrapping or erroring. Kills any still-running move tween
# first so mashing a direction doesn't stack several tweens all fighting
# over the same global_position at once.
func _move_actor_grid_location(d_col: int, d_row: int) -> void:
	_grid_pos.x = clampi(_grid_pos.x + d_col, COL_MIN, COL_MAX)
	_grid_pos.y = clampi(_grid_pos.y + d_row, ROW_MIN, ROW_MAX)
	if diver_actor == null:
		return
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	var target: Vector3 = _diver_base_pos + _grid_offset(_grid_pos.x, _grid_pos.y)
	_move_tween = diver_actor.create_tween()
	_move_tween.tween_property(diver_actor, "global_position", target, MOVE_TIME)

# Needs BOTH a live rock AND the diver actually standing in that rock's own
# cell right now - a press with no rock live, or one that's live but the
# diver isn't lined up with, does nothing at all (not counted as a miss,
# same "free/off-target presses don't get punished" rule
# rock_dodge_minigame.gd's own trigger already follows - only a live rock's
# window actually expiring unlanded, see _run_one_rock(), counts as a
# miss). Same rule extends to the cooldown below: it only ever starts on
# an actual hit, never on a whiff, so missing never locks you out of the
# very next attempt.
func _try_blast() -> void:
	if _active_rock == null or _grid_pos != _active_rock_cell:
		return
	if Time.get_ticks_msec() < _shockwave_ready_at:
		return
	if diver_actor is Diver:
		(diver_actor as Diver)._shockwave_vfx()
	_shockwave_ready_at = Time.get_ticks_msec() + SHOCKWAVE_COOLDOWN_MS
	_blast_rock_forward(_active_rock)

func _spawn_loop() -> void:
	while _resolved < ROCK_COUNT:
		await get_tree().create_timer(randf_range(MIN_SPAWN_GAP, MAX_SPAWN_GAP)).timeout
		if not is_instance_valid(self):
			return
		await _run_one_rock()

func _run_one_rock() -> void:
	var col := randi_range(COL_MIN, COL_MAX)
	var row := randi_range(ROW_MIN, ROW_MAX)
	var landing_pos: Vector3 = _diver_base_pos + _grid_offset(col, row)
	# Alternates which side rocks fly in from, purely for visual variety -
	# same brown rock look as rock_dodge_minigame.gd's, for a consistent
	# visual language between the two minigames.
	var side: float = -6.0 if randf() < 0.5 else 6.0
	var spawn_pos: Vector3 = _diver_base_pos + Vector3(side, 1.0, 0.0)

	# Telegraph: a flat, pulsing amber marker at the landing point - shown
	# for the whole incoming flight, so there's real time to notice where
	# this one's headed (and swim over there) before it actually arrives
	# and becomes live.
	var marker := _build_telegraph_marker(landing_pos)
	stage_root.add_child(marker)
	var pulse := marker.create_tween()
	pulse.set_loops()
	pulse.tween_property(marker, "scale", Vector3.ONE * 1.3, 0.35)
	pulse.tween_property(marker, "scale", Vector3.ONE, 0.35)

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
	pulse.kill()
	marker.queue_free()
	if not is_instance_valid(self):
		return

	# Live - landed, sitting still at landing_pos, waiting on the diver to
	# swim into its cell and E to be pressed.
	_active_rock = rock
	_active_rock_cell = Vector2i(col, row)

	await get_tree().create_timer(LIVE_WINDOW).timeout
	if not is_instance_valid(self):
		return
	# Still the SAME rock and still active means nothing blasted it during
	# the wait - a miss. If _try_blast() already fired, _active_rock was
	# already nulled out (and possibly reassigned to a later rock by now),
	# so this check is what keeps a resolved rock from being resolved
	# twice.
	if _active_rock == rock:
		_miss_rock(rock)

func _build_telegraph_marker(at: Vector3) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.35
	disc.bottom_radius = 0.35
	disc.height = 0.03
	marker.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.7, 0.2, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.7, 0.2)
	marker.material_override = mat
	marker.global_position = at
	return marker

# The actual "blasts them forward towards the enemy" step - a second
# flight, landing point -> enemy_actor, only reachable via a successful
# E press while the diver is standing in the cell (see _try_blast()).
# Damage doesn't apply until this flight actually arrives (rock_blasted,
# below) - not the instant E is pressed.
func _blast_rock_forward(rock: MeshInstance3D) -> void:
	_active_rock = null
	_active_rock_cell = Vector2i(-99, -99)
	_hits += 1
	_resolved += 1
	_update_progress()
	# rock.create_tween(), not create_tween() (which would bind to self,
	# this minigame's own Control) - whichever rock happens to push
	# _resolved to ROCK_COUNT calls _maybe_finish() below in this same
	# function, which emits `finished` synchronously; battle.gd calls
	# minigame.queue_free() the instant that await resumes, and Godot
	# auto-kills any tween bound to a node the moment that node is freed.
	# Bound to the rock itself instead so the flight always finishes and
	# actually applies its damage, even for the very last hit.
	var tw := rock.create_tween()
	tw.tween_property(rock, "global_position", enemy_actor.global_position, BLAST_FLIGHT_TIME)
	tw.tween_callback(func() -> void:
		rock_blasted.emit()
		rock.queue_free()
	)
	_maybe_finish()

# The window expired with nobody blasting it - just fades out in place,
# no forward flight, no damage to anyone. A wasted attempt, not a
# penalty.
func _miss_rock(rock: MeshInstance3D) -> void:
	_active_rock = null
	_active_rock_cell = Vector2i(-99, -99)
	_resolved += 1
	_update_progress()
	# transparency has to be turned on before tweening albedo_color's
	# alpha, or the fade is invisible - same gotcha flagged a few
	# messages back for rock_dodge_minigame.gd's own material fades.
	var mat := rock.material_override as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tw := rock.create_tween()   # bound to the rock, not self - same reason as _blast_rock_forward()'s own tween
	tw.tween_property(rock, "scale", Vector3.ONE * 0.3, 0.3)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(rock.queue_free)
	_maybe_finish()

func _maybe_finish() -> void:
	if _resolved >= ROCK_COUNT:
		# Swim back to exactly where this started - the diver shouldn't be
		# left stranded off to one side (or up in the water column) for the
		# rest of the battle just because that's where the last rock happened
		# to be.
		if diver_actor != null:
			if _move_tween != null and _move_tween.is_valid():
				_move_tween.kill()
			var back := diver_actor.create_tween()
			back.tween_property(diver_actor, "global_position", _diver_base_pos, MOVE_TIME)
		finished.emit(_hits, ROCK_COUNT)
