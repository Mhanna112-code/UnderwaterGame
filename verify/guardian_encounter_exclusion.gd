# Captured route contract: a guarded site is a deliberate encounter space,
# not a place where a random roll can replace its mapped enemy and reward.
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
	world.route_state.opening_video_seen = true
	world.route_state.prologue_complete = true
	world.route_state.tutorial_complete = true
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

	# Drive the same public signal a successful distance roll reaches. Site
	# proximity must intercept it and build the mapped guardian battle rather
	# than an ordinary random pack.
	diver.encounter_triggered.emit()
	await process_frame
	await process_frame
	if _battle_count() != 1 or world.battle == null:
		findings.append("GUARDIAN ZONE: entering shallows produced %d battles instead of one mapped fight" % _battle_count())
	else:
		var built := world.battle as Battle
		if not built.guardian_encounter or built.reward_item_on_win != String(site.item):
			findings.append("GUARDIAN ZONE: site entry lost its guardian source or '%s' reward" % String(site.item))
		elif built.enemies.is_empty() or ((built.enemies[0] as Dictionary).actor as Goblin).enemy_id() != String(site.enemy):
			findings.append("GUARDIAN ZONE: site entry did not preserve mapped enemy '%s'" % String(site.enemy))

	for finding in findings:
		push_error(finding)
	_restore_slot()
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
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

func _restore_slot() -> void:
	if _slot_existed:
		var destination := FileAccess.open(_slot_path, FileAccess.WRITE)
		destination.store_buffer(_slot_backup)
	elif FileAccess.file_exists(_slot_path):
		DirAccess.remove_absolute(_slot_path)
