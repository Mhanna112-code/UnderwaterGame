# Captures the exact player route guarded by verify/maze_traversal.gd for
# PR evidence. It begins at the authored DiverEntry, uses the production H
# handler, production Diver movement, production wall collision and
# production currents; only the input is automated so the before/after frames
# are repeatable.
#
# Usage: godot --path . --script tools/shoot_maze_traversal.gd -- /tmp/frames
extends SceneTree

const DT := 1.0 / 60.0
const ENTRANCE_Z := -4.0
const EXIT_Z := 18.0
const MAX_FRAMES_PER_LEG := 900

var frame_dir := "/tmp/pr70-maze-traversal-frames"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		frame_dir = String(args[0])
	call_deferred("_run")

func _capture(index: int) -> void:
	await process_frame
	root.get_texture().get_image().save_png(frame_dir.path_join("frame_%03d.png" % index))

func _press_h(maze: MazeLevel) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_H
	maze._unhandled_input(event)

func _settle_camera(maze: MazeLevel, frames := 18) -> void:
	for _frame in range(frames):
		maze._move_camera(DT)
		await process_frame

func _swim_to_capture(maze: MazeLevel, diver: Diver, target: Vector3, capture_index: int) -> Dictionary:
	for frame in range(MAX_FRAMES_PER_LEG):
		var delta := target - diver.global_position
		delta.y = 0.0
		if delta.length() < 0.55:
			return {"arrived": true, "capture_index": capture_index}
		diver.swim(delta.normalized(), 0.0, DT)
		maze._move_camera(DT)
		await physics_frame
		if frame % 12 == 11:
			await _capture(capture_index)
			capture_index += 1
	return {"arrived": false, "capture_index": capture_index}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(frame_dir)
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	for i in range(10):
		await physics_frame
	var diver := maze._diver
	var wall_6 := maze.get_node("CSGBox3D6") as CSGBox3D
	var wall_7 := maze.get_node("CSGBox3D7") as CSGBox3D
	var entrance_x := (wall_6.global_position.x + wall_7.global_position.x) * 0.5

	# The first frame is a normal player's real starting position. The bottom
	# HUD instruction is intentionally left visible: the reviewer can see that
	# H is the action that opens the route in subsequent frames.
	maze._yaw = PI * 0.5
	maze._pitch = -0.08
	await _settle_camera(maze)
	await _capture(0)
	_press_h(maze)
	await create_timer(1.4).timeout
	for i in range(3):
		await physics_frame
	maze.set_physics_process(false)
	await _settle_camera(maze)
	await _capture(1)

	var first_leg: Dictionary = await _swim_to_capture(maze, diver, Vector3(entrance_x, 0.0, ENTRANCE_Z), 2)
	var capture_index := int(first_leg.capture_index)
	maze._yaw = 0.0
	await _settle_camera(maze)
	await _capture(capture_index)
	capture_index += 1
	var second_leg: Dictionary = {"arrived": false, "capture_index": capture_index}
	if bool(first_leg.arrived):
		second_leg = await _swim_to_capture(maze, diver, Vector3(entrance_x, 0.0, EXIT_Z), capture_index)
	capture_index = int(second_leg.capture_index)
	await _settle_camera(maze)
	await _capture(capture_index)
	print("traversal capture complete at %s: %s" % [diver.global_position, frame_dir])
	quit(0 if bool(first_leg.arrived) and bool(second_leg.arrived) else 1)
