# `spell playtest: title route provides learned spells — guards against empty
# Party Spells`.
#
# Drives World._on_title_spell_playtest() directly (same pattern
# verify/special_encounters.gd uses for its own playtest route) rather than
# actually pressing the title button, then proves the thing the route
# promises. Max spell points and every key item only remove the POINTS/ITEM
# gates SpellTree.can_learn() checks. This test deliberately does NOT call
# SpellTree.learn() itself: doing so was hiding the real production defect
# where the human-facing route supplied resources but no learned spells.
#
# Usage: godot --headless --path . --script verify/spell_playtest.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame

	world._on_title_spell_playtest()
	await process_frame

	for d_value in world.divers:
		var d := d_value as Diver

		var all_spell_ids: Array[String] = []
		for branch in SpellTree.branches(d.model_name):
			for spell_id in SpellTree.tree_for(d.model_name)[branch]:
				all_spell_ids.append(String(spell_id))

		for spell_id in all_spell_ids:
			_expect(d.known_spells.has(spell_id),
				"SPELL PLAYTEST: %s is not learned for %s after selecting Spell Test" % [spell_id, d.model_name])
			_expect(d.equipped_spells.has(spell_id),
				"SPELL PLAYTEST: %s is learned but not equipped for %s" % [spell_id, d.model_name])

	var visible_party_spells := 0
	for d_value in world.divers:
		visible_party_spells += world._inventory_spells_for(d_value as Diver).size()
	_expect(visible_party_spells > 0,
		"SPELL PLAYTEST: Party Spells has no usable support action after selecting Spell Test")
	_expect(world._current_slot == -1,
		"SPELL PLAYTEST: review route assigned a save slot")

	if findings.is_empty():
		print("spell playtest        prepared roster is learned, equipped, and visible")
		quit(0)
		return
	for finding in findings:
		print("FINDING  " + finding)
	quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
