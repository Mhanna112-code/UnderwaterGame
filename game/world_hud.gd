# The dive readout, drawn rather than written.
#
# One pip per salvage site: amber and lit means something is still standing
# over it, green and hollow means it is aboard. That is the whole status
# display, and it uses the same legend as the beacons outside, so a player
# who has learned the lights already knows how to read this.
extends Control

const AMBER := Color(1.0, 0.76, 0.36)
const GREEN := Color(0.45, 0.92, 0.62)
const DIM := Color(0.36, 0.48, 0.54)

var guarded := 0
var total := 0

func _draw() -> void:
	var x := size.x - 34.0
	for i in range(total):
		var at := Vector2(x - float(i) * 30.0, 34.0)
		var got: bool = i >= guarded
		_part(at, 9.0, GREEN if got else AMBER, got)

# the regulator in outline: the same silhouette as the thing on the seabed
func _part(at: Vector2, r: float, col: Color, hollow: bool) -> void:
	var w := 2.2
	draw_arc(at, r * 0.62, 0.0, TAU, 20, col, w)
	draw_line(at + Vector2(-r, 0), at + Vector2(-r * 0.62, 0), col, w)
	draw_line(at + Vector2(r * 0.62, 0), at + Vector2(r, 0), col, w)
	draw_arc(at + Vector2(0, -r * 0.85), r * 0.32, PI, TAU, 12, col, w)
	if not hollow:
		draw_circle(at, r * 0.3, col)
