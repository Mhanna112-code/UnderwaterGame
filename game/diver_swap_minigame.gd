# Mech Pilot's special-encounter minigame (see battle.gd's _do_enemy_turn()
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
# Fired once a round's 3 lanes have all resolved - _spawn_loop() awaits this
# instead of a fixed timer so round N+1 can never start before round N is
# genuinely done (see _spawn_loop()'s own comment for why the old fixed
# timer let rounds overlap and contaminate each other's state).
signal round_finished

# Every Node3D this instance has ever added under stage_root (portrait
# sprites, reference sprites, the cursor) - stage_root is a SubViewport that
# outlives any one DiverSwapMinigame instance, so nothing parented to it
# gets cleaned up just because this Control does. Individual pieces mostly
# free themselves as they mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmresolve (see _on_portrait_arrived(),
# _clear_reference_sprites()), but that's proven easy to miss a case of
# (the cursor was left behind entirely until this was added) - this is a
# final safety-net sweep in _maybe_finish() that frees whatever, if
# anything, is still around regardless of which specific cleanup path was
# supposed to catch it.
var _spawned_stage_nodes: Array[Node3D] = []
func _cleanup_stage_nodes() -> void:
	for n in _spawned_stage_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_spawned_stage_nodes.clear()

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

func _ready() -> void:
	# MODIFIED (fixed): battle.gd's Battle extends CanvasLayer, not Control -
	# added directly under it (see _do_swap_minigame()'s add_child(minigame)),
	# this Control has no Control ancestor to resolve set_anchors_preset()'s
	# anchor fractions against. Without an explicit offsets pass (or a real
	# size), a Control parented under a non-Control never gets its rect
	# recomputed from anchors at all - it just stays at the (0,0)/zero-size
	# default a fresh Control.new() starts with. Every child's PRESET_CENTER_*
	# anchor below (title/hint/progress) then collapsed to that same (0,0)
	# point instead of true screen-center, which is exactly why "SWAP TO
	# SAFETY" and the old control-hint text were both rendering crammed into
	# the top-left corner instead of centered. Same fallback grapple_
	# intercept_minigame.gd's own _ready() already uses correctly.
	if get_parent() is Control:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # only individual rocks/labels catch clicks, not the whole overlay

	# No full-screen dimmer: the special encounter should leave the battle
	# scene at its normal brightness while the portrait lanes are overlaid.

	# MODIFIED (removed): the "SWAP TO SAFETY" title, the "Left/Right to aim,
	# E to swap into that spot" hint, and this progress readout all used to
	# render here as floating Control text over the minigame - per direct
	# request, every one of them is gone now. The controls explanation and
	# the "flawless run" wave narration already live in the battle log
	# instead (see battle.gd's _do_swap_minigame() and _finish_special_
	# enemy_turn()), so nothing is actually lost, just no longer duplicated
	# as an overlay competing with the HUD for the same screen space.

# No more title card to hold on screen before the portraits start - the
# battle log's own lead-in line (see _do_swap_minigame()) already covers
# that beat, so this starts the encounter immediately instead of waiting
# out a title that no longer exists.
func run() -> void:
	_spawn_loop()
	_maybe_finish()

# MODIFIED (changed): used to write into _progress_label, now removed (see
# _ready()'s own comment) - kept as a no-op rather than deleted outright so
# every call site that reports a hit (_maybe_finish() and friends) doesn't
# need its own edit just to drop a call to a function that used to matter.
func _update_progress() -> void:
	pass

var PORTRAIT_COUNT = 3
# MODIFIED: was `await get_tree().create_timer(_current_travel_time).timeout`
# - a FIXED duration equal to how long each round's own portraits take to
# fly, so round N+1 could start at nearly the same instant round N's
# portraits were still resolving. When that happened, round N+1's
# _select_correct_portraits() (_clear_reference_sprites() + rebuild) could
# run before round N's last arrival fired, so that late arrival read round
# N+1's brand-new references, bumped round N+1's _round_resolved before any
# of ITS OWN lanes had resolved, and could clear round N+1's references
# early - exactly the kind of cross-round contamination that would make a
# later round (see round_finished below) look unresponsive to input even
# though the code "should" be fine. Awaiting round_finished instead makes
# round N+1 wait for round N's _round_resolved to genuinely reach 3 first,
# so rounds can never overlap.
# MODIFIED (fixed): this loop had no idea request_abort() (or a natural
# finish - PORTRAIT_COUNT rounds already spawned before a slow last one even
# resolves) had already happened, since `run()` fires it off unawaited and
# nothing here ever checked _did_finish. On an early abort (the diver died
# partway through) it just kept going, spawning another round - and each
# round's own _start_spawn_minigame() re-parks the diver back in the swap
# grid (_blank_slot_position) to set it up, undoing whatever already put her
# back at her real rest spot, which is exactly why the camera kept reading
# as zoomed into the grid: new portraits, and her, both back in the middle
# of it, well after battle.gd had already moved on to the death/loss flow.
func _spawn_loop() -> void:
	while _spawned < PORTRAIT_COUNT and not _did_finish:
		_start_spawn_minigame()
		_spawned += 1
		if _spawned < PORTRAIT_COUNT and not _did_finish:
			await round_finished

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

# Second, separate 8-portrait pool (the "Cyclops" helmet set) - kept as its
# own array rather than merged into PORTRAIT_PATHS so select_random_
# portraits() can pick a pool first and draw both of a round's portraits
# from just that one, never mixing an image from each set in the same
# round.
const CYCLOPS_PORTRAIT_PATHS := [
	"res://portraits/helmet_pool/cyclops_01_calm.png",
	"res://portraits/helmet_pool/cyclops_02_wavy.png",
	"res://portraits/helmet_pool/cyclops_03_content.png",
	"res://portraits/helmet_pool/cyclops_04_grin.png",
	"res://portraits/helmet_pool/cyclops_05_angry.png",
	"res://portraits/helmet_pool/cyclops_06_surprised.png",
	"res://portraits/helmet_pool/cyclops_07_pout.png",
	"res://portraits/helmet_pool/cyclops_08_mystery.png",
]

func select_random_portraits() -> Array:
	# MODIFIED (added): picks one of the two 8-portrait pools first, then
	# draws both portraits from that same pool - duplicated before
	# shuffling so this never mutates the shared const array in place, and
	# so the other pool's own array is never touched by picking this one.
	var pool: Array = (PORTRAIT_PATHS if randi() % 2 == 0 else CYCLOPS_PORTRAIT_PATHS).duplicate()
	pool.shuffle()
	var portraits: Array = [pool[0], pool[1]]
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
	_spawned_stage_nodes.append(_active_cursor)

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
	var lift = (target_actor as Diver).height + 0.6
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
	# MODIFIED (added): _select_correct_portraits() used to derive the
	# whole grid's center/orientation from target_actor's CURRENT position
	# every round - but by round 2 that's wherever round 1 left her (the
	# blank slot, or a manual swap), so the grid re-centered on an
	# already-offset spot each round, compounding further every round
	# after. Captured once here, before she's ever moved, so every round
	# in this encounter uses the same fixed anchor.
	if not _has_player_anchor:
		_player_anchor_position = target_actor.global_position
		_player_anchor_forward = -target_actor.global_transform.basis.z.normalized()
		_player_anchor_right = target_actor.global_transform.basis.x.normalized()
		_has_player_anchor = true
	_round_resolved = 0
	_select_correct_portraits()
	target_actor.global_position = _blank_slot_position
	if _active_cursor == null:
		_build_active_cursor()
	_selected_slot_index = _diver_slot_index
	_update_active_cursor()

# Confirms the cursor's current selection (Left/Right, see _select_slot())
# with an actual SWAP - the "swap" this minigame is themed around (see
# diver.gd's Staff_Diver ability id). The diver moves into the target slot
# AND whichever reference portrait was sitting there (_reference_sprites)
# moves back into the slot she just vacated, so the two genuinely trade
# places instead of her just teleporting on top of it. Landing on the
# round's real blank slot is what makes her safe from the incoming
# portraits; moving anywhere else just relocates her into a slot one is
# still inbound for.
func _confirm_swap() -> void:
	if _slot_positions.is_empty() or _selected_slot_index == _diver_slot_index:
		return
	var previous_diver_slot := _diver_slot_index
	var target_slot := _selected_slot_index
	var portrait_at_target: Sprite3D = _reference_sprites[target_slot]

	target_actor.global_position = _slot_positions[target_slot]
	if portrait_at_target != null and is_instance_valid(portrait_at_target):
		portrait_at_target.global_position = _slot_positions[previous_diver_slot]
	_reference_sprites[previous_diver_slot] = portrait_at_target
	_reference_sprites[target_slot] = null

	_diver_slot_index = target_slot
	_update_active_cursor()

# Units per second a portrait travels - was declared but never actually
# used anywhere, which is why tuning it never had any effect. Speed was
# implicitly fixed instead by PORTRAIT_TRAVEL_TIME (a flat duration): every
# portrait crossed whatever distance that round happened to need in the
# same 1.4s, so widening the enemy/player gap for is_swap_encounter (see
# battle.gd's _build_stage()) made portraits visibly speed up without this
# file changing at all - same distance-in-fixed-time trap the comment atop
# this file already calls out for blast_rocks_minigame.gd's flight time.
# _current_travel_time (below) now derives the actual duration from this
# speed and this round's real distance instead.
var portraitSpeed = 2.6
# This round's travel duration, computed in _select_correct_portraits()
# from the actual enemy-to-player distance and portraitSpeed above - used
# for both the tween itself and _spawn_loop()'s round-to-round pacing, so
# both stay correct no matter how the encounter's spacing changes.
var _current_travel_time := 1.75

const SLOT_NAMES := ["left", "middle", "right"]
# Sprite3D's own default - kept as an explicit const so the half-width
# math below uses the exact same number the sprite is actually built with,
# instead of relying on the default staying 0.01 forever.
const PORTRAIT_PIXEL_SIZE := 0.01
const PORTRAIT_TARGET_SIZE := Vector2(410.0, 384.0)
const PORTRAIT_LANE_GAP := 0.3

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

# The diver's fixed rest position/orientation for this encounter - captured
# once in _start_spawn_minigame() before she's ever moved, so every round's
# grid is centered on the same spot instead of drifting round to round.
var _player_anchor_position: Vector3
var _player_anchor_forward: Vector3
var _player_anchor_right: Vector3
var _has_player_anchor := false

# The static reference portrait currently resting in each player-side slot
# (see _select_correct_portraits()), indexed the same way _slot_positions
# is (0/1/2 = left/middle/right) rather than just appended in order - null
# for the diver's own slot, so _confirm_swap() can look up "what's sitting
# in the slot I'm swapping into" and move it into the slot she's leaving.
# Freed once this round's 3 incoming portraits all resolve (_round_resolved,
# below), instead of lingering on screen until the next round starts.
var _reference_sprites: Array[Sprite3D] = [null, null, null]
func _clear_reference_sprites() -> void:
	for i in range(_reference_sprites.size()):
		var s := _reference_sprites[i]
		if s != null and is_instance_valid(s):
			s.queue_free()
		_reference_sprites[i] = null

# How many of THIS round's 3 incoming portraits have resolved so far -
# reset every round in _start_spawn_minigame(), unlike _resolved (which
# tracks the total across all PORTRAIT_COUNT rounds for _maybe_finish()).
# Once all 3 are in, the reference sprites have done their job and clear.
var _round_resolved := 0

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
	if texture != null:
		sprite.texture = texture
	sprite.pixel_size = PORTRAIT_PIXEL_SIZE
	if texture != null:
		sprite.scale = _portrait_scale(texture)
	else:
		# Keep a non-rendering arrival marker for the intentionally blank
		# lane. Its tween/callback must still complete so every round reaches
		# all three lane results, but there is no portrait to draw or scale.
		sprite.visible = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Add to the tree BEFORE touching global_position: off-tree,
	# set_global_position() reads get_global_transform(), which fails
	# ("!is_inside_tree()") and returns an identity Transform3D - writing
	# that back wiped the scale set above, so every portrait drew at its
	# raw texture size instead of PORTRAIT_TARGET_SIZE.
	stage_root.add_child(sprite)
	sprite.global_position = at_position
	_spawned_stage_nodes.append(sprite)
	return sprite

# AtlasTexture.get_size() can report a size that doesn't match the crop we
# actually want to display. Read AtlasTexture.region explicitly so scaling
# and lane spacing use the cropped frame dimensions, not the source atlas.
func _portrait_texture_size(texture: Texture2D) -> Vector2:
	if texture is AtlasTexture:
		return (texture as AtlasTexture).region.size
	return texture.get_size()

# Stretch every portrait crop to exactly PORTRAIT_TARGET_SIZE pixels, so all
# cards read as the same size regardless of crop or source pool. X and Y are
# scaled independently, which does not preserve each crop's aspect ratio.
func _portrait_scale(texture: Texture2D) -> Vector3:
	var s := PORTRAIT_TARGET_SIZE / _portrait_texture_size(texture)
	return Vector3(s.x, s.y, 1.0)

func _select_correct_portraits() -> void:
	var portraits: Array = select_random_portraits()
	# MODIFIED: select_random_portrait() can return the same texture twice
	# in a row (it's just a uniform random pick each time) - re-rolling
	# right_image until it differs guarantees the two "portraits" this
	# round are actually distinguishable from each other.
	var left_image: Texture2D = load(portraits[0])
	var right_image: Texture2D = load(portraits[1])

	var gap := 2.0
	# Every portrait is scaled to PORTRAIT_TARGET_SIZE.x pixels wide
	# (_portrait_scale()); multiplying by the sprite's pixel_size converts
	# that to the world-unit width the Sprite3D nodes below are built at.
	# Adjacent lane centers are one `spacing` apart (left-to-middle and
	# middle-to-right), so use the full card width here, then add a small
	# visible gap. Using the half-width made neighboring cards overlap.
	var card_width: float = PORTRAIT_TARGET_SIZE.x * PORTRAIT_PIXEL_SIZE
	var spacing: float = card_width + PORTRAIT_LANE_GAP

	var forward = _player_anchor_forward
	var right = _player_anchor_right

	var player_distance: float = target_actor.height + gap
	var enemy_distance: float = enemy_actor.height + gap

	var enemy_portrait_middle_position: Vector3 = enemy_actor.global_position + forward * enemy_distance
	var enemy_positions := {
		"left": enemy_portrait_middle_position - right * spacing,
		"middle": enemy_portrait_middle_position,
		"right": enemy_portrait_middle_position + right * spacing,
	}

	var player_portrait_middle_position: Vector3 = _player_anchor_position + forward * player_distance
	_current_travel_time = enemy_portrait_middle_position.distance_to(player_portrait_middle_position) / portraitSpeed
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

	var player_layout: Array = enemy_layout.duplicate()
	var player_0 = randi_range(1, 2)
	var player_1
	if player_0 == 1:
		player_1 = 2
	else:
		player_1 = 0
	var secured_positions : Array = [player_0, player_1]
	if 0 not in secured_positions:
		secured_positions.append(0)
	elif 1 not in secured_positions:
		secured_positions.append(1)


	player_layout[0] = enemy_layout[secured_positions[0]]
	player_layout[1] = enemy_layout[secured_positions[1]]
	player_layout[2] = enemy_layout[secured_positions[2]]

	_slot_positions = [player_positions["left"], player_positions["middle"], player_positions["right"]]
	_diver_slot_index = player_layout.find(null)
	_blank_slot_position = _slot_positions[_diver_slot_index]

	# Static "reference" sprites - sit at rest in the two player-side slots
	# that actually hold a portrait this round (player_layout), so the
	# player can see right away what's supposed to end up where instead of
	# only finding out once the real incoming portrait finishes its flight.
	# Only 2, not 3 - the one slot player_layout leaves blank is where the
	# diver herself is standing (_blank_slot_position, above), so it
	# doesn't need a placeholder. Cleared and rebuilt every round rather
	# than left to pile up.
	_clear_reference_sprites()
	for i in range(3):
		var reference_texture: Texture2D = player_layout[i]
		if reference_texture == null:
			continue
		_reference_sprites[i] = _make_portrait_sprite(reference_texture, player_positions[SLOT_NAMES[i]])

	for i in range(3):
		var texture: Texture2D = enemy_layout[i]
		var target_slot: String = SLOT_NAMES[i]
		var sprite := _make_portrait_sprite(texture, enemy_positions[target_slot])
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "global_position", player_positions[target_slot], _current_travel_time)
		tw.tween_callback(_on_portrait_arrived.bind(sprite, target_slot))

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

# Fires once a single portrait's flight finishes. "Hit" (safe/green) means
# the SAME portrait that launched from this lane on the enemy side
# (enemy_layout, sprite.texture) matches whatever's CURRENTLY the correct
# reference portrait for this same lane on the player side
# (_reference_sprites[slot_index]) - or, for the lane the diver herself is
# standing in (no reference sprite there), that nothing (null) arrived.
# Reads _reference_sprites rather than the frozen player_layout snapshot
# from round start specifically so a manual swap (_confirm_swap(), which
# keeps _reference_sprites live-updated) actually changes what counts as
# correct for the lane moved into - checking player_layout directly would
# still grade against the ORIGINAL pre-swap arrangement.
signal portrait_landed
func _on_portrait_arrived(sprite: Sprite3D, target_slot: String) -> void:
	var slot_index := SLOT_NAMES.find(target_slot)
	var reference: Sprite3D = _reference_sprites[slot_index]
	var expected_texture: Texture2D = reference.texture if reference != null and is_instance_valid(reference) else null
	var hit := sprite.texture == expected_texture
	if hit:
		_hits += 1
	else:
		# MODIFIED: was `elif sprite.texture != null` - only counted a REAL
		# arriving portrait mismatching a null reference as a misfire, not
		# the reverse (nothing arriving where a reference expected a real
		# portrait). Both directions are equally a mismatch now - up to 2
		# lanes can misfire per round, either way round.
		portrait_landed.emit()
	_round_resolved += 1
	var is_last_in_round := _round_resolved >= SLOT_NAMES.size()
	_update_progress()

	# Only the player-side reference portrait in this lane flashes: red if
	# it's in the wrong lane (doesn't match what just arrived), green if it
	# matches. The incoming sprite lands exactly on top of the reference, so
	# it's freed right away rather than flashed - otherwise it would cover
	# the reference's flash. The diver's own lane has no reference, so it
	# doesn't flash either way.
	sprite.queue_free()
	if reference != null and is_instance_valid(reference):
		await flash_object(reference, Color.GREEN if hit else Color.RED, 0.15)
	else:
		# Same wait as a flash, so the last-in-round ordering below still
		# holds no matter which lane resolves last.
		await get_tree().create_timer(0.15).timeout

	# References are cleared only AFTER this round's flashes - clearing on
	# the third arrival (before awaiting) freed them mid-flash. All three
	# lanes land in the same frame with the same flash duration, so the
	# last arrival's timer is also the last to fire.
	if is_last_in_round:
		_clear_reference_sprites()
		round_finished.emit()

	# MODIFIED: _resolved's increment (and the _maybe_finish() check) used
	# to happen BEFORE this sprite's own flash/free above, so the 9th
	# (truly last) arrival could call _maybe_finish(), which emits
	# `finished`, which resumes battle.gd's `await minigame.finished`
	# SYNCHRONOUSLY right here mid-call - battle.gd immediately calls
	# minigame.queue_free() on this very Control, and resuming this
	# sprite's own still-pending await get_tree().create_timer() above
	# afterward (on a since-freed Object) errors out silently, so its
	# flash/queue_free() never ran and it was orphaned on screen. Since
	# several of a round's sprites can finish their tween in the same
	# frame, this could strand more than one - matching "last round of
	# portraits stays on screen." Counting a sprite as resolved only AFTER
	# it has fully flashed and freed itself means whichever call is the
	# one to finally reach 9 is guaranteed to be the last one to finish,
	# by which point every other sprite has already completed too.
	_resolved += 1
	_maybe_finish()

# MODIFIED: was object: Node2D - sprite here is a Sprite3D (Node3D side of
# the tree, not Node2D), so this would have been a static type error the
# moment _on_portrait_arrived actually called it.
func flash_object(object: Sprite3D, flash_color: Color, duration: float) -> void:
	var original_color = object.modulate
	object.modulate = flash_color
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(object):
		object.modulate = original_color

# MODIFIED: was 1.5 - battle.gd widened the diver/enemy gap for special
# encounters (roughly doubled), but this radius stayed the same, so a rock
# only spent a small fraction of its now-longer flight actually within
# range - pressing E as soon as a rock appeared (the natural instinct)
# almost always landed outside this radius and did nothing, which read as
# "shockwave doesn't affect the rocks at all." Scaled up to keep roughly
# the same fraction of the flight breakable as before the gap widened.
const SHOCKWAVE_RADIUS := 3.0

# Left/Right (keyboard) move the cursor; left click confirms it
# immediately - unlike blast_rocks_minigame.gd/rock_dodge_minigame.gd
# (single E press does the whole action), this one already needs the
# keyboard to aim, so confirming with a click keeps the two steps on
# separate inputs instead of overloading E for both.
func _unhandled_input(event: InputEvent) -> void:
	# MODIFIED: was left-click (InputEventMouseButton), then briefly Enter -
	# settled on E to match the same confirm key rock_dodge_minigame.gd/
	# blast_rocks_minigame.gd already use for their own encounters, so all
	# three special-encounter minigames share one consistent "E confirms"
	# convention instead of each picking its own input.
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var keycode := (event as InputEventKey).keycode
	if keycode == KEY_LEFT:
		_select_slot(-1)
	elif keycode == KEY_RIGHT:
		_select_slot(1)
	elif keycode == KEY_E:
		_confirm_swap()

# MODIFIED: picks whichever live rock is actually closest and within
# range, not just "the" active one - with several rocks in flight at once
# there's no single rock to check against anymore, so this scans all of
# them. Still a no-op (not a miss) if nothing's in range, same "free
# presses don't get punished" rule as before.

# A quick scale-up-and-free "shattered" flash rather than an instant
# queue_free() - a hit needs to visibly register as a hit, same reason
# cracked_wall.gd's break isn't silent either.
"""func _break_rock(rock: MeshInstance3D) -> void:
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
	_maybe_finish()"""

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
"""func _on_rock_landed(rock: MeshInstance3D) -> void:
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
	_maybe_finish()"""

# Guards _finish_now() against emitting `finished` twice - it's reachable
# from two places (the natural PORTRAIT_COUNT/total_portraits completion
# below, and battle.gd's request_abort() when the player's HP hits 0
# mid-encounter), and a second emission would resume battle.gd's already-
# resumed `await minigame.finished` a second time.
var _did_finish := false

func _maybe_finish() -> void:
	# MODIFIED: was `_resolved >= PORTRAIT_COUNT` (3) - _resolved counts
	# every individual lane arrival across ALL rounds (3 rounds x 3 lanes =
	# up to 9), not rounds. Since round 1's 3 lanes typically finish
	# resolving by around the time round 3 even SPAWNS (_spawn_loop() paces
	# rounds _current_travel_time apart, about the same as one lane's own
	# flight time), _resolved could already be >= 3 the instant _spawned
	# hit 3 - `finished` fired, and battle.gd's minigame.queue_free() tore
	# down the camera/overlay, while round 2 and round 3's sprites (parented
	# to stage_root, not to this Control, so queue_free() never touched
	# them) were still mid-flight. That's why portraits kept being visible
	# after the view had already switched back to the normal battle framing.
	var total_portraits: int = PORTRAIT_COUNT * SLOT_NAMES.size()
	if _spawned >= PORTRAIT_COUNT and _resolved >= total_portraits:
		_finish_now(total_portraits)

# Called by battle.gd the instant the player's HP hits 0 mid-encounter -
# ends the swap minigame right away with whatever tally it has so far,
# instead of continuing to fly more portraits at a diver who's already
# down. _finish_now()'s own _did_finish guard makes this safe even if the
# natural completion above was also about to fire on its own.
func request_abort() -> void:
	_finish_now(PORTRAIT_COUNT * SLOT_NAMES.size())

func _finish_now(total_portraits: int) -> void:
	if _did_finish:
		return
	_did_finish = true
	# MODIFIED (added): was leaving target_actor wherever the last round
	# (or the player's last manual swap) put her - same "swim back to
	# exactly where this started" fix blast_rocks_minigame.gd already
	# applies for the same reason (see its own _maybe_finish()).
	# Without this, she'd stay stranded off to one side after the
	# minigame ends, so the NEXT special-encounter turn's camera
	# (_look_at_swap_angle(), computed from her current position) would
	# frame around that drifted spot instead of her real battle stance
	# - exactly why the camera angle looked different the second time
	# the enemy used this attack.
	if is_instance_valid(target_actor):
		var back := target_actor.create_tween()
		back.tween_property(target_actor, "global_position", _player_anchor_position, _current_travel_time * 0.5)
	# MODIFIED (was individually freeing just _active_cursor here): that
	# fixed the cursor specifically, but it was still one more instance
	# of the same class of bug (stage_root outlives this Control, so
	# nothing parented to it gets cleaned up just because this Control
	# does) - _cleanup_stage_nodes() is the general version, sweeping
	# every sprite/cursor this instance ever created under stage_root
	# regardless of whether its own individual cleanup path (self-free
	# on arrival, per-round reference clearing) already got it. Anything
	# already freed is skipped via is_instance_valid(), so this is a
	# safety net, not a duplicate free.
	_cleanup_stage_nodes()
	finished.emit(_hits, total_portraits)
