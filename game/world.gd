# The dive site: a seafloor, the three divers, and a camera you swim behind.
#
# Deliberately small. This exists so the team can get hands on the models and
# feel their scale and speed in motion, which no screenshot can settle, and
# so the next argument about the art is had in front of something playable.
#
# class_name so other nodes that need a live reference (MiniMap,
# TargetSelector) can type it properly instead of reading dynamic
# properties off a plain Node3D.
class_name World
extends Node3D

const CAST := [
	{"model": "Staff_Diver", "at": Vector3(0, 2.0, 0)},
	{"model": "Prototype_1(1910)", "at": Vector3(-3.6, 2.2, -3.0)},
	{"model": "Prototype_V(1922)", "at": Vector3(3.6, 2.4, -3.0)},
]

var divers: Array = []
var active := 0

# random encounters: each Diver tracks its own distance swum and fires
# encounter_triggered when it rolls one (see diver.gd). This just reacts -
# drops into a turn-based fight against a goblin grunt, Pokemon-style, and
# freezes the dive while game/battle.gd runs it.
var banner: Label
var _banner_timer := 0.0
var battling := false
var battle: Battle
var yaw := 0.0
var pitch := -0.16
var cam_dist := 6.5
var cam: Camera3D
var hud: Label
var mouse_look := false
var _t := 0.0

# First-person aim mode for aimed abilities (grapple): E enters it instead
# of firing right away, camera cuts to the diver's own eye line, left click
# fires, right click backs out. Nothing about the ability itself changes -
# use_ability() still does the actual raycast/pull, this only decides when
# it gets called.
var aiming := false

# Swap goes through TargetSelector instead of first-person aim: cycle
# between allies with Left/Right, Enter confirms, Escape cancels. See
# target_selector.gd for the selection logic and _start_ability()/
# _unhandled_input() below for how E and the arrow keys route into it.
var target_selector: TargetSelector

# P opens save_point_menu, but only while standing on a SavePoint (see
# _save_points/_toggle_save_menu/_update_save_point_prompt) - spell
# learning/equipping is deliberately unavailable anywhere else.
var save_point_menu: SavePointMenu
var _save_points: Array = []
var _showing_save_prompt := false

# Party-wide, not per-diver - a key item (current_pearl/reef_plate) unlocks
# a spell for whichever diver's tree gates on it, it isn't "held" by
# whoever happened to win the guardian fight. Same array object gets handed
# to save_point_menu.learn_ui in _ready() (see SpellTree.can_learn()'s
# key_items param) rather than copied, so appending here is automatically
# visible there without any extra sync step.
var key_items: Array[String] = []

# Which ItemGuardian.SPOTS item ids sonar has ever pinged (see
# Diver.update_sonar()) - MiniMap draws a marker for anything in here
# that isn't also in key_items yet (still unclaimed). Party-wide like
# key_items, not per-diver, and never cleared except implicitly by an id
# leaving this "revealed but unclaimed" state once it's actually claimed.
var revealed_key_items: Array[String] = []

# Every persistable world object (breakable rocks, the entrance blockade -
# see _build_breakable_rocks()/_build_highway()) that's already been
# consumed this run, by a stable id string ("rock_0", "entrance_blockade",
# etc.) rather than a node reference, since this is exactly what
# _serialize_state()/_load_save() read and write to the save file. Without
# this, loading a save always looked pristine again - the world geometry
# was rebuilt fresh in _ready() before any save was ever read, and nothing
# tracked which of those fresh rocks should immediately disappear again.
var consumed_world_ids: Array[String] = []

# id -> live CrackedWall node, populated at build time (_build_breakable_
# rocks()/_build_highway()) - _load_save() uses this to actually free the
# matching node the instant a loaded save says its id is already consumed,
# since consumed_world_ids by itself is just data, not something that
# removes anything on its own.
var _cracked_walls: Dictionary = {}

# Party-wide consumables (item_id -> count) - what an ItemOrb pickup or a
# non-key guardian reward actually adds to now, instead of Items.grant()
# applying instantly on pickup (see _on_item_orb_collected()/
# _grant_reward_item()). Only ever spent from inventory_menu.gd's Use
# button, via use_inventory_item() below - that's the one place
# Items.grant() is still called from.
var inventory: Dictionary = {}

# Stable rock id -> {item, position:[x,y,z]} for a reward that has spawned
# but has not entered inventory yet. This is the third mutually-exclusive
# reward state alongside an intact source rock and a collected inventory
# entry; serializing it prevents save-after-break-before-pickup from erasing
# the reward when the consumed rock is removed on load.
var pending_world_drops: Dictionary = {}

# Escape's pause menu - see _unhandled_input()'s ESCAPE branch for how it
# opens/closes (mutually exclusive with aiming/target_selector.selecting/
# save_point_menu, same guard shape those already use against each other)
# and _physics_process()'s gate for why movement actually stops while it's
# open, unlike save_point_menu (that gap predates this and isn't this
# menu's problem to fix).
var inventory_menu: InventoryMenu

# The title screen (New Game/Load Game, shown once at start and again on
# "Return to Title") and the game-over screen ("lost" a battle) - see
# _show_title_screen()/_show_game_over() below.
var title_screen: TitleScreen
var game_over_screen: GameOverScreen

# Set right before a guardian fight starts (see _on_item_guardian_triggered
# ()), read once in _on_battle_finished() and cleared immediately after -
# "" means an ordinary random encounter, nothing to hand out on a win.
var _pending_reward_item := ""

# Which save slot this run is playing into - set the instant the title
# screen resolves (New Game picks one and writes an initial save into it;
# Load Game picks one and reads from it), -1 only while the title screen
# itself is still up and nothing's been chosen yet. Everything that used
# to be an in-memory-only checkpoint (see _write_save()/_load_save() below)
# now reads/writes SaveManager.slot_path(_current_slot) instead, so a game
# over's "restart from save point" and an actual save-point visit are the
# same real file, and it all survives closing the game entirely.
var _current_slot := -1

# Scene reload is the only honest way to roll mutable geometry back to a
# checkpoint: _load_save() can remove objects a save says are consumed, but
# it cannot recreate a CrackedWall already queue_free()'d after that save.
# This one-shot handoff survives reload_current_scene(), then the fresh World
# consumes and clears it at the end of _ready().
static var _restart_slot := -1

# Full state: per-diver position/stats/spells plus the world-level
# inventory/key_items/active - everything _write_save()'s caller (a save
# point) or the initial New Game write needs to reproduce the run exactly.
# Vector3 isn't JSON-serializable, so position goes in as a plain [x,y,z]
# array (see _load_save()'s reverse conversion).
func _serialize_state() -> Dictionary:
	var divers_data: Array = []
	for d in divers:
		var s: CombatantStats = d.stats
		divers_data.append({
			"position": [d.position.x, d.position.y, d.position.z],
			"known_spells": (d.known_spells as Array).duplicate(),
			"equipped_spells": (d.equipped_spells as Array).duplicate(),
			"stats": {
				"hp_max": s.hp_max, "strength": s.strength, "defense": s.defense,
				"agility": s.agility, "accuracy": s.accuracy, "evasion": s.evasion,
				"barrier_max": s.barrier_max, "oxygen_max": s.oxygen_max,
				"level": s.level, "xp": s.xp, "xp_to_next": s.xp_to_next,
				"spell_points": s.spell_points,
				"grow_hp": s.grow_hp, "grow_strength": s.grow_strength,
				"grow_defense": s.grow_defense, "grow_agility": s.grow_agility,
				"grow_accuracy": s.grow_accuracy, "grow_evasion": s.grow_evasion,
				"hp": s.hp, "barrier": s.barrier, "oxygen": s.oxygen,
			},
		})
	return {
		"active": active,
		"inventory": inventory.duplicate(),
		"pending_world_drops": pending_world_drops.duplicate(true),
		"key_items": key_items.duplicate(),
		"revealed_key_items": revealed_key_items.duplicate(),
		"consumed_world_ids": consumed_world_ids.duplicate(),
		"divers": divers_data,
	}

func _write_save() -> void:
	if _current_slot < 0:
		return
	SaveManager.write_slot(_current_slot, _serialize_state())

# Bails out and does nothing rather than a half-restore if the save data
# doesn't actually match divers[] one-to-one (a missing/corrupt slot reads
# back as {} from SaveManager, whose "divers" key then defaults to []) -
# a wrong-shaped restore silently leaving some divers untouched would be a
# worse bug than just not restoring at all.
func _load_save() -> void:
	var data: Dictionary = SaveManager.read_slot(_current_slot)
	var divers_data: Array = data.get("divers", [])
	if divers_data.size() != divers.size():
		return
	for i in range(divers.size()):
		var d: Diver = divers[i]
		var snap: Dictionary = divers_data[i]
		var pos: Array = snap.get("position", [d.position.x, d.position.y, d.position.z])
		d.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		d.known_spells.assign((snap.get("known_spells", []) as Array).duplicate())
		d.equipped_spells.assign((snap.get("equipped_spells", []) as Array).duplicate())
		var sd: Dictionary = snap.get("stats", {})
		var s: CombatantStats = d.stats
		s.hp_max = int(sd.get("hp_max", s.hp_max))
		s.strength = int(sd.get("strength", s.strength))
		s.defense = int(sd.get("defense", s.defense))
		s.agility = int(sd.get("agility", s.agility))
		s.accuracy = int(sd.get("accuracy", s.accuracy))
		s.evasion = int(sd.get("evasion", s.evasion))
		s.barrier_max = int(sd.get("barrier_max", s.barrier_max))
		s.oxygen_max = float(sd.get("oxygen_max", s.oxygen_max))
		s.level = int(sd.get("level", s.level))
		s.xp = int(sd.get("xp", s.xp))
		s.xp_to_next = int(sd.get("xp_to_next", s.xp_to_next))
		s.spell_points = int(sd.get("spell_points", s.spell_points))
		s.grow_hp = int(sd.get("grow_hp", s.grow_hp))
		s.grow_strength = int(sd.get("grow_strength", s.grow_strength))
		s.grow_defense = int(sd.get("grow_defense", s.grow_defense))
		s.grow_agility = int(sd.get("grow_agility", s.grow_agility))
		s.grow_accuracy = int(sd.get("grow_accuracy", s.grow_accuracy))
		s.grow_evasion = int(sd.get("grow_evasion", s.grow_evasion))
		s.hp = int(sd.get("hp", s.hp_max))
		s.barrier = int(sd.get("barrier", s.barrier_max))
		s.oxygen = float(sd.get("oxygen", s.oxygen_max))
	inventory = (data.get("inventory", {}) as Dictionary).duplicate()
	pending_world_drops = (data.get("pending_world_drops", {}) as Dictionary).duplicate(true)
	# .assign(), not a plain `=` - key_items/revealed_key_items/
	# consumed_world_ids are all typed Array[String], and JSON.parse_string()
	# only ever hands back a plain untyped Array. Plain `=` replaces the
	# variable's array reference outright with that untyped one, which
	# throws "Trying to assign an array of type Array to a variable of
	# type Array[String]" at runtime - .assign() instead coerces into the
	# existing typed array in place, same pattern known_spells/
	# equipped_spells above already use for exactly this reason.
	key_items.assign((data.get("key_items", []) as Array).duplicate())
	revealed_key_items.assign((data.get("revealed_key_items", []) as Array).duplicate())
	consumed_world_ids.assign((data.get("consumed_world_ids", []) as Array).duplicate())
	active = int(data.get("active", 0))

	# The world was already rebuilt pristine before this ever runs (see
	# TitleScreen's New-Game/Load-Game flow, or the full scene reload
	# "Return to Title" does) - anything this save says is already
	# consumed needs to be removed again right now, or a loaded save would
	# hand back a leveled-up party standing in a world that looks like
	# nothing was ever broken (exactly the gap that prompted this).
	for id in consumed_world_ids:
		if _cracked_walls.has(id):
			(_cracked_walls[id] as CrackedWall).queue_free()
			_cracked_walls.erase(id)
	for id in pending_world_drops:
		var drop: Dictionary = pending_world_drops[id]
		var saved_position: Array = drop.get("position", [])
		if saved_position.size() == 3:
			_spawn_world_drop(String(id), String(drop.get("item", "")), Vector3(
				float(saved_position[0]), float(saved_position[1]), float(saved_position[2])))

	_update_hud()
	_update_hp_bar()
	_update_oxygen_bar()

# get_tree().paused freezes every node whose process_mode isn't ALWAYS -
# the whole world (movement, physics, encounters, the HUD's own per-frame
# updates) just stops, and TitleScreen/GameOverScreen (both explicitly
# ALWAYS, see their own _ready()) are the only things still receiving
# input. Mirrors the pause Battle already puts the world into during a
# fight, just triggered by a menu screen instead of battle.gd.
func _show_title_screen() -> void:
	get_tree().paused = true
	title_screen.open()

# New Game always starts from the fresh, level-1 divers _ready()'s CAST
# loop just built (nothing here resets stats - there's nothing to reset
# yet) - just claims a slot and writes the very first save into it, same
# role the old implicit end-of-_ready() checkpoint used to serve, now a
# real file instead of an in-memory snapshot.
func _on_title_new_game(slot: int) -> void:
	_current_slot = slot
	_write_save()
	title_screen.close()
	get_tree().paused = false

func _on_title_load_game(slot: int) -> void:
	_current_slot = slot
	_load_save()
	title_screen.close()
	get_tree().paused = false

func _show_game_over() -> void:
	get_tree().paused = true
	game_over_screen.open()

func _on_game_over_restart() -> void:
	_restart_slot = _current_slot
	get_tree().paused = false
	get_tree().reload_current_scene()

# reload_current_scene() re-runs World._ready() from scratch - every rock,
# cracked wall, item guardian and diver goes back to its pristine starting
# state, which a hand-written "reset everything" function would otherwise
# have to reproduce piece by piece. Lands back on the title screen exactly
# like a cold launch does, since _ready() always ends by showing it.
func _on_game_over_title() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# The gap sequence's three-plate finale (see _build_highway()). Populated
# there, checked every physics frame in _check_gap_puzzle().
var _lock_plates: Array = []
var _doors: Array = []
var _puzzle_goal: Waypoint
var _puzzle_solved := false

# [a, b] Vector3 endpoint pairs, one per wall built by _build_wall() -
# read directly by game/mini_map.gd (world.gd has a class_name now, so
# MiniMap can type its reference and read this like any other property).
var _wall_segments: Array = []
var minimap: MiniMap

# The camera's one alternate mode: instead of chasing the active diver,
# hold on `_camera_focus_target` (used both by TargetSelector while
# picking a swap target, and for a brief confirmation hold on whoever a
# swap just traded places with - see focus_camera_on()/
# return_camera_to_player() and _on_diver_swapped()). auto_return_after
# is 0 for "stay until told otherwise" (TargetSelector explicitly calls
# return_camera_to_player() on confirm/cancel) or >0 for "hold this long,
# then snap back to the player on its own."
enum CameraMode { PLAYER, FOCUS }
var camera_mode := CameraMode.PLAYER
var _camera_focus_target: Node3D = null
var _camera_focus_timer := 0.0

# test seam: verify/swim.gd steers the player without a keyboard. Nothing in
# the game writes these, so the shipped build reads the real keys.
var scripted := false
var scripted_dir := Vector3.ZERO
var scripted_rise := 0.0

# Marks whichever diver TAB currently has you steering - same green cone,
# same "hover above the head" positioning target_selector.gd's own cursor
# already uses for a swap target, so "this is who you're currently in
# control of" reads as the same visual language as "this is who you're
# about to swap into." Hidden rather than left dangling over a diver that
# doesn't apply right now: mid-swap-selection (target_selector's own cursor
# is already doing this job for the target being picked), first-person aim
# (there's no "above your own head" view to show it in), and battling (the
# dive site isn't even what's on screen).
var _active_cursor: MeshInstance3D

func _ready() -> void:
	cam = $Camera3D
	hud = $HUD/Controls
	banner = Label.new()
	banner.name = "Banner"
	banner.offset_left = 16.0
	banner.offset_top = 80.0
	banner.offset_right = 900.0
	banner.offset_bottom = 130.0
	banner.add_theme_font_size_override("font_size", 20)
	banner.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	$HUD.add_child(banner)

	minimap = MiniMap.new()
	minimap.world = self
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -166.0
	minimap.offset_top = 10.0
	minimap.offset_right = -10.0
	minimap.offset_bottom = 166.0
	$HUD.add_child(minimap)

	save_point_menu = SavePointMenu.new()
	save_point_menu.save_requested.connect(_on_save_requested)
	$HUD.add_child(save_point_menu)
	save_point_menu.learn_ui.key_items = key_items

	inventory_menu = InventoryMenu.new()
	inventory_menu.world = self
	$HUD.add_child(inventory_menu)

	_build_hp_bar()
	_build_oxygen_bar()
	_build_active_cursor()

	target_selector = TargetSelector.new()
	target_selector.world = self
	target_selector.confirmed.connect(_on_swap_target_confirmed)
	target_selector.cancelled.connect(_on_swap_target_cancelled)
	add_child(target_selector)

	_build_site()
	for c in CAST:
		var d := Diver.new()
		d.model_name = String(c.model)
		d.position = c.at as Vector3
		d.world = self
		add_child(d)
		divers.append(d)
		d.encounter_triggered.connect(_on_encounter_triggered.bind(d))
		d.swapped_with.connect(_on_diver_swapped.bind(d))
		target_selector.register_character(d)
	_update_hud()

	title_screen = TitleScreen.new()
	title_screen.new_game_chosen.connect(_on_title_new_game)
	title_screen.load_game_chosen.connect(_on_title_load_game)
	$HUD.add_child(title_screen)

	game_over_screen = GameOverScreen.new()
	game_over_screen.restart_chosen.connect(_on_game_over_restart)
	game_over_screen.title_chosen.connect(_on_game_over_title)
	$HUD.add_child(game_over_screen)

	# A game-over restart must rebuild the scene before applying its save so
	# unsaved geometry and inventory roll back as one checkpoint. Cold launch
	# still opens the title screen exactly as before.
	if _restart_slot >= 0:
		_current_slot = _restart_slot
		_restart_slot = -1
		_load_save()
		title_screen.close()
		get_tree().paused = false
		_announce("You wake back at your last save.")
	else:
		_show_title_screen()

# A floor and some rock so there is parallax to swim past: without something
# to move relative to, motion at this scale reads as standing still.
func _build_site() -> void:
	var floor_body := StaticBody3D.new()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.24, 0.24)
	fm.roughness = 1.0
	floor_mesh.material_override = fm
	floor_body.add_child(floor_mesh)
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 0.4, 120)
	fs.shape = box
	fs.position.y = -0.2
	floor_body.add_child(fs)
	add_child(floor_body)

	# One MultiMesh, not 46 nodes with 46 collision bodies. The browser build
	# was taking most of a minute to show its first frame and every node set up
	# at startup was part of that bill. Rocks are scenery: they do not need to
	# be solid, and they do not need to be separate objects.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260814          # same site every run: a level you can talk about
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 0.7
	rock.radial_segments = 7
	rock.rings = 4
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.13, 0.19, 0.21)
	rock_mat.roughness = 1.0
	rock.surface_set_material(0, rock_mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock
	mm.instance_count = 46
	for i in range(46):
		var sz := rng.randf_range(0.8, 3.6)
		var a := rng.randf() * TAU
		var dist := rng.randf_range(7.0, 48.0)
		var t := Transform3D()
		t = t.scaled(Vector3(sz, sz * rng.randf_range(0.5, 0.9), sz))
		t = t.rotated(Vector3.UP, rng.randf() * TAU)
		t.origin = Vector3(cos(a) * dist, sz * 0.15, sin(a) * dist)
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

	_build_breakable_rocks()
	_build_highway()
	_build_item_guardians()

# A couple of small CrackedWalls scattered in the open dive site, before
# the tunnel entrance - unlike the entrance blockade (a full-width gate),
# these are just optional side pickups: break one with shockwave and it
# pops an ItemOrb instead of handing out a fixed reward directly (see
# _on_breakable_rock_broken()) - what actually comes out is rolled fresh
# per break (Items.random_drop()), not always the same potion. No invisible
# collision extension (collision_height/width stay 0) since nothing needs
# to stop a diver going around one, only breaking it matters.
#
# disguised_as_scenery_rock = true - these look exactly like the ambient
# rock scatter from _build_site() until shockwaved, discoverable by
# actually sweeping the site rather than obviously marked out as "a thing"
# the way the old brown box read (see cracked_wall.gd's own comment on
# the flag). The entrance blockade below stays a plain (non-disguised)
# box - a gate should still read as a gate.
func _build_breakable_rocks() -> void:
	const SPOTS := [Vector3(6.0, 1.0, -7.0), Vector3(-7.0, 1.0, 5.0)]
	for i in range(SPOTS.size()):
		var spot: Vector3 = SPOTS[i]
		var id := "rock_%d" % i
		var rock := CrackedWall.new()
		rock.span = Vector3(1.1, 1.1, 1.1)
		rock.disguised_as_scenery_rock = true
		rock.position = spot
		rock.broken.connect(_on_breakable_rock_broken.bind(id, spot))
		# Separate listener purely for save persistence (see
		# _on_world_object_consumed()/consumed_world_ids) - kept apart from
		# _on_breakable_rock_broken() above so "spawn a reward" and "record
		# that this is now permanently gone" stay two independent jobs, the
		# same way cracked_wall.gd itself never mixes reward logic into its
		# own break detection.
		rock.broken.connect(_on_world_object_consumed.bind(id))
		add_child(rock)
		_cracked_walls[id] = rock

# id and spot are bound at connect time (see _build_breakable_rocks()) - the
# `broken` signal stays ability/reward-agnostic. The stable id ties together
# the consumed source and its pending reward across save/load.
func _on_breakable_rock_broken(id: String, spot: Vector3) -> void:
	var item_id := Items.random_drop()
	var drop_position := spot + Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6))
	pending_world_drops[id] = {
		"item": item_id,
		"position": [drop_position.x, drop_position.y, drop_position.z],
	}
	_spawn_world_drop(id, item_id, drop_position)

func _spawn_world_drop(id: String, item_id: String, drop_position: Vector3) -> void:
	if item_id == "":
		return
	var orb := ItemOrb.new()
	orb.item_id = item_id
	# Small scatter so a pop doesn't sit dead-center in the rubble - purely
	# cosmetic, the pickup radius (see item_orb.gd) covers either way.
	orb.position = drop_position
	orb.collected.connect(_on_item_orb_collected.bind(id))
	add_child(orb)

# Shared by every persistable CrackedWall's `broken` signal (reward rocks
# AND the entrance blockade - see _build_breakable_rocks()/_build_highway())
# - just records that `id` is gone for good, so a later _write_save() call
# captures it and a later _load_save() knows to free it again on a fresh
# world rebuild (see consumed_world_ids/_cracked_walls above). Doesn't
# touch the node itself; on_shockwave() already queue_free()s it - this is
# purely bookkeeping for persistence, same separation _on_breakable_rock_
# broken() (the reward-spawning listener) already keeps from this.
func _on_world_object_consumed(id: String) -> void:
	if not consumed_world_ids.has(id):
		consumed_world_ids.append(id)
	_cracked_walls.erase(id)

func _on_item_orb_collected(item_id: String, _d: Diver, drop_id: String) -> void:
	pending_world_drops.erase(drop_id)
	_add_to_inventory(item_id)

# Party-wide, not applied to `d` (who physically swam into the orb) at all
# anymore - see inventory/use_inventory_item()'s own header comments for
# why an item sits in the inventory until the player chooses to use it
# instead of applying itself the instant it's picked up.
func _add_to_inventory(item_id: String) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
	_announce("Picked up a %s." % display)

# The only place Items.grant() still runs from - called by
# inventory_menu.gd's Use button. Applies to whichever diver is currently
# being steered, same as the old instant-pickup behavior did, just delayed
# until the player actually chooses to spend it.
#
# Refuses (announces why, doesn't touch the count) rather than spending
# the item when it wouldn't do anything - Items.would_help() is the same
# check inventory_menu.gd's Use button already disables on, kept here too
# so this can never waste a potion even if it's ever called some other
# way than clicking that button.
func use_inventory_item(item_id: String) -> void:
	var count: int = int(inventory.get(item_id, 0))
	if count <= 0 or divers.is_empty():
		return
	var diver: Diver = divers[active]
	if not Items.would_help(item_id, diver.stats):
		var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
		_announce("%s wouldn't do anything right now." % display)
		return
	var msg := Items.grant(item_id, diver.stats)
	if msg != "":
		_announce(msg)
	inventory[item_id] = count - 1
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	_update_hp_bar()

# Every move/spell a given diver can use from the pause menu's "Party
# Spells" tab right now - their BASE_MOVES entries (see battle.gd) plus
# whatever they've learned in the spell tree (known_spells, not just
# equipped_spells - see spell_tree.gd's own header comment on why), each
# filtered down to just the ones tagged "inventory": true. Returns move/
# spell-def dictionaries as-is (mixed shape - BASE_MOVES uses "name",
# spell defs use "display" - see _party_spell_label() below for reading
# either one back).
func _inventory_spells_for(d: Diver) -> Array:
	var out: Array = []
	for mv in Battle.BASE_MOVES.get(d.model_name, []):
		if bool((mv as Dictionary).get("inventory", false)):
			out.append(mv)
	for spell_id in d.known_spells:
		var def: Dictionary = SpellTree.find_def(d.model_name, spell_id)
		if bool(def.get("inventory", false)):
			out.append(def)
	return out

func _party_spell_label(spell: Dictionary) -> String:
	return String(spell.get("display", spell.get("name", "")))

# Same oxygen economy as casting it in battle - a spell that costs 16
# oxygen there shouldn't become a free, infinite-use heal just because
# there's no battle running right now (oxygen_cost defaults to 0.0 same as
# battle.gd, so Mermaid's free base Heal really does stay free here too).
# Called by the menu before it lets a spell be picked at all - see
# inventory_menu.gd's caster-picker, which disables anyone who can't
# currently afford it, same as battle.gd's move menu already does.
func can_afford_party_spell(spell: Dictionary, caster: Diver) -> bool:
	return caster.stats.oxygen >= float(spell.get("oxygen_cost", 0.0))

# Resolves a "heal"/"revive" party spell straight against target.stats,
# same math battle.gd's _apply_heal()/_apply_revive() use, just without a
# live Battle around to run it through - there's no accuracy check and no
# enemy to miss against, so this is the minimum needed to reuse the same
# effect data in both places. Deducts the caster's oxygen same as a real
# cast would (see can_afford_party_spell() above); does nothing if the
# spell's effect isn't one this menu knows how to apply (e.g. someone
# mistags a damage move "inventory" - there's no opponent to swing it at
# outside battle, so it's a silent no-op rather than a crash).
func use_party_spell(spell: Dictionary, caster: Diver, target: Diver) -> void:
	if not can_afford_party_spell(spell, caster):
		return
	caster.stats.oxygen -= float(spell.get("oxygen_cost", 0.0))
	var s := target.stats
	var amount := int(spell.get("amount", 0))
	var label := _party_spell_label(spell)
	match String(spell.get("effect", "")):
		"heal":
			var before := s.hp
			s.hp = mini(s.hp_max, s.hp + amount)
			var changed := s.hp - before
			if changed > 0:
				_announce("%s - %s recovers %d HP." % [label, _display_name(target.model_name), changed])
			else:
				_announce("%s - %s is already at full health." % [label, _display_name(target.model_name)])
		"revive":
			if s.hp > 0:
				_announce("%s isn't down." % _display_name(target.model_name))
				return
			s.hp = mini(s.hp_max, amount)
			_announce("%s - %s is back up!" % [label, _display_name(target.model_name)])
		_:
			return
	_update_hp_bar()
	_update_oxygen_bar()

# Two fixed guardian spots, each sitting on exactly the key item
# spell_tree.gd's two capstone spells are gated behind (current_pearl for
# Staff_Diver's Tidal Burst, reef_plate for Prototype_V(1922)'s Bulwark
# Stance) - see items.gd's ITEMS entries for both. Placed well clear of the
# scattered rocks/CAST start positions/highway, out in the open dive site
# where _build_site()'s rock scatter already reaches (dist up to 48).
func _build_item_guardians() -> void:
	const SPOTS := [
		{"item": "current_pearl", "at": Vector3(16.0, 1.2, 12.0), "radius": 10},
		{"item": "reef_plate", "at": Vector3(-16.0, 1.2, -12.0), "radius": 10},
	]
	"""for entry in SPOTS:
		var guardian := ItemGuardian.new()
		guardian.item_id = String(entry.item)
		guardian.position = entry.at as Vector3
		add_child(guardian)

		# Decorative only - a real Goblin instance standing just beside the
		# guardian spot so "an enemy is here" is visible before you ever get
		# close enough to trigger the fight, not just an invisible volume
		# (offset sideways so it doesn't visually clip through the spiky
		# guardian mesh). No collision (see goblin.gd's own header - display
		# only), so it can't block movement or be mistaken for the trigger
		# itself.
		var decoy := Goblin.new()
		decoy.position = (entry.at as Vector3) + Vector3(1.1, 0.0, 0.0)
		add_child(decoy)

		guardian.triggered.connect(_on_item_guardian_triggered.bind(guardian, decoy))"""

# A straight corridor out past the rest of the scattered rocks - and the
# whole first real gate, not just scenery to swim through. In order:
#   0. A save point sits before the entrance blockade, in the open dive
#      site - a rest/prep stop before the gate, not a reward for clearing
#      it (see save_point.gd).
#   1. Rubble blocks the entrance - only Marine Man's shockwave clears it
#      (an invisible collision extension well above the visible rocks
#      rules out just swimming over the top - see cracked_wall.gd).
#   2. A whirlpool over a real gap in the floor. Getting close warns you;
#      getting caught sucks you in, costs HP, and sweeps you back - unless
#      you're mid-grapple, which is exempt (see whirlpool.gd). Nothing
#      ever disarms it - there is no bridge, no permanent safe crossing.
#      Every plain swim through it gets caught, every single time. A
#      second GrappleAnchor sits right before it as a staging point; the
#      real crossing anchor is on the far side.
#   3. Reaching that far anchor used to unlock Mermaid's swap ability (see
#      grapple_anchor.gd's on_grappled_to()) - swap now starts available
#      from the beginning like every other diver's ability (see diver.gd's
#      BASE_STATS), so this anchor's unlock call is a no-op today. Grapple
#      and swap are still the only two ways across the whirlpool.
#   4. Three lit plates on the far side. All three divers standing on
#      their own plate at once opens the way past END_X - which means
#      getting all three across by grapple/swap alone, since nothing
#      ever makes the whirlpool safe to swim through.
# Every piece here is a reusable class (CrackedWall, GrappleAnchor,
# Whirlpool, LockPlate, Waypoint) - this function is just where they get
# placed and wired together for this one gate.
func _build_highway() -> void:
	const START_X := 15.0
	const GAP_START_X := 24.0
	const GAP_END_X := 30.0
	const END_X := 45.0
	const LANE_Z := 10.0
	const LANE_HALF_WIDTH := 4.0
	const WALL_HEIGHT := 6.0

	var length := END_X - START_X
	var center_x := (START_X + END_X) * 0.5

	# 0. A save point before the corridor even starts - the first place in
	# the game spell learning/equipping becomes available at all (see
	# save_point.gd/SavePointMenu). Sits in the open dive site ahead of the
	# entrance blockade, not inside the walled corridor, so it reads as
	# "rest here before attempting the gate," not "partway through it."
	var save_point := SavePoint.new()
	save_point.position = Vector3(START_X - 5.0, 2.0, LANE_Z)
	add_child(save_point)
	_save_points.append(save_point)

	_build_wall(
		Vector3(center_x, WALL_HEIGHT * 0.5, LANE_Z - LANE_HALF_WIDTH),
		Vector3(length, WALL_HEIGHT, 0.6)
	)
	_build_wall(
		Vector3(center_x, WALL_HEIGHT * 0.5, LANE_Z + LANE_HALF_WIDTH),
		Vector3(length, WALL_HEIGHT, 0.6)
	)

	# 1. The entrance blockade - one solid rock formation spanning the full
	# lane width and wall height, no gaps to swim around or over. Only
	# Marine Man's shockwave clears it.
	var entrance_rocks := CrackedWall.new()
	entrance_rocks.span = Vector3(2.0, WALL_HEIGHT, LANE_HALF_WIDTH * 2.0)
	# Invisible collision extends far above the visible rocks - divers rise
	# freely in 3D, so a blockade that only matched its visible height
	# could just be swum over, the same gap the corridor's own walls have
	# (and accept, since going over a wall to cut a corner isn't the same
	# problem as skipping a gate entirely).
	entrance_rocks.collision_height = 40.0
	# Also wider than the visible rocks - the corridor's own side walls
	# don't cap their outer ends, so without this a diver could swim wide
	# around the whole corridor from the open dive site and cut back in
	# past the blockade entirely.
	entrance_rocks.collision_width = 60.0
	entrance_rocks.position = Vector3(START_X + 1.0, WALL_HEIGHT * 0.5, LANE_Z)
	add_child(entrance_rocks)
	entrance_rocks.broken.connect(_on_world_object_consumed.bind("entrance_blockade"))
	_cracked_walls["entrance_blockade"] = entrance_rocks

	# 2. The gap itself: a dark visual patch plus the whirlpool hazard.
	var gap_center_x := (GAP_START_X + GAP_END_X) * 0.5
	var gap_width := GAP_END_X - GAP_START_X

	# Sits just ABOVE the floor's own surface (y=0), not below it - a patch
	# placed under the floor is invisible, since the floor is one big
	# opaque plane covering the same footprint and renders right over it.
	# Unshaded so it reads as pure void regardless of the site's lighting,
	# not just "a dark rock."
	var void_mesh := MeshInstance3D.new()
	var void_plane := BoxMesh.new()
	void_plane.size = Vector3(gap_width, 0.06, LANE_HALF_WIDTH * 2.0)
	void_mesh.mesh = void_plane
	var void_mat := StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.015, 0.02, 0.03)
	void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	void_mesh.material_override = void_mat
	void_mesh.position = Vector3(gap_center_x, 0.03, LANE_Z)
	add_child(void_mesh)

	var whirlpool := Whirlpool.new()
	whirlpool.position = Vector3(gap_center_x, 2.0, LANE_Z)
	whirlpool.reset_to = Vector3(GAP_START_X - 4.0, 2.0, LANE_Z)
	whirlpool.warned.connect(_on_whirlpool_warned)
	whirlpool.diver_sucked_in.connect(_on_diver_sucked_in)
	add_child(whirlpool)

	# A second anchor right before the gap, in addition to the one on the
	# far side - a staging point for Diver Boy on the approach, not itself
	# a way across.
	var near_anchor := GrappleAnchor.new()
	near_anchor.position = Vector3(GAP_START_X - 1.0, 2.0, LANE_Z)
	add_child(near_anchor)

	# 3. The anchor that unlocks Mermaid's swap - reaching it is the
	# "you made it across" beat, but it doesn't disarm anything. The
	# whirlpool stays armed forever; grapple and swap are the permanent
	# way across, not a one-time gate.
	var anchor := GrappleAnchor.new()
	anchor.position = Vector3(GAP_END_X + 2.0, 2.0, LANE_Z)
	anchor.unlocks_diver_ability_for = "Staff_Diver"
	add_child(anchor)

	# 5. Three lit plates - the actual finale. All three occupied at once
	# (checked in _physics_process via _check_gap_puzzle) reveals the goal.
	var plate_x := lerpf(GAP_END_X, END_X, 0.6)
	for z_off in [-2.5, 0.0, 2.5]:
		var plate := LockPlate.new()
		plate.position = Vector3(plate_x, 2.0, LANE_Z + z_off)
		add_child(plate)
		_lock_plates.append(plate)

		# One door per plate, a little further down the lane than its own
		# plate - solid until _check_gap_puzzle opens all three together,
		# once every plate is occupied at once.
		var door := Door.new()
		door.position = Vector3(plate_x + 1.6, WALL_HEIGHT * 0.5, LANE_Z + z_off)
		add_child(door)
		_doors.append(door)

	_puzzle_goal = Waypoint.new()
	_puzzle_goal.is_goal = true
	_puzzle_goal.position = Vector3(END_X + 2.0, 2.0, LANE_Z)
	_puzzle_goal.visible = false
	add_child(_puzzle_goal)

func _on_whirlpool_warned() -> void:
	_announce("Danger - a whirlpool lies just ahead!")

func _on_diver_sucked_in(d: Diver, amount: int) -> void:
	_announce("You were sucked into the whirlpool! (-%d HP)" % amount)
	if d == divers[active]:
		_flash_hp_bar()

# Polled rather than signal-driven, since "solved" is a fact about all
# three plates at once, not something any single plate can know on its
# own - simplest to just check the three of them each frame.
func _check_gap_puzzle() -> void:
	if _puzzle_solved or _lock_plates.size() < 3 or _puzzle_goal == null:
		return
	for p in _lock_plates:
		if not (p as LockPlate).is_occupied():
			return
	_puzzle_solved = true
	for d in _doors:
		(d as Door).open()
	var cutscene := Cutscene.new()
	add_child(cutscene)
	cutscene.play_scroll_text("Welcome to the Deep Sea")
	_puzzle_goal.visible = true
	_announce("All three in place - the way ahead opens!")

# One plain wall segment: a StaticBody3D box, solid (divers collide with
# it via CharacterBody3D's own move_and_slide, same as the floor), centered
# on `center` with total dimensions `size`.
func _build_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.27, 0.3)
	mat.roughness = 1.0
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	add_child(body)

	# Minimap segment: along whichever horizontal axis is actually the
	# wall's length. Every wall built here is axis-aligned, so this is
	# just picking x vs z, not reading the body's real rotation.
	if size.x >= size.z:
		_wall_segments.append([center - Vector3(size.x * 0.5, 0.0, 0.0), center + Vector3(size.x * 0.5, 0.0, 0.0)])
	else:
		_wall_segments.append([center - Vector3(0.0, 0.0, size.z * 0.5), center + Vector3(0.0, 0.0, size.z * 0.5)])

func _unhandled_input(e: InputEvent) -> void:
	if battling:
		return

	# Aim mode intercepts clicks before the normal "first click captures
	# the mouse" handling below - a click here means fire/cancel, not
	# "start looking around" (mouse is already captured to get here in the
	# first place in any normal session).
	if aiming and e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_fire_aimed_ability()
			return
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_aim()
			return

	# TargetSelector intercepts Left/Right/Enter the same way aim mode
	# intercepts clicks - before they'd otherwise turn the camera or do
	# nothing at all (see _physics_process, which suppresses the normal
	# arrow-key camera turn outright while target_selector.selecting).
	if target_selector.selecting and e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var sk := (e as InputEventKey).keycode
		if sk == KEY_RIGHT:
			target_selector.select_next()
			_update_hud()
			return
		elif sk == KEY_LEFT:
			target_selector.select_previous()
			_update_hud()
			return
		elif sk == KEY_ENTER or sk == KEY_KP_ENTER:
			target_selector.confirm_selection()
			return

	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		# the web build starts with a free cursor; the first click takes it
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_look = true
	elif e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
		# elif, not a run of independent ifs like this used to be - opening
		# the inventory menu only makes sense when NONE of the others were
		# already true (otherwise a stray Escape while aiming would both
		# cancel the aim AND pop the pause menu open in the same press).
		# Closing it is the mirror of save_point_menu's own close branch
		# right above it.
		if aiming:
			_cancel_aim()
		elif target_selector.selecting:
			target_selector.cancel_selection()
		elif save_point_menu.visible:
			save_point_menu.close()
		elif inventory_menu.visible:
			inventory_menu.close()
		elif not battling:
			inventory_menu.open()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_look = false
	elif e is InputEventMouseMotion and mouse_look:
		var mm := e as InputEventMouseMotion
		yaw -= mm.relative.x * 0.004
		pitch = clampf(pitch - mm.relative.y * 0.003, -1.1, 0.7)
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var k := (e as InputEventKey).keycode
		if k == KEY_TAB:
			if not aiming and not target_selector.selecting:
				active = (active + 1) % divers.size()
				_update_hud()
		elif k == KEY_E:
			_start_ability()
		elif k == KEY_P:
			_toggle_save_menu()
		elif k == KEY_Q:
			_toggle_sonar()

# E's actual behavior depends on the active diver's ability: shockwave has
# nothing to aim, fires immediately. Grapple enters first-person aim mode.
# Swap goes through TargetSelector's cycle-through-candidates flow instead
# of either - see target_selector.gd.
func _start_ability() -> void:
	if aiming or target_selector.selecting:
		return
	var d: Diver = divers[active]
	if not d.can_use_ability():
		return
	if d.ability_id == "swap":
		target_selector.start_selection(d)
		_update_hud()
	elif d.ability_needs_aim():
		aiming = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_look = true
		_update_hud()
	else:
		d.use_ability(_aim_dir())

# Q, separate from E - sonar isn't the active diver's "ability" (that slot
# is swap, on this same diver), it's a passive being switched on and off,
# so it gets its own key rather than competing with _start_ability(). Only
# does anything for whichever diver actually has the sonar passive; a
# stray Q on anyone else is a silent no-op just like it would be on a
# diver with no ability at all.
func _toggle_sonar() -> void:
	var d: Diver = divers[active]
	if d.passive_id != "sonar":
		return
	var was_active := d.sonar_active
	var now_active := d.toggle_sonar()
	if now_active:
		_announce("Sonar on.")
	elif was_active:
		_announce("Sonar off.")
	else:
		_announce("Not enough oxygen for sonar.")
	_update_hud()   # refreshes the "Q: Sonar (On/Off)" hint immediately

# Only opens if the active diver is actually standing on a save point -
# see save_point.gd.has_diver(). Closes on a second press; won't open
# while aiming or mid-swap-selection, same guard _start_ability() already
# applies for the same reason (those modes already own the mouse/camera).
func _toggle_save_menu() -> void:
	if save_point_menu.visible:
		save_point_menu.close()
		return
	if aiming or target_selector.selecting:
		return
	# Pressing P off a save point used to just silently do nothing - which
	# reads identically to "the menu is broken" from the player's side.
	# Bannering it means a stray P press is never mistaken for a bug.
	if not _diver_on_save_point(divers[active]):
		_announce("No save point nearby.")
		return
	save_point_menu.open_for(divers[active], _display_name(divers[active].model_name))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_look = false

func _diver_on_save_point(d: Diver) -> bool:
	for sp in _save_points:
		if (sp as SavePoint).has_diver(d):
			return true
	return false

# world.gd owns showing the confirmation and closing the menu - the menu
# itself only ever emits the request, it doesn't know whether saving
# "worked" since there's nothing real to fail yet (see save_point_menu.gd).
#
# Also the only way oxygen ever comes back now that there's no passive
# regen - a save point is a real destination to swim for once you've spent
# it down on abilities/sonar/spells, not just a spell-loadout menu. And now
# a real save-file write (_write_save()) to whichever slot this run is
# playing into - a game over's "Restart from Save Point" (see
# _show_game_over()/_on_game_over_restart()) reads back exactly this.
#
# HP/barrier/oxygen restore for the WHOLE party, not just whoever's
# physically standing on the point - battle damage (and oxygen spend) is
# shared across all three divers, so a rest stop patching up only the one
# you happened to be steering would leave the other two stuck damaged/
# drained with no other way to recover.
func _on_save_requested(_d: Diver) -> void:
	for other in divers:
		var s: CombatantStats = (other as Diver).stats
		s.hp = s.hp_max
		s.barrier = s.barrier_max
		s.oxygen = s.oxygen_max
	_update_hp_bar()
	_update_oxygen_bar()
	_write_save()
	_announce("Progress saved.")
	save_point_menu.close()

# Shows "Save/Update Spells" while standing on a save point with the menu
# closed, clears it the moment either stops being true. Tracked separately
# from _announce()'s normal fade (_banner_timer stays 0 here) so the
# prompt persists exactly as long as you're standing there, not for a
# fixed few seconds - but that also means it only ever clears its own
# text, never a real announcement's, via _showing_save_prompt.
func _update_save_point_prompt() -> void:
	if save_point_menu.visible:
		if _showing_save_prompt:
			banner.text = ""
			_showing_save_prompt = false
		return
	var on_point := _diver_on_save_point(divers[active])
	if on_point and not _showing_save_prompt:
		banner.text = "Save/Update Spells - Press P"
		_banner_timer = 0.0
		_showing_save_prompt = true
	elif not on_point and _showing_save_prompt:
		banner.text = ""
		_showing_save_prompt = false

func _fire_aimed_ability() -> void:
	aiming = false
	divers[active].use_ability(_aim_dir())
	_update_hud()

func _cancel_aim() -> void:
	aiming = false
	_update_hud()

# TargetSelector confirmed a target (Enter, with a valid candidate
# currently selected) - fire the active diver's ability at them.
func _on_swap_target_confirmed(target: Node3D) -> void:
	divers[active].use_ability(Vector3.ZERO, target)
	_update_hud()

# TargetSelector cancelled (Escape, or Left/Right cancel handling) - just
# needs the HUD put back, TargetSelector already returned the camera.
func _on_swap_target_cancelled() -> void:
	_update_hud()

func _physics_process(dt: float) -> void:
	_t += dt
	if battling or inventory_menu.visible:
		return
	# keyboard turning too: mouse capture is the first thing to go wrong in a
	# browser, and a build nobody can steer is a build nobody plays.
	# Suppressed while target_selector.selecting - Left/Right are
	# repurposed there for cycling (see _unhandled_input), so they'd
	# otherwise both spin the camera AND change the selection on one press.
	if not target_selector.selecting and Input.is_key_pressed(KEY_LEFT):
		yaw += dt * 2.0
	if not target_selector.selecting and Input.is_key_pressed(KEY_RIGHT):
		yaw -= dt * 2.0
	if Input.is_key_pressed(KEY_UP):
		pitch = clampf(pitch + dt * 1.2, -1.1, 0.7)
	if Input.is_key_pressed(KEY_DOWN):
		pitch = clampf(pitch - dt * 1.2, -1.1, 0.7)

	for i in range(divers.size()):
		var d: Diver = divers[i]
		# Movement pauses for the active diver while picking a swap target
		# too - the camera's busy showing an ally, swimming around blind
		# to where your own diver actually is would be confusing controls.
		if i == active and not target_selector.selecting:
			d.swim(_player_dir(), _player_rise(), dt)
		else:
			# Zero input, not skipped entirely - swim() still drains
			# velocity to a stop and keeps bob/bubble animation ticking,
			# it just never gives them anywhere new to go. A diver you
			# TAB away from (mid-gap-crossing, standing on a lock plate)
			# now stays exactly where you left it instead of drifting off.
			d.swim(Vector3.ZERO, 0.0, dt)
	_move_camera(dt)
	_update_aim_marker()
	_update_hp_bar()
	_update_oxygen_bar()
	_update_active_cursor()
	_update_banner(dt)
	_update_save_point_prompt()
	_check_gap_puzzle()

func _player_dir() -> Vector3:
	if scripted:
		return scripted_dir
	var f := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		f.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		f.y += 1.0
	if Input.is_key_pressed(KEY_A):
		f.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		f.x += 1.0
	if f == Vector2.ZERO:
		return Vector3.ZERO
	f = f.normalized()
	# swim where the camera is looking, not where the world's axes point.
	# fwd matches the camera's actual look direction (see _move_camera's
	# `dir`); right is fwd rotated -90 around Y so it points to screen-right
	# regardless of which way the diver model currently happens to be
	# facing. W/A/S/D always map to camera-forward/left/back/right.
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(-cos(yaw), 0, sin(yaw))
	return (right * f.x - fwd * f.y).normalized()

func _player_rise() -> float:
	if scripted:
		return scripted_rise
	var r := 0.0
	if Input.is_key_pressed(KEY_SPACE):
		r += 1.0
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		r -= 1.0
	return r

func _move_camera(dt: float) -> void:
	var d: Diver = divers[active]
	var dir := _aim_dir()

	if camera_mode == CameraMode.FOCUS and is_instance_valid(_camera_focus_target):
		_camera_pan_toward(_camera_focus_target, dir, dt)
		if _camera_focus_timer > 0.0:
			_camera_focus_timer -= dt
			if _camera_focus_timer <= 0.0:
				return_camera_to_player()
		return

	if aiming:
		# Cut to the diver's own eye line instead of the chase framing -
		# same eye height _grapple() itself fires from (diver.gd's
		# height * 0.4), so what you see lines up with what the raycast
		# actually checks.
		var eye: Vector3 = d.global_position + Vector3(0, d.height * 0.4, 0)
		cam.global_position = cam.global_position.lerp(eye, clampf(dt * 14.0, 0.0, 1.0))
		cam.look_at(eye + dir * 10.0, Vector3.UP)
		return

	var focus: Vector3 = d.global_position + Vector3(0, d.height * 0.35, 0)
	var want: Vector3 = focus - dir * cam_dist
	want.y = maxf(want.y, 0.6)      # never bury the camera in the seabed
	cam.global_position = cam.global_position.lerp(want, clampf(dt * 8.0, 0.0, 1.0))
	cam.look_at(focus, Vector3.UP)

# Shared chase-style framing centered on `target` instead of the active
# diver - the one camera behavior behind both CameraMode.FOCUS uses
# (TargetSelector picking a swap candidate, and the post-swap confirmation
# hold in _on_diver_swapped), so both look and feel identical rather than
# being two independent implementations of "look at someone else."
func _camera_pan_toward(target: Node3D, dir: Vector3, dt: float) -> void:
	var lift := 0.35
	if target is Diver:
		lift = (target as Diver).height * 0.35
	var focus: Vector3 = target.global_position + Vector3(0, lift, 0)
	var want: Vector3 = focus - dir * (cam_dist * 0.85)
	want.y = maxf(want.y, 0.6)
	cam.global_position = cam.global_position.lerp(want, clampf(dt * 6.0, 0.0, 1.0))
	cam.look_at(focus, Vector3.UP)

# Called by TargetSelector while cycling (no auto-return - TargetSelector
# explicitly calls return_camera_to_player() on confirm/cancel) and by
# _on_diver_swapped for the brief post-swap confirmation hold (auto-return
# after 1.1s, since nothing else ends that one on its own).
func focus_camera_on(target: Node3D, auto_return_after: float = 0.0) -> void:
	camera_mode = CameraMode.FOCUS
	_camera_focus_target = target
	_camera_focus_timer = auto_return_after

func return_camera_to_player() -> void:
	camera_mode = CameraMode.PLAYER
	_camera_focus_target = null
	_camera_focus_timer = 0.0

# Where the camera is actually looking, from yaw/pitch (mouse-look or
# arrow keys) - matches _player_dir()'s horizontal forward when pitch is 0.
# Shared by the camera itself and by aimed abilities (grapple), so "what
# you're looking at" and "what you're aiming at" are always the same thing.
func _aim_dir() -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))

var _aim_marker: MeshInstance3D
var _aim_marker_mat: StandardMaterial3D

func _ensure_aim_marker() -> void:
	if _aim_marker != null:
		return
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.32
	_aim_marker = MeshInstance3D.new()
	_aim_marker.mesh = ring
	_aim_marker_mat = StandardMaterial3D.new()
	_aim_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_marker_mat.emission_enabled = true
	_aim_marker.material_override = _aim_marker_mat
	_aim_marker.visible = false
	add_child(_aim_marker)

# Runs the same raycast grapple will fire, every frame while aiming,
# purely so the player can see where a shot would land before committing
# to it - a preview, not a hitbox. Turns green on a valid grapple_anchor,
# gray otherwise. Grapple-only now - swap goes through TargetSelector's
# cycle-through-candidates flow instead, with its own cursor (see
# target_selector.gd), not this raycast-based ring reticle.
func _update_aim_marker() -> void:
	if not aiming:
		if _aim_marker != null:
			_aim_marker.visible = false
		return
	_ensure_aim_marker()

	var d: Diver = divers[active]
	var dir := _aim_dir()
	var from: Vector3 = d.global_position + Vector3(0, d.height * 0.4, 0)
	var to: Vector3 = from + dir * Diver.GRAPPLE_RANGE
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [d.get_rid()]
	var result := space.intersect_ray(query)

	var point: Vector3 = to if result.is_empty() else (result.position as Vector3)
	var on_target: bool = not result.is_empty() and (result.collider as Node).is_in_group("grapple_anchor")

	_aim_marker.visible = true
	_aim_marker.global_position = point
	_aim_marker.look_at(from, Vector3.UP)
	var c: Color = Color(0.35, 0.95, 0.4) if on_target else Color(0.75, 0.78, 0.8)
	_aim_marker_mat.albedo_color = c
	_aim_marker_mat.emission = c
	_aim_marker_mat.emission_energy_multiplier = 1.6 if on_target else 0.7

# fade the banner. Only called while not battling: _physics_process skips
# this whole side of the world once a fight is up.
func _update_banner(dt: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= dt
		if _banner_timer <= 0.0:
			banner.text = ""

# a Diver rolled an encounter (see diver.gd's distance-based check). Only the
# diver you're actually steering gets to start one - the two drifting NPCs
# roll independently but their triggers are ignored here.
func _on_encounter_triggered(d: Diver) -> void:
	if battling or d != divers[active]:
		return
	# Standing on a key item's spot turns the next random encounter into
	# that item's guardian fight. Everywhere else it is an ordinary one.
	#
	# Two bugs lived in these five lines. The spot dictionaries are keyed
	# "item", not "item_id", so this threw, and a throw inside a signal
	# handler takes the rest of the handler with it: an encounter rolled
	# anywhere within 10 m of either spot started nothing at all. No fight,
	# no message, and check_for_encounter() had already reset the counter,
	# so the only symptom was a stretch of map that never attacked you. And
	# had it not thrown, the unconditional _start_battle() underneath would
	# have stacked a second battle screen on the same encounter.
	#
	# ItemGuardian.new() went with them. SPOTS is a const on the class, so
	# reading it never needed an instance, and that instance was an Area3D
	# that was never added to the tree and never freed. One leak per
	# encounter for the whole session.
	var reward := ""
	for spot in ItemGuardian.SPOTS:
		if d.position.distance_to(spot.at as Vector3) <= float(spot.radius):
			reward = String(spot.item)
			break
	_start_battle(reward)

# guardian/decoy are bound at connect time (see _build_item_guardians()).
# Both get freed the instant this fires, win or lose the fight that
# follows - a guardian is a one-time gate on its item, not a repeatable
# encounter spot, so there's nothing left here to trigger again either way.
func _on_item_guardian_triggered(item_id: String, guardian: ItemGuardian, decoy: Goblin) -> void:
	if battling:
		return
	guardian.call_deferred("queue_free")
	decoy.call_deferred("queue_free")
	_start_battle(item_id)

# `d` (bound at connect time) is whoever's swapped_with just fired - only
# react if it's the diver currently being steered, same guard shape as
# _on_encounter_triggered, so a background diver's stray signal (there
# shouldn't be one, but nothing enforces that) can't hijack the camera.
func _on_diver_swapped(target: Diver, d: Diver) -> void:
	if d != divers[active]:
		return
	focus_camera_on(target, 1.1)

# reward_item carries straight into _pending_reward_item - "" (the
# default, what every ordinary random encounter passes) means an
# unmodified fight with nothing riding on it, same as before this existed.
func _start_battle(reward_item: String = "") -> void:
	battling = true
	inventory_menu.close()   # shouldn't normally be open when an encounter rolls, but not a state battle.gd should ever have to share the screen with
	_pending_reward_item = reward_item
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE      # buttons need the cursor back
	mouse_look = false
	_announce("Something grunts out of the murk!")
	battle = Battle.new()
	battle.party_source = divers
	battle.world = self
	battle.finished.connect(_on_battle_finished)
	add_child(battle)

func _on_battle_finished(result: String) -> void:
	battle.queue_free()
	battle = null
	battling = false
	match result:
		"won":
			if _pending_reward_item != "":
				_grant_reward_item(_pending_reward_item)
			else:
				_announce("The grunt backs off into the dark.")
		"fled":
			_announce("You put some distance between you.")
		"lost":
			# All three divers down - Battle._lose() fires this the instant
			# _living(party) is empty. Used to auto-restore the checkpoint
			# instantly and silently; now hands the player an actual choice
			# instead (see _show_game_over()) - restart from the current
			# slot's last save, or bail out to the title screen entirely.
			_show_game_over()
		_:
			_announce("You regroup and catch your breath.")
	_pending_reward_item = ""

# Key items (current_pearl/reef_plate) go straight into the party-wide
# key_items array - Items.grant() refuses those on purpose (see its own
# header comment), a guardian's reward isn't "held" by whichever diver's
# turn it was when the fight ended. Everything else Items.ITEMS could
# theoretically hold goes into the shared inventory same as an orb pickup
# would (see _add_to_inventory()), in case a future guardian ever guards a
# consumable instead of a key item.
func _grant_reward_item(item_id: String) -> void:
	if Items.is_key_item(item_id):
		if not key_items.has(item_id):
			key_items.append(item_id)
		var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
		_announce("Victory - you claim the key item %s!" % display)
	else:
		_add_to_inventory(item_id)

func _announce(text: String) -> void:
	banner.text = text
	_banner_timer = 4.0

# Display-only nicknames, not used anywhere gameplay reads model_name -
# purely so the HUD reads "Marine Man" instead of "Prototype_V(1922)".
const DISPLAY_NAMES := {
	"Staff_Diver": "Mermaid",
	"Prototype_1(1910)": "Diver Boy",
	"Prototype_V(1922)": "Marine Man",
}

func _display_name(model_name: String) -> String:
	return String(DISPLAY_NAMES.get(model_name, model_name))

func _update_hud() -> void:
	if target_selector.selecting:
		var t := target_selector.current_target()
		if t != null and t is Diver:
			hud.text = "Swap with %s?\nLeft/Right: cycle   ·   Enter: confirm   ·   Esc: cancel" % _display_name((t as Diver).model_name)
		else:
			hud.text = "Left/Right: cycle   ·   Enter: confirm   ·   Esc: cancel"
		return
	if aiming:
		hud.text = "Aiming %s\nLeft click: fire   ·   Right click: cancel" % String(divers[active].ability_id).capitalize()
		return
	var d: Diver = divers[active]
	var line := "%s  (%.2f m)\nWASD swim · SPACE up · SHIFT down · mouse or arrows look · TAB switch diver" % [
		_display_name(d.model_name), d.height]
	if d.ability_id != "":
		line += "  ·  E: %s" % String(d.ability_id).capitalize()
	# Only shows for whichever diver actually has the passive (see
	# _toggle_sonar()'s own passive_id check) - same "only mention it if
	# it'd do something" rule the E: hint above already follows for
	# ability_id.
	if d.passive_id == "sonar":
		line += "  ·  Q: Sonar (%s)" % ("On" if d.sonar_active else "Off")
	hud.text = line

# A persistent readout of the active diver's HP, always visible during
# free swimming (not just during Battle, which has its own separate HP
# bars on its own screen) - bottom-center, red fill matching Battle's own
# bar styling (see battle.gd's _add_bar) so the same number reads the
# same way in both places.
var hp_bar: ProgressBar
var hp_bar_label: Label
var _hp_bar_mat: StyleBoxFlat

func _build_hp_bar() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wrap.offset_top = -56.0
	wrap.offset_bottom = -10.0
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	$HUD.add_child(wrap)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(220, 20)
	hp_bar.show_percentage = false
	hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hp_bar_mat = StyleBoxFlat.new()
	_hp_bar_mat.bg_color = Color(0.78, 0.15, 0.15)
	hp_bar.add_theme_stylebox_override("fill", _hp_bar_mat)
	wrap.add_child(hp_bar)

	hp_bar_label = Label.new()
	hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(hp_bar_label)

func _update_hp_bar() -> void:
	var d: Diver = divers[active]
	hp_bar.max_value = d.stats.hp_max
	hp_bar.value = d.stats.hp
	hp_bar_label.text = "%s   %d / %d" % [_display_name(d.model_name), d.stats.hp, d.stats.hp_max]

# Same wrap/bar/label shape as the HP bar, stacked just above it - O2 is
# read continuously (sonar drains it every frame while active - see
# Diver._physics_process()) so it's updated every physics frame right
# alongside HP rather than only on discrete events like the HP bar's other
# callers do. No regen to show ticking here - the only thing that ever
# moves this bar back up is a save point (_on_save_requested()).
var oxygen_bar: ProgressBar
var oxygen_bar_label: Label

func _build_oxygen_bar() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wrap.offset_top = -82.0
	wrap.offset_bottom = -58.0
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	$HUD.add_child(wrap)

	oxygen_bar = ProgressBar.new()
	oxygen_bar.custom_minimum_size = Vector2(220, 14)
	oxygen_bar.show_percentage = false
	oxygen_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var mat := StyleBoxFlat.new()
	mat.bg_color = Color(0.25, 0.65, 0.85)
	oxygen_bar.add_theme_stylebox_override("fill", mat)
	wrap.add_child(oxygen_bar)

	oxygen_bar_label = Label.new()
	oxygen_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oxygen_bar_label.add_theme_font_size_override("font_size", 13)
	wrap.add_child(oxygen_bar_label)

func _update_oxygen_bar() -> void:
	var d: Diver = divers[active]
	oxygen_bar.max_value = d.stats.oxygen_max
	oxygen_bar.value = d.stats.oxygen
	oxygen_bar_label.text = "O2   %d / %d" % [int(d.stats.oxygen), int(d.stats.oxygen_max)]

# Same downward-pointing cone TargetSelector's own cursor uses, same green,
# built once here rather than in TargetSelector since this one's purpose is
# different (mark who you're steering, not who you're about to swap into)
# even though the shape is deliberately identical.
func _build_active_cursor() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.4
	_active_cursor = MeshInstance3D.new()
	_active_cursor.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.albedo_color = Color(0.35, 0.95, 0.4)
	mat.emission = Color(0.35, 0.95, 0.4)
	_active_cursor.material_override = mat
	_active_cursor.rotation_degrees.x = 180.0   # cone points down at the diver's head
	add_child(_active_cursor)

# Refreshed every physics frame (same cadence as _update_hp_bar()/
# _update_oxygen_bar()) so it keeps following the active diver as they
# swim, not just snapping into place on a TAB press. Hidden during
# target_selector.selecting/aiming/battling - see _active_cursor's own
# header comment for why each of those isn't a "hover over your own head"
# moment.
func _update_active_cursor() -> void:
	if battling or aiming or target_selector.selecting or divers.is_empty():
		_active_cursor.visible = false
		return
	var d: Diver = divers[active]
	_active_cursor.visible = true
	_active_cursor.global_position = d.global_position + Vector3.UP * (d.height + 0.5)

# Called on top of the normal value drop (which already reads as "the bar
# is noticeably lower now") for a brief extra flash, so a hit lands even
# if you're not staring at the bar the instant it happens.
func _flash_hp_bar() -> void:
	var tw := create_tween()
	tw.tween_property(_hp_bar_mat, "bg_color", Color(1.0, 0.9, 0.85), 0.1)
	tw.tween_property(_hp_bar_mat, "bg_color", Color(0.78, 0.15, 0.15), 0.3)

func _find(n: Node, nm: String) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name) == nm:
		return n
	for c in n.get_children():
		var r := _find(c, nm)
		if r != null:
			return r
	return null
