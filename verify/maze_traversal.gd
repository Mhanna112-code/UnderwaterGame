extends SceneTree

# This is the actual player-facing route in Marc's screenshot: begin at the
# authored DiverEntry, use the documented H action, enter the doorway from
# the west, then swim north through the mouth formed by CSGBox3D6/7. It
# deliberately drives the production Diver (CharacterBody3D) instead of a
# ray or point query, so wall collision and every relocated current
# participate in the result.

const DT := 1.0 / 60.0
const ENTRANCE_Z := -4.0
const EXIT_Z := 18.0
const MAX_FRAMES_PER_LEG := 900

func _initialize() -> void:
	call_deferred("_run")

func _press_h(maze: MazeLevel) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_H
	maze._unhandled_input(event)

func _swim_to(diver: Diver, target: Vector3, tracked_range: Array[float]) -> bool:
	for _frame in range(MAX_FRAMES_PER_LEG):
		var delta := target - diver.global_position
		delta.y = 0.0
		if delta.length() < 0.55:
			return true
		diver.swim(delta.normalized(), 0.0, DT)
		await physics_frame
		if diver.global_position.z >= -0.5:
			tracked_range[0] = minf(tracked_range[0], diver.global_position.x)
			tracked_range[1] = maxf(tracked_range[1], diver.global_position.x)
	return false

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	for i in range(10):
		await physics_frame
	_press_h(maze)
	await create_timer(1.4).timeout
	for i in range(3):
		await physics_frame
	maze.set_physics_process(false)

	var diver := maze._diver
	var wall_6 := maze.get_node("CSGBox3D6") as CSGBox3D
	var wall_7 := maze.get_node("CSGBox3D7") as CSGBox3D
	var entrance_x := (wall_6.global_position.x + wall_7.global_position.x) * 0.5

	var findings: Array[String] = []
	var current_1_open: WaterCurrent = maze._currents_by_corridor.get(maze.get_node("WindCorridor1"), null)
	var current_2_open: WaterCurrent = maze._currents_by_corridor.get(maze.get_node("WindCorridor2"), null)
	var current_3_open: WaterCurrent = maze._currents_by_corridor.get(maze.get_node("WindCorridor3"), null)
	if current_1_open != null or current_2_open != null:
		findings.append("opening H leaves a current in the west-entry corridor instead of clearing the approach")
	if current_3_open == null or current_3_open.orientation != WaterCurrent.direction_to_vector(WaterCurrent.Direction.POSITIVE_Z):
		findings.append("opening H does not place a northbound current in the CSGBox3D6/7 passage")

	# No test-written position is used here. The real standalone player starts
	# at DiverEntry, crosses the west-entry area, then follows the same
	# northbound passage the reviewer sees after H.
	var x_range: Array[float] = [INF, -INF]
	var reached_mouth := await _swim_to(diver, Vector3(entrance_x, 0.0, ENTRANCE_Z), x_range)
	if not reached_mouth:
		findings.append("H leaves the reported passage unreachable from DiverEntry: player stopped at %s before the CSGBox3D6/7 mouth" % diver.global_position)
	var reached_exit := false
	if reached_mouth:
		reached_exit = await _swim_to(diver, Vector3(entrance_x, 0.0, EXIT_Z), x_range)
	if not reached_exit:
		findings.append("H seals the visible CSGBox3D6/7 entrance: player stopped at %s instead of reaching z >= %.1f" % [diver.global_position, EXIT_Z])
	var safe_min_x := minf(wall_6.global_position.x, wall_7.global_position.x) + diver.radius
	var safe_max_x := maxf(wall_6.global_position.x, wall_7.global_position.x) - diver.radius
	if x_range[0] < safe_min_x or x_range[1] > safe_max_x:
		findings.append("player escaped the two-wall corridor sideways rather than traversing it")

	_press_h(maze)
	await create_timer(1.4).timeout
	var current_1: WaterCurrent = maze._currents_by_corridor.get(maze.get_node("WindCorridor1"), null)
	var current_2: WaterCurrent = maze._currents_by_corridor.get(maze.get_node("WindCorridor2"), null)
	if current_1 == null or current_1.orientation != WaterCurrent.direction_to_vector(WaterCurrent.Direction.NEGATIVE_Z):
		findings.append("closing H does not restore WindCorridor1's authored NEGATIVE_Z current")
	if current_2 == null or current_2.orientation != WaterCurrent.direction_to_vector(WaterCurrent.Direction.NEGATIVE_X):
		findings.append("closing H does not restore WindCorridor2's authored NEGATIVE_X current")
	if maze._currents_by_corridor.has(maze.get_node("WindCorridor3")):
		findings.append("closing H leaves a stale current in WindCorridor3")

	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE TRAVERSAL: clean" if findings.is_empty() else "MAZE TRAVERSAL: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
