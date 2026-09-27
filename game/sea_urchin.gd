# Glassgoat's delivered Sea Urchin model as the deep-zone armored counter
# target.  The model has no delivered authored animation/move list yet, so
# this class is explicitly temporary at the move layer (see EnemyMoves), not
# a claim that Contact Spines is final combat content.
class_name SeaUrchin
extends Goblin

const URCHIN_SRC := preload("res://game/Sea_Urchin.fbx")

# The separate DEF gate is deliberate: the player needs Musashi's Weaken to
# turn normal damage into a meaningful hit.  Zero EVA follows Glassgoat's
# note that the sea spike ball should not be another evasive enemy.
const URCHIN_FLOOR_STATS := {
	"hp": 8, "strength": 1, "defense": 4, "agility": 1,
	"evasion": 0, "accuracy": 1,
}

func floor_stats() -> Dictionary:
	return URCHIN_FLOOR_STATS

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

func choose_move_and_target(_self_stats: CombatantStats, _alive_party: Array, default_target: Dictionary, _forced: bool) -> Dictionary:
	return {"move": choose_move(default_target.stats as CombatantStats), "target": default_target}

func model_source() -> PackedScene:
	return URCHIN_SRC

func enemy_catalogue() -> Array:
	return EnemyMoves.sea_urchin_catalogue()

func enemy_id() -> String:
	return "sea_urchin"

func display_name() -> String:
	return "Sea Urchin"

func primary_attack_clip() -> String:
	return ""
