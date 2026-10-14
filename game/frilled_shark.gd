# Frilled Shark: ordinary enemy on the Goblin contract; only asset, moves and stats differ.
class_name FrilledShark
extends Goblin

const SHARK_SRC := preload("res://game/FrilledShark.fbx")

# Own floor stats; named distinctly because subclass consts can't shadow parent consts.
const SHARK_FLOOR_STATS := {
	"hp": 5, "strength": 2, "defense": 2, "agility": 1,
	"evasion": 2, "accuracy": 2,
}

func floor_stats() -> Dictionary:
	return SHARK_FLOOR_STATS

# Complete authored stat block (no Angler random boosts); only XP progression is shared.
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

# No Angler state machine: Battle's plain target-then-move flow.
func choose_move_and_target(_self_stats: CombatantStats, _alive_party: Array, default_target: Dictionary, _forced: bool) -> Dictionary:
	return {"move": choose_move(default_target.stats as CombatantStats), "target": default_target}

func model_source() -> PackedScene:
	return SHARK_SRC

func enemy_catalogue() -> Array:
	return EnemyMoves.frilled_shark_catalogue()

func enemy_id() -> String:
	return "frilled_shark"

func display_name() -> String:
	return "Frilled Shark"

func primary_attack_clip() -> String:
	return "attack)bite"

# Cap the eel-long rig's largest horizontal span, keeping proportions.
func max_visual_horizontal_span() -> float:
	return 3.4
