# Where each guarded item is. This shared data drives sonar/minimap markers,
# encounter rewards, and World._build_item_grapple_anchors()'s color-coded
# grapple rings, so those systems all agree on the same locations.
class_name ItemGuardian
extends RefCounted

static func spots() -> Array:
	return Sites.guarded()
