extends SceneTree

# This is the actual player-facing route in Marc's screenshot: after the
# documented H action, swim north from the mouth formed by CSGBox3D6/7.
# It deliberately drives the production Diver (CharacterBody3D) instead of
# a ray or point query, so wall collision and the relocated current both
# participate in the result.

const DT := 1.0 / 60.0
const ENTRANCE_Z := -4.0
const EXIT_Z := 18.0
const MAX_FRAMES := 480

func _initialize() -> void:
	call_deferred("_run")

func _press_h(maze: MazeLevel) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_H
	maze._unhandled_input(event)

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
	diver.global_position = Vector3(entrance_x, 0.0, ENTRANCE_Z)
	diver.velocity = Vector3.ZERO

	var findings: Array[String] = []
	var min_x := diver.global_position.x
	var max_x := diver.global_position.x
	for frame in range(MAX_FRAMES):
		# Vector3.BACK is world +Z, the direction the visible corridor runs.
		diver.swim(Vector3.BACK, 0.0, DT)
		await physics_frame
		min_x = minf(min_x, diver.global_position.x)
		max_x = maxf(max_x, diver.global_position.x)
		if diver.global_position.z >= EXIT_Z:
			break
	if diver.global_position.z < EXIT_Z:
		findings.append("H seals the visible CSGBox3D6/7 entrance: player stopped at %s instead of reaching z >= %.1f" % [diver.global_position, EXIT_Z])
	var safe_min_x := minf(wall_6.global_position.x, wall_7.global_position.x) + diver.radius
	var safe_max_x := maxf(wall_6.global_position.x, wall_7.global_position.x) - diver.radius
	if min_x < safe_min_x or max_x > safe_max_x:
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
