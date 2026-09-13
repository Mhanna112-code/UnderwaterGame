# Captured regression: entering the rendered light column at ordinary diving
# height must start the first tutorial battle.  The beam is a 12 m tall mesh
# whose origin is at its vertical center; this deliberately exercises the
# player-visible base of that column rather than teleporting to that origin.
# Usage: godot --headless --path . --script verify/intro_sequence.gd
extends SceneTree

const TIMEOUT_SECONDS := 2.0

var world: World
var started_at := 0
var moved_into_beam := false
var findings: Array[String] = []
var _slot_path := ""
var _slot_backup := PackedByteArray()
var _slot_existed := false

func _initialize() -> void:
	_slot_path = ProjectSettings.globalize_path(SaveManager.slot_path(2))
	_slot_existed = FileAccess.file_exists(_slot_path)
	if _slot_existed:
		var previous := FileAccess.open(_slot_path, FileAccess.READ)
		_slot_backup = previous.get_buffer(previous.get_length())
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	started_at = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if not moved_into_beam:
		if world.title_screen == null or world.divers.is_empty() or world.light_beam == null:
			return false
		# Use the same New Game signal a player invokes. skip_intro_for_test
		# bypasses only the draft narration so this gate can reach the world.
		world.title_screen.new_game_chosen.emit(2)
		var d: Diver = world.divers[world.active] as Diver
		d.global_position = Vector3(
			world.light_beam.global_position.x,
			d.global_position.y,
			world.light_beam.global_position.z
		)
		d.force_update_transform()
		moved_into_beam = true
		return false

	var tutorial_battles := 0
	for child in world.get_children():
		if child is Battle and (child as Battle).tutorial_encounter:
			tutorial_battles += 1
	if tutorial_battles == 1:
		print("intro beam           visible column started one tutorial battle")
		_finish(0)
		return true
	if tutorial_battles > 1:
		findings.append("DUPLICATE FIRST FIGHT: entering the beam opened %d tutorial battles" % tutorial_battles)
		return _report()
	if Time.get_ticks_msec() - started_at > int(TIMEOUT_SECONDS * 1000.0):
		findings.append("BEAM SOFTLOCK: a diver inside the visible light column never reached tutorial combat")
		return _report()
	return false

func _report() -> bool:
	for finding in findings:
		push_error(finding)
	_finish(1)
	return true

func _finish(status: int) -> void:
	if _slot_existed:
		var restore := FileAccess.open(_slot_path, FileAccess.WRITE)
		restore.store_buffer(_slot_backup)
	elif FileAccess.file_exists(_slot_path):
		DirAccess.remove_absolute(_slot_path)
	quit(status)
