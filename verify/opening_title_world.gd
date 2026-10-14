# TITLE-002: actual movie/title with real W held; fresh owned slot only.
extends SceneTree

var findings: Array[String] = []
var slot := 1918312

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	slot += OS.get_process_id()
	if SaveManager.slot_exists(slot) or FileAccess.file_exists(SaveManager.slot_path(slot) + ".pending"):
		print("FINDING TITLE fixture slot exists; refusing overwrite")
		quit(1)
		return
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(slot)
	var diver := world.divers[world.active] as Diver
	var origin := diver.position
	var deadline := Time.get_ticks_msec() + 45000
	while world.route_state.prologue_phase != "opening_handoff" and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(world.route_state.prologue_phase == "opening_handoff", "TITLE-001 World did not opt into actual EOF handoff")
	if world.route_state.prologue_phase == "opening_handoff":
		_key(KEY_W, true)
		await create_timer(1.1).timeout
		_expect(paused and not world.battling and diver.position.is_equal_approx(origin), "TITLE-002 world moves/fights beneath title")
		_key(KEY_W, false)
		var revealed_camera := world.cam.global_transform
		while world.route_state.prologue_phase == "opening_handoff" and Time.get_ticks_msec() < deadline:
			await process_frame
		# The title hands straight to the Cordys introduction: no free swim.
		_expect(world.get_node("HUD").visible, "TITLE-002 title does not restore the visible HUD")
		_expect(world.route_state.prologue_phase == "octopus_introduction" and get_first_node_in_group("prologue_cinematic") != null,
			"TITLE-002 title did not hand to the Cordys introduction (phase %s)" % world.route_state.prologue_phase)
		_expect(world.route_state.opening_video_seen and not world.route_state.prologue_complete, "TITLE-006 title corrupts durable milestones")
		for frame in range(3):
			await physics_frame
		_expect(revealed_camera.origin.distance_to(world.cam.global_position) < 0.03 and revealed_camera.basis.is_equal_approx(world.cam.global_basis), "TITLE-007 camera zooms/reorients after the title reveal")
		_key(KEY_W, true)
		await create_timer(1.0).timeout
		_key(KEY_W, false)
		_expect(not world.battling and diver.position.is_equal_approx(origin), "TITLE-002 swimming under the Cordys introduction moves/fights")
		var movie := get_first_node_in_group("prologue_cinematic")
		if movie != null:
			movie.call("pause_introduction_for_test")
			await process_frame
		_expect(world.battling and world.battle != null and world.route_state.encounter_source == "prologue_octopus", "TITLE-002 introduction starts wrong encounter")
		if world.battle != null:
			_expect(world.battle.enemies.size() == 1 and String(world.battle.enemies[0].display_name) == "Cordys", "TITLE-002 prologue battle is not Cordys alone")
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	await process_frame
	for suffix in ["", ".pending"]:
		var path: String = ProjectSettings.globalize_path(SaveManager.slot_path(slot)) + String(suffix)
		if FileAccess.file_exists(path):
			_expect(DirAccess.remove_absolute(path) == OK, "TITLE fixture could not remove its newly owned slot")
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING TITLE WORLD: clean" if findings.is_empty() else "OPENING TITLE WORLD: failed")
	quit(0 if findings.is_empty() else 1)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
