# Real checkpoint round trips for mutable world state. Uses a save slot far
# outside the three slots exposed by the title UI and removes it on exit.
#
# Usage: godot --headless --path . --script verify/persistence.gd
extends SceneTree

const TEST_SLOT := 918273
const ROCK_ZERO_POSITION := Vector3(6.0, 1.0, -7.0)

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_save()
	var world := await _fresh_world()
	world._on_title_new_game(TEST_SLOT)

	var rock := _rock_at(world, ROCK_ZERO_POSITION)
	if rock == null:
		findings.append("SETUP: rock_0 was not built")
		_finish()
		return
	rock.on_shockwave(rock.global_position, 1.0)
	await process_frame

	var orb := _only_orb(world)
	if orb == null:
		findings.append("SETUP: breaking rock_0 did not create one ItemOrb")
		_finish()
		return
	var item_id := orb.item_id
	orb._on_body_entered(world.divers[0])
	await process_frame
	if int(world.inventory.get(item_id, 0)) != 1:
		findings.append("SETUP: collecting the orb did not add exactly one %s" % item_id)

	world._on_game_over_restart()
	for _i in range(4):
		await process_frame
	var restored := current_scene as World
	if restored == null:
		findings.append("RESTART SCENE: no World is active after checkpoint restart")
	else:
		if int(restored.inventory.get(item_id, 0)) != 0:
			findings.append("INVENTORY ROLLBACK: unsaved %s survived checkpoint restart" % item_id)
		if _rock_at(restored, ROCK_ZERO_POSITION) == null:
			findings.append("WORLD ROLLBACK: rock_0 stayed broken after loading the pre-break checkpoint")

	var restart_clean := findings.is_empty()
	print("restart rollback       inventory + rock restored atomically" if restart_clean else "restart rollback       FAILED")
	if restored != null and restart_clean:
		await _test_pending_drop_round_trip(restored)
	_finish()

# persistence: a saved uncollected drop reloads exactly once — guards
# against reward loss or duplication.
func _test_pending_drop_round_trip(world: World) -> void:
	var rock := _rock_at(world, ROCK_ZERO_POSITION)
	rock.on_shockwave(rock.global_position, 1.0)
	await process_frame
	var pending := _only_orb(world)
	if pending == null:
		findings.append("PENDING SETUP: breaking rock_0 did not create exactly one orb")
		return
	var item_id := pending.item_id
	world._on_save_requested(world.divers[0])
	world._on_game_over_restart()
	for _i in range(4):
		await process_frame

	var loaded := current_scene as World
	var loaded_orb := _only_orb(loaded)
	if _rock_at(loaded, ROCK_ZERO_POSITION) != null:
		findings.append("PENDING SOURCE: saved consumed rock_0 returned")
	if loaded_orb == null or loaded_orb.item_id != item_id:
		findings.append("PENDING REWARD: saved uncollected %s did not reload exactly once" % item_id)
		return
	if int(loaded.inventory.get(item_id, 0)) != 0:
		findings.append("PENDING DUPLICATE: %s exists in inventory before its reloaded orb is collected" % item_id)

	loaded_orb._on_body_entered(loaded.divers[0])
	await process_frame
	loaded._on_save_requested(loaded.divers[0])
	loaded._on_game_over_restart()
	for _i in range(4):
		await process_frame
	var collected := current_scene as World
	if _only_orb(collected) != null:
		findings.append("COLLECTED DUPLICATE: orb returned after collection was saved")
	if int(collected.inventory.get(item_id, 0)) != 1:
		findings.append("COLLECTED COUNT: expected exactly one saved %s, got %d" % [item_id, int(collected.inventory.get(item_id, 0))])
	print("pending reward         source -> orb -> inventory exactly once" if findings.is_empty() else "pending reward         FAILED")

func _fresh_world() -> World:
	var packed := load("res://game/world.tscn") as PackedScene
	var world := packed.instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	return world

func _rock_at(world: World, wanted: Vector3) -> CrackedWall:
	for child in world.get_children():
		if child is CrackedWall and (child as CrackedWall).position.distance_to(wanted) < 0.1:
			return child as CrackedWall
	return null

func _only_orb(world: World) -> ItemOrb:
	var found: ItemOrb
	for child in world.get_children():
		if child is ItemOrb:
			if found != null:
				return null
			found = child as ItemOrb
	return found

func _remove_test_save() -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)

func _finish() -> void:
	_remove_test_save()
	for finding in findings:
		print("FINDING  " + finding)
	print("PERSISTENCE: clean" if findings.is_empty() else "PERSISTENCE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
