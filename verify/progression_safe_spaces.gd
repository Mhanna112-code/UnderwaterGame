# `progression route: every tutorial, beacon, checkpoint, capstone, lab, and
# boss-approach phase rejects ordinary encounter signals — guards against a
# distance roll making authored combat ambiguous`.
extends SceneTree

const ROLLS_PER_SPACE := 100
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	paused = false
	var diver := world.divers[world.active] as Diver

	# Tutorial itself is protected before the public route begins.
	_probe(world, diver, "tutorial")
	world.route.start_after_tutorial()
	for beat_index in range(RouteProgression.BEATS.size()):
		var beat := world.route.active_beat()
		diver.global_position = world.route.active_position()
		diver.force_update_transform()
		_probe(world, diver, "%s beacon/checkpoint" % String(beat.id))
		# Old guardian locations are also protected while the critical path is
		# active, so a random signal cannot be mistaken for their deliberate UI.
		for site_value in Sites.guarded():
			diver.global_position = (site_value as Dictionary).at as Vector3
			diver.force_update_transform()
			_probe(world, diver, "%s guardian space during %s" % [String((site_value as Dictionary).site), String(beat.id)])
		world.route.begin_active_encounter()
		world.route.resolve_active_encounter("won")

	world.queue_free()
	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("progression safe spaces ordinary encounter rolls rejected in every authored phase")
	quit(0 if findings.is_empty() else 1)

func _probe(world: World, diver: Diver, label: String) -> void:
	for _roll in range(ROLLS_PER_SPACE):
		diver.encounter_triggered.emit()
	if world.battle != null:
		findings.append("ROUTE INTERRUPTION: %s mounted an ordinary Battle" % label)
		world.battle.queue_free()
		world.battle = null
		world.battling = false

