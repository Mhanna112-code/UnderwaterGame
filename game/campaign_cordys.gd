# The rematch reuses Glassgoat's validated presentation, never the opener's
# overwhelming numbers or forced-response sequencing. Fixed first-pass tuning
# reflects the real 10-HP party: spell levels do not increase its base stats.
class_name CampaignCordys
extends PrologueOctopus

const XP_REWARD := 120
const MOVES := [
	{"name": "Octo Stab", "clip": "octo_stab", "target": "single", "hits": 1,
		"formula": {"strength": 1}, "acc_mod": 1},
	{"name": "Head Bash", "clip": "head_bash", "target": "single", "hits": 1,
		"power": 3, "acc_mod": 0, "quick_time_bool": true},
	{"name": "Electric Shooting", "clip": "electric_shooting", "target": "all", "hits": 1,
		"formula": {"strength": 1}, "acc_mod": 0},
	# 'finish' is the validated framing key for the same Poison Breath take.
	{"name": "Poison Breath", "clip": "finish", "target": "all", "hits": 1,
		"formula": {}, "acc_mod": 1, "poison_fraction": 0.1, "poison_turns": 3},
]

var _move_index := 0

func make_stats() -> CombatantStats:
	var stats := CombatantStats.new()
	stats.hp_max = 75
	stats.strength = 2
	stats.defense = 1
	stats.agility = 2
	stats.evasion = 2
	stats.accuracy = 3
	stats.fill()
	return stats

func next_move() -> Dictionary:
	var move := (MOVES[_move_index % MOVES.size()] as Dictionary).duplicate(true)
	_move_index += 1
	return move

func play_attack(move: Dictionary) -> float:
	set_framing_clip(String(move.clip))
	return play(String(move.clip))

func play_hit_reaction(_heavy: bool) -> void:
	play("hurt")

func play_death() -> void:
	# Delivered file has no death take. Keep its hurt pose, then let the
	# defeated composite sink out rather than inventing a nonexistent clip.
	play("hurt")
	var tween := create_tween()
	tween.tween_interval(0.6)
	# Sink only the visual. Moving the framing owner caused the victory
	# layout resize to chase the corpse and push the party behind the HUD.
	tween.tween_property(_model, "position:y", _model.position.y - height, 1.0)
	tween.tween_callback(hide)
