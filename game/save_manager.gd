# Static save-slot I/O as JSON under user://, one file per slot so a corrupt slot can't affect others.
# See World._serialize_state()/_apply_state() for contents.
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

# Manual and autosave ordering must survive cold loads, same-second writes and clock changes.
static func _ordered_snapshot(slot: int, data: Dictionary) -> Dictionary:
	var snapshot := data.duplicate(true)
	snapshot["save_sequence"] = maxi(_sequence(read_slot(slot)), _sequence(read_autosave(slot))) + 1
	return snapshot

static func _sequence(data: Dictionary) -> int:
	var value: Variant = data.get("save_sequence", 0)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 9007199254740990.0 or float(value) != floorf(float(value)):
		return 0
	return int(value)

# Try candidates in order, falling back if the newest is incompatible (World validates shape).
static func latest_candidates(slot: int) -> Array[Dictionary]:
	var manual := read_slot(slot)
	var automatic := read_autosave(slot)
	var manual_order := _sequence(manual)
	var auto_order := _sequence(automatic)
	# Legacy saves use file times; ties favor the manual checkpoint. Never rewrite on load.
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

# No-op if the directory exists, so safe before every write.
static func write_slot(slot: int, data: Dictionary) -> Error:
	return _write_bytes(slot, JSON.stringify(_ordered_snapshot(slot, data)).to_utf8_buffer())

# Web sync failure rolls back to the exact previous bytes; never delete an existing slot.
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
	# Write to a .pending file first so a failed write never truncates the last good checkpoint.
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

# {} for a missing/corrupt slot, which callers treat as empty.
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
