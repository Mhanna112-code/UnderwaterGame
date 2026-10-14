class_name BrowserCheckpoint
extends RefCounted

## On web, FileAccess success only means the in-memory write; IndexedDB sync errors aren't reported.
## Reads back the durable bytes before acknowledging a checkpoint (never writes IndexedDB itself).
signal checked(success: bool)

const CHECKER := """
window.UnderwaterCheckpoint = {confirm(path, expected, callback) {
  let finished = false;
  const finish = success => {
    if (finished) return;
    finished = true;
    clearTimeout(deadline);
    callback(success);
  };
  const deadline = setTimeout(() => finish(false), 4000);
  const database = '/' + path.split('/')[1];
  const poll = () => {
    if (finished) return;
    let request;
    try { request = indexedDB.open(database); }
    catch (_) { finish(false); return; }
    request.onupgradeneeded = () => request.transaction.abort();
    request.onerror = () => finish(false);
    request.onsuccess = () => {
      const db = request.result;
      if (finished) { db.close(); return; }
      if (!db.objectStoreNames.contains('FILE_DATA')) {
        db.close(); finish(false); return;
      }
      try {
        const transaction = db.transaction('FILE_DATA', 'readonly');
        const read = transaction.objectStore('FILE_DATA').get(path);
        let matches = false;
        read.onsuccess = () => {
          matches = !!read.result &&
            new TextDecoder().decode(read.result.contents) === expected;
        };
        transaction.oncomplete = () => {
          db.close();
          if (matches) finish(true);
          else if (!finished) setTimeout(poll, 50);
        };
        transaction.onabort = transaction.onerror = () => {
          db.close(); finish(false);
        };
      } catch (_) { db.close(); finish(false); }
    };
  };
  poll();
}};
"""

static func confirm_slot(slot: int, autosave := false) -> Error:
	if not OS.has_feature("web"):
		return OK
	if not OS.is_userfs_persistent():
		return ERR_UNAVAILABLE
	var owner := BrowserCheckpoint.new()
	# Keep both references until the callback fires, or it is lost.
	var callback := JavaScriptBridge.create_callback(owner._on_checked)
	# eval can't return JS objects; install the interface and fetch it via the object bridge.
	JavaScriptBridge.eval(CHECKER, true)
	var bridge := JavaScriptBridge.get_interface("UnderwaterCheckpoint")
	if bridge == null:
		return ERR_UNAVAILABLE
	var filename := SaveManager.autosave_path(slot) if autosave else SaveManager.slot_path(slot)
	var expected := FileAccess.get_file_as_string(filename)
	if expected.is_empty():
		return ERR_FILE_CORRUPT
	JavaScriptBridge.force_fs_sync()
	bridge.confirm(ProjectSettings.globalize_path(filename), expected, callback)
	var success: bool = await owner.checked
	return OK if success else ERR_CANT_CREATE

func _on_checked(arguments: Array) -> void:
	checked.emit(not arguments.is_empty() and arguments[0] == true)
