# OPEN-041/042: checkpoint round-trip must preserve later Q/R choices,
# migrate missing defaults, reject bad booleans and keep empty-O2 Sonar honest.
extends SceneTree
const SLOT := 918310
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if SaveManager.slot_exists(SLOT):
		findings.append("OPEN-041 owned test slot already exists; refusing overwrite")
		quit(1)
		return
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var baseline := world._serialize_state() # checkpoint fixture only
	baseline.route_state = {"opening_video_seen": true, "prologue_complete": true, "tutorial_complete": true}
	baseline.random_encounters_enabled = true
	baseline.divers[0].sonar_active = true
	for sonar_on in [false, true]:
		for encounters_on in [false, true]:
			for chosen_diver in [0, 1]:
				SaveManager.write_slot(SLOT, baseline)
				world.title_screen.load_game_chosen.emit(SLOT)
				await process_frame
				await process_frame
				if not sonar_on:
					await _key(KEY_Q)
				if not encounters_on:
					await _key(KEY_R)
				if chosen_diver == 1:
					await _key(KEY_TAB)
				# Production save request, not hand-authored On/Off snapshots.
				world.save_point_menu.save_requested.emit(world.divers[world.active], SLOT)
				await process_frame
				var saved := SaveManager.read_slot(SLOT)
				_expect(saved.get("random_encounters_enabled") == encounters_on and saved.divers[0].get("sonar_active") == sonar_on, "OPEN-041 save loses manual Q/R choices")
				# Deliberately invert live values; Load must use the actual checkpoint.
				world.random_encounters_enabled = not encounters_on
				(world.divers[0] as Diver).sonar_active = not sonar_on
				world.title_screen.load_game_chosen.emit(SLOT)
				await process_frame
				await process_frame
				_expect(world.random_encounters_enabled == encounters_on and (world.divers[0] as Diver).sonar_active == sonar_on, "OPEN-041 Load replaces saved preference with a default")
				_expect(world.minimap._sonar_currently_active() == sonar_on and world.active == chosen_diver, "OPEN-041 Sonar ownership fails after switching diver/Load")
				print("EXPLORATION ROUND TRIP|sonar=", sonar_on, "|encounters=", encounters_on, "|active=", world.active)
	# Old completed saves get the new defaults. An unfinished opener stays quiet.
	for route in [{}, {"opening_video_seen": true, "prologue_complete": true, "tutorial_complete": false}, {"opening_video_seen": true, "prologue_complete": false, "tutorial_complete": false}]:
		var legacy := baseline.duplicate(true)
		legacy.route_state = route
		legacy.erase("random_encounters_enabled")
		for snap in legacy.divers:
			snap.erase("sonar_active")
		SaveManager.write_slot(SLOT, legacy)
		world.title_screen.load_game_chosen.emit(SLOT)
		await process_frame
		await process_frame
		_expect(world.random_encounters_enabled, "OPEN-041 legacy Load disables encounters")
		_expect((world.divers[0] as Diver).sonar_active == world.route_state.prologue_complete, "OPEN-041 legacy Sonar default disagrees with opening milestone")
	# Invalid types must be rejected before changing live state.
	for invalid in ["false", 0, [], null]:
		for field in ["sonar_active", "random_encounters_enabled"]:
			var malformed := baseline.duplicate(true)
			if field == "sonar_active":
				malformed.divers[0][field] = invalid
			else:
				malformed[field] = invalid
			SaveManager.write_slot(SLOT, malformed)
			var before := world._serialize_state()
			world.title_screen.load_game_chosen.emit(SLOT)
			await process_frame
			await process_frame
			_expect(world._serialize_state() == before and paused and world.title_screen.is_visible_in_tree(), "OPEN-042 invalid setting partially restores gameplay")
	var empty := baseline.duplicate(true)
	empty.divers[0].stats.oxygen = 0
	SaveManager.write_slot(SLOT, empty)
	world.title_screen.load_game_chosen.emit(SLOT)
	await process_frame
	await process_frame
	_expect(not (world.divers[0] as Diver).sonar_active and not world.minimap._sonar_currently_active(), "OPEN-042 empty oxygen leaves inert Sonar On")
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for suffix in ["", ".pending"]:
		var path: String = ProjectSettings.globalize_path(SaveManager.slot_path(SLOT)) + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING EXPLORATION DEFAULTS: clean" if findings.is_empty() else "OPENING EXPLORATION DEFAULTS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
