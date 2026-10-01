# Render the delivered Door FBX through the actual KeyDoor component, before
# and after its authored `Open` blend shape.  This deliberately is not a
# substitute for the route or interaction tests: it is visual evidence that
# the model's real mesh moves in the expected component at a reviewable scale.
#
# Usage:
#   godot --headless --path . --script tools/shoot_key_door.gd -- before.png open.png
extends SceneTree

var before_path := "/tmp/key-door-locked.png"
var open_path := "/tmp/key-door-open.png"
var stage := Node3D.new()
var door: KeyDoor
var camera: Camera3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		before_path = String(args[0])
	if args.size() > 1:
		open_path = String(args[1])
	root.add_child(stage)
	_build_stage()
	call_deferred("_run")

func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("071d26")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8ecfe8")
	settings.ambient_light_energy = 0.85
	environment.environment = settings
	stage.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	key_light.light_energy = 2.1
	stage.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-18.0, -130.0, 0.0)
	fill_light.light_energy = 1.0
	stage.add_child(fill_light)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 16.0)
	floor.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("123947")
	floor.material_override = material
	stage.add_child(floor)

	door = KeyDoor.new()
	door.door_id = "visual_evidence"
	door.visual_height = 4.2
	door.position = Vector3(0.0, 0.0, 0.0)
	stage.add_child(door)

	camera = Camera3D.new()
	camera.position = Vector3(4.4, 2.8, 4.4)
	camera.near = 0.05
	camera.far = 100.0
	stage.add_child(camera)

func _capture(path: String) -> void:
	# Rendering is asynchronous even in headless Godot; two frames make the
	# current blend-shape value authoritative in the captured viewport.
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("captured %s" % path)

func _run() -> void:
	await process_frame
	camera.look_at(Vector3(0.0, 1.7, 0.0), Vector3.UP)
	await _capture(before_path)
	# This is the same progress setter driven by KeyDoor's opening tween; using
	# it here permits a stable review capture without faking a separate model.
	door._open_progress = 1.0
	await _capture(open_path)
	quit()
