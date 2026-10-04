# Contract gate for Glassgoat's authored Swordfish Duelist kit.
#
# Usage: godot --headless --path . --script verify/swordfish_moves.gd
extends SceneTree

const SwordDuelistActor = preload("res://game/sword_duelist.gd")
const EnemyMoveData = preload("res://content/enemy_moves.gd")

var findings: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_authored_floor_stats()
	await _test_catalogue_and_clips()
	_test_two_target_scope()
	_test_triple_combo_sequence()
	_finish()

func _test_authored_floor_stats() -> void:
	_expect(SwordDuelistActor.DUELIST_FLOOR_STATS == {
		"hp": 8, "strength": 2, "defense": 1, "agility": 6,
		"evasion": 4, "accuracy": 3,
	}, "SWORDFISH STATS DRIFT: expected Group_StatsV2's 8/2/1/6/4/3 floor block")
	var duelist := SwordDuelistActor.new()
	var inflated_reference := _stats(99, 9, 9, 9, 9, 9)
	var spawned := duelist.make_stats(inflated_reference, 5)
	_expect([spawned.hp_max, spawned.strength, spawned.defense, spawned.agility, spawned.evasion, spawned.accuracy] == [8, 2, 1, 6, 4, 3],
		"SWORDFISH SPAWN STATS DRIFT: a Swordfish encounter must use Glassgoat's authored 8/2/1/6/4/3 values, not a party-scaled generic enemy")
	duelist.free()

func _test_catalogue_and_clips() -> void:
	var expected := {
		"arc_slash": {
			"name": "Arc Slash", "clip": "attack)greatslash", "target": "two",
			"formula": {"strength": 1, "defense": 1},
			"effect": {"kind": "status", "status": "bleed", "level": {"strength": 1}},
		},
		"triple_combo": {
			"name": "Triple Combo", "clip": "attack)stabbing", "target": "single",
			"formula": {"strength": 1}, "hits": 3,
		},
		"spinning_slayer": {
			"name": "Spinning Slayer", "clip": "attack)spinning_drill", "target": "single",
			"formula": {"strength": 1, "defense": 1},
			"effect": {"kind": "reduce_defense", "amount": {"defense": 1}},
		},
	}
	var by_id := {}
	for move_value in EnemyMoveData.swordfish_duelist_catalogue():
		var move := move_value as Dictionary
		by_id[String(move.get("id", ""))] = move
	_expect(by_id.size() == expected.size(),
		"SWORDFISH KIT INCOMPLETE: expected exactly Arc Slash, Triple Combo, and Spinning Slayer")

	var duelist := SwordDuelistActor.new()
	root.add_child(duelist)
	await process_frame
	await process_frame
	for move_id_value in expected.keys():
		var move_id := String(move_id_value)
		var specification := expected[move_id] as Dictionary
		var move := by_id.get(move_id, {}) as Dictionary
		_expect(bool(move.get("enabled", false)),
			"SWORDFISH KIT INCOMPLETE: %s must be enabled" % String(specification.name))
		_expect(String(move.get("name", "")) == String(specification.name) and String(move.get("target", "")) == String(specification.target),
			"SWORDFISH MOVE IDENTITY DRIFT: %s must keep its authored name and target scope" % move_id)
		_expect(move.get("combat", {}).get("formula", {}) == specification.formula,
			"SWORDFISH FORMULA DRIFT: %s must use %s" % [String(specification.name), specification.formula])
		if specification.has("hits"):
			_expect(int(move.get("combat", {}).get("hits", 1)) == int(specification.hits),
				"SWORDFISH TRIPLE COMBO: must resolve exactly three hits")
		if specification.has("effect"):
			_expect((move.get("combat", {}).get("effects", []) as Array).has(specification.effect),
				"SWORDFISH EFFECT DRIFT: %s must retain its authored effect" % String(specification.name))
		_expect(duelist.has_clip_fragment(String(specification.clip)),
			"SWORDFISH CLIP MISSING: %s cannot resolve '%s' on the imported actor" % [String(specification.name), String(specification.clip)])
		_expect(duelist.play_move(move) > 0.0,
			"SWORDFISH CLIP DOES NOT PLAY: %s returned no animation duration" % String(specification.name))
	duelist.queue_free()
	await process_frame

func _test_two_target_scope() -> void:
	var primary := {"label": "Maxilani", "stats": _stats(10, 1, 0, 3, 3, 3)}
	var second := {"label": "Marine Man", "stats": _stats(10, 2, 2, 2, 2, 2)}
	var targets: Array = Battle.enemy_targets_for_scope(primary, [primary, second], "two")
	_expect(targets.size() == 2 and targets[0] == primary and targets[1] == second,
		"SWORDFISH TWO-TARGET DISPATCH: Arc Slash must retain the selected primary and one other living diver")
	var lone: Array = Battle.enemy_targets_for_scope(primary, [primary], "two")
	_expect(lone.size() == 1 and lone[0] == primary,
		"SWORDFISH TWO-TARGET FALLBACK: Arc Slash must degrade safely to its sole living target")

func _test_triple_combo_sequence() -> void:
	var attacker := _stats(20, 2, 0, 1, 0, 3)
	var defender := _stats(20, 1, 0, 1, 4, 0)
	var triple: Dictionary = _swordfish_move("triple_combo").get("combat", {})
	var results: Array = Battle.resolve_formula_hits(attacker, defender, triple)
	_expect(results.size() == 3,
		"SWORDFISH TRIPLE COMBO: three hits must resolve all three impacts")
	_expect(results.size() == 3 and not bool((results[0] as Dictionary).get("hit", true)) and
		bool((results[1] as Dictionary).get("hit", false)) and bool((results[2] as Dictionary).get("hit", false)),
		"SWORDFISH TRIPLE COMBO: three hits must consume Evasion sequentially rather than resetting it per hit")
	_expect(defender.hp == 16,
		"SWORDFISH TRIPLE COMBO DAMAGE: two post-evasion Strength hits must deal four total damage")

func _swordfish_move(id: String) -> Dictionary:
	for move_value in EnemyMoveData.swordfish_duelist_catalogue():
		var move := move_value as Dictionary
		if String(move.get("id", "")) == id:
			return move
	return {}

func _stats(hp: int, strength: int, defense: int, agility: int, evasion: int, accuracy: int) -> CombatantStats:
	var stats := CombatantStats.new()
	stats.hp_max = hp
	stats.strength = strength
	stats.defense = defense
	stats.agility = agility
	stats.evasion = evasion
	stats.accuracy = accuracy
	stats.fill()
	return stats

func _finish() -> void:
	if findings.is_empty():
		print("SWORDFISH MOVES: clean")
		quit(0)
		return
	for finding in findings:
		print("FINDING  " + finding)
	print("SWORDFISH MOVES: %d finding(s)" % findings.size())
	quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
