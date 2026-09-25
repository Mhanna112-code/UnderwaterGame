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
	# Goblin.make_stats() reads the engine RNG for its documented edge. Reset it
	# per sample so every strategy faces the identical starting encounter.
	seed(700000 + seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900000 + seed_value
	var party := _party()
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

func _party() -> Array:
	return [
		{"kind": "party", "model": "Staff_Diver", "stats": _stats(10, 1, 0, 3, 3, 3)},
		{"kind": "party", "model": "Prototype_1(1910)", "stats": _stats(10, 2, 2, 2, 2, 2)},
		{"kind": "party", "model": "Prototype_V(1922)", "stats": _stats(10, 4, 4, 1, 0, 1)},
	]

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
	stats.oxygen -= float(move.get("oxygen_cost", 0.0))
	_apply(stats, target.stats as CombatantStats, move, rng)

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
		if policy != "damage_only" and target_id == "swordfish_duelist" and (target.stats as CombatantStats).evasion >= 2:
			return scuba[0] as Dictionary # Electric Touch
		if policy == "skilled" and (target.stats as CombatantStats).evasion >= 2:
			return scuba[0] as Dictionary # remove a live evasive defense first
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
	if policy == "skilled" and target_id == "sea_urchin":
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
