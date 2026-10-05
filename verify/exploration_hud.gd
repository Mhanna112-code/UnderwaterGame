extends SceneTree
## HUD-1: approved exploration has exactly two visible resource meters.
var findings: Array[String] = []
var captures := ""
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			captures = arg.trim_prefix("--capture-dir=")
	var world := load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world._on_title_spell_playtest()
	for i in range(3):
		world.divers[i].global_position = Vector3(30, 3, 30 + i * 2)
		world.divers[i].sonar_active = false
	world.random_encounters_enabled = false
	for frame in range(8):
		await process_frame
	var meters := 0
	for control in world.get_node("HUD").find_children("*", "ProgressBar", true, false):
		if control.is_visible_in_tree():
			meters += 1
	if meters != 2:
		findings.append("HUD-1: expected two visible active-diver meters, got %d" % meters)
	if findings.is_empty():
		await _verify_resources_and_layout(world)
		await _verify_owners(world)
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("EXPLORATION HUD: clean|checks=%d" % checks if findings.is_empty() else "EXPLORATION HUD: failed")
	quit(0 if findings.is_empty() else 1)

func _verify_resources_and_layout(world: World) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100506
	var shapes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(720, 480), Vector2i(360, 640)]
	for i in range(16):
		shapes.append(Vector2i(rng.randi_range(360, 1600), rng.randi_range(480, 1000)))
	for shape in shapes:
		root.size = shape
		for selected in range(3):
			# Generated resource fixtures characterize presentation, not gameplay.
			for actor in world.divers:
				actor.stats.hp = rng.randi_range(0, 10)
				actor.stats.oxygen = rng.randf_range(0, 100)
			await _settle()
			var d := world.divers[world.active] as Diver
			var ui := world.exploration_hud
			_expect(world.active == selected, "HUD-2 actual TAB selected the wrong diver")
			_expect(world.hp_bar.value == d.stats.hp and is_equal_approx(world.oxygen_bar.value, d.stats.oxygen), "HUD-2 meters show wrong actor's resources")
			_expect(String(ui.active_name.text) == ["Maxilani", "Musashi", "Bucky"][selected], "HUD-2 active name disagrees with steered actor")
			_expect("%d/%d" % [d.stats.hp, d.stats.hp_max] in world.hp_bar_label.text and "Health" in world.hp_bar_label.text, "HUD-2 health label hides numeric value or resource identity")
			_expect("Oxygen" in world.oxygen_bar_label.text, "HUD-5 Oxygen label is still an unexplained abbreviation")
			_expect(not "LOW" in world.oxygen_bar_label.text or d.stats.oxygen <= 20, "HUD-2 spurious oxygen warning")
			var teammate_names := ""
			for label in ui.party_panel.find_children("*", "Label", true, false):
				if label.is_visible_in_tree():
					teammate_names += label.text + "\n"
			for i in range(3):
				var name: String = ["Maxilani", "Musashi", "Bucky"][i]
				_expect((name in teammate_names) == (i != selected), "HUD-2 teammate list duplicates active diver or omits ally")
			_expect("Arrow keys" in world.hud.text and "F:" in world.hud.text and "R:" in world.hud.text and "Esc:" in world.hud.text, "HUD-5 existing movement/ability/menu controls lost")
			var panels: Array[Control] = [ui.active_panel, ui.party_panel, ui.encounter_label, world.hud, world.minimap]
			var bounds := Rect2(Vector2.ZERO, Vector2(shape))
			for panel in panels:
				_expect(bounds.encloses(panel.get_global_rect()), "HUD-4 HUD panel clipped at %s: %s" % [shape, panel.name])
				for label in panel.find_children("*", "Label", true, false):
					if label.is_visible_in_tree():
						_expect(bounds.encloses(label.get_global_rect()), "HUD-4 text clipped at %s: %s" % [shape, label.text])
						_expect(panel.get_global_rect().encloses(label.get_global_rect()), "HUD-4 text escapes its card at %s: %s" % [shape, label.text])
			for a in range(panels.size()):
				for b in range(a + 1, panels.size()):
					_expect(not panels[a].get_global_rect().intersects(panels[b].get_global_rect()), "HUD-4 panels overlap at %s: %s/%s" % [shape, panels[a].name, panels[b].name])
			for control in ui.find_children("*", "Control", true, false):
				_expect(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD-3 informational resource UI eats aim/click input")
			if not captures.is_empty() and shape in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(720, 480), Vector2i(360, 640)] and selected == 0:
				for actor in world.divers:
					actor.stats.fill()
				await _settle()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(captures.path_join("exploration-%dx%d.png" % [shape.x, shape.y]))
			# Restore live health so actual Tab can select the next actor.
			for actor in world.divers:
				actor.stats.hp = 10
			await _tap(KEY_TAB)
	# R is keyboard-owned, not a newly invented clickable status toggle.
	await _tap(KEY_R)
	_expect(world.random_encounters_enabled and "ON" in world.exploration_hud.encounter_label.text, "HUD-5 actual R preference/status disagree")
	await _tap(KEY_R)
	_expect(not world.random_encounters_enabled and "OFF" in world.exploration_hud.encounter_label.text, "HUD-5 R-off status is stale")
	world.divers[0].stats.oxygen = 70
	await _tap(KEY_Q)
	_expect(world.divers[0].sonar_active and "Sonar On" in world.hud.text, "HUD-5 Sonar input/hint disappeared")
	await _tap(KEY_Q)
	world.divers[0].stats.hp = 0
	world.divers[0].stats.oxygen = 0
	await _settle()
	_expect("DOWN" in world.hp_bar_label.text and "LOW" in world.oxygen_bar_label.text, "HUD-2 empty resource labels hide down/low state")
	world.divers[0].stats.fill()

func _verify_owners(world: World) -> void:
	await _tap(KEY_ESCAPE)
	_expect(world.inventory_menu.visible and not world.exploration_hud.is_visible_in_tree() and not world.hud.is_visible_in_tree(), "HUD-3 Escape menu shares pixels with exploration HUD")
	await _tap(KEY_ESCAPE)
	_expect(world.exploration_hud.is_visible_in_tree() and world.hud.is_visible_in_tree(), "HUD-3 closing menu loses HUD")
	world.save_point_menu.open_for(world.divers[world.active])
	await _settle()
	_expect(not world.exploration_hud.is_visible_in_tree(), "HUD-3 save menu shares resource HUD")
	world.save_point_menu.close()
	await _settle()
	world.route_state.set_encounter_source("random")
	world._start_battle()
	await _settle()
	_expect(world.battling and world.battle != null and not world.exploration_hud.is_visible_in_tree() and not world.hud.is_visible_in_tree() and not world.minimap.is_visible_in_tree(), "HUD-3 real battle entry still displays exploration UI")

func _tap(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await _settle()

func _settle() -> void:
	for frame in range(6):
		await process_frame

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok and not findings.has(message):
		findings.append(message)
