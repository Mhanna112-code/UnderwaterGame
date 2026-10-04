# High-risk guardian/item regression gate.  The first contract below was
# intentionally written before its repair: a physically collected key item
# must not rebuild a stale, triggerable guardian when that save is loaded.
extends SceneTree

const TEST_SLOT := 918276
const ITEM_ID := "current_pearl"

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
	call_deferred("_run")

func _run() -> void:
	var first := await _open_world(false)
	var diver := first.divers[first.active] as Diver
	# Ordinary key-item sites are proximity contracts now; the removed visible
	# guardian/ring presentation must not be required. A distance-roll signal
	# at either location is intercepted into exactly its mapped enemy/reward.
	for spot_value in ItemGuardian.spots():
		var spot := spot_value as Dictionary
		if bool(spot.get("special", false)):
			continue
		var site_item := String(spot.item)
		diver.global_position = spot.at as Vector3
		first._inside_item_site_id = ""
		diver.encounter_triggered.emit()
		await process_frame
		var site_battle := first.battle
		_expect(site_battle != null and site_battle.guardian_encounter and site_battle.reward_item_on_win == site_item,
			"guardian item integration: site starts its mapped reward fight — guards against guardian flow drift (%s)" % site_item)
		if site_battle != null and not site_battle.enemies.is_empty():
			var actor := (site_battle.enemies[0] as Dictionary).get("actor") as Goblin
			_expect(actor != null and actor.enemy_id() == String(spot.enemy),
				"guardian item integration: site starts its mapped enemy — guards against species drift (%s)" % site_item)
			site_battle.finished.emit("fled")
			await process_frame
			await process_frame
			_expect(not first.key_items.has(site_item),
				"guardian item integration: leaving a site fight cannot grant its key reward (%s)" % site_item)

	# Win current_pearl through the same normal-entry proximity path, then
	# prove the claimed state survives a fresh World and cannot reopen the
	# reward encounter.
	var pearl_spot := Sites.by_id("shallows")
	diver.global_position = pearl_spot.at as Vector3
	first._inside_item_site_id = ""
	diver.encounter_triggered.emit()
	await process_frame
	_expect(first.battle != null and first.battle.reward_item_on_win == ITEM_ID,
		"guardian item integration: shallows does not start the current_pearl fight")
	if first.battle != null:
		first.battle.finished.emit("won")
		await process_frame
		await process_frame
	_expect(first.key_items.has(ITEM_ID),
		"guardian item integration: winning grants the key item — guards against reward loss before persistence")
	first._write_save()
	first.queue_free()
	await process_frame

	var loaded := await _open_world(true)
	_expect(loaded.key_items.has(ITEM_ID),
		"guardian item integration: key item survives save/load — guards against dropped reward state")
	var loaded_diver := loaded.divers[loaded.active] as Diver
	loaded_diver.global_position = pearl_spot.at as Vector3
	loaded._inside_item_site_id = ""
	var claimed_triggered := loaded._try_trigger_item_site(loaded_diver)
	_expect(not claimed_triggered and loaded.battle == null,
		"guardian item integration: claimed site reopened its reward encounter after load")
	loaded.queue_free()
	await process_frame
	_restore_slot()
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	for finding in findings:
		push_error(finding)
	print("GUARDIAN ITEM INTEGRATION: clean" if findings.is_empty() else "GUARDIAN ITEM INTEGRATION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _open_world(load_existing: bool) -> World:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.route_state.opening_video_seen = true
	world.route_state.prologue_complete = true
	world.route_state.tutorial_complete = true
	root.add_child(world)
	await process_frame
	await process_frame
	if load_existing:
		world.title_screen.load_game_chosen.emit(TEST_SLOT)
	else:
		world.title_screen.new_game_chosen.emit(TEST_SLOT)
	await process_frame
	world._intro_active = false
	world._first_encounter_done = true
	return world

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _restore_slot() -> void:
	if _slot_existed:
		var destination := FileAccess.open(_slot_path, FileAccess.WRITE)
		destination.store_buffer(_slot_backup)
	elif FileAccess.file_exists(_slot_path):
		DirAccess.remove_absolute(_slot_path)
