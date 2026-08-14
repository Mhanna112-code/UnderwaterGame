# Screenshot whatever scene it is pointed at, after N frames of settle.
# Usage: godot --path ~/underwatergame --script tools/shoot_scene.gd -- <scene> <out.png> [frames]
extends SceneTree
var out_png := "/tmp/scene.png"
var settle := 8
var frames := 0
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var scn := String(a[0]) if a.size() > 0 else "res://game/lineup.tscn"
	out_png = String(a[1]) if a.size() > 1 else out_png
	if a.size() > 2:
		settle = int(a[2])
	root.add_child((load(scn) as PackedScene).instantiate())
func _process(_d: float) -> bool:
	frames += 1
	if frames < settle:
		return false
	root.get_texture().get_image().save_png(out_png)
	print("shot       %s" % out_png)
	return true
