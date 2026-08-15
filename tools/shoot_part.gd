# Look at the salvage part on its own, close up, before it goes in the game.
extends SceneTree
const PartScript := preload("res://game/salvage_part.gd")
var frames := 0
var out := "/tmp/part.png"
var cam: Camera3D
var angle := 0.0
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = String(a[0])
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.13, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.5, 0.58)
	e.ambient_light_energy = 1.0
	env.environment = e
	root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 35, 0)
	key.light_energy = 2.2
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-8, -140, 0)
	rim.light_color = Color(0.6, 0.85, 1.0)
	rim.light_energy = 1.1
	root.add_child(rim)
	var p := PartScript.new()
	root.add_child(p)
	cam = Camera3D.new()
	cam.fov = 42.0
	root.add_child(cam)
func _process(_d: float) -> bool:
	frames += 1
	# aim only once the camera is in the tree: look_at on a node with no
	# global transform silently points at nothing
	if frames == 1:
		var a := OS.get_cmdline_user_args()
		angle = float(a[1]) if a.size() > 1 else 0.9
		var dist := float(a[2]) if a.size() > 2 else 1.9
		cam.position = Vector3(cos(angle) * dist, 0.62, sin(angle) * dist)
		cam.look_at(Vector3(0, 0.05, 0), Vector3.UP)
		return false
	if frames < 8: return false
	root.get_texture().get_image().save_png(out)
	print("shot %s" % out)
	return true
