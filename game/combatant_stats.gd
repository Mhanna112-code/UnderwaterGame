# A fighter's numbers: HP plus the stats damage math reads from
# (game/battle.gd - _resolve_attack). Divers keep one of these on the node
# itself so a level survives between encounters for as long as the Diver
# does (see game/diver.gd); enemies get a fresh one built from a preset each
# battle, since nothing about them persists.
class_name CombatantStats
extends Resource

@export var hp_max: int = 20
@export var strength: int = 5    # adds straight onto a move's power
@export var defense: int = 2     # V2 damage floors at 1 unless defense leads raw damage by more than 5
@export var agility: int = 5     # decides who acts first each round - not part of hit/miss at all

# Hit/miss is deterministic: Accuracy must exceed the defender's remaining
# Evasion pool. A tie goes to Evasion; successful dodges spend that pool.
@export var accuracy: int = 5
@export var evasion: int = 5

# Glassgoat's evasion is a per-turn pool, not a permanent comparison. A
# successful dodge spends the attacker's Accuracy from this value and the
# pool refills at the start of this combatant's next turn.
var evasion_current: int = 5

# Status entries are {level, turns}. A turns value of 0 means persistent for
# the battle (Bleed); positive durations tick after this combatant's turn.
var statuses: Dictionary = {}
var temporary_modifiers := {"accuracy": 0, "evasion": 0}

# A temporary shield: absorbs damage before HP does, doesn't come back on
# its own once spent (see fill() and gain_xp() below - a level-up is the
# only thing that recharges it, same as HP).
@export var barrier_max: int = 0
var barrier: int

# Spent on ability use (Diver.use_ability()), on the sonar passive while
# it's active, and on casting an equipped spell in battle (battle.gd's
# _resolve_party_move()) - float rather than int like hp/barrier so a
# continuous drain (sonar) and passive regen (Diver._process) don't get
# rounded to zero every frame. Same fill()-on-level-up/refill story as
# barrier: nothing but a level-up tops it off instantly, everything else is
# gradual regen.
@export var oxygen_max: float = 100.0
var oxygen: float

@export var level: int = 1
@export var xp: int = 0
@export var xp_to_next: int = 30

# Currency spent in game/spell_tree.gd - one per level-up, awarded in the
# same loop that already applies growth stats (see gain_xp below), so it
# rides along with leveling rather than needing its own trigger.
@export var spell_points: int = 0

# FF-style XP curve: each level needs XP_BASE * level^XP_CURVE, not a flat
# amount more than the last. Early levels stay cheap (level 1->2 is still
# exactly 30, unchanged) and later ones get steadily more expensive - level
# 4->5 needs 240, not 60. Recomputed fresh each level-up from `level` itself
# (see gain_xp below) rather than accumulated, so there's no drift.
const XP_BASE := 30.0
const XP_CURVE := 1.5

# Per-level growth. Zero on all of these (the default) means "doesn't
# level" - what enemies get, since only divers gain XP.
#
# grow_accuracy/grow_evasion exist so neither side of _resolve_attack's
# accuracy-vs-evasion comparison can permanently cross the other and get
# stuck there. Before these existed, a diver's accuracy/evasion were fixed
# forever while Goblin.SCALE_PER_LEVEL scaled a grunt's accuracy AND
# evasion up every player level - eventually a low-accuracy diver would
# start missing every grunt permanently (or a low-evasion one would start
# getting hit by everything), with no way back since only one side of the
# comparison was ever moving. Small growth on both stats keeps the
# player's own numbers climbing roughly in step with whatever they're
# fighting, on top of goblin.gd now deriving enemy stats from the party's
# current numbers directly rather than an independent curve (see
# Goblin.make_stats()) - belt and suspenders against the same failure mode.
@export var grow_hp: int = 0
@export var grow_strength: int = 0
@export var grow_defense: int = 0
@export var grow_agility: int = 0
@export var grow_accuracy: int = 0
@export var grow_evasion: int = 0

var hp: int

func _init() -> void:
	hp = hp_max
	barrier = barrier_max
	oxygen = oxygen_max
	evasion_current = evasion

# Call after setting hp_max/barrier_max/etc from a base-stat table, so
# current HP and barrier start full rather than at whatever the Resource
# default was.
func fill() -> void:
	hp = hp_max
	barrier = barrier_max
	oxygen = oxygen_max
	evasion_current = evasion
	statuses.clear()
	temporary_modifiers = {"accuracy": 0, "evasion": 0}

func effective_accuracy() -> int:
	return maxi(0, accuracy - status_level("blindness") + int(temporary_modifiers.accuracy))

func effective_evasion() -> int:
	return maxi(0, evasion + int(temporary_modifiers.evasion))

func effective_agility() -> int:
	return maxi(0, agility - status_level("blindness"))

func effective_defense() -> int:
	return maxi(0, defense - status_level("blindness"))

func begin_turn() -> void:
	temporary_modifiers = {"accuracy": 0, "evasion": 0}
	evasion_current = effective_evasion()

func end_turn() -> Dictionary:
	var bleed_damage := status_level("bleed")
	if bleed_damage > 0:
		hp = maxi(0, hp - bleed_damage)
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
	return {"bleed_damage": bleed_damage, "expired": expired}

func spend_evasion(amount: int) -> int:
	var spent := mini(evasion_current, maxi(0, amount))
	evasion_current -= spent
	return spent

func reduce_evasion(amount: int) -> int:
	var before := evasion
	evasion = maxi(0, evasion - maxi(0, amount))
	evasion_current = mini(evasion_current, effective_evasion())
	return before - evasion

func add_temporary_modifier(stat: String, amount: int) -> void:
	if not temporary_modifiers.has(stat):
		return
	temporary_modifiers[stat] = int(temporary_modifiers[stat]) + amount
	if stat == "evasion":
		evasion_current = mini(evasion_current, effective_evasion())

func add_status(status: String, level: int, turns: int = 0) -> void:
	if status == "" or level <= 0:
		return
	if status == "bleed" and statuses.has(status):
		(statuses[status] as Dictionary).level = mini(10, status_level(status) + level)
		return
	var existing := statuses.get(status, {}) as Dictionary
	statuses[status] = {
		"level": maxi(level, int(existing.get("level", 0))),
		"turns": maxi(turns, int(existing.get("turns", 0))),
	}

func status_level(status: String) -> int:
	return int((statuses.get(status, {}) as Dictionary).get("level", 0))

func status_turns(status: String) -> int:
	return int((statuses.get(status, {}) as Dictionary).get("turns", 0))

func status_summary() -> String:
	var parts: Array[String] = []
	for status in statuses.keys():
		var level := status_level(String(status))
		var turns := status_turns(String(status))
		parts.append("%s %d%s" % [String(status).capitalize(), level, "·%d" % turns if turns > 0 else ""])
	return "  ".join(parts)

# Adds XP and applies every level-up it crosses (a big win can jump more
# than one level at once). Returns the list of levels reached, empty if
# none - battle.gd uses that to decide whether to log anything.
func gain_xp(amount: int) -> Array:
	xp += amount
	var levels_gained: Array = []
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		hp_max += grow_hp
		strength += grow_strength
		defense += grow_defense
		agility += grow_agility
		accuracy += grow_accuracy
		evasion += grow_evasion
		xp_to_next = int(round(XP_BASE * pow(float(level), XP_CURVE)))
		spell_points += 1
		levels_gained.append(level)
	if not levels_gained.is_empty():
		fill()      # a level-up is the game's only heal/recharge right now
	return levels_gained
