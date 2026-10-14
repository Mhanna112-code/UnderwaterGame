# Second one-time lab blocker; reuses the Swordfish Duelist move catalogue with its own model and tuning.
class_name SwordSlayer
extends Goblin

const SWORD_SLAYER_SRC := preload("res://art/deep_zone/Sword_Slayer.fbx")

# Faster but less armoured than Bomb Bot; first-pass values pending playtests.
const SWORD_SLAYER_STATS := {
	"hp": 14, "strength": 3, "defense": 2, "agility": 5,
	"evasion": 3, "accuracy": 3,
}

func floor_stats() -> Dictionary:
	return SWORD_SLAYER_STATS

func make_stats(_reference: CombatantStats, player_level: int = 1) -> CombatantStats:
	xp_reward = maxi(1, int(round(float(BASE_XP) * 1.7 * (1.0 + float(maxi(player_level - 1, 0)) * 0.12))))
	var stats := CombatantStats.new()
	stats.hp_max = int(SWORD_SLAYER_STATS.hp)
	stats.strength = int(SWORD_SLAYER_STATS.strength)
	stats.defense = int(SWORD_SLAYER_STATS.defense)
	stats.agility = int(SWORD_SLAYER_STATS.agility)
	stats.evasion = int(SWORD_SLAYER_STATS.evasion)
	stats.accuracy = int(SWORD_SLAYER_STATS.accuracy)
	stats.fill()
	stats.stat_floor = {
		"strength": stats.strength, "defense": stats.defense,
		"agility": stats.agility, "evasion": stats.evasion,
		"accuracy": stats.accuracy,
	}
	return stats

func choose_move_and_target(_self_stats: CombatantStats, _alive_party: Array, default_target: Dictionary, _forced: bool) -> Dictionary:
	return {"move": choose_move(default_target.stats as CombatantStats), "target": default_target}

func model_source() -> PackedScene:
	return SWORD_SLAYER_SRC

func enemy_catalogue() -> Array:
	return EnemyMoves.swordfish_duelist_catalogue()

func enemy_id() -> String:
	return "sword_slayer"

func display_name() -> String:
	return "Sword Slayer"

func primary_attack_clip() -> String:
	return "greatslash"
