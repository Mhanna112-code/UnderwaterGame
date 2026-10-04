# OPEN-029: invalid Load must not masquerade as New Game or replay the opener.
# Property/negative-path integration through the public chosen-slot signal.
extends SceneTree

const SLOT := 918305
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(SLOT))
	if FileAccess.file_exists(absolute):
		findings.append("OPEN-029 uniquely owned test slot already exists; refusing overwrite")
		_finish()
		return
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var cases: Array = [null, "{\"divers\":", {}, {"divers": "invalid"}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9029
	# Independent oracle: exactly three diver snapshots are required, not a
	# test copy of the loader. Generate counts across the invalid range.
	for _i in range(18):
		var count := rng.randi_range(0, 16)
		if count == 3:
			count = 17
		var snapshots: Array = []
		for _j in range(count):
			snapshots.append({})
		cases.append({"divers": snapshots})
	for malformed in [
		{"divers": [null, {}, {}]},
		{"divers": [{"position": [0, 2]}, {}, {}]},
		{"divers": [{"stats": "invalid"}, {}, {}]},
		{"divers": [{"known_spells": 4}, {}, {}]},
		{"divers": [{}, {}, {}], "active": 99},
		{"divers": [{}, {}, {}], "route_state": "invalid"},
		{"divers": [{}, {}, {}], "active": 1.5},
		{"divers": [{"stats": {"hp": "broken"}}, {}, {}]},
		{"divers": [{}, {}, {}], "pending_world_drops": {"rock_0": "broken"}},
		{"divers": [{}, {}, {}], "route_state": {"prologue_complete": "false"}},
	]:
		cases.append(malformed)
	for case_value in cases:
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
		if case_value != null:
			DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
			var file := FileAccess.open(absolute, FileAccess.WRITE)
			file.store_string(case_value if case_value is String else JSON.stringify(case_value))
			file.close()
		var before := FileAccess.get_file_as_bytes(absolute) if FileAccess.file_exists(absolute) else PackedByteArray()
		world.title_screen.load_game_chosen.emit(SLOT)
		await process_frame
		await process_frame
		_expect(world.title_screen.is_visible_in_tree() and paused, "OPEN-029 invalid Load releases the title instead of retaining an actionable error")
		_expect(world.opening_video == null and get_nodes_in_group("opening_video").is_empty(), "OPEN-029 invalid Load launches the opener")
		_expect(not world.get_node("HUD").visible and not world.route_state.prologue_complete, "OPEN-029 invalid Load creates a false restored session")
		_expect(_has_visible_load_error(world.title_screen), "OPEN-029 invalid Load has no visible explanation")
		var after := FileAccess.get_file_as_bytes(absolute) if FileAccess.file_exists(absolute) else PackedByteArray()
		_expect(after == before, "OPEN-029 invalid Load changed the selected checkpoint")
		if not findings.is_empty():
			print("INVALID LOAD CASE|", case_value)
			break
	if findings.is_empty():
		# Negative load must not poison the next legitimate selection. Legacy
		# and current checkpoints both remain supported; no user slot is used.
		for route in [{}, {"opening_video_seen": true, "prologue_complete": true, "tutorial_complete": false}]:
			var valid := world._serialize_state()
			valid["route_state"] = route
			SaveManager.write_slot(SLOT, valid)
			world.title_screen.load_game_chosen.emit(SLOT)
			await process_frame
			await process_frame
			_expect(world.route_state.prologue_complete and not paused and not world.title_screen.is_visible_in_tree(), "OPEN-029 invalid selection poisons a later legitimate Load")
			world.title_screen.open()
			paused = true
	world.queue_free()
	await process_frame
	paused = false
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	_finish()

func _has_visible_load_error(node: Node) -> bool:
	if node is Label and (node as Label).is_visible_in_tree() and "Could not load" in (node as Label).text:
		return true
	for child in node.get_children():
		if _has_visible_load_error(child):
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("CHECKPOINT LOAD FAILURES: clean" if findings.is_empty() else "CHECKPOINT LOAD FAILURES: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
