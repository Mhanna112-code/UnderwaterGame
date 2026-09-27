# `Glassgoat review: Swap accepts A/D and Space and tells the player so —
# guards against an undiscoverable teammate-selection control scheme`.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	# The title path intentionally holds exploration abilities until the
	# tutorial/route handoff; this input contract is a free-world contract.
	world._intro_active = false
	world.active = 0
	world._update_hud()

	# Start the real Swap ability through the live input boundary. The selected
	# teammate is a public selector result; no selector state is faked here.
	world._unhandled_input(_key(KEY_E))
	_expect(world.target_selector.selecting, "SWAP START: E did not open teammate selection")
	if world.target_selector.selecting:
		var first := world.target_selector.current_target()
		world._unhandled_input(_key(KEY_D))
		_expect(world.target_selector.current_target() != first,
			"SWAP CONTROL: D did not choose the next teammate")
		world._unhandled_input(_key(KEY_A))
		_expect(world.target_selector.current_target() == first,
			"SWAP CONTROL: A did not choose the previous teammate")
		_expect(world.hud.text.contains("A/D") and world.hud.text.contains("Space"),
			"SWAP COPY: visible selection instructions do not advertise A/D and Space")
		world._unhandled_input(_key(KEY_SPACE))
		_expect(not world.target_selector.selecting,
			"SWAP CONTROL: Space did not confirm the highlighted teammate")

	# Steering identity must not masquerade as the route's forward beacon. A low
	# ring has no directional point and leaves the amber route post as the only
	# "go this way" landmark.
	world._update_active_cursor()
	var active_diver := world.divers[world.active] as Diver
	_expect(world._active_cursor.mesh is TorusMesh,
		"ACTIVE MARKER: active diver is still marked by a directional cone instead of a neutral halo")
	_expect(world._active_cursor.global_position.y - active_diver.global_position.y <= 0.25,
		"ACTIVE MARKER: selection halo floats high enough to read as route guidance")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("Glassgoat review: Swap A/D + Space control contract clean")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
