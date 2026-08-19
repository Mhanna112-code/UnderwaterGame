# A fighter's numbers: HP plus the stats damage math reads from
# (game/battle.gd - _resolve_attack). Divers keep one of these on the node
# itself so a level survives between encounters for as long as the Diver
# does (see game/diver.gd); enemies get a fresh one built from a preset each
# battle, since nothing about them persists.
class_name CombatantStats
extends Resource

@export var hp_max: int = 20
@export var strength: int = 5    # adds straight onto a move's power
@export var defense: int = 2     # subtracted flat from incoming damage - can floor a hit at 0
@export var agility: int = 5     # decides who acts first each round - not part of hit/miss at all

# Hit/miss is a straight comparison, no roll: an attack lands if the
# attacker's accuracy (plus the move's own acc_mod) is greater than the
# defender's evasion. No luck, no crit - two numbers decide it.
@export var accuracy: int = 5
@export var evasion: int = 5

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

# Call after setting hp_max/barrier_max/etc from a base-stat table, so
# current HP and barrier start full rather than at whatever the Resource
# default was.
func fill() -> void:
	hp = hp_max
	barrier = barrier_max
	oxygen = oxygen_max

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

# Copies every field from `other` onto self - used by world.gd's save
# checkpoint system (see World._capture_checkpoint()/_restore_checkpoint())
# to snapshot and later restore a diver's stats. Explicit field-by-field
# rather than Resource.duplicate(), so it's unambiguous exactly which
# fields travel with a checkpoint - same explicit-assignment habit
# diver.gd's _build_stats() already uses rather than leaning on an
# implicit copy.
func copy_from(other: CombatantStats) -> void:
	hp_max = other.hp_max
	strength = other.strength
	defense = other.defense
	agility = other.agility
	accuracy = other.accuracy
	evasion = other.evasion
	barrier_max = other.barrier_max
	barrier = other.barrier
	oxygen_max = other.oxygen_max
	oxygen = other.oxygen
	level = other.level
	xp = other.xp
	xp_to_next = other.xp_to_next
	spell_points = other.spell_points
	grow_hp = other.grow_hp
	grow_strength = other.grow_strength
	grow_defense = other.grow_defense
	grow_agility = other.grow_agility
	grow_accuracy = other.grow_accuracy
	grow_evasion = other.grow_evasion
	hp = other.hp
