# Captures the exact player route guarded by verify/maze_traversal.gd for
# PR evidence. It uses the production H handler, production Diver movement,
# production wall collision and production currents; only the input is
# automated so the before/after frames are repeatable.
#
# Usage: godot --path . --script tools/shoot_maze_traversal.gd -- /tmp/frames
extends SceneTree

const DT := 1.0 / 60.0
const EXIT_Z := 18.0

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

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(frame_dir)
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
	diver.global_position = Vector3((wall_6.global_position.x + wall_7.global_position.x) * 0.5, 0.0, -4.0)
	diver.velocity = Vector3.ZERO
	maze._yaw = 0.0
	maze._pitch = -0.08
	for i in range(30):
		maze._move_camera(DT)
		await process_frame
	await _capture(0)

	var capture_index := 1
	for frame in range(360):
		diver.swim(Vector3.BACK, 0.0, DT)
		maze._move_camera(DT)
		await physics_frame
		if frame % 8 == 7:
			await _capture(capture_index)
			capture_index += 1
		if diver.global_position.z >= EXIT_Z:
			break
	await _capture(capture_index)
	print("traversal capture complete at %s: %s" % [diver.global_position, frame_dir])
	quit(0 if diver.global_position.z >= EXIT_Z else 1)
