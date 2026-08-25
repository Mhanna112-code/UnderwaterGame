# Capture the real cold-launch surface for title-screen layout review.
# Usage: godot --path . --script tools/shoot_title.gd -- <out.png>
extends SceneTree

var out_png := "/tmp/title-screen.png"
var frames := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_png = String(args[0])
	root.add_child((load("res://game/world.tscn") as PackedScene).instantiate())

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 6:
		return false
	root.get_texture().get_image().save_png(out_png)
	print("title shot  %s" % out_png)
	return true
