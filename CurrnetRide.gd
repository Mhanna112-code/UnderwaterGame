extends Path3D

func _ready() -> void:
	var curve := path.curve
	var local := path.to_local(diver.global_position)
	var offset := curve.get_closest_offset(local)           # distance along the spline
	var center := path.to_global(curve.sample_baked(offset))
	var ahead  := path.to_global(curve.sample_baked(offset + 0.5))
	var flow_dir := (ahead - center).normalized()           # direction the current flows here
	var from_center := diver.global_position - center      # how far off the centreline
	const TUBE_RADIUS := 2.0
	const FLOW_SPEED := 9.0
	const WALL_PULL := 6.0

	var push := flow_dir * FLOW_SPEED
	var dist := from_center.length()
	if dist > TUBE_RADIUS * 0.7:          # near the edge: pull back toward the middle, gently at first
		var t := (dist - TUBE_RADIUS * 0.7) / (TUBE_RADIUS * 0.3)
		push -= from_center.normalized() * WALL_PULL * t
	diver.external_push = push
