class_name MazePoster
extends Node3D

# A paper poster stuck flat on a wall: one diver portrait with scribbly
# "handwriting" lines underneath, and a blinking red light just below it to
# show it can be interacted with. Its +Z faces out of the wall. The artwork
# is built by build_art() - rendered once into a SubViewport for the 3D
# poster, and built again full size by PosterModal, from the same seed so
# both show the same scribbles. MazeLevel lights it while the diver is in
# reach and opens a PosterModal (with its `number`) on E.

const POSTER_SIZE := Vector2(1.2, 1.6)   # metres
const ART_BASE := Vector2(300, 400)      # build_art()'s layout units
const ART_PIXELS := Vector2i(600, 800)   # texture resolution
# Unshaded, so the paper reads the same in the dark water; brightness is
# the albedo tint - dimmed normally, full while the diver is in reach.
const DIM_TINT := Color(0.5, 0.5, 0.5)
const LIT_TINT := Color(1.0, 1.0, 1.0)

var diver_index := 0                     # 0 Maxilani, 1 Bucky, 2 Musashi (SwitchMinigameModal.POOLS)
var portrait: Texture2D
var number := 1                          # what the poster's modal shows under it
var scribble_seed := 0

var _material: StandardMaterial3D
# Interacted with: the poster goes green and its light stays green.
var seen := false
const SEEN_DIM_TINT := Color(0.45, 0.78, 0.45)
const SEEN_LIT_TINT := Color(0.7, 1.0, 0.7)
var _bulb_mat: StandardMaterial3D
var _bulb: MeshInstance3D
var _glow: OmniLight3D
var _blink: Tween

# Sets the poster up before it enters the tree.
func setup(diver: int, poster_number: int) -> void:
	diver_index = diver
	number = poster_number
	var pool: Array = SwitchMinigameModal.POOLS[diver]
	portrait = load(pool[randi() % pool.size()]) as Texture2D
	scribble_seed = randi()

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = ART_PIXELS
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.add_child(build_art(Vector2(ART_PIXELS), portrait, scribble_seed))
	add_child(viewport)

	var quad := QuadMesh.new()
	quad.size = POSTER_SIZE
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	_material = StandardMaterial3D.new()
	_material.albedo_texture = viewport.get_texture()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = DIM_TINT
	mesh.material_override = _material
	add_child(mesh)

	# Blinking red light just under the poster.
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	bulb.mesh = sphere
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.1, 0.1)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.1, 0.1)
	bulb_mat.emission_energy_multiplier = 3.0
	bulb.material_override = bulb_mat
	bulb.position = Vector3(0, -POSTER_SIZE.y * 0.5 - 0.22, 0.05)
	add_child(bulb)
	_bulb = bulb
	_bulb_mat = bulb_mat
	var glow := OmniLight3D.new()
	_glow = glow
	glow.light_color = Color(1.0, 0.15, 0.15)
	glow.omni_range = 2.0
	glow.light_energy = 1.0
	glow.position = bulb.position + Vector3(0, 0, 0.2)
	add_child(glow)
	var blink := create_tween().set_loops()
	blink.tween_callback(func() -> void:
		bulb.visible = not bulb.visible
		glow.visible = bulb.visible)
	blink.tween_interval(0.5)
	_blink = blink

# Lit up (fully bright) while the diver is in reach.
func set_highlight(on: bool) -> void:
	if _material != null:
		if seen:
			_material.albedo_color = SEEN_LIT_TINT if on else SEEN_DIM_TINT
		else:
			_material.albedo_color = LIT_TINT if on else DIM_TINT

func mark_seen() -> void:
	if seen:
		return
	seen = true
	if _blink != null:
		_blink.kill()
	var green := Color(0.2, 1.0, 0.35)
	if _bulb_mat != null:
		_bulb_mat.albedo_color = green
		_bulb_mat.emission = green
		_bulb.visible = true
	if _glow != null:
		_glow.light_color = green
		_glow.visible = true
	set_highlight(true)

# The poster's front direction (out of the wall), flattened.
func facing() -> Vector3:
	var f := global_basis.z
	f.y = 0.0
	return f.normalized()

# The poster artwork at `art_size`: aged paper, two strips of tape, the
# portrait in a frame, and rows of wavy ink scribbles under it (unless
# `scribbles` is false). Layout is in ART_BASE units scaled to art_size's
# width; the paper fills art_size; `seed` fixes the scribbles.
static func build_art(art_size: Vector2, portrait_tex: Texture2D, seed: int, scribbles := true) -> Control:
	var k := art_size.x / ART_BASE.x
	var root := Control.new()
	root.size = art_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var paper := ColorRect.new()
	paper.color = Color(0.92, 0.87, 0.74)
	paper.size = art_size
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(paper)

	for tape_x in [40.0, 220.0]:
		var tape := ColorRect.new()
		tape.color = Color(0.95, 0.93, 0.8, 0.85)
		tape.size = Vector2(46, 16) * k
		tape.position = Vector2(tape_x, -2) * k
		tape.rotation = deg_to_rad(-8.0 if tape_x < 100.0 else 8.0)
		root.add_child(tape)

	var frame := ColorRect.new()
	frame.color = Color(0.18, 0.15, 0.12)
	frame.position = Vector2(26, 26) * k
	frame.size = Vector2(248, 233) * k
	root.add_child(frame)
	var pic := TextureRect.new()
	pic.texture = portrait_tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.position = Vector2(30, 30) * k
	pic.size = Vector2(240, 225) * k
	root.add_child(pic)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ink := Color(0.12, 0.14, 0.3, 0.9)
	for row in (4 if scribbles else 0):
		var line := Line2D.new()
		line.width = 2.2 * k
		line.default_color = ink
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.antialiased = true
		var base_y := 285.0 + row * 28.0
		var x := 34.0 + rng.randf_range(0.0, 10.0)
		var end_x := 266.0 - (rng.randf_range(0.0, 110.0) if row == 3 else rng.randf_range(0.0, 30.0))
		var freq := rng.randf_range(0.35, 0.6)
		var phase := rng.randf() * TAU
		while x < end_x:
			# Small gaps between "words".
			if rng.randf() < 0.06:
				x += rng.randf_range(6.0, 10.0)
				line.add_point(Vector2(x, base_y) * k)
			var y := base_y + sin(x * freq + phase) * rng.randf_range(2.0, 5.0) + rng.randf_range(-1.2, 1.2)
			line.add_point(Vector2(x, y) * k)
			x += rng.randf_range(2.5, 4.5)
		root.add_child(line)
	return root
