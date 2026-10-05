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
var _intro_arrow: MeshInstance3D
var _blockade_arrow: MeshInstance3D
const BLOCKADE_ARROW_HIDE_DIST := 6.0

# Gates TAB/random-encounters and holds the camera on the light beam from
# the moment the world loads until the active diver actually reaches it -
# see intro_arrow(), _show_intro_text(), render_light_beam(), and
# _update_intro_sequence() below.
var _intro_active := false
# Horizontal radius of the rendered light column that counts as arrival.
# The beam is 12 m tall and its node is centered at y=6, whereas divers
# swim near y=2; arrival must be measured across the seafloor plane, not to
# the mesh origin in 3D (see _update_intro_sequence()).
const INTRO_ARRIVAL_DIST := 2.5
var _first_encounter_started := false
var _transitioning_to_encounter := false
var random_encounter_reveal: RandomEncounterReveal
# Set once the choreographed tutorial fight (see battle.gd's
# tutorial_encounter) actually finishes - _on_battle_finished() flips this.
# Gates the save point (_toggle_save_menu()/_update_save_point_prompt())
# until then, same reasoning as gating TAB/random encounters: nothing about
# the tutorial should be skippable by ducking into a menu mid-walk-over.
var _first_encounter_done := false
# Set right before tutorial_result_popup.open() in _on_battle_finished()'s
# "lost" branch, read by _on_tutorial_loss_exit() - the popup itself carries
# no memory of which tutorial fight opened it (special encounter vs. the
# plain first combat fight), and _show_ability_popups() (World Map, Maxilani
# Swap/Sonar, Musashi/Bucky's own pages) is onboarding for the latter only.
var _tutorial_loss_was_special := false
# Test seam only. Automated subsystem checks need to enter their focused
# scenario immediately; an actual player always sees the opening crawl.
var skip_intro_for_test := false
# Developer convenience, same shape as skip_intro_for_test above but for the
# scripted first fight itself, not just the narration crawl before it -
# playtesting exploration, other encounters, or saves shouldn't require
# walking to the light beam and fighting through the tutorial every single
# session. Set from code (skip_intro_for_test's own use case) or by
# launching with the --skip-tutorial arg / (on a web build) a ?skip_
# tutorial=1 URL, same convention as _boss_playtest_requested() and its
# siblings above - never a persisted save value, so there is no way for a
# real player to end up with it on by accident.
var skip_tutorial_for_test := false
# Focused route gates do not need to wait through Tethys's full authored swim
# entrance before asserting World's handoff/result ownership. Production and
# browser play keep the entrance enabled.
var skip_boss_intro_for_test := false

func _tutorial_skip_requested() -> bool:
	if OS.get_cmdline_user_args().has("--skip-tutorial"):
		return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return String(search).contains("skip_tutorial=1")
	return false

# random encounters: each Diver tracks its own distance swum and fires
# encounter_triggered when it rolls one (see diver.gd). This just reacts -
# drops into a turn-based fight against an ordinary enemy pack, Pokemon-style, and
# freezes the dive while game/battle.gd runs it.
var banner: Label
var _banner_timer := 0.0
var _announcements := preload("res://game/orange_message_queue.gd").new()
var route_objective_panel: PanelContainer
var route_objective_label: Label
var battling := false
var battle: Battle
var yaw := 0.0
var pitch := -0.16
var cam_dist := 6.5
var cam: Camera3D
var hud: Label
var mouse_look := false
# R toggles this - see _on_encounter_triggered()'s own early-out and the
# "R: Encounters" hint _update_hud() adds next to it. Player-facing (not a
# dev/test-only flag): on by default, so ordinary play is unaffected unless
# someone actually presses R.
var random_encounters_enabled := true
var escape_encounter_hint: PanelContainer
var _t := 0.0

# First-person aim mode for aimed abilities (grapple): E enters it instead
# of firing right away, camera cuts to the diver's own eye line, left click
# fires, right click backs out. Nothing about the ability itself changes -
# use_ability() still does the actual raycast/pull, this only decides when
# it gets called.
var aiming := false

# Swap goes through TargetSelector instead of first-person aim: cycle
# between allies with A/D or Left/Right, Space/Enter confirms, Escape cancels. See
# target_selector.gd for the selection logic and _start_ability()/
# _unhandled_input() below for how E and the arrow keys route into it.
var target_selector: TargetSelector

# P opens save_point_menu, but only while standing on a SavePoint (see
# _save_points/_toggle_save_menu/_update_save_point_prompt). Spell learning
# and equipping happen automatically after battles.
var save_point_menu: SavePointMenu
var _save_points: Array = []
var _showing_save_prompt := false
var _save_point_contact_active := false
var _save_point_tutorial_seen := false

# Party-wide, not per-diver - key items unlock spells in whichever diver's
# tree requires them, they aren't "held" by whoever found one or won the
# guardian fight.
# The dive site as physical places from content/sites.gd. Built by
# _build_dive_sites(); site_nodes is keyed by site id.
var site_nodes: Dictionary = {}

const SiteScript := preload("res://game/site.gd")
const DeepZoneLayoutScript := preload("res://content/deep_zone_layout.gd")
const DeepZoneEnvironmentScript := preload("res://game/deep_zone_environment.gd")
const LabVideoCutsceneScript := preload("res://game/lab_video_cutscene.gd")
const OpeningVideoScript := preload("res://game/opening_video.gd")
const OpeningTriggerScript := preload("res://game/opening_prologue_trigger.gd")
const PrologueRecoveryScript := preload("res://game/prologue_recovery.gd")
const CampaignCompletionScript := preload("res://game/campaign_completion.gd")
const PrologueCinematicScript := preload("res://game/prologue_cinematic.gd")

var key_items: Array[String] = []
const BLOCKADE_HEIGHT := 6.0
const AIRBORNE_ROCK_HEIGHT := BLOCKADE_HEIGHT * 3.0
const ROCK_KEY_ITEM_REWARDS := {
	"rock_7": "abyssal_lens",
	"rock_8": "sunken_core",
}
const ROCK_AMBUSH_IDS := ["rock_9", "rock_10"]

# Which ItemGuardian.spots() item ids sonar has ever pinged (see
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
var title_layer: CanvasLayer

# Special encounters (the solo-diver ability minigame) are opt-in - the
# player chooses which diver's ability to face it with. Entering an
# unclaimed special item's site radius opens the encounter directly; it does
# not require Sonar or a random encounter roll.
var special_encounter_prompt: SpecialEncounterPrompt
var tutorial_book: TutorialBook
# Shown in place of the old immediate heal-and-return on a tutorial loss -
# see _on_battle_finished()'s "lost" branch and _on_tutorial_loss_retry()/
# _on_tutorial_loss_exit() below.
var tutorial_result_popup: TutorialResultPopup

const SLOT_SCENE := preload("res://slot.tscn")
# One Slot (see slot.gd) per diver, built once in _ready() by
# _build_diver_slots() - purely a HUD anchor CharacterAbilityPopup
# highlights while explaining that diver's world ability, same index order
# as `divers`. CharacterAbilityPopup itself needs no instancing here - it's
# an autoload singleton (project.godot's [autoload] section), reached
# directly by its global name in _show_ability_popups() below.
var _diver_slots: Array = []
# The first-run opening and the later lab cutscene deliberately have separate
# owners and policies even while both temporarily point to the same Mermaid
# media bytes. This reference exists so the normal title path and verification
# can observe one active owner without searching the scene tree.
var opening_video: CanvasLayer
var _special_encounter_item := ""
var _special_encounter_diver: Diver
var _special_encounter_pre_hp := 0
var _special_encounter_pre_oxygen := 0.0
var _inside_item_site_id := ""
# Which enemy species the special encounter's closing swing (and the real
# battle if the diver picks to fight it out) should use - set right before
# _offer_special_encounter() from whichever guarded site's radius the diver
# entered (see _try_trigger_item_site()), same
# per-site mapping (Angler at shallows, Swordfish Duelist at trench)
# Sites.guarded() has always carried.
var _pending_guardian_enemy_id := "angler"

# Set right before a special encounter opens for a guarded item (see
# _on_encounter_triggered()), read once in _on_battle_finished() and cleared
# immediately after - "" means an ordinary random encounter, nothing to hand
# out on a win.
var _pending_reward_item := ""

# True only during the isolated ?boss=1 review route. It never writes a
# save and returns to the title after the result, so repeatedly testing
# Tethys cannot damage a real playthrough.
var _boss_playtest_active := false

# Isolated ?special=1 review route. It opens the real guardian chooser and
# battle/minigame dispatcher but never grants an item or alters a save.
var _special_playtest_active := false

# Which save slot this run is playing into - set the instant the title
# screen resolves (New Game picks one and writes an initial save into it;
# Load Game picks one and reads from it), -1 only while the title screen
# itself is still up and nothing's been chosen yet. Everything that used
# to be an in-memory-only checkpoint (see _write_save()/_load_save() below)
# now reads/writes SaveManager.slot_path(_current_slot) instead, so a game
# over's "restart from save point" and an actual save-point visit are the
# same real file, and it all survives closing the game entirely.
var _current_slot := -1
const AUTOSAVE_INTERVAL := 180.0
var _autosave_timer := 0.0
var _autosave_writing := false
var _checkpoint_saving := false
var _completion_screen: CanvasLayer
var _completion_checkpoint: Dictionary = {}
var _completion_saving := false

func _show_campaign_completion(already_saved := false) -> void:
	if is_instance_valid(_completion_screen) or route_state.octopus_state != "defeated":
		return
	# The actual battle result has already paid XP and removed the station.
	# Freeze this boundary before yielding; retries must not replay rewards or
	# silently restore/heal the party. This does not relax ordinary save guards.
	_checkpoint_saving = true
	$HUD.visible = false
	if embedded_maze != null:
		embedded_maze.get_node("HUD").visible = false
	for diver in divers:
		diver.velocity = Vector3.ZERO
		diver.exploration_paused = true
	_completion_checkpoint = _serialize_state()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_completion_screen = CampaignCompletionScript.new()
	_completion_screen.retry_chosen.connect(_save_campaign_completion)
	_completion_screen.title_chosen.connect(_on_game_over_title)
	add_child(_completion_screen)
	if already_saved:
		_completion_screen.show_saved(_current_slot)
	else:
		_save_campaign_completion()

func _save_campaign_completion() -> void:
	if _completion_saving or not is_instance_valid(_completion_screen):
		return
	if _current_slot < 0:
		_completion_screen.show_failure("No save slot is selected. Keep this game open; completion has not been saved.")
		return
	_completion_saving = true
	_completion_screen.show_saving()
	var slot := _current_slot
	var existed := SaveManager.slot_exists(slot)
	var previous := FileAccess.get_file_as_bytes(SaveManager.slot_path(slot)) if existed else PackedByteArray()
	var error := SaveManager.write_slot(slot, _completion_checkpoint)
	var written := error == OK
	if written:
		error = await BrowserCheckpoint.confirm_slot(slot)
	var rollback_error := OK
	if error != OK and written:
		rollback_error = SaveManager.rollback_slot(slot, existed, previous)
	_completion_saving = false
	if error == OK:
		_completion_screen.show_saved(slot)
	elif rollback_error == OK:
		_completion_screen.show_failure("Completion could not be saved. Your previous checkpoint is unchanged. Enable saving or free storage, then retry before leaving.")
	else:
		_completion_screen.show_failure("Saving failed and the previous checkpoint could not be restored. Keep this game open and retry before leaving.")

func _autosave_safe() -> bool:
	if _checkpoint_saving:
		return false
	if _current_slot < 0 or title_screen.visible or get_tree().paused or not route_state.prologue_complete:
		return false
	if battling or _intro_active or _transitioning_to_encounter or aiming or target_selector.selecting:
		return false
	if is_instance_valid(random_encounter_reveal) or is_instance_valid(_lab_video_cutscene):
		return false
	if special_encounter_prompt.visible or _special_encounter_item != "" or _special_encounter_diver != null:
		return false
	if save_point_menu.visible or inventory_menu.visible or tutorial_result_popup.visible:
		return false
	if embedded_maze != null and embedded_maze.maze_active and not embedded_maze.can_capture_campaign_snapshot():
		return false
	return not Whirlpool.busy_in(self)

func _tick_autosave(dt: float) -> void:
	if _current_slot < 0 or title_screen.visible or get_tree().paused or not route_state.prologue_complete:
		return
	_autosave_timer += dt
	if _autosave_timer < AUTOSAVE_INTERVAL or _autosave_writing or not _autosave_safe():
		return
	_autosave_writing = true
	var slot := _current_slot
	var path := SaveManager.autosave_path(slot)
	var existed := FileAccess.file_exists(path)
	var previous := FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
	var error := SaveManager.write_autosave(slot, _serialize_state())
	var written := error == OK
	if written:
		error = await BrowserCheckpoint.confirm_slot(slot, true)
	if error != OK and written:
		SaveManager.rollback_autosave(slot, existed, previous)
	_autosave_writing = false
	_autosave_timer = 0.0
	_announce("Game autosaved." if error == OK else "Autosave failed. Your last checkpoint is unchanged.")

# One public source of truth for authored progression beyond the existing
# free-roam/tutorial state. RouteState owns JSON-safe data and its objective
# signal; World only includes it in the same atomic checkpoint dictionary as
# party, inventory, and mutable geometry.
var route_state := RouteState.new()
var _prologue_trigger := OpeningTriggerScript.new()
var _prologue_spawn_delay := 0.0
var _prologue_cinematic: CanvasLayer
var deep_zone_layout := DeepZoneLayoutScript.new()
var deep_zone_environment: DeepZoneEnvironment
var _lab_video_cutscene: LabVideoCutscene
const LAB_TRIGGER_RADIUS := 4.0
const MAZE_TRANSITION_RADIUS := 5.0
const PUZZLE_MAZE_EXIT := Vector3(47.0, 2.0, 10.0)
const PUZZLE_MAZE_EXIT_RADIUS := 2.5
var _maze_entry_source := "deep_landmark"

# One-time authored blocker trigger ownership. `_inside_route_blocker_id` is a
# re-entry latch: fleeing or losing while still inside the volume must not drop
# the player straight back into the same battle on the next physics frame.
const ROUTE_BLOCKER_TRIGGER_RADIUS := 4.0
const ROUTE_BLOCKER_EXIT_RADIUS := 6.0
const ROUTE_BLOCKER_TRIGGER_HALF_WIDTH := 10.0
const ROUTE_BLOCKER_EXIT_HALF_WIDTH := 11.5
var _active_route_blocker_id := ""
var _inside_route_blocker_id := ""
var _route_blocker_world_actors: Dictionary = {}
var _route_blocker_gates: Dictionary = {}

# Scene reload is the only honest way to roll mutable geometry back to a
# checkpoint: _load_save() can remove objects a save says are consumed, but
# it cannot recreate a CrackedWall already queue_free()'d after that save.
# This one-shot handoff survives reload_current_scene(), then the fresh World
# consumes and clears it at the end of _ready().
static var _restart_slot := -1
var _loaded_maze_session: CampaignSession
var _campaign_session: CampaignSession
var embedded_maze: MazeLevel

# Full state: per-diver position/stats/spells plus the world-level
# inventory/key_items/active - everything _write_save()'s caller (a save
# point) or the initial New Game write needs to reproduce the run exactly.
# Vector3 isn't JSON-serializable, so position goes in as a plain [x,y,z]
# array (see _load_save()'s reverse conversion).
func _serialize_world_state() -> Dictionary:
	var divers_data: Array = []
	for d in divers:
		var s: CombatantStats = d.stats
		divers_data.append({
			"position": [d.position.x, d.position.y, d.position.z],
			"sonar_active": d.sonar_active,
			"known_spells": (d.known_spells as Array).duplicate(),
			"equipped_spells": (d.equipped_spells as Array).duplicate(),
			"stats": {
				"hp_max": s.hp_max, "strength": s.strength, "defense": s.defense,
				"agility": s.agility, "accuracy": s.accuracy, "evasion": s.evasion,
				"oxygen_max": s.oxygen_max,
				"level": s.level, "xp": s.xp, "xp_to_next": s.xp_to_next,
				"spell_points": s.spell_points,
				"hp": s.hp, "oxygen": s.oxygen,
			},
		})
	return {
		"active": active,
		"ability_puzzle_solved": _puzzle_solved,
		"maze_entry_source": _maze_entry_source,
		"random_encounters_enabled": random_encounters_enabled,
		"inventory": inventory.duplicate(),
		"pending_world_drops": pending_world_drops.duplicate(true),
		"key_items": key_items.duplicate(),
		"revealed_key_items": revealed_key_items.duplicate(),
		"consumed_world_ids": consumed_world_ids.duplicate(),
		"save_point_tutorial_seen": _save_point_tutorial_seen,
		"route_state": route_state.to_save_data(),
		"divers": divers_data,
	}

func _serialize_state() -> Dictionary:
	var data := _serialize_world_state()
	# An uncompleted opening still uses the legacy World checkpoint contract.
	if _campaign_session == null or not route_state.prologue_complete:
		return data
	if embedded_maze != null:
		_campaign_session.maze_snapshot = embedded_maze.campaign_snapshot()
	_campaign_session.capture_party(divers, active)
	_campaign_session.inventory = inventory
	_campaign_session.campaign_key_items.assign(key_items)
	_campaign_session.route_state = route_state
	_campaign_session.random_encounters_enabled = random_encounters_enabled
	_campaign_session.outer_world_checkpoint = data
	return CampaignCheckpoint.encode(_campaign_session, "maze" if embedded_maze != null and embedded_maze.maze_active else "world")

func _write_save() -> Error:
	if _current_slot < 0:
		return ERR_UNCONFIGURED
	return SaveManager.write_slot(_current_slot, _serialize_state())

# Bails out and does nothing rather than a half-restore if the save data
# doesn't actually match divers[] one-to-one (a missing/corrupt slot reads
# back as {} from SaveManager, whose "divers" key then defaults to []) -
# a wrong-shaped restore silently leaving some divers untouched would be a
# worse bug than just not restoring at all.
func _load_save(from_autosave := false) -> bool:
	return restore_checkpoint(SaveManager.read_autosave(_current_slot) if from_autosave else SaveManager.read_slot(_current_slot))

# Shared validated restore used by disk Load and a live campaign return.
# Neither consumer needs to write a temporary save or discard live stats.
func restore_checkpoint(data: Dictionary) -> bool:
	_loaded_maze_session = null
	var maze_session: CampaignSession
	if data.has("campaign_scene") or data.has("campaign_checkpoint"):
		maze_session = CampaignCheckpoint.decode(data)
		if maze_session == null:
			return false
		if embedded_maze != null and not embedded_maze.snapshot_matches_runtime(maze_session.maze_snapshot):
			return false
	var raw_divers: Variant = data.get("divers", [])
	if not raw_divers is Array or raw_divers.size() != divers.size():
		return false
	# Validate the complete shape before mutating any live actor. Invalid IO
	# must not partly restore the party then fall through as a fresh opening.
	if not data.get("route_state", {}) is Dictionary:
		return false
	var raw_route := data.get("route_state", {}) as Dictionary
	if data.has("random_encounters_enabled") and not data["random_encounters_enabled"] is bool:
		return false
	if data.has("ability_puzzle_solved") and not data.ability_puzzle_solved is bool:
		return false
	if data.get("maze_entry_source", "deep_landmark") not in ["deep_landmark", "puzzle_exit"]:
		return false
	for field in ["opening_video_seen", "prologue_complete", "tutorial_complete", "deep_warning_seen"]:
		if raw_route.has(field) and not raw_route[field] is bool:
			return false
	var raw_active: Variant = data.get("active", 0)
	if not typeof(raw_active) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(raw_active)) or float(raw_active) != floorf(float(raw_active)) or int(raw_active) < 0 or int(raw_active) >= divers.size():
		return false
	for field in ["key_items", "revealed_key_items", "consumed_world_ids"]:
		var values: Variant = data.get(field, [])
		if not values is Array or values.any(func(value: Variant) -> bool: return not value is String):
			return false
	for field in ["inventory", "pending_world_drops"]:
		if not data.get(field, {}) is Dictionary:
			return false
	for drop_value in (data.get("pending_world_drops", {}) as Dictionary).values():
		if not drop_value is Dictionary:
			return false
		var drop := drop_value as Dictionary
		var position_value: Variant = drop.get("position", [])
		if not drop.get("item", "") is String or not position_value is Array or position_value.size() != 3 or position_value.any(func(value: Variant) -> bool: return not typeof(value) in [TYPE_INT, TYPE_FLOAT]):
			return false
	for snap_value in raw_divers:
		if not snap_value is Dictionary:
			return false
		var snap := snap_value as Dictionary
		if snap.has("sonar_active") and not snap["sonar_active"] is bool:
			return false
		var position_value: Variant = snap.get("position", [0, 2, 0])
		if not position_value is Array or position_value.size() != 3 or position_value.any(func(value: Variant) -> bool: return not typeof(value) in [TYPE_INT, TYPE_FLOAT]):
			return false
		if not snap.get("stats", {}) is Dictionary:
			return false
		var raw_stats := snap.get("stats", {}) as Dictionary
		for field in ["hp_max", "strength", "defense", "agility", "accuracy", "evasion", "oxygen_max", "level", "xp", "xp_to_next", "spell_points", "hp", "oxygen"]:
			if raw_stats.has(field) and (not typeof(raw_stats[field]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(raw_stats[field]))):
				return false
		for field in ["known_spells", "equipped_spells"]:
			var values: Variant = snap.get(field, [])
			if not values is Array or values.any(func(value: Variant) -> bool: return not value is String):
				return false
	var divers_data := raw_divers as Array
	# Preflight is complete. Old hazard timers must relinquish shared actors
	# before the loaded pose/resources replace them, never after that point.
	Whirlpool.cancel_in(self)
	_loaded_maze_session = maze_session if data.get("campaign_scene") == "maze" else null
	_campaign_session = maze_session
	_cancel_random_encounter_reveal()
	if is_instance_valid(escape_encounter_hint):
		escape_encounter_hint.dismiss()
	for i in range(divers.size()):
		var d: Diver = divers[i]
		var snap: Dictionary = divers_data[i]
		var pos: Array = snap.get("position", [d.position.x, d.position.y, d.position.z])
		d.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		d.known_spells.assign((snap.get("known_spells", []) as Array).duplicate())
		d.equipped_spells.assign((snap.get("equipped_spells", []) as Array).duplicate())
		# Saves from before auto-equip can have learned-but-unequipped spells.
		SpellTree.equip_all_known(d)
		var sd: Dictionary = snap.get("stats", {})
		var s: CombatantStats = d.stats
		s.hp_max = int(sd.get("hp_max", s.hp_max))
		s.strength = int(sd.get("strength", s.strength))
		s.defense = int(sd.get("defense", s.defense))
		s.agility = int(sd.get("agility", s.agility))
		s.accuracy = int(sd.get("accuracy", s.accuracy))
		s.evasion = int(sd.get("evasion", s.evasion))
		s.oxygen_max = float(sd.get("oxygen_max", s.oxygen_max))
		s.level = int(sd.get("level", s.level))
		s.xp = int(sd.get("xp", s.xp))
		s.xp_to_next = int(sd.get("xp_to_next", s.xp_to_next))
		s.spell_points = int(sd.get("spell_points", s.spell_points))
		s.hp = int(sd.get("hp", s.hp_max))
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
	_save_point_tutorial_seen = bool(data.get("save_point_tutorial_seen", false))
	route_state.load_save_data(data.get("route_state", {}) as Dictionary)
	random_encounters_enabled = data.get("random_encounters_enabled", true)
	_puzzle_solved = data.get("ability_puzzle_solved", false)
	_maze_entry_source = data.get("maze_entry_source", "deep_landmark")
	_sync_puzzle_maze_exit()
	for i in range(divers.size()):
		var d := divers[i] as Diver
		# Older completed checkpoints predate these settings. Migrate them
		# to the new exploration default; explicit later Off choices survive.
		var sonar_on: bool = divers_data[i].get("sonar_active", route_state.prologue_complete and d.passive_id == "sonar")
		sonar_on = sonar_on and d.passive_id == "sonar" and d.stats.oxygen > 0.0
		if d.sonar_active != sonar_on:
			d.toggle_sonar() # initializes the drain clock and refuses empty O2
	_first_encounter_done = route_state.prologue_complete
	_first_encounter_started = route_state.tutorial_complete
	_normalize_loaded_route_state()
	_sync_deep_zone_blocker_staging()
	_sync_lab_staging()

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

	if _campaign_session != null:
		_campaign_session.restore_party(divers)
		_campaign_session.route_state = route_state
	if embedded_maze != null:
		embedded_maze.inventory = inventory
		embedded_maze.campaign_key_items = key_items
		embedded_maze.route_state = route_state
		if maze_session != null:
			embedded_maze.campaign_session = maze_session
			embedded_maze.restore_campaign_snapshot(maze_session.maze_snapshot, _loaded_maze_session != null)
		elif _campaign_session == null:
			_campaign_session = CampaignSession.new()
			_campaign_session.route_state = route_state
			embedded_maze.campaign_session = _campaign_session
		# Restore the saved active diver, not the construction-time choice.
		embedded_maze.active = active
		embedded_maze._diver = divers[active]
	_update_hud()
	_update_hp_bar()
	_update_oxygen_bar()
	return true

func _normalize_loaded_route_state() -> void:
	# Flat legacy/entry saves contain the outer-world checkpoint, not maze
	# geometry. Returning there must leave the independent entrance usable.
	if _loaded_maze_session == null and route_state.zone_id == "maze":
		route_state.set_zone("deep")
		route_state.set_maze_door_state("available")
	# A movie decoder or live Battle is not a serializable checkpoint. Older or
	# interrupted saves that captured either transient state return to the safe
	# laboratory entrance and can replay the authored handoff exactly once.
	if route_state.lab_state in ["cutscene", "boss"] or route_state.tethys_state == "in_progress":
		route_state.set_lab_state("available")
		route_state.set_tethys_state("available")
		route_state.set_objective("find_lab")
		route_state.set_encounter_source("random")
	# The current maze is a separate deep-zone branch, not a reward for beating
	# Tethys. Migrate older deep-zone saves that captured the former lab-gated
	# `locked` state so they cannot remain permanently unable to use the branch.
	if route_state.zone_id == "deep" and route_state.maze_door_state == "locked":
		route_state.set_maze_door_state("available")
	# Migrate blocker-first objective copy from early PR #96 builds. The fight
	# states still preserve exactly where the player is; only the HUD hierarchy
	# changes so the laboratory remains the goal Marc described.
	if route_state.zone_id == "deep" and route_state.objective_id in ["defeat_bomb_bot", "defeat_sword_slayer", "enter_lab"]:
		route_state.set_objective("find_lab")

# get_tree().paused freezes every node whose process_mode isn't ALWAYS -
# the whole world (movement, physics, encounters, the HUD's own per-frame
# updates) just stops, and TitleScreen/GameOverScreen (both explicitly
# ALWAYS, see their own _ready()) are the only things still receiving
# input. Mirrors the pause Battle already puts the world into during a
# fight, just triggered by a menu screen instead of battle.gd.
func _audio_call(method: StringName) -> void:
	var owner := get_node_or_null("/root/GameAudio")
	if owner != null:
		owner.call(method)

func _show_title_screen() -> void:
	_cancel_random_encounter_reveal()
	if embedded_maze != null:
		embedded_maze.set_maze_active(false)
	cam.current = true
	if is_instance_valid(escape_encounter_hint):
		escape_encounter_hint.dismiss()
	# The title owns the entire cold-launch surface. Keeping it on a separate
	# layer lets the world HUD disappear as one unit instead of maintaining a
	# growing list of labels/bars/minimap nodes to hide individually.
	$HUD.visible = false
	# Cold title must remain silent until a trusted browser gesture. Any return
	# from gameplay also retires the prior world/battle/result cue here.
	_audio_call(&"stop_music")
	Whirlpool.refresh_in(self)
	get_tree().paused = true
	title_screen.open()

# New Game always starts from the fresh, level-1 divers _ready()'s CAST
# loop just built (nothing here resets stats - there's nothing to reset
# yet) - just claims a slot and writes the very first save into it, same
# role the old implicit end-of-_ready() checkpoint used to serve, now a
# real file instead of an in-memory snapshot.
func _on_title_new_game(slot: int) -> void:
	_current_slot = slot
	_autosave_timer = 0.0
	var existed := SaveManager.slot_exists(slot)
	var previous := FileAccess.get_file_as_bytes(SaveManager.slot_path(slot)) if existed else PackedByteArray()
	var error := _write_save()
	var written := error == OK
	if written:
		error = await BrowserCheckpoint.confirm_slot(slot)
	if error != OK:
		if written:
			SaveManager.rollback_slot(slot, existed, previous)
		_current_slot = -1
		title_screen.show_load_error("Could not start this saved run. Your previous saves are unchanged. Please retry.")
		return
	SaveManager.clear_autosave(slot)
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
	title_screen.close()
	await _play_opening_if_needed()
	_begin_quiet_spawn_if_needed()
	$HUD.visible = true
	get_tree().paused = false
	_audio_call(&"play_prologue_exploration_music" if not route_state.prologue_complete else &"play_exploration_music")
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		audio.fade_music_in(0.35)
	# Covers the plain --skip-tutorial/?skip_tutorial=1 route: skip_tutorial_
	# for_test was already true before _ready() ever rendered the light beam
	# (see the block right after _build_diver_slots()), so a player clicking
	# the ordinary "New Game" button still never gets the scripted first
	# fight. Since that fight is what normally triggers _show_ability_popups()
	# (via _on_battle_finished()), it has to fire from here instead - this is
	# the actual moment a skipped-tutorial game truly begins.
	if skip_tutorial_for_test:
		call_deferred("_show_ability_popups")

# The "New Game (Skip Tutorial)" title-screen button - same idea as
# --skip-tutorial, reachable without configuring a command-line arg. Unlike
# that flag, this fires from a button press well after _ready() already
# rendered the light beam/intro arrow assuming a normal tutorial run (only
# _tutorial_skip_requested() is checked that early), so this has to undo
# that setup itself before handing off to the same _on_title_new_game() flow
# every other new game goes through - reusing it rather than duplicating its
# save/intro-crawl/HUD handling.
func _on_title_skip_tutorial(slot: int = 0) -> void:
	skip_tutorial_for_test = true
	# This dedicated review entry bypasses the opening too. Normal New Game
	# never calls it; do not confuse its skip with completing optional training.
	route_state.opening_video_seen = true
	route_state.prologue_complete = true
	route_state.tutorial_complete = true
	route_state.set_prologue_phase("complete")
	# Otherwise _on_title_new_game() below still plays the full intro-crawl
	# narrative cutscene first, same as an ordinary New Game - every other
	# playtest button (Boss/Guardian/Special/Spell) jumps straight into
	# gameplay with none of that, and this one silently not matching them
	# reads as "the button doesn't work" rather than "there's a cutscene
	# playing first."
	skip_intro_for_test = true
	if is_instance_valid(light_beam):
		light_beam.queue_free()
	if is_instance_valid(_intro_arrow):
		_intro_arrow.queue_free()
	_intro_active = false
	_camera_look_override = null
	_first_encounter_started = true
	_first_encounter_done = true
	await _on_title_new_game(slot)

func _on_title_load_autosave(slot: int) -> void:
	await _on_title_load_game(slot, true)

func _on_title_load_game(slot: int, from_autosave := false) -> bool:
	_cancel_random_encounter_reveal()
	_current_slot = slot
	_autosave_timer = 0.0
	if not _load_save(from_autosave):
		_current_slot = -1
		$HUD.visible = false
		get_tree().paused = true
		title_screen.show_load_error("Could not load Slot %d. Choose another save or start a new game." % (slot + 1))
		print("CHECKPOINT_LOAD_FAILED|slot=", slot)
		return false
	title_screen.close()
	if _loaded_maze_session != null:
		_loaded_maze_session.selected_slot = slot
		_loaded_maze_session = null
		get_tree().paused = false
		_set_maze_ownership(true, true)
		_audio_call(&"play_exploration_music")
		_show_campaign_completion(true)
		return true
	if _campaign_session != null:
		_campaign_session.selected_slot = slot
	await _play_opening_if_needed()
	_begin_quiet_spawn_if_needed()
	$HUD.visible = true
	get_tree().paused = false
	_audio_call(&"play_prologue_exploration_music" if not route_state.prologue_complete else &"play_exploration_music")
	if route_state.octopus_state == "defeated":
		_show_campaign_completion(true)
		return true
	if route_state.prologue_complete:
		_build_optional_training()
	return true

# The opening owns no campaign state. World owns the durable milestone and
# writes it only after actual playback completes. A decoder fallback continues
# this session safely but intentionally leaves the viewing milestone false.
# Retry that cinematic only while the playable prologue is still incomplete;
# completed recovery takes precedence and must never rewind normal play.
func _play_opening_if_needed() -> bool:
	if route_state.prologue_complete or route_state.opening_video_seen:
		return true
	if skip_intro_for_test:
		route_state.opening_video_seen = true
		route_state.set_prologue_phase(RouteState.PROLOGUE_PHASE_SPAWN_EXPLORATION)
		_write_save()
		return true
	_audio_call(&"stop_music")
	route_state.set_prologue_phase(RouteState.PROLOGUE_PHASE_OPENING_VIDEO)
	opening_video = OpeningVideoScript.new() as CanvasLayer
	opening_video.show_opening_title = true
	opening_video.handoff_started.connect(func() -> void:
		route_state.set_prologue_phase("opening_handoff")
		# Prepare the HUD behind the opaque title so the final reveal includes
		# controls. World physics stays paused until completed below.
		_camera_look_override = null
		return_camera_to_player()
		# Settle the existing chase framing before revealing it, not on the
		# first unpaused frame (which otherwise visibly zooms after the fade).
		_move_camera(1.0)
		_update_hp_bar()
		_update_oxygen_bar()
		_update_active_cursor()
		$HUD.visible = true
	)
	title_layer.add_child(opening_video)
	var successful: bool = await opening_video.completed
	opening_video = null
	if successful:
		route_state.opening_video_seen = true
	route_state.set_prologue_phase(RouteState.PROLOGUE_PHASE_SPAWN_EXPLORATION)
	_write_save()
	return successful

func _begin_quiet_spawn_if_needed() -> void:
	if route_state.prologue_complete:
		return
	_intro_active = false
	_camera_look_override = null
	_announcements.clear()
	banner.text = ""
	route_state.set_objective("")
	route_state.set_prologue_phase("spawn_exploration")
	_prologue_spawn_delay = 0.35
	_prologue_trigger.reset((divers[active] as Diver).position)

func _update_prologue_trigger(dt: float) -> void:
	if route_state.prologue_complete or route_state.prologue_phase != "spawn_exploration" or battling:
		return
	if _prologue_spawn_delay > 0.0:
		_prologue_spawn_delay = maxf(0.0, _prologue_spawn_delay - dt)
		return
	var swimming := _player_dir().length_squared() > 0.0 and not target_selector.selecting and not _transitioning_to_encounter
	if _prologue_trigger.update((divers[active] as Diver).position, dt, swimming):
		route_state.set_prologue_phase("angler")
		route_state.set_encounter_source("prologue_angler")
		_start_battle("", false, "angler", divers, false, false, "An Angler darts out of the murk.", true)

func _on_prologue_angler_defeated() -> void:
	if route_state.prologue_phase != "angler" or not is_instance_valid(battle) or not battle.prologue_angler_encounter:
		return
	route_state.set_prologue_phase("angler_victory")
	_audio_call(&"play_prologue_victory_music")
	var bridge := preload("res://game/prologue_victory_bridge.gd").new()
	bridge.battlefield_texture = battle.get_battlefield_texture()
	bridge.beat_changed.connect(func(beat: String) -> void:
		match beat:
			"notice":
				route_state.set_prologue_phase("octopus_notice")
				_audio_call(&"fade_music_out")
			"omen":
				route_state.set_prologue_phase("octopus_omen")
	)
	title_layer.add_child(bridge)
	await bridge.completed
	# Music has already faded to silence during the notice. Retire its owner
	# explicitly before the movie starts, even if a device's audio thread lags.
	_audio_call(&"stop_music")
	route_state.set_encounter_source("prologue_octopus")
	route_state.set_prologue_phase("octopus_introduction")
	_prologue_cinematic = PrologueCinematicScript.new() as CanvasLayer
	title_layer.add_child(_prologue_cinematic)
	await _prologue_cinematic.introduction_finished
	get_tree().paused = false
	route_state.set_prologue_phase("octopus_reveal")
	battle.reveal_prologue_octopus()

func _report_prologue_phase(phase: String) -> void:
	print("PROLOGUE_PHASE|" + phase)

func _on_prologue_phase_changed(phase: String) -> void:
	route_state.set_prologue_phase(phase)

func _recover_from_prologue() -> void:
	_audio_call(&"stop_music")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_look = false
	# Hold deliberate silence while the defeated formation remains visible.
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(_prologue_cinematic) and not _prologue_cinematic.is_queued_for_deletion():
		route_state.set_prologue_phase("octopus_aftermath")
		_prologue_cinematic.resume_aftermath()
		await _prologue_cinematic.completed
	_prologue_cinematic = null
	route_state.set_prologue_phase("recovery")
	var recovery := PrologueRecoveryScript.new() as PrologueRecovery
	title_layer.add_child(recovery)
	for i in range(divers.size()):
		var diver := divers[i] as Diver
		diver.position = CAST[i].at as Vector3
		diver.velocity = Vector3.ZERO
		diver.stats.fill()
		if diver.passive_id == "sonar" and not diver.sonar_active:
			diver.toggle_sonar()
	active = 0
	yaw = 0.0
	pitch = -0.16
	_camera_look_override = null
	_intro_active = false
	_first_encounter_done = true
	_first_encounter_started = false
	route_state.prologue_complete = true
	route_state.set_encounter_source("random")
	random_encounters_enabled = true
	route_state.set_objective("")
	_announcements.clear()
	banner.text = ""
	_banner_timer = 0.0
	recovery.show_saving()
	var checkpoint_error := _write_save()
	if checkpoint_error == OK:
		checkpoint_error = await BrowserCheckpoint.confirm_slot(_current_slot)
	while checkpoint_error != OK:
		# Ordinary play must never be released on a false checkpoint promise.
		# Retain this restored session, explain the failure and retry the exact
		# active slot without replaying either movie or fight.
		recovery.show_save_failure()
		print("CHECKPOINT_SAVE_FAILED|slot=", _current_slot, "|error=", checkpoint_error)
		await recovery.continued
		recovery.show_saving()
		checkpoint_error = _write_save()
		if checkpoint_error == OK:
			checkpoint_error = await BrowserCheckpoint.confirm_slot(_current_slot)
	recovery.clear_save_failure()
	# The save is already safe if the player closes while reading motivation.
	await recovery.continued
	recovery.queue_free()
	if is_instance_valid(battle):
		battle.queue_free()
	battle = null
	battling = false
	route_state.set_prologue_phase("complete")
	_build_optional_training()
	_update_hud()
	_update_hp_bar()
	_update_oxygen_bar()
	$HUD.visible = true
	get_tree().paused = false
	_audio_call(&"play_exploration_music")
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		audio.fade_music_in(0.35)

func _build_optional_training() -> void:
	if not route_state.prologue_complete or route_state.tutorial_complete or is_instance_valid(light_beam):
		return
	# Use the existing training beam at its original clear-water position,
	# ten metres from recovery spawn, with no compulsory arrow/camera lock.
	render_light_beam()
	light_beam.position = Vector3(0.0, 6.0, 10.0)
	var label := Label3D.new()
	label.name = "OptionalTrainingLabel"
	label.text = "Optional Combat Training"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 72
	label.pixel_size = 0.01
	label.modulate = Color("a6e6ff")
	label.outline_size = 8
	# The old y=4 label projected directly through Maxilani's head after
	# recovery/Load. Put the optional affordance above the swimming silhouette.
	label.position = Vector3(0.0, 1.2, 0.0)
	label.no_depth_test = true
	light_beam.add_child(label)

func _on_title_boss_playtest() -> void:
	_current_slot = -1
	_boss_playtest_active = true
	title_screen.close()
	$HUD.visible = true
	get_tree().paused = false
	call_deferred("_start_battle", "", true)

func _on_title_special_playtest() -> void:
	_current_slot = -1
	_special_playtest_active = true
	title_screen.close()
	$HUD.visible = true
	get_tree().paused = false
	_offer_special_encounter("current_pearl")

# Drops straight into ordinary free-roam (no battle, no tutorial - see
# _ready()'s own use of _spell_playtest_requested() to also set
# skip_tutorial_for_test) with a fully learned/equipped temporary roster.
# This branch's normal progression automatically learns every currently
# affordable spell after a real victory (Battle._win()), so a review route
# that merely hands out points and keys but leaves `known_spells` empty is
# not a usable substitute: Party Spells says there is nothing to review.
# Learn through the same SpellTree rule instead of assigning arrays by hand,
# so prerequisites, key-item gates, and auto-equip remain real. Never writes
# a save, same as every other playtest route here.
func _on_title_spell_playtest() -> void:
	_current_slot = -1
	title_screen.close()
	$HUD.visible = true
	get_tree().paused = false
	_audio_call(&"play_exploration_music")
	for item_id in Items.ITEMS:
		if item_id != "maze_nav_map" and Items.is_key_item(String(item_id)) and not key_items.has(item_id):
			key_items.append(item_id)
	for d in divers:
		var diver := d as Diver
		diver.stats.spell_points = 99
		SpellTree.learn_all_available(diver, key_items)
	_announce("Spell test ready: spells are learned and equipped. Press Esc, then Party Spells.")

func _on_title_blocker_playtest() -> void:
	_current_slot = -1
	title_screen.close()
	$HUD.visible = true
	get_tree().paused = false
	_first_encounter_started = true
	_first_encounter_done = true
	route_state.set_zone("deep")
	route_state.set_objective("find_lab")
	_start_deep_zone_blocker("bomb_bot")

func _boss_playtest_requested() -> bool:
	if OS.get_cmdline_user_args().has("--boss-playtest"):
		return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return String(search).contains("boss=1")
	return false

func _special_playtest_requested() -> bool:
	if OS.get_cmdline_user_args().has("--special-playtest"):
		return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return String(search).contains("special=1")
	return false

func _blocker_playtest_requested() -> bool:
	if OS.get_cmdline_user_args().has("--blocker-playtest"):
		return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return String(search).contains("blocker=bomb_bot")
	return false

# For quickly iterating on tutorial_result_popup's own look/copy without
# actually needing to lose the scripted first fight every time - opens it
# immediately once the world loads, standing in for a real tutorial loss.
# Retry/Exit still work for real off of this (see _on_tutorial_loss_retry()/
# _on_tutorial_loss_exit()), neither depends on an actual Battle existing.
func _tutorial_loss_playtest_requested() -> bool:
	if OS.get_cmdline_user_args().has("--tutorial-loss-playtest"):
		return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return String(search).contains("tutorial_loss=1")
	return false

func _spell_playtest_requested() -> bool:
	if OS.get_cmdline_user_args().has("--spell-playtest"):
		return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return String(search).contains("spell_playtest=1")
	return false

func _maze_playtest_requested() -> bool:
	if OS.get_cmdline_user_args().has("--maze-playtest"):
		return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return String(search).contains("maze=1")
	return false

func _show_game_over() -> void:
	escape_encounter_hint.dismiss()
	print("CHECKPOINT_GAME_OVER|slot=", _current_slot, "|complete=", route_state.prologue_complete)
	# Defeat owns the whole screen just like cold launch. The controls, active
	# diver label, bars, minimap and any announcement describe a playable world
	# and become misleading noise once that world has been paused.
	$HUD.visible = false
	title_screen.close()
	_audio_call(&"play_game_over_music")
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
var _puzzle_hint_bounds := AABB()
var _puzzle_exit_label: Label3D

# Array[Dictionary], each {a: Vector3, b: Vector3, body: StaticBody3D,
# revealed: bool, line_a: Vector3, line_b: Vector3} - one entry per
# WALL_REVEAL_SEGMENT_LENGTH-ish slice of a wall (see
# _slice_wall_into_pieces(), called once per wall from _build_wall()).
# `a`/`b` are the piece's own full, fixed span; `line_a`/`line_b` are the
# actual overlap geometry frozen in at the moment this piece was first
# found (see _update_wall_visibility()/_piece_area_overlap()) - only
# meaningful once `revealed` is true, unset (Vector3.ZERO) before that.
# World's own walls are static - nothing here ever moves once built - so
# slicing once at build time is enough; there's no need to recompute a
# piece's endpoints every frame the way maze_mini_map.gd's live-swinging
# test-scene walls require. Read directly by mini_map.gd's
# _draw_lines_at_overlapping_areas() (world.gd has a class_name now, so
# MiniMap can type its reference and read this like any other property).
var _wall_pieces: Array[Dictionary] = []
var minimap: MiniMap

# How finely each wall is sliced for reveal purposes - matches
# maze_mini_map.gd's own REVEAL_SEGMENT_LENGTH, so a long corridor wall
# lights up gradually as you swim its length instead of all at once.
const WALL_REVEAL_SEGMENT_LENGTH := 2.0

# MODIFIED: was a one-shot PhysicsShapeQueryParameters3D/intersect_shape()
# sphere-cast, re-issued from scratch once a second - replaced with a
# persistent Area3D that follows the active diver (see
# _build_wall_sight_area()/_update_wall_visibility()), checked every
# physics tick via get_overlapping_bodies() instead. That's cheap even at
# full physics rate: it just reads the physics server's already-computed
# overlap list for this one Area3D, not a fresh broad-phase query over
# every wall in the level the way intersect_shape() was. It's only the
# COARSE first pass now, though - which walls are even worth checking
# closely this tick - see _update_wall_visibility()'s own per-piece
# distance check for what actually decides which exact stretch of a
# wall counts as "found."
var _wall_sight_area: Area3D

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

# Keeps the normal chase camera's position (still tracking the active diver)
# but points it at this instead of the diver, while set - used for the
# intro sequence's light beam so the player stays framed the whole walk
# over instead of the camera cutting away to hover near the beam. See
# _move_camera()'s own use of this.
var _camera_look_override: Node3D = null
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
	if OS.get_cmdline_user_args().has("--dev"):
		skip_intro_for_test = true
		skip_tutorial_for_test = true
	# Read-only trace synchronizes exported playtests to real gameplay without
	# query shortcuts or commands that mutate state.
	route_state.phase_changed.connect(_report_prologue_phase)
	cam = $Camera3D
	hud = $HUD/Controls
	# MODIFIED (added): none of $HUD's own children ever set mouse_filter,
	# so this hint label - like the banner/minimap/HP/oxygen bars below -
	# defaulted to STOP. $HUD stays visible for the entire duration of a
	# battle (nothing hides it when one starts), so any special-encounter
	# minigame's own full-screen _unhandled_input (mouse-look, click-to-
	# grapple) was getting eaten by whichever of these plain HUD elements
	# happened to sit under the cursor - none of them are meant to be
	# clickable in the first place.
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = Label.new()
	banner.name = "Banner"
	# Bottom-center, hugging the bottom edge of its own box so the text sits
	# right underneath the diver (who's roughly screen-center while playing)
	# and just above the HP/oxygen bars (_build_hp_bar/_build_oxygen_bar
	# occupy the last 82px at the very bottom - see below).
	banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	banner.offset_left = -320.0
	banner.offset_right = 320.0
	banner.offset_top = -170.0
	banner.offset_bottom = -130.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_font_size_override("font_size", 20)
	banner.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(banner)
	_build_route_objective_hud()
	escape_encounter_hint = preload("res://game/encounter_escape_hint.gd").new()
	$HUD.add_child(escape_encounter_hint)
	route_state.objective_changed.connect(_on_route_objective_changed)
	_on_route_objective_changed(route_state.objective_id)

	minimap = MiniMap.new()
	minimap.world = self
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -166.0
	minimap.offset_top = 10.0
	minimap.offset_right = -10.0
	minimap.offset_bottom = 166.0
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(minimap)
	_layout_world_hud_for_size(get_viewport().get_visible_rect().size)
	get_viewport().size_changed.connect(func() -> void:
		_layout_world_hud_for_size(get_viewport().get_visible_rect().size)
	)
	_build_wall_sight_area()

	save_point_menu = SavePointMenu.new()
	save_point_menu.save_requested.connect(_on_save_requested)
	$HUD.add_child(save_point_menu)

	inventory_menu = InventoryMenu.new()
	inventory_menu.world = self
	$HUD.add_child(inventory_menu)
	inventory_menu.visibility_changed.connect(_refresh_world_reading)
	save_point_menu.visibility_changed.connect(_refresh_world_reading)

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
	_build_diver_slots()
	# The spell-playtest route (see _on_title_spell_playtest()) is meant to
	# reach a save point immediately, same reason it also grants max spell
	# points/every key item - fighting through the scripted first battle
	# first would defeat the point of a fast spell-testing loop.
	if _tutorial_skip_requested() or _spell_playtest_requested() or _blocker_playtest_requested():
		skip_tutorial_for_test = true
	if skip_tutorial_for_test:
		# Never spawn the beam/arrow at all, and mark the tutorial as already
		# done up front - TAB/random encounters/the save point prompt all
		# gate on _first_encounter_done, the same state a player has after
		# actually finishing the real tutorial fight.
		_first_encounter_started = true
		_first_encounter_done = true
		route_state.opening_video_seen = true
		route_state.prologue_complete = true
		route_state.tutorial_complete = true
		route_state.set_prologue_phase("complete")
	_update_hud()

	# Do not parent the title to HUD: _show_title_screen() deliberately hides
	# that whole layer so its controls cannot bunch underneath the title on the
	# first frame. This layer remains visible and interactive while paused.
	title_layer = CanvasLayer.new()
	title_layer.name = "TitleLayer"
	title_layer.layer = 20
	add_child(title_layer)
	title_screen = TitleScreen.new()
	title_screen.new_game_chosen.connect(_on_title_new_game)
	title_screen.load_game_chosen.connect(_on_title_load_game)
	title_screen.load_autosave_chosen.connect(_on_title_load_autosave)
	title_screen.boss_playtest_chosen.connect(_on_title_boss_playtest)
	title_screen.special_playtest_chosen.connect(_on_title_special_playtest)
	title_screen.spell_playtest_chosen.connect(_on_title_spell_playtest)
	title_screen.skip_tutorial_chosen.connect(_on_title_skip_tutorial)
	title_screen.blocker_playtest_chosen.connect(_on_title_blocker_playtest)
	title_layer.add_child(title_screen)
	if _boss_playtest_requested():
		title_screen.enable_boss_playtest()
	if _special_playtest_requested():
		title_screen.enable_special_playtest()
	if _spell_playtest_requested():
		title_screen.enable_spell_playtest()
	if _tutorial_skip_requested():
		title_screen.enable_skip_tutorial()
	if _blocker_playtest_requested():
		title_screen.enable_blocker_playtest()

	special_encounter_prompt = SpecialEncounterPrompt.new()
	special_encounter_prompt.diver_chosen.connect(_on_special_encounter_diver_chosen)
	special_encounter_prompt.cancelled.connect(_on_special_encounter_cancelled)
	title_layer.add_child(special_encounter_prompt)

	tutorial_book = TutorialBook.new()
	title_layer.add_child(tutorial_book)

	tutorial_result_popup = TutorialResultPopup.new()
	tutorial_result_popup.retry_chosen.connect(_on_tutorial_loss_retry)
	tutorial_result_popup.exit_chosen.connect(_on_tutorial_loss_exit)
	title_layer.add_child(tutorial_result_popup)
	if _tutorial_loss_playtest_requested():
		call_deferred("_show_tutorial_loss_playtest")

	game_over_screen = GameOverScreen.new()
	game_over_screen.restart_chosen.connect(_on_game_over_restart)
	game_over_screen.title_chosen.connect(_on_game_over_title)
	# This cannot live under HUD: _show_game_over() deliberately hides HUD as
	# one unit. Keep both exclusive, paused menu surfaces on the overlay layer.
	title_layer.add_child(game_over_screen)
	_build_embedded_maze()

	# A game-over restart must rebuild the scene before applying its save so
	# unsaved geometry and inventory roll back as one checkpoint. Cold launch
	# still opens the title screen exactly as before.
	if SceneHandoff.returning_to_world:
		SceneHandoff.returning_to_world = false
		var returned := SceneHandoff.take_campaign_session()
		if not _restore_campaign_return(returned):
			_show_title_screen()
			title_screen.show_load_error("Could not restore the open-water route. Choose a saved game.")
	elif _restart_slot >= 0:
		var restart_slot := _restart_slot
		_restart_slot = -1
		if await _on_title_load_game(restart_slot):
			_announce("You wake back at your last save.")
	else:
		_show_title_screen()
		if not SceneHandoff.checkpoint_load_error.is_empty():
			title_screen.show_load_error(SceneHandoff.checkpoint_load_error)
			SceneHandoff.checkpoint_load_error = ""
	if OS.get_cmdline_user_args().has("--dev"):
		_start_dev_mode.call_deferred()
	elif _maze_playtest_requested():
		call_deferred("_enter_maze_scene", true)

func _start_dev_mode() -> void:
	# Explicit command-line diagnostics never claim or write a player slot.
	_current_slot = -1
	route_state.opening_video_seen = true
	route_state.prologue_complete = true
	route_state.set_prologue_phase("complete")
	for id in Items.ITEMS:
		if Items.is_key_item(String(id)):
			if id != "maze_nav_map" and not key_items.has(id):
				key_items.append(id)
		else:
			inventory[id] = 5
	title_screen.close()
	get_tree().paused = false
	$HUD.visible = true
	embedded_maze.keys_held = 99
	if embedded_maze._gate != null:
		embedded_maze._gate_lowered = true
		embedded_maze._gate.visible = false
		for child in embedded_maze._gate.get_children():
			if child is CollisionShape3D:
				child.disabled = true
	var front := Vector3(263, 2, DeepZoneLayoutScript.MAZE_TRANSITION.z)
	if OS.get_cmdline_user_args().has("--secret-room"):
		var room := embedded_maze._secret_item_room_rect().abs()
		front = Vector3(room.get_center().x, embedded_maze._floor_top_y + 1.2, room.get_center().y)
	for i in divers.size():
		(divers[i] as Diver).global_position = front + Vector3(-float(i) * 1.5, 0, float(i) * 1.5)
		(divers[i] as Diver).velocity = Vector3.ZERO
	_set_maze_ownership(true)
	_announce("DEV MODE: temporary items and maze keys. No player save is written.")

func _restore_campaign_return(session: CampaignSession) -> bool:
	if session == null or session.outer_world_checkpoint.is_empty():
		return false
	session.route_state.set_zone("deep")
	session.route_state.set_maze_door_state("available")
	session.route_state.set_encounter_source("random")
	var data := CampaignCheckpoint.encode(session, "world")
	# The World entrance activates automatically inside its radius. A return
	# places the party just outside it, in the protected open-water approach.
	var spot := deep_zone_layout.route_points().maze_transition as Vector3
	if session.outer_world_checkpoint.get("maze_entry_source", "deep_landmark") == "puzzle_exit":
		spot = PUZZLE_MAZE_EXIT + Vector3(8.0, 0, 0)
	else:
		spot += Vector3(-(MAZE_TRANSITION_RADIUS + 3.0), 0, 0)
	for i in range(3):
		data.divers[i].position = CampaignSession.vector_data(spot + Vector3(0, 0, (i - session.active) * 2.5))
	if not restore_checkpoint(data):
		return false
	# Disk Load builds new resources; a live return must retain their identity.
	session.restore_party(divers)
	session.route_state = route_state
	_campaign_session = session
	_current_slot = session.selected_slot
	_restart_slot = -1
	title_screen.close()
	$HUD.visible = true
	get_tree().paused = false
	_audio_call(&"play_exploration_music")
	_update_hud()
	return true

# A floor and some rock so there is parallax to swim past: without something
# to move relative to, motion at this scale reads as standing still.
func _build_site() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "ShallowsFloorBody"
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "ShallowsFloor"
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

	# The authored route continues east beyond the former x=62 collision rail.
	# Keep this as its own darker surface so the boundary is visible rather
	# than merely changing a zone id while the world looks identical.
	var deep_body := StaticBody3D.new()
	deep_body.name = "DeepZoneFloorBody"
	var deep_mesh := MeshInstance3D.new()
	deep_mesh.name = "DeepZoneFloor"
	var deep_plane := PlaneMesh.new()
	deep_plane.size = Vector2(
		DeepZoneLayoutScript.WORLD_MAX_X - DeepZoneLayoutScript.DEEP_START_X,
		DeepZoneLayoutScript.WORLD_HALF_Z * 2.0
	)
	deep_mesh.mesh = deep_plane
	var deep_material := StandardMaterial3D.new()
	deep_material.albedo_color = Color(0.025, 0.06, 0.09)
	deep_material.roughness = 1.0
	deep_mesh.material_override = deep_material
	deep_body.position = Vector3(
		(DeepZoneLayoutScript.DEEP_START_X + DeepZoneLayoutScript.WORLD_MAX_X) * 0.5,
		0.0,
		0.0
	)
	deep_body.add_child(deep_mesh)
	var deep_shape := CollisionShape3D.new()
	var deep_box := BoxShape3D.new()
	deep_box.size = Vector3(
		DeepZoneLayoutScript.WORLD_MAX_X - DeepZoneLayoutScript.DEEP_START_X,
		0.4,
		DeepZoneLayoutScript.WORLD_HALF_Z * 2.0
	)
	deep_shape.shape = deep_box
	deep_shape.position.y = -0.2
	deep_body.add_child(deep_shape)
	add_child(deep_body)

	deep_zone_environment = DeepZoneEnvironmentScript.new()
	deep_zone_environment.name = "DeepZoneEnvironment"
	add_child(deep_zone_environment)
	_build_deep_zone_blocker_staging()

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
	_build_boundary_walls()
	_build_item_grapple_anchors()

# Keep the playable space inside the visible seafloor perimeter. These outer
# safety rails intentionally do not appear on the minimap; unlike a ceiling,
# they align with the readable end of the authored world rather than cutting
# through ordinary open water.
func _build_boundary_walls() -> void:
	const WALL_HEIGHT := 80.0
	const WALL_Y := 30.0
	const THICKNESS := 4.0
	var span_x := DeepZoneLayoutScript.WORLD_MAX_X - DeepZoneLayoutScript.WORLD_MIN_X
	var center_x := (DeepZoneLayoutScript.WORLD_MIN_X + DeepZoneLayoutScript.WORLD_MAX_X) * 0.5
	var span_z := DeepZoneLayoutScript.WORLD_HALF_Z * 2.0
	_build_invisible_wall(Vector3(center_x, WALL_Y, DeepZoneLayoutScript.WORLD_HALF_Z + THICKNESS * 0.5), Vector3(span_x + THICKNESS * 2.0, WALL_HEIGHT, THICKNESS))
	_build_invisible_wall(Vector3(center_x, WALL_Y, -DeepZoneLayoutScript.WORLD_HALF_Z - THICKNESS * 0.5), Vector3(span_x + THICKNESS * 2.0, WALL_HEIGHT, THICKNESS))
	# Only the lab-side ramp opening leaves the World perimeter.
	var gap := DeepZoneLayoutScript.MAZE_TRANSITION.z
	var half_width := DeepZoneLayoutScript.MAZE_APPROACH_HALF_WIDTH
	for limits in [[-DeepZoneLayoutScript.WORLD_HALF_Z - THICKNESS, gap - half_width], [gap + half_width, DeepZoneLayoutScript.WORLD_HALF_Z + THICKNESS]]:
		_build_invisible_wall(Vector3(DeepZoneLayoutScript.WORLD_MAX_X + THICKNESS * 0.5, WALL_Y, (float(limits[0]) + float(limits[1])) * 0.5), Vector3(THICKNESS, WALL_HEIGHT, float(limits[1]) - float(limits[0])))
	_build_invisible_wall(Vector3(DeepZoneLayoutScript.WORLD_MIN_X - THICKNESS * 0.5, WALL_Y, 0.0), Vector3(THICKNESS, WALL_HEIGHT, span_z + THICKNESS * 2.0))

func _build_invisible_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

# CrackedWalls scattered around the open world. Ground-level rocks give a
# random consumable; the four airborne rocks at 3x blockade height instead
# hold two fixed spell keys and two enemy ambushes. No invisible collision
# extension (collision_height/width stay 0) since only breaking them matters.
#
# Spread through open water away from every other placed thing - clear of
# the anchor's own radius (Sites.ALL[0], r=6.5), both combat sites' radii
# (shallows r=9.5 at (-24,-12), trench r=10.0 at (12,-42)), and the gated
# highway corridor.
# Two formerly misplaced rocks remain before the visible entrance formation,
# keeping their rewards available without making the player cross that authored
# gate first. The old 60 m invisible collision wing no longer exists.
#
# disguised_as_scenery_rock left at its default (false) on purpose - these
# read as a rounded rock (sphere_shaped) recolored brown, so a player can
# spot "this one's breakable" on sight rather than only discovering these
# by sweeping the whole site with shockwave.
func _build_breakable_rocks() -> void:
	const SPOTS := [
		Vector3(6.0, 1.0, -7.0), Vector3(-7.0, 1.0, 5.0),
		Vector3(-15.0, 1.0, -20.0), Vector3(-3.0, 1.0, -30.0),
		Vector3(-25.0, 1.0, 12.0), Vector3(10.0, 1.0, -15.0),
		Vector3(8.0, 1.0, 22.0),
		# These four rocks float three times the 6m blockade height above the
		# seafloor. Two hold spell keys and two conceal encounter ambushes.
		# All four stay before the visible entrance formation (see the note
		# above), so the Sunken Core and ambushes remain available beforehand.
		Vector3(-38.0, AIRBORNE_ROCK_HEIGHT, 22.0), Vector3(10.0, AIRBORNE_ROCK_HEIGHT, -48.0),
		Vector3(-38.0, AIRBORNE_ROCK_HEIGHT, -30.0), Vector3(10.0, AIRBORNE_ROCK_HEIGHT, 46.0),
	]
	for i in range(SPOTS.size()):
		var spot: Vector3 = SPOTS[i]
		var id := "rock_%d" % i
		var rock := CrackedWall.new()
		rock.span = Vector3(1.1, 1.1, 1.1)
		rock.sphere_shaped = true
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
	if ROCK_KEY_ITEM_REWARDS.has(id):
		var key_item := String(ROCK_KEY_ITEM_REWARDS[id])
		if not key_items.has(key_item):
			key_items.append(key_item)
		var display := String(Items.ITEMS.get(key_item, {}).get("display", key_item))
		_announce("Found the key item %s!" % display)
		return
	if id in ROCK_AMBUSH_IDS:
		_start_battle("", false, "angler", [], false, false, "Some enemies were hiding in the rocks!")
		return
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
	_refresh_world_guidance()

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
	# MODIFIED (fixed): battle_only items (attack_up/defense_up - see
	# items.gd's own header comment) are only ever meant to last "for the
	# rest of this fight," which is entirely battle.gd's own bookkeeping
	# (_resolve_item() records the amount, _revert_temp_buffs() subtracts it
	# back off before the fight ends) - this world-map inventory menu never
	# goes through that at all (Esc's inventory_menu.open() only ever fires
	# while not battling, see _unhandled_input()'s own guard), so calling
	# Items.grant() from here was a real, permanent stat increase with
	# nothing left to ever revert it. would_help() still returns true for
	# these (a real battle-time check still needs to allow them), so this
	# needs its own explicit refusal rather than reusing that check.
	if bool(Items.ITEMS.get(item_id, {}).get("battle_only", false)):
		_announce("This item can only be used during a battle.")
		return
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
# battle.gd, so Maxilani's free base Heal really does stay free here too).
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
# The one place in the dive site worth swimming *to*, as opposed to swimming
# around until something attacks you.
#
# Every other piece of this already existed and was already wired to
# ItemGuardian.spots(): sonar reveals a spot once you get within the minimap's
# view radius (diver.gd's update_sonar), the minimap then draws a pulsing
# marker for it or an arrow toward it (mini_map.gd), and winning the special
# encounter it can now open (see _try_trigger_item_site()) grants the item
# (_grant_reward_item). The only thing missing here originally was the six
# lines that put a guarded site's ring/plinth in the water at all. They were
# here, wrapped in a triple-quoted string, which GDScript parses as a string
# literal and Godot never warns about, so the function ran and built
# nothing. See #45.
# Places to discover while exploring or using Maxilani's sonar.
#
# The dive site used to be open water with rocks in it: encounters happened
# wherever you were, so the terrain did no work and there was nothing on the
# map to aim at. This is the answer from the first combat PR, ported: a
# handful of built places joined by trails of lit beacons.
#
# A site is a bowl. A low berm ring you physically cross, broken columns
# round the rim, and a plinth at the middle. The enclosure is the point:
# it narrows the volume, which is the only thing that makes a fight inside
# it mean anything in three dimensions, where anything in open water can be
# swum around.
#
# The site bowls themselves have no decorative lamps. Ordinary guarded item
# locations get cyan grappleable rings; special encounter sites have none.
func _build_dive_sites() -> void:
	for d in Sites.ALL:
		var site: Site = SiteScript.new()
		add_child(site)
		site.build(d)
		site_nodes[String(d.id)] = site


# A straight corridor out past the rest of the scattered rocks - and the
# whole first real gate, not just scenery to swim through. In order:
#   0. A save point sits before the entrance blockade, in the open dive
#      site - a rest/prep stop before the gate, not a reward for clearing
#      it (see save_point.gd).
#   1. Rubble blocks the entrance - only Mech Pilot's shockwave clears it
#      (an invisible collision extension well above the visible rocks
#      rules out just swimming over the top - see cracked_wall.gd).
#   2. A whirlpool over a real gap in the floor. Getting close warns you;
#      getting caught sucks you in, costs HP, and sweeps you back - unless
#      you're mid-grapple, which is exempt (see whirlpool.gd). Nothing
#      ever disarms it - there is no bridge, no permanent safe crossing.
#      Every plain swim through it gets caught, every single time. A
#      second GrappleAnchor sits right before it as a staging point; the
#      real crossing anchor is on the far side.
#   3. Reaching that far anchor used to unlock Maxilani's swap ability (see
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
	const WALL_HEIGHT := BLOCKADE_HEIGHT

	var length := END_X - START_X
	var center_x := (START_X + END_X) * 0.5
	# Contextual guidance follows this visible room, not a world-spanning
	# collider or a saved objective. Small margins count contact/approach.
	_puzzle_hint_bounds = AABB(
		Vector3(START_X - 3.0, 0.0, LANE_Z - LANE_HALF_WIDTH - 2.0),
		Vector3(length + 6.0, WALL_HEIGHT + 2.0, LANE_HALF_WIDTH * 2.0 + 4.0)
	)

	# 0. A save point before the corridor even starts - the first place in
	# the game save menu becomes available at all (see
	# save_point.gd/SavePointMenu). Sits in the open dive site ahead of the
	# entrance blockade, not inside the walled corridor, so it reads as
	# "rest here before attempting the gate," not "partway through it."
	var save_point := SavePoint.new()
	save_point.position = Vector3(START_X - 5.0, 2.0, LANE_Z)
	# Contact volume is centred at swimming height; its visual footprint belongs
	# on the floor, not across the player's torso at that same two-metre height.
	save_point.footprint_offset_y = -1.8
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
	# Mech Pilot's shockwave clears it.
	var entrance_rocks := CrackedWall.new()
	entrance_rocks.span = Vector3(2.0, WALL_HEIGHT, LANE_HALF_WIDTH * 2.0)
	# Invisible collision extends far above the visible rocks - divers rise
	# freely in 3D, so a blockade that only matched its visible height
	# could just be swum over, the same gap the corridor's own walls have
	# (and accept, since going over a wall to cut a corner isn't the same
	# problem as skipping a gate entirely).
	entrance_rocks.collision_height = 40.0
	# Collision stays the same width as the visible formation. Extending it
	# across open water prevents a bypass, but does so with an invisible wall
	# that blocks ordinary travel far outside the authored corridor. The
	# visible side walls and route staging must communicate/contain the gate;
	# collision cannot silently reach beyond what the player can see.
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
	# far side - a staging point for Musashi on the approach, not itself
	# a way across.
	var near_anchor := GrappleAnchor.new()
	# Leave enough swim room after the staging pull to move past this
	# collider before aiming at the far anchor. At GAP_START_X - 1 the
	# diver stopped inside the near anchor's generous target cylinder, so
	# the next straight shot selected it again instead of crossing.
	near_anchor.position = Vector3(GAP_START_X - 3.0, 2.0, LANE_Z)
	add_child(near_anchor)

	# 3. The anchor that unlocks Maxilani's swap - reaching it is the
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
	_puzzle_exit_label = Label3D.new()
	_puzzle_exit_label.name = "PuzzleMazeEntranceLabel"
	_puzzle_exit_label.text = "DEEP WATER\nLaboratory and maze beyond"
	_puzzle_exit_label.position = PUZZLE_MAZE_EXIT + Vector3(0, 2.8, 0)
	_puzzle_exit_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_exit_label.font_size = 48
	_puzzle_exit_label.outline_size = 12
	_puzzle_exit_label.modulate = Color("a9e8ff")
	_puzzle_exit_label.pixel_size = 0.009
	_puzzle_exit_label.visible = false
	add_child(_puzzle_exit_label)

func _on_whirlpool_warned() -> void:
	# The whirlpool shows its own "Danger: Whirlpool ahead" caption while
	# the diver is within its warning radius (see whirlpool.gd).
	pass

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
	_sync_puzzle_maze_exit()
	var cutscene := Cutscene.new()
	add_child(cutscene)
	cutscene.play_scroll_text("Welcome to the deep sea")
	_announce("The way is open. Explore the deep sea.")

func _sync_puzzle_maze_exit() -> void:
	if is_instance_valid(_puzzle_exit_label):
		_puzzle_exit_label.visible = _puzzle_solved
	if not _puzzle_solved:
		return
	for door in _doors:
		(door as Door).open()
	if route_state.maze_door_state == "locked":
		route_state.set_maze_door_state("available")
	# The old visual-only goal must not compete with the actual doorway.
	if is_instance_valid(_puzzle_goal):
		_puzzle_goal.visible = false

# One plain wall segment: a StaticBody3D box, solid (divers collide with
# it via CharacterBody3D's own move_and_slide, same as the floor), centered
# on `center` with total dimensions `size`.
func _build_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	# Tag so _update_wall_visibility()'s detection area can tell an actual
	# wall apart from anything else it might overlap (the diver's own
	# body, CrackedWall rocks, LockPlates, whatever else sits on a
	# physics layer it can see).
	body.add_to_group("Wall")

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
		_slice_wall_into_pieces(center - Vector3(size.x * 0.5, 0.0, 0.0), center + Vector3(size.x * 0.5, 0.0, 0.0), body)
	else:
		_slice_wall_into_pieces(center - Vector3(0.0, 0.0, size.z * 0.5), center + Vector3(0.0, 0.0, size.z * 0.5), body)

# Cuts one wall's full [a, b] span into WALL_REVEAL_SEGMENT_LENGTH-ish
# pieces, each its own independent reveal entry - see _wall_pieces' own
# comment for why a long wall should light up gradually rather than all
# at once the moment any part of it is found.
func _slice_wall_into_pieces(a: Vector3, b: Vector3, body: StaticBody3D) -> void:
	var length: float = a.distance_to(b)
	var count: int = maxi(1, int(ceil(length / WALL_REVEAL_SEGMENT_LENGTH)))
	for i in range(count):
		_wall_pieces.append({
			"a": a.lerp(b, float(i) / float(count)),
			"b": a.lerp(b, float(i + 1) / float(count)),
			"body": body,
			"revealed": false,
			"line_a": Vector3.ZERO,
			"line_b": Vector3.ZERO,
		})

func _refresh_world_reading() -> void:
	Whirlpool.refresh_in(self)
	if embedded_maze != null and embedded_maze.maze_active:
		return # Its own reading/input owner controls the shared party.
	var reading := _checkpoint_saving or inventory_menu.visible or save_point_menu.visible
	for actor in divers:
		# Sonar owns a separate physics clock; stopping World.swim alone would
		# keep billing Oxygen behind this exclusive reading surface.
		actor.exploration_paused = reading or (embedded_maze != null and embedded_maze.contains_point(actor.global_position))

func whirlpool_activity() -> int:
	if battling or _transitioning_to_encounter or (embedded_maze != null and embedded_maze.maze_active):
		return Whirlpool.Activity.INACTIVE
	if _checkpoint_saving or not $HUD.visible or (inventory_menu != null and inventory_menu.visible) \
		or (save_point_menu != null and save_point_menu.visible):
		return Whirlpool.Activity.SUSPENDED
	return Whirlpool.Activity.EXPLORING

func _unhandled_input(e: InputEvent) -> void:
	if _checkpoint_saving:
		get_viewport().set_input_as_handled()
		return
	if embedded_maze != null and embedded_maze.maze_active:
		return
	if battling or _transitioning_to_encounter:
		return
	# These menus freeze exploration through this owner rather than pausing
	# the entire SceneTree. Physics already respects them; keyboard/mouse
	# dispatch must do the same or F/Tab can act behind a reading screen.
	if inventory_menu.visible or save_point_menu.visible:
		if e is InputEventKey and e.pressed and not e.echo:
			if e.keycode == KEY_ESCAPE:
				if save_point_menu.visible:
					save_point_menu.close()
				else:
					inventory_menu.close()
			elif e.keycode == KEY_P and save_point_menu.visible:
				save_point_menu.close()
		get_viewport().set_input_as_handled()
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

	# TargetSelector intercepts A/D/Left/Right/Space/Enter the same way aim mode
	# intercepts clicks - before they'd otherwise turn the camera or do
	# nothing at all (see _physics_process, which suppresses the normal
	# arrow-key camera turn outright while target_selector.selecting).
	if target_selector.selecting and e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var sk := (e as InputEventKey).keycode
		if sk == KEY_D or sk == KEY_RIGHT:
			target_selector.select_next()
			_update_hud()
			return
		elif sk == KEY_A or sk == KEY_LEFT:
			target_selector.select_previous()
			_update_hud()
			return
		elif sk == KEY_SPACE or sk == KEY_ENTER or sk == KEY_KP_ENTER:
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
	# Left-click-and-drag always works here, independent of mouse_look/
	# MOUSE_MODE_CAPTURED - a guaranteed fallback for whatever's leaving
	# capture-based free-look dead after the tutorial (reported: arrow-key
	# turning still works, so battling/pause aren't the gate; captured
	# mouse-look specifically goes silent). Doesn't touch mouse_look or
	# Input.mouse_mode at all, so it can't make that separate problem worse.
	elif e is InputEventMouseMotion and (mouse_look or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		var mm := e as InputEventMouseMotion
		yaw -= mm.relative.x * 0.004
		pitch = clampf(pitch - mm.relative.y * 0.003, -1.1, 0.7)
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var k := (e as InputEventKey).keycode
		if k == KEY_TAB:
			if route_state.prologue_complete and not aiming and not target_selector.selecting and not _intro_active:
				active = (active + 1) % divers.size()
				_update_hud()
		elif k == KEY_F:
			_start_ability()
		elif k == KEY_P:
			_toggle_save_menu()
		elif k == KEY_Q:
			_toggle_sonar()
		elif k == KEY_R:
			_toggle_random_encounters()
		elif k == KEY_F1:
			tutorial_book.open(TutorialContent.GENERAL_PAGES)

# F's actual behavior depends on the active diver's ability: shockwave has
# nothing to aim, fires immediately. Grapple enters first-person aim mode.
# Swap goes through TargetSelector's cycle-through-candidates flow instead
# of either - see target_selector.gd.
func _start_ability() -> void:
	if not route_state.prologue_complete or aiming or target_selector.selecting:
		return
	var d: Diver = divers[active]
	if not d.can_use_ability() or _intro_active:
		return
	if d.ability_id == "swap":
		target_selector.start_selection(d)
		_update_hud()
	elif d.ability_needs_aim():
		aiming = true
		# Aim uses the active diver's eye line. Keep their own rig out of that
		# first-person view so the body cannot cover the crosshair or target.
		d.set_model_visible(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_look = true
		_update_hud()
	else:
		d.use_ability(_aim_dir())

# Q, separate from F - sonar isn't the active diver's "ability" (that slot
# is swap, on this same diver), it's a passive being switched on and off,
# so it gets its own key rather than competing with _start_ability(). Only
# does anything for whichever diver actually has the sonar passive; a
# stray Q on anyone else is a silent no-op just like it would be on a
# diver with no ability at all.
#
# Silent no-op (same shape as _start_ability()'s own _intro_active check)
# until the choreographed first fight is actually done - _first_encounter_
# done covers the intro walk AND the fight itself (battling already blocks
# _unhandled_input() outright, but the brief transition tween between the
# two - _transitioning_to_encounter - has neither flag set), so this one
# check covers the whole span "before the tutorial" actually means,
# without a separate carve-out for that gap. No "not yet" message either -
# the goal is a clean first walk with nothing else competing for
# attention, not a wall of "can't do that yet" banners.
func _toggle_sonar() -> void:
	if not route_state.prologue_complete:
		return
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

# Flips random_encounters_enabled - _on_encounter_triggered() reads it as
# its own early-out, so this doesn't touch a battle already in progress,
# only whether a NEW one is allowed to start. No _first_encounter_done gate
# like _toggle_sonar() has - unlike sonar (a diver ability that wouldn't
# make sense to explain before the tutorial hands out abilities at all),
# this is a player convenience that's just as meaningful before the
# tutorial fight as after it.
func _toggle_random_encounters() -> void:
	random_encounters_enabled = not random_encounters_enabled
	escape_encounter_hint.set_encounters_enabled(random_encounters_enabled)
	_announce("Random encounters on." if random_encounters_enabled else "Random encounters off.")
	_update_hud()   # refreshes the "R: Encounters (On/Off)" hint immediately

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
	if not route_state.prologue_complete:
		_announce("Finish your first encounter before saving.")
		return
	# Pressing P off a save point used to just silently do nothing - which
	# reads identically to "the menu is broken" from the player's side.
	# Bannering it means a stray P press is never mistaken for a bug.
	if not _diver_on_save_point(divers[active]):
		_announce("No save point nearby.")
		return
	save_point_menu.open_for(divers[active])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_look = false

func _diver_on_save_point(d: Diver) -> bool:
	for sp in _save_points:
		if (sp as SavePoint).has_diver(d):
			return true
	return false

# world.gd owns showing the confirmation and closing the menu - the menu
# itself only emits the request; World checks the persistent write before
# promising success or changing the run's active checkpoint.
#
# A save-point visit restores HP/O2 on contact; this handler writes a real
# save file (_write_save()) to whichever slot this run is
# playing into - a game over's "Restart from Save Point" (see
# _show_game_over()/_on_game_over_restart()) reads back exactly this.
#
# HP/oxygen restore for the WHOLE party, not just whoever's physically
# standing on the point - battle damage (and oxygen spend) is shared
# across all three divers, so a rest stop patching up only the one you
# happened to be steering would leave the other two stuck damaged/
# drained with no other way to recover.
func _manual_save_safe() -> bool:
	if battling or _transitioning_to_encounter or _intro_active or aiming or target_selector.selecting or get_tree().paused:
		return false
	if not route_state.prologue_complete or title_screen.visible or is_instance_valid(random_encounter_reveal) or is_instance_valid(_lab_video_cutscene):
		return false
	if special_encounter_prompt.visible or _special_encounter_item != "" or _special_encounter_diver != null or tutorial_result_popup.visible:
		return false
	if Whirlpool.busy_in(self) or divers.any(func(d: Diver) -> bool: return d.is_grappling() or d.is_suction_locked()):
		return false
	# The menu requesting this save is allowed. The other area's puzzle and
	# reward state must still be stable, even though its shared actors live here.
	return embedded_maze == null or (not embedded_maze.maze_active and embedded_maze.can_capture_campaign_snapshot())

func _on_save_requested(_d: Diver, slot: int) -> void:
	if _checkpoint_saving or _autosave_writing:
		return
	if slot < 0 or not _manual_save_safe():
		save_point_menu.close()
		_announce("Wait for the movement or encounter to finish, then save.")
		return
	for other in divers:
		var s: CombatantStats = (other as Diver).stats
		s.hp = s.hp_max
		s.oxygen = s.oxygen_max
	_update_hp_bar()
	_update_oxygen_bar()
	# A save-point save can target any slot from the title screen's slot
	# list. Make the chosen slot this run's active checkpoint too, so future
	# save-point visits and "Restart from Save Point" continue from the same
	# destination rather than silently returning to the slot New Game chose.
	var existed := SaveManager.slot_exists(slot)
	var previous := FileAccess.get_file_as_bytes(SaveManager.slot_path(slot)) if existed else PackedByteArray()
	_checkpoint_saving = true
	save_point_menu.set_saving(true, slot)
	_refresh_world_reading()
	var save_error := SaveManager.write_slot(slot, _serialize_state())
	var written := save_error == OK
	if written:
		save_error = await BrowserCheckpoint.confirm_slot(slot)
	if save_error != OK and written:
		if SaveManager.rollback_slot(slot, existed, previous) != OK:
			save_point_menu.set_saving(false)
			_checkpoint_saving = false
			save_point_menu.close()
			_announce("Saving failed and recovery could not be confirmed. Please retry before leaving.")
			return
	save_point_menu.set_saving(false)
	_checkpoint_saving = false
	_refresh_world_reading()
	if save_error != OK:
		_announce("Could not save. Your previous checkpoint is unchanged. Please retry.")
		save_point_menu.close()
		return
	_current_slot = slot
	_announce("Progress saved to Slot %d." % (slot + 1))
	save_point_menu.close()

# Shows the save prompt while standing on a save point with the menu
# closed, clears it the moment either stops being true. Tracked separately
# from _announce()'s normal fade (_banner_timer stays 0 here) so the
# prompt persists exactly as long as you're standing there, not for a
# fixed few seconds - but that also means it only ever clears its own
# text, never a real announcement's, via _showing_save_prompt.
func _update_save_point_prompt() -> void:
	var on_point := _diver_on_save_point(divers[active]) and route_state.prologue_complete
	if on_point and not _save_point_contact_active:
		_save_point_contact_active = true
		_restore_party_at_save_point()
	elif not on_point:
		_save_point_contact_active = false

	if save_point_menu.visible:
		if _showing_save_prompt:
			banner.text = ""
			_showing_save_prompt = false
		return
	if on_point and not _showing_save_prompt and _announcements.current_text().is_empty():
		if not _save_point_tutorial_seen:
			_save_point_tutorial_seen = true
			var pages: Array[Dictionary] = [{
				"title": "Save Points",
				"body": "At Save Points you can write/overwrite your game progress to one of three save slots. Save points also revive any downed party members and fully replenish the party's health/O2 bars.",
				"slot": null,
			}]
			(get_node("/root/CharacterAbilityPopup") as Node).call("open", pages)
		banner.text = "Save - Press P"
		_banner_timer = 0.0
		_showing_save_prompt = true
	elif not on_point and _showing_save_prompt:
		banner.text = ""
		_showing_save_prompt = false

func _restore_party_at_save_point() -> void:
	escape_encounter_hint.dismiss()
	for other in divers:
		var s: CombatantStats = (other as Diver).stats
		s.hp = s.hp_max
		s.oxygen = s.oxygen_max
	_update_hp_bar()
	_update_oxygen_bar()

func _fire_aimed_ability() -> void:
	var d: Diver = divers[active]
	aiming = false
	d.use_ability(_aim_dir())
	d.set_model_visible(true)
	_update_hud()

func _cancel_aim() -> void:
	aiming = false
	divers[active].set_model_visible(true)
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
	_tick_autosave(dt)
	# Run before combat/maze early returns so the old world waypoint cannot
	# remain visible after another owner takes control of this frame.
	_update_blockade_arrow()
	if embedded_maze != null and embedded_maze.maze_active:
		active = embedded_maze.active
		if not embedded_maze._battling:
			for diver in divers:
				diver.exploration_paused = not embedded_maze.contains_point(diver.global_position)
		if not embedded_maze.contains_point((divers[active] as Diver).global_position) and embedded_maze.prepare_area_exit():
			_set_maze_ownership(false)
		# The Maze owns this frame even on departure: never swim twice.
		return
	if battling or is_instance_valid(random_encounter_reveal) or inventory_menu.visible or save_point_menu.visible or _checkpoint_saving:
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
		if embedded_maze != null and embedded_maze.contains_point(d.global_position):
			# Parked actors cannot drift or spend Oxygen in an inactive area.
			d.exploration_paused = true
			continue
		d.exploration_paused = false
		# Movement pauses for the active diver while picking a swap target
		# too - the camera's busy showing an ally, swimming around blind
		# to where your own diver actually is would be confusing controls.
		# Also pauses for the brief _start_first_encounter() tween onto the
		# light beam's center - swim()'s own move_and_slide() running the
		# same frame as a Tween driving global_position directly would fight
		# it for the diver's actual position.
		if i == active and not target_selector.selecting and not _transitioning_to_encounter:
			d.swim(_player_dir(), _player_rise(), dt)
			# The distance roll can pause the tree inside swim(). Do not continue
			# this already-running frame and move the camera or trigger a second
			# route encounter after the preview has measured its placement.
			if is_instance_valid(random_encounter_reveal):
				return
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
	if not route_state.prologue_complete:
		_update_prologue_trigger(dt)
		return
	_try_trigger_item_site(divers[active] as Diver)
	_update_save_point_prompt()
	_check_gap_puzzle()
	_update_wall_visibility()
	_update_intro_sequence()
	_update_route_zone()
	_refresh_world_guidance()
	_update_deep_zone_visuals()
	_update_deep_zone_blockers()
	_update_lab_route()
	_update_maze_transition()

func _update_route_zone() -> void:
	if not route_state.prologue_complete or divers.is_empty():
		return
	var physical_zone: String = deep_zone_layout.zone_for_position((divers[active] as Diver).global_position)
	if physical_zone == route_state.zone_id:
		return
	route_state.set_zone(physical_zone)
	if physical_zone == "deep":
		# Independent branch: the maze transition is available on entering Deep
		# even while the two lab blockers and Tethys remain untouched.
		if route_state.maze_door_state == "locked":
			route_state.set_maze_door_state("available")
		if route_state.lab_state != "cleared" and route_state.tethys_state != "defeated":
			route_state.set_objective("find_lab")
		if not route_state.deep_warning_seen:
			route_state.mark_deep_warning_seen()
			_announce("You've entered deeper water. Stronger enemies may appear.")

# Marc's review described Deep as a water-color gradient around the laboratory,
# not a binary floor swap. Grade the actual world environment from the active
# diver's physical x-position so every route through the region gets the same
# continuous treatment. The battle viewport owns its own environment and is
# intentionally unaffected.
func _update_deep_zone_visuals() -> void:
	if divers.is_empty():
		return
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return
	var factor := deep_zone_layout.depth_factor_for_position((divers[active] as Diver).global_position)
	var environment := world_environment.environment
	environment.background_color = Color(0.04, 0.12, 0.16).lerp(Color(0.012, 0.035, 0.06), factor)
	environment.fog_light_color = Color(0.05, 0.16, 0.2).lerp(Color(0.015, 0.055, 0.085), factor)
	environment.fog_density = lerpf(0.035, 0.065, factor)
	environment.ambient_light_color = Color(0.32, 0.5, 0.56).lerp(Color(0.18, 0.3, 0.4), factor)
	environment.ambient_light_energy = lerpf(1.1, 0.82, factor)

# Checks the live diver's physical position, not a query-string route or a
# test-only teleport. Sword Slayer joins this same table after its actor slice;
# keeping Bomb Bot alone here prevents an unimplemented id falling back to an
# Angler if a player swims ahead during this commit.
func _update_deep_zone_blockers() -> void:
	if battling or divers.is_empty() or not route_state.prologue_complete:
		return
	var diver := divers[active] as Diver
	var points: Dictionary = deep_zone_layout.route_points()
	if _inside_route_blocker_id != "":
		var inside_point := points[_inside_route_blocker_id] as Vector3
		if not _inside_route_blocker_volume(diver.global_position, inside_point, true):
			_inside_route_blocker_id = ""
		else:
			return
	for blocker_id in ["bomb_bot", "sword_slayer"]:
		if blocker_id == "sword_slayer" and route_state.bomb_bot_state != "defeated":
			continue
		var state := route_state.bomb_bot_state if blocker_id == "bomb_bot" else route_state.sword_slayer_state
		if not ["available", "in_progress"].has(state):
			continue
		var point := points[blocker_id] as Vector3
		if _inside_route_blocker_volume(diver.global_position, point):
			_inside_route_blocker_id = blocker_id
			_start_deep_zone_blocker(blocker_id)
			return

func _inside_route_blocker_volume(position: Vector3, point: Vector3, exit_volume: bool = false) -> bool:
	var x_radius := ROUTE_BLOCKER_EXIT_RADIUS if exit_volume else ROUTE_BLOCKER_TRIGGER_RADIUS
	var z_radius := ROUTE_BLOCKER_EXIT_HALF_WIDTH if exit_volume else ROUTE_BLOCKER_TRIGGER_HALF_WIDTH
	return absf(position.x - point.x) <= x_radius and absf(position.z - point.z) <= z_radius

func _start_deep_zone_blocker(blocker_id: String) -> void:
	if battling or not ["bomb_bot", "sword_slayer"].has(blocker_id):
		return
	if blocker_id == "sword_slayer" and route_state.bomb_bot_state != "defeated":
		return
	var state := route_state.bomb_bot_state if blocker_id == "bomb_bot" else route_state.sword_slayer_state
	if not ["available", "in_progress"].has(state):
		return
	_active_route_blocker_id = blocker_id
	route_state.set_blocker_state(blocker_id, "in_progress")
	route_state.set_encounter_source("lab_blocker")
	_sync_deep_zone_blocker_staging()
	var intro := "Bomb Bot seals the laboratory approach." if blocker_id == "bomb_bot" else "Sword Slayer guards the laboratory entrance."
	_start_battle("", false, blocker_id, [], false, false, intro, true)

func _resolve_deep_zone_blocker(blocker_id: String, result: String) -> void:
	if result == "won":
		route_state.set_blocker_state(blocker_id, "defeated")
		if blocker_id == "bomb_bot":
			route_state.set_objective("find_lab")
		elif blocker_id == "sword_slayer":
			route_state.set_lab_state("available")
			route_state.set_objective("find_lab")
	else:
		route_state.set_blocker_state(blocker_id, "available")
	route_state.set_encounter_source("random")
	_active_route_blocker_id = ""
	_sync_deep_zone_blocker_staging()
	if result == "won":
		_write_save()

# LAB-TETHYS-001/010: the physical unlocked door is the one production entry
# point. A state latch is more reliable than a one-frame Area signal and makes
# remaining inside the radius harmless after the cutscene has started.
func _update_lab_route() -> void:
	if battling or divers.is_empty() or not route_state.prologue_complete:
		return
	if route_state.lab_state != "available":
		return
	if route_state.bomb_bot_state != "defeated" or route_state.sword_slayer_state != "defeated":
		return
	var lab_point := deep_zone_layout.route_points().lab as Vector3
	var position := (divers[active] as Diver).global_position
	if Vector2(position.x, position.z).distance_to(Vector2(lab_point.x, lab_point.z)) <= LAB_TRIGGER_RADIUS:
		_start_lab_cutscene()

func _start_lab_cutscene() -> void:
	if route_state.lab_state != "available" or is_instance_valid(_lab_video_cutscene):
		return
	route_state.set_lab_state("cutscene")
	route_state.set_tethys_state("available")
	route_state.set_encounter_source("lab_boss")
	route_state.set_objective("defeat_tethys")
	_sync_lab_staging()
	_audio_call(&"stop_music")
	$HUD.visible = false
	_lab_video_cutscene = LabVideoCutsceneScript.new()
	_lab_video_cutscene.completed.connect(_on_lab_cutscene_completed)
	add_child(_lab_video_cutscene)

func _on_lab_cutscene_completed(_skipped: bool) -> void:
	if route_state.lab_state != "cutscene" or battling:
		return
	_lab_video_cutscene = null
	$HUD.visible = true
	route_state.set_lab_state("boss")
	route_state.set_tethys_state("in_progress")
	route_state.set_encounter_source("lab_boss")
	_sync_lab_staging()
	_start_battle("", true)

func _sync_lab_staging() -> void:
	if is_instance_valid(deep_zone_environment):
		deep_zone_environment.set_lab_phase(route_state.lab_state)

# Independent world-to-maze branch. Lab victory is not a prerequisite.
func _update_maze_transition() -> void:
	if embedded_maze == null or battling or divers.is_empty() or not route_state.prologue_complete:
		return
	if embedded_maze.contains_point((divers[active] as Diver).global_position):
		_maze_entry_source = "deep_landmark"
		_set_maze_ownership(true)

func _enter_maze_scene(review_route: bool = false) -> void:
	if embedded_maze == null:
		return
	if review_route:
		title_screen.close()
		get_tree().paused = false
		for i in range(divers.size()):
			(divers[i] as Diver).global_position = embedded_maze.entrance_point() + Vector3(0, 2, (i - active) * 2.0)
		_set_maze_ownership(true)
	else:
		_update_maze_transition()

func _set_maze_ownership(on: bool, restored := false) -> void:
	if on:
		_campaign_session.selected_slot = _current_slot
		if aiming:
			_cancel_aim()
		if target_selector.selecting:
			target_selector.cancel_selection()
		if restored:
			embedded_maze.set_maze_active(true)
		else:
			embedded_maze.enter_from_world()
		route_state.set_zone("maze")
		route_state.set_maze_door_state("entered")
		route_state.set_encounter_source("maze_door")
		cam.current = false
	else:
		embedded_maze.leave_to_world()
		cam.current = true
		route_state.set_zone("deep")
		route_state.set_maze_door_state("available")
	$HUD.visible = not on
	$HUD.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	_active_cursor.visible = false if on else _active_cursor.visible
	Whirlpool.refresh_in(self)

func _build_embedded_maze() -> void:
	_campaign_session = CampaignSession.new()
	_campaign_session.capture_party(divers, active)
	_campaign_session.inventory = inventory
	_campaign_session.campaign_key_items = key_items
	_campaign_session.route_state = route_state
	_campaign_session.outer_world_checkpoint = _serialize_world_state()
	embedded_maze = preload("res://game/maze_level.tscn").instantiate() as MazeLevel
	embedded_maze.name = "MazeLevel"
	embedded_maze.world = self
	embedded_maze.coordinate_origin = DeepZoneLayoutScript.MAZE_ORIGIN
	embedded_maze.campaign_session = _campaign_session
	embedded_maze.campaign_completed.connect(_show_campaign_completion)
	add_child(embedded_maze)
	_build_lab_maze_ramp()

func _build_lab_maze_ramp() -> void:
	var start := Vector3(DeepZoneLayoutScript.WORLD_MAX_X, 0, DeepZoneLayoutScript.MAZE_TRANSITION.z)
	var finish := Vector3(embedded_maze.embedded_bounds.position.x, embedded_maze._floor_top_y, start.z)
	var span := finish - start
	var root := Node3D.new()
	root.name = "LabMazeRamp"
	add_child(root)
	# Match collision and visible slab. The top face joins both existing floors;
	# rotating a flat box instead of stacking steps keeps the return traversable.
	var slope := atan2(span.y, span.x)
	var floor := CSGBox3D.new()
	floor.name = "RampFloor"
	floor.size = Vector3(span.length() + 0.1, 0.4, DeepZoneLayoutScript.MAZE_APPROACH_HALF_WIDTH * 2.0)
	floor.rotation.z = slope
	floor.position = (start + finish) * 0.5 - floor.basis.y * 0.2
	floor.use_collision = true
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.27, 0.31)
	floor.material = material
	root.add_child(floor)
	# Tall side collision closes the gap between the two enclosing perimeters.
	for side in [-1.0, 1.0]:
		var rail := CSGBox3D.new()
		rail.size = Vector3(span.x + 8.0, 8.0, 0.5)
		rail.position = Vector3((start.x + finish.x) * 0.5, 3.0, start.z + side * (DeepZoneLayoutScript.MAZE_APPROACH_HALF_WIDTH + 0.25))
		rail.material = material
		rail.use_collision = true
		root.add_child(rail)
		var edge := CSGBox3D.new()
		edge.size = Vector3(0.12, 2.5, 0.12)
		edge.position = Vector3(start.x + 1.0, 1.8, start.z + side * 3.6)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("65b9df")
		glow.emission_enabled = true
		glow.emission = Color("65b9df")
		glow.emission_energy_multiplier = 2.0
		edge.material = glow
		root.add_child(edge)
		var light := OmniLight3D.new()
		light.position = edge.position
		light.light_color = Color("65b9df")
		light.light_energy = 1.4
		light.omni_range = 12.0
		root.add_child(light)
		_build_invisible_wall(Vector3(rail.position.x, 30.0, rail.position.z), Vector3(rail.size.x, 80.0, rail.size.z))
	# Preserve Marc's ceiling plug: no swimming over the maze ceiling into a
	# sealed interior. Its lower ceiling has a visible face.
	var reference := embedded_maze.get_node("CurrentWall1") as CSGBox3D
	var ceiling := reference.position.y + reference.size.y * 0.5 + embedded_maze._CEILING_CLEARANCE
	_build_invisible_wall(Vector3((start.x + finish.x) * 0.5, (ceiling + 80.0) * 0.5, start.z), Vector3(span.x + 8.0, 80.0 - ceiling, DeepZoneLayoutScript.MAZE_APPROACH_HALF_WIDTH * 2.0))
	var roof := CSGBox3D.new()
	roof.name = "RampCeiling"
	roof.size = Vector3(span.x + 8.0, 0.3, DeepZoneLayoutScript.MAZE_APPROACH_HALF_WIDTH * 2.0)
	roof.position = Vector3((start.x + finish.x) * 0.5, ceiling + 0.15, start.z)
	roof.material = material
	root.add_child(roof)
	var label := Label3D.new()
	label.text = "MAZE"
	label.position = Vector3(start.x - 7.0, 6.0, start.z)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 80
	label.outline_size = 8
	label.pixel_size = 0.008
	root.add_child(label)

func _build_deep_zone_blocker_staging() -> void:
	var definitions := [
		{"id": "bomb_bot", "actor": BombBot.new()},
		{"id": "sword_slayer", "actor": SwordSlayer.new()},
	]
	var points: Dictionary = deep_zone_layout.route_points()
	for definition_value in definitions:
		var definition := definition_value as Dictionary
		var blocker_id := String(definition.id)
		var actor := definition.actor as Goblin
		actor.name = "%sWorldActor" % blocker_id.to_pascal_case()
		actor.add_to_group("deep_zone_blocker_staging")
		actor.set_meta("blocker_id", blocker_id)
		var point := points[blocker_id] as Vector3
		# These are visible guardians, not waypoint icons. Their source rigs use
		# large authored offsets, so a guessed Y value can put every rendered
		# mesh below the seafloor even while the actor node itself looks valid.
		# Place first, measure the real transformed meshes, then hover above the
		# floor and the approaching diver's silhouette.
		var presentation_scale := 1.5 if blocker_id == "bomb_bot" else 1.6
		# Stand on the player's side of the field, centered on its opening.
		# Imported roots are offset: center actual bounds after facing, not just
		# the Node3D, otherwise both guardians still look pushed to the left.
		actor.position = Vector3(point.x - 5.0, 0.0, point.z)
		actor.scale = Vector3.ONE * presentation_scale
		add_child(actor)
		actor.face_toward(Vector3(point.x - 10.0, 0.0, point.z))
		actor.force_update_transform()
		var actor_bounds := _route_actor_visible_bounds(actor)
		if actor_bounds.size.length() > 0.01:
			actor.position.x += point.x - 5.0 - actor_bounds.get_center().x
			actor.position.z += point.z - actor_bounds.get_center().z
			# Hover above the chase-camera diver's silhouette. Horizontal mesh
			# centering alone hid the entire guard behind the player on approach.
			actor.position.y += 5.0 - actor_bounds.position.y
			actor.force_update_transform()
		_route_blocker_world_actors[blocker_id] = actor
		_route_blocker_gates[blocker_id] = _build_route_blocker_gate(blocker_id, point)
	_sync_deep_zone_blocker_staging()

func _build_route_blocker_gate(blocker_id: String, point: Vector3) -> Dictionary:
	var body := StaticBody3D.new()
	body.name = "%sPressureField" % blocker_id.to_pascal_case()
	body.position = Vector3(point.x, 7.0, point.z)
	body.add_to_group("deep_zone_blocker_gate")
	body.set_meta("blocker_id", blocker_id)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 14.0, 20.0)
	collision.shape = shape
	body.add_child(collision)

	# A sparse energy grid and bright edge pylons make the collision legible
	# from both sides without tinting most of the screen. This is deliberately
	# a wall, not another ring or waypoint: the guardian identifies the fight;
	# the field explains why swimming around it is not possible.
	var color := Color("ff9b55") if blocker_id == "bomb_bot" else Color("a879ff")

	for z_offset in [-9.5, 9.5]:
		var pylon := MeshInstance3D.new()
		pylon.position = Vector3(0.0, -4.5, z_offset)
		var pylon_mesh := CylinderMesh.new()
		pylon_mesh.top_radius = 0.28
		pylon_mesh.bottom_radius = 0.52
		pylon_mesh.height = 5.0
		pylon_mesh.radial_segments = 8
		pylon.mesh = pylon_mesh
		var pylon_material := StandardMaterial3D.new()
		pylon_material.albedo_color = color.darkened(0.35)
		pylon_material.metallic = 0.45
		pylon_material.roughness = 0.28
		pylon_material.emission_enabled = true
		pylon_material.emission = color
		pylon_material.emission_energy_multiplier = 1.2
		pylon.material_override = pylon_material
		body.add_child(pylon)

	var field := MeshInstance3D.new()
	field.name = "EnergyField"
	field.rotation.y = PI * 0.5
	var field_mesh := QuadMesh.new()
	field_mesh.size = Vector2(19.0, 13.5)
	field_mesh.orientation = PlaneMesh.FACE_Z
	field.mesh = field_mesh
	var field_shader := Shader.new()
	field_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 field_color : source_color;

void fragment() {
	vec2 centered = abs(UV - vec2(0.5));
	float border = smoothstep(0.475, 0.5, max(centered.x, centered.y));
	vec2 cell = abs(fract(UV * vec2(9.0, 6.0)) - vec2(0.5));
	float grid_x = smoothstep(0.46, 0.495, cell.x);
	float grid_y = smoothstep(0.46, 0.495, cell.y);
	float grid = max(grid_x, grid_y);
	float scan = 1.0 - smoothstep(0.0, 0.035, abs(fract(UV.y - TIME * 0.11) - 0.5));
	float vertical_fade = smoothstep(0.0, 0.055, UV.y) * smoothstep(0.0, 0.055, 1.0 - UV.y);
	float shimmer = 0.5 + 0.5 * sin(TIME * 2.1 + UV.y * 18.0 + UV.x * 5.0);
	float alpha = (0.014 + grid * 0.12 + border * 0.48 + scan * 0.15 + shimmer * 0.012) * vertical_fade;
	ALBEDO = field_color.rgb;
	EMISSION = field_color.rgb * (0.35 + grid * 0.85 + border * 1.5 + scan * 1.1);
	ALPHA = alpha;
}
"""
	var field_material := ShaderMaterial.new()
	field_material.shader = field_shader
	field_material.set_shader_parameter("field_color", color)
	field.material_override = field_material
	body.add_child(field)

	add_child(body)
	return {"body": body, "collision": collision}

func _route_actor_visible_bounds(node: Node) -> AABB:
	var combined := AABB()
	var first := true
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.visible:
			combined = mesh.global_transform * mesh.get_aabb()
			first = false
	for child in node.get_children():
		var child_bounds := _route_actor_visible_bounds(child)
		if child_bounds.size.length() <= 0.01:
			continue
		combined = child_bounds if first else combined.merge(child_bounds)
		first = false
	return combined

func _sync_deep_zone_blocker_staging() -> void:
	if _route_blocker_world_actors.has("bomb_bot"):
		(_route_blocker_world_actors.bomb_bot as Node3D).visible = route_state.bomb_bot_state == "available"
	if _route_blocker_world_actors.has("sword_slayer"):
		(_route_blocker_world_actors.sword_slayer as Node3D).visible = route_state.sword_slayer_state == "available"
	for blocker_id in _route_blocker_gates:
		var gate := _route_blocker_gates[blocker_id] as Dictionary
		var state := route_state.bomb_bot_state if blocker_id == "bomb_bot" else route_state.sword_slayer_state
		var closed := state != "defeated"
		(gate.body as Node3D).visible = closed
		(gate.collision as CollisionShape3D).set_deferred("disabled", not closed)

# Runs every physics frame from world load until the active diver reaches
# the light beam: keeps the arrow aimed at it (the diver keeps moving, so a
# one-time look_at from intro_arrow() would go stale immediately) and hands
# off to _start_first_encounter() the moment they arrive. _intro_active
# itself stays true straight through that handoff (see _start_first_
# encounter()'s own comment) - TAB/random encounters/camera don't return to
# normal until the tutorial battle is actually about to start.
# Plain look_at(target, Vector3.UP) warns and produces a degenerate
# rotation whenever the arrow ends up directly above/below the target - and
# it does, right at game start: Maxilani's CAST position is (0, 2.0, 0),
# directly over the beam's own (0, *, 0) center. Falls back to a level
# vector as the up hint for just that one degenerate case; normal look_at
# resumes the instant the diver steps off that exact vertical line.
func _point_arrow_at(target_pos: Vector3) -> void:
	if not is_instance_valid(_intro_arrow):
		return
	var to_target := target_pos - _intro_arrow.global_position
	var up := Vector3.UP
	if absf(to_target.normalized().dot(Vector3.UP)) > 0.999:
		up = Vector3.FORWARD
	_intro_arrow.look_at(target_pos, up)

func _update_intro_sequence() -> void:
	if not route_state.prologue_complete or route_state.tutorial_complete or _first_encounter_started:
		return
	if not is_instance_valid(light_beam):
		_intro_active = false
		return
	_point_arrow_at(light_beam.global_position)
	var d: Diver = divers[active]
	# The beam is a vertical cylinder.  Its node sits halfway up its 12 m
	# height, so a full Vector3 distance would make the part a diver can
	# visibly swim through (near y=2) more than 2.5 m away from its origin.
	# Only x/z describe whether the diver entered the displayed column.
	var horizontal_distance := Vector2(d.global_position.x, d.global_position.z).distance_to(
		Vector2(light_beam.global_position.x, light_beam.global_position.z)
	)
	if horizontal_distance <= INTRO_ARRIVAL_DIST:
		if is_instance_valid(_intro_arrow):
			_intro_arrow.visible = false
		_start_first_encounter(d)

func _start_first_encounter(d: Diver) -> void:
	if _first_encounter_started:
		return
	_first_encounter_started = true
	light_beam.visible = false
	_transitioning_to_encounter = true
	Whirlpool.refresh_in(self)
	var target_pos := Vector3(light_beam.global_position.x, d.global_position.y, light_beam.global_position.z)
	var tw := create_tween()
	tw.tween_property(d, "global_position", target_pos, 0.5)
	await tw.finished
	_transitioning_to_encounter = false
	_intro_active = false
	_camera_look_override = null
	# All three divers now, not just the one that walked up - the tutorial
	# script itself demonstrates one scripted move each from all three (see
	# battle.gd's _TUTORIAL_SCRIPT), CAST's own order (Staff_Diver,
	# Prototype_1(1910), Prototype_V(1922)) is what makes divers[0]/[1]/[2]
	# resolve to Maxilani/Musashi/Mech Pilot there.
	_start_battle("", false, "angler", divers, false, true)

# A real Area3D, radius matched to minimap.view_radius - "revealed" and
# "currently fits on the minimap's own zoom circle" are the same distance
# by construction now, rather than two independently-tuned numbers (the
# old WALL_SIGHT_RADIUS was a separate constant that happened to be
# smaller than view_radius).
#
# MODIFIED: monitorable used to be explicitly set false (nothing else
# needs to detect THIS area itself, only monitoring - detecting the walls
# - seemed relevant) - empirically, in this Godot version, monitorable
# false also silently breaks get_overlapping_bodies() entirely, not just
# area-vs-area detection the way the docs describe. Confirmed directly: a
# body sitting well inside the sphere's radius stopped showing up in
# get_overlapping_bodies() the instant monitorable was set false, and
# came back the instant it wasn't. Left at its default (true) now - real,
# observed behavior wins over documented semantics here.
func _build_wall_sight_area() -> void:
	_wall_sight_area = Area3D.new()
	_wall_sight_area.monitoring = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = minimap.view_radius
	shape.shape = sphere
	_wall_sight_area.add_child(shape)
	add_child(_wall_sight_area)


# Follows the active diver every physics tick and reveals whichever
# WALL PIECES (not whole walls) actually overlap the detection area, for
# mini_map.gd's fog-of-war (_wall_pieces' own "revealed"/"line_a"/
# "line_b" fields).
#
# Two passes: get_overlapping_bodies() is the coarse first pass - a
# cheap read of the physics server's already-computed overlap list for
# this one persistent Area3D, telling us which WHOLE walls are even
# worth checking closely this tick, without having to test every single
# piece in the entire level every frame. Then, for only the pieces
# belonging to those nearby bodies, _piece_area_overlap() computes the
# actual overlapping RANGE (as two Vector3 endpoints, not just a yes/no)
# between that piece's own bounds and the detection area's bounds - a
# piece right next to the diver and a piece at the far end of the same
# long wall don't necessarily reveal together, and a piece only grazed at
# its very edge reveals only that grazed sliver, not its whole span.
#
# The overlap is computed once, the instant a piece is first found, and
# frozen into line_a/line_b from then on (piece.revealed gates this to a
# one-time write) - it does NOT keep recomputing every frame off the
# diver's current position. Redrawing from a live, continuously-
# recomputed overlap would make a previously-revealed stretch shrink or
# vanish the moment the diver moved away again, breaking the "seen
# doesn't un-happen" rule every other reveal system in this project
# already follows (World.revealed_key_items, maze_mini_map.gd's own fog).
# Freezing the vectors at first contact keeps that guarantee while still
# drawing the exact overlap geometry, not just the piece's full span.
func _update_wall_visibility() -> void:
	if divers.is_empty():
		return
	var diver_pos: Vector3 = (divers[active] as Diver).global_position
	_wall_sight_area.global_position = diver_pos

	var nearby_bodies: Dictionary = {}
	for body in _wall_sight_area.get_overlapping_bodies():
		if body is StaticBody3D and (body as StaticBody3D).is_in_group("Wall"):
			nearby_bodies[body] = true
	if nearby_bodies.is_empty():
		return

	var view_radius: float = minimap.view_radius
	var area_min := Vector2(diver_pos.x - view_radius, diver_pos.z - view_radius)
	var area_max := Vector2(diver_pos.x + view_radius, diver_pos.z + view_radius)
	for piece in _wall_pieces:
		if bool(piece.revealed) or not nearby_bodies.has(piece.body):
			continue
		var overlap := _piece_area_overlap(piece.a, piece.b, area_min, area_max)
		if overlap.is_empty():
			continue
		piece.revealed = true
		piece.line_a = overlap[0]
		piece.line_b = overlap[1]

# The overlapping RANGE between one wall piece's own bounding box and the
# detection area's bounding box, both measured as [min, max] Vector2
# bounds in the horizontal XZ plane - the difference between each box's
# own max and min gives the overlap on each axis (overlap_min/
# overlap_max below). Returns [] if that range is empty (min > max on
# either axis) - no overlap at all - otherwise [Vector3, Vector3]: the
# two actual world-space endpoints of the overlapping stretch, reusing
# piece a's own Y (walls don't vary in height along their own length).
#
# Since a piece is a LINE, not a filled box, one of the two axes always
# collapses to the piece's own fixed coordinate on that axis (e.g. a
# piece running along X has piece_min.y == piece_max.y == its one fixed
# Z value), so the returned points differ only along whichever axis the
# piece actually runs on - exactly the clipped sub-segment, not a
# degenerate box corner.
static func _piece_area_overlap(a: Vector3, b: Vector3, area_min: Vector2, area_max: Vector2) -> Array:
	var piece_min := Vector2(minf(a.x, b.x), minf(a.z, b.z))
	var piece_max := Vector2(maxf(a.x, b.x), maxf(a.z, b.z))
	var overlap_min := Vector2(maxf(piece_min.x, area_min.x), maxf(piece_min.y, area_min.y))
	var overlap_max := Vector2(minf(piece_max.x, area_max.x), minf(piece_max.y, area_max.y))
	if overlap_min.x > overlap_max.x or overlap_min.y > overlap_max.y:
		return []
	return [
		Vector3(overlap_min.x, a.y, overlap_min.y),
		Vector3(overlap_max.x, a.y, overlap_max.y),
	]

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
	# fwd matches the camera's actual look direction; right is fwd rotated
	# -90 around Y so it points to screen-right regardless of which way the
	# diver model currently happens to be facing. W/A/S/D always map to
	# camera-forward/left/back/right.
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	# MODIFIED: while _camera_look_override is set (the intro's light beam -
	# see _move_camera()'s own `orbit_dir`), the camera actually LOOKS at
	# that override, not wherever yaw points - fwd used to stay yaw-based
	# regardless, so W/A/S/D kept mapping to a direction the screen wasn't
	# actually showing as forward, which read as the controls having gone
	# inverted/scrambled for the length of the walk to the beam. Matching
	# _move_camera()'s own orbit_dir here (diver-to-beam, not yaw) keeps
	# "forward" meaning the same thing on screen as it does to the keys.
	if is_instance_valid(_camera_look_override) and active >= 0 and active < divers.size():
		var to_target: Vector3 = _camera_look_override.global_position - divers[active].global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			fwd = to_target.normalized()
	var right := Vector3(-fwd.z, 0, fwd.x)
	return (right * f.x - fwd * f.y).normalized()

func _player_rise() -> float:
	if scripted:
		return scripted_rise
	var r := 0.0
	if Input.is_key_pressed(KEY_SPACE):
		r += 1.0
	if Input.is_key_pressed(KEY_SHIFT):
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
	# MODIFIED: `dir` used to stay _aim_dir() (the diver's own movement/
	# facing direction) even while _camera_look_override was set, so the
	# camera sat wherever the diver's OWN heading put it and only swiveled
	# to look at the beam afterward - correct look_at, but positioned with
	# no regard for where the beam actually was, so the diver routinely
	# ended up off to one side of frame (or out of it) instead of staying
	# centered between the camera and the thing it's looking at. Orbiting
	# around the diver-to-beam direction instead keeps the camera on the
	# opposite side of the diver FROM the beam, so the shot reads as
	# "looking past the diver at the beam" the whole walk over, the same
	# framing intent _start_first_encounter()'s own header comment already
	# describes.
	var orbit_dir := dir
	if is_instance_valid(_camera_look_override):
		var to_target: Vector3 = _camera_look_override.global_position - focus
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			orbit_dir = to_target.normalized()
	var want: Vector3 = focus - orbit_dir * cam_dist
	want.y = maxf(want.y, 0.6)      # never bury the camera in the seabed
	cam.global_position = cam.global_position.lerp(want, clampf(dt * 8.0, 0.0, 1.0))
	var look_at_point := focus
	if is_instance_valid(_camera_look_override):
		look_at_point = _camera_look_override.global_position
	cam.look_at(look_at_point, Vector3.UP)

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

# A vertical shaft of light (e.g. sunlight through the water). The
# shimmer/pulse/height-fade all vary per-pixel along the beam's length, which
# only the GPU can do - so that math lives in the shader's fragment(), driven
# by the shader's own TIME (free-running, no GDScript upkeep) and v_y (the
# vertex's normalized height, computed once per vertex and handed to
# fragment() via a varying). GDScript's job is just: build the mesh, write
# the shader, wire up the material, and add one node to the tree.
var light_beam: MeshInstance3D

func render_light_beam() -> void:
	if light_beam != null:
		return

	var shimmer_speed := 1.5
	var pulse_speed := 1.5
	var brightness := 1.5
	# MODIFIED: 6.0 -> 12.0, radii doubled below too - too small/thin to
	# read as a landmark from across the dive site, the whole reason the
	# intro walks the player toward it in the first place.
	var beam_height := 12.0

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 beam_color : source_color = vec4(0.3, 0.6, 0.9, 0.3);
uniform float shimmer_speed = 1.5;
uniform float pulse_speed = 1.5;
uniform float brightness = 1.5;
uniform float beam_height = 6.0;

varying float v_y;

void vertex() {
	// CylinderMesh is centered on local Y, spanning -height/2..height/2 -
	// remap that to 0 (base) .. 1 (tip) so fragment() has a clean 0-1 height.
	v_y = (VERTEX.y + beam_height * 0.5) / beam_height;
}

void fragment() {
	float wave_1 = sin(v_y + 16.0 - TIME * shimmer_speed);
	float wave_2 = sin(v_y + 31.0 - TIME * shimmer_speed);
	float wave_3 = sin(v_y + 48.0 - TIME * shimmer_speed);
	float shimmer = (wave_1 * 0.5 + wave_2 * 0.3 + wave_3 * 0.2) * 0.25;

	float pulse = 0.8 + sin(TIME * pulse_speed) * 0.2;
	float vertical_fade = 1.0 - v_y; // brightest at the base, dims toward the tip
	float glow = vertical_fade * (0.65 + shimmer) * pulse;

	ALBEDO = beam_color.rgb;
	ALPHA = beam_color.a * glow;
	EMISSION = beam_color.rgb * glow * brightness;
}
"""

	var mesh := CylinderMesh.new()
	mesh.height = beam_height
	mesh.top_radius = 0.8
	mesh.bottom_radius = 1.2

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("shimmer_speed", shimmer_speed)
	material.set_shader_parameter("pulse_speed", pulse_speed)
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("beam_height", beam_height)

	light_beam = MeshInstance3D.new()
	light_beam.mesh = mesh
	light_beam.material_override = material
	# World center, base resting on the seafloor (y=0 - see _build_site()),
	# rising straight up: CylinderMesh is centered on its own local origin,
	# so lifting it by half its height puts the base exactly at y=0.
	var d: Diver = divers[active]
	# This runs during World._ready(), while its new Diver children may not
	# yet be inside the scene tree. Their local position is already valid;
	# querying global_position here emits an engine error in headless checks.
	# Keep the first visible objective on the default W/forward swim axis. The
	# prior lateral x+10 placement made an ordinary forward input miss the beam
	# entirely, which PR #88 fixed and later branches accidentally dropped.
	light_beam.position = d.position + Vector3(0.0, beam_height * 0.5, 10.0)
	add_child(light_beam)

# Ordinary guarded-item locations retain their grapple targets without a
# visible ring. Special encounter sites have no item-location grapple target.
func _build_item_grapple_anchors() -> void:
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		if bool(entry.get("special", false)):
			continue
		var anchor := GrappleAnchor.new()
		anchor.show_ring = false
		anchor.target_radius = 1.8
		anchor.target_height = 3.2
		anchor.position = entry.at as Vector3
		add_child(anchor)

# A one-shot marker that points at the light beam (render_light_beam()) from
# just in front of the active diver. Parented to the diver at a small local
# offset (forward along her own -Z, per diver.gd's rest-facing convention -
# see the battle stage's own "backs to camera" comment for the same fact
# used the other way - plus a little lift toward head height) rather than
# anywhere in world space, so it moves and turns with her as she swims
# without any extra tracking code of its own.
# MODIFIED: this local offset used to be (10, height + 0.6, 0) - that 10
# was meant for render_light_beam()'s OWN world-space nudge a few lines up
# and never belonged here at all. Parented to the diver with a full 10
# units of local X, it swung in a wide circle around her head every time
# she turned, instead of sitting still in front of her.
# Its own ROTATION is a separate matter from this position: _point_arrow_
# at() re-aims it at the beam's global position every frame regardless of
# the diver's current facing (look_at() computes whatever local rotation
# achieves that global aim, parent rotation and all), so turning to swim
# sideways moves the arrow's spot (still in front of her) without ever
# throwing off which way it's pointing. No billboard here - unlike a
# label, this mesh's whole job is to visibly point in a real 3D direction,
# which billboarding would just override with "face the camera."
func intro_arrow() -> void:
	if _intro_arrow != null or light_beam == null:
		return
	var d: Diver = divers[active]
	_intro_arrow = _make_waypoint_arrow()
	_intro_arrow.position = Vector3(0, d.height * 0.6, -1.0)
	d.add_child(_intro_arrow)
	_point_arrow_at(light_beam.global_position)

func _make_waypoint_arrow() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Tip along local -Z (the axis look_at() aims at a target) with the base
	# behind it, so orienting this mesh via look_at makes the tip visibly
	# point at whatever it's aimed at.
	st.add_vertex(Vector3(0, 0, -1))
	st.add_vertex(Vector3(-0.5, 0, 0.6))
	st.add_vertex(Vector3(0.5, 0, 0.6))

	var material := StandardMaterial3D.new()
	material.albedo_color = Color.LIGHT_BLUE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(material)

	var arrow := MeshInstance3D.new()
	arrow.mesh = st.commit()
	arrow.scale = Vector3.ONE * 0.6
	return arrow

# Marc's post-tutorial waypoint, adapted to the campaign's completed prologue:
# optional training must not become a prerequisite for finding the blockade.
# Physical target existence (including loaded consumed geometry) owns cleanup.
func _update_blockade_arrow() -> void:
	var wall := _cracked_walls.get("entrance_blockade") as Node3D
	if not is_instance_valid(wall) or wall.is_queued_for_deletion():
		if is_instance_valid(_blockade_arrow):
			_blockade_arrow.queue_free()
		_blockade_arrow = null
		return
	var available := route_state.prologue_complete and route_state.prologue_phase == "complete" and not divers.is_empty()
	var blocked := battling or is_instance_valid(random_encounter_reveal) or _transitioning_to_encounter or aiming
	blocked = blocked or (embedded_maze != null and embedded_maze.maze_active)
	blocked = blocked or not $HUD.visible or title_screen.visible or game_over_screen.visible
	blocked = blocked or inventory_menu.visible or save_point_menu.visible or target_selector.selecting
	if not available or blocked:
		if is_instance_valid(_blockade_arrow):
			_blockade_arrow.visible = false
		return
	var d := divers[active] as Diver
	if not is_instance_valid(_blockade_arrow):
		_blockade_arrow = _make_waypoint_arrow()
		_blockade_arrow.name = "BlockadeWaypoint"
	if _blockade_arrow.get_parent() != d:
		if _blockade_arrow.get_parent() != null:
			_blockade_arrow.get_parent().remove_child(_blockade_arrow)
		d.add_child(_blockade_arrow)
	_blockade_arrow.position = Vector3(0, d.height * 0.6, -1.0)
	var near := Vector2(d.global_position.x, d.global_position.z).distance_to(Vector2(wall.global_position.x, wall.global_position.z)) <= BLOCKADE_ARROW_HIDE_DIST
	_blockade_arrow.visible = not near
	if _blockade_arrow.visible:
		var to_target := wall.global_position - _blockade_arrow.global_position
		var up := Vector3.FORWARD if absf(to_target.normalized().dot(Vector3.UP)) > 0.999 else Vector3.UP
		_blockade_arrow.look_at(wall.global_position, up)


# Pairs with intro_arrow() - called at the same moment (world _ready()) so
# the hint text and the waypoint arrow appear together. Goes through the
# shared banner (bottom-center, see _ready()) rather than its own label,
# same as every other on-screen message.
func _show_intro_text() -> void:
	_intro_announce("Swim over to the light beam.")


# Where the camera is actually looking, from yaw/pitch (mouse-look or
# arrow keys) - matches _player_dir()'s horizontal forward when pitch is 0.
# Shared by the camera itself and by aimed abilities (grapple), so "what
# you're looking at" and "what you're aiming at" are always the same thing.
func _aim_dir() -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))

var _aim_marker: MeshInstance3D
var _aim_marker_mat: StandardMaterial3D

# The reticle is a world-space torus. At its authored size it reads well on a
# distant Grapple target, but a ray that immediately hits a corridor wall can
# put that same 64 cm marker only centimetres from the first-person camera and
# turn it into a screen-filling gray polygon. Keep its apparent angular size
# bounded near surfaces while preserving the full authored size on route-scale
# targets. The small non-zero floor also keeps a close miss visible as feedback.
func _aim_marker_scale_for_distance(distance: float) -> float:
	return clampf(distance / 3.0, 0.04, 1.0)

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
	query.collision_mask = Diver.GRAPPLE_COLLISION_MASK
	var result := space.intersect_ray(query)

	var point: Vector3 = to if result.is_empty() else (result.position as Vector3)
	var on_target: bool = not result.is_empty() and (result.collider as Node).is_in_group("grapple_anchor")

	_aim_marker.visible = true
	_aim_marker.global_position = point
	_aim_marker.scale = Vector3.ONE * _aim_marker_scale_for_distance(from.distance_to(point))
	_aim_marker.look_at(from, Vector3.UP)
	var c: Color = Color(0.35, 0.95, 0.4) if on_target else Color(0.75, 0.78, 0.8)
	_aim_marker_mat.albedo_color = c
	_aim_marker_mat.emission = c
	_aim_marker_mat.emission_energy_multiplier = 1.6 if on_target else 0.7

# fade the banner. Only called while not battling: _physics_process skips
# this whole side of the world once a fight is up.
func _update_banner(dt: float) -> void:
	if _announcements.current_text().is_empty():
		return # Held intro/save-point prompts are not transient announcements.
	# SavePointMenu does not pause the tree, unlike a lesson; neither reading
	# menu may consume the exploration banner's allotted time underneath it.
	if $HUD.visible and not save_point_menu.visible and not inventory_menu.visible:
		_announcements.advance(dt)
	_banner_timer = _announcements.seconds_left()
	banner.text = _announcements.current_text()

# Entering a guarded item's site starts its encounter directly; Sonar and
# random-encounter rolls are not prerequisites, but the R encounter toggle
# still gates it. Only the active diver can trigger one. A per-site latch
# prevents reopening a prompt or battle while the diver remains inside the
# same radius; leaving and re-entering can trigger a repeatable special
# reward site again.
func _try_trigger_item_site(d: Diver) -> bool:
	if not route_state.prologue_complete or d != divers[active] or battling or _intro_active or _transitioning_to_encounter:
		return false
	var found: Dictionary = {}
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		var radius := float(entry.get("radius", 0.0))
		if radius > 0.0 and d.position.distance_to(entry.at as Vector3) <= radius:
			found = entry
			break
	if found.is_empty():
		_inside_item_site_id = ""
		return false
	if not random_encounters_enabled:
		# Clear the latch while encounters are off, so switching them back on
		# while still inside this radius can trigger the site immediately.
		_inside_item_site_id = ""
		return true
	var item_id := String(found.item)
	var site_id := String(found.get("site", item_id))
	if site_id == _inside_item_site_id:
		return true
	_inside_item_site_id = site_id
	if key_items.has(item_id):
		return false
	var enemy_id := String(found.get("enemy", "angler"))
	if bool(found.get("special", false)):
		_pending_guardian_enemy_id = enemy_id
		_offer_special_encounter(item_id)
	else:
		_start_battle(item_id, false, enemy_id)
	return true

# A Diver's distance-based roll still controls ordinary encounters outside
# guarded item sites. Site proximity is checked independently in
# _physics_process() and here, since a movement roll may land on the same
# frame the active diver crosses a site boundary.
func _on_encounter_triggered(d: Diver) -> void:
	if embedded_maze != null and embedded_maze.maze_active:
		return
	if not route_state.prologue_complete or battling or _transitioning_to_encounter or d != divers[active] or _intro_active or not random_encounters_enabled:
		return
	if _try_trigger_item_site(d):
		return
	if deep_zone_layout.zone_for_position(d.global_position) == "deep" and not deep_zone_layout.allows_random_encounter(d.global_position):
		return
	_begin_random_encounter_reveal()

func _begin_random_encounter_reveal() -> void:
	var selected := Battle.select_ordinary_enemies((divers[0] as Diver).stats.level)
	_transitioning_to_encounter = true
	Whirlpool.refresh_in(self)
	if aiming:
		_cancel_aim()
	if target_selector.selecting:
		target_selector.cancel_selection()
	random_encounter_reveal = RandomEncounterReveal.new()
	var reveal := random_encounter_reveal
	reveal.enemy_ids = selected
	reveal.camera = cam
	# Freeze world physics/status timers, not just movement input. Preview
	# animations run ALWAYS; no HP/O2, preference or checkpoint is modified.
	get_tree().paused = true
	reveal.finished.connect(func() -> void:
		if random_encounter_reveal != reveal:
			return
		_cancel_random_encounter_reveal()
		route_state.set_encounter_source("random")
		_start_battle("", false, "angler", [], false, false, "", false, selected)
		print("RANDOM_COMBAT|enemies=", ",".join(selected))
	, CONNECT_ONE_SHOT)
	add_child(reveal)

func _cancel_random_encounter_reveal() -> void:
	if not is_instance_valid(random_encounter_reveal):
		return
	random_encounter_reveal.set_process(false)
	random_encounter_reveal.restore_camera()
	random_encounter_reveal.queue_free()
	random_encounter_reveal = null
	_transitioning_to_encounter = false
	get_tree().paused = false

# Skips the Enter/Not Now prompt and drops the player straight into the
# minigame as Maxilani, narrated by battle.gd's own _first_fight_prompt()
# ("Welcome to your first special encounter!..."), same "show, don't ask
# permission" idea the combat tutorial's own first fight already uses.
# MODIFIED (fixed): this never actually flipped back to false, so every
# special encounter for the rest of the game skipped the real prompt and
# forced Maxilani - now cleared the first time this path actually runs.
var player_first_special_encounter := true
func _offer_special_encounter(item_id: String) -> void:
	_special_encounter_item = item_id
	if not player_first_special_encounter:
		get_tree().paused = true
		special_encounter_prompt.open()
	else:
		player_first_special_encounter = false
		# MODIFIED (fixed): custom_party takes actual Diver nodes
		# (_build_party() does `d as Diver` on each entry) - the literal
		# string "Maxilani" here crashed that cast the instant this path
		# ever actually ran. divers[0] is Maxilani/Staff_Diver by CAST's
		# own fixed order (see CAST above), same convention _show_ability_
		# popups() and others already rely on.
		var maxilani: Diver = divers[0]
		# MODIFIED (added): this is the exact crash battle.gd's _build_stage()
		# hits if she's downed - it never gives a hp<=0 party member an
		# "actor" at all, and this fight forces her in solo regardless of
		# whether some earlier ordinary battle left her at 0 HP. The
		# tutorial win-heal a few screens over (_on_battle_finished()) covers
		# her coming OUT of this fight downed; this covers going INTO it
		# already downed, since nothing else guarantees she's alive by the
		# time a player wanders into the first special-encounter site.
		if maxilani.stats.hp <= 0:
			maxilani.stats.hp = maxilani.stats.hp_max
			maxilani.stats.oxygen = maxilani.stats.oxygen_max
			_update_hp_bar()
			_update_oxygen_bar()
		_start_battle(item_id, false, _pending_guardian_enemy_id, [maxilani], true, true)

func _on_special_encounter_diver_chosen(model_name: String) -> void:
	special_encounter_prompt.close()
	get_tree().paused = false
	var chosen: Diver = null
	for diver in divers:
		if (diver as Diver).model_name == model_name:
			chosen = diver as Diver
			break
	if chosen == null:
		_on_special_encounter_cancelled()
		return
	_special_encounter_diver = chosen
	_special_encounter_pre_hp = chosen.stats.hp
	_special_encounter_pre_oxygen = chosen.stats.oxygen
	_start_battle(_special_encounter_item, false, _pending_guardian_enemy_id, [chosen], true)

func _on_special_encounter_cancelled() -> void:
	special_encounter_prompt.close()
	get_tree().paused = false
	_special_encounter_item = ""
	if _special_playtest_active:
		_special_playtest_active = false
		call_deferred("_show_title_screen")

# `d` (bound at connect time) is whoever's swapped_with just fired - only
# react if it's the diver currently being steered, same guard shape as
# _on_encounter_triggered, so a background diver's stray signal (there
# shouldn't be one, but nothing enforces that) can't hijack the camera.
func _on_diver_swapped(target: Diver, d: Diver) -> void:
	if embedded_maze != null and embedded_maze.maze_active:
		return
	if d != divers[active]:
		return
	focus_camera_on(target, 1.1)

# reward_item carries straight into _pending_reward_item - "" (the
# default, what every ordinary random encounter passes) means an
# unmodified fight with nothing riding on it, same as before this existed.
func _start_battle(reward_item: String = "", boss_encounter: bool = false, guardian_enemy_id: String = "angler", custom_party: Array = [], special: bool = false, tutorial: bool = false, intro_text: String = "", authored_enemy: bool = false, revealed_enemy_ids: Array[String] = []) -> void:
	for diver in divers:
		diver.exploration_paused = true
	_cancel_random_encounter_reveal()
	escape_encounter_hint.dismiss()
	battling = true
	Whirlpool.refresh_in(self)
	if boss_encounter:
		_audio_call(&"play_tethys_music")
	elif route_state.encounter_source == "prologue_angler":
		_audio_call(&"play_prologue_battle_music")
	else:
		_audio_call(&"play_battle_music")
	inventory_menu.close()   # shouldn't normally be open when an encounter rolls, but not a state battle.gd should ever have to share the screen with
	_pending_reward_item = reward_item
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE      # buttons need the cursor back
	mouse_look = false
	if boss_encounter:
		# Laboratory Battle already owns this arrival in its intro/log. A
		# World announcement freezes underneath battle and the payoff popup,
		# then falsely re-announces Tethys after she has been defeated.
		# Preserve other queued exploration feedback; don't clear the FIFO.
		if route_state.encounter_source != "lab_boss":
			_announce("Tethys rises from the deep!")
	elif tutorial:
		# No announce line for the tutorial fight itself (removed on
		# purpose), but _show_intro_text()'s "Swim over to the light beam."
		# sits in the same banner via _intro_announce(), which - unlike
		# _announce() - never sets a timer to clear itself. Every other
		# branch here overwrites it with a fresh, self-clearing announce;
		# without an explicit clear here too, that intro line would just
		# hang on screen through the whole fight and after.
		banner.text = ""
		_banner_timer = 0.0
	elif reward_item != "":
		# Marc PR99: actual carrier notice belongs with the combat log and
		# first playable turn, not a competing world banner.
		banner.text = ""
		_banner_timer = 0.0
	else:
		_announce("Enemies emerge from the murk!" if revealed_enemy_ids.size() > 1 else "An enemy emerges from the murk!")
	battle = Battle.new()
	battle.ordinary_enemy_ids = revealed_enemy_ids.duplicate()
	battle.party_source = custom_party if not custom_party.is_empty() else divers
	battle.world = self
	battle.boss_encounter = boss_encounter
	battle.boss_intro_enabled = not skip_boss_intro_for_test
	battle.special_encounter = special
	battle.guardian_encounter = (reward_item != "" or authored_enemy) and not boss_encounter
	battle.guardian_enemy_id = guardian_enemy_id
	battle.encounter_source = route_state.encounter_source
	battle.prologue_angler_encounter = route_state.encounter_source == "prologue_angler"
	if battle.prologue_angler_encounter:
		battle.prologue_angler_defeated.connect(_on_prologue_angler_defeated)
		battle.prologue_phase_changed.connect(_on_prologue_phase_changed)
	battle.tutorial_encounter = tutorial
	battle.reward_item_on_win = reward_item
	battle.encounter_intro_override = intro_text
	battle.finished.connect(_on_battle_finished)
	add_child(battle)


func _on_battle_finished(result: String) -> void:
	for diver in divers:
		diver.exploration_paused = false
	if result == "prologue_defeat" and battle.encounter_source == "prologue_octopus":
		_recover_from_prologue()
		return
	var was_special := battle.special_encounter
	var was_tutorial := battle.tutorial_encounter
	var was_lab_boss := battle.boss_encounter and battle.encounter_source == "lab_boss"
	var route_blocker_id := _active_route_blocker_id
	battle.queue_free()
	battle = null
	battling = false
	# Battle owns victory music while its result is visible. Once it relinquishes
	# the screen, restore exploration before any playtest/title early return.
	# A normal loss is replaced by _show_game_over() below.
	match result:
		"won", "fled", "skipped":
			_audio_call(&"play_exploration_music")
		"lost":
			if was_tutorial or was_special:
				_audio_call(&"play_exploration_music")
	if was_tutorial and not was_special:
		_first_encounter_done = true
		if result in ["won", "skipped"]:
			route_state.tutorial_complete = true
		# Guided the walk-over and held the camera during it - once the
		# tutorial fight is actually over (win or the softened loss), it's
		# done its job and would just sit there as a permanent beam of light
		# in the overworld otherwise.
		if route_state.tutorial_complete and is_instance_valid(light_beam):
			light_beam.queue_free()
			light_beam = null
		# Do not persist the damaged/dead training result. Win/Skip save only
		# after the shared recovery below; loss keeps the prior checkpoint
		# until Return heals/repositions the party.
	if _boss_playtest_active:
		var test_kind := "Tethys boss"
		_boss_playtest_active = false
		_pending_reward_item = ""
		match result:
			"won":
				_announce("%s test complete." % test_kind)
			"fled":
				_announce("%s test ended early." % test_kind)
			_:
				_announce("%s overwhelmed the party. Try the test again." % test_kind)
		call_deferred("_show_title_screen")
		return
	if _special_playtest_active:
		_special_playtest_active = false
		_pending_reward_item = ""
		if _special_encounter_diver != null:
			_special_encounter_diver.stats.hp = _special_encounter_pre_hp
			_special_encounter_diver.stats.oxygen = _special_encounter_pre_oxygen
		_special_encounter_item = ""
		_special_encounter_diver = null
		_announce("Special encounter test complete.")
		call_deferred("_show_title_screen")
		return
	if route_blocker_id != "":
		_resolve_deep_zone_blocker(route_blocker_id, result)
	if was_lab_boss:
		if result == "won":
			route_state.set_lab_state("cleared")
			route_state.set_tethys_state("defeated")
			# The maze branch was already available on entering Deep. Point the
			# player toward it after the lab victory without making Tethys its key.
			route_state.set_objective("enter_maze")
		else:
			# The real checkpoint remains the one written before entering the
			# laboratory. Keep the live state retryable too so a nonstandard test
			# or future soft-loss flow cannot strand the route in `in_progress`.
			route_state.set_lab_state("available")
			route_state.set_tethys_state("available")
			route_state.set_objective("enter_lab")
		route_state.set_encounter_source("random")
		_sync_lab_staging()
		if result == "won":
			_write_save()
			call_deferred("_show_lab_payoff")
	match result:
		"won":
			if was_special and _special_encounter_diver != null:
				# MODIFIED (changed): was a full heal (hp_max/oxygen_max) on a
				# win specifically - a loss just below already reverts to
				# _special_encounter_pre_hp/_special_encounter_pre_oxygen (the
				# snapshot taken before the encounter started, see line 2285),
				# so winning used to leave the diver in better shape than
				# losing did. Matched to the same pre-fight snapshot either
				# way - a special encounter no longer changes this diver's
				# HP/O2 at all outside the fight itself, regardless of outcome.
				_special_encounter_diver.stats.hp = _special_encounter_pre_hp
				_special_encounter_diver.stats.oxygen = _special_encounter_pre_oxygen
				_update_hp_bar()
				_update_oxygen_bar()
			# MODIFIED (added): the very first special encounter is a
			# choreographed practice fight, same idea as the very first
			# combat tutorial's own no-XP rule just above - it's there to
			# teach the mechanic, not to hand out a real reward for it. The
			# item itself was never a one-time key item to begin with (see
			# _grant_reward_item()'s is_key_item() branch - attack_up/
			# defense_up fall through to plain inventory, and nothing here
			# ever marks the site "claimed" the way current_pearl/reef_plate
			# do), so skipping the grant doesn't lock the reward away -
			# every real special encounter at this same site afterward
			# (through the normal diver-choice prompt) can still win it.
			# MODIFIED (changed): this whole win used to show its own orange
			# _announce() banner right here, after already being back in the
			# overworld ("no reward this time" for the practice run, or the
			# generic tutorial-win line otherwise) - moved into the fight's
			# own tutorial captions instead (see battle.gd's _advance_turn(),
			# the special-encounter finale block, shown at the end of the
			# guided portion before the real fight-to-the-death). The reward
			# grant is still skipped for this practice run either way; this
			# win now shows no banner at all, since everything worth saying
			# about it was already said inside the fight.
			if was_special and was_tutorial:
				pass
			elif _pending_reward_item != "":
				_grant_reward_item(_pending_reward_item)
			elif was_tutorial:
				_announce("You won! You can replay this fight any time from the Esc menu's Combat Help tab.")
			elif was_lab_boss:
				_announce("Tethys is defeated. The blue-lit maze passage is now your next route.")
			elif route_blocker_id == "bomb_bot":
				_announce("Bomb Bot powers down. The path to Sword Slayer is open.")
			elif route_blocker_id == "sword_slayer":
				_announce("Sword Slayer falls back. The laboratory entrance is open.")
			else:
				_announce("The enemy backs off into the dark.")
			if was_tutorial:
				# MODIFIED (added): a win never healed anyone, unlike "skipped"
				# and the loss popup's own "Exit to World" (both just above/
				# below) which already do this full heal. A diver who went down
				# during the choreographed finale stayed down afterward - and
				# since this fight is replayable from the Esc menu at any HP,
				# with no way back to a save to recover from it otherwise, that
				# state could ride straight into the next real battle. Confirmed
				# as the actual cause of a real crash: the very first special
				# encounter forces the party down to just that one diver (see
				# World._offer_special_encounter()), and _build_stage() in
				# battle.gd never gives a hp<=0 party member an "actor" key at
				# all - anything after that touching party_entry.actor for her
				# (its own party_centre-facing math) hit a bare Dictionary
				# without the key instead.
				for d in divers:
					var s: CombatantStats = (d as Diver).stats
					s.hp = s.hp_max
					s.oxygen = s.oxygen_max
				_update_hp_bar()
				_update_oxygen_bar()
		"fled":
			_announce("You successfully ran away.")
			escape_encounter_hint.show_after_escape(random_encounters_enabled)
		"skipped":
			# The "Skip Tutorial" in-battle menu option (see battle.gd's
			# _on_skip_tutorial_pressed()) - Run itself stays disabled for the
			# whole tutorial fight, so this is the deliberate way out of it
			# early, same recovery a loss's own "Exit to World" choice gives
			# rather than a separate, unique flow.
			for d in divers:
				var s: CombatantStats = (d as Diver).stats
				s.hp = s.hp_max
				s.oxygen = s.oxygen_max
			_update_hp_bar()
			_update_oxygen_bar()
		"lost":
			if was_special and _special_encounter_diver != null:
				_special_encounter_diver.stats.hp = _special_encounter_pre_hp
				_special_encounter_diver.stats.oxygen = _special_encounter_pre_oxygen
				_update_hp_bar()
				_update_oxygen_bar()
				_announce("The current sweeps you back out, unharmed but empty-handed.")
			elif was_tutorial:
				# A brand-new player's first-ever fight has no real save to
				# fall back to yet, so losing here was never going to be the
				# normal game-over flow below - now offered as an actual
				# choice (see _on_tutorial_loss_retry()/_on_tutorial_loss_
				# exit()) instead of unconditionally healing and returning to
				# the world. Both handlers do their own cleanup (heal, HUD
				# refresh, _show_ability_popups()), so this returns immediately
				# rather than falling through to the shared cleanup below.
				_tutorial_loss_was_special = was_special
				tutorial_result_popup.open(
					"Tutorial Fight Lost",
					"Losing here isn't a real setback - nothing has been saved yet, so there's nothing to lose by trying again. You can also replay this fight any time later from the Esc menu's Combat Help tab.",
				)
				return
			else:
				_show_game_over()
		_:
			_announce("You regroup and catch your breath.")
	_pending_reward_item = ""
	_special_encounter_item = ""
	_special_encounter_diver = null
	# MODIFIED (fixed): was just `if was_tutorial:` - the first special
	# encounter is ALSO tutorial_encounter (see World._offer_special_
	# encounter()), so a win there was firing this same World Map/Maxilani
	# Swap-Sonar/Musashi/Bucky onboarding carousel a second time, right after
	# it had already run once for the real first combat tutorial.
	# _show_ability_popups() is specifically that carousel, not a generic
	# "a tutorial fight just ended" hook.
	if was_tutorial and not was_special:
		# Deferred, not called inline - the announcements/HP-bar updates
		# above still need to land first, and open() itself pauses the
		# tree, which should only happen once this whole handler (and
		# whatever signal dispatch got it here) has actually finished.
		_write_save()
		call_deferred("_show_ability_popups")

# Heals the party and returns to the overworld - the same recovery a
# tutorial loss always did, just now behind an explicit "Exit to World"
# choice (see tutorial_result_popup.open() above) rather than automatic.
# In the real loss flow, _on_battle_finished() already freed `battle`
# before ever opening tutorial_result_popup, so this is a no-op there. It's
# only load-bearing for --tutorial-loss-playtest (_show_tutorial_loss_
# playtest()), which starts a real battle to sit visibly behind the popup
# and never goes through _on_battle_finished() at all - without this, the
# battle scene just kept running underneath, unpaused, once the popup
# closed, which looked like Exit/Retry doing nothing at all.
func _free_lingering_test_battle() -> void:
	if battle != null:
		battle.queue_free()
		battle = null
		battling = false

func _on_tutorial_loss_exit() -> void:
	_free_lingering_test_battle()
	for d in divers:
		var s: CombatantStats = (d as Diver).stats
		s.hp = s.hp_max
		s.oxygen = s.oxygen_max
	_update_hp_bar()
	_update_oxygen_bar()
	_announce("The party regroups and returns to the overworld, fully recovered.")
	_pending_reward_item = ""
	_special_encounter_item = ""
	_special_encounter_diver = null
	# MODIFIED (fixed): same as _on_battle_finished()'s own fix just above -
	# a lost-and-exited first special encounter was opening this onboarding
	# carousel again too.
	if not _tutorial_loss_was_special:
		_first_encounter_started = false
		for i in range(divers.size()):
			(divers[i] as Diver).position = CAST[i].at as Vector3
		if is_instance_valid(light_beam):
			light_beam.visible = true
		else:
			_build_optional_training()
		_write_save()
		call_deferred("_show_ability_popups")

# --tutorial-loss-playtest's own entry point (see
# _tutorial_loss_playtest_requested()) - jumps straight past the title
# screen to the exact popup a real tutorial loss opens, with the same real
# Retry/Exit handlers behind it.
func _show_tutorial_loss_playtest() -> void:
	title_screen.close()
	$HUD.visible = true
	get_tree().paused = false
	# A short real-time wait, not just call_deferred (one idle frame) - every
	# other path that starts a real Battle only ever does so well after the
	# world has fully settled (player walked to the light beam, etc.), and
	# this is the one place that builds a full 3D battle scene the instant
	# the world loads. Cheap insurance either way, though a repro session
	# established this ISN'T what was behind an earlier string of crashes
	# investigating this feature - a plain, code-untouched launch failed
	# just as often in the same session (3/3), which pointed at this
	# machine's own GPU/driver flakiness (already seen intermittently
	# elsewhere this session), not a bug in this code path.
	await get_tree().create_timer(1.0).timeout
	# A real tutorial battle first, not just the plain overworld behind it -
	# the point of this mode is seeing the popup exactly as it looks
	# mid-fight (the popup's own open() pauses the tree right after, which
	# freezes the battle scene in place behind it, same as a real loss would).
	_start_battle("", false, "angler", divers, false, true)
	call_deferred("_open_tutorial_loss_playtest_popup")

func _open_tutorial_loss_playtest_popup() -> void:
	# This debug route always builds the plain tutorial fight (see the
	# hardcoded call just above) - reset in case a real special-encounter
	# loss earlier in the same session left this true, which would
	# incorrectly suppress _on_tutorial_loss_exit()'s ability popups here.
	_tutorial_loss_was_special = false
	tutorial_result_popup.open(
		"Tutorial Fight Lost",
		"There's nothing to lose here by trying again. You can also replay this fight any time later from the Esc menu's Combat Help tab.",
	)

func _on_tutorial_loss_retry() -> void:
	_free_lingering_test_battle()
	if _tutorial_loss_was_special:
		_replay_special_encounter_tutorial()
	else:
		_replay_tutorial_battle()

# _on_tutorial_loss_retry()'s special-encounter counterpart to
# _replay_tutorial_battle() just below - relaunches the exact same forced-
# Maxilani solo fight _offer_special_encounter()'s first-time branch does,
# using _special_encounter_item/_pending_guardian_enemy_id, which are still
# whatever they were on the failed attempt (_on_battle_finished()'s "lost"
# branch returns before ever clearing them - see its own comment). Heals
# Maxilani first for the same "always start a retry undamaged" reason
# _replay_tutorial_battle() does.
func _replay_special_encounter_tutorial(item_id: String = "", enemy_id: String = "") -> void:
	# Combat Help supplies a stable practice setup. The retry path leaves these
	# blank so it can reuse the exact reward/site and enemy from the failed
	# tutorial encounter instead.
	if item_id == "":
		item_id = _special_encounter_item if _special_encounter_item != "" else "attack_up"
	if enemy_id == "":
		enemy_id = _pending_guardian_enemy_id if _pending_guardian_enemy_id != "" else "angler"
	_special_encounter_item = item_id
	_pending_guardian_enemy_id = enemy_id
	var maxilani: Diver = divers[0]
	maxilani.stats.hp = maxilani.stats.hp_max
	maxilani.stats.oxygen = maxilani.stats.oxygen_max
	_update_hp_bar()
	_update_oxygen_bar()
	_start_battle(item_id, false, enemy_id, [maxilani], true, true)

# The same tutorial fight _start_first_encounter() launches the first time
# (all three divers, angler enemy, tutorial_encounter true) - reused by
# both the "Retry" button above and the Esc menu's own replay option (see
# inventory_menu.gd's Combat Help tab), so there's exactly one definition of
# "what the tutorial fight actually is" rather than two copies drifting
# apart. Heals first so a retry (or an on-demand replay well into a real
# playthrough) always starts from a fair, undamaged state.
func _replay_tutorial_battle() -> void:
	for d in divers:
		var s: CombatantStats = (d as Diver).stats
		s.hp = s.hp_max
		s.oxygen = s.oxygen_max
	_update_hp_bar()
	_update_oxygen_bar()
	_start_battle("", false, "angler", divers, false, true)

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
		return
	_add_to_inventory(item_id)

func _announce(text: String) -> void:
	_announcements.push(text)
	_showing_save_prompt = false
	banner.text = _announcements.current_text()
	_banner_timer = _announcements.seconds_left()

func _intro_announce(text: String) -> void:
	_announcements.clear()
	_banner_timer = 0.0
	banner.text = text


func _display_name(model_name: String) -> String:
	# Display identity is centralized with each rig in Cast; model_name remains
	# the stable gameplay/save identifier.
	return Cast.display_name(model_name)

# One Slot per diver, in a row along the top-left of the HUD - no icon
# texture yet (none exists), so each Slot just renders as its own empty
# bordered box until set_diver() is given one. Built once, right after
# `divers` itself is populated in _ready(), since each Slot needs a live
# Diver reference for _show_ability_popups() to read ability_id/passive_id
# off of.
func _build_diver_slots() -> void:
	# Not parented into $HUD - with no icon art to actually show yet, the
	# row just rendered as 3 blank boxes over the diver-name/controls text.
	# Kept as unparented, invisible Slot instances instead of dropping them
	# entirely: _show_ability_popups() still uses set_diver()/set_highlighted()
	# on these, and neither needs the node to be in the scene tree to work -
	# only actually showing a highlighted box on screen does, which nothing
	# does right now anyway with the row gone. Once real icon art exists,
	# re-parent `slot` into $HUD here instead of leaving it detached.
	for d in divers:
		var slot: Slot = SLOT_SCENE.instantiate()
		slot.set_diver(d as Diver)
		_diver_slots.append(slot)

# `_diver_slots` intentionally stays outside the scene tree until real icon art
# exists, so tree teardown cannot free those Nodes for us. Explicit ownership
# here prevents three hidden Control subtrees leaking on every restart/load.
func _exit_tree() -> void:
	_cancel_random_encounter_reveal()
	for slot_value in _diver_slots:
		var slot := slot_value as Slot
		if is_instance_valid(slot) and not slot.is_inside_tree():
			slot.free()
	_diver_slots.clear()


# Fired once, right after the tutorial fight's own battle screen closes and
# control returns to the overworld (see _on_battle_finished()) - five fixed
# CharacterAbilityPopup pages, in party order: the general world-controls
# blurb (no Slot to highlight - it isn't about any one diver), then
# Maxilani's Swap and Sonar as two separate pages, then Musashi/Bucky's own
# single-ability writeups. Text lives on slot.gd itself (worldExplanation/
# maxilaniSwapTitle/etc.) rather than here - every Slot instance carries an
# identical copy of all of it, so which one they're read off doesn't
# matter, only _diver_slots[i] matching CAST's fixed Staff_Diver/
# Prototype_1(1910)/Prototype_V(1922) order matters for picking the right
# Slot to highlight per page.
func _show_ability_popups() -> void:
	if _diver_slots.is_empty():
		return
	var first: Slot = _diver_slots[0]
	var pages: Array[Dictionary] = [
		{"slot": null, "title": "The World Map", "body": first.worldExplanation, "media": "world"},
	]
	if _diver_slots.size() > 0:
		var maxilani: Slot = _diver_slots[0]
		# Two separate pages, not one combined page - Swap and Sonar are two
		# distinct things to learn (and, eventually, two distinct demo clips;
		# see "media" below and TutorialContent.ABILITY_MEDIA), and cramming
		# both into one page's body left Sonar with no clip of its own at
		# all (the page could only ever show ability_id's one clip, "swap").
		pages.append({
			"slot": maxilani,
			"title": maxilani.maxilaniSwapTitle,
			"body": maxilani.maxilaniSwapBody,
			"media": "swap",
		})
		pages.append({
			"slot": maxilani,
			"title": maxilani.maxilaniSonarTitle,
			"body": maxilani.maxilaniSonarBody,
			"media": "sonar",
		})
	if _diver_slots.size() > 1:
		var musashi: Slot = _diver_slots[1]
		pages.append({
			"slot": musashi,
			"title": musashi.musashiAbilityTitle,
			"body": musashi.musashiGrappleBody,
			"media": "grapple",
		})
	if _diver_slots.size() > 2:
		var bucky: Slot = _diver_slots[2]
		pages.append({
			"slot": bucky,
			"title": bucky.buckyAbilityTitle,
			"body": bucky.buckyShockwaveBody,
			"media": "shockwave",
		})
	# Keep this as the final page and omit "media" so it has no clip.
	pages.append({
		"slot": null,
		"title": "Inventory",
		"body": "Press Escape to access the inventory menu where you can use items, diver spells and access any tutorials from Combat Help.",
	})
	# get_node("/root/...") rather than the bare autoload name - the bare
	# global identifier only resolves when Godot boots the project the
	# normal way (main scene + autoload pass). verify/'s gates launch
	# headless via `--script <file>`, which runs that script as the main
	# loop directly; under that path the GDScript compiler fails to
	# resolve the bare name at all ("Identifier not found"), which failed
	# world.gd's own compile and left the affected gate hanging forever
	# with nothing left to run and no reachable quit(). The NodePath lookup
	# is a runtime call, not a parse-time identifier, so it works either way.
	(get_node("/root/CharacterAbilityPopup") as Node).call("open", pages, self)

func _build_route_objective_hud() -> void:
	route_objective_panel = PanelContainer.new()
	route_objective_panel.name = "RouteObjectivePanel"
	route_objective_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	route_objective_panel.offset_left = -285.0
	route_objective_panel.offset_top = 70.0
	route_objective_panel.offset_right = 285.0
	route_objective_panel.offset_bottom = 114.0
	route_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.11, 0.16, 0.92)
	panel_style.border_color = Color(0.29, 0.78, 0.82, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	route_objective_panel.add_theme_stylebox_override("panel", panel_style)
	$HUD.add_child(route_objective_panel)

	route_objective_label = Label.new()
	route_objective_label.name = "RouteObjective"
	route_objective_label.add_to_group("route_objective_hud")
	route_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	route_objective_label.add_theme_font_size_override("font_size", 19)
	route_objective_label.add_theme_color_override("font_color", Color(0.72, 0.96, 1.0))
	route_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_objective_panel.add_child(route_objective_label)

func _layout_world_hud_for_size(viewport_size: Vector2) -> void:
	# The top-right minimap owns 166 px. Keep both text surfaces out of that
	# rectangle at narrow browser widths instead of letting readable text exist
	# underneath an opaque navigation control.
	var compact := viewport_size.x < 600.0
	var right_limit := maxf(160.0 if compact else 304.0, viewport_size.x - 176.0)
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.offset_left = 16.0
	hud.offset_top = 12.0
	hud.offset_right = right_limit
	hud.offset_bottom = 166.0 if compact else 68.0
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_theme_font_size_override("font_size", 14 if viewport_size.x < 900.0 else 16)

	if route_objective_panel == null:
		return
	var panel_width := viewport_size.x - 32.0 if compact else minf(570.0, maxf(288.0, right_limit - 32.0))
	var panel_left := clampf(
		(viewport_size.x - panel_width) * 0.5,
		16.0,
		maxf(16.0, right_limit - panel_width)
	)
	route_objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	route_objective_panel.offset_left = panel_left
	route_objective_panel.offset_top = 176.0 if compact else 74.0
	route_objective_panel.offset_right = panel_left + panel_width
	route_objective_panel.offset_bottom = route_objective_panel.offset_top + 44.0

func _show_lab_payoff() -> void:
	if route_state.lab_state != "cleared" or route_state.tethys_state != "defeated":
		return
	# The meeting requested a brief computer/controller message, not new
	# narration or another compulsory encounter. Reuse the input-exclusive
	# paged surface and its scene-owner/battle-deferral protection. `cleared`
	# already persists this payoff; loading never repays or replays victory.
	var pages: Array[Dictionary] = [{
		"slot": null,
		"title": "Computer recovered",
		"body": "Tethys is defeated. You recovered the computer she swallowed. Another being is controlling these creatures.\n\nSuggested next step: explore the maze via the ramp beyond the laboratory. Use the divers' abilities for its puzzles.",
	}]
	$HUD.visible = false
	var popup := get_node("/root/CharacterAbilityPopup")
	if not popup.closed.is_connected(_on_lab_payoff_closed):
		popup.closed.connect(_on_lab_payoff_closed, CONNECT_ONE_SHOT)
	popup.call("open", pages, self)

func _on_lab_payoff_closed() -> void:
	if not battling and not embedded_maze.maze_active and not is_instance_valid(_completion_screen):
		$HUD.visible = true
		_refresh_world_guidance()

func _on_route_objective_changed(_objective_id: String) -> void:
	_refresh_world_guidance()

func _refresh_world_guidance() -> void:
	if route_objective_panel == null or route_objective_label == null:
		return
	var text := ""
	if route_state.prologue_complete and not divers.is_empty():
		var position := (divers[active] as Diver).global_position
		if deep_zone_layout.zone_for_position(position) == "deep":
			text = route_state.exploration_goal("deep")
		elif _puzzle_solved and _puzzle_hint_bounds.has_point(position):
			text = "The way is open. Explore the deep sea."
		elif _cracked_walls.has("entrance_blockade") and _puzzle_hint_bounds.has_point(position):
			text = "Use Bucky's Shockwave to break the wall. (TAB)"
		elif _near_reward_rock(position):
			if (divers[active] as Diver).ability_id == "shockwave":
				text = "Break this rock for items: (F) Shockwave."
			else:
				text = "Break rocks for items: (TAB) Bucky, (F) Shockwave."
		else:
			text = route_state.exploration_goal("shallows")
	route_objective_label.text = text
	route_objective_panel.visible = text != ""
	if get_viewport().get_visible_rect().size.x < 600.0:
		# Compact controls can wrap below the map. Keep proximity prompts
		# below both surfaces instead of allowing the map to obscure the keys.
		route_objective_panel.offset_top = maxf(176.0, hud.get_rect().end.y + 8.0)
		route_objective_panel.offset_bottom = route_objective_panel.offset_top + 44.0

func _near_reward_rock(position: Vector3) -> bool:
	# Guidance belongs to actual, unbroken loot rocks, never scenery, the
	# route blockade or ambush rocks. Full 3D distance prevents seabed hints
	# while swimming high overhead; the prompt appears within Shockwave reach.
	for id in _cracked_walls:
		if not String(id).begins_with("rock_") or id in ROCK_AMBUSH_IDS:
			continue
		var rock := _cracked_walls[id] as CrackedWall
		if is_instance_valid(rock) and not rock.is_queued_for_deletion() and position.distance_to(rock.global_position) <= Diver.SHOCKWAVE_RADIUS:
			return true
	return false

func _update_hud() -> void:
	_refresh_world_guidance()
	if target_selector.selecting:
		var t := target_selector.current_target()
		if t != null and t is Diver:
			hud.text = "Swap with %s?\nA/D or Left/Right: cycle   ·   Space/Enter: confirm   ·   Esc: cancel" % _display_name((t as Diver).model_name)
		else:
			hud.text = "A/D or Left/Right: cycle   ·   Space/Enter: confirm   ·   Esc: cancel"
		return
	if aiming:
		hud.text = "Aiming %s\nLeft click: fire   ·   Right click: cancel" % String(divers[active].ability_id).capitalize()
		return
	var d: Diver = divers[active]
	if not route_state.prologue_complete:
		hud.text = "%s\nWASD swim · SPACE/SHIFT depth · mouse/arrows look" % _display_name(d.model_name)
		return
	var narrow := get_viewport().get_visible_rect().size.x < 900.0
	var line := ""
	if narrow:
		line = "%s · WASD swim · SPACE/SHIFT depth\nmouse/arrows look · TAB diver" % _display_name(d.model_name)
	else:
		line = "%s\nWASD swim · SPACE/SHIFT depth · mouse/arrows look · TAB diver" % _display_name(d.model_name)
	if d.ability_id != "":
		line += (" · F:%s" if narrow else "  ·  F: %s") % String(d.ability_id).capitalize()
	# Only shows for whichever diver actually has the passive (see
	# _toggle_sonar()'s own passive_id check) - same "only mention it if
	# it'd do something" rule the F: hint above already follows for
	# ability_id.
	if d.passive_id == "sonar":
		line += (" · Q:Sonar %s" if narrow else "  ·  Q: Sonar (%s)") % ("On" if d.sonar_active else "Off")
	line += (" · R:Random %s" if narrow else "  ·  R: Encounters (%s)") % ("On" if random_encounters_enabled else "Off")
	hud.text = line

# A persistent readout of the active diver's HP, always visible during
# free swimming (not just during Battle, which has its own separate HP
# bars on its own screen) - bottom-center, red fill matching Battle's own
# bar styling (see battle.gd's _add_bar) so the same number reads the
# same way in both places.
var hp_bar: ProgressBar
var hp_bar_label: Label
var _hp_bar_mat: StyleBoxFlat

# Shared by hp_bar_label and oxygen_bar_label - hp_bar_label had no
# override at all (whatever the default theme font size happens to be)
# while oxygen_bar_label was hardcoded to 13, so the two never actually
# matched. One constant for both now.
const WORLD_HUD_LABEL_FONT_SIZE := 14

func _build_hp_bar() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wrap.offset_top = -56.0
	wrap.offset_bottom = -10.0
	wrap.add_theme_constant_override("separation", 4)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	# MODIFIED (added): this spans the full WIDTH of the screen (BOTTOM_WIDE)
	# and defaulted to STOP - a special-encounter minigame's own aim-down
	# input landed right in this strip and got eaten here instead of
	# reaching it. Purely informational, nothing here is ever clicked.
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(wrap)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(220, 20)
	hp_bar.show_percentage = false
	hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# MODIFIED (added): wrap's own IGNORE (above) only applies to wrap
	# itself - hp_bar/hp_bar_label are separate nodes that each still
	# defaulted to STOP independently, which is what was actually still
	# blocking this strip regardless of the outer wrap's own filter.
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar_mat = StyleBoxFlat.new()
	_hp_bar_mat.bg_color = Color(0.78, 0.15, 0.15)
	hp_bar.add_theme_stylebox_override("fill", _hp_bar_mat)
	wrap.add_child(hp_bar)

	hp_bar_label = Label.new()
	hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_label.add_theme_font_size_override("font_size", WORLD_HUD_LABEL_FONT_SIZE)
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
	# MODIFIED: this band (offset_top to offset_bottom) used to be only 24px
	# tall (-82 to -58), with just 2px of clearance above the HP bar's own
	# band starting at -56 - nowhere near enough to fit a 14px bar plus a
	# label on top of it, so the label routinely overflowed straight down
	# onto the HP bar below. Now 40px tall with an 8px real gap above the
	# HP bar's own top edge (-56).
	wrap.offset_top = -104.0
	wrap.offset_bottom = -64.0
	wrap.add_theme_constant_override("separation", 4)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	# MODIFIED (added): same full-width STOP-by-default bug as the HP bar's
	# own wrap just above.
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(wrap)

	oxygen_bar = ProgressBar.new()
	oxygen_bar.custom_minimum_size = Vector2(220, 14)
	oxygen_bar.show_percentage = false
	oxygen_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# MODIFIED (added): same reasoning as the HP bar's own fix just above -
	# wrap's IGNORE doesn't cascade to its children.
	oxygen_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := StyleBoxFlat.new()
	mat.bg_color = Color(0.25, 0.65, 0.85)
	oxygen_bar.add_theme_stylebox_override("fill", mat)
	wrap.add_child(oxygen_bar)

	oxygen_bar_label = Label.new()
	oxygen_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oxygen_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oxygen_bar_label.add_theme_font_size_override("font_size", WORLD_HUD_LABEL_FONT_SIZE)
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
