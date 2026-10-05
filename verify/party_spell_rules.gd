# Out-of-battle Party Spells: downed divers can't cast, heals never revive,
# and a refused cast spends no Oxygen.
#
# Bugs caught:
# - SPELL-01: a downed caster can still cast from the Esc Party Spells menu.
# - SPELL-02: a heal spell (Mending Current) brings a downed diver back.
# - SPELL-03: a refused heal/revive still spends the caster's Oxygen.
# - SPELL-04: Tidal Revival no longer revives a downed diver.
# - SPELL-05: a Potion heals or revives a downed diver.
#
# Usage: godot --headless --path . --script verify/party_spell_rules.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	var caster := world.divers[2] as Diver
	var downed := world.divers[0] as Diver
	var mend := SpellTree.find_def(caster.model_name, "mending_current")
	var revive := SpellTree.find_def(caster.model_name, "tidal_revival")
	_expect(not mend.is_empty() and not revive.is_empty(), "SPELL setup: support spells missing")

	for d in world.divers:
		(d as Diver).stats.fill()
	caster.stats.hp = 0
	_expect(not world.can_afford_party_spell(mend, caster), "SPELL-01 a downed caster can still cast")
	caster.stats.fill()

	downed.stats.hp = 0
	var o2 := caster.stats.oxygen
	world.use_party_spell(mend, caster, downed)
	_expect(downed.stats.hp == 0, "SPELL-02 Mending Current revived a downed diver")
	_expect(is_equal_approx(caster.stats.oxygen, o2), "SPELL-03 refused heal spent Oxygen")

	var living := world.divers[1] as Diver
	world.use_party_spell(mend, caster, living)
	_expect(is_equal_approx(caster.stats.oxygen, o2), "SPELL-03 heal on a full-HP diver spent Oxygen")
	world.use_party_spell(revive, caster, living)
	_expect(is_equal_approx(caster.stats.oxygen, o2), "SPELL-03 refused revive spent Oxygen")

	world.use_party_spell(revive, caster, downed)
	_expect(downed.stats.hp > 0, "SPELL-04 Tidal Revival did not revive a downed diver")
	_expect(caster.stats.oxygen < o2, "SPELL-04 a successful revive spent no Oxygen")

	var potion_target := CombatantStats.new()
	potion_target.fill()
	potion_target.hp = 0
	_expect(not Items.would_help("potion", potion_target) and Items.grant("potion", potion_target) == "" and potion_target.hp == 0,
		"SPELL-05 a Potion heals or revives a downed diver")

	world.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	print("PARTY SPELL RULES: clean" if findings.is_empty() else "PARTY SPELL RULES: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
		print("FINDING  ", message)
