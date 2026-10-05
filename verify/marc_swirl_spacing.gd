extends SceneTree
## SWIRL-1: exported positions must leave swimming gaps, not just fewer instances.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(970435)
	for size in [16.0, 18.0, 20.0, 24.0, 28.0, 32.0]:
		var room := SwirlRoom.new()
		room.setup(Rect2(Vector2(12, -7), Vector2(size, size)), 0, 1.25)
		root.add_child(room)
		await physics_frame
		var rings: Dictionary = {}
		for point in room.positions():
			var planar := Vector2(point.x - room.center.x, point.z - room.center.z)
			var radius_key := roundi(planar.length() * 100)
			if not rings.has(radius_key):
				rings[radius_key] = []
			rings[radius_key].append(planar)
		var minimum := INF
		for ring in rings.values():
			ring.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.angle() < b.angle())
			for index in ring.size():
				minimum = minf(minimum, (ring[index] as Vector2).distance_to(ring[(index + 1) % ring.size()]))
		_expect(not rings.is_empty() and minimum >= 3.5,
			"SWIRL-1 neighboring columns leave no intended swim gap at size %.1f: %.3fm" % [size, minimum])
		print("SWIRL SPACING|size=", size, "|rocks=", room.positions().size(), "|min_chord=", minimum)
		room.queue_free()
		await process_frame
	for finding in findings:
		print("FINDING ", finding)
	print("MARC SWIRL SPACING: clean" if findings.is_empty() else "MARC SWIRL SPACING: failed")
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
