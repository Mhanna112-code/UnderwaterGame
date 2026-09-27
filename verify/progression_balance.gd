# `progression balance: authored shallow/deep encounters meet quick-read and
# skilled success bands, with deep counters beating damage-only by 25 points
# — guards against a route that looks readable but has no strategic payoff`.
#
# This is deliberately a small production-shaped simulator. Enemy floor stats,
# actual move catalogues, CombatRules, legacy Battle damage resolution, turn
# order, status ticks, and the exact route rosters are live code. Only player
# choice policy and seeded variance/target selection belong to this gate.
extends SceneTree

const SEEDS := 240
const PERSISTENT_SEEDS := 60
const MAX_ROUNDS := 30
const CASES := [
	{"id": "shallow_angler", "label": "basic_angler", "quick_min": 90.0, "quick_max": 100.0, "skilled_min": 95.0},
	{"id": "shallow_frilled_shark", "label": "basic_frilled", "quick_min": 90.0, "quick_max": 100.0, "skilled_min": 95.0},
	{"id": "shallow_capstone", "label": "shallow_capstone", "quick_min": 80.0, "quick_max": 95.0, "skilled_min": 95.0},
	{"id": "deep_swordfish", "label": "deep_swordfish", "quick_min": 80.0, "quick_max": 100.0, "skilled_min": 95.0},
	{"id": "deep_sea_urchin", "label": "deep_sea_urchin", "quick_min": 80.0, "quick_max": 100.0, "skilled_min": 95.0},
	{"id": "deep_capstone", "label": "deep_capstone", "quick_min": 70.0, "quick_max": 100.0, "skilled_min": 90.0, "counter_gap": 25.0},
]

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for case_value in CASES:
		var spec := case_value as Dictionary
		var beat := _route_beat(String(spec.id))
		# Capstones occur after tutorial XP, prior encounters, recovery and a
		# checkpoint. A synthetic fresh level-one party is not a player-reachable
		# capstone state; their authored bands are asserted below from the
		# persistent campaign trace instead.
		if bool(beat.get("capstone", false)):
			print("%-18s measured in persistent campaign state" % String(spec.label))
			continue
		var roster := beat.get("roster", []) as Array
		var modifiers := beat.get("enemy_modifiers", []) as Array
		var quick := _rate(roster, modifiers, "quick_read")
		var skilled := _rate(roster, modifiers, "skilled")
		var damage_only := _rate(roster, modifiers, "damage_only")
		print("%-18s damage-only %5.1f%%  quick-read %5.1f%%  skilled %5.1f%%" % [String(spec.label), damage_only, quick, skilled])
		_expect(quick >= float(spec.quick_min) and quick <= float(spec.quick_max),
			"%s QUICK-READ OUT OF BAND: %.1f%% expected %.1f-%.1f%%" % [String(spec.id), quick, float(spec.quick_min), float(spec.quick_max)])
		_expect(skilled >= float(spec.skilled_min),
			"%s SKILLED TOO WEAK: %.1f%% expected at least %.1f%%" % [String(spec.id), skilled, float(spec.skilled_min)])
		if spec.has("counter_gap"):
			_expect(quick - damage_only >= float(spec.counter_gap),
				"DEEP COUNTER GAP: quick-read %.1f%% minus damage-only %.1f%% is below %.1f points" % [quick, damage_only, float(spec.counter_gap)])
	# The per-encounter bands above catch local tuning regressions. This second
	# pass is intentionally not a reset: it starts after the real 30-XP tutorial
	# reward, carries the same party through every ordered beat, applies the
	# standard post-victory recovery, and performs the full checkpoint restore
	# the route promises before/after capstones.
	var route_rates := {}
	for policy in ["damage_only", "casual", "quick_read", "skilled"]:
		var rates := _persistent_route_rates(policy)
		route_rates[policy] = rates
		print("persistent %-11s %5.1f%% complete | shallow cap %5.1f%% | deep cap %5.1f%%" % [
			policy, float(rates.complete), float(rates.shallow_capstone), float(rates.deep_capstone)])
	var quick := route_rates.quick_read as Dictionary
	var skilled := route_rates.skilled as Dictionary
	var damage_only := route_rates.damage_only as Dictionary
	_expect(float(quick.shallow_capstone) >= 80.0 and float(quick.shallow_capstone) <= 95.0,
		"PERSISTENT SHALLOW QUICK-READ OUT OF BAND: %.1f%% expected 80-95%%" % float(quick.shallow_capstone))
	_expect(float(skilled.shallow_capstone) >= 95.0,
		"PERSISTENT SHALLOW SKILLED WALL: %.1f%% expected at least 95%%" % float(skilled.shallow_capstone))
	_expect(float(quick.deep_capstone) >= 70.0,
		"PERSISTENT DEEP QUICK-READ WALL: %.1f%% expected at least 70%%" % float(quick.deep_capstone))
	_expect(float(skilled.deep_capstone) >= 90.0,
		"PERSISTENT DEEP SKILLED WALL: %.1f%% expected at least 90%%" % float(skilled.deep_capstone))
	_expect(float(quick.deep_capstone) - float(damage_only.deep_capstone) >= 25.0,
		"PERSISTENT DEEP COUNTER GAP: quick-read %.1f%% minus damage-only %.1f%% is below 25 points" % [float(quick.deep_capstone), float(damage_only.deep_capstone)])
	_expect(float(quick.complete) >= 70.0 and float(skilled.complete) >= 80.0,
		"PERSISTENT ROUTE COMPLETION WALL: quick-read %.1f%% / skilled %.1f%%" % [float(quick.complete), float(skilled.complete)])
	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("progression balance    authored route bands and deep counter gap hold")
	quit(0 if findings.is_empty() else 1)

func _route_beat(id: String) -> Dictionary:
	for beat_value in RouteProgression.BEATS:
		var beat := beat_value as Dictionary
		if String(beat.id) == id:
			return beat
	return {}

func _rate(roster: Array, modifiers: Array, policy: String) -> float:
	var wins := 0
	for seed_value in range(SEEDS):
		if _fight(roster, modifiers, policy, seed_value):
			wins += 1
	return 100.0 * float(wins) / float(SEEDS)

func _fight(roster: Array, modifiers: Array, policy: String, seed_value: int) -> bool:
	return _fight_with_party(_party(), roster, modifiers, policy, seed_value)

func _fight_with_party(party: Array, roster: Array, modifiers: Array, policy: String, seed_value: int) -> bool:
	# Keep the random stream per encounter stable while allowing the caller to
	# carry the actual party Resources from one route beat into the next.
	seed(700000 + seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900000 + seed_value
	var average := _average_stats(party)
	var enemies: Array = []
	for index in range(roster.size()):
		var modifier := modifiers[index] as Dictionary if index < modifiers.size() else {}
		enemies.append(_enemy(String(roster[index]), average, modifier))
	for _round in range(MAX_ROUNDS):
		if _living(party).is_empty() or _living(enemies).is_empty():
			break
		var queue := _living(party) + _living(enemies)
		queue.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var a := left.stats as CombatantStats
			var b := right.stats as CombatantStats
			if a.effective_agility() == b.effective_agility():
				return String(left.kind) == "party" and String(right.kind) != "party"
			return a.effective_agility() > b.effective_agility())
		for actor_value in queue:
			var actor := actor_value as Dictionary
			var stats := actor.stats as CombatantStats
			if stats.hp <= 0 or _living(party).is_empty() or _living(enemies).is_empty():
				continue
			if stats.is_stunned():
				stats.consume_status_turn("stun")
				continue
			stats.begin_turn()
			if String(actor.kind) == "party":
				_party_turn(actor, enemies, policy, rng)
			else:
				_enemy_turn(actor, party, rng)
			stats.end_turn()
	return _living(enemies).is_empty()

func _persistent_route_rates(policy: String) -> Dictionary:
	var complete := 0
	var shallow_capstone := 0
	var deep_capstone := 0
	for seed_value in range(PERSISTENT_SEEDS):
		var outcome := _persistent_route_outcome(policy, seed_value)
		if bool(outcome.complete):
			complete += 1
		var beaten := outcome.beaten as Dictionary
		if bool(beaten.get("shallow_capstone", false)):
			shallow_capstone += 1
		if bool(beaten.get("deep_capstone", false)):
			deep_capstone += 1
	return {
		"complete": 100.0 * float(complete) / float(PERSISTENT_SEEDS),
		"shallow_capstone": 100.0 * float(shallow_capstone) / float(PERSISTENT_SEEDS),
		"deep_capstone": 100.0 * float(deep_capstone) / float(PERSISTENT_SEEDS),
	}

func _persistent_route_outcome(policy: String, seed_value: int) -> Dictionary:
	var party := _party()
	var beaten := {}
	# The normal route begins only after the tutorial win, which awards its
	# guaranteed 30 XP to every diver. This changes the live party's stats and
	# must not be silently omitted from a campaign-balance claim.
	_award_party_xp(party, 30)
	for index in range(CASES.size()):
		var spec := CASES[index] as Dictionary
		var beat := _route_beat(String(spec.id))
		if bool(beat.get("capstone", false)):
			_restore_checkpoint_resources(party)
		var won := _fight_with_party(
			party,
			beat.get("roster", []) as Array,
			beat.get("enemy_modifiers", []) as Array,
			policy,
			seed_value * 31 + index
		)
		if not won:
			return {"complete": false, "beaten": beaten}
		beaten[String(spec.id)] = true
		_award_party_xp(party, 10 * (beat.get("roster", []) as Array).size())
		if bool(beat.get("capstone", false)):
			_restore_checkpoint_resources(party)
		else:
			for entry_value in party:
				(entry_value as Dictionary).stats.recover_after_victory()
	return {"complete": true, "beaten": beaten}

func _restore_checkpoint_resources(party: Array) -> void:
	for entry_value in party:
		(entry_value as Dictionary).stats.fill()

func _award_party_xp(party: Array, amount: int) -> void:
	for entry_value in party:
		(entry_value as Dictionary).stats.gain_xp(amount)

func _party() -> Array:
	return [
		{"kind": "party", "model": "Staff_Diver", "stats": _diver_stats("Staff_Diver")},
		{"kind": "party", "model": "Prototype_1(1910)", "stats": _diver_stats("Prototype_1(1910)")},
		{"kind": "party", "model": "Prototype_V(1922)", "stats": _diver_stats("Prototype_V(1922)")},
	]

func _diver_stats(model: String) -> CombatantStats:
	var base := Diver.BASE_STATS.get(model, {}) as Dictionary
	var stats := _stats(
		int(base.get("hp", 10)), int(base.get("strength", 1)), int(base.get("defense", 0)),
		int(base.get("agility", 1)), int(base.get("evasion", 0)), int(base.get("accuracy", 0)))
	for key in ["hp", "strength", "defense", "agility", "accuracy", "evasion"]:
		stats.set("grow_%s" % key, int(base.get("grow_%s" % key, 0)))
	return stats

func _enemy(id: String, reference: CombatantStats, modifier: Dictionary = {}) -> Dictionary:
	var actor: Goblin
	match id:
		"swordfish_duelist": actor = SwordDuelist.new()
		"frilled_shark": actor = FrilledShark.new()
		"sea_urchin": actor = SeaUrchin.new()
		_: actor = Goblin.new()
	var stats := actor.make_stats(reference, 1)
	for stat in ["hp_max", "strength", "defense", "agility", "evasion", "accuracy"]:
		if modifier.has(stat):
			stats.set(stat, int(modifier[stat]))
	stats.fill()
	actor.free()
	return {"kind": "enemy", "enemy_id": id, "stats": stats}

func _party_turn(actor: Dictionary, enemies: Array, policy: String, rng: RandomNumberGenerator) -> void:
	var target := _target_for_party(actor, _living(enemies), policy, rng)
	if target.is_empty():
		return
	var move := _move_for_party(actor, target, policy)
	if move.is_empty():
		return
	var stats := actor.stats as CombatantStats
	# Battle disables a move whose O2 cost cannot be paid (battle.gd's
	# _on_move_chosen()).  A simulator that lets an exhausted party keep
	# choosing Haymaker/Weaken would overstate both policies and make a
	# counterplay claim untrustworthy.  Model the same player-visible rule by
	# falling back to each diver's free, available move.
	if stats.oxygen < float(move.get("oxygen_cost", 0.0)):
		move = _free_fallback_move(actor)
	stats.oxygen -= float(move.get("oxygen_cost", 0.0))
	_apply(stats, target.stats as CombatantStats, move, rng)

func _free_fallback_move(actor: Dictionary) -> Dictionary:
	var model := String(actor.model)
	if model == "Staff_Diver":
		return CombatMoves.for_model(model)[1] as Dictionary # Scuba Stabbing
	return Battle.BASE_MOVES[model][0] as Dictionary # Precise Tap / Guard Bash

func _target_for_party(actor: Dictionary, enemies: Array, policy: String, rng: RandomNumberGenerator) -> Dictionary:
	if enemies.is_empty():
		return {}
	if policy == "damage_only":
		return enemies[0] as Dictionary
	var model := String(actor.model)
	if model == "Staff_Diver":
		for enemy_value in enemies:
			if String((enemy_value as Dictionary).enemy_id) == "swordfish_duelist":
				return enemy_value as Dictionary
	if model == "Prototype_1(1910)":
		for enemy_value in enemies:
			if String((enemy_value as Dictionary).enemy_id) == "sea_urchin":
				return enemy_value as Dictionary
	var lowest := enemies[0] as Dictionary
	for enemy_value in enemies:
		if int(((enemy_value as Dictionary).stats as CombatantStats).hp) < int((lowest.stats as CombatantStats).hp):
			lowest = enemy_value as Dictionary
	return lowest

func _move_for_party(actor: Dictionary, target: Dictionary, policy: String) -> Dictionary:
	var model := String(actor.model)
	var target_id := String(target.enemy_id)
	if model == "Staff_Diver":
		var scuba := CombatMoves.for_model(model)
		if policy == "damage_only":
			# Damage-only deliberately chases the largest immediately displayed
			# number (STR + ACC) and ignores Axe Kick's red self-EVA cost.
			return scuba[4] as Dictionary
		if policy != "damage_only" and target_id == "swordfish_duelist" and (target.stats as CombatantStats).evasion >= 2:
			return scuba[0] as Dictionary # Electric Touch
		# Axe Kick's self-EVA loss is visibly red risk, so a skilled reader does
		# not mash it into an enemy turn; Scuba Stabbing is the reliable follow-up.
		return scuba[1] as Dictionary
	if model == "Prototype_1(1910)":
		if policy != "damage_only" and target_id == "sea_urchin" and (target.stats as CombatantStats).defense >= 3:
			return Battle.BASE_MOVES[model][1] as Dictionary # Weaken
		return Battle.BASE_MOVES[model][0] as Dictionary # Precise Tap
	# Crushing Haymaker has the largest raw badge but a visible red accuracy
	# cost. Damage-only presses it anyway; a reader chooses reliable Heavy Kick
	# or the lower-cost Guard Bash rather than mistaking raw power for outcome.
	if policy == "damage_only":
		return Battle.BASE_MOVES[model][2] as Dictionary
	if policy != "damage_only":
		# Once the visible counter has opened the matchup, the readable green
		# follow-up is Heavy Kick: it ends the dangerous pair a turn sooner
		# without Haymaker's red accuracy risk.  This is intentionally part of
		# quick-read rather than a hidden expert-only rule; skilled play may
		# optimize targeting, but must not be required merely to survive.
		return Battle.BASE_MOVES[model][1] as Dictionary
	return Battle.BASE_MOVES[model][0] as Dictionary

func _enemy_turn(actor: Dictionary, party: Array, rng: RandomNumberGenerator) -> void:
	var targets := _living(party)
	if targets.is_empty():
		return
	var target := targets[rng.randi_range(0, targets.size() - 1)] as Dictionary
	var id := String(actor.enemy_id)
	var move: Dictionary
	match id:
		"frilled_shark": move = EnemyMoves.frilled_shark_catalogue()[rng.randi_range(0, 1)] as Dictionary
		"swordfish_duelist": move = EnemyMoves.swordfish_duelist_catalogue()[rng.randi_range(1, 2)] as Dictionary
		"sea_urchin": move = EnemyMoves.sea_urchin_catalogue()[0] as Dictionary
		_: move = EnemyMoves.angler_catalogue()[rng.randi_range(0, 2)] as Dictionary
	var combat := move.get("combat", {}) as Dictionary
	_apply(actor.stats as CombatantStats, target.stats as CombatantStats, combat, rng)

func _apply(attacker: CombatantStats, defender: CombatantStats, move: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if move.has("formula"):
		return CombatRules.resolve(attacker, defender, move)
	if String(move.get("debuff", "")) == "defense":
		if attacker.effective_accuracy() + int(move.get("acc_mod", 0)) > defender.evasion_current:
			return {"hit": true, "damage": 0, "changed": defender.reduce_defense(int(move.get("amount", 0)))}
		defender.spend_evasion(attacker.effective_accuracy() + int(move.get("acc_mod", 0)))
		return {"hit": false, "damage": 0}
	return Battle.apply_damage_roll(attacker, defender, move, rng.randf_range(0.85, 1.15))

func _average_stats(party: Array) -> CombatantStats:
	var out := CombatantStats.new()
	for key in ["hp_max", "strength", "defense", "agility", "evasion", "accuracy"]:
		var total := 0
		for actor_value in party:
			total += int((actor_value as Dictionary).stats.get(key))
		out.set(key, int(round(float(total) / float(party.size()))))
	out.fill()
	return out

func _stats(hp: int, strength: int, defense: int, agility: int, evasion: int, accuracy: int) -> CombatantStats:
	var out := CombatantStats.new()
	out.hp_max = hp
	out.strength = strength
	out.defense = defense
	out.agility = agility
	out.evasion = evasion
	out.accuracy = accuracy
	out.fill()
	return out

func _living(entries: Array) -> Array:
	return entries.filter(func(entry: Dictionary) -> bool: return (entry.stats as CombatantStats).hp > 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
