# The fight, with no words in it.
#
# Five playtesters across two prototypes have now said they did not read the
# text. The previous readout named every limb, spelled out every telegraph and
# labelled every button, which is exactly the thing this team demonstrably
# does not read. Everything here is drawn: bars for health, pips for air,
# glyphs for what an action does, and an arrow that points where a move would
# take you.
#
# Numerals survive on purpose. "-4" over the limb you just hit was asked for
# by name, and a digit is not prose.
extends Control

signal chose(action: Dictionary)
signal ended_turn()
signal picked_diver(index: int)
signal dismissed()

const INK := Color(0.90, 0.95, 0.97)
const DIM := Color(0.42, 0.52, 0.56)
const WARN := Color(0.96, 0.45, 0.36)
const GOOD := Color(0.46, 0.82, 0.68)
const AIR := Color(0.62, 0.86, 0.95)
const PANEL := Color(0.06, 0.13, 0.16, 0.72)

# glyph per ability kind, read off the sim rather than off the ability's name
const KIND_GLYPH := {
	"hit": "impact",
	"hit_wide": "sweep",
	"hit_shove": "shove",
	"hit_and_step": "step",
	"shut": "clamp",
}
const TRAIT_GLYPH := {
	"brittle": "crack",
	"pressurised": "burst",
	"plated": "shield",
	"leaking": "drop",
}

var combat: Combat
var selected := 0
var locked_out := false          # the enemy is swinging; nothing is clickable
var tint_of: Array = []          # diver index -> colour, matches the models
var station_dir: Callable        # station -> Vector2 on screen, for move arrows

var _hits: Array = []            # [{rect, kind, payload}]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	_hits = []
	if combat == null:
		return
	_draw_air()
	_draw_enemy()
	_draw_divers()
	if combat.outcome != "ongoing":
		_draw_outcome()
		return
	if not locked_out:
		_draw_actions()

# ---- air, as pips ------------------------------------------------------

func _draw_air() -> void:
	var have := combat.air_this_turn()
	var cap := Combat.AIR_PER_TURN
	for i in range(cap):
		var at := Vector2(30.0 + float(i) * 26.0, 34.0)
		if i < have:
			draw_circle(at, 9.0, AIR)
		else:
			draw_arc(at, 9.0, 0.0, TAU, 20, DIM, 2.0)

# ---- the enemy: one bar per limb, with what it is aiming at ------------

func _draw_enemy() -> void:
	var aimed: Dictionary = {}
	for it in combat.intents():
		aimed[int(it.limb)] = it
	var w := 250.0
	var x := size.x * 0.5 - w * 0.5
	for li in range(combat.LIMB_NAMES.size()):
		var y := 26.0 + float(li) * 34.0
		var broken: bool = combat.limb_broken[li]
		var frac: float = 0.0 if broken else clampf(float(combat.limb_hp[li]) / maxf(1.0, float(_limb_max(li))), 0.0, 1.0)

		draw_rect(Rect2(x, y, w, 16.0), PANEL)
		if not broken:
			draw_rect(Rect2(x, y, w * frac, 16.0), GOOD if frac > 0.35 else WARN)
		draw_rect(Rect2(x, y, w, 16.0), DIM, false, 1.5)
		if broken:
			# a broken limb gets struck through rather than described
			draw_line(Vector2(x + 4, y + 8), Vector2(x + w - 4, y + 8), DIM, 2.0)

		# what it does to you, on the left of the bar
		var tr := combat.trait_of(li)
		if tr != "":
			var known: bool = combat.known(li)
			_glyph(String(TRAIT_GLYPH.get(tr, "impact")), Vector2(x - 26.0, y + 8.0), 9.0,
				INK if known else DIM, not known)

		# the announced swing, on the right: a chevron per point of damage is
		# unreadable, so it is one arrow plus the number it will cost you
		if aimed.has(li) and not broken and int(combat.limb_stun[li]) == 0:
			var it: Dictionary = aimed[li]
			_glyph("aim", Vector2(x + w + 22.0, y + 8.0), 9.0, WARN)
			_number(int(it.dmg), Vector2(x + w + 44.0, y + 8.0), WARN)
		elif not broken and int(combat.limb_stun[li]) > 0:
			_glyph("clamp", Vector2(x + w + 22.0, y + 8.0), 9.0, AIR)

func _limb_max(li: int) -> int:
	return int((combat.enc.limbs[li] as Dictionary).hp)

# ---- the squad: a chip each, click to pick ----------------------------

func _draw_divers() -> void:
	var y := size.y - 146.0
	for i in range(combat.divers.size()):
		var d = combat.divers[i]
		var x := 30.0 + float(i) * 152.0
		var r := Rect2(x, y, 132.0, 58.0)
		draw_rect(r, PANEL)
		var col: Color = tint_of[i] if i < tint_of.size() else INK
		# the colour block IS the diver: it matches the model on the stage
		draw_rect(Rect2(x + 6.0, y + 6.0, 20.0, 32.0), col if not d.down else DIM)
		var frac: float = clampf(float(d.hp) / maxf(1.0, float(d.max_hp)), 0.0, 1.0)
		draw_rect(Rect2(x + 34.0, y + 14.0, 90.0, 14.0), Color(0, 0, 0, 0.35))
		if not d.down:
			draw_rect(Rect2(x + 34.0, y + 14.0, 90.0 * frac, 14.0), GOOD if frac > 0.35 else WARN)
		draw_rect(Rect2(x + 34.0, y + 14.0, 90.0, 14.0), DIM, false, 1.0)
		if d.down:
			_glyph("down", Vector2(x + 79.0, y + 21.0), 10.0, WARN)
		# Defences as icon plus numeral, the habit the status screens Marc
		# sent all share: a glyph carries which stat it is, a digit carries
		# how much. Nothing that reads as zero is drawn at all.
		var sx := x + 34.0
		for pair in [["shield", int(d.stats.def)], ["swerve", int(d.stats.dodge)], ["hex", int(d.barrier)]]:
			if int(pair[1]) <= 0:
				continue
			_glyph(String(pair[0]), Vector2(sx + 6.0, y + 36.0), 6.0, AIR)
			_number(int(pair[1]), Vector2(sx + 19.0, y + 36.0), AIR)
			sx += 30.0
		if i == selected and not d.down:
			draw_rect(r, INK, false, 2.0)
		if not d.down and not locked_out:
			_hits.append({"rect": r, "kind": "pick", "i": i})

# ---- what this diver may do, as glyphs --------------------------------

func _draw_actions() -> void:
	var acts: Array = []
	for a in Bots.legal(combat):
		if int(a.i) == selected:
			acts.append(a)
	var box := 62.0
	var gap := 10.0
	var total := float(acts.size()) * (box + gap) - gap
	var x := size.x * 0.5 - total * 0.5
	var y := size.y - 78.0
	for a in acts:
		var r := Rect2(x, y, box, box)
		draw_rect(r, PANEL)
		draw_rect(r, DIM, false, 1.5)
		var c := r.position + r.size * 0.5
		match String(a.kind):
			"attack":
				var d = combat.divers[int(a.i)]
				var k: Dictionary = d.kit[int(a.get("slot", 0))]
				_glyph(String(KIND_GLYPH.get(String(k.kind), "impact")), c - Vector2(0, 6), 16.0, INK)
				_cost(r, int(d.cost))
				_number(int(k.dmg), c + Vector2(0, 18), INK)
			"analyze":
				_glyph("eye", c, 16.0, INK)
				_cost(r, Combat.ANALYZE_COST)
			"move":
				# the arrow points where you would end up, so the board
				# itself explains the button
				var dir := Vector2.RIGHT
				if station_dir.is_valid():
					dir = station_dir.call(int(a.s), int(combat.divers[int(a.i)].station))
				_arrow(c, dir, 18.0, AIR)
		_hits.append({"rect": r, "kind": "act", "a": a})
		x += box + gap

	# end turn, on its own at the right
	var er := Rect2(size.x - 104.0, size.y - 78.0, 62.0, 62.0)
	draw_rect(er, PANEL)
	draw_rect(er, WARN if _threatened() else DIM, false, 1.5)
	_glyph("hourglass", er.position + er.size * 0.5, 16.0, INK)
	_hits.append({"rect": er, "kind": "end"})

func _cost(r: Rect2, n: int) -> void:
	for i in range(n):
		draw_circle(r.position + Vector2(9.0 + float(i) * 12.0, 9.0), 4.0, AIR)

func _threatened() -> bool:
	return not combat.threatened_stations().is_empty()

# ---- the end -----------------------------------------------------------

func _draw_outcome() -> void:
	var won: bool = combat.outcome == "victory"
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	draw_rect(Rect2(c.x - 120.0, c.y - 80.0, 240.0, 160.0), PANEL)
	_glyph("part" if won else "down", c - Vector2(0, 16), 34.0, GOOD if won else WARN)
	var r := Rect2(c.x - 44.0, c.y + 32.0, 88.0, 40.0)
	draw_rect(r, PANEL)
	draw_rect(r, INK, false, 2.0)
	_arrow(r.position + r.size * 0.5, Vector2.UP, 14.0, INK)
	_hits.append({"rect": r, "kind": "done"})

# ---- input -------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton) or not (e as InputEventMouseButton).pressed:
		return
	var at: Vector2 = (e as InputEventMouseButton).position
	for h in _hits:
		if not (h.rect as Rect2).has_point(at):
			continue
		match String(h.kind):
			"pick": picked_diver.emit(int(h.i))
			"act": chose.emit(h.a as Dictionary)
			"end": ended_turn.emit()
			"done": dismissed.emit()
		accept_event()
		return

# ---- the glyph set -----------------------------------------------------
#
# Line art, drawn rather than imported, so nothing here waits on an art
# delivery and every symbol can be tuned in the same file that uses it.

func _glyph(kind: String, at: Vector2, r: float, col: Color, hollow := false) -> void:
	var w := 2.4
	match kind:
		"impact":
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var inner: float = r * (0.34 if i % 2 == 0 else 0.5)
				draw_line(at + Vector2(cos(a), sin(a)) * inner, at + Vector2(cos(a), sin(a)) * r, col, w)
		"sweep":
			for i in range(3):
				var o := float(i - 1) * r * 0.45
				draw_polyline([at + Vector2(-r * 0.5, o - r * 0.3), at + Vector2(r * 0.2, o),
					at + Vector2(-r * 0.5, o + r * 0.3)], col, w)
		"shove":
			draw_line(at + Vector2(-r, 0), at + Vector2(r * 0.4, 0), col, w)
			_arrow(at + Vector2(r * 0.55, 0), Vector2.RIGHT, r * 0.55, col)
		"step":
			draw_arc(at, r * 0.55, PI * 0.9, TAU * 0.95, 16, col, w)
			_arrow(at + Vector2(r * 0.5, r * 0.42), Vector2(0.7, 0.7), r * 0.45, col)
		"clamp":
			draw_line(at + Vector2(-r, -r * 0.45), at + Vector2(r, -r * 0.45), col, w)
			draw_line(at + Vector2(-r, r * 0.45), at + Vector2(r, r * 0.45), col, w)
			_arrow(at + Vector2(0, -r * 0.12), Vector2.DOWN, r * 0.3, col)
			_arrow(at + Vector2(0, r * 0.12), Vector2.UP, r * 0.3, col)
		"eye":
			draw_arc(at, r * 0.85, PI * 1.15, PI * 1.85, 18, col, w)
			draw_arc(at, r * 0.85, PI * 0.15, PI * 0.85, 18, col, w)
			draw_circle(at, r * 0.3, col)
		"aim":
			_arrow(at, Vector2.LEFT, r, col)
		"crack":
			draw_polyline([at + Vector2(-r * 0.2, -r), at + Vector2(r * 0.25, -r * 0.2),
				at + Vector2(-r * 0.25, r * 0.2), at + Vector2(r * 0.2, r)], col, w)
		"burst":
			for i in range(6):
				var a2 := TAU * float(i) / 6.0
				draw_line(at, at + Vector2(cos(a2), sin(a2)) * r, col, w)
		"shield":
			draw_polyline([at + Vector2(-r * 0.7, -r * 0.6), at + Vector2(r * 0.7, -r * 0.6),
				at + Vector2(r * 0.7, r * 0.1), at, at + Vector2(-r * 0.7, r * 0.1),
				at + Vector2(-r * 0.7, -r * 0.6)], col, w)
		"drop":
			draw_circle(at + Vector2(0, r * 0.25), r * 0.55, col)
			draw_polyline([at + Vector2(-r * 0.3, 0), at + Vector2(0, -r), at + Vector2(r * 0.3, 0)], col, w)
		"swerve":
			draw_arc(at, r * 0.9, PI * 0.15, PI * 1.15, 16, col, w)
			_arrow(at + Vector2(r * 0.6, -r * 0.5), Vector2(0.8, -0.6), r * 0.6, col)
		"hex":
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(7):
				var a3 := TAU * float(i) / 6.0
				pts.append(at + Vector2(cos(a3), sin(a3)) * r)
			draw_polyline(pts, col, w)
		"down":
			draw_line(at + Vector2(-r * 0.7, -r * 0.7), at + Vector2(r * 0.7, r * 0.7), col, w)
			draw_line(at + Vector2(r * 0.7, -r * 0.7), at + Vector2(-r * 0.7, r * 0.7), col, w)
		"hourglass":
			draw_polyline([at + Vector2(-r * 0.7, -r), at + Vector2(r * 0.7, -r), at + Vector2(-r * 0.7, r),
				at + Vector2(r * 0.7, r), at + Vector2(-r * 0.7, -r)], col, w)
		"part":
			# the regulator, in outline: what you came down here to take
			draw_arc(at, r * 0.62, 0.0, TAU, 24, col, w)
			draw_line(at + Vector2(-r, 0), at + Vector2(-r * 0.62, 0), col, w)
			draw_line(at + Vector2(r * 0.62, 0), at + Vector2(r, 0), col, w)
			draw_arc(at + Vector2(0, -r * 0.85), r * 0.34, PI, TAU, 14, col, w)
	if hollow:
		draw_arc(at, r * 1.35, 0.0, TAU, 20, DIM, 1.6)

func _arrow(at: Vector2, dir: Vector2, r: float, col: Color) -> void:
	var d := dir.normalized()
	var tip := at + d * r
	var back := at - d * r * 0.5
	draw_line(back, tip, col, 2.6)
	var side := Vector2(-d.y, d.x) * r * 0.42
	draw_polyline([tip - d * r * 0.5 + side, tip, tip - d * r * 0.5 - side], col, 2.6)

# Digits, drawn as seven-segment strokes. The HUD carries no font on purpose:
# once a font is loaded, somebody writes a sentence with it.
const SEG := [
	[1, 1, 1, 0, 1, 1, 1], [0, 0, 1, 0, 0, 1, 0], [1, 0, 1, 1, 1, 0, 1],
	[1, 0, 1, 1, 0, 1, 1], [0, 1, 1, 1, 0, 1, 0], [1, 1, 0, 1, 0, 1, 1],
	[1, 1, 0, 1, 1, 1, 1], [1, 0, 1, 0, 0, 1, 0], [1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 0, 1, 1],
]

func _number(n: int, at: Vector2, col: Color) -> void:
	var s := str(maxi(0, n))
	var w := 9.0
	var x := at.x - float(s.length()) * (w + 3.0) * 0.5
	for i in range(s.length()):
		_digit(int(s[i]), Vector2(x + float(i) * (w + 3.0), at.y - 8.0), col)

func _digit(d: int, at: Vector2, col: Color) -> void:
	var w := 9.0
	var h := 16.0
	var s: Array = SEG[clampi(d, 0, 9)]
	var t := 2.0
	if s[0]: draw_line(at + Vector2(0, 0), at + Vector2(w, 0), col, t)
	if s[1]: draw_line(at + Vector2(0, 0), at + Vector2(0, h * 0.5), col, t)
	if s[2]: draw_line(at + Vector2(w, 0), at + Vector2(w, h * 0.5), col, t)
	if s[3]: draw_line(at + Vector2(0, h * 0.5), at + Vector2(w, h * 0.5), col, t)
	if s[4]: draw_line(at + Vector2(0, h * 0.5), at + Vector2(0, h), col, t)
	if s[5]: draw_line(at + Vector2(w, h * 0.5), at + Vector2(w, h), col, t)
	if s[6]: draw_line(at + Vector2(0, h), at + Vector2(w, h), col, t)
