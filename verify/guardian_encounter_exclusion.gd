# Captured route contract: a guardian site is a deliberate encounter space,
# not a place where a random roll can interrupt and obscure the artifact.
# Usage: godot --headless --path . --script verify/guardian_encounter_exclusion.gd
extends SceneTree

const TEST_SLOT := 918275

var world: World
var findings: Array[String] = []
var _slot_path := ""
var _slot_backup := PackedByteArray()
var _slot_existed := false

func _initialize() -> void:
	_slot_path = ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	_slot_existed = FileAccess.file_exists(_slot_path)
	if _slot_existed:
		var source := FileAccess.open(_slot_path, FileAccess.READ)
		_slot_backup = source.get_buffer(source.get_length())
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(TEST_SLOT)
	await process_frame
	world._intro_active = false
	var site: Dictionary = Sites.by_id("shallows")
	var diver := world.divers[world.active] as Diver
	diver.global_position = site.at as Vector3
	diver.force_update_transform()

	# Drive the same public signal a successful random roll reaches. RED on
	# current production: World opens an ordinary Battle at this site.
	diver.encounter_triggered.emit()
	await process_frame
	await process_frame
	if _battle_count() != 0:
		findings.append("GUARDIAN ZONE: random encounter opened %d battle(s) at an unclaimed artifact" % _battle_count())
		_clear_battle()

	# The exclusion must not disable the site itself. Enter its actual Area3D
	# after the rejected random roll and require the real chooser.
	var guardian := _guardian_for(String(site.item))
	if guardian == null:
		findings.append("GUARDIAN ZONE: no physical guardian exists at shallows")
	else:
		guardian.body_entered.emit(diver)
		await process_frame
		if not world.special_encounter_prompt.visible:
			findings.append("GUARDIAN ZONE: rejecting random encounter also blocked the physical guardian")

	for finding in findings:
		push_error(finding)
	_restore_slot()
	world.queue_free()
	if findings.is_empty():
		print("guardian encounter exclusion  random rolls yield to the real guardian")
	quit(0 if findings.is_empty() else 1)

func _battle_count() -> int:
	var count := 0
	for child in world.get_children():
		if child is Battle:
			count += 1
	return count

func _clear_battle() -> void:
	for child in world.get_children():
		if child is Battle:
			child.queue_free()
	world.battle = null
	world.battling = false

func _guardian_for(item_id: String) -> ItemGuardian:
	for child in world.get_children():
		if child is ItemGuardian and (child as ItemGuardian).item_id == item_id:
			return child as ItemGuardian
	return null

func _restore_slot() -> void:
	if _slot_existed:
		var destination := FileAccess.open(_slot_path, FileAccess.WRITE)
		destination.store_buffer(_slot_backup)
	elif FileAccess.file_exists(_slot_path):
		DirAccess.remove_absolute(_slot_path)
