# Throwaway probe: confirms R toggles random_encounters_enabled, the HUD
# hint reflects it, and _on_encounter_triggered() actually honors it.
# Usage: godot --headless --path . --script verify/random_encounters_toggle_probe.gd
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(1)
	await process_frame
	await process_frame

	print("enabled by default: %s" % world.random_encounters_enabled)
	print("hud mentions R before toggle: %s" % ("R: Encounters" in world.hud.text))

	world._toggle_random_encounters()
	print("enabled after one toggle: %s" % world.random_encounters_enabled)
	print("hud shows Off: %s" % ("R: Encounters (Off)" in world.hud.text))

	var d: Diver = world.divers[world.active]
	var before_battling := world.battling
	world._on_encounter_triggered(d)
	print("battle started while disabled: %s (should be false)" % (world.battling != before_battling))

	world._toggle_random_encounters()
	print("enabled after second toggle: %s" % world.random_encounters_enabled)
	print("hud shows On: %s" % ("R: Encounters (On)" in world.hud.text))

	quit(0)
