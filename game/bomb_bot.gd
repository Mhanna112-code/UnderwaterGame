# First one-time laboratory blocker. It stays inside Goblin's stable battle
# actor contract so camera framing, turn dispatch, status presentation and
# victory cleanup do not need a model-specific branch.
class_name BombBot
extends Goblin

const BOMB_BOT_SRC := preload("res://art/deep_zone/Bomb_Bot.fbx")

# No authored stat sheet accompanied this model. These conservative fixed
# values establish a reproducible tuning baseline: durable armour, low speed
# and evasion, and enough accuracy for its control move to matter. They are
# explicitly provisional and must move only through measured route playtests.
const BOMB_BOT_STATS := {
	"hp": 12, "strength": 3, "defense": 4, "agility": 1,
	"evasion": 1, "accuracy": 3,
}

func floor_stats() -> Dictionary:
	return BOMB_BOT_STATS

func make_stats(_reference: CombatantStats, player_level: int = 1) -> CombatantStats:
	xp_reward = maxi(1, int(round(float(BASE_XP) * 1.5 * (1.0 + float(maxi(player_level - 1, 0)) * 0.12))))
	var stats := CombatantStats.new()
	stats.hp_max = int(BOMB_BOT_STATS.hp)
	stats.strength = int(BOMB_BOT_STATS.strength)
	stats.defense = int(BOMB_BOT_STATS.defense)
	stats.agility = int(BOMB_BOT_STATS.agility)
	stats.evasion = int(BOMB_BOT_STATS.evasion)
	stats.accuracy = int(BOMB_BOT_STATS.accuracy)
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
	return BOMB_BOT_SRC

func enemy_catalogue() -> Array:
	return EnemyMoves.bomb_bot_catalogue()

func enemy_id() -> String:
	return "bomb_bot"

func display_name() -> String:
	return "Bomb Bot"

func primary_attack_clip() -> String:
	return "lightingblast"
