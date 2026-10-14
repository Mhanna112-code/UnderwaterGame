# Records a tutorial clip by playing the real game with a scripted "player".
# Run with Godot's movie writer so time advances in fixed steps:
#
#   godot --path . --rendering-driver d3d12 --resolution 1920x1080 \
#     --write-movie <dir>/frame.png --fixed-fps 30 \
#     --script res://tools/record_tutorial_clip.gd -- <clip>
#
# <clip>: popup_grapple | special_shockwave | special_grapple
# Prints "CLIP_RANGE <first> <last>" (movie frame numbers) for the encoder;
# frames outside that range are setup/teardown.
# The grapple rings in popup_grapple exist only in this recording.
extends SceneTree

var clip := "popup_grapple"
var world: World

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		clip = String(args[0])
	call_deferred("_run")

func _frame() -> int:
	return Engine.get_frames_drawn()

func _wait(seconds: float) -> void:
	var frames := int(round(seconds * 30.0))
	for i in frames:
		await process_frame

func _setup_world() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	world.route_state.opening_video_seen = true
	world.route_state.prologue_complete = true
	world.route_state.set_prologue_phase("complete")
	world.route_state.tutorial_complete = true
	world.special_encounter_left = true
	world.ability_popups_seen = true
	world.random_encounters_enabled = false
	for d in world.divers:
		(d as Diver).unlock_ability()
		(d as Diver).stats.fill()
	await process_frame

func _index_of(model: String) -> int:
	for i in world.divers.size():
		if String((world.divers[i] as Diver).model_name) == model:
			return i
	return 0

func _run() -> void:
	match clip:
		"popup_grapple":
			await _popup_grapple()
		"special_shockwave":
			await _special("Prototype_V(1922)")
		"special_grapple":
			await _special("Prototype_1(1910)")
		"save_point_shot":
			await _save_point_shot()
		_:
			push_error("unknown clip " + clip)
	quit()

# --- Musashi grapples two rings in the deep ------------------------------------
func _ring(at: Vector3) -> GrappleAnchor:
	var ring := GrappleAnchor.new()
	ring.ring_inner_radius = 0.45
	ring.ring_outer_radius = 0.7
	world.add_child(ring)
	ring.global_position = at
	# Hoop faces +Z (the way Musashi approaches) so it reads as a ring.
	ring.rotation = Vector3(PI * 0.5, 0, 0)
	return ring

func _ease_aim(to_yaw: float, to_pitch: float, seconds: float) -> void:
	var from_yaw := world.yaw
	var from_pitch := world.pitch
	var frames := int(round(seconds * 30.0))
	for i in frames:
		var t := float(i + 1) / float(frames)
		t = t * t * (3.0 - 2.0 * t)
		world.yaw = lerp_angle(from_yaw, to_yaw, t)
		world.pitch = lerpf(from_pitch, to_pitch, t)
		await process_frame

func _aim_angles(from: Vector3, to: Vector3) -> Vector2:
	var d := (to - from).normalized()
	return Vector2(atan2(d.x, d.z), -asin(clampf(d.y, -1.0, 1.0)))

func _popup_grapple() -> void:
	await _setup_world()
	var musashi := _index_of("Prototype_1(1910)")
	world.active = musashi
	var diver := world.divers[musashi] as Diver
	# Open water at the deep hub, looking north towards the vents (away from
	# Bomb Bot's barrier further east).
	var start := Vector3(90.0, 2.6, 4.0)
	for i in world.divers.size():
		var other := world.divers[i] as Diver
		other.global_position = start + Vector3(-4.0 - i * 1.5, 0, -5.0) if i != musashi else start
		other.velocity = Vector3.ZERO
	var ring_a := _ring(start + Vector3(1.5, 2.4, 9.0))
	var ring_b := _ring(ring_a.global_position + Vector3(-2.5, 2.2, 8.5))
	world.yaw = 0.0
	world.pitch = 0.18
	world.get_node("HUD").visible = false
	world._update_hud()
	await _wait(1.5)   # camera settles behind Musashi
	var first := _frame()
	await _wait(1.2)
	for ring in [ring_a, ring_b]:
		world._start_ability()
		world.get_node("HUD").visible = false
		await _wait(0.5)
		var eye := diver.global_position + Vector3(0, diver.height * 0.4, 0)
		var a := _aim_angles(eye, (ring as Node3D).global_position)
		await _ease_aim(a.x, a.y, 1.1)
		await _wait(0.45)
		world._fire_aimed_ability()
		await _wait(1.6)
		world.pitch = 0.18
		await _wait(0.6)
	await _wait(0.6)
	print("CLIP_RANGE %d %d" % [first, _frame()])

# --- Special encounters: the real battle, with a bot playing the minigame ----
func _key_event(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)

# Clicks through the diver's own turn (Attack -> first move -> first target).
func _play_party_turn(battle: Battle) -> void:
	if battle.main_menu.visible and not battle.attack_btn.disabled:
		battle.attack_btn.pressed.emit()
	elif battle.move_menu.visible:
		for b in battle.move_buttons:
			if not (b as Button).disabled:
				(b as Button).pressed.emit()
				break
	elif battle.target_menu.visible:
		for c in battle.target_menu.get_children():
			if c is Button and not (c as Button).disabled and (c as Button).visible and c != battle.target_back_btn:
				(c as Button).pressed.emit()
				break

func _special(model: String) -> void:
	await _setup_world()
	var idx := _index_of(model)
	world.active = idx
	var diver := world.divers[idx] as Diver
	diver.global_position = Vector3(90.0, 2.6, 4.0)
	world.get_node("HUD").visible = false
	world._start_battle("attack_up", false, "angler", [diver], true, false)
	var battle := world.battle
	var minigame: Control = null
	var turn_clicks := 0
	while minigame == null:
		await _wait(0.4)
		for c in battle.get_children():
			if c is RockDodgeMinigame or c is GrappleInterceptMinigame:
				minigame = c
		if minigame == null and turn_clicks < 40:
			_play_party_turn(battle)
			turn_clicks += 1
	# The battle log's "...hurls rocks / vortex" line comes ~3 s before the
	# minigame itself; include it.
	var first := maxi(0, _frame() - 105)
	if minigame is RockDodgeMinigame:
		await _bot_rock_dodge(minigame as RockDodgeMinigame)
	else:
		await _bot_grapple(minigame as GrappleInterceptMinigame)
	await _wait(3.0)   # result line and the enemy's follow-up
	print("CLIP_RANGE %d %d" % [first, _frame()])

# Bucky: line up with each wave's rock and shockwave it - except two waves
# where he stands in the rock's lane and lets it hit him.
func _bot_rock_dodge(mg: RockDodgeMinigame) -> void:
	var fail_waves := [3, 7]
	var wave_no := 0
	var seen: Dictionary = {}
	var held := KEY_NONE
	while is_instance_valid(mg) and not mg._did_finish:
		await process_frame
		if not is_instance_valid(mg):
			break
		var wave: Dictionary = mg._current_wave
		if wave.is_empty():
			continue
		var rock_lane := ""
		for lane in wave:
			if String(wave[lane].kind) == "rock":
				rock_lane = String(lane)
		var wave_id: int = (wave[rock_lane].node as Object).get_instance_id() if rock_lane != "" else 0
		if not seen.has(wave_id):
			seen[wave_id] = true
			wave_no += 1
		var want := KEY_NONE
		if rock_lane == "left":
			want = KEY_LEFT
		elif rock_lane == "right":
			want = KEY_RIGHT
		if want != held:
			if held != KEY_NONE:
				_key_event(held, false)
			if want != KEY_NONE:
				_key_event(want, true)
			held = want
		var entry: Dictionary = wave.get(rock_lane, {})
		if entry.is_empty() or bool(entry.broken) or fail_waves.has(wave_no):
			continue
		var node := entry.node as Node3D
		if is_instance_valid(node) and mg.target_actor.global_position.distance_to(node.global_position) <= RockDodgeMinigame.HIT_RADIUS * 0.85:
			_key_event(KEY_E, true)
			await process_frame
			_key_event(KEY_E, false)
	if held != KEY_NONE:
		_key_event(held, false)

# Musashi: sweep the crosshair onto each safe-colour sphere and grapple it.
func _bot_grapple(mg: GrappleInterceptMinigame) -> void:
	const TURN_SPEED := 0.9   # radians / second of crosshair travel - a readable, human pace
	var last_wave_id := 0
	while is_instance_valid(mg) and not mg._did_finish:
		await process_frame
		if not is_instance_valid(mg) or mg._did_finish:
			break
		if not mg._grapple_controls_active or not mg._vortex_active or mg._vortex_spheres.is_empty():
			continue
		# A new wave: give the viewer time to read the "GRAPPLE <COLOUR>" callout.
		var wave_id: int = (mg._vortex_spheres[0].node as Object).get_instance_id() if is_instance_valid(mg._vortex_spheres[0].node) else last_wave_id
		if wave_id != last_wave_id:
			last_wave_id = wave_id
			await _wait(0.9)
			continue
		var target: Node3D = null
		var best := INF
		for entry in mg._vortex_spheres:
			if bool(entry.is_yellow) != mg._vortex_safe_is_yellow:
				continue
			var node := entry.node as Node3D
			if not is_instance_valid(node) or not node.visible:
				continue
			var d := mg.stage_camera.global_position.distance_to(node.global_position)
			if d < best:
				best = d
				target = node
		if target == null:
			continue
		var dir := (target.global_position - mg.stage_camera.global_position).normalized()
		var base: Vector3 = mg._base_forward
		var want_yaw := wrapf(atan2(dir.x, dir.z) - atan2(base.x, base.z), -PI, PI)
		var yawed := base.rotated(Vector3.UP, want_yaw)
		var want_pitch := asin(clampf(dir.y, -1.0, 1.0)) - asin(clampf(yawed.y, -1.0, 1.0))
		want_yaw = clampf(want_yaw, -mg.MAX_YAW, mg.MAX_YAW)
		want_pitch = clampf(want_pitch, -mg.MAX_PITCH, mg.MAX_PITCH)
		var step := TURN_SPEED / 30.0
		mg._yaw = move_toward(mg._yaw, want_yaw, step)
		mg._pitch = move_toward(mg._pitch, want_pitch, step)
		mg._update_camera()
		var aim := -mg.stage_camera.global_transform.basis.z
		if aim.angle_to(dir) < deg_to_rad(1.2):
			await _wait(0.12)
			mg._grapple()
			await _wait(0.55)

# --- Still image for the "Saving" modal: a diver beside a save point ---------
# Run without --write-movie:  -- save_point_shot [out.png]
func _save_point_shot() -> void:
	await _setup_world()
	var sp := world._save_points[0] as Node3D
	world.active = 0
	var diver := world.divers[0] as Diver
	for i in world.divers.size():
		(world.divers[i] as Diver).global_position = sp.global_position + Vector3(14.0 + i * 1.5, 0, 6.0)
	# Beside the save point, camera looking back along the open lane (-X).
	diver.global_position = sp.global_position + Vector3(1.0, 0.0, 1.9)
	diver.velocity = Vector3.ZERO
	world.yaw = -PI * 0.5 + 0.45
	world.pitch = 0.32
	world.get_node("HUD").visible = false
	await _wait(2.5)
	world._active_cursor.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var out := "res://media/tutorials/saving_save_point.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out = String(args[1])
	root.get_texture().get_image().save_png(out)
	print("SHOT ", out)
