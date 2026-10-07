# Ordinary enemy roster data; each pack member rolls independently (guardians are fixed).
class_name EnemyRoster
extends RefCounted

const ORDINARY_IDS := ["angler", "swordfish_duelist", "frilled_shark"]
static var _rng := _new_rng()

static func _new_rng() -> RandomNumberGenerator:
	var out := RandomNumberGenerator.new()
	out.randomize()
	return out

# Even thirds: [0, 1/3) Angler, [1/3, 2/3) Swordfish, [2/3, 1) Frilled Shark.
static func id_for_roll(roll: float) -> String:
	var clamped := clampf(roll, 0.0, 0.999999)
	if clamped < 1.0 / 3.0:
		return "angler"
	if clamped < 2.0 / 3.0:
		return "swordfish_duelist"
	return "frilled_shark"

static func random_id() -> String:
	# Separate RNG so roster rolls never shift combat outcomes.
	return id_for_roll(_rng.randf())
