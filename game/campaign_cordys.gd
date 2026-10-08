# Campaign Cordys rematch: reuses the prologue presentation with fixed tuning for the 10-HP party.
class_name CampaignCordys
extends PrologueOctopus

const XP_REWARD := 120
const MOVES := [
	{"name": "Octo Stab", "clip": "octo_stab", "target": "single", "hits": 1,
		"formula": {"strength": 1, "flat": 2}, "acc_mod": 1},
	{"name": "Head Bash", "clip": "head_bash", "target": "single", "hits": 1,
		"power": 3, "acc_mod": 1, "quick_time_bool": true},   # +1 so it lands on Musashi
	{"name": "Electric Shooting", "clip": "electric_shooting", "target": "all", "hits": 1,
		"formula": {"strength": 1, "flat": 2}, "acc_mod": 0},
	# 'finish' is the validated framing key for the same Poison Breath take.
	{"name": "Poison Breath", "clip": "finish", "target": "all", "hits": 1,
		"formula": {}, "acc_mod": 1, "poison_fraction": 0.1, "poison_turns": 3},
]

var _move_index := 0

func make_stats() -> CombatantStats:
	var stats := CombatantStats.new()
	stats.hp_max = 78
	stats.strength = 5
	stats.defense = 2
	stats.agility = 5
	stats.evasion = 5
	stats.accuracy = 6
	stats.immune_to_stat_loss = true   # like Tethys: stat-lowering effects don't stick
	stats.fill()
	return stats

# Self-heal rolled on 15% of turns (below full HP), outside the cycle: heals 10% max HP and stops Bleed.
# 'reveal' is a validated framing key.
const HEAL_CHANCE := 0.15
var heal_chance := HEAL_CHANCE   # tests set 0 for the fixed cycle
const HEAL_MOVE := {
	"name": "Regenerate", "clip": "reveal",
	"target": "self", "effect": "self_heal", "heal_fraction": 0.10,
}

# `stats`: the boss's own stats; the heal is never rolled at full health.
func next_move(stats: CombatantStats = null) -> Dictionary:
	if stats != null and stats.hp < stats.hp_max and randf() < heal_chance:
		return HEAL_MOVE.duplicate(true)
	var move := (MOVES[_move_index % MOVES.size()] as Dictionary).duplicate(true)
	_move_index += 1
	return move

func play_attack(move: Dictionary) -> float:
	set_framing_clip(String(move.clip))
	return play(String(move.clip))

func play_hit_reaction(_heavy: bool) -> void:
	play("hurt")

func play_death() -> void:
	# No death clip: hold the hurt pose and sink the model.
	play("hurt")
	var tween := create_tween()
	tween.tween_interval(0.6)
	# Sink only the visual so the victory layout doesn't follow it.
	tween.tween_property(_model, "position:y", _model.position.y - height, 1.0)
	tween.tween_callback(hide)
