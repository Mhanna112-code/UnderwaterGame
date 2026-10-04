# Captures the reviewable maze navigation HUD at the same narrow 653px width
# used by the browser playtest.  It drives the production M/H handlers rather
# than altering MazeMiniMap state directly, so the frames show exactly the
# closed and opened route a reviewer receives.
#
# Usage:
#   godot --path . --resolution 653x980 --script tools/shoot_maze_minimap.gd -- \
#     docs/evidence/maze-minimap-closed.png docs/evidence/maze-minimap-open.png
extends SceneTree

var closed_path := "docs/evidence/maze-minimap-closed.png"
var open_path := "docs/evidence/maze-minimap-open.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		closed_path = String(args[0])
	if args.size() > 1:
		open_path = String(args[1])
	call_deferred("_run")

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event

func _capture(path: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("maze minimap shot %s" % path)

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	for _frame in range(8):
		await process_frame
	var minimap := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	# Production input opens the same panel a browser player uses.
	minimap._unhandled_input(_key(KEY_M))
	await process_frame
	if not minimap.main_map.visible:
		push_error("M did not open the maze map for the evidence capture")
		quit(1)
		return
	await _capture(closed_path)

	# Production H rotates both walls and relocates the active current.  Wait
	# through the real animation before capturing the map's settled state.
	maze._unhandled_input(_key(KEY_H))
	await create_timer(1.4).timeout
	if minimap.selectedCurrentCorridor == null or minimap.selectedCurrentCorridor.name != "WindCorridor3":
		push_error("H did not leave the map focused on the northbound WindCorridor3 flow")
		quit(1)
		return
	await _capture(open_path)
	print("MAZE MINIMAP EVIDENCE: clean")
	quit()
