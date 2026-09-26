# `interactive combat training: optional five-move practice is reachable,
# keeps the opening compact, and restores campaign state`.
#
# Usage: godot --headless --path . --script verify/interactive_combat_training.gd
extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.close()
	world.get_node("HUD").visible = true
	world._first_encounter_done = true

	var before: Array[Dictionary] = []
	for diver_value in world.divers:
		var diver := diver_value as Diver
		before.append({"hp": diver.stats.hp, "oxygen": diver.stats.oxygen, "xp": diver.stats.xp})

	world.inventory_menu.open_combat_help()
	await process_frame
	var training := _button_named(world.inventory_menu, "Interactive Combat Training")
	_expect(training != null,
		"INTERACTIVE-TRAINING-1: Combat Help has no reachable Interactive Combat Training button")
	if training != null:
		training.pressed.emit()
		if not await _wait_for_battle(world):
			_expect(false,
				"INTERACTIVE-TRAINING-1: selecting Interactive Combat Training did not open a live practice battle")
		else:
			_expect(String(world.battle.get("tutorial_profile")) == "interactive_combat_training",
				"INTERACTIVE-TRAINING-2: training opened the short opening lesson instead of the interactive profile")
			_expect(world.battle.has_method("active_tutorial_script"),
				"INTERACTIVE-TRAINING-2: live training exposes no inspectable lesson contract")
			if world.battle.has_method("active_tutorial_script"):
				var script: Array = world.battle.call("active_tutorial_script") as Array
				var move_names: Array[String] = []
				for stage_value in script:
					move_names.append(String((stage_value as Dictionary).get("move", "")))
				_expect(move_names == ["Electric Touch", "Precise Tap", "Crushing Haymaker", "Weaken", "Flash Blast"],
					"INTERACTIVE-TRAINING-2: training does not expose the five distinct combat lessons")
			world.battle.call("_on_skip_tutorial_pressed")
			await create_timer(1.25).timeout
			for index in range(world.divers.size()):
				var after := (world.divers[index] as Diver).stats
				var snapshot := before[index]
				_expect(after.hp == int(snapshot.hp) and is_equal_approx(after.oxygen, float(snapshot.oxygen)) and after.xp == int(snapshot.xp),
					"INTERACTIVE-TRAINING-3: ending optional training changed campaign HP, oxygen, or XP")

	for failure in failures:
		push_error(failure)
	print("INTERACTIVE COMBAT TRAINING: %s" % ("clean" if failures.is_empty() else "%d failure(s)" % failures.size()))
	world.queue_free()
	quit(0 if failures.is_empty() else 1)

func _wait_for_battle(world: World) -> bool:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		if world.battle != null:
			return true
		await process_frame
	return false

func _button_named(node: Node, text_value: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == text_value:
			return child as Button
		var nested := _button_named(child, text_value)
		if nested != null:
			return nested
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
