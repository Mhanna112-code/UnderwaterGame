extends SceneTree

var failures: Array[String] = []
var receipts: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Six independent bounded shapes: near/middle/far in translated scenes,
	# including golden shimmer and a shooter moving after the shot.
	for offset in [Vector3.ZERO, Vector3(100, -15, 45)]:
		for distance in [2.5, 6.0, 11.0]:
			await _shot_case(offset, distance)
			if not failures.is_empty():
				_finish()
				return
	await _abandoned_shooter_case()
	await _scene_teardown_case()
	await _anchor_and_occlusion_case()
	await _touch_collection_case()
	_finish()

func _shot_case(offset: Vector3, distance: float) -> void:
	receipts.clear()
	var stage := Node3D.new()
	root.add_child(stage)
	var shooter := _diver(stage, offset)
	var eye := offset + Vector3(0, shooter.height * 0.4, 0)
	var orb := _orb(stage, eye + Vector3.FORWARD * distance, distance > 5.0)
	var bystander := _diver(stage, orb.global_position + Vector3(2, 0, 0))
	await physics_frame
	await physics_frame
	shooter.use_ability(Vector3.FORWARD)
	_check(not shooter.is_grappling(), "ORB-2: light reward does not start a diver traversal pull")
	_check(not shooter.can_use_ability(), "ORB-3: successful orb shot spends its cooldown even at zero Oxygen")
	await create_timer(0.16).timeout
	_check(shooter.global_position.is_equal_approx(offset), "ORB-2: shooter stays put before player-directed movement")
	# Another party member intersects the moving item. This must not steal it.
	bystander.global_position = orb.global_position
	shooter.global_position += Vector3(1.5, 0.4, 0)
	shooter.use_ability(Vector3.FORWARD)
	await create_timer(0.5).timeout
	_check(receipts.size() == 1, "ORB-1/3: real shot collects exactly once at distance %s, offset %s" % [distance, offset])
	if receipts.size() == 1:
		_check(receipts[0].collector == shooter.get_instance_id(), "ORB-2: collection identifies the shooter, not the nearest bystander")
		_check(receipts[0].item == "potion", "ORB-2: authored item identity survives reeling")
		var chest := shooter.global_position + Vector3(0, shooter.height * 0.5, 0)
		_check((receipts[0].at as Vector3).distance_to(chest) < 0.02, "ORB-2: item follows the moving shooter to their current position")
	_check(shooter.stats.oxygen == 0.0, "ORB-1: environmental grapple remains available without Oxygen")
	stage.queue_free()
	await process_frame

func _abandoned_shooter_case() -> void:
	receipts.clear()
	var stage := Node3D.new()
	root.add_child(stage)
	var shooter := _diver(stage, Vector3.ZERO)
	var start := Vector3(0, shooter.height * 0.4, -6)
	var orb := _orb(stage, start, true)
	await physics_frame
	await physics_frame
	shooter.use_ability(Vector3.FORWARD)
	await create_timer(0.15).timeout
	shooter.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	_check(receipts.is_empty(), "ORB-4: freed shooter cannot receive a reward")
	_check(is_instance_valid(orb) and orb.global_position.is_equal_approx(start), "ORB-4: abandoned reel restores a reachable reward")
	var replacement := _diver(stage, Vector3.ZERO)
	await physics_frame
	await physics_frame
	replacement.use_ability(Vector3.FORWARD)
	await create_timer(0.7).timeout
	_check(receipts.size() == 1, "ORB-4: surviving shooter can recollect the abandoned reward")
	if receipts.size() == 1:
		_check(receipts[0].collector == replacement.get_instance_id(), "ORB-4: no stale shooter identity survives cancellation")
	stage.queue_free()
	await process_frame

func _anchor_and_occlusion_case() -> void:
	receipts.clear()
	var stage := Node3D.new()
	root.add_child(stage)
	var shooter := _diver(stage, Vector3.ZERO)
	var eye := Vector3(0, shooter.height * 0.4, 0)
	var orb := _orb(stage, eye + Vector3(0, 0, -8), false)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 5, 0.5)
	shape.shape = box
	wall.add_child(shape)
	stage.add_child(wall)
	wall.global_position = eye + Vector3(0, 0, -3)
	await physics_frame
	await physics_frame
	shooter.use_ability(Vector3.FORWARD)
	await create_timer(0.7).timeout
	_check(receipts.is_empty() and is_instance_valid(orb), "ORB-5: solid walls occlude light-item shots")
	_check(shooter.can_use_ability(), "ORB-5: hitting a non-target wall spends no cooldown")
	wall.queue_free()
	orb.queue_free()
	await process_frame
	var anchor := GrappleAnchor.new()
	stage.add_child(anchor)
	anchor.global_position = Vector3(0, 0, -7)
	# A real party capsule on the shot line must not block the anchor.
	_diver(stage, Vector3(0, 0, -3))
	await physics_frame
	await physics_frame
	shooter.use_ability(Vector3.FORWARD)
	_check(shooter.is_grappling(), "ORB-5: anchor still starts traversal despite an intervening buddy")
	await create_timer(0.6).timeout
	_check(shooter.global_position.distance_to(Vector3(0, 0, -6)) < 0.02, "ORB-5: anchor pull reaches its original one-metre standoff")
	_check(not shooter.is_grappling(), "ORB-5: anchor traversal releases movement ownership")
	stage.queue_free()
	await process_frame

func _scene_teardown_case() -> void:
	receipts.clear()
	var stage := Node3D.new()
	root.add_child(stage)
	var shooter := _diver(stage, Vector3.ZERO)
	_orb(stage, Vector3(0, shooter.height * 0.4, -6), false)
	await physics_frame
	await physics_frame
	shooter.use_ability(Vector3.FORWARD)
	await create_timer(0.1).timeout
	stage.queue_free()
	await process_frame
	await create_timer(0.6).timeout
	_check(receipts.is_empty(), "ORB-4: scene teardown cancels a pending reward without a late callback")

func _touch_collection_case() -> void:
	receipts.clear()
	var stage := Node3D.new()
	root.add_child(stage)
	var collector := _diver(stage, Vector3.ZERO)
	var orb := _orb(stage, Vector3(0, 0, -4), false)
	orb.grapple_only = false
	await physics_frame
	await physics_frame
	collector.global_position = orb.global_position
	await physics_frame
	await physics_frame
	_check(receipts.size() == 1, "ORB-3: ordinary pickups still collect once by actual body overlap")
	stage.queue_free()
	await process_frame

func _diver(stage: Node3D, at: Vector3) -> Diver:
	var diver := Diver.new()
	diver.model_name = "Prototype_1(1910)"
	stage.add_child(diver)
	diver.global_position = at
	diver.stats.oxygen = 0.0
	return diver

func _orb(stage: Node3D, at: Vector3, golden: bool) -> ItemOrb:
	var orb := ItemOrb.new()
	orb.item_id = "potion"
	orb.grappleable = true
	orb.grapple_only = true
	orb.golden = golden
	stage.add_child(orb)
	orb.global_position = at
	orb.collected.connect(func(id: String, diver: Diver) -> void:
		receipts.append({"item": id, "collector": diver.get_instance_id(), "at": orb.global_position})
		# Signal handlers run synchronously, before queue_free. Simulate a
		# second body event during reward granting, not a private collect call.
		if receipts.size() == 1:
			orb.body_entered.emit(diver))
	return orb

func _finish() -> void:
	if failures.is_empty():
		print("MARC ORB REEL: clean")
		quit()
	else:
		print("MARC ORB REEL: failures %s" % str(failures))
		quit(1)

func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
