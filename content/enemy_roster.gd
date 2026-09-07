# The ordinary enemy roster is data, separate from fixed artifact guardians.
# A pack rolls each actor independently, so mixed Angler/Swordfish groups are
# possible without making either artifact's defender random.
class_name EnemyRoster
extends RefCounted

const ORDINARY_IDS := ["angler", "swordfish_duelist"]
static var _rng := _new_rng()

static func _new_rng() -> RandomNumberGenerator:
	var out := RandomNumberGenerator.new()
	out.randomize()
	return out

static func id_for_roll(roll: float) -> String:
	return "angler" if clampf(roll, 0.0, 0.999999) < 0.5 else "swordfish_duelist"

static func random_id() -> String:
	# Presentation variety must not consume the global combat/stat RNG. A
	# roster roll changing whether a later attack hits would be a hidden
	# balance change, not an art-roster change.
	return id_for_roll(_rng.randf())
