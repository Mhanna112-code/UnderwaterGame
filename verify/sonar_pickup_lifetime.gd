extends SceneTree
## SV-6: collecting/loading the lens must not leave an infinite freed-target Tween.
## Placement is a lifecycle fixture, not an earned campaign route or balance test.
var findings: Array[String] = []
var cases := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for selected in 3:
		await _collect_and_load(selected)
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("SONAR PICKUP LIFETIME: %s|cases=%d" % ["clean" if findings.is_empty() else "failed", cases])
	quit(0 if findings.is_empty() else 1)

func _collect_and_load(selected: int) -> void:
	var maze := _new_maze()
	await _frames(8)
	for i in selected:
		await _key(KEY_TAB)
	_expect(maze.active == selected, "SV-6 real Tab did not select the collection actor")
	var pickup := maze.get_node_or_null("SonarVisionPickup") as Area3D
	_expect(pickup != null and not maze.inventory.has("sonar_vision"), "SV-6 fresh maze omitted the unearned lens")
	if pickup == null:
		maze.queue_free()
		await process_frame
		return
	var spot := pickup.global_position
	# Enter the real Area3D with one real actor; never call its callback.
	maze.divers[selected].global_position = spot
	maze.divers[selected].velocity = Vector3.ZERO
	await _frames(8)
	_expect(maze.inventory.get("sonar_vision", 0) == 1 and maze.get_node_or_null("SonarVisionPickup") == null,
		"SV-6 actual lens contact failed to award/remove exactly one pickup")
	print("SONAR PICKUP COLLECTED|actor=", selected)
	# More than a full spin cycle: the runner rejects any engine error even
	# if the semantic checks below succeed and this script exits zero.
	await _frames(150)
	_expect(maze.inventory.get("sonar_vision", 0) == 1, "SV-6 a removed lens awarded a duplicate item")
	cases += 1
	var session := CampaignSession.new()
	session.route_state = RouteState.new()
	session.route_state.prologue_complete = true
	session.random_encounters_enabled = false
	session.capture_party(maze.divers, selected)
	session.inventory = maze.inventory.duplicate()
	session.maze_snapshot = maze.campaign_snapshot()
	var decoded := CampaignCheckpoint.decode(JSON.parse_string(JSON.stringify(CampaignCheckpoint.encode(session))))
	_expect(decoded != null, "SV-6 collected lens session rejected by the actual checkpoint decoder")
	maze.queue_free()
	await process_frame
	if decoded == null:
		return
	SceneHandoff.campaign_session = decoded
	maze = _new_maze()
	await _frames(150)
	_expect(maze.active == selected and maze.inventory.get("sonar_vision", 0) == 1
		and maze.get_node_or_null("SonarVisionPickup") == null,
		"SV-6 cold restored lens ownership duplicated or resurrected the pickup")
	for i in 3:
		var member := maze.divers[i].campaign_member_state()
		_expect(member.stats == decoded.party[i].stats, "SV-6 lens lifecycle changed restored party resources/stats")
	print("SONAR PICKUP RESTORED|actor=", selected)
	cases += 1
	maze.queue_free()
	await process_frame

func _new_maze() -> MazeLevel:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	maze.random_encounters_enabled = false
	maze.room_encounters_enabled = false
	root.add_child(maze)
	current_scene = maze
	return maze

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
