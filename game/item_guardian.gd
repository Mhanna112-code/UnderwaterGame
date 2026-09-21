# Where each guarded item is - no longer a placed object in the world (see
# World._on_encounter_triggered()'s own header comment: a revealed item's
# location is now just a radius an ordinary random encounter can roll a
# reward inside, not a fixed statue you have to swim into), just the shared
# data source sonar (diver.gd's update_sonar()) and the minimap
# (mini_map.gd's _draw_key_item_markers()) both still read to agree on
# where a revealed item's red circle actually is. Kept as its own class
# (rather than having every caller read Sites.guarded() directly) so
# nothing outside this file needed to change when the on-screen guardian
# itself was removed.
class_name ItemGuardian
extends RefCounted

static func spots() -> Array:
	return Sites.guarded()
