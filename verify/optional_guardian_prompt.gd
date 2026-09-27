# `optional guardian: prompt identifies the off-route reward, objective,
# controls, practice, entry, and leave paths — guards against an unexplained
# artifact challenge masquerading as mandatory progression`.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.new_game_chosen.emit(11)
	await process_frame

	var guardian := _guardian_for(world, "current_pearl")
	_expect(guardian != null, "OPTIONAL GUARDIAN: Current Pearl site was not constructed")
	if guardian != null:
		guardian.triggered.emit("current_pearl")
		await process_frame
		var prompt := world.special_encounter_prompt
		var copy := prompt.confirm_text()
		var actions := prompt.confirm_actions()
		_expect(prompt.visible and paused,
			"OPTIONAL GUARDIAN: entering a site did not open the explicit paused choice prompt")
		_expect(copy.contains("Optional") and copy.contains("Current Pearl") and copy.contains("Objective") and copy.contains("off the main route"),
			"OPTIONAL GUARDIAN: prompt did not identify its optional reward/objective boundary")
		_expect(copy.contains("Swap") and copy.contains("Grapple") and copy.contains("Shockwave") and copy.contains("E"),
			"OPTIONAL GUARDIAN: prompt did not show the named diver-ability controls before entry")
		_expect(actions.has("Practice Controls") and actions.has("Enter Challenge") and actions.has("Leave"),
			"OPTIONAL GUARDIAN: prompt did not offer practice, deliberate entry, and safe leave")

		prompt.show_practice_controls()
		_expect(prompt.confirm_text().contains("Practice Controls") and prompt.confirm_text().contains("leaving does not block progression"),
			"OPTIONAL GUARDIAN: Practice Controls did not reveal a readable pre-entry objective")
		prompt.cancelled.emit()
		await process_frame
		_expect(not prompt.visible and not paused and world.battle == null and guardian != null and is_instance_valid(guardian),
			"OPTIONAL GUARDIAN: Leave started combat, left the world paused, or consumed the optional site")

	for finding in findings:
		push_error(finding)
	print("OPTIONAL GUARDIAN PROMPT: clean" if findings.is_empty() else "OPTIONAL GUARDIAN PROMPT: %d finding(s)" % findings.size())
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _guardian_for(world: World, item_id: String) -> ItemGuardian:
	for child in world.get_children():
		if child is ItemGuardian and (child as ItemGuardian).item_id == item_id:
			return child as ItemGuardian
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
