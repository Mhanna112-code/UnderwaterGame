# Mech Pilot's portrait-swap special-encounter minigame. Left/Right aim, E swaps the
# diver into a slot so incoming portraits land on their matching references.
# battle.gd calls run(), awaits `finished`, and owns all damage logic.
class_name DiverSwapMinigame
extends Control

signal finished(hits: int, total: int)
# Emitted when all 3 lanes of a round resolve; _spawn_loop() awaits it so rounds never overlap.
signal round_finished

# Every Node3D added under stage_root, which outlives this Control. Swept in _finish_now() as a safety net.
var _spawned_stage_nodes: Array[Node3D] = []
func _cleanup_stage_nodes() -> void:
	for n in _spawned_stage_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_spawned_stage_nodes.clear()

var stage_root: SubViewport

var target_actor: Node3D
var enemy_actor: Node3D

var _hits := 0
var _resolved := 0
var _spawned := 0

func _ready() -> void:
	# Parent may be a CanvasLayer, so size to the viewport manually.
	if get_parent() is Control:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # only rocks/labels catch clicks



func run() -> void:
	_spawn_loop()
	_maybe_finish()

# No-op; kept so existing call sites don't need edits.
func _update_progress() -> void:
	pass

var PORTRAIT_COUNT = 3
# Awaits round_finished between rounds; stops on _did_finish (early abort).
func _spawn_loop() -> void:
	while _spawned < PORTRAIT_COUNT and not _did_finish:
		_start_spawn_minigame()
		_spawned += 1
		if _spawned < PORTRAIT_COUNT and not _did_finish:
			await round_finished


# Leftover state used only by the retired rock functions in the strings below.
var _live_rocks: Array[MeshInstance3D] = []
var _rock_tweens: Dictionary = {}   # MeshInstance3D -> Tween
# One pool per character; each wave draws both portraits from a single pool.
const MAXILANI_PORTRAIT_PATHS := [
	"res://portraits/maxilani_pool/maxilani_01_normal.png",
	"res://portraits/maxilani_pool/maxilani_02_smile.png",
	"res://portraits/maxilani_pool/maxilani_03_eyes_closed.png",
	"res://portraits/maxilani_pool/maxilani_04_smirk.png",
	"res://portraits/maxilani_pool/maxilani_05_grimace.png",
	"res://portraits/maxilani_pool/maxilani_06_surprised.png",
	"res://portraits/maxilani_pool/maxilani_07_sad.png",
	"res://portraits/maxilani_pool/maxilani_08_wink.png",
]

const BUCKY_PORTRAIT_PATHS := [
	"res://portraits/bucky_pool/bucky_01_calm.png",
	"res://portraits/bucky_pool/bucky_02_grin.png",
	"res://portraits/bucky_pool/bucky_03_love.png",
	"res://portraits/bucky_pool/bucky_04_angry.png",
	"res://portraits/bucky_pool/bucky_05_crying.png",
	"res://portraits/bucky_pool/bucky_06_frown.png",
	"res://portraits/bucky_pool/bucky_07_bored.png",
	"res://portraits/bucky_pool/bucky_08_surprised.png",
]

const MUSASHI_PORTRAIT_PATHS := [
	"res://portraits/musashi_pool/cyclops_01_calm.png",
	"res://portraits/musashi_pool/cyclops_02_wavy.png",
	"res://portraits/musashi_pool/cyclops_03_content.png",
	"res://portraits/musashi_pool/cyclops_04_grin.png",
	"res://portraits/musashi_pool/cyclops_05_angry.png",
	"res://portraits/musashi_pool/cyclops_06_surprised.png",
	"res://portraits/musashi_pool/cyclops_07_pout.png",
	"res://portraits/musashi_pool/cyclops_08_mystery.png",
]

const PORTRAIT_POOLS := [MAXILANI_PORTRAIT_PATHS, BUCKY_PORTRAIT_PATHS, MUSASHI_PORTRAIT_PATHS]

func select_random_portraits() -> Array:
	# Random pool, then two different portraits; duplicated so the const isn't mutated.
	var pool: Array = (PORTRAIT_POOLS.pick_random() as Array).duplicate()
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
	_active_cursor.rotation_degrees.x = 180.0   # points down at the diver
	# Must live under stage_root to render.
	stage_root.add_child(_active_cursor)
	_spawned_stage_nodes.append(_active_cursor)

# Hovers the cursor over the selected slot.
func _update_active_cursor() -> void:
	if _active_cursor == null or _slot_positions.is_empty():
		return
	var lift = (target_actor as Diver).height + 0.6
	_active_cursor.visible = true
	_active_cursor.global_position = _slot_positions[_selected_slot_index] + Vector3.UP * lift

# Wraps around at either end.
func _select_slot(delta: int) -> void:
	_selected_slot_index = (_selected_slot_index + delta + 3) % 3
	_update_active_cursor()

# Starts a round: build layout and flights, place the diver in the blank slot, select it.
func _start_spawn_minigame() -> void:
	# Anchor captured once so every round's grid is centered on the same spot.
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

# Swaps the diver with the reference portrait in the selected slot.
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

# Portrait speed in units/sec; travel time is derived from it per round.
var portraitSpeed = 3.7209
# This round's travel duration (distance / portraitSpeed).
var _current_travel_time := 1.75

const SLOT_NAMES := ["left", "middle", "right"]
# Sprite3D's default; explicit so the width math matches.
const PORTRAIT_PIXEL_SIZE := 0.01
const PORTRAIT_TARGET_SIZE := Vector2(410.0, 384.0)
const PORTRAIT_LANE_GAP := 0.3

signal portrait_hit(slot_name: String)

# This round's player-side slot positions, [left, middle, right].
var _slot_positions: Array = []
# Slot left blank this round; the diver stands here.
var _diver_slot_index := 1
# Cached _slot_positions[_diver_slot_index].
var _blank_slot_position: Vector3
# Slot the cursor is over.
var _selected_slot_index := 1

# Diver's rest position/orientation, captured once per encounter.
var _player_anchor_position: Vector3
var _player_anchor_forward: Vector3
var _player_anchor_right: Vector3
var _has_player_anchor := false

# Reference portrait in each player-side slot (null for the diver's slot); kept live by _confirm_swap().
var _reference_sprites: Array[Sprite3D] = [null, null, null]
func _clear_reference_sprites() -> void:
	for i in range(_reference_sprites.size()):
		var s := _reference_sprites[i]
		if s != null and is_instance_valid(s):
			s.queue_free()
		_reference_sprites[i] = null

# Portraits resolved this round (vs _resolved, the encounter total).
var _round_resolved := 0

var left_image
var center_image
var right_image

# Billboarded Sprite3D wrapper for a portrait texture.
func _make_portrait_sprite(texture: Texture2D, at_position: Vector3) -> Sprite3D:
	var sprite := Sprite3D.new()
	if texture != null:
		sprite.texture = texture
	sprite.pixel_size = PORTRAIT_PIXEL_SIZE
	if texture != null:
		sprite.scale = _portrait_scale(texture)
	else:
		# Invisible marker for the blank lane; its tween must still complete.
		sprite.visible = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Add to the tree before setting global_position, or the scale is wiped.
	stage_root.add_child(sprite)
	sprite.global_position = at_position
	_spawned_stage_nodes.append(sprite)
	return sprite

# Use AtlasTexture.region so sizing uses the crop, not the full atlas.
func _portrait_texture_size(texture: Texture2D) -> Vector2:
	if texture is AtlasTexture:
		return (texture as AtlasTexture).region.size
	return texture.get_size()

# Stretch every crop to PORTRAIT_TARGET_SIZE (aspect not preserved).
func _portrait_scale(texture: Texture2D) -> Vector3:
	var s := PORTRAIT_TARGET_SIZE / _portrait_texture_size(texture)
	return Vector3(s.x, s.y, 1.0)

func _select_correct_portraits() -> void:
	var portraits: Array = select_random_portraits()
	var left_image: Texture2D = load(portraits[0])
	var right_image: Texture2D = load(portraits[1])

	var gap := 2.0
	# Lane centers are one full card width plus a gap apart.
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

	# Two slots hold portraits, one is blank; which one is randomized.
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

	# Static references in the player-side slots that hold a portrait this round.
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

# 3-cycles never leave a portrait in its own slot; the swap variant depends on the blank index.
const ROTATE_FORWARD := [1, 2, 0]
const ROTATE_BACKWARD := [2, 0, 1]

func _valid_player_permutations(blank_index: int) -> Array:
	var swap_keep_blank: Array = [0, 1, 2]
	var portrait_indices: Array = [0, 1, 2]
	portrait_indices.erase(blank_index)
	swap_keep_blank[portrait_indices[0]] = portrait_indices[1]
	swap_keep_blank[portrait_indices[1]] = portrait_indices[0]
	return [ROTATE_FORWARD, ROTATE_BACKWARD, swap_keep_blank]

# Hit if the arriving portrait matches the lane's current reference (null for the diver's lane).
# Reads _reference_sprites so manual swaps change what counts as correct.
signal portrait_landed
func _on_portrait_arrived(sprite: Sprite3D, target_slot: String) -> void:
	var slot_index := SLOT_NAMES.find(target_slot)
	var reference: Sprite3D = _reference_sprites[slot_index]
	var expected_texture: Texture2D = reference.texture if reference != null and is_instance_valid(reference) else null
	var hit := sprite.texture == expected_texture
	if hit:
		_hits += 1
	else:
		# Any mismatch is a miss; only a real portrait in the wrong lane deals damage.
		if sprite.texture != null:
			portrait_landed.emit()
	_round_resolved += 1
	var is_last_in_round := _round_resolved >= SLOT_NAMES.size()
	_update_progress()

	# Flash the reference green/red; the incoming sprite is freed so it doesn't cover it.
	sprite.queue_free()
	if reference != null and is_instance_valid(reference):
		await flash_object(reference, Color.GREEN if hit else Color.RED, 0.15)
	else:
		# Same wait as a flash, to keep last-in-round ordering.
		await get_tree().create_timer(0.15).timeout

	# Clear references only after the round's flashes finish.
	if is_last_in_round:
		_clear_reference_sprites()
		round_finished.emit()

	# Counted only after flash/free: `finished` may free this Control synchronously.
	_resolved += 1
	_maybe_finish()

func flash_object(object: Sprite3D, flash_color: Color, duration: float) -> void:
	var original_color = object.modulate
	object.modulate = flash_color
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(object):
		object.modulate = original_color

# Unused by the swap minigame.
const SHOCKWAVE_RADIUS := 3.0

# Left/Right move the cursor; E confirms the swap.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var keycode := (event as InputEventKey).keycode
	if keycode == KEY_LEFT:
		_select_slot(-1)
	elif keycode == KEY_RIGHT:
		_select_slot(1)
	elif keycode == KEY_E:
		_confirm_swap()

# Retired rock functions, kept as strings.
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

# Prevents emitting `finished` twice (natural end and request_abort()).
var _did_finish := false

func _maybe_finish() -> void:
	# _resolved counts every lane arrival across all rounds, not rounds.
	var total_portraits: int = PORTRAIT_COUNT * SLOT_NAMES.size()
	if _spawned >= PORTRAIT_COUNT and _resolved >= total_portraits:
		_finish_now(total_portraits)

# Called by battle.gd when the player's HP hits 0 mid-encounter.
func request_abort() -> void:
	_finish_now(PORTRAIT_COUNT * SLOT_NAMES.size())

func _finish_now(total_portraits: int) -> void:
	if _did_finish:
		return
	_did_finish = true
	# Swim back to the anchor so the next encounter's camera frames correctly.
	if is_instance_valid(target_actor):
		var back := target_actor.create_tween()
		back.tween_property(target_actor, "global_position", _player_anchor_position, _current_travel_time * 0.5)
	# Free anything left under stage_root.
	_cleanup_stage_nodes()
	finished.emit(_hits, total_portraits)
