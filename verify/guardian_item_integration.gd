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
	# Both sites are deliberate spaces. A random-roll signal there must yield
	# to the player's explicit guardian choice, while physical entry must
	# preserve the site record's own enemy identity and a retry after loss.
	for spot_value in ItemGuardian.spots():
		var spot := spot_value as Dictionary
		var site_item := String(spot.item)
		diver.global_position = spot.at as Vector3
		diver.encounter_triggered.emit()
		await process_frame
		_expect(first.battle == null and not first.special_encounter_prompt.visible,
			"guardian item integration: both unclaimed sites suppress ordinary rolls — guards against artifact/random encounter ambiguity (%s)" % site_item)
		first.revealed_key_items.append(site_item)
		first._update_item_guardian_visibility()
		var site_guardian := _guardian_for(first, site_item)
		_expect(site_guardian != null and site_guardian.visible,
			"guardian item integration: revealed site exposes its physical guardian — guards against sonar/site drift (%s)" % site_item)
		if site_guardian == null:
			continue
		site_guardian.body_entered.emit(diver)
		await process_frame
		_expect(first.special_encounter_prompt.visible,
			"guardian item integration: physical entry opens the chooser — guards against a dead Area3D trigger (%s)" % site_item)
		first.special_encounter_prompt.diver_chosen.emit(diver.model_name)
		await process_frame
		var site_battle := first.battle
		_expect(site_battle != null and site_battle.special_encounter and site_battle.party.size() == 1,
			"guardian item integration: revealed sites start their mapped one-diver fight — guards against guardian flow drift (%s)" % site_item)
		if site_battle != null and not site_battle.enemies.is_empty():
			var actor := (site_battle.enemies[0] as Dictionary).get("actor") as Goblin
			_expect(actor != null and actor.enemy_id() == String(spot.enemy),
				"guardian item integration: revealed sites start their mapped one-diver fight — guards against species drift (%s)" % site_item)
			site_battle.finished.emit("lost")
			await process_frame
			await process_frame
			_expect(_guardian_for(first, site_item) != null and not first.key_items.has(site_item),
				"guardian item integration: loss preserves a retryable site — guards against missable key rewards (%s)" % site_item)

	# A player who found the site with sonar must carry that discovery through
	# the reward and into the save. This makes the old stale-guardian bug
	# visibly reproducible, rather than merely checking a hidden node.
	first._update_item_guardian_visibility()
	var guardian := _guardian_for(first, ITEM_ID)
	_expect(guardian != null and guardian.visible,
		"guardian item integration: revealed item has a physical guardian before win — guards against discovery/site drift")
	if guardian != null:
		guardian.body_entered.emit(diver)
		await process_frame
		_expect(first.special_encounter_prompt.visible,
			"guardian item integration: physical entry opens the chooser — guards against a dead Area3D trigger")
		first.special_encounter_prompt.diver_chosen.emit(diver.model_name)
		await process_frame
		_expect(first.battle != null and first.battle.special_encounter,
			"guardian item integration: chooser starts a special battle — guards against rewardless guardian entry")
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
	var stale := _guardian_for(loaded, ITEM_ID)
	_expect(stale == null,
		"guardian item integration: claimed item reload has no live guardian — guards against stale post-save guardian fights")
	if stale != null:
		var loaded_diver := loaded.divers[loaded.active] as Diver
		stale.body_entered.emit(loaded_diver)
		await process_frame
		_expect(not loaded.special_encounter_prompt.visible,
			"guardian item integration: claimed guardian cannot reopen a special encounter — guards against repeatable site combat")
	loaded.queue_free()
	await process_frame
	_restore_slot()
	for finding in findings:
		push_error(finding)
	print("GUARDIAN ITEM INTEGRATION: clean" if findings.is_empty() else "GUARDIAN ITEM INTEGRATION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _open_world(load_existing: bool) -> World:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
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

func _guardian_for(world: World, item_id: String) -> ItemGuardian:
	for child in world.get_children():
		if child is ItemGuardian and (child as ItemGuardian).item_id == item_id:
			return child as ItemGuardian
	return null

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _restore_slot() -> void:
	if _slot_existed:
		var destination := FileAccess.open(_slot_path, FileAccess.WRITE)
		destination.store_buffer(_slot_backup)
	elif FileAccess.file_exists(_slot_path):
		DirAccess.remove_absolute(_slot_path)
