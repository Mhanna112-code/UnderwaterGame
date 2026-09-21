# Swordfish Duelist is Glassgoat's second ordinary-enemy-compatible rig.
# It extends Goblin deliberately: the base class is the public enemy contract
# for battle, guardian triggers, saving, balance, facing and death effects.
# Only asset identity and authored move data vary by model.
class_name SwordDuelist
extends Goblin

const DUELIST_SRC := preload("res://characters/Sword_Duelist.fbx")

# Glassgoat's authored Swordfish block (Group_StatsV2): faster and more evasive
# than the rest of the ordinary roster, but with only light armour. It is the
# complete Swordfish battle block, not a party-relative Angler-style floor.
# Named distinctly from the parent's FLOOR_STATS - GDScript does not allow a
# subclass const to shadow one already declared on its parent.
const DUELIST_FLOOR_STATS := {
	"hp": 8, "strength": 2, "defense": 1, "agility": 6,
	"evasion": 4, "accuracy": 3,
}

func floor_stats() -> Dictionary:
	return DUELIST_FLOOR_STATS

# In particular, scaling 3 Accuracy above Scuba's 3 Evasion turns Triple Combo
# into an almost automatic opening three-hit kill, which is neither the
# authored 8/2/1/6/4/3 design nor a traversable first route. Keep the shared
# XP reward progression, but build the Swordfish's battle stats directly from
# its own specification.
func make_stats(_reference: CombatantStats, player_level: int = 1) -> CombatantStats:
	xp_reward = maxi(1, int(round(float(BASE_XP) * (1.0 + float(maxi(player_level - 1, 0)) * 0.12))))
	var authored := floor_stats()
	var stats := CombatantStats.new()
	stats.hp_max = int(authored.hp)
	stats.strength = int(authored.strength)
	stats.defense = int(authored.defense)
	stats.agility = int(authored.agility)
	stats.evasion = int(authored.evasion)
	stats.accuracy = int(authored.accuracy)
	stats.fill()
	return stats

# Goblin's low-HP Headbutt-priority / Bite-streak-into-Flash-Blast state
# machine is authored specifically for the Angler; Swordfish keeps Battle's
# older two-step flow (a target picked first, then choose_move() asked
# independently which move to swing) exactly as it always has.
func choose_move_and_target(_self_stats: CombatantStats, _alive_party: Array, default_target: Dictionary, _forced: bool) -> Dictionary:
	return {"move": choose_move(default_target.stats as CombatantStats), "target": default_target}

func model_source() -> PackedScene:
	return DUELIST_SRC

func enemy_catalogue() -> Array:
	return EnemyMoves.swordfish_duelist_catalogue()

func enemy_id() -> String:
	return "swordfish_duelist"

func display_name() -> String:
	return "Swordfish Duelist"

func primary_attack_clip() -> String:
	return "attack)greatslash"
