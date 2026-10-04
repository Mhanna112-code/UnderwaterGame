# Repeatable production-adapter gallery for the opening Cordys actor.
# Usage: godot --path . --resolution 1280x720 --script tools/shoot_prologue_octopus.gd -- <outdir>
extends SceneTree

const POSES := ["reveal", "idle", "hurt", "finish"]
const PROLOGUE_OCTOPUS := preload("res://game/prologue_octopus.gd")

var outdir := "/tmp/prologue-octopus"
var holder: Node3D
var actor: Node3D
var camera: Camera3D
var label: Label

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		outdir = String(args[0])
	DirAccess.make_dir_recursive_absolute(outdir)
	call_deferred("_run")

func _run() -> void:
	holder = Node3D.new()
	root.add_child(holder)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061c27")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6faabd")
	environment.ambient_light_energy = 0.78
	environment_node.environment = environment
	holder.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28.0, 145.0, 0.0)
	key.light_color = Color("b7efff")
	key.light_energy = 1.65
	holder.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18.0, -35.0, 0.0)
	rim.light_color = Color("ff8e71")
	rim.light_energy = 0.75
	holder.add_child(rim)

	actor = PROLOGUE_OCTOPUS.new() as Node3D
	holder.add_child(actor)
	await process_frame
	actor.call("face_toward", Vector3(0.0, 2.0, 20.0))
	camera = Camera3D.new()
	camera.fov = 44.0
	holder.add_child(camera)

	var overlay := CanvasLayer.new()
	holder.add_child(overlay)
	label = Label.new()
	label.position = Vector2(28, 24)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(label)

	for pose in POSES:
		var duration := float(actor.call("play", pose))
		await process_frame
		var animation_player := actor.get("anim") as AnimationPlayer
		if animation_player != null and duration > 0.0:
			animation_player.seek(duration * (0.46 if pose != "idle" else 0.2), true)
			animation_player.pause()
		for _frame in range(3):
			await process_frame
		var bounds := actor.call("visual_bounds") as AABB
		var center: Vector3 = bounds.get_center()
		# Depth along the view direction should not shrink a long composite into
		# a speck. Fit the projected X/Y silhouette, then add only enough depth
		# clearance to keep the closest animated limb in front of the camera.
		var screen_radius := maxf(bounds.size.y * 0.5, bounds.size.x * 0.5 / (1280.0 / 720.0))
		var distance := screen_radius / tan(deg_to_rad(camera.fov * 0.5)) * 1.28 + bounds.size.z
		var view_direction := Vector3(0.0, 0.08, 1.0).normalized()
		camera.position = center + view_direction * distance
		camera.look_at(center, Vector3.UP)
		camera.near = maxf(0.02, distance * 0.005)
		camera.far = distance * 12.0
		label.text = "Cordys opening actor\n%s pose  •  %.2f × %.2f × %.2f m" % [
			pose.capitalize(), bounds.size.x, bounds.size.y, bounds.size.z]
		for _frame in range(5):
			await process_frame
		var path := outdir.path_join("cordys-%s.png" % pose)
		root.get_texture().get_image().save_png(path)
		print("shot       %s" % path)

	actor.queue_free()
	await process_frame
	quit()
