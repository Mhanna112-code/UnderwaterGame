# Swordfish Duelist: extends Goblin (the enemy contract); only assets and move data differ.
class_name SwordDuelist
extends Goblin

const DUELIST_SRC := preload("res://characters/Sword_Duelist.fbx")

# Authored Swordfish stats: fast and evasive, light armour.
# Distinct name because a subclass const can't shadow the parent's FLOOR_STATS.
const DUELIST_FLOOR_STATS := {
	"hp": 8, "strength": 2, "defense": 1, "agility": 6,
	"evasion": 4, "accuracy": 3,
}

func floor_stats() -> Dictionary:
	return DUELIST_FLOOR_STATS

# Built directly from its spec (no Accuracy scaling, which made Triple Combo an auto-kill).
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

# Angler's AI state machine doesn't apply; target first, then choose_move() independently.
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
