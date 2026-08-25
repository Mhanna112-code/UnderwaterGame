# Capture the real cold-launch surface for title-screen layout review.
# Usage: godot --path . --script tools/shoot_title.gd -- <out.png>
extends SceneTree

var out_png := "/tmp/title-screen.png"
var mode := "main"
var frames := 0
var world: World
var _saved_files: Dictionary = {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_png = String(args[0])
	if args.size() > 1:
		mode = String(args[1])
	if mode == "fresh":
		_backup_slots()
		_remove_slots()
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2 and mode == "new-slots":
		world.title_screen._open_slots("new")
	elif frames == 2 and mode == "load-slots":
		world.title_screen._open_slots("load")
	if frames < 6:
		return false
	root.get_texture().get_image().save_png(out_png)
	if mode == "fresh":
		_restore_slots()
	print("title shot  %s" % out_png)
	return true

func _backup_slots() -> void:
	for slot in range(SaveManager.SLOT_COUNT):
		var path := ProjectSettings.globalize_path(SaveManager.slot_path(slot))
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			_saved_files[path] = file.get_buffer(file.get_length())

func _remove_slots() -> void:
	for slot in range(SaveManager.SLOT_COUNT):
		var path := ProjectSettings.globalize_path(SaveManager.slot_path(slot))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _restore_slots() -> void:
	_remove_slots()
	for path in _saved_files:
		DirAccess.make_dir_recursive_absolute(String(path).get_base_dir())
		var file := FileAccess.open(String(path), FileAccess.WRITE)
		file.store_buffer(_saved_files[path] as PackedByteArray)
