# Mech Pilot's shockwave minigame, played on the enemy's turn.
# Three lanes run from enemy to player; each wave sends one breakable rock and two
# walls. Hold Left/Right to line up with the rock, press E to shockwave it.
# battle.gd calls run(), awaits `finished`, and owns all damage logic.
class_name RockDodgeMinigame
extends Control

signal finished(hits: int, total: int)

# Emitted the instant an unbroken rock or wall reaches the player, so battle.gd applies damage live.
signal rock_landed

const WAVE_COUNT := 10
const MIN_WAVE_GAP := 1
const MAX_WAVE_GAP := 2.5
const TRAVEL_TIME := 0.64

# Waves fire in random-size clusters; the gap above is between clusters. Batch is capped to waves remaining.
const MIN_WAVE_BATCH := 2
const MAX_WAVE_BATCH := 8

const LANES: Array[String] = ["left", "middle", "right"]
const LANE_SIGN := {"left": -1.0, "middle": 0.0, "right": 1.0}

# Must exceed HIT_RADIUS so one lane can't reach a neighboring lane's object.
const LANE_SPACING := 2.4

# Shared radius for both breaking a rock and being hit.
const HIT_RADIUS := 1.8

var thrower_position: Vector3
var stage_root: SubViewport
var target_actor: Node3D

var _hits := 0
var _resolved := 0

# Shared sideways axis for both enemy and player lane positions; must be the same
# vector for both sides so lanes run straight.
var _right := Vector3.RIGHT
var _player_base_pos: Vector3

# Derived from held input each frame: holding leans into a lane, releasing snaps back to middle.
var _player_lane := 1   # 0=left, 1=middle, 2=right
const MOVE_TIME := 0.18
var _move_tween: Tween

# Only a successful break starts the cooldown; a miss doesn't.
const SHOCKWAVE_COOLDOWN_MS := 350
var _shockwave_ready_at := 0

# lane -> {node, kind ("rock"/"wall"), landing_pos, broken, tween}. Empty between waves.
var _current_wave: Dictionary = {}

# Prevents emitting `finished` twice (normal end and request_abort()).
var _did_finish := false

func _ready() -> void:
	# Parent may be a CanvasLayer, so size to the viewport manually.
	if get_parent() is Control:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # only rocks/labels catch clicks


func run() -> void:
	if target_actor != null:
		_player_base_pos = target_actor.global_position
	# Horizontal-only so the enemy's height offset doesn't tilt the lane axis.
	var forward := _player_base_pos - thrower_position
	forward.y = 0.0
	if forward.length() > 0.001:
		forward = forward.normalized()
		# UP x forward matches the dodge camera's screen-right.
		_right = Vector3.UP.cross(forward).normalized()

	_wave_loop()

# No-op; kept so existing call sites don't need edits.
func _update_progress() -> void:
	pass

# Poll held keys each frame; neither or both held resolves to middle.
func _process(_delta: float) -> void:
	var desired := 1   # neither/both held -> middle
	if Input.is_key_pressed(KEY_LEFT) and not Input.is_key_pressed(KEY_RIGHT):
		desired = 0
	elif Input.is_key_pressed(KEY_RIGHT) and not Input.is_key_pressed(KEY_LEFT):
		desired = 2
	if desired != _player_lane:
		_snap_to_lane(desired)

# Kill any running move tween so quick inputs don't stack.
func _snap_to_lane(index: int) -> void:
	if target_actor == null:
		return
	_player_lane = index
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	var target: Vector3 = _player_base_pos + _right * LANE_SIGN[LANES[_player_lane]] * LANE_SPACING
	_move_tween = target_actor.create_tween()
	_move_tween.tween_property(target_actor, "global_position", target, MOVE_TIME)

# Random gaps so the player reacts rather than counting a rhythm. Stops on _did_finish (early abort).
func _wave_loop() -> void:
	while _resolved < WAVE_COUNT and not _did_finish:
		await get_tree().create_timer(randf_range(MIN_WAVE_GAP, MAX_WAVE_GAP)).timeout
		if not is_instance_valid(self) or _did_finish:
			return
		var remaining := WAVE_COUNT - _resolved
		var batch_size: int = mini(randi_range(MIN_WAVE_BATCH, MAX_WAVE_BATCH), remaining)
		for i in range(batch_size):
			await _run_one_wave()
			if not is_instance_valid(self) or _resolved >= WAVE_COUNT or _did_finish:
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
	_shockwave_used_this_wave = false
	# All lanes share TRAVEL_TIME, so one timer covers the wave; broken rocks are skipped.
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
		# Swim back to the starting position.
		if _move_tween != null and _move_tween.is_valid():
			_move_tween.kill()
		var back := target_actor.create_tween()
		back.tween_property(target_actor, "global_position", _player_base_pos, MOVE_TIME)
	finished.emit(_hits, WAVE_COUNT)

# Called by battle.gd when the player's HP hits 0 mid-encounter.
func request_abort() -> void:
	_finish()

func _spawn_rock(at: Vector3) -> MeshInstance3D:
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	rock.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.22, 0.14)   # same brown as cracked_wall.gd's rocks
	rock.material_override = mat
	stage_root.add_child(rock)
	rock.global_position = at
	return rock

# Visually distinct from the rock so safe lanes are readable from afar.
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

# Only rocks can be broken, checked against their live position. One shockwave per
# wave: a press during a wave is spent whether it hits or not.
var _shockwave_used_this_wave := false

func _try_shockwave() -> void:
	if _current_wave.is_empty() or _shockwave_used_this_wave:
		return
	_shockwave_used_this_wave = true
	if target_actor is Diver:
		(target_actor as Diver)._shockwave_vfx()
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
			_shockwave_ready_at = 0
		return   # at most one rock per wave

func _break_rock(lane: String, entry: Dictionary) -> void:
	entry.broken = true
	_current_wave[lane] = entry
	var travel_tw: Tween = entry.tween
	if travel_tw != null and travel_tw.is_valid():
		travel_tw.kill()
	_hits += 1
	_flash_and_free(entry.node)

# Bound to the node, not this Control, so the flash survives this minigame being freed.
func _flash_and_free(node: MeshInstance3D) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 1.6, 0.12)
	tw.tween_callback(node.queue_free)

# Red emission flash for a hit on the player. Node-bound like _flash_and_free().
func _flash_hit_and_free(node: MeshInstance3D) -> void:
	var mat := node.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	var tw := node.create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 3.0, 0.15)
	tw.tween_callback(node.queue_free)
