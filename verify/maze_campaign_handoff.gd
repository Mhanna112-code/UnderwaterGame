# INT-01: embedded area entry must preserve the live campaign party.
# Six bounded cases cover every active diver, with/without a downed member.
# Fixture skips onboarding and places the party near the normal entrance;
# this proves live state conservation, not navigation or cold-load persistence.
extends SceneTree

var findings: Array[String] = []
const STAT_FIELDS := ["hp_max", "strength", "defense", "agility", "accuracy",
	"evasion", "evasion_current", "oxygen_max", "level", "xp", "xp_to_next",
	"spell_points", "hp"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for selected in range(3):
		for downed in [false, true]:
			await _case(selected, downed)
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE CAMPAIGN HANDOFF: six cases clean" if findings.is_empty()
		else "MAZE CAMPAIGN HANDOFF: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _case(selected: int, downed: bool) -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.active = selected
	world.random_encounters_enabled = false
	world.route_state.prologue_complete = true
	world.route_state.tutorial_complete = false
	world.route_state.set_zone("deep")
	world.route_state.set_maze_door_state("available")
	world.route_state.set_lab_state("locked")
	world.inventory = {"potion": 3, "oxygen_cell": 2}
	world.key_items.assign(["current_pearl", "reef_plate"])
	var expected: Array[Dictionary] = []
	for i in range(3):
		var diver := world.divers[i] as Diver
		diver.stats.hp = 0 if downed and i == (selected + 1) % 3 else 4 + i
		diver.stats.oxygen = 41.25 + i * 7.0
		diver.stats.level = 2 + i
		diver.stats.xp = 7 + i
		diver.stats.spell_points = 2 + i
		diver.stats.evasion_current = i
		diver.stats.statuses = {"blindness": {"level": 1, "turns": 2}}
		diver.stats.temporary_modifiers = {"accuracy": -1, "evasion": 0}
		# Valid auto-equipped earned kit from the actual character catalogue.
		SpellTree.learn_all_available(diver, world.key_items)
		if i == 0 and not diver.sonar_active:
			diver.toggle_sonar()
		var values: Dictionary = {}
		for field in STAT_FIELDS:
			values[field] = diver.stats.get(field)
		expected.append({"model": diver.model_name, "stats": values,
			"oxygen": diver.stats.oxygen, "statuses": diver.stats.statuses.duplicate(true),
			"modifiers": diver.stats.temporary_modifiers.duplicate(true),
			"known": diver.known_spells.duplicate(), "equipped": diver.equipped_spells.duplicate(),
			"sonar": diver.sonar_active})
	# Physics owns the transition, not a direct call to its private helper.
	(world.divers[selected] as Diver).global_position = Vector3(263, 2, 16)
	for frame in range(12):
		await physics_frame
		if world.embedded_maze.maze_active:
			break
	await process_frame
	var label := "INT-01 active=%d downed=%s" % [selected, downed]
	if current_scene != world or not world.embedded_maze.maze_active:
		findings.append(label + ": normal area entry did not activate embedded MazeLevel")
	else:
		var maze := world.embedded_maze
		_expect(maze.active == selected, label + ": selected diver reset")
		_expect(maze.inventory == {"potion": 3, "oxygen_cell": 2}, label + ": inventory reset")
		_expect(maze.get("campaign_key_items") == ["current_pearl", "reef_plate"], label + ": campaign relics lost/mixed with door keys")
		_expect(maze.get("random_encounters_enabled") == false, label + ": global encounter preference lost")
		var route: Variant = maze.get("route_state")
		_expect(route is RouteState and route.prologue_complete and not route.tutorial_complete
			and route.lab_state == "locked", label + ": independent campaign progress lost")
		for i in range(3):
			var actual := maze.divers[i]
			var wanted := expected[i]
			_expect(actual.model_name == wanted.model, label + ": party identity changed")
			for field in STAT_FIELDS:
				_expect(actual.stats.get(field) == wanted.stats[field], label + ": diver %d %s reset" % [i, field])
			_expect(absf(actual.stats.oxygen - float(wanted.oxygen)) < 0.5, label + ": Oxygen reset")
			_expect(actual.stats.statuses == wanted.statuses and actual.stats.temporary_modifiers == wanted.modifiers,
				label + ": active effects erased")
			_expect(actual.known_spells == wanted.known and actual.equipped_spells == wanted.equipped,
				label + ": earned kit erased")
			_expect(actual.sonar_active == wanted.sonar, label + ": Sonar preference lost")
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
