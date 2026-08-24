# Captures the hallway before and after its programmatic rotation from the
# same top-down camera. This is the visual counterpart to verify/maze.gd's
# transform invariants.
# Usage: godot --path . --script tools/shoot_maze.gd -- /tmp/maze-before.png /tmp/maze-after.png
extends SceneTree

var before_path := "/tmp/maze-before.png"
var after_path := "/tmp/maze-after.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		before_path = String(args[0])
	if args.size() > 1:
		after_path = String(args[1])
	call_deferred("_run")

func _capture(path: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("shot       %s" % path)

func _color(wall: CSGBox3D, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall.material = material

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	await process_frame
	var camera := maze.get_node("Camera3D") as Camera3D
	_color(maze.get_node("CurrentWall1"), Color(1.0, 0.25, 0.25))
	_color(maze.get_node("CSGBox3D"), Color(1.0, 0.75, 0.15))
	_color(maze.get_node("CurrentWall2"), Color(0.2, 0.85, 1.0))
	_color(maze.get_node("CurrentWall3"), Color(0.3, 1.0, 0.35))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 42.0
	camera.look_at_from_position(Vector3(5.0, 45.0, 0.0), Vector3(5.0, 0.0, 0.0), Vector3.FORWARD)
	await _capture(before_path)
	maze._rotate_hallway_1_2()
	await create_timer(1.4).timeout
	await _capture(after_path)
	quit()
