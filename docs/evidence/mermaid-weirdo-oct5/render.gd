extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	root.add_child(stage)
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = Environment.new()
	atmosphere.environment.background_mode = Environment.BG_COLOR
	atmosphere.environment.background_color = Color("102a34")
	atmosphere.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.environment.ambient_light_color = Color.WHITE
	atmosphere.environment.ambient_light_energy = 0.3
	stage.add_child(atmosphere)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.position = Vector3(0, 3, 10)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 2, 0))
	camera.current = true
	var players: Array[AnimationPlayer] = []
	var index := 0
	for name in ["Mermaid_Freak.fbx", "Freak_Mermaid-Weirdo.fbx"]:
		var actor := (load("res://" + name) as PackedScene).instantiate() as Node3D
		stage.add_child(actor)
		actor.position = Vector3(-2.2 if index == 0 else 2.2, 1.55, 0)
		# Neutral inspection override exposes shape; it is not delivered texture
		# evidence and must never be copied into the game's validated materials.
		for node in actor.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			for surface in mesh.mesh.get_surface_count():
				var material := StandardMaterial3D.new()
				material.albedo_color = Color(0.22, 0.34, 0.38)
				material.roughness = 0.8
				mesh.set_surface_override_material(surface, material)
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		players.append(player)
		var caption := Label3D.new()
		caption.text = "Current Mermaid_Freak" if index == 0 else "Delivered Mermaid-Weirdo"
		caption.position = Vector3(actor.position.x, 4.5, 0)
		caption.font_size = 40
		stage.add_child(caption)
		index += 1
	for view in ["base-front", "base-back", "poison", "swim"]:
		camera.position = Vector3(0, 3, -7 if view == "base-back" else 7)
		camera.look_at(Vector3(0, 2, 0))
		for player in players:
			var fragment := "Base_pose"
			if view == "poison":
				fragment = "Poison_Breath"
			elif view == "swim":
				fragment = "Swimming)(Loop"
			for clip in player.get_animation_list():
				if fragment in clip:
					player.play(clip)
					player.seek(player.get_animation(clip).length * 0.5, true)
					player.pause()
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var destination: String = "/private/tmp/underwater-weirdo-inspection.RApXcf/" + view + ".png"
		print("ASSET_VIEW|", view, "|save=", root.get_texture().get_image().save_png(destination))
	quit(0)
