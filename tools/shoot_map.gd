# The whole map from above, so the layout can be judged as a layout.
extends SceneTree
var frames := 0
var out := "/tmp/map.png"
var cam: Camera3D
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = String(a[0])
	root.add_child((load("res://game/world.tscn") as PackedScene).instantiate())
	cam = Camera3D.new()
	root.add_child(cam)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 1:
		cam.position = Vector3(6, 78, -22)
		cam.look_at(Vector3(6, 0, -22.001), Vector3.FORWARD)
		cam.fov = 70.0
		cam.far = 400.0
		cam.current = true
		return false
	if frames < 10: return false
	root.get_texture().get_image().save_png(out)
	print("shot %s" % out)
	return true
