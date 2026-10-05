# Tethys shrugs off every stat-lowering effect but still takes damage and
# damage-over-time.
#
# Bugs caught:
# - IMMUNE-01: Electric Touch / Defense Down / Blindness / Evasion Down still
#   lower an immune boss's stats, or the hit stops dealing its damage.
# - IMMUNE-02: a legacy Weaken/Slow-style debuff still lowers the stat.
# - IMMUNE-03: Bleed is wrongly blocked, or ordinary enemies became immune.
#
# Usage: godot --headless --path . --script verify/tethys_immunity.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	var boss := TethysBoss.new()
	var tethys := boss.make_stats(CombatantStats.new())
	boss.free()
	_expect(tethys.immune_to_stat_loss, "IMMUNE-01 Tethys stats are not flagged immune")
	var attacker := CombatantStats.new()
	attacker.strength = 3
	attacker.accuracy = 9
	attacker.defense = 2
	attacker.fill()

	var before := [tethys.evasion, tethys.defense, tethys.effective_accuracy(), tethys.effective_defense(), tethys.effective_evasion()]
	for effect in [
		{"kind": "reduce_evasion", "amount": {"accuracy": 1}},
		{"kind": "reduce_defense", "amount": {"defense": 1}},
		{"kind": "status", "status": "blindness", "level": {"flat": 2}, "duration": {"flat": 3}},
		{"kind": "status", "status": "evasion_down", "level": {"flat": 2}, "duration": {"flat": 3}},
		{"kind": "status", "status": "defense_down", "level": {"flat": 2}, "duration": 3},
	]:
		tethys.evasion_current = 0
		var hp := tethys.hp
		var r := CombatRules.resolve(attacker, tethys, {"name": "Test", "formula": {"strength": 1}, "effects": [effect]})
		_expect(bool(r.get("immune", false)), "IMMUNE-01 %s did not report immunity" % String(effect.get("status", effect.kind)))
		_expect(tethys.hp < hp, "IMMUNE-01 immunity also blocked the hit's damage")
	var after := [tethys.evasion, tethys.defense, tethys.effective_accuracy(), tethys.effective_defense(), tethys.effective_evasion()]
	_expect(before == after, "IMMUNE-01 an immune boss's stats changed: %s -> %s" % [before, after])

	var battle := Battle.new()
	var debuff := battle._apply_debuff(tethys, "defense", 2)
	_expect(bool(debuff.get("immune", false)) and tethys.defense == int(before[1]), "IMMUNE-02 legacy debuff lowered an immune boss's Defense")
	battle.free()

	tethys.evasion_current = 0
	CombatRules.resolve(attacker, tethys, {"name": "Stab", "formula": {"strength": 1}, "effects": [{"kind": "status", "status": "bleed", "level": {"flat": 2}}]})
	_expect(tethys.status_level("bleed") == 2, "IMMUNE-03 Bleed must still apply to Tethys")

	var grunt := CombatantStats.new()
	grunt.evasion = 3
	grunt.fill()
	grunt.evasion_current = 0
	CombatRules.resolve(attacker, grunt, {"name": "Touch", "formula": {"strength": 1}, "effects": [{"kind": "reduce_evasion", "amount": {"accuracy": 1}}]})
	_expect(grunt.evasion == 0, "IMMUNE-03 an ordinary enemy became immune to Electric Touch")

	print("TETHYS IMMUNITY: clean" if findings.is_empty() else "TETHYS IMMUNITY: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
		print("FINDING  ", message)
