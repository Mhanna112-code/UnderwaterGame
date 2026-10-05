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

static func autosave_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d_auto.json" % slot

static func write_autosave(slot: int, data: Dictionary) -> Error:
	return _write_path(autosave_path(slot), JSON.stringify(_ordered_snapshot(slot, data)).to_utf8_buffer())

# Both files belong to the same slot/run. Ordering must survive a cold load,
# same-second writes, and clock changes; never infer that autosave always wins.
static func _ordered_snapshot(slot: int, data: Dictionary) -> Dictionary:
	var snapshot := data.duplicate(true)
	snapshot["save_sequence"] = maxi(_sequence(read_slot(slot)), _sequence(read_autosave(slot))) + 1
	return snapshot

static func _sequence(data: Dictionary) -> int:
	var value: Variant = data.get("save_sequence", 0)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 9007199254740990.0 or float(value) != floorf(float(value)):
		return 0
	return int(value)

# Shape validation remains with World/CampaignCheckpoint. Try each candidate
# in this order, falling back if the newest parsed dictionary is incompatible.
static func latest_candidates(slot: int) -> Array[Dictionary]:
	var manual := read_slot(slot)
	var automatic := read_autosave(slot)
	var manual_order := _sequence(manual)
	var auto_order := _sequence(automatic)
	# Pre-metadata saves retain their existing file times. A tie favors the safe
	# manual checkpoint. Never rewrite a legacy save merely to inspect/load it.
	if manual_order == 0 and auto_order == 0:
		manual_order = FileAccess.get_modified_time(slot_path(slot)) if not manual.is_empty() else 0
		auto_order = FileAccess.get_modified_time(autosave_path(slot)) if not automatic.is_empty() else 0
	var candidates: Array[Dictionary] = [
		{"autosave": false, "data": manual}, {"autosave": true, "data": automatic}]
	if auto_order > manual_order:
		candidates.reverse()
	return candidates

static func read_autosave(slot: int) -> Dictionary:
	return _read_path(autosave_path(slot))

static func clear_autosave(slot: int) -> Error:
	var path := autosave_path(slot)
	return DirAccess.remove_absolute(path) if FileAccess.file_exists(path) else OK

static func rollback_autosave(slot: int, existed: bool, previous: PackedByteArray) -> Error:
	return _write_path(autosave_path(slot), previous) if existed else clear_autosave(slot)

static func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

# make_dir_recursive_absolute() is a no-op (returns OK) if the directory
# already exists, so this is safe to call before every write rather than
# needing a one-time setup step anywhere.
static func write_slot(slot: int, data: Dictionary) -> Error:
	return _write_bytes(slot, JSON.stringify(_ordered_snapshot(slot, data)).to_utf8_buffer())

# A web durable-sync rejection must roll the RAM filesystem back too. Keep
# exact previous bytes, including a previously corrupt file; never delete an
# existing slot simply because JSON parsing returned an empty dictionary.
static func rollback_slot(slot: int, existed: bool, previous: PackedByteArray) -> Error:
	if existed:
		return _write_bytes(slot, previous)
	if slot_exists(slot):
		return DirAccess.remove_absolute(slot_path(slot))
	return OK

static func _write_bytes(slot: int, serialized: PackedByteArray) -> Error:
	return _write_path(slot_path(slot), serialized)

static func _write_path(destination: String, serialized: PackedByteArray) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if directory_error != OK:
		return directory_error
	# Never truncate the last usable checkpoint before a replacement has
	# actually been written. A full disk/denied write must leave it readable.
	# The same-directory .pending file is the save protocol's staging owner;
	# only a complete, flushed candidate may replace the selected slot.
	var pending := destination + ".pending"
	var f := FileAccess.open(pending, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(serialized)
	f.flush()
	var write_error := f.get_error()
	f.close()
	if write_error != OK:
		return write_error
	if FileAccess.get_file_as_bytes(pending) != serialized:
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(pending, destination)

# {} for a missing/corrupt slot rather than an error - callers (World's
# title screen slot list, _apply_state()) already treat an empty
# dictionary as "nothing to load," so a bad file degrades to "looks empty"
# instead of crashing the title screen.
static func read_slot(slot: int) -> Dictionary:
	return _read_path(slot_path(slot))

static func _read_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	var parsed: Variant = parser.data
	return parsed if parsed is Dictionary else {}
