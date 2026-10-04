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

# make_dir_recursive_absolute() is a no-op (returns OK) if the directory
# already exists, so this is safe to call before every write rather than
# needing a one-time setup step anywhere.
static func write_slot(slot: int, data: Dictionary) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if directory_error != OK:
		return directory_error
	# Never truncate the last usable checkpoint before a replacement has
	# actually been written. A full disk/denied write must leave it readable.
	# The same-directory .pending file is the save protocol's staging owner;
	# only a complete, flushed candidate may replace the selected slot.
	var destination := slot_path(slot)
	var pending := destination + ".pending"
	var serialized := JSON.stringify(data)
	var f := FileAccess.open(pending, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(serialized)
	f.flush()
	var write_error := f.get_error()
	f.close()
	if write_error != OK:
		return write_error
	if FileAccess.get_file_as_string(pending) != serialized:
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(pending, destination)

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
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	var parsed: Variant = parser.data
	return parsed if parsed is Dictionary else {}
