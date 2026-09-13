# Records a fixed overhead proof of a diver holding full upstream input
# against a traversal-blocking WaterCurrent.
# Usage: godot --path . --script tools/shoot_current_barrier.gd -- /tmp/current-frames
extends SceneTree

var frame_dir := "/tmp/current-barrier-frames"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		frame_dir = String(args[0])
	call_deferred("_run")

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _box(size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color)
	return node

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(frame_dir)
	var stage := Node3D.new()
	root.add_child(stage)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.10, 0.14)
	environment.environment = env
	stage.add_child(environment)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.0
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 18.0, 0.0), Vector3.ZERO, Vector3.FORWARD)

	# Cyan is the active current volume; red is the edge the diver must not
	# cross while swimming upstream (+Z). The arrow points with the flow.
	stage.add_child(_box(Vector3(6.0, 0.08, 8.0), Vector3.ZERO, Color(0.1, 0.65, 0.9, 0.32)))
	stage.add_child(_box(Vector3(6.3, 0.12, 0.12), Vector3(0.0, 0.08, 4.0), Color(1.0, 0.2, 0.2)))
	stage.add_child(_box(Vector3(0.18, 0.10, 3.0), Vector3(2.3, 0.10, -0.5), Color(0.4, 0.9, 1.0)))
	stage.add_child(_box(Vector3(0.9, 0.10, 0.18), Vector3(2.3, 0.10, -1.9), Color(0.4, 0.9, 1.0)))

	var area := Area3D.new()
	area.collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 4.0, 8.0)
	collision.shape = shape
	area.add_child(collision)
	stage.add_child(area)

	var current := WaterCurrent.new()
	stage.add_child(current)
	current.setup(area, Vector3(0.0, 0.0, -1.0), 7.0, false)

	var diver := Diver.new()
	diver.model_name = "Prototype_V(1922)"
	diver.position = Vector3(0.0, 0.0, -2.5)
	stage.add_child(diver)
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.76
	marker.mesh = sphere
	marker.position.y = 1.2
	marker.material_override = _material(Color(1.0, 0.55, 0.1))
	diver.add_child(marker)

	var hud := CanvasLayer.new()
	var label := Label.new()
	label.position = Vector2(16.0, 14.0)
	label.text = "FULL UPSTREAM INPUT HELD (+Z)\nOrange: diver   Cyan: current   Red: forbidden crossing edge\nFlow pushes upward (-Z)"
	label.add_theme_font_size_override("font_size", 20)
	hud.add_child(label)
	stage.add_child(hud)

	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	for frame in range(120):
		# The player holds maximum input directly against the current.
		diver.swim(Vector3(0.0, 0.0, 1.0), 0.0, 1.0 / 60.0)
		await physics_frame
		diver.swim(Vector3(0.0, 0.0, 1.0), 0.0, 1.0 / 60.0)
		await physics_frame
		root.get_texture().get_image().save_png(
			frame_dir.path_join("frame_%03d.png" % frame)
		)
	quit()
