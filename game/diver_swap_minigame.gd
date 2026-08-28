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
class_name DiverSwapMinigame
extends Control

signal finished(hits: int, total: int)

# MODIFIED: was 1.15 - battle.gd widened the gap between the diver and the
# enemy for special encounters (more room for both rock minigames to read
# clearly), which roughly doubled the distance a thrown rock actually
# covers. Bumped up to keep rocks arriving at about the same speed instead
# of suddenly crossing twice the distance in the same time.
var stage_root: SubViewport

var target_actor: Node3D
var enemy_actor: Node3D

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
	#_progress_label.text = "%d / %d" % [_hits, ROCK_COUNT]
	pass

var PORTRAIT_COUNT = 4
func _spawn_loop() -> void:
	while _spawned < PORTRAIT_COUNT:
		_select_correct_portraits()
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
const PORTRAIT_PATHS := [
	"res://portraits/portrait_01_normal.png",
	"res://portraits/portrait_02_smile.png",
	"res://portraits/portrait_03_eyes_closed.png",
	"res://portraits/portrait_04_angry.png",
	"res://portraits/portrait_05_grimace.png",
	"res://portraits/portrait_06_surprised.png",
	"res://portraits/portrait_07_sad.png",
	"res://portraits/portrait_08_wink.png",
]

func select_random_portraits() -> Array:
	PORTRAIT_PATHS.shuffle()
	var portraits: Array = [PORTRAIT_PATHS[0], PORTRAIT_PATHS[1]]
	return portraits
	
var _active_cursor: MeshInstance3D
func _build_active_cursor() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.4
	_active_cursor = MeshInstance3D.new()
	_active_cursor.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.albedo_color = Color(0.35, 0.95, 0.4)
	mat.emission = Color(0.35, 0.95, 0.4)
	_active_cursor.material_override = mat
	_active_cursor.rotation_degrees.x = 180.0   # cone points down at the diver's head
	# MODIFIED: was add_child(_active_cursor) - parented it to this Control,
	# but every other 3D thing in this minigame (target_actor, enemy_actor,
	# the portrait sprites) lives under stage_root's SubViewport. A
	# MeshInstance3D parented to a Control instead of that viewport's own
	# 3D tree never renders anywhere.
	stage_root.add_child(_active_cursor)

# Repositions the cursor to hover over whichever of the three player slots
# (_slot_positions[_selected_slot_index]) is currently selected. Lift only
# uses the Diver height+0.6 rule (target_selector.gd's own convention) when
# the selection is the slot the diver herself is standing in
# (_diver_slot_index) - the other two slots just hold a portrait sprite,
# not a Diver, so they fall back to the same flat 2.5 target_selector.gd
# uses for a non-Diver target.
func _update_active_cursor() -> void:
	if _active_cursor == null or _slot_positions.is_empty():
		return
	var lift := 2.5
	if _selected_slot_index == _diver_slot_index:
		lift = (target_actor as Diver).height + 0.6
	_active_cursor.visible = true
	_active_cursor.global_position = _slot_positions[_selected_slot_index] + Vector3.UP * lift

# Left/Right move the cursor one slot over, wrapping past either end
# (pressing left at slot 0 lands on slot 2, and vice versa) rather than
# clamping - three slots in a row reads more like a carousel than a line
# with hard stops.
func _select_slot(delta: int) -> void:
	_selected_slot_index = (_selected_slot_index + delta + 3) % 3
	_update_active_cursor()

# Kicks off a round: builds this round's layouts/flights (_select_correct_
# portraits()), then plants the diver at the one player-side slot that's
# staying blank (_blank_slot_position/_diver_slot_index, set there once
# player_layout is known) and starts the cursor selection there too, so
# Left/Right from the very start of the round moves relative to wherever
# she actually is.
func _start_spawn_minigame() -> void:
	_select_correct_portraits()
	target_actor.global_position = _blank_slot_position
	if _active_cursor == null:
		_build_active_cursor()
	_selected_slot_index = _diver_slot_index
	_update_active_cursor()
	
func _swap(target: Texture2D) -> void:
	if target == null or not is_instance_valid(target) or not target.can_be_selected:
		return
		
	var my_pos: Vector3 = target_actor.lobal_position
	var their_pos: Vector3 = target.global_position
	
	target_actor.velocity = Vector3.ZERO
	target.velocity = Vector3.ZERO
	target_actor.global_position = their_pos
	target.global_position = my_pos

var portraitSpeed = 10.0

const SLOT_NAMES := ["left", "middle", "right"]
# Sprite3D's own default - kept as an explicit const so the half-width
# math below uses the exact same number the sprite is actually built with,
# instead of relying on the default staying 0.01 forever.
const PORTRAIT_PIXEL_SIZE := 0.01
const PORTRAIT_TRAVEL_TIME := 1.4
const PORTRAIT_HIT_RADIUS := 1.0

signal portrait_hit(slot_name: String)

# This round's three player-side slot positions, in SLOT_NAMES order
# ([left, middle, right]) - set inside _select_correct_portraits() once
# player_positions is known. Kept on the instance (along with the two
# derived values below) since player_positions is otherwise local to
# _select_correct_portraits(), and _update_active_cursor()/_select_slot()
# need it every time Left/Right is pressed, not just once at round start.
var _slot_positions: Array = []
# Index into _slot_positions that player_layout left blank - the diver
# stands here (see _start_spawn_minigame()), and it's what tells
# _update_active_cursor() when the current selection is "the diver" (Diver
# height+0.6 lift) versus "a portrait" (flat 2.5 lift).
var _diver_slot_index := 1
# The one player-side slot player_layout left blank this round - just
# _slot_positions[_diver_slot_index], cached for readability where only the
# position (not the index) is needed.
var _blank_slot_position: Vector3
# Which of the three slots the cursor is currently over - starts on the
# diver's own slot each round (_start_spawn_minigame()), moved by
# _select_slot() on Left/Right.
var _selected_slot_index := 1

var left_image
var center_image
var right_image

# select_random_portrait() returns a bare Texture2D, which has no
# global_position to tween - needs a real Node3D wrapping it. Sprite3D
# (billboarded, so it always faces the camera regardless of which way
# target_actor/enemy_actor happen to be turned) is the natural fit, same
# "throwaway 3D node built in code, no .tscn" convention this project uses
# for rocks/cursors elsewhere.
func _make_portrait_sprite(texture: Texture2D, at_position: Vector3) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = PORTRAIT_PIXEL_SIZE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.global_position = at_position
	stage_root.add_child(sprite)
	return sprite

func _select_correct_portraits() -> void:
	var portraits: Array = select_random_portraits()
	# MODIFIED: select_random_portrait() can return the same texture twice
	# in a row (it's just a uniform random pick each time) - re-rolling
	# right_image until it differs guarantees the two "portraits" this
	# round are actually distinguishable from each other.
	var left_image: Texture2D = load(portraits[0])
	var right_image: Texture2D = load(portraits[1])

	var gap := 2.0
	# MODIFIED: was left_image.get_rect().size.x * left_image.scale.x -
	# get_rect()/scale are Sprite2D/Control properties, not Texture2D ones
	# (left_image here is the raw Texture2D select_random_portrait()
	# returns), so this would have errored the first time it ran.
	# Texture2D's own get_size() is the pixel dimensions; multiplying by
	# the sprite's pixel_size converts that to the same world-unit scale
	# the Sprite3D nodes below are actually built at.
	var half_width: float = left_image.get_size().x * PORTRAIT_PIXEL_SIZE / 2.0
	var spacing: float = half_width + gap  # extra breathing room beyond the sprite's own half-width

	var forward = -target_actor.global_transform.basis.z.normalized()
	var right = target_actor.global_transform.basis.x.normalized()

	var player_distance: float = target_actor.height + gap
	var enemy_distance: float = enemy_actor.height + gap

	var enemy_portrait_middle_position: Vector3 = enemy_actor.global_position + forward * enemy_distance
	var enemy_positions := {
		"left": enemy_portrait_middle_position - right * spacing,
		"middle": enemy_portrait_middle_position,
		"right": enemy_portrait_middle_position + right * spacing,
	}

	var player_portrait_middle_position: Vector3 = target_actor.global_position + forward * player_distance
	var player_positions := {
		"left": player_portrait_middle_position - right * spacing,
		"middle": player_portrait_middle_position,
		"right": player_portrait_middle_position + right * spacing,
	}

	# Two of the three slots hold a portrait, one is always blank - which
	# slot is blank is randomized (not pinned to "middle") so the safe spot
	# actually moves fight to fight instead of being memorizable.
	var enemy_layout: Array = [left_image, right_image, null]
	enemy_layout.shuffle()

	# Player's layout: both portraits must land somewhere other than their
	# own enemy-side slot (the blank is free to go anywhere - nothing to
	# dodge/catch there). With only 3 slots there are exactly 3 index
	# permutations of [0,1,2] that ever satisfy that - the two full
	# rotations (which have no fixed point at all, so they're always safe
	# regardless of where the blank is) plus swapping the two portrait
	# slots while leaving the blank's own slot untouched (see
	# _valid_player_permutations()). Picking directly from that precomputed
	# list is one randi_range() and three array reads - no shuffle-and-
	# reject loop needed.
	var player_layout: Array = enemy_layout
	var player_0 = randi_range(1, 2)
	var player_1
	if player_0 == 1:
		var remaining_positions: Array = [0, 2]
		remaining_positions.shuffle()
		player_1 = remaining_positions[0]
	else:

		player_1 = 0
	var secured_positions : Array = [player_0, player_1]
	if 0 not in secured_positions:
		secured_positions.append(0)
	elif 1 not in secured_positions:
		secured_positions.append(1)
	else:
		secured_positions.append(2)


	player_layout[0] = enemy_layout[secured_positions[0]]
	player_layout[1] = enemy_layout[secured_positions[1]]
	player_layout[2] = enemy_layout[secured_positions[2]]
	#var left_sprite := _make_portrait_sprite(player_layout[0], player_positions[target_slot])
	#var middle_sprite := _make_portrait_sprite(player_layout[1], enemy_positions[target_slot])
	#var right_sprite := _make_portrait_sprite(player_layout[2], enemy_positions[target_slot])


	_slot_positions = [player_positions["left"], player_positions["middle"], player_positions["right"]]
	_diver_slot_index = player_layout.find(null)
	_blank_slot_position = _slot_positions[_diver_slot_index]

	for i in range(3):
		var texture: Texture2D = enemy_layout[i]
		if texture == null:
			continue
		var target_slot: String = SLOT_NAMES[i]
		var sprite := _make_portrait_sprite(texture, enemy_positions[target_slot])
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "global_position", player_positions[target_slot], PORTRAIT_TRAVEL_TIME)
		tw.tween_callback(_on_portrait_arrived.bind(sprite, target_slot, player_layout[i]))

# The two 3-cycles of [0,1,2] have no fixed points at all, so a rotation
# never leaves a portrait in its own slot no matter where the blank is -
# always valid. The third valid arrangement (swap the two portrait slots,
# leave the blank's own slot alone) depends on which index the blank is
# at, so it's built fresh here rather than also being a constant.
const ROTATE_FORWARD := [1, 2, 0]
const ROTATE_BACKWARD := [2, 0, 1]

func _valid_player_permutations(blank_index: int) -> Array:
	var swap_keep_blank: Array = [0, 1, 2]
	var portrait_indices: Array = [0, 1, 2]
	portrait_indices.erase(blank_index)
	swap_keep_blank[portrait_indices[0]] = portrait_indices[1]
	swap_keep_blank[portrait_indices[1]] = portrait_indices[0]
	return [ROTATE_FORWARD, ROTATE_BACKWARD, swap_keep_blank]

# Fires once a single portrait's flight finishes. "Hit" is decided by
# actual distance to the player right now (same idiom _try_shockwave()
# already uses for rocks: target_actor.global_position, not the slot's
# static computed position) rather than just "which slot was it aimed at" -
# so this stays correct later if the player ends up able to move between
# slots to dodge, instead of a hit being a foregone conclusion the instant
# the round is set up.
func _on_portrait_arrived(sprite: Sprite3D, target_slot: String, expected_texture: Texture2D) -> void:
	var hit := expected_texture != null and sprite.texture == expected_texture
	if hit:
		portrait_hit.emit(target_slot)

	# MODIFIED: was a bare sprite.queue_free() right after the hit check -
	# freed the sprite before flash_object's own await get_tree().
	# create_timer() ever had a chance to finish, so the flash would never
	# actually be seen. Awaiting it here first means queue_free() only runs
	# once the flash has fully played out.
	await flash_object(sprite, Color.GREEN if hit else Color.RED, 0.15)
	sprite.queue_free()


# MODIFIED: was object: Node2D - sprite here is a Sprite3D (Node3D side of
# the tree, not Node2D), so this would have been a static type error the
# moment _on_portrait_arrived actually called it.
func flash_object(object: Sprite3D, flash_color: Color, duration: float) -> void:
	var original_color = object.modulate
	object.modulate = flash_color
	await get_tree().create_timer(duration).timeout
	object.modulate = original_color

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
	var keycode := (event as InputEventKey).keycode
	if keycode == KEY_E:
		_try_shockwave()
	elif keycode == KEY_LEFT:
		_select_slot(-1)
	elif keycode == KEY_RIGHT:
		_select_slot(1)

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
