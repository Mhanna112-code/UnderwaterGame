# A fighter's HP and stats. Divers keep theirs across encounters; enemies get a fresh one each battle.
class_name CombatantStats
extends Resource

@export var hp_max: int = 20
@export var strength: int = 5    # adds straight onto a move's power
@export var defense: int = 2     # V2 damage floors at 1 unless defense leads raw damage by more than 5
@export var agility: int = 5  # turn order only

# Hit/miss is deterministic: Accuracy must exceed the defender's remaining
# Evasion pool. A tie goes to Evasion; successful dodges spend that pool.
@export var accuracy: int = 5
@export var evasion: int = 5

# Per-turn evasion pool: dodges spend the attacker's Accuracy; refills at this combatant's next turn.
var evasion_current: int = 5

# Per-stat debuff floor (enemy species BASE_STATS; empty for divers). Debuffs can't go below it.
var stat_floor: Dictionary = {}

# Status entries are {level, turns}; turns 0 = persistent for the battle, else ticks after this turn.
var statuses: Dictionary = {}
var temporary_modifiers := {"accuracy": 0, "evasion": 0}

# Spent on abilities, sonar and spells. Float so continuous drain/regen isn't rounded away.
@export var oxygen_max: float = 100.0
var oxygen: float

@export var level: int = 1
@export var xp: int = 0
@export var xp_to_next: int = 30

# Spent in spell_tree.gd; one per level-up.
@export var spell_points: int = 0

# XP to next level = XP_BASE * level^XP_CURVE (1->2 is 30, 4->5 is 240).
const XP_BASE := 30.0
# Level cap: 9 Spell Points by then, enough for the largest spell tree.
const MAX_LEVEL := 10
const XP_CURVE := 1.5

# Battle-only HP floor (never saved); the special tutorial sets 1 so nobody goes down early. 0 = off.
var min_hp := 0
var hp: int:
	set(value):
		hp = maxi(value, min_hp) if min_hp > 0 else value
		# Going down clears every status, so a revive starts clean.
		if hp <= 0:
			statuses.clear()

func _init() -> void:
	hp = hp_max
	oxygen = oxygen_max
	evasion_current = evasion

# Call after setting maxima from a base-stat table so current values start full.
func fill() -> void:
	hp = hp_max
	oxygen = oxygen_max
	evasion_current = evasion
	statuses.clear()
	temporary_modifiers = {"accuracy": 0, "evasion": 0}

# Legacy partial post-victory heal (skips downed divers); production Battle no longer calls it.
func recover_after_victory(fraction: float = 0.30) -> void:
	var amount := clampf(fraction, 0.0, 1.0)
	if hp > 0:
		hp = mini(hp_max, hp + maxi(1, int(ceil(float(hp_max) * amount))))
	oxygen = minf(oxygen_max, oxygen + oxygen_max * amount)
	statuses.clear()
	temporary_modifiers = {"accuracy": 0, "evasion": 0}
	evasion_current = effective_evasion()

func effective_accuracy() -> int:
	return maxi(0, accuracy - status_level("blindness") + int(temporary_modifiers.accuracy))

func effective_evasion() -> int:
	return maxi(0, evasion - status_level("evasion_down") + int(temporary_modifiers.evasion))

func effective_agility() -> int:
	return maxi(0, agility - status_level("blindness"))

func effective_defense() -> int:
	return maxi(0, defense - status_level("blindness") - status_level("defense_down"))

func begin_turn() -> void:
	temporary_modifiers = {"accuracy": 0, "evasion": 0}
	evasion_current = effective_evasion()

# DoT damage only, no countdown; also used on skipped Stun turns.
func tick_damage_over_time() -> Dictionary:
	var bleed_damage := status_level("bleed")
	if bleed_damage > 0:
		hp = maxi(0, hp - bleed_damage)
	var poison_damage := status_level("poison")
	if poison_damage > 0:
		hp = maxi(0, hp - poison_damage)
	return {"bleed_damage": bleed_damage, "poison_damage": poison_damage}

func end_turn() -> Dictionary:
	var dot := tick_damage_over_time()
	var bleed_damage := int(dot.bleed_damage)
	var poison_damage := int(dot.poison_damage)
	var expired: Array[String] = []
	for status in statuses.keys():
		var entry := statuses[status] as Dictionary
		var turns := int(entry.get("turns", 0))
		if turns <= 0:
			continue
		turns -= 1
		if turns == 0:
			expired.append(String(status))
		else:
			entry.turns = turns
	for status in expired:
		statuses.erase(status)
	return {
		"bleed_damage": bleed_damage,
		"poison_damage": poison_damage,
		"expired": expired,
	}

func spend_evasion(amount: int) -> int:
	var spent := mini(evasion_current, maxi(0, amount))
	evasion_current -= spent
	return spent

# Bosses ignore stat-lowering effects; Bleed, Poison and Stun still apply.
var immune_to_stat_loss := false
const BLEED_MAX_STACKS := 3
# Most Bleed this combatant can carry; divers set 5 (Diver), enemies keep 10.
var bleed_cap := 10
const STAT_LOSS_STATUSES := ["blindness", "evasion_down", "defense_down"]

func reduce_evasion(amount: int) -> int:
	var before := evasion
	evasion = maxi(0, evasion - maxi(0, amount))
	evasion_current = mini(evasion_current, effective_evasion())
	return before - evasion

func reduce_defense(amount: int) -> int:
	var before := defense
	defense = maxi(0, defense - maxi(0, amount))
	return before - defense

func is_stunned() -> bool:
	return status_level("stun") > 0 and status_turns("stun") > 0

func consume_status_turn(status: String) -> void:
	if not statuses.has(status):
		return
	var entry := statuses[status] as Dictionary
	var turns := int(entry.get("turns", 0))
	if turns <= 1:
		statuses.erase(status)
	else:
		entry.turns = turns - 1

func add_temporary_modifier(stat: String, amount: int) -> void:
	if not temporary_modifiers.has(stat):
		return
	temporary_modifiers[stat] = int(temporary_modifiers[stat]) + amount
	if stat == "evasion":
		evasion_current = mini(evasion_current, effective_evasion())

func add_status(status: String, level: int, turns: int = 0) -> void:
	if status == "" or level <= 0:
		return
	# The Bleed cap applies to the first wound too.
	if status == "bleed":
		level = mini(bleed_cap, level)
	if status == "bleed" and statuses.has(status):
		# After the first wound Bleed grows at most BLEED_MAX_STACKS more times per fight, never past 10.
		var bleed := statuses[status] as Dictionary
		var stacks := int(bleed.get("stacks", 0))
		if stacks >= BLEED_MAX_STACKS:
			return
		bleed.stacks = stacks + 1
		bleed.level = mini(bleed_cap, status_level(status) + level)
		return
	var existing := statuses.get(status, {}) as Dictionary
	statuses[status] = {
		"level": maxi(level, int(existing.get("level", 0))),
		"turns": maxi(turns, int(existing.get("turns", 0))),
	}
	# Timed debuff shrinks the live dodge pool immediately, but never refills a spent pool.
	if status == "evasion_down":
		evasion_current = mini(evasion_current, effective_evasion())

func status_level(status: String) -> int:
	return int((statuses.get(status, {}) as Dictionary).get("level", 0))

func status_turns(status: String) -> int:
	return int((statuses.get(status, {}) as Dictionary).get("turns", 0))

func status_summary() -> String:
	var parts: Array[String] = []
	for status in statuses.keys():
		var level := status_level(String(status))
		var turns := status_turns(String(status))
		var name := String(status).capitalize()
		var left := " (%d %s left)" % [turns, "turn" if turns == 1 else "turns"] if turns > 0 else ""
		# Readable duration units, separate from the amount.
		if String(status) == "stun":
			parts.append(name + (left if turns > 0 else " (%d %s left)" % [level, "turn" if level == 1 else "turns"]))
		else:
			parts.append("%s %d%s" % [name, level, left])
	return "  ".join(parts)

# Adds XP and applies each level-up crossed; returns [{"level": int}, ...].
# Only spell_points and a full refill change; base stats don't.
func gain_xp(amount: int) -> Array:
	xp += amount
	var levels_gained: Array = []
	while xp >= xp_to_next and level < MAX_LEVEL:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(XP_BASE * pow(float(level), XP_CURVE)))
		spell_points += 1
		levels_gained.append({"level": level})
	# At the cap, XP stops accumulating.
	if level >= MAX_LEVEL:
		xp = 0
	if not levels_gained.is_empty():
		fill()  # only full heal/recharge
	return levels_gained
