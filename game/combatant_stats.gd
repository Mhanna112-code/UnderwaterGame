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

# Per-stat debuff floor - empty for a Diver (permanent debuffs only ever
# target enemies today, see battle.gd's _apply_debuff()), populated for an
# enemy with its own species BASE_STATS (Goblin._stats_from()). A stat can
# be debuffed down to this floor and no further, even though the enemy's
# actual starting value this fight is usually higher (make_stats()'s own
# 5-25% roll on top of it) - the species' real base stays a hard bottom
# regardless of how much of that roll a Weaken/Slow strips back off.
var stat_floor: Dictionary = {}

# Status entries are {level, turns}. A turns value of 0 means persistent for
# the battle; positive durations tick after this combatant's turn. Current
# Bleed is authored as persistent; Poison and other timed statuses expire.
var statuses: Dictionary = {}
var temporary_modifiers := {"accuracy": 0, "evasion": 0}

# Spent on ability use (Diver.use_ability()), on the sonar passive while
# it's active, and on casting an equipped spell in battle (battle.gd's
# _resolve_party_move()) - float rather than int like hp so a continuous
# drain (sonar) and passive regen (Diver._process) don't get rounded to
# zero every frame. Same fill()-on-level-up/refill story as hp: nothing
# but a level-up tops it off instantly, everything else is gradual regen.
@export var oxygen_max: float = 100.0
var oxygen: float

@export var level: int = 1
@export var xp: int = 0
@export var xp_to_next: int = 30

# Currency spent in game/spell_tree.gd - one per level-up (see gain_xp
# below). Leveling doesn't touch hp_max/strength/defense/etc at all - a
# level-up is a full HP/Oxygen refill plus this, nothing more.
@export var spell_points: int = 0

# FF-style XP curve: each level needs XP_BASE * level^XP_CURVE, not a flat
# amount more than the last. Early levels stay cheap (level 1->2 is still
# exactly 30, unchanged) and later ones get steadily more expensive - level
# 4->5 needs 240, not 60. Recomputed fresh each level-up from `level` itself
# (see gain_xp below) rather than accumulated, so there's no drift.
const XP_BASE := 30.0
const XP_CURVE := 1.5

var hp: int

func _init() -> void:
	hp = hp_max
	oxygen = oxygen_max
	evasion_current = evasion

# Call after setting hp_max/oxygen_max/etc from a base-stat table, so
# current HP starts full rather than at whatever the Resource default was.
func fill() -> void:
	hp = hp_max
	oxygen = oxygen_max
	evasion_current = evasion
	statuses.clear()
	temporary_modifiers = {"accuracy": 0, "evasion": 0}

# A short post-victory regroup. Without a camp/healer between the two artifact
# sites, even a won encounter could leave a diver at 0 HP and turn the next
# legal pack into a foregone conclusion. This restores only a fraction, so
# damage still matters across the route; a level-up remains the only free
# full refill. Called by Battle after XP and mirrored by the campaign balance
# gate. Skips the HP restore entirely for anyone already at 0 - a downed
# diver doesn't get back up just because the party won; only a level-up
# (fill(), above) or an actual Revive spell (battle.gd's "revive" effect,
# world.gd's out-of-battle version) brings them back.
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
	return maxi(0, defense - status_level("blindness"))

func begin_turn() -> void:
	temporary_modifiers = {"accuracy": 0, "evasion": 0}
	evasion_current = effective_evasion()

func end_turn() -> Dictionary:
	var bleed_damage := status_level("bleed")
	if bleed_damage > 0:
		hp = maxi(0, hp - bleed_damage)
	var poison_damage := status_level("poison")
	if poison_damage > 0:
		hp = maxi(0, hp - poison_damage)
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
	# The advertised Bleed cap applies to the first wound too. A high-STR
	# Stabbing must not start above the cap that repeat hits enforce.
	if status == "bleed":
		level = mini(10, level)
	if status == "bleed" and statuses.has(status):
		(statuses[status] as Dictionary).level = mini(10, status_level(status) + level)
		return
	var existing := statuses.get(status, {}) as Dictionary
	statuses[status] = {
		"level": maxi(level, int(existing.get("level", 0))),
		"turns": maxi(turns, int(existing.get("turns", 0))),
	}
	# Marc's timed debuff also shrinks the live dodge allowance immediately.
	# Never refill a pool already spent by previous attacks this turn.
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
		# Marc's readable duration units, separate from damage/debuff amount.
		if String(status) == "stun":
			parts.append(name + (left if turns > 0 else " (%d %s left)" % [level, "turn" if level == 1 else "turns"]))
		else:
			parts.append("%s %d%s" % [name, level, left])
	return "  ".join(parts)

# Adds XP and applies every level-up it crosses (a big win can jump more
# than one level at once). Returns one Dictionary per level reached -
# {"level": int} - empty if none. battle.gd uses "level" to decide whether/
# what to log. Purely a counter plus a reward trigger: hp_max/strength/
# defense/agility/accuracy/evasion never change here, only spell_points and
# (via fill() below) current HP/oxygen.
func gain_xp(amount: int) -> Array:
	xp += amount
	var levels_gained: Array = []
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(XP_BASE * pow(float(level), XP_CURVE)))
		spell_points += 1
		levels_gained.append({"level": level})
	if not levels_gained.is_empty():
		fill()      # a level-up is the game's only full heal/recharge right now
	return levels_gained
