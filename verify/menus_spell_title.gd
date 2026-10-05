# Current menu, tutorial replay, spell-review, and title-route contract.
# Usage: godot --headless --path . --script verify/menus_spell_title.gd
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
	paused = false
	world._first_encounter_done = true

	await _test_combat_help_surface(world)
	await _test_inventory_item_surface(world)
	await _test_tutorial_replay(world)
	await _test_spell_review_route(world)
	await _test_title_review_route_composition(world)
	await _finish(world)

func _test_combat_help_surface(world: World) -> void:
	world.inventory_menu.open()
	world.inventory_menu.call("_switch_to", "help")
	await process_frame
	var scroll := world.inventory_menu.find_child("ContentScroll", true, false) as ScrollContainer
	_expect(scroll != null and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED,
		"MENU-HELP-2: Combat Help has no scrollable reading surface")
	for action in [
		"Replay Tutorial Fight",
		"Replay Special Encounter Tutorial",
	]:
		_expect(_button_named(world.inventory_menu, action) != null,
			"MENU-HELP-2: Combat Help is missing action: %s" % action)
	for heading in ["Stats", "Effects", "Status Conditions"]:
		_expect(_label_named(world.inventory_menu, heading) != null,
			"MENU-HELP-2: Combat Help is missing reference section: %s" % heading)
	_expect(world.inventory_menu.get_parent() == world.get_node("HUD"),
		"MENU-OVERLAY-8: Inventory moved out of the established HUD menu layer")
	_expect(world.inventory_menu.size.x >= world.get_viewport().get_visible_rect().size.x * 0.98,
		"MENU-OVERLAY-8: Inventory backdrop does not cover the viewport width")
	world.inventory_menu.close()

func _test_inventory_item_surface(world: World) -> void:
	var diver := world.divers[world.active] as Diver
	diver.stats.hp = maxi(1, diver.stats.hp_max - 13)
	var before_hp := diver.stats.hp
	world.inventory = {"potion": 1}
	world.inventory_menu.open()
	await process_frame
	var potion_button := _button_named(world.inventory_menu, "Potion")
	_expect(potion_button != null and not potion_button.disabled,
		"MENU-ITEM-7: a usable Potion is not selectable from Inventory")
	if potion_button != null:
		potion_button.pressed.emit()
		await process_frame
	_expect(diver.stats.hp == mini(diver.stats.hp_max, before_hp + 10),
		"MENU-ITEM-7: Potion did not apply exactly its documented 10 HP")
	_expect(not world.inventory.has("potion"),
		"MENU-ITEM-7: one Potion click did not consume exactly one copy")
	_expect(world.inventory_menu.visible,
		"MENU-ITEM-7: applying an item unexpectedly closed Inventory")
	world.inventory_menu.close()

func _test_tutorial_replay(world: World) -> void:
	var growth_before: Array[Dictionary] = []
	for index in range(world.divers.size()):
		var stats := (world.divers[index] as Diver).stats
		stats.hp = maxi(1, stats.hp_max - index - 2)
		stats.oxygen = maxf(1.0, stats.oxygen_max - float((index + 1) * 7))
		growth_before.append({
			"level": stats.level,
			"xp": stats.xp,
			"spell_points": stats.spell_points,
			"known_spells": (world.divers[index] as Diver).known_spells.duplicate(),
			"equipped_spells": (world.divers[index] as Diver).equipped_spells.duplicate(),
		})
	var inventory_before := world.inventory.duplicate(true)
	var keys_before := world.key_items.duplicate()

	world.inventory_menu.open()
	world._replay_tutorial_battle()
	await process_frame
	_expect(world.battling and world.battle != null and world.battle.tutorial_encounter,
		"MENU-REPLAY-1: replay did not enter the actual tutorial battle")
	_expect(not world.inventory_menu.visible,
		"MENU-REPLAY-1: practice battle left Inventory on screen")
	for diver_value in world.divers:
		var stats := (diver_value as Diver).stats
		_expect(stats.hp == stats.hp_max and is_equal_approx(stats.oxygen, stats.oxygen_max),
			"MENU-REPLAY-1: tutorial replay did not begin from a fair restored party")

	# Exercise the real World completion boundary. Battle's tutorial branch is
	# responsible for granting no XP; World returns a fair party to free roam
	# without granting items or keys.
	world._on_battle_finished("won")
	await process_frame
	for index in range(world.divers.size()):
		var stats := (world.divers[index] as Diver).stats
		var before := growth_before[index]
		_expect(stats.hp == stats.hp_max and is_equal_approx(stats.oxygen, stats.oxygen_max),
			"MENU-REPLAY-1: practice did not return a fully restored party")
		_expect(stats.level == int(before.level) and stats.xp == int(before.xp)
			and stats.spell_points == int(before.spell_points)
			and (world.divers[index] as Diver).known_spells == before.known_spells
			and (world.divers[index] as Diver).equipped_spells == before.equipped_spells,
			"MENU-REPLAY-1: practice changed real growth or spells")
	_expect(world.inventory == inventory_before and world.key_items == keys_before,
		"MENU-REPLAY-1: practice granted or consumed campaign rewards")
	_expect(not world.battling and world.battle == null,
		"MENU-REPLAY-1: practice did not return cleanly to the world")
	await process_frame
	var popup := root.get_node_or_null("CharacterAbilityPopup")
	if popup != null and popup.has_method("close"):
		popup.call("close")
	paused = false

func _test_spell_review_route(world: World) -> void:
	world.title_screen.open()
	await process_frame
	_expect(_button_named(world.title_screen, "Play Spell Test") == null,
		"MENU-TITLE-4: ordinary title leaks the spell review action")
	world.title_screen.enable_spell_playtest()
	await process_frame
	var spell_button := _button_named(world.title_screen, "Play Spell Test")
	_expect(spell_button != null,
		"MENU-SPELL-3: enabled review route has no visible title action")
	if spell_button == null:
		return
	spell_button.pressed.emit()
	await process_frame
	_expect(world._current_slot < 0 and not world.title_screen.visible
		and world.get_node("HUD").visible and not paused,
		"MENU-SPELL-3: spell review did not enter save-free free roam")
	for item_id in Items.ITEMS:
		if Items.is_key_item(String(item_id)):
			_expect(world.key_items.has(String(item_id)),
				"MENU-SPELL-3: spell review omitted key item %s" % item_id)
	for diver_value in world.divers:
		var diver := diver_value as Diver
		var expected_count := 0
		for branch in SpellTree.branches(diver.model_name):
			for spell_id in SpellTree.tree_for(diver.model_name)[branch]:
				expected_count += 1
				_expect(diver.known_spells.has(String(spell_id)),
					"MENU-SPELL-3: %s is not learned for %s" % [spell_id, diver.model_name])
		_expect(diver.known_spells.size() == expected_count,
			"MENU-SPELL-3: %s spell review has an incomplete or duplicate learned set" % diver.model_name)
		_expect(diver.stats.spell_points < 99,
			"MENU-SPELL-3: spell review did not pay real spell costs")
	var guard_break := SpellTree.spell_def("Prototype_V(1922)", "debuff", "guard_break")
	_expect(int(guard_break.get("acc_mod", 999)) == 4,
		"MENU-SPELL-3: Guard Break no longer matches the approved current move table")

	world.inventory_menu.open()
	world.inventory_menu.call("_switch_to", "spells_root")
	await process_frame
	_expect(_button_containing(world.inventory_menu, "Mending Current") != null,
		"MENU-SPELL-3: learned inventory spells are absent from Party Spells")
	_expect(_label_named(world.inventory_menu, "No party spells known yet.") == null,
		"MENU-SPELL-3: Party Spells incorrectly reports an empty learned roster")
	world.inventory_menu.close()

func _test_title_review_route_composition(world: World) -> void:
	world.title_screen.open()
	world.title_screen.enable_boss_playtest()
	world.title_screen.enable_special_playtest()
	world.title_screen.enable_spell_playtest()
	world.title_screen.enable_skip_tutorial()
	await process_frame
	for label in [
		"Play Tethys Boss Test",
		"Play Special Encounter Test",
		"Play Spell Test",
		"New Game (Skip Tutorial)",
	]:
		_expect(_button_named(world.title_screen, label) != null,
			"MENU-TITLE-4: review route disappeared after composition: %s" % label)
	world.title_screen.close()

func _button_named(node: Node, text_value: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == text_value:
			return child as Button
		var nested := _button_named(child, text_value)
		if nested != null:
			return nested
	return null

func _button_containing(node: Node, text_value: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text.contains(text_value):
			return child as Button
		var nested := _button_containing(child, text_value)
		if nested != null:
			return nested
	return null

func _label_named(node: Node, text_value: String) -> Label:
	for child in node.get_children():
		if child is Label and (child as Label).text == text_value:
			return child as Label
		var nested := _label_named(child, text_value)
		if nested != null:
			return nested
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish(world: World) -> void:
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	for failure in failures:
		push_error(failure)
	print("MENUS / SPELLS / TITLE: %s" % ("clean" if failures.is_empty() else "%d failure(s)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
