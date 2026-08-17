# A fighter's numbers: HP plus the stats damage math reads from
# (game/battle.gd - _resolve_attack). Divers keep one of these on the node
# itself so a level survives between encounters for as long as the Diver
# does (see game/diver.gd); enemies get a fresh one built from a preset each
# battle, since nothing about them persists.
class_name CombatantStats
extends Resource

@export var hp_max: int = 20
@export var attack: int = 5      # adds straight onto a move's power
@export var defense: int = 2     # subtracted flat from incoming damage - can floor a hit at 0
@export var speed: int = 5       # decides who acts first each round
@export var luck: int = 5        # crit chance only - dodge/accuracy below handle whether a hit lands

# dodge: chance (0.0-1.0) to avoid a hit completely, regardless of its
# damage. accuracy: cancels the attacker's target's dodge point-for-point -
# it doesn't add a bonus to hit, it just eats into how dodgy they are.
@export var dodge: float = 0.05
@export var accuracy: float = 0.05

# A temporary shield: absorbs damage before HP does, doesn't come back on
# its own once spent (see fill() and gain_xp() below - a level-up is the
# only thing that recharges it, same as HP).
@export var barrier_max: int = 0
var barrier: int

@export var level: int = 1
@export var xp: int = 0
@export var xp_to_next: int = 30

# FF-style XP curve: each level needs XP_BASE * level^XP_CURVE, not a flat
# amount more than the last. Early levels stay cheap (level 1->2 is still
# exactly 30, unchanged) and later ones get steadily more expensive - level
# 4->5 needs 240, not 60. Recomputed fresh each level-up from `level` itself
# (see gain_xp below) rather than accumulated, so there's no drift.
const XP_BASE := 30.0
const XP_CURVE := 1.5

# Per-level growth. Zero on all of these (the default) means "doesn't
# level" - what enemies get, since only divers gain XP.
@export var grow_hp: int = 0
@export var grow_attack: int = 0
@export var grow_defense: int = 0
@export var grow_speed: int = 0
@export var grow_luck: int = 0

var hp: int

func _init() -> void:
	hp = hp_max
	barrier = barrier_max

# Call after setting hp_max/barrier_max/etc from a base-stat table, so
# current HP and barrier start full rather than at whatever the Resource
# default was.
func fill() -> void:
	hp = hp_max
	barrier = barrier_max

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
		attack += grow_attack
		defense += grow_defense
		speed += grow_speed
		luck += grow_luck
		xp_to_next = int(round(XP_BASE * pow(float(level), XP_CURVE)))
		levels_gained.append(level)
	if not levels_gained.is_empty():
		fill()      # a level-up is the game's only heal/recharge right now
	return levels_gained
