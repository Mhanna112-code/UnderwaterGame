# Can you actually see the fight, or is the HUD sitting on top of it?
#
# This exists because of a bug that was visible in every screenshot anybody
# took and still went unreported for weeks, because "the combat screen covers
# the characters" reads as a taste complaint rather than a defect. It was
# three defects stacked:
#
#   1. The stage viewport was PRESET_FULL_RECT and the HUD was drawn over it.
#   2. The HUD ran on Godot's default PanelContainer theme, which is 60%
#      black rather than opaque, so it did not hide the lower half of the
#      fight so much as smear it.
#   3. The stage camera was a hand-placed position, tuned once, and aimed
#      every combatant into the half of the screen the HUD occupied. At
#      1280x720 all five were below its top edge while the top half of the
#      screen was empty water.
#
# None of that is checkable by reading. This starts real fights, at a real
# resolution, and projects every combatant's head and feet through the actual
# stage camera to see where they land.
#
# MUST run windowed, not headless: a headless run gets a 64x64 window and
# every screen-space number it produces is meaningless.
#
# Usage: godot --path . --resolution 1280x720 --script verify/stage_framing.gd
extends SceneTree

const FIGHTS := 8
# _fit_panel_height() is deferred, and the stage only takes its final height
# once it has run. Measuring before that measures a zero-height stage.
const SETTLE_FRAMES := 20
# How far a bar may end up above the head it belongs to. Some gap is the
# point; enough of one and you can no longer tell whose bar it is.
const MAX_BAR_DRIFT := 90.0

var world: Node3D
var frames := 0
var settle := 0
var runs := 0
var findings: Array = []

func _initialize() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames < 4:
		return false

	if world.battle == null:
		if runs >= FIGHTS:
			return _report()
		world._start_battle()
		return false

	var b: Battle = world.battle
	if b._stage_cam == null or b._stage_container == null:
		return false
	settle += 1
	if settle < SETTLE_FRAMES:
		return false
	settle = 0
	runs += 1
	_check(b)
	world.battle.free()
	world.battle = null
	world.battling = false
	return false

func _check(b: Battle) -> void:
	var panel: Control = b._bottom_panel
	var stage: Control = b._stage_container
	var screen := Vector2(root.get_visible_rect().size)

	print("fight %d: %d party vs %d enemies, stage %.0fpx of %.0f, HUD %.0fpx" % [
		runs, b.party.size(), b.enemies.size(), stage.size.y, screen.y, panel.size.y])

	# The stage is the band between the two bars. If it runs under either,
	# the fight is being drawn somewhere nobody can see it. Checked on the
	# stage's bottom edge in screen coordinates rather than on its height,
	# because it no longer starts at the top of the screen.
	if absf(stage.position.y + stage.size.y - panel.global_position.y) > 1.0:
		findings.append("STAGE UNDER THE BOTTOM STRIP: stage ends at y=%.0f, the strip starts at y=%.0f" % [
			stage.position.y + stage.size.y, panel.global_position.y])
	var queue_bottom: float = b._queue_bar.position.y + b._queue_bar.size.y
	if stage.position.y + 0.5 < queue_bottom:
		findings.append("STAGE UNDER THE TURN BAR: stage starts at y=%.0f, the turn bar ends at y=%.0f" % [
			stage.position.y, queue_bottom])

	# And the HUD has to be opaque, or the stage shows through it.
	var sb := panel.get_theme_stylebox("panel")
	var alpha: float = (sb as StyleBoxFlat).bg_color.a if sb is StyleBoxFlat else 0.0
	if alpha < 0.99:
		findings.append("SEE THROUGH HUD: the panel background is %.2f alpha, the fight shows through it" % alpha)

	# Viewport pixels to screen pixels: the SubViewportContainer stretches,
	# and the stage no longer starts at the top of the screen.
	var vpz := Vector2(b._stage_vp.size)
	var sc := Vector2(stage.size.x / maxf(1.0, vpz.x), stage.size.y / maxf(1.0, vpz.y))
	var top: float = stage.position.y
	var bottom: float = stage.position.y + stage.size.y

	for e in (b.party + b.enemies):
		if not e.has("actor") or not is_instance_valid(e.actor):
			continue
		var a := e.actor as Node3D
		var h := 1.9
		if a is Diver:
			h = (a as Diver).height
		elif a is Goblin:
			h = (a as Goblin).height
		var head: Vector2 = b._stage_cam.unproject_position(a.global_position + Vector3(0, h, 0)) * sc + stage.position
		var foot: Vector2 = b._stage_cam.unproject_position(a.global_position) * sc + stage.position
		if head.y < top or foot.y > bottom or head.x < 0.0 or head.x > stage.size.x:
			findings.append("OUT OF FRAME: %s, head at (%.0f, %.0f) and feet at (%.0f, %.0f), stage runs y=%.0f to %.0f" % [
				String(e.display_name), head.x, head.y, foot.x, foot.y, top, bottom])

	# The bars belong to the combatants, so they have to be on screen, and
	# they have to stay near the combatant they name. Marc predicted the
	# overlap the moment this layout was proposed; the nudging that stops
	# bars stacking is also what can walk one halfway up the screen away
	# from its owner, so both are measured.
	var boxes: Array = []
	for e in (b.party + b.enemies):
		var box: Control = e.get("overhead")
		if box == null or not is_instance_valid(box) or not box.visible:
			continue
		var r := Rect2(box.position, box.size)
		if r.position.y < top - 0.5 or r.end.y > bottom + 0.5 or r.position.x < -0.5 or r.end.x > screen.x + 0.5:
			findings.append("BAR OFF SCREEN: %s's bar at %s size %s, stage runs y=%.0f to %.0f" % [
				String(e.display_name), r.position, r.size, top, bottom])
		for other in boxes:
			if r.intersects((other[1] as Rect2)):
				findings.append("BARS OVERLAP: %s and %s" % [String(e.display_name), String(other[0])])
		boxes.append([String(e.display_name), r])

		# How far the bar had to travel from where its owner's head is.
		if not e.has("actor") or not is_instance_valid(e.actor):
			continue
		var a2 := e.actor as Node3D
		var h2 := 1.9
		if a2 is Diver:
			h2 = (a2 as Diver).height
		elif a2 is Goblin:
			h2 = (a2 as Goblin).height
		var head2: Vector2 = b._stage_cam.unproject_position(
			a2.global_position + Vector3(0, h2, 0)) * sc + stage.position
		var drift: float = head2.y - r.end.y
		if drift > MAX_BAR_DRIFT:
			findings.append("BAR ADRIFT: %s's bar sits %.0fpx above their head, over the %.0fpx budget" % [
				String(e.display_name), drift, MAX_BAR_DRIFT])

func _report() -> bool:
	for f in findings:
		print("FINDING  " + f)
	print("STAGE FRAMING: clean over %d fights" % runs if findings.is_empty()
		else "STAGE FRAMING: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
