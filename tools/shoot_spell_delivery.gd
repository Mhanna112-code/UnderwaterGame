# Native visual audit of the actual runtime diver, not replacement FBX scenes.
# godot --path . --rendering-method gl_compatibility --script tools/shoot_spell_delivery.gd
extends SceneTree
const CASES := [
	["Staff_Diver", "Swift Strike"], ["Staff_Diver", "Riptide Slash"],
	["Prototype_1(1910)", "Blinding Silt"], ["Prototype_1(1910)", "Exploit Opening"],
	["Prototype_1(1910)", "Precise Jab"], ["Prototype_V(1922)", "Guard Break"],
	["Prototype_V(1922)", "Heavy Slam"], ["Prototype_V(1922)", "Mending Current"],
	["Prototype_V(1922)", "Tidal Revival"],
]
var actors: Array[Diver] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1400, 1000)
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2, 15)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.5
	stage.add_child(camera)
	camera.look_at(Vector3(0, 2, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -25, 0)
	light.light_energy = 1.4
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("123039")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	for index in range(CASES.size()):
		var actor := Diver.new()
		actor.model_name = CASES[index][0]
		stage.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.scale *= 2.3 / actor.height
		actor.position = Vector3(-4 + (index % 3) * 4, 6 - floorf(index / 3.0) * 4, 0)
		actor.rotation.y = 0.45
		actors.append(actor)
		var label := Label3D.new()
		label.text = Cast.display_name(actor.model_name) + " / " + CASES[index][1]
		label.font_size = 34
		label.position = Vector3(actor.position.x, actor.position.y + 1.85, 0)
		stage.add_child(label)
	DirAccess.make_dir_recursive_absolute("/tmp/spell-delivery-native")
	for fraction in [0.25, 0.55, 0.8]:
		for index in range(actors.size()):
			var actor := actors[index]
			var length := actor.play_clip(Cast.ability(actor.model_name, CASES[index][1]))
			actor.anim.seek(length * fraction, true)
			actor.anim.pause()
		for frame in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/spell-delivery-native/pose-%02d.png" % int(fraction * 100))
	quit()
