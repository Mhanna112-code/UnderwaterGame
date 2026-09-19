# `spell playtest: every spell in every diver's tree becomes learnable
# immediately, no leveling or key-item grind required`.
#
# Drives World._on_title_spell_playtest() directly (same pattern
# verify/special_encounters.gd uses for its own playtest route) rather than
# actually pressing the title button, then proves the thing the route
# promises. Max spell points and every key item only remove the POINTS/ITEM
# gates SpellTree.can_learn() checks - a spell with "requires_spells" still
# needs that prerequisite actually learned first, same as real play, so this
# walks each tree to completion (repeatedly learning whatever's newly
# learnable) rather than expecting every node learnable in one pass.
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
		_expect(d.stats.spell_points >= 99,
			"SPELL PLAYTEST: %s has %d spell points, expected at least 99" % [d.model_name, d.stats.spell_points])

		var all_spell_ids: Array[String] = []
		for branch in SpellTree.branches(d.model_name):
			for spell_id in SpellTree.tree_for(d.model_name)[branch]:
				all_spell_ids.append(String(spell_id))

		var progressed := true
		while progressed:
			progressed = false
			for branch in SpellTree.branches(d.model_name):
				for spell_id in SpellTree.tree_for(d.model_name)[branch].keys():
					if SpellTree.learn(d, branch, String(spell_id), world.key_items):
						progressed = true

		for spell_id in all_spell_ids:
			_expect(d.known_spells.has(spell_id),
				"SPELL PLAYTEST: %s never became learnable for %s even with max points and every key item" % [spell_id, d.model_name])

	if findings.is_empty():
		print("spell playtest        every spell in every tree became learnable")
		quit(0)
		return
	for finding in findings:
		print("FINDING  " + finding)
	quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
