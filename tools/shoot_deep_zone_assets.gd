# Render each selected deep-zone FBX from its measured raw bounds. This is an
# intake gallery, not production scale: every asset gets its own fitted frame
# so a reviewer can inspect visible geometry/materials before gameplay wrappers
# choose scale, facing, and placement.
#
# Usage: godot --path . --resolution 1280x720 --script tools/shoot_deep_zone_assets.gd -- <outdir>
extends SceneTree

const ASSETS := [
	{"id": "bomb-bot", "path": "res://art/deep_zone/Bomb_Bot.fbx"},
	{"id": "sword-slayer", "path": "res://art/deep_zone/Sword_Slayer.fbx"},
	{"id": "broken-office", "path": "res://art/deep_zone/Broken_Office.fbx"},
	{"id": "deep-rocks", "path": "res://art/deep_zone/Rocks.fbx"},
]

var outdir := "/tmp/deep-zone-assets"
var holder: Node3D
var camera: Camera3D
var label: Label
var subject: Node3D
var asset_index := -1
var settle_frames := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		outdir = String(args[0])
	DirAccess.make_dir_recursive_absolute(outdir)

	holder = Node3D.new()
	root.add_child(holder)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071922")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("87b8c5")
	environment.ambient_light_energy = 1.1
	environment_node.environment = environment
	holder.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
	key.light_energy = 2.0
	holder.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, -145.0, 0.0)
	fill.light_energy = 0.8
	holder.add_child(fill)

	camera = Camera3D.new()
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

func _process(_delta: float) -> bool:
	if settle_frames == 0:
		asset_index += 1
		if asset_index >= ASSETS.size():
			return true
		_arm(ASSETS[asset_index] as Dictionary)
	settle_frames += 1
	if settle_frames < 8:
		return false
	var asset_id := String((ASSETS[asset_index] as Dictionary).id)
	var path := outdir.path_join("%s.png" % asset_id)
	root.get_texture().get_image().save_png(path)
	print("shot       %s" % path)
	settle_frames = 0
	return false

func _arm(definition: Dictionary) -> void:
	if subject != null:
		subject.free()
	subject = (load(String(definition.path)) as PackedScene).instantiate() as Node3D
	holder.add_child(subject)
	_play_idle(subject)
	var meshes := _meshes(subject)
	var bounds := _combined_bounds(meshes)
	# Put the measured lowest point on the floor without otherwise altering the
	# raw import. Production wrappers make their own documented scale choice.
	subject.position.y -= bounds.position.y
	bounds = _combined_bounds(meshes)

	var center := bounds.get_center()
	var radius := maxf(0.25, bounds.size.length() * 0.5)
	var distance := radius / tan(deg_to_rad(32.0)) * 0.78
	var direction := Vector3(0.82, 0.42, 1.0).normalized()
	camera.position = center + direction * distance
	camera.look_at(center, Vector3.UP)
	camera.near = maxf(0.01, distance * 0.002)
	camera.far = distance * 12.0
	label.text = "%s\nRaw bounds: %.2f × %.2f × %.2f\nMeshes: %d  Animations: %d" % [
		String(definition.id).replace("-", " ").capitalize(),
		bounds.size.x, bounds.size.y, bounds.size.z,
		meshes.size(), _animation_count(subject),
	]

func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out

func _combined_bounds(meshes: Array) -> AABB:
	var combined := AABB()
	var first := true
	for mesh_value in meshes:
		var mesh := mesh_value as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		combined = box if first else combined.merge(box)
		first = false
	return combined

func _animation_count(node: Node) -> int:
	var total := 0
	if node is AnimationPlayer:
		total += (node as AnimationPlayer).get_animation_list().size()
	for child in node.get_children():
		total += _animation_count(child)
	return total

func _play_idle(node: Node) -> bool:
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		for clip_value in player.get_animation_list():
			var clip := String(clip_value)
			var normalized := clip.to_lower().replace(" ", "")
			if normalized.contains("idle") and normalized.contains("loop"):
				player.play(clip)
				return true
	for child in node.get_children():
		if _play_idle(child):
			return true
	return false
