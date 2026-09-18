# Player-visible lifecycle and identity regressions discovered during the final
# PR 54 audit. Keep these on the real World/Battle surfaces: a unit test of
# GameOverScreen alone cannot catch the CanvasLayer/HUD ownership bug.
# Usage: godot --headless --path . --script verify/pr54_merge_readiness.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _defeat_owns_the_viewport()
	await _identities_match_in_world_and_battle()
	for finding in findings:
		push_error(finding)
	print("PR54 merge readiness  defeat and identities clean" if findings.is_empty() else "PR54 merge readiness  FAILED")
	quit(0 if findings.is_empty() else 1)

func _defeat_owns_the_viewport() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame

	# Put the scene in the same visible state as active play without touching a
	# real save slot, then enter through World's production defeat transition.
	world.title_screen.close()
	world.get_node("HUD").visible = true
	paused = false
	world._show_game_over()
	await process_frame
	await process_frame

	if not world.game_over_screen.visible:
		findings.append("DEFEAT HIDDEN: GameOverScreen did not open")
	if world.get_node("HUD").visible:
		findings.append("HUD LEAK: active-character controls remain behind defeat")
	if world.title_screen.visible:
		findings.append("TITLE LEAK: title remains visible behind defeat")
	if not paused:
		findings.append("WORLD LIVE: defeat did not pause gameplay")
	var viewport_size := root.get_visible_rect().size
	if not world.game_over_screen.size.is_equal_approx(viewport_size):
		findings.append("DEFEAT RECT: %s vs viewport %s" % [world.game_over_screen.size, viewport_size])

	paused = false
	world.queue_free()
	await process_frame

func _identities_match_in_world_and_battle() -> void:
	var expected := ["Maxilani", "Musashi", "Bucky"]
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	world.title_screen.close()
	world.get_node("HUD").visible = true
	paused = false

	for i in range(world.divers.size()):
		world.active = i
		world._update_hud()
		var first_line := String(world.hud.text).split("\n")[0]
		if not first_line.begins_with(expected[i] + " "):
			findings.append("WORLD NAME %d: expected %s, got %s" % [i, expected[i], first_line])

	var battle := Battle.new()
	battle.party_source = world.divers
	battle._build_party()
	for i in range(battle.party.size()):
		var actual := String((battle.party[i] as Dictionary).display_name)
		if actual != expected[i]:
			findings.append("BATTLE NAME %d: expected %s, got %s" % [i, expected[i], actual])
	battle.queue_free()

	world.queue_free()
	await process_frame
