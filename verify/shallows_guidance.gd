# SHALLOW-001: completed Shallows Load must visibly name the zone and purpose.
# Run in an isolated verifier user directory; never overwrite a player slot.
extends SceneTree

const SLOT := 918313
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if SaveManager.slot_exists(SLOT):
		push_error("Owned Shallows verifier slot exists; refusing overwrite")
		quit(1)
		return
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var fixture := world._serialize_state()
	fixture.route_state = {"opening_video_seen": true, "prologue_complete": true, "tutorial_complete": true, "objective_id": "find_lab", "zone_id": "deep", "deep_warning_seen": true}
	fixture.divers[0].position = [-30, 2, 30]
	fixture.random_encounters_enabled = false
	fixture.save_point_tutorial_seen = true
	SaveManager.write_slot(SLOT, fixture)
	world.title_screen.load_game_chosen.emit(SLOT)
	await process_frame
	await physics_frame
	await process_frame
	var text := world.route_objective_label.text.to_lower()
	# Tutorial side of the entrance blockade (x < 16).
	_expect(world.route_objective_panel.visible and "mysterious blockade" in text,
		"SHALLOW-001 post-opening Shallows has no visible zone/purpose instruction: " + text)
	_expect(not "laboratory" in text and not "wall" in text,
		"SHALLOW-001 Shallows shows an unrelated contextual instruction")
	_expect(world.route_state.objective_id == "find_lab", "SHALLOW-002 Shallows instruction erases lab progression")
	if OS.get_cmdline_user_args().has("--capture"):
		await create_timer(0.5).timeout
		_expect(root.get_visible_rect().encloses(world.route_objective_panel.get_global_rect()), "SHALLOW-004 Shallows instruction is clipped")
		var minimap := Rect2(Vector2(root.size.x - 166, 0), Vector2(166, 166))
		_expect(not minimap.intersects(world.route_objective_panel.get_global_rect()), "SHALLOW-004 minimap covers Shallows instruction")
		DisplayServer.window_move_to_foreground()
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/shallows-guidance-%dx%d.png" % [int(root.size.x), int(root.size.y)])
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(SLOT)))
	for finding in findings:
		print("FINDING  " + finding)
	print("SHALLOWS GUIDANCE: clean" if findings.is_empty() else "SHALLOWS GUIDANCE: failed")
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
