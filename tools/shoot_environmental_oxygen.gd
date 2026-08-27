# Autoplays the dedicated zero-oxygen puzzle scene while capturing a
# continuous frame sequence for issue/PR evidence.
# Usage: mkdir -p /tmp/oxygen-frames &&
#   godot --path . --script tools/shoot_environmental_oxygen.gd -- /tmp/oxygen-frames
extends SceneTree

var out_dir := "/tmp/oxygen-frames"
var harness: OxygenPlaytest
var capturing := false
var capture_index := 0
var frame := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = String(args[0])
	harness = (load("res://game/oxygen_playtest.tscn") as PackedScene).instantiate() as OxygenPlaytest
	root.add_child(harness)
	call_deferred("_run")

func _process(_delta: float) -> bool:
	frame += 1
	if capturing and frame % 4 == 0:
		root.get_texture().get_image().save_png("%s/frame_%04d.png" % [out_dir, capture_index])
		capture_index += 1
	return false

func _run() -> void:
	while not harness.ready_for_playtest:
		await process_frame
	var world := harness.world
	var mermaid := world.divers[0] as Diver
	var diver_boy := world.divers[1] as Diver
	var marine_man := world.divers[2] as Diver
	var camera := world.cam
	camera.global_position = Vector3(27.0, 24.0, 25.0)
	camera.look_at(Vector3(27.0, 2.0, 10.0), Vector3.UP)
	world.set_physics_process(false)
	capturing = true

	_set_step("O2 0/100 on all three • Marine Man: Shockwave rubble (0 O2)", 2)
	marine_man.use_ability()
	await create_timer(1.0).timeout

	mermaid.global_position = Vector3(22.0, 2.0, 9.0)
	diver_boy.global_position = Vector3(22.0, 2.0, 10.0)
	marine_man.global_position = Vector3(22.0, 2.0, 11.0)
	await _grapple(diver_boy, "Diver Boy: Grapple crossing 1/3 (O2 stays 0)")
	await _swap(mermaid, diver_boy, "Mermaid: Swap 1/3 (O2 stays 0)")
	await _grapple(diver_boy, "Diver Boy: Grapple crossing 2/3 (O2 stays 0)")
	await _swap(mermaid, marine_man, "Mermaid: Swap 2/3 (O2 stays 0)")
	await _swap(mermaid, diver_boy, "Mermaid: Swap 3/3 (O2 stays 0)")
	await _grapple(diver_boy, "Diver Boy: Grapple crossing 3/3 — entire party across")

	harness.status_label.text = "All three across at O2 0/100 • occupying the three plates"
	for i in range(3):
		(world.divers[i] as Diver).global_position = Vector3(39.0, 2.0, 7.5 + i * 2.5)
		await create_timer(0.45).timeout
	world._check_gap_puzzle()
	await create_timer(2.5).timeout
	harness.status_label.text = "PASS • zero O2 → all abilities worked → goal opened without reload"
	harness.status_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6))
	await create_timer(2.0).timeout
	capturing = false
	print("oxygen frames  %d in %s" % [capture_index, out_dir])
	quit()

func _set_step(text: String, active: int) -> void:
	harness.status_label.text = text
	harness.world.active = active
	harness.world._update_hud()
	harness.world._update_hp_bar()
	harness.world._update_oxygen_bar()

func _grapple(diver_boy: Diver, label: String) -> void:
	await create_timer(Diver.GRAPPLE_COOLDOWN + 0.05).timeout
	_set_step(label, 1)
	var eye := diver_boy.global_position + Vector3(0.0, diver_boy.height * 0.4, 0.0)
	diver_boy.use_ability((Vector3(32.0, 2.0, 10.0) - eye).normalized())
	await create_timer(Diver.GRAPPLE_PULL_DURATION + 0.55).timeout

func _swap(mermaid: Diver, target: Diver, label: String) -> void:
	await create_timer(Diver.SWAP_COOLDOWN + 0.05).timeout
	_set_step(label, 0)
	mermaid.use_ability(Vector3.ZERO, target)
	await create_timer(0.8).timeout
