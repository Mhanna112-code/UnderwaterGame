# Marine Man's special-encounter minigame (see battle.gd's _do_enemy_turn()
# special_encounter branch) - a burst of rocks fly in at irregular
# intervals (not a fixed beat - real rhythm-game feel means the player is
# reacting, not just memorizing a metronome) and get left-clicked out of
# the air before they land. Performance (hits out of ROCK_COUNT) scales
# how much damage the "attack" actually deals - see finished signal.
#
# Self-contained: battle.gd just instantiates one, adds it as a child,
# calls run(), and awaits `finished`. Nothing here knows about
# CombatantStats/damage - that's battle.gd's job once it has the result,
# same ability-agnostic split cracked_wall.gd/grapple_anchor.gd use
# elsewhere in this project.
class_name RockDodgeMinigame
extends Control

signal finished(hits: int, total: int)

# Fired the instant one rock lands unbroken - battle.gd listens for this
# to apply that rock's own damage live, in real time as the barrage
# plays out, rather than one lump sum computed after the fact (see
# battle.gd's _do_rock_dodge_encounter()). Kept separate from `finished`
# (which only ever carries the tally, for the closing log line) - this
# script still doesn't know what a CombatantStats even is, only "a rock
# got past you," same ability-agnostic split as everywhere else.
signal rock_landed

const ROCK_COUNT := 8
const MIN_SPAWN_GAP := 0.35
const MAX_SPAWN_GAP := 1.1
# MODIFIED: was 1.15 - battle.gd widened the gap between the diver and the
# enemy for special encounters (more room for both rock minigames to read
# clearly), which roughly doubled the distance a thrown rock actually
# covers. Bumped up to keep rocks arriving at about the same speed instead
# of suddenly crossing twice the distance in the same time.
const ROCK_TRAVEL_TIME := 0.7

var thrower_position: Vector3
var stage_root: SubViewport
var target_actor: Node3D

var _hits := 0
var _resolved := 0
var _spawned := 0
var _title_label: Label
var _progress_label: Label

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

	# MODIFIED: was left-click, wording updated to match - "above center"
	# (anchored to the top of the screen, not dead-center) so it doesn't
	# sit on top of the diver/rocks the 3D stage is showing in the middle
	# of the screen. Same repositioning applied to blast_rocks_minigame.gd
	# for a consistent prompt placement between both minigames.
	var hint := Label.new()
	hint.text = "Press E to shockwave each rock before it lands"
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.offset_top = 90.0
	hint.offset_left = -220.0
	hint.offset_right = 220.0
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
# this is the visual one) before rocks start - a burst that begins the
# instant the screen appears would read as starting mid-warning.
const TITLE_HOLD := 1.1

func run() -> void:
	await get_tree().create_timer(TITLE_HOLD).timeout
	_title_label.visible = false
	_progress_label.visible = true
	_update_progress()
	_spawn_loop()

func _update_progress() -> void:
	_progress_label.text = "%d / %d" % [_hits, ROCK_COUNT]

# Irregular, not metronomic - each gap is its own random roll rather than
# a fixed beat, so the player's reacting to each rock arriving, not
# counting a rhythm out in advance. Stops issuing new rocks once
# ROCK_COUNT have spawned; _maybe_finish() (called from each rock's own
# resolution) is what actually ends the minigame once the LAST one
# resolves, which can be after this loop itself has already returned.
func _spawn_loop() -> void:
	while _spawned < ROCK_COUNT:
		await get_tree().create_timer(randf_range(MIN_SPAWN_GAP, MAX_SPAWN_GAP)).timeout
		if not is_instance_valid(self):
			return
		_spawn_rock()
		_spawned += 1

# MODIFIED: removed the old 2D Panel-based _spawn_rock() that used to sit
# here commented out in a """...""" string - fully superseded by the 3D
# MeshInstance3D version below, keeping it around was just dead-code
# clutter at this point (nothing referenced it anymore).

# MODIFIED: was a single _active_rock/_active_tween pair - that only ever
# tracked the MOST RECENTLY spawned rock. _spawn_loop() fires rocks without
# waiting for the previous one to land (that's the whole point - "many
# rocks flying at irregular rhythm"), so multiple rocks are routinely in
# flight at once. A second rock spawning silently overwrote the first
# one's reference here; when the first rock's own tween later finished,
# _on_rock_landed() checked "is _active_rock null" (a leftover guard meant
# to catch an ALREADY-BROKEN rock) and found it pointing at the SECOND
# rock instead - not null - so it wrongly treated the first rock as still
# trackable, nulled out the second rock's own live reference out from under
# it, and never counted the first rock as resolved at all. That undercount
# meant _resolved could never reach ROCK_COUNT, finished never emitted, and
# the whole battle hung forever right after the last rock's flight ended.
# Array + Dictionary instead - every rock still in flight (or just landed,
# right up until it's actually resolved) stays in _live_rocks, so an E
# press can find any of them, and each rock's own landing only resolves
# itself, not whichever rock happens to be "the" active one.
var _live_rocks: Array[MeshInstance3D] = []
var _rock_tweens: Dictionary = {}   # MeshInstance3D -> Tween, only while that rock is still in flight

func _spawn_rock() -> void:
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	rock.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.22, 0.14)   # same brown as cracked_wall.gd's disguised rocks
	rock.material_override = mat
	stage_root.add_child(rock)
	rock.global_position = thrower_position + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.3, 0.3))
	_live_rocks.append(rock)

	var tw := create_tween()
	tw.tween_property(rock, "global_position", target_actor.global_position, ROCK_TRAVEL_TIME)
	_rock_tweens[rock] = tw
	tw.finished.connect(func() -> void: _on_rock_landed(rock))

# MODIFIED: was 1.5 - battle.gd widened the diver/enemy gap for special
# encounters (roughly doubled), but this radius stayed the same, so a rock
# only spent a small fraction of its now-longer flight actually within
# range - pressing E as soon as a rock appeared (the natural instinct)
# almost always landed outside this radius and did nothing, which read as
# "shockwave doesn't affect the rocks at all." Scaled up to keep roughly
# the same fraction of the flight breakable as before the gap widened.
const SHOCKWAVE_RADIUS := 3.0

# MODIFIED: was left-click (InputEventMouseButton) - switched to E, same
# trigger key blast_rocks_minigame.gd now uses too, so both minigames
# share one consistent input instead of one being mouse-driven and the
# other keyboard-driven.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	if (event as InputEventKey).keycode == KEY_E:
		_try_shockwave()

# MODIFIED: picks whichever live rock is actually closest and within
# range, not just "the" active one - with several rocks in flight at once
# there's no single rock to check against anymore, so this scans all of
# them. Still a no-op (not a miss) if nothing's in range, same "free
# presses don't get punished" rule as before.
func _try_shockwave() -> void:
	if _live_rocks.is_empty():
		return
	(target_actor as Diver)._shockwave_vfx()
	var best: MeshInstance3D = null
	var best_dist := SHOCKWAVE_RADIUS
	for r in _live_rocks:
		var d := target_actor.global_position.distance_to(r.global_position)
		if d <= best_dist:
			best = r
			best_dist = d
	if best != null:
		_break_rock(best)

# A quick scale-up-and-free "shattered" flash rather than an instant
# queue_free() - a hit needs to visibly register as a hit, same reason
# cracked_wall.gd's break isn't silent either.
func _break_rock(rock: MeshInstance3D) -> void:
	_live_rocks.erase(rock)
	var tw: Tween = _rock_tweens.get(rock, null)
	if tw != null and tw.is_valid():
		tw.kill()
	_rock_tweens.erase(rock)
	_hits += 1
	_resolved += 1
	_update_progress()
	# MODIFIED: was create_tween() (bound to self, this minigame's own
	# Control) - the exact rock that pushes _resolved to ROCK_COUNT fires
	# `finished` synchronously right here in this same call, and battle.gd
	# calls minigame.queue_free() the instant that await resumes. A tween
	# bound to self gets auto-killed the moment self is freed, so this
	# flash's own tween_callback (the rock's actual queue_free()) never got
	# to run for whichever rock happened to be last - it just sat there,
	# scaled up, forever. rock.create_tween() binds the tween to the ROCK
	# instead, so it survives the minigame's own teardown and still frees
	# the rock a beat later regardless.
	var flash := rock.create_tween()
	flash.tween_property(rock, "scale", Vector3.ONE * 1.8, 0.12)
	flash.tween_callback(rock.queue_free)
	_maybe_finish()

# MODIFIED: rock is a MeshInstance3D now, not the old 2D Panel this was
# originally written for - MeshInstance3D has no `modulate` property
# (that's a CanvasItem/2D thing), so tweening "modulate" here would have
# errored the first time a rock actually reached the player. Flashes red
# via the material's emission instead, same mechanism _shockwave_vfx()
# already uses for its own effect. Guards on _live_rocks still containing
# THIS rock (not just "is something null") - this rock's own flight
# finished, but _break_rock() may have already pulled it out if it got
# shockwaved in the meantime, which now correctly only affects this one
# rock instead of whichever rock happened to be "the" active one.
func _on_rock_landed(rock: MeshInstance3D) -> void:
	if not _live_rocks.has(rock):
		return
	_live_rocks.erase(rock)
	_rock_tweens.erase(rock)
	_resolved += 1
	_update_progress()
	rock_landed.emit()
	var mat := rock.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	# MODIFIED: was create_tween() (bound to self) - same issue as
	# _break_rock()'s own flash tween above (see its comment): whichever
	# rock happens to be the LAST one resolved triggers `finished` and an
	# immediate minigame.queue_free() from battle.gd before this tween's
	# 0.15s had a chance to finish, killing it mid-flash and leaving that
	# rock stuck on screen, still looking "unbroken," forever. Bound to the
	# rock itself instead so it survives the minigame's own teardown.
	var tw := rock.create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 3.0, 0.15)
	tw.tween_callback(rock.queue_free)
	_maybe_finish()

func _maybe_finish() -> void:
	if _spawned >= ROCK_COUNT and _resolved >= ROCK_COUNT:
		finished.emit(_hits, ROCK_COUNT)
