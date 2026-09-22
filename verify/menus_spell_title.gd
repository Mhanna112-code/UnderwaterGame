# Slice 3 regression contract for raw #72 menu, spell, and title extraction.
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

	# This represents the normal post-tutorial campaign state: world controls
	# are live and the onboarding was already completed, so a voluntary replay
	# must not hand the player another modal or turn practice into a reset.
	world.title_screen.close()
	world.get_node("HUD").visible = true
	paused = false
	world._first_encounter_done = true
	world._ability_onboarding_shown = true
	await _test_combat_help_surface(world)
	await _test_inventory_item_surface(world)
	_seed_campaign_state(world)
	var before := _campaign_state(world)

	if not world.has_method("_replay_tutorial_battle"):
		failures.append("MENU-REPLAY-1: Combat Help cannot replay the tutorial without a campaign-mutating workaround")
		_finish(world)
		return

	world.inventory_menu.open()
	world.call("_replay_tutorial_battle")
	await process_frame
	_expect(world.battling and world.battle != null and world.battle.tutorial_encounter,
		"MENU-REPLAY-1: replay did not enter the actual tutorial battle")
	_expect(not world.inventory_menu.visible,
		"MENU-REPLAY-1: practice battle left the pause menu on screen")

	# Simulate the effects that a genuine tutorial victory has on party state:
	# battle XP, refill/recovery, temporary effects, and evasion. The World
	# completion handler must restore the campaign snapshot afterward.
	for diver_value in world.divers:
		var stats := (diver_value as Diver).stats
		stats.hp = stats.hp_max
		stats.oxygen = stats.oxygen_max
		stats.level += 1
		stats.xp += 17
		stats.spell_points += 1
		stats.statuses.clear()
		stats.temporary_modifiers = {"accuracy": 0, "evasion": 0}
		stats.evasion_current = stats.evasion
	world._on_battle_finished("won")
	await process_frame

	_expect(_campaign_state(world) == before,
		"MENU-REPLAY-1: finishing practice changed real HP/O2/XP/level/status/evasion state")
	_expect(not world.battling and world.battle == null,
		"MENU-REPLAY-1: practice did not return cleanly to the world")
	await _test_spell_review_route(world)
	await _test_title_review_route_composition(world)
	_finish(world)

func _seed_campaign_state(world: World) -> void:
	for index in range(world.divers.size()):
		var stats := (world.divers[index] as Diver).stats
		stats.hp = maxi(1, stats.hp_max - (index + 1))
		stats.oxygen = maxf(1.0, stats.oxygen_max - float((index + 1) * 7))
		stats.xp = index + 3
		stats.spell_points = index
		stats.evasion_current = maxi(0, stats.evasion - index)
		stats.statuses = {"bleed": {"level": index + 1, "turns": 0}}
		stats.temporary_modifiers = {"accuracy": -index, "evasion": -index}

func _test_combat_help_surface(world: World) -> void:
	world.inventory_menu.open()
	world.inventory_menu.call("_switch_to", "help")
	await process_frame
	var scroll := world.inventory_menu.find_child("ContentScroll", true, false) as ScrollContainer
	_expect(scroll != null and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and scroll.custom_minimum_size.y >= 300.0,
		"MENU-HELP-2: Combat Help has no vertical reading surface for stats, effects, and statuses")
	_expect(_button_named(world.inventory_menu, "Replay Tutorial Fight") != null,
		"MENU-HELP-2: Combat Help does not expose the safe tutorial replay action")
	_expect(_label_named(world.inventory_menu, "Stats") != null and _label_named(world.inventory_menu, "Effects") != null and _label_named(world.inventory_menu, "Status Conditions") != null,
		"MENU-HELP-2: Combat Help does not separate stats, effects, and statuses")
	world.inventory_menu.close()

# The menu is the public boundary for consumables: a player should see the
# usable item, choose it once, receive precisely its documented effect, and
# never lose a second copy through a refresh or stale button signal.
func _test_inventory_item_surface(world: World) -> void:
	var diver := world.divers[world.active] as Diver
	diver.stats.hp = maxi(1, diver.stats.hp_max - 13)
	var before_hp := diver.stats.hp
	world.inventory = {"potion": 1}
	world.inventory_menu.open()
	await process_frame
	var potion_button := _button_with_prefix(world.inventory_menu, "Use Potion")
	_expect(potion_button != null and not potion_button.disabled,
		"MENU-ITEM-6: a documented usable potion is not selectable from Inventory")
	if potion_button != null:
		potion_button.pressed.emit()
		await process_frame
	_expect(diver.stats.hp == mini(diver.stats.hp_max, before_hp + 10),
		"MENU-ITEM-6: Inventory did not apply exactly Potion's documented 10 HP effect")
	_expect(not world.inventory.has("potion"),
		"MENU-ITEM-6: one Inventory click did not consume exactly one item")
	_expect(world.inventory_menu.visible,
		"MENU-ITEM-6: applying an item unexpectedly closes or softlocks Inventory")
	world.inventory_menu.close()

func _test_spell_review_route(world: World) -> void:
	if not world.has_method("_on_title_spell_playtest") or not world.title_screen.has_method("enable_spell_playtest"):
		failures.append("MENU-SPELL-3: title has no direct spell review route")
		return
	# No review flag means no developer action leaks into the ordinary title.
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
	_expect(world._current_slot < 0 and not world.title_screen.visible and world.get_node("HUD").visible and not paused,
		"MENU-SPELL-3: spell review did not enter a save-free playable UI state")
	_expect(world.save_point_menu.visible,
		"MENU-SPELL-3: spell review does not open the actual spell interface")
	for item_id in Items.ITEMS:
		if Items.is_key_item(String(item_id)):
			_expect(world.key_items.has(String(item_id)),
				"MENU-SPELL-3: spell review omitted key item %s" % item_id)
	for diver_value in world.divers:
		var diver := diver_value as Diver
		_expect(diver.stats.spell_points >= 99,
			"MENU-SPELL-3: %s lacks review spell points" % diver.model_name)
		var learned_any := true
		while learned_any:
			learned_any = false
			for branch in SpellTree.branches(diver.model_name):
				for spell_id in SpellTree.tree_for(diver.model_name)[branch]:
					if SpellTree.learn(diver, branch, String(spell_id), world.key_items):
						learned_any = true
		for branch in SpellTree.branches(diver.model_name):
			for spell_id in SpellTree.tree_for(diver.model_name)[branch]:
				_expect(diver.known_spells.has(String(spell_id)),
					"MENU-SPELL-3: %s is not learnable in review mode for %s" % [spell_id, diver.model_name])
	var guard_break := SpellTree.spell_def("Prototype_V(1922)", "debuff", "guard_break")
	_expect(int(guard_break.get("acc_mod", 999)) == 0,
		"MENU-SPELL-3: menu extraction changed Guard Break accuracy instead of preserving combat reconciliation for Slice 5")

func _test_title_review_route_composition(world: World) -> void:
	world.save_point_menu.close()
	world.title_screen.open()
	# Guardian is intentionally enabled while the title is already live. This
	# catches a stale screen even when later feature flags happen to rebuild it.
	world.title_screen.enable_guardian_playtest("Play Guardian Test")
	await process_frame
	_expect(_button_named(world.title_screen, "Play Guardian Test") != null,
		"MENU-TITLE-4: a live guardian-review flag did not refresh the title")
	world.title_screen.enable_boss_playtest()
	world.title_screen.enable_special_playtest()
	world.title_screen.enable_onboarding_playtest()
	# Spell was enabled by the real signal route above. Every action must still
	# render together after a live title refresh, rather than one flag replacing
	# a previous review surface as raw #72 did.
	await process_frame
	for label in [
		"Play Tethys Boss Test", "Play Guardian Test", "Play Special Encounter Test",
		"Review World Controls", "Play Spell Test",
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

func _button_with_prefix(node: Node, prefix: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text.begins_with(prefix):
			return child as Button
		var nested := _button_with_prefix(child, prefix)
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

func _campaign_state(world: World) -> Array:
	var snapshot: Array = []
	for diver_value in world.divers:
		var stats := (diver_value as Diver).stats
		snapshot.append({
			"hp": stats.hp, "oxygen": stats.oxygen, "level": stats.level,
			"xp": stats.xp, "spell_points": stats.spell_points,
			"evasion_current": stats.evasion_current,
			"statuses": stats.statuses.duplicate(true),
			"temporary_modifiers": stats.temporary_modifiers.duplicate(true),
		})
	return snapshot

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish(world: World) -> void:
	world.queue_free()
	for failure in failures:
		push_error(failure)
	print("MENUS / SPELLS / TITLE: %s" % ("clean" if failures.is_empty() else "%d failure(s)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
