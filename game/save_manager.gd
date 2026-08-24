# Reads/writes the game's persistent save slots to user:// as plain JSON -
# no state of its own, every function here is static, same shape as
# items.gd/spell_tree.gd. One flat file per slot (slot_0.json etc.), not
# one shared file with an array inside, so a corrupt/missing slot can never
# take another slot down with it.
#
# Godot's user:// resolves to a real per-OS app-data folder outside the
# project directory, so these survive closing the game/editor entirely -
# see World._serialize_state()/_apply_state() for what actually goes into
# one of these dictionaries.
class_name SaveManager
extends RefCounted

const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 3

static func slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot

static func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

# A SEPARATE file from the main slot save, on purpose - world-object
# consumption (broken rocks, etc. - see World.consumed_world_ids) used to
# ride inside the same blob as party stats/position, written only on an
# explicit _write_save() (a real save-point visit, or New Game's initial
# write). That let a player break a rock, quit without saving again, and
# cold-load back into a pristine rock - the consumption was real in that
# session but never reached disk. This ledger is written immediately the
# instant something's consumed (see World._on_world_object_consumed()),
# independent of the save cadence, so a same-session "Restart from Save
# Point" and a cold relaunch always agree on what's already gone.
static func consumed_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d_consumed.json" % slot

static func write_consumed(slot: int, ids: Array) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(consumed_path(slot), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(ids))
	f.close()

static func read_consumed(slot: int) -> Array:
	if not FileAccess.file_exists(consumed_path(slot)):
		return []
	var f := FileAccess.open(consumed_path(slot), FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Array else []

# make_dir_recursive_absolute() is a no-op (returns OK) if the directory
# already exists, so this is safe to call before every write rather than
# needing a one-time setup step anywhere.
static func write_slot(slot: int, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

# {} for a missing/corrupt slot rather than an error - callers (World's
# title screen slot list, _apply_state()) already treat an empty
# dictionary as "nothing to load," so a bad file degrades to "looks empty"
# instead of crashing the title screen.
static func read_slot(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
