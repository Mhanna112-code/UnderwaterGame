# The dive site: a seafloor, the three divers, and a chase camera.
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

# Gates TAB/random encounters and holds the camera on the light beam until
# the active diver reaches it.
var _intro_active := false
# Horizontal (XZ) arrival radius around the light beam.
const INTRO_ARRIVAL_DIST := 2.5
var _first_encounter_started := false
var _transitioning_to_encounter := false
var random_encounter_reveal: RandomEncounterReveal
# Set when the tutorial fight finishes; gates the save point until then.
var _first_encounter_done := false
# Which tutorial fight opened the loss popup (special vs. first combat).
var _tutorial_loss_was_special := false
# Test seam: skip the opening crawl.
var skip_intro_for_test := false
# Dev/test: skip the scripted first fight (--skip-tutorial or ?skip_tutorial=1).
var skip_tutorial_for_test := false
# Test seam: skip Tethys's swim entrance.
var skip_boss_intro_for_test := false

func _tutorial_skip_requested() -> bool:
	if OS.get_cmdline_user_args().has("--skip-tutorial"):
		return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return String(search).contains("skip_tutorial=1")
	return false

# Random encounters: Diver emits encounter_triggered; World starts a battle.
var banner: Label
var _banner_timer := 0.0
var _announcements := preload("res://game/orange_message_queue.gd").new()
var route_objective_panel: PanelContainer
var route_objective_label: Label
var maze_route_guide: MazeRouteGuide
var battling := false
var battle: Battle
var yaw := 0.0
var pitch := -0.16
var cam_dist := 6.5
var cam: Camera3D
var hud: Label
var mouse_look := false
# R toggles random encounters (player-facing, on by default).
var random_encounters_enabled := true
var escape_encounter_hint: PanelContainer
var _t := 0.0

# First-person aim mode for aimed abilities (grapple): E enters, left click
# fires, right click cancels.
var aiming := false

# Swap target picking (A/D or arrows, Space/Enter confirms, Escape cancels).
var target_selector: TargetSelector

# P opens the save menu while standing on a SavePoint.
var save_point_menu: SavePointMenu
var _save_points: Array = []
var _showing_save_prompt := false
var _save_point_contact_active := false
var _save_point_tutorial_seen := false
# Combat Help unlocks (saved).
var special_encounter_left := false
var ability_popups_seen := false
# Item sites beaten and claimed; these stop triggering. Saved.
var cleared_item_sites: Array[String] = []
var _pending_reward_site := ""   # site whose fight is being offered/started
var _battle_reward_site := ""    # site the current battle was started from

# Party-wide key items (unlock spells in any diver's tree).
# Dive sites from content/sites.gd; site_nodes is keyed by site id.
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
const WORLD_CEILING_Y := BLOCKADE_HEIGHT * 4.0
# Entrance rocks x; west of it is the tutorial side.
const ENTRANCE_BLOCKADE_X := 16.0
# Lock-plate doors x; "Explore the deep sea" shows only past them.
const PUZZLE_DOORS_X := 42.0
const CEILING_THICKNESS := 2.0
const ROCK_KEY_ITEM_REWARDS := {
	"rock_7": "abyssal_lens",
	"rock_8": "sunken_core",
}
const ROCK_AMBUSH_IDS := ["rock_9", "rock_10"]

# Item ids sonar has pinged; MiniMap marks those not yet in key_items.
var revealed_key_items: Array[String] = []

# Stable ids of consumed persistable world objects (saved; removed on load).
var consumed_world_ids: Array[String] = []

# id -> live CrackedWall, so _load_save() can free consumed ones.
var _cracked_walls: Dictionary = {}

# Party-wide consumables (item_id -> count), spent via use_inventory_item().
var inventory: Dictionary = {}

# Rock id -> {item, position} for a spawned but uncollected reward (saved so
# it survives the rock being removed on load).
var pending_world_drops: Dictionary = {}

# Escape pause menu (mutually exclusive with aim/target select/save menu).
var inventory_menu: InventoryMenu

# Title screen and game-over screen.
var title_screen: TitleScreen
var game_over_screen: GameOverScreen
var title_layer: CanvasLayer

# Special encounters open on entering an unclaimed special item's site radius.
var special_encounter_prompt: SpecialEncounterPrompt
var tutorial_book: TutorialBook
# Tutorial loss popup (retry/exit).
var tutorial_result_popup: TutorialResultPopup

const SLOT_SCENE := preload("res://slot.tscn")
# One HUD Slot per diver, same order as `divers`; anchors CharacterAbilityPopup.
var _diver_slots: Array = []
# Active first-run opening owner, observable without searching the tree.
var opening_video: CanvasLayer
var _special_encounter_item := ""
var _special_encounter_diver: Diver
var _special_encounter_pre_hp := 0
var _special_encounter_pre_oxygen := 0.0
var _inside_item_site_id := ""
# Enemy species for the pending special encounter, set from the guarded site.
var _pending_guardian_enemy_id := "angler"

# Guarded item to grant on a win; "" for an ordinary random encounter.
var _pending_reward_item := ""

# Isolated ?boss=1 review route: never saves, returns to title afterwards.
var _boss_playtest_active := false

# Isolated ?special=1 review route: never grants items or saves.
var _special_playtest_active := false

# Active save slot; -1 while the title screen is still up.
var _current_slot := -1
const AUTOSAVE_INTERVAL := 180.0
var _autosave_timer := 0.0
var _autosave_writing := false
var _checkpoint_saving := false
var _completion_screen: CanvasLayer
var _completion_checkpoint: Dictionary = {}
var _completion_saving := false

# State captured when the Cordys fight was confirmed (per World/run).
var _pre_boss_checkpoint: Dictionary = {}
var _pre_boss_slot := -1
var _pre_boss_save_error: Error = ERR_UNAVAILABLE
var _pre_boss_saving := false
var _pre_boss_generation := 0
static var _restart_checkpoint: Dictionary = {}

func _capture_pre_boss_autosave() -> void:
	_pre_boss_checkpoint = _serialize_state()
	_pre_boss_slot = _current_slot
	_pre_boss_generation += 1
	var generation := _pre_boss_generation
	_pre_boss_save_error = ERR_UNAVAILABLE
	if _current_slot < 0:
		return
	var slot := _current_slot
	var path := SaveManager.autosave_path(slot)
	var existed := FileAccess.file_exists(path)
	var previous := FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
	_pre_boss_saving = true
	var error := SaveManager.write_autosave(slot, _pre_boss_checkpoint)
	var written := error == OK
	var written_bytes := FileAccess.get_file_as_bytes(path) if written else PackedByteArray()
	if written:
		error = await BrowserCheckpoint.confirm_slot(slot, true)
	if written and error != OK and FileAccess.get_file_as_bytes(path) == written_bytes:
		# Roll back only this write; a newer run may own the checkpoint now.
		SaveManager.rollback_autosave(slot, existed, previous)
		if OS.has_feature("web"):
			JavaScriptBridge.force_fs_sync()
	# A later Title Load/New Game owns its own checkpoint/status.
	if generation != _pre_boss_generation:
		return
	_pre_boss_saving = false
	_pre_boss_save_error = error
	_refresh_completion_restart_options()

func _clear_pre_boss_checkpoint() -> void:
	_pre_boss_generation += 1
	_pre_boss_checkpoint = {}
	_pre_boss_slot = -1
	_pre_boss_saving = false
	_pre_boss_save_error = ERR_UNAVAILABLE

func _pre_boss_restart_data() -> Dictionary:
	var data := _pre_boss_checkpoint if _pre_boss_slot == _current_slot else {}
	if data.is_empty() and _current_slot >= 0:
		data = SaveManager.read_autosave(_current_slot)
	# Only a valid pre-Cordys checkpoint counts. Read-only validation.
	if data.get("campaign_scene") != "maze" or CampaignCheckpoint.decode(data) == null \
		or data.get("route_state", {}).get("octopus_state") == "defeated" \
		or not data.get("campaign_checkpoint", {}).get("maze", {}).get("boss_triggers", []).has("main_boss"):
		return {}
	return data

func _refresh_completion_restart_options() -> void:
	if not is_instance_valid(_completion_screen):
		return
	var has_restart := not _pre_boss_restart_data().is_empty()
	var current_memory := _pre_boss_slot == _current_slot and not _pre_boss_checkpoint.is_empty()
	var durable := has_restart and (_pre_boss_save_error == OK if current_memory else true)
	_completion_screen.show_options(has_restart, durable, _pre_boss_saving)

func _restart_from_pre_boss_autosave() -> void:
	var data := _pre_boss_restart_data()
	if data.is_empty():
		return
	_restart_checkpoint = data
	_restart_slot = -1
	_resume_slot_after_restart = _current_slot
	get_tree().paused = false
	get_tree().reload_current_scene()

static var _resume_slot_after_restart := -1

# Like a Title Load, but from an in-memory checkpoint (the pre-boss autosave).
func _resume_from_checkpoint(data: Dictionary, slot: int) -> void:
	_current_slot = slot
	if not restore_checkpoint(data):
		_current_slot = -1
		_show_title_screen()
		title_screen.show_load_error("Could not restart from the autosave.")
		return
	title_screen.close()
	if _loaded_maze_session != null:
		_loaded_maze_session.selected_slot = slot
		_loaded_maze_session = null
		get_tree().paused = false
		_set_maze_ownership(true, true)
		_audio_call(&"play_exploration_music")
	else:
		$HUD.visible = true
		get_tree().paused = false
		_audio_call(&"play_exploration_music")
	_announce("Restarted from the autosave before the Cordys fight.")

func _show_campaign_completion(already_saved := false) -> void:
	if is_instance_valid(_completion_screen) or route_state.octopus_state != "defeated":
		return
	# Rewards are already paid; freeze this boundary so retries can't replay them.
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
	_completion_screen.restart_chosen.connect(_restart_from_pre_boss_autosave)
	_completion_screen.title_chosen.connect(_on_game_over_title)
	add_child(_completion_screen)
	# The ending offers the pre-Cordys autosave instead of a completion save.
	_refresh_completion_restart_options()

func _autosave_safe() -> bool:
	if _checkpoint_saving or _pre_boss_saving:
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
	_announce(("Progress saved to Slot %d." % (slot + 1)) if error == OK else "Autosave failed. Your last checkpoint is unchanged.")

# Authored progression state; saved in the same atomic checkpoint.
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

# One-time blocker triggers. `_inside_route_blocker_id` prevents re-triggering
# while still inside the volume.
const ROUTE_BLOCKER_TRIGGER_RADIUS := 4.0
const ROUTE_BLOCKER_EXIT_RADIUS := 6.0
const ROUTE_BLOCKER_TRIGGER_HALF_WIDTH := 10.0
const ROUTE_BLOCKER_EXIT_HALF_WIDTH := 11.5
var _active_route_blocker_id := ""
var _inside_route_blocker_id := ""
var _route_blocker_world_actors: Dictionary = {}
var _route_blocker_gates: Dictionary = {}

# One-shot handoff across reload_current_scene() to restore a checkpoint
# (consumed geometry can't be recreated in place).
static var _restart_slot := -1
static var _restart_latest := false
var _loaded_maze_session: CampaignSession
var _campaign_session: CampaignSession
var embedded_maze: MazeLevel

# Full run state for saving. Vector3 is stored as [x,y,z] for JSON.
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
		"special_encounter_left": special_encounter_left,
		"ability_popups_seen": ability_popups_seen,
		"cleared_item_sites": cleared_item_sites.duplicate(),
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

# Refuses partial restores when save data doesn't match divers[] one-to-one.
func _load_save(from_autosave := false, latest := false) -> bool:
	if latest:
		for candidate in SaveManager.latest_candidates(_current_slot):
			if restore_checkpoint(candidate.data):
				print("CHECKPOINT_LATEST_LOADED|slot=", _current_slot, "|autosave=", candidate.autosave)
				return true
		return false
	return restore_checkpoint(SaveManager.read_autosave(_current_slot) if from_autosave else SaveManager.read_slot(_current_slot))

# Shared validated restore used by disk Load and a live campaign return.
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
	# Validate the complete shape before mutating any live actor.
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
	# Old hazard timers must release shared actors before the restore.
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
	for retired in Items.RETIRED_ITEMS:
		inventory.erase(retired)
		for drop_id in pending_world_drops:
			if String((pending_world_drops[drop_id] as Dictionary).get("item", "")) == retired:
				(pending_world_drops[drop_id] as Dictionary)["item"] = Items.EVEN_DROP_ORDER[0]
	# .assign(): these are typed Array[String]; JSON gives untyped Arrays.
	key_items.assign((data.get("key_items", []) as Array).duplicate())
	revealed_key_items.assign((data.get("revealed_key_items", []) as Array).duplicate())
	consumed_world_ids.assign((data.get("consumed_world_ids", []) as Array).duplicate())
	active = int(data.get("active", 0))
	_save_point_tutorial_seen = bool(data.get("save_point_tutorial_seen", false))
	special_encounter_left = bool(data.get("special_encounter_left", false))
	ability_popups_seen = bool(data.get("ability_popups_seen", false))
	cleared_item_sites.clear()
	for site_value in data.get("cleared_item_sites", []):
		cleared_item_sites.append(String(site_value))
	# Older saves: an owned key item's site counts as cleared.
	if not data.has("cleared_item_sites"):
		for spot in ItemGuardian.spots():
			if Items.is_key_item(String(spot.item)) and key_items.has(String(spot.item)):
				cleared_item_sites.append(String(spot.get("site", spot.item)))
	# The forced first special encounter only happens once.
	player_first_special_encounter = not special_encounter_left
	route_state.load_save_data(data.get("route_state", {}) as Dictionary)
	random_encounters_enabled = data.get("random_encounters_enabled", true)
	_puzzle_solved = data.get("ability_puzzle_solved", false)
	_maze_entry_source = data.get("maze_entry_source", "deep_landmark")
	_sync_puzzle_maze_exit()
	for i in range(divers.size()):
		var d := divers[i] as Diver
		# Migrate older completed checkpoints to the new exploration default.
		var sonar_on: bool = divers_data[i].get("sonar_active", route_state.prologue_complete and d.passive_id == "sonar")
		sonar_on = sonar_on and d.passive_id == "sonar" and d.stats.oxygen > 0.0
		if d.sonar_active != sonar_on:
			d.toggle_sonar() # initializes the drain clock and refuses empty O2
	_first_encounter_done = route_state.prologue_complete
	_first_encounter_started = route_state.tutorial_complete
	_normalize_loaded_route_state()
	_sync_deep_zone_blocker_staging()
	_sync_lab_staging()

	# Remove objects this save marks as consumed from the freshly built world.
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
	# Flat legacy saves hold the outer-world checkpoint; keep the entrance usable.
	if _loaded_maze_session == null and route_state.zone_id == "maze":
		route_state.set_zone("deep")
		route_state.set_maze_door_state("available")
	# Movie/battle states aren't serializable; return to the lab entrance.
	if route_state.lab_state in ["cutscene", "boss"] or route_state.tethys_state == "in_progress":
		route_state.set_lab_state("available")
		route_state.set_tethys_state("available")
		route_state.set_objective("find_lab")
		route_state.set_encounter_source("random")
	# Migrate older saves with the former lab-gated `locked` maze state.
	if route_state.zone_id == "deep" and route_state.maze_door_state == "locked":
		route_state.set_maze_door_state("available")
	# Migrate blocker-first objective copy from early builds.
	if route_state.zone_id == "deep" and route_state.objective_id in ["defeat_bomb_bot", "defeat_sword_slayer", "enter_lab"]:
		route_state.set_objective("find_lab")

# Pause the world; title/game-over screens run with PROCESS_MODE_ALWAYS.
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
	# The title owns a separate layer so the world HUD hides as one unit.
	$HUD.visible = false
	# Cold title stays silent until a browser gesture; retire any prior cues.
	_audio_call(&"stop_music")
	Whirlpool.refresh_in(self)
	get_tree().paused = true
	title_screen.open()

# New Game: claim a slot and write the first save from the fresh divers.
func _on_title_new_game(slot: int) -> void:
	_clear_pre_boss_checkpoint()
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
	# Skip-tutorial route: show ability popups here since no first fight runs.
	if skip_tutorial_for_test:
		call_deferred("_show_ability_popups")

# "New Game (Skip Tutorial)": undo the tutorial setup done in _ready(), then
# use the normal new-game flow.
func _on_title_skip_tutorial(slot: int = 0) -> void:
	skip_tutorial_for_test = true
	# Review entry that bypasses the opening (not normal New Game).
	route_state.opening_video_seen = true
	route_state.prologue_complete = true
	route_state.tutorial_complete = true
	route_state.set_prologue_phase("complete")
	# Skip the intro crawl, like the other playtest buttons.
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

func _on_title_load_latest(slot: int) -> bool:
	return await _on_title_load_game(slot, false, true)

func _on_title_load_game(slot: int, from_autosave := false, latest := false) -> bool:
	_clear_pre_boss_checkpoint()
	_cancel_random_encounter_reveal()
	_current_slot = slot
	_autosave_timer = 0.0
	if not _load_save(from_autosave, latest):
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
		_build_forced_tutorial_beam()
	return true

# World writes the opening milestone only after playback completes. Retry the
# cinematic only while the prologue is incomplete.
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
		# Prepare the HUD behind the opaque title; physics stays paused.
		_camera_look_override = null
		return_camera_to_player()
		# Settle camera framing before the reveal to avoid a visible zoom.
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
	# Start the Angler only after real swimming, not on reveal.
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
	# Retire the music owner before the movie starts.
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
	# Hold silence while the defeated formation remains visible.
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
		# Don't release play on a failed checkpoint; explain and retry the same slot.
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
	_build_forced_tutorial_beam()
	_update_hud()
	_update_hp_bar()
	_update_oxygen_bar()
	$HUD.visible = true
	get_tree().paused = false
	_audio_call(&"play_exploration_music")
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		audio.fade_music_in(0.35)

# After prologue recovery the combat tutorial is mandatory: beam, arrow and
# camera hold return until the diver arrives.
func _build_forced_tutorial_beam() -> void:
	if not route_state.prologue_complete or route_state.tutorial_complete:
		return
	if not is_instance_valid(light_beam):
		light_beam = null
		render_light_beam()
		light_beam.position = Vector3(0.0, 6.0, 10.0)
	light_beam.visible = true
	_first_encounter_started = false
	intro_arrow()
	if is_instance_valid(_intro_arrow):
		_intro_arrow.visible = true
		_point_arrow_at(light_beam.global_position)
	_show_intro_text()
	_intro_active = true
	_camera_look_override = light_beam

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

# Free-roam with a fully learned/equipped temporary roster, learned through
# SpellTree so gates stay real. Never saves.
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

# Opens the tutorial loss popup immediately for iterating on its look.
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
	# Defeat hides the world HUD like the cold-launch title.
	$HUD.visible = false
	title_screen.close()
	_audio_call(&"play_game_over_music")
	get_tree().paused = true
	game_over_screen.open(autosave_tooltip())

func _on_game_over_restart() -> void:
	_restart_slot = _current_slot
	_restart_latest = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_game_over_continue() -> void:
	_restart_slot = _current_slot
	_restart_latest = true
	get_tree().paused = false
	get_tree().reload_current_scene()

# Reload rebuilds the pristine world and lands on the title screen.
func return_to_title() -> void:
	# --dev would otherwise restart dev mode on the reload and skip the title.
	_dev_start_suppressed = true
	_on_game_over_title()

# Survives reload_current_scene(): after Return To Title, a --dev session lands
# on the title screen instead of jumping straight back into dev mode.
static var _dev_start_suppressed := false

func _dev_requested() -> bool:
	return OS.get_cmdline_user_args().has("--dev") and not _dev_start_suppressed

# Writes the current run to this slot's autosave right now (used before
# returning to the title). ERR_UNCONFIGURED when there's no save slot (dev mode).
func autosave_now() -> Error:
	if _current_slot < 0:
		return ERR_UNCONFIGURED
	var slot := _current_slot
	var error := SaveManager.write_autosave(slot, _serialize_state())
	if error == OK:
		error = await BrowserCheckpoint.confirm_slot(slot, true)
	return error

# Game-over tooltip for "Continue from Last Autosave": when it was made and
# each diver's level in it.
func autosave_tooltip() -> String:
	if _dev_mode or _current_slot < 0:
		# No slot (dev mode): nothing is written, so describe the party now.
		var now: Array[String] = []
		for d in divers:
			var ds := (d as Diver).stats
			now.append("%s Lv %d (%d/%d HP)" % [_display_name((d as Diver).model_name), ds.level, ds.hp, ds.hp_max])
		return "Dev mode: no autosave is written.\nParty now: %s" % ", ".join(now)
	var data := SaveManager.read_autosave(_current_slot)
	var raw_divers: Variant = data.get("divers", [])
	if data.is_empty() or not raw_divers is Array:
		return "No autosave yet."
	var levels: Array[String] = []
	for i in (raw_divers as Array).size():
		var stats := ((raw_divers as Array)[i] as Dictionary).get("stats", {}) as Dictionary
		var diver_name := _display_name((divers[i] as Diver).model_name) if i < divers.size() else "Diver %d" % (i + 1)
		levels.append("%s Lv %d (%d/%d HP)" % [diver_name, int(stats.get("level", 1)), int(stats.get("hp", 0)), int(stats.get("hp_max", 10))])
	var lines: Array[String] = []
	var saved_at := FileAccess.get_modified_time(SaveManager.autosave_path(_current_slot))
	if saved_at > 0:
		lines.append("Autosaved %s" % _time_ago(int(Time.get_unix_time_from_system()) - int(saved_at)))
	lines.append("\n".join(levels))
	return "\n".join(lines)

static func _time_ago(seconds: int) -> String:
	if seconds < 60:
		return "just now"
	if seconds < 3600:
		var minutes := seconds / 60
		return "%d minute%s ago" % [minutes, "" if minutes == 1 else "s"]
	if seconds < 86400:
		var hours := seconds / 3600
		return "%d hour%s ago" % [hours, "" if hours == 1 else "s"]
	var days := seconds / 86400
	return "%d day%s ago" % [days, "" if days == 1 else "s"]

# Autosave right after a boss win, once back in the world. Returns the banner
# text to show when the moment is right ("" when there's no save slot).
func autosave_after_boss() -> String:
	if _dev_mode:
		return "Autosave skipped in dev mode."
	if _current_slot < 0:
		return ""
	var error := await autosave_now()
	_autosave_timer = 0.0
	return ("Progress saved to Slot %d." % (_current_slot + 1)) if error == OK else "Autosave failed. Your last checkpoint is unchanged."

# Banner for the post-Tethys autosave, shown once the lab payoff closes.
var _post_tethys_autosave_text := ""

func _autosave_after_tethys() -> void:
	_post_tethys_autosave_text = await autosave_after_boss()

func _on_game_over_title() -> void:
	_restart_slot = -1
	_restart_latest = false
	get_tree().paused = false
	get_tree().reload_current_scene()

# Gap puzzle's three plates; checked each frame in _check_gap_puzzle().
var _lock_plates: Array = []
var _doors: Array = []
var _puzzle_goal: Waypoint
var _puzzle_solved := false
var _puzzle_hint_bounds := AABB()
var _puzzle_exit_label: Label3D

# Wall pieces: {a, b, body, revealed, line_a, line_b}. a/b are the fixed span;
# line_a/line_b are the overlap frozen when first revealed. Read by MiniMap.
var _wall_pieces: Array[Dictionary] = []
var minimap: MiniMap

# Wall slice length for gradual reveal (matches maze_mini_map.gd).
const WALL_REVEAL_SEGMENT_LENGTH := 2.0

# Area3D following the active diver; coarse pass for wall reveal.
var _wall_sight_area: Area3D

# Camera focus override: hold on `_camera_focus_target` (swap targeting or
# post-swap hold). auto_return_after 0 = until told, >0 = timed.
enum CameraMode { PLAYER, FOCUS }
var camera_mode := CameraMode.PLAYER
var _camera_focus_target: Node3D = null

# While set, the chase camera keeps its position but looks at this point
# (used for the intro light beam).
var _camera_look_override: Node3D = null
var _camera_focus_timer := 0.0

# Test seam: verify/swim.gd steers the player without a keyboard.
var scripted := false
var scripted_dir := Vector3.ZERO
var scripted_rise := 0.0

# Cone above the active diver; hidden while swap-selecting, aiming or battling.
var _active_cursor: MeshInstance3D

# World-space labels (save points, sites, names) vanish past this distance
# instead of shrinking to unreadable specks.
const LABEL_VISIBLE_RANGE := 100.0

func _hide_far_label(node: Node) -> void:
	if node is Label3D and node.get_viewport() == get_viewport():
		(node as Label3D).visibility_range_end = LABEL_VISIBLE_RANGE

func _ready() -> void:
	# Battle labels live in the stage SubViewport, so they're never affected.
	get_tree().node_added.connect(_hide_far_label)
	if _dev_requested():
		skip_intro_for_test = true
		skip_tutorial_for_test = true
	# Read-only trace that syncs exported playtests to real gameplay.
	route_state.phase_changed.connect(_report_prologue_phase)
	cam = $Camera3D
	hud = $HUD/Controls
	# HUD elements must not eat mouse input meant for minigames.
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = Label.new()
	banner.name = "Banner"
	# Bottom-center, just above the HP/oxygen bars.
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
	maze_route_guide = preload("res://game/maze_route_guide.gd").new()
	$HUD.add_child(maze_route_guide)
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
		d.sonar_changed.connect(_update_hud, CONNECT_DEFERRED)
		target_selector.register_character(d)
	_build_diver_slots()
	_build_party_bars()   # needs the divers that were just created
	# process_frame fires even while paused (menus and maze map).
	get_tree().process_frame.connect(_sync_overlay_hud)
	# The spell-playtest route needs a save point immediately, so skip the tutorial.
	if _tutorial_skip_requested() or _spell_playtest_requested() or _blocker_playtest_requested():
		skip_tutorial_for_test = true
	if skip_tutorial_for_test:
		# No beam/arrow; mark the tutorial done up front.
		_first_encounter_started = true
		_first_encounter_done = true
		route_state.opening_video_seen = true
		route_state.prologue_complete = true
		route_state.tutorial_complete = true
		route_state.set_prologue_phase("complete")
	_update_hud()

	# Not under HUD: _show_title_screen() hides that whole layer.
	title_layer = CanvasLayer.new()
	title_layer.name = "TitleLayer"
	title_layer.layer = 20
	add_child(title_layer)
	title_screen = TitleScreen.new()
	title_screen.new_game_chosen.connect(_on_title_new_game)
	title_screen.load_game_chosen.connect(_on_title_load_game)
	title_screen.load_latest_chosen.connect(_on_title_load_latest)
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
	game_over_screen.continue_chosen.connect(_on_game_over_continue)
	game_over_screen.title_chosen.connect(_on_game_over_title)
	# Not under HUD: _show_game_over() hides HUD as one unit.
	title_layer.add_child(game_over_screen)
	_build_embedded_maze()

	# A game-over restart rebuilds the scene before applying its save.
	if SceneHandoff.returning_to_world:
		SceneHandoff.returning_to_world = false
		var returned := SceneHandoff.take_campaign_session()
		if not _restore_campaign_return(returned):
			_show_title_screen()
			title_screen.show_load_error("Could not restore the open-water route. Choose a saved game.")
	elif not _restart_checkpoint.is_empty():
		var data := _restart_checkpoint
		_restart_checkpoint = {}
		var slot := _resume_slot_after_restart
		_resume_slot_after_restart = -1
		_resume_from_checkpoint.call_deferred(data, slot)
	elif _restart_slot >= 0:
		var restart_slot := _restart_slot
		var restart_latest := _restart_latest
		_restart_slot = -1
		_restart_latest = false
		if await _on_title_load_game(restart_slot, false, restart_latest):
			_announce("You wake back at your last save.")
	else:
		_show_title_screen()
		if not SceneHandoff.checkpoint_load_error.is_empty():
			title_screen.show_load_error(SceneHandoff.checkpoint_load_error)
			SceneHandoff.checkpoint_load_error = ""
	if _dev_requested():
		_start_dev_mode.call_deferred()
	elif _maze_playtest_requested():
		call_deferred("_enter_maze_scene", true)

# Set by _start_dev_mode(): hides the objective line at the top of the screen.
var _dev_mode := false

# Set by _start_dev_mode() (--dev). Battle reads it to show every status.
var dev_mode := false

func _start_dev_mode() -> void:
	dev_mode = true
	_dev_mode = true
	# Explicit command-line diagnostics never claim or write a player slot.
	_current_slot = -1
	route_state.opening_video_seen = true
	route_state.prologue_complete = true
	route_state.set_prologue_phase("complete")
	# Dev mode: every item, including the Maze Navigation Map.
	for id in Items.ITEMS:
		if Items.is_key_item(String(id)):
			if not key_items.has(id):
				key_items.append(id)
		elif String(Items.ITEMS[id].get("kind", "")) == "info":
			inventory[id] = 1
		else:
			inventory[id] = 5
	# Every Combat Help tutorial/replay is unlocked in dev mode.
	special_encounter_left = true
	ability_popups_seen = true
	_save_point_tutorial_seen = true
	route_state.tutorial_complete = true
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
	# Every ability and every spell the unlocked key items allow.
	embedded_maze.key_items = key_items
	for d in divers:
		var diver := d as Diver
		diver.unlock_ability()
		diver.stats.spell_points = 99
		SpellTree.learn_all_available(diver, key_items)
		diver.stats.fill()
	add_child(DevTeleport.new(self))
	# Dev mode: Cordys is always out of his cave, ready to fight.
	embedded_maze._set_cordys_out(true)
	var front := Vector3(263, 2, DeepZoneLayoutScript.MAZE_TRANSITION.z)
	if OS.get_cmdline_user_args().has("--secret-room"):
		var room := embedded_maze._secret_item_room_rect().abs()
		front = Vector3(room.get_center().x, embedded_maze._floor_top_y + 1.2, room.get_center().y)
	elif OS.get_cmdline_user_args().has("--octopus-front"):
		# Diagnostic shortcut: just inside the main boss room's door, facing Cordys
		# (outside his prompt radius).
		var b33 := embedded_maze.get_node("CSGBox3D33") as Node3D
		front = Vector3(b33.global_position.x + 3.0, embedded_maze._floor_top_y + 1.2, embedded_maze._main_boss_door_z)
		yaw = -PI * 0.5   # face east, toward Cordys
	for i in divers.size():
		(divers[i] as Diver).global_position = front + Vector3(-float(i) * 1.5, 0, float(i) * 1.5)
		(divers[i] as Diver).velocity = Vector3.ZERO
	_set_maze_ownership(true)
	_announce("DEV MODE: everything unlocked. G = teleport menu, T = jump to aim. No player save is written.")

# Dev mode only: open the Tethys fight without playing up to it - both route
# blockers beaten, lab available. Entering the lab then starts the cutscene.
func dev_unlock_tethys() -> void:
	route_state.set_blocker_state("bomb_bot", "defeated")
	route_state.set_blocker_state("sword_slayer", "defeated")
	if route_state.lab_state in ["locked", "cleared"] or route_state.tethys_state == "defeated":
		route_state.set_lab_state("available")
		route_state.set_tethys_state("available")
	_sync_deep_zone_blocker_staging()
	_sync_lab_staging()

# Dev mode only (DevTeleport): move the party to `pos`, switching between
# the overworld and the maze if needed.
func dev_teleport(pos: Vector3, to_maze: bool, label: String, look_yaw := NAN) -> void:
	if battling:
		_announce("Can't teleport during a battle.")
		return
	var in_maze := embedded_maze != null and embedded_maze.maze_active
	for i in divers.size():
		var diver := divers[i] as Diver
		diver.global_position = pos + Vector3(-float(i) * 1.5, 0, float(i) * 1.5)
		diver.velocity = Vector3.ZERO
	if not is_nan(look_yaw):
		yaw = look_yaw
		if in_maze and to_maze:
			embedded_maze._yaw = look_yaw
	if to_maze != in_maze:
		_set_maze_ownership(to_maze)
	_announce("Teleported to %s." % label)

var _maze_hidden_hud: Array[CanvasItem] = []

func _maze_hud_keep() -> Array:
	var keep: Array = []
	if hp_bar != null:
		keep.append(hp_bar.get_parent())
	if oxygen_bar != null:
		keep.append(oxygen_bar.get_parent())
	if _party_bars_box != null:
		keep.append(_party_bars_box)
	return keep

func _apply_maze_hud(on: bool) -> void:
	$HUD.visible = true
	$HUD.process_mode = Node.PROCESS_MODE_INHERIT
	if on:
		var keep := _maze_hud_keep()
		_maze_hidden_hud.clear()
		for child in $HUD.get_children():
			var item := child as CanvasItem
			if item != null and item.visible and not keep.has(item):
				item.visible = false
				_maze_hidden_hud.append(item)
	else:
		for item in _maze_hidden_hud:
			if is_instance_valid(item):
				item.visible = true
		_maze_hidden_hud.clear()
		_refresh_world_guidance()

func _restore_campaign_return(session: CampaignSession) -> bool:
	if session == null or session.outer_world_checkpoint.is_empty():
		return false
	session.route_state.set_zone("deep")
	session.route_state.set_maze_door_state("available")
	session.route_state.set_encounter_source("random")
	var data := CampaignCheckpoint.encode(session, "world")
	# Returns place the party just outside the auto-activating entrance radius.
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
	_restart_latest = false
	title_screen.close()
	$HUD.visible = true
	get_tree().paused = false
	_audio_call(&"play_exploration_music")
	_update_hud()
	return true

# Floor and rocks give parallax so motion reads at this scale.
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

	# Darker surface for the eastern extension so the boundary is visible.
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
	# Save point before the laboratory so a Tethys loss isn't a long walk back.
	var lab_save_point := SavePoint.new()
	lab_save_point.name = "LabSavePoint"
	lab_save_point.position = DeepZoneLayoutScript.LAB_SAVE_POINT
	lab_save_point.footprint_offset_y = -1.8
	add_child(lab_save_point)
	_save_points.append(lab_save_point)

	# One non-colliding MultiMesh for scenery rocks (startup cost).
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260814          # fixed seed: same site every run
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

# Invisible perimeter rails along the visible seafloor edge (not on minimap).
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
	# Collision-only roof at four blockade heights; airborne rocks stay reachable.
	_build_invisible_wall(
		Vector3(center_x, WORLD_CEILING_Y + CEILING_THICKNESS * 0.5, 0.0),
		Vector3(span_x, CEILING_THICKNESS, span_z)
	)

func _build_invisible_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

# Breakable reward rocks in open water, clear of sites and the highway.
# Ground rocks give a random consumable; airborne ones hold spell keys or ambushes.
func _build_breakable_rocks() -> void:
	const SPOTS := [
		Vector3(6.0, 1.0, -7.0), Vector3(-7.0, 1.0, 5.0),
		Vector3(-15.0, 1.0, -20.0), Vector3(-3.0, 1.0, -30.0),
		Vector3(-25.0, 1.0, 12.0), Vector3(10.0, 1.0, -15.0),
		Vector3(8.0, 1.0, 22.0),
		# Airborne rocks at 3x blockade height: two spell keys, two ambushes.
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
		# Separate listener for save persistence (rewards handled elsewhere).
		rock.broken.connect(_on_world_object_consumed.bind(id))
		add_child(rock)
		_cracked_walls[id] = rock

# id and spot are bound at connect time; the id links the consumed rock to
# its pending reward across save/load.
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
	var item_id := Items.drop_for_rock(int(id.trim_prefix("rock_")))
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
	# Small cosmetic scatter for the reward pop.
	orb.position = drop_position
	orb.collected.connect(_on_item_orb_collected.bind(id))
	add_child(orb)

# Records `id` as consumed for save/load; doesn't touch the node.
func _on_world_object_consumed(id: String) -> void:
	if not consumed_world_ids.has(id):
		consumed_world_ids.append(id)
	_cracked_walls.erase(id)
	_refresh_world_guidance()

func _on_item_orb_collected(item_id: String, _d: Diver, drop_id: String) -> void:
	pending_world_drops.erase(drop_id)
	_add_to_inventory(item_id)

# Goes into the party inventory; applied later via use_inventory_item().
func _add_to_inventory(item_id: String, announce := true) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	if not announce:
		return
	var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
	_announce("Picked up a %s." % display)

# Applies an inventory item to the active diver (inventory_menu.gd's Use).
# Refuses without spending when Items.would_help() says it wouldn't help.
func use_inventory_item(item_id: String) -> void:
	var count: int = int(inventory.get(item_id, 0))
	if count <= 0 or divers.is_empty():
		return
	var diver: Diver = divers[active]
	# battle_only buffs are reverted only by battle.gd, so refuse them here.
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

# Inventory-tagged moves/spells (BASE_MOVES + known_spells) for the pause menu.
# Mixed shape: BASE_MOVES uses "name", spell defs use "display".
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

# Same oxygen cost as casting in battle.
func can_afford_party_spell(spell: Dictionary, caster: Diver) -> bool:
	# A downed diver can't cast anything, in or out of battle.
	return caster.stats.hp > 0 and caster.stats.oxygen >= float(spell.get("oxygen_cost", 0.0))

# Applies a heal/revive party spell outside battle (same math as battle.gd)
# and deducts oxygen. Unknown effects are a no-op.
func use_party_spell(spell: Dictionary, caster: Diver, target: Diver) -> void:
	if not can_afford_party_spell(spell, caster):
		return
	if String(spell.get("target", "")) == "all_allies":
		_use_party_heal_all(spell, caster)
		return
	var s := target.stats
	var effect := String(spell.get("effect", ""))
	# Validate the target before spending Oxygen: heals only touch the living
	# (they never revive), and a revive only works on someone who is down.
	if effect == "heal" and s.hp <= 0:
		_announce("%s is down - only a revive can help." % _display_name(target.model_name))
		return
	if effect == "heal" and s.hp >= s.hp_max:
		_announce("%s is already at full health." % _display_name(target.model_name))
		return
	if effect == "revive" and s.hp > 0:
		_announce("%s isn't down." % _display_name(target.model_name))
		return
	caster.stats.oxygen -= float(spell.get("oxygen_cost", 0.0))
	var amount := int(spell.get("amount", 0))
	var label := _party_spell_label(spell)
	match effect:
		"heal":
			var before := s.hp
			s.hp = mini(s.hp_max, s.hp + amount)
			var changed := s.hp - before
			if changed > 0:
				_announce("%s - %s recovers %d HP." % [label, _display_name(target.model_name), changed])
			else:
				_announce("%s - %s is already at full health." % [label, _display_name(target.model_name)])
		"revive":
			s.hp = mini(s.hp_max, amount)
			_announce("%s - %s is back up!" % [label, _display_name(target.model_name)])
		_:
			return
	_update_hp_bar()
	_update_oxygen_bar()

# Party-wide heal (Healing Current): every living, hurt diver, one Oxygen cost.
func _use_party_heal_all(spell: Dictionary, caster: Diver) -> void:
	var hurt := divers.filter(func(d: Diver) -> bool: return d.stats.hp > 0 and d.stats.hp < d.stats.hp_max)
	if hurt.is_empty():
		_announce("Everyone is already at full health.")
		return
	caster.stats.oxygen -= float(spell.get("oxygen_cost", 0.0))
	var parts: Array[String] = []
	for d in hurt:
		var before: int = d.stats.hp
		d.stats.hp = mini(d.stats.hp_max, d.stats.hp + int(spell.get("amount", 0)))
		parts.append("%s +%d" % [_display_name(d.model_name), d.stats.hp - before])
	_announce("%s - %s HP." % [_party_spell_label(spell), ", ".join(parts)])
	_update_hp_bar()
	_update_oxygen_bar()

# Dive sites: bowls (berm ring, columns, plinth) joined by beacon trails.
# Guarded item sites get cyan grappleable rings; special sites have none.
func _build_dive_sites() -> void:
	for d in Sites.ALL:
		var site: Site = SiteScript.new()
		add_child(site)
		site.build(d)
		site_nodes[String(d.id)] = site


# The first gate corridor, in order:
#   0. Save point before the entrance blockade.
#   1. Rubble only Mech Pilot's shockwave clears (tall invisible collision).
#   2. A permanent whirlpool over a floor gap; grapple is exempt.
#   3. Far-side grapple anchor; grapple and swap are the only ways across.
#   4. Three lock plates that all need a diver to open the way past END_X.
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
	# Contextual guidance follows this visible room; small margins count approach.
	_puzzle_hint_bounds = AABB(
		Vector3(START_X - 3.0, 0.0, LANE_Z - LANE_HALF_WIDTH - 2.0),
		Vector3(length + 6.0, WALL_HEIGHT + 2.0, LANE_HALF_WIDTH * 2.0 + 4.0)
	)

	# 0. Save point ahead of the entrance blockade.
	var save_point := SavePoint.new()
	save_point.position = Vector3(START_X - 5.0, 2.0, LANE_Z)
	# Contact volume at swimming height; visual footprint on the floor.
	save_point.footprint_offset_y = -1.8
	add_child(save_point)
	# Must stay _save_points[0] (the lab save point is built earlier).
	_save_points.push_front(save_point)

	_build_wall(
		Vector3(center_x, WALL_HEIGHT * 0.5, LANE_Z - LANE_HALF_WIDTH),
		Vector3(length, WALL_HEIGHT, 0.6)
	)
	_build_wall(
		Vector3(center_x, WALL_HEIGHT * 0.5, LANE_Z + LANE_HALF_WIDTH),
		Vector3(length, WALL_HEIGHT, 0.6)
	)

	# 1. The entrance blockade: full lane width and height, shockwave only.
	var entrance_rocks := CrackedWall.new()
	entrance_rocks.span = Vector3(2.0, WALL_HEIGHT, LANE_HALF_WIDTH * 2.0)
	# Invisible collision far above the visible rocks so it can't be swum over.
	entrance_rocks.collision_height = 40.0
	# Invisible collision extends 60 m wide so the gate can't be bypassed.
	entrance_rocks.collision_width = 60.0
	entrance_rocks.position = Vector3(START_X + 1.0, WALL_HEIGHT * 0.5, LANE_Z)
	add_child(entrance_rocks)
	entrance_rocks.broken.connect(_on_world_object_consumed.bind("entrance_blockade"))
	_cracked_walls["entrance_blockade"] = entrance_rocks

	# 2. The gap itself: a dark visual patch plus the whirlpool hazard.
	var gap_center_x := (GAP_START_X + GAP_END_X) * 0.5
	var gap_width := GAP_END_X - GAP_START_X

	# Slightly above the floor (below would be hidden); unshaded to read as void.
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
	whirlpool.floor_visual = true
	whirlpool.position = Vector3(gap_center_x, 2.0, LANE_Z)
	whirlpool.reset_to = Vector3(GAP_START_X - 4.0, 2.0, LANE_Z)
	whirlpool.warned.connect(_on_whirlpool_warned)
	whirlpool.diver_sucked_in.connect(_on_diver_sucked_in)
	add_child(whirlpool)

	# Staging anchor before the gap (not itself a way across).
	var near_anchor := GrappleAnchor.new()
	# Far enough back that the next shot doesn't reselect this anchor.
	near_anchor.position = Vector3(GAP_START_X - 3.0, 2.0, LANE_Z)
	add_child(near_anchor)

	# 3. Far-side anchor; the whirlpool stays armed.
	var anchor := GrappleAnchor.new()
	anchor.position = Vector3(GAP_END_X + 2.0, 2.0, LANE_Z)
	anchor.unlocks_diver_ability_for = "Staff_Diver"
	add_child(anchor)

	# 5. Three lit plates; all occupied (see _check_gap_puzzle) opens the doors.
	var plate_x := lerpf(GAP_END_X, END_X, 0.6)
	for z_off in [-2.5, 0.0, 2.5]:
		var plate := LockPlate.new()
		plate.position = Vector3(plate_x, 2.0, LANE_Z + z_off)
		add_child(plate)
		_lock_plates.append(plate)

		# One door per plate, past the plate's ring; opened by _check_gap_puzzle.
		var door := Door.new()
		door.position = Vector3(plate_x + 3.0, WALL_HEIGHT * 0.5, LANE_Z + z_off)
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
	# The whirlpool shows its own warning caption (see whirlpool.gd).
	pass

func _on_diver_sucked_in(d: Diver, amount: int) -> void:
	_announce("You were sucked into the whirlpool! (-%d HP)" % amount)
	if d == divers[active]:
		_flash_hp_bar()

# Polled: "solved" depends on all three plates at once.
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

# One solid wall segment centered on `center` with dimensions `size`.
func _build_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	# Tag so the wall-reveal area can tell walls from other bodies.
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

	# Minimap segment along the wall's long horizontal axis (walls are axis-aligned).
	if size.x >= size.z:
		_slice_wall_into_pieces(center - Vector3(size.x * 0.5, 0.0, 0.0), center + Vector3(size.x * 0.5, 0.0, 0.0), body)
	else:
		_slice_wall_into_pieces(center - Vector3(0.0, 0.0, size.z * 0.5), center + Vector3(0.0, 0.0, size.z * 0.5), body)

# Splits a wall span into reveal pieces of ~WALL_REVEAL_SEGMENT_LENGTH.
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
		# Sonar has its own physics clock; stop it too or Oxygen keeps draining.
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
	# These menus freeze exploration via this owner; block input here too.
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

	# In aim mode a click means fire/cancel.
	if aiming and e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_fire_aimed_ability()
			return
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_aim()
			return

	# TargetSelector intercepts its keys before camera turning.
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
		# elif chain: one Escape press does only one thing.
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
	# Left-drag look works independently of mouse capture as a fallback.
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

# F depends on the ability: shockwave fires, grapple aims, swap uses TargetSelector.
func _start_ability() -> void:
	if not route_state.prologue_complete or aiming or target_selector.selecting:
		return
	var d: Diver = divers[active]
	if d.shockwave_needs_oxygen() and not _intro_active:
		_announce("Not enough Oxygen for Shockwave (needs %d)." % int(Diver.SHOCKWAVE_OXYGEN_COST))
		return
	if not d.can_use_ability() or _intro_active:
		return
	if d.ability_id == "swap":
		target_selector.start_selection(d)
		_update_hud()
	elif d.ability_needs_aim():
		aiming = true
		# Hide the active diver's rig in first-person aim.
		d.set_model_visible(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_look = true
		_update_hud()
	else:
		d.use_ability(_aim_dir())

# Q toggles sonar for the diver with the sonar passive. Silent no-op until
# the first fight is done.
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
	_update_hud()   # refresh the sonar hint

# Toggles whether new random encounters can start (no tutorial gate).
func _toggle_random_encounters() -> void:
	random_encounters_enabled = not random_encounters_enabled
	escape_encounter_hint.set_encounters_enabled(random_encounters_enabled)
	_announce("Random encounters on." if random_encounters_enabled else "Random encounters off.")
	_update_hud()   # refresh the encounters hint

# Opens only while standing on a save point; not while aiming or selecting.
func _toggle_save_menu() -> void:
	if save_point_menu.visible:
		save_point_menu.close()
		return
	if aiming or target_selector.selecting:
		return
	if not route_state.prologue_complete:
		_announce("Finish your first encounter before saving.")
		return
	# Explain instead of silently doing nothing off a save point.
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

# The menu only emits the request; World writes the save before confirming.
# Restores HP/O2 for the whole party, since damage is shared.
func _manual_save_safe() -> bool:
	if battling or _transitioning_to_encounter or _intro_active or aiming or target_selector.selecting or get_tree().paused:
		return false
	if not route_state.prologue_complete or title_screen.visible or is_instance_valid(random_encounter_reveal) or is_instance_valid(_lab_video_cutscene):
		return false
	if special_encounter_prompt.visible or _special_encounter_item != "" or _special_encounter_diver != null or tutorial_result_popup.visible:
		return false
	if Whirlpool.busy_in(self) or divers.any(func(d: Diver) -> bool: return d.is_grappling() or d.is_suction_locked()):
		return false
	# The other area's puzzle and reward state must be stable to save.
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
	# The chosen slot becomes this run's active checkpoint.
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

# Holds the save prompt while on a save point with the menu closed; clears
# only its own text.
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
			var pages: Array[Dictionary] = [TutorialContent.saving_page()]
			(get_node("/root/CharacterAbilityPopup") as Node).call("open", pages)
		banner.text = "Save your progress."
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

# TargetSelector confirmed a target: fire the active diver's ability at it.
func _on_swap_target_confirmed(target: Node3D) -> void:
	divers[active].use_ability(Vector3.ZERO, target)
	_update_hud()

# TargetSelector cancelled; just restore the HUD.
func _on_swap_target_cancelled() -> void:
	_update_hud()

func _physics_process(dt: float) -> void:
	_t += dt
	_tick_autosave(dt)
	# Run before early returns so the world waypoint can't linger.
	_update_blockade_arrow()
	_update_maze_route_guide()
	if embedded_maze != null and embedded_maze.maze_active:
		active = embedded_maze.active
		if not embedded_maze._battling:
			for diver in divers:
				diver.exploration_paused = not embedded_maze.contains_point(diver.global_position)
		# Keep the shared HP/O2 and party bars current while the maze plays.
		_update_hp_bar()
		_update_oxygen_bar()
		if not embedded_maze.contains_point((divers[active] as Diver).global_position) and embedded_maze.prepare_area_exit():
			_set_maze_ownership(false)
		# The Maze owns this frame even on departure: never swim twice.
		return
	if battling or is_instance_valid(random_encounter_reveal) or inventory_menu.visible or save_point_menu.visible or _checkpoint_saving:
		return
	# Keyboard turning as a fallback to mouse capture; suppressed while
	# target selecting (Left/Right cycle there).
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
		if embedded_maze != null and embedded_maze.contains_point(d.global_position):
			# Parked actors cannot drift or spend Oxygen in an inactive area.
			d.exploration_paused = true
			continue
		d.exploration_paused = false
		# Movement pauses while picking a swap target and during the intro tween.
		if i == active and not target_selector.selecting and not _transitioning_to_encounter:
			d.swim(_player_dir(), _player_rise(), dt)
			# swim() may pause the tree on an encounter roll; stop this frame.
			if is_instance_valid(random_encounter_reveal):
				return
		else:
			# Zero input so inactive divers decelerate and stay put.
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
	_update_maze_route_guide()

func _update_maze_route_guide() -> void:
	if maze_route_guide == null:
		return
	# Derived from the earned milestone; the maze needs no lab prerequisite.
	maze_route_guide.visible = (
		route_state.prologue_complete
		and route_state.lab_state == "cleared"
		and route_state.tethys_state == "defeated"
		and route_state.octopus_state != "defeated"
		and not divers.is_empty()
		and deep_zone_layout.zone_for_position((divers[active] as Diver).global_position) == "deep"
		and not battling and not is_instance_valid(random_encounter_reveal)
		and not aiming and not target_selector.selecting
		and not inventory_menu.visible and not save_point_menu.visible
		and not embedded_maze.maze_active and not get_tree().paused
		and $HUD.visible and cam.current
	)
	if maze_route_guide.visible:
		# Aim just inside the real maze boundary, not at the ramp mouth.
		var ramp := Vector3(embedded_maze.embedded_bounds.position.x + 1, 2, DeepZoneLayoutScript.MAZE_TRANSITION.z)
		maze_route_guide.update_bearing(cam, (divers[active] as Diver).global_position,
			ramp, maxf(route_objective_panel.get_rect().end.y, hud.get_rect().end.y))

func _update_route_zone() -> void:
	if not route_state.prologue_complete or divers.is_empty():
		return
	var physical_zone: String = deep_zone_layout.zone_for_position((divers[active] as Diver).global_position)
	if physical_zone == route_state.zone_id:
		return
	route_state.set_zone(physical_zone)
	if physical_zone == "deep":
		# The maze transition is available on entering Deep regardless of lab state.
		if route_state.maze_door_state == "locked":
			route_state.set_maze_door_state("available")
		if route_state.lab_state != "cleared" and route_state.tethys_state != "defeated":
			route_state.set_objective("find_lab")
		if not route_state.deep_warning_seen:
			route_state.mark_deep_warning_seen()
			_announce("You've entered deeper water. Stronger enemies may appear.")

# Grade the world environment by the active diver's x-position (Deep gradient).
# The battle viewport has its own environment.
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

# Checks the live diver's position. Only Bomb Bot is listed for now.
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

# The unlocked lab door is the one production entry; a latch makes staying
# in the radius harmless.
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
	# Autosave on entering the lab, before the cutscene and the Tethys fight.
	_capture_pre_boss_autosave()
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
	# The maze has its own HUD; hide only overworld-only pieces.
	_apply_maze_hud(on)
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
	embedded_maze.cordys_fight_starting.connect(_capture_pre_boss_autosave)
	add_child(embedded_maze)
	_build_lab_maze_ramp()

func _build_lab_maze_ramp() -> void:
	var start := Vector3(DeepZoneLayoutScript.WORLD_MAX_X, 0, DeepZoneLayoutScript.MAZE_TRANSITION.z)
	var finish := Vector3(embedded_maze.embedded_bounds.position.x, embedded_maze._floor_top_y, start.z)
	var span := finish - start
	var root := Node3D.new()
	root.name = "LabMazeRamp"
	add_child(root)
	# A rotated slab joins both floors so the return stays traversable.
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
	# Ceiling plug: no swimming over the maze ceiling.
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
		# Rigs have large authored offsets: place, measure real mesh bounds, then
		# hover above the floor and the diver.
		var presentation_scale := 1.5 if blocker_id == "bomb_bot" else 1.6
		# Center actual mesh bounds on the field opening (imported roots are offset).
		actor.position = Vector3(point.x - 5.0, 0.0, point.z)
		actor.scale = Vector3.ONE * presentation_scale
		add_child(actor)
		actor.face_toward(Vector3(point.x - 10.0, 0.0, point.z))
		actor.force_update_transform()
		var actor_bounds := _route_actor_visible_bounds(actor)
		if actor_bounds.size.length() > 0.01:
			actor.position.x += point.x - 5.0 - actor_bounds.get_center().x
			actor.position.z += point.z - actor_bounds.get_center().z
			# Hover above the chase-camera diver's silhouette.
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

	# Sparse energy grid and edge pylons make the field's collision legible.
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

# Keeps the intro arrow aimed at the beam and starts the first encounter on
# arrival. Uses a level up-vector when directly above/below the target.
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
	# Measure in XZ only; the beam's origin is at half its height.
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
	# All three divers join the tutorial (CAST order matters for its script).
	_start_battle("", false, "angler", divers, false, true)

# Radius matches minimap.view_radius. monitorable must stay true or
# get_overlapping_bodies() returns nothing.
func _build_wall_sight_area() -> void:
	_wall_sight_area = Area3D.new()
	_wall_sight_area.monitoring = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = minimap.view_radius
	shape.shape = sphere
	_wall_sight_area.add_child(shape)
	add_child(_wall_sight_area)


# Reveals overlapping wall pieces for the minimap fog of war. Coarse pass via
# get_overlapping_bodies(), then per-piece overlap frozen on first reveal.
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

# XZ overlap between a wall piece and the detection area, as two endpoints
# at the piece's Y; [] if none.
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
	# Camera-relative movement: W/A/S/D map to camera forward/left/back/right.
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	# With a look override, forward follows the camera's actual view direction.
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
		# First-person at the same eye height grapple fires from.
		var eye: Vector3 = d.global_position + Vector3(0, d.height * 0.4, 0)
		cam.global_position = cam.global_position.lerp(eye, clampf(dt * 14.0, 0.0, 1.0))
		cam.look_at(eye + dir * 10.0, Vector3.UP)
		return

	var focus: Vector3 = d.global_position + Vector3(0, d.height * 0.35, 0)
	# With a look override, orbit on the diver-to-target axis to keep the diver
	# framed between camera and target.
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

# auto_return_after 0 = until return_camera_to_player(), >0 = timed hold.
func focus_camera_on(target: Node3D, auto_return_after: float = 0.0) -> void:
	camera_mode = CameraMode.FOCUS
	_camera_focus_target = target
	_camera_focus_timer = auto_return_after

func return_camera_to_player() -> void:
	camera_mode = CameraMode.PLAYER
	_camera_focus_target = null
	_camera_focus_timer = 0.0

# A vertical shaft of light; shimmer/pulse/fade are done in the shader.
var light_beam: MeshInstance3D

func render_light_beam() -> void:
	if light_beam != null:
		return

	var shimmer_speed := 1.5
	var pulse_speed := 1.5
	var brightness := 1.5
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
	# Base rests on the seafloor (CylinderMesh is centered on its origin).
	var d: Diver = divers[active]
	# Use local position: Divers may not be in the tree yet during _ready().
	# Keep the beam on the default forward swim axis.
	light_beam.position = d.position + Vector3(0.0, beam_height * 0.5, 10.0)
	add_child(light_beam)

# Guarded item sites keep invisible grapple targets; special sites have none.
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

# Arrow parented in front of the active diver; _point_arrow_at() re-aims it
# at the beam every frame.
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
	# Tip along local -Z so look_at() points it at the target.
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

# Post-tutorial waypoint; waits for tutorial_complete so it never overlaps
# the beam arrow. Cleanup follows the physical target's existence.
func _update_blockade_arrow() -> void:
	var wall := _cracked_walls.get("entrance_blockade") as Node3D
	if not is_instance_valid(wall) or wall.is_queued_for_deletion():
		if is_instance_valid(_blockade_arrow):
			_blockade_arrow.queue_free()
		_blockade_arrow = null
		return
	var available := route_state.prologue_complete and route_state.prologue_phase == "complete" 		and route_state.tutorial_complete and not divers.is_empty()
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


# Intro hint shown in the shared banner alongside the arrow.
func _show_intro_text() -> void:
	_intro_announce("Swim over to the light beam.")


# Camera look direction from yaw/pitch; shared by camera and aimed abilities.
func _aim_dir() -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))

var _aim_marker: MeshInstance3D
var _aim_marker_mat: StandardMaterial3D

# Clamp the reticle's apparent size near surfaces so it can't fill the screen.
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

# Grapple aim preview: green on a valid anchor, gray otherwise.
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

# Fade the banner (exploration only).
func _update_banner(dt: float) -> void:
	if _announcements.current_text().is_empty():
		return # Held intro/save-point prompts are not transient announcements.
	# Reading menus don't consume the banner's time.
	if $HUD.visible and not save_point_menu.visible and not inventory_menu.visible:
		_announcements.advance(dt)
	_banner_timer = _announcements.seconds_left()
	banner.text = _announcements.current_text()

# Entering a guarded item's site starts its encounter directly (active diver
# only). A per-site latch prevents retriggering until the diver leaves.
func _try_trigger_item_site(d: Diver) -> bool:
	if not route_state.prologue_complete or d != divers[active] or battling or _intro_active or _transitioning_to_encounter:
		return false
	var found: Dictionary = {}
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		var radius := float(entry.get("radius", 0.0))
		# Same height window as the minimap's red circle.
		if radius > 0.0 and d.position.distance_to(entry.at as Vector3) <= radius and MiniMap.within_marker_height(d.position.y, (entry.at as Vector3).y):
			found = entry
			break
	if found.is_empty():
		_inside_item_site_id = ""
		return false
	var item_id := String(found.item)
	var site_id := String(found.get("site", item_id))
	if site_id == _inside_item_site_id:
		return true
	_inside_item_site_id = site_id
	# Gone only once beaten and won (not merely because the item is owned).
	if cleared_item_sites.has(site_id):
		return false
	_pending_reward_site = site_id
	var enemy_id := String(found.get("enemy", "angler"))
	if bool(found.get("special", false)):
		_pending_guardian_enemy_id = enemy_id
		_offer_special_encounter(item_id)
	else:
		_start_battle(item_id, false, enemy_id)
	return true

# Distance rolls drive ordinary encounters; site proximity is checked here
# too since both can happen on the same frame.
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
	# Shown immediately; queued announcements only tick during exploration.
	banner.text = _random_encounter_text(selected.size())
	reveal.camera = cam
	# Freeze world physics/status timers; nothing persistent is modified.
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

func _random_encounter_text(count: int) -> String:
	return "Enemies emerge from the murk!" if count > 1 else "An enemy emerges from the murk!"

func _cancel_random_encounter_reveal() -> void:
	if not is_instance_valid(random_encounter_reveal):
		return
	random_encounter_reveal.set_process(false)
	random_encounter_reveal.restore_camera()
	random_encounter_reveal.queue_free()
	random_encounter_reveal = null
	_transitioning_to_encounter = false
	get_tree().paused = false

# First special encounter: skip the prompt and force Maxilani (once).
var player_first_special_encounter := true
func _offer_special_encounter(item_id: String) -> void:
	_special_encounter_item = item_id
	if not player_first_special_encounter:
		get_tree().paused = true
		special_encounter_prompt.open()
	else:
		player_first_special_encounter = false
		# custom_party needs Diver nodes; divers[0] is Maxilani by CAST order.
		var maxilani: Diver = divers[0]
		# Battle can't stage a downed party member; make sure she's alive.
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

# Only react for the diver currently being steered.
func _on_diver_swapped(target: Diver, d: Diver) -> void:
	if embedded_maze != null and embedded_maze.maze_active:
		return
	if d != divers[active]:
		return
	focus_camera_on(target, 1.1)

# reward_item "" means an ordinary fight with no reward.
func _start_battle(reward_item: String = "", boss_encounter: bool = false, guardian_enemy_id: String = "angler", custom_party: Array = [], special: bool = false, tutorial: bool = false, intro_text: String = "", authored_enemy: bool = false, revealed_enemy_ids: Array[String] = []) -> void:
	for diver in divers:
		diver.exploration_paused = true
	_cancel_random_encounter_reveal()
	escape_encounter_hint.dismiss()
	battling = true
	_update_maze_route_guide() # Hide before Battle pauses exploration frames.
	Whirlpool.refresh_in(self)
	if boss_encounter:
		_audio_call(&"play_tethys_music")
	elif route_state.encounter_source == "prologue_angler":
		_audio_call(&"play_prologue_battle_music")
	else:
		_audio_call(&"play_battle_music")
	inventory_menu.close()   # shouldn't be open during a battle
	_pending_reward_item = reward_item
	# Remember the site only when the fight carries its reward.
	_battle_reward_site = _pending_reward_site if reward_item != "" else ""
	_pending_reward_site = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE      # buttons need the cursor back
	mouse_look = false
	if boss_encounter:
		# The lab Battle announces this itself; don't add a World banner. Keep the
		# queue intact.
		if route_state.encounter_source != "lab_boss":
			_announce("Tethys rises from the deep!")
	elif tutorial:
		# Clear the non-expiring intro banner so it doesn't linger through the fight.
		banner.text = ""
		_banner_timer = 0.0
	elif reward_item != "":
		# The carrier notice belongs in the combat log, not a world banner.
		banner.text = ""
		_banner_timer = 0.0
	else:
		# Random encounters already announced during the reveal; others narrate in
		# the battle log.
		banner.text = ""
		_banner_timer = 0.0
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
	for diver in divers:
		(diver as Diver).reset_passives_after_battle()
	var was_special := battle.special_encounter
	var was_tutorial := battle.tutorial_encounter
	if was_special:
		special_encounter_left = true
	var was_lab_boss := battle.boss_encounter and battle.encounter_source == "lab_boss"
	var route_blocker_id := _active_route_blocker_id
	battle.queue_free()
	battle = null
	battling = false
	# Restore exploration music once Battle releases the screen. A normal loss
	# goes to _show_game_over() below.
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
		# The intro beam's job is done once the tutorial fight ends.
		if route_state.tutorial_complete and is_instance_valid(light_beam):
			light_beam.queue_free()
			light_beam = null
		# Don't persist the training result; save only after recovery below.
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
			# Point the player toward the (already available) maze after the lab victory.
			route_state.set_objective("enter_maze")
		else:
			# Keep the live state retryable so the route can't get stuck `in_progress`.
			route_state.set_lab_state("available")
			route_state.set_tethys_state("available")
			route_state.set_objective("enter_lab")
		route_state.set_encounter_source("random")
		_sync_lab_staging()
		if result == "won":
			_write_save()
			_autosave_after_tethys()
			call_deferred("_show_lab_payoff")
	match result:
		"won":
			if was_special and _special_encounter_diver != null:
				# Win or lose, restore the pre-encounter HP/O2 snapshot.
				_special_encounter_diver.stats.hp = _special_encounter_pre_hp
				_special_encounter_diver.stats.oxygen = _special_encounter_pre_oxygen
				_update_hp_bar()
				_update_oxygen_bar()
			# The first special encounter is practice: no item grant and no banner.
			if was_special and was_tutorial:
				pass
			elif _pending_reward_item != "":
				_grant_reward_item(_pending_reward_item)
				if _battle_reward_site != "" and not cleared_item_sites.has(_battle_reward_site):
					cleared_item_sites.append(_battle_reward_site)
			elif was_tutorial:
				pass   # no banner after the tutorial fight (the battle already said it all)
			elif was_lab_boss:
				_announce("Tethys is defeated. The blue-lit maze passage is now your next route.")
			elif route_blocker_id == "bomb_bot":
				_announce("Bomb Bot powers down. The path to Sword Slayer is open.")
			elif route_blocker_id == "sword_slayer":
				_announce("Sword Slayer falls back. The laboratory entrance is open.")
			else:
				_announce("The enemy backs off into the dark.")
			if was_tutorial:
				# Heal after a win so nobody downed carries into the next battle.
				for d in divers:
					var s: CombatantStats = (d as Diver).stats
					s.hp = s.hp_max
					s.oxygen = s.oxygen_max
				_update_hp_bar()
				_update_oxygen_bar()
		"fled":
			_announce("You successfully ran away.")
			# The HUD badge by the HP bar already shows the encounters setting.
		"skipped":
			# In-battle "Skip Tutorial": same recovery as a loss's "Exit to World".
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
				# First-fight loss offers Retry/Exit instead of game over; handlers do their
				# own cleanup.
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
	# The first special encounter is also tutorial_encounter; only the combat
	# tutorial shows the onboarding carousel.
	if was_tutorial and not was_special:
		# Deferred: open() pauses the tree, so let this handler finish first.
		_write_save()
		# First time only: Combat Help replays don't repeat the onboarding
		# (it stays available from the Esc menu's Character Abilities button).
		if not ability_popups_seen:
			call_deferred("_show_ability_popups")

# Heal and return to the overworld. Freeing `battle` here matters only for
# the tutorial-loss playtest, which never goes through _on_battle_finished().
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
	# Not after the first special encounter (see _on_battle_finished()).
	if not _tutorial_loss_was_special:
		_first_encounter_started = false
		for i in range(divers.size()):
			(divers[i] as Diver).position = CAST[i].at as Vector3
		_build_forced_tutorial_beam()
		_write_save()
		if not ability_popups_seen:
			call_deferred("_show_ability_popups")

# --tutorial-loss-playtest entry: straight to the real tutorial loss popup.
func _show_tutorial_loss_playtest() -> void:
	title_screen.close()
	$HUD.visible = true
	get_tree().paused = false
	# Short wait so the world settles before building a battle scene.
	await get_tree().create_timer(1.0).timeout
	# Start a real tutorial battle so the popup appears over it as in a real loss.
	_start_battle("", false, "angler", divers, false, true)
	call_deferred("_open_tutorial_loss_playtest_popup")

func _open_tutorial_loss_playtest_popup() -> void:
	# This route is the plain tutorial fight; reset the special flag.
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

# Retry of the first special encounter: relaunch the forced solo Maxilani
# fight with the same item/enemy, healing her first.
func _replay_special_encounter_tutorial(item_id: String = "", enemy_id: String = "") -> void:
	# Combat Help uses a stable setup; Retry leaves these blank to reuse the
	# failed encounter's reward/site and enemy.
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

# The single tutorial fight definition (Retry and Combat Help replay).
# Heals first.
func _replay_tutorial_battle() -> void:
	for d in divers:
		var s: CombatantStats = (d as Diver).stats
		s.hp = s.hp_max
		s.oxygen = s.oxygen_max
	_update_hp_bar()
	_update_oxygen_bar()
	_start_battle("", false, "angler", divers, false, true)

# Key items go to party-wide key_items; anything else to the shared inventory.
func _grant_reward_item(item_id: String) -> void:
	if Items.is_key_item(item_id):
		# Announced in the battle's combat log (Battle._win).
		if not key_items.has(item_id):
			key_items.append(item_id)
		return
	# Announced in the battle's combat log (Battle.reward_claim_text()).
	_add_to_inventory(item_id, false)

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

# One Slot per diver, needed by _show_ability_popups().
func _build_diver_slots() -> void:
	# Not parented to $HUD until icon art exists; set_diver()/set_highlighted()
	# work outside the tree.
	for d in divers:
		var slot: Slot = SLOT_SCENE.instantiate()
		slot.set_diver(d as Diver)
		_diver_slots.append(slot)

# _diver_slots live outside the tree, so free them explicitly.
func _exit_tree() -> void:
	_cancel_random_encounter_reveal()
	for slot_value in _diver_slots:
		var slot := slot_value as Slot
		if is_instance_valid(slot) and not slot.is_inside_tree():
			slot.free()
	_diver_slots.clear()


# Ability onboarding pages after the tutorial fight, in party order. Text lives
# on slot.gd; _diver_slots[i] must match CAST order.
func _show_ability_popups() -> void:
	if _diver_slots.is_empty():
		return
	var first: Slot = _diver_slots[0]
	var pages: Array[Dictionary] = [
		{"slot": null, "title": "The World Map", "body": first.worldExplanation, "media": "world"},
	]
	if _diver_slots.size() > 0:
		var maxilani: Slot = _diver_slots[0]
		# Swap and Sonar get separate pages (each has its own clip).
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
		"body": "Press " + Slot._badge("Esc") + " to access the inventory menu where you can use items, diver spells and access any tutorials from Combat Help.",
	})
	# get_node() instead of the bare autoload name so headless --script runs compile.
	(get_node("/root/CharacterAbilityPopup") as Node).call("open", pages, self)
	ability_popups_seen = true

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
	# Keep text out of the minimap's 166 px top-right corner.
	var compact := viewport_size.x < 600.0
	var right_limit := maxf(160.0 if compact else 304.0, viewport_size.x - 176.0)
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.offset_left = 16.0
	hud.offset_top = 12.0
	hud.offset_right = right_limit
	hud.offset_bottom = 166.0 if compact else 68.0
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_theme_font_size_override("font_size", 14 if viewport_size.x < 900.0 else 16)

	_layout_route_objective_panel()

# Guidance panel: centred, clear of the minimap and the side bars.
func _layout_route_objective_panel() -> void:
	if route_objective_panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 600.0
	var right_limit := maxf(160.0 if compact else 304.0, viewport_size.x - 176.0)
	var panel_width := viewport_size.x - 32.0 if compact else minf(570.0, maxf(288.0, right_limit - 32.0))
	var panel_left := clampf(
		(viewport_size.x - panel_width) * 0.5,
		16.0,
		maxf(16.0, right_limit - panel_width)
	)
	var panel_top := maxf(176.0, _controls_text_bottom() + 8.0) if compact else 74.0
	if _party_bars_box != null and _party_bars_box.is_visible_in_tree():
		var bars := _party_bars_box.get_global_rect()
		var bars_right := bars.end.x + 12.0
		if panel_left < bars_right:
			if right_limit - bars_right >= 280.0:
				panel_left = bars_right
				panel_width = minf(panel_width, right_limit - bars_right)
			else:
				panel_top = maxf(panel_top, bars.end.y + 8.0)
	route_objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	route_objective_panel.offset_left = panel_left
	route_objective_panel.offset_top = panel_top
	route_objective_panel.offset_right = panel_left + panel_width
	route_objective_panel.offset_bottom = panel_top + 44.0

func _show_lab_payoff() -> void:
	if route_state.lab_state != "cleared" or route_state.tethys_state != "defeated":
		return
	# Brief computer message on the paged input-exclusive surface; `cleared`
	# already persists it.
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
	if _post_tethys_autosave_text != "":
		_announce(_post_tethys_autosave_text)
		_post_tethys_autosave_text = ""

func _on_route_objective_changed(_objective_id: String) -> void:
	_refresh_world_guidance()

func _refresh_world_guidance() -> void:
	if route_objective_panel == null or route_objective_label == null:
		return
	var text := ""
	if _dev_mode:
		pass   # dev mode: no objectives
	elif route_state.prologue_complete and not divers.is_empty():
		var position := (divers[active] as Diver).global_position
		if deep_zone_layout.zone_for_position(position) == "deep":
			text = route_state.exploration_goal("deep")
		elif not route_state.tutorial_complete:
			text = ""   # the tutorial's light-beam arrow owns guidance
		elif position.x < PUZZLE_DOORS_X:
			# Until the party is through the ringed lock-plate doors.
			text = "Explore the mysterious blockade."
		else:
			text = "Explore the deep sea."
	route_objective_label.text = text
	route_objective_panel.visible = text != ""
	_layout_route_objective_panel()


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
	# Only for the diver that has the sonar passive.
	if d.passive_id == "sonar":
		line += (" · Q:Sonar %s" if narrow else "  ·  Q: Sonar (%s)") % ("On" if d.sonar_active else "Off")
	line += (" · R:Random %s" if narrow else "  ·  R: Random Encounters (%s)") % ("On" if random_encounters_enabled else "Off")
	hud.text = line

# Active diver's HP bar during exploration, styled like Battle's bars.
var hp_bar: ProgressBar
var hp_bar_label: Label
var _hp_bar_mat: StyleBoxFlat

# Shared font size for the HP and O2 bar labels.
const WORLD_HUD_LABEL_FONT_SIZE := 14

func _build_hp_bar() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wrap.offset_top = -56.0
	wrap.offset_bottom = -10.0
	wrap.add_theme_constant_override("separation", 4)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	# Informational; must not eat minigame mouse input.
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(wrap)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(220, 20)
	hp_bar.show_percentage = false
	hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# IGNORE doesn't cascade to children.
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar_mat = StyleBoxFlat.new()
	_hp_bar_mat.bg_color = Color(0.78, 0.15, 0.15)
	hp_bar.add_theme_stylebox_override("fill", _hp_bar_mat)
	wrap.add_child(hp_bar)

	# Blue Random Encounters On/Off badge, a child of the HP bar on its left.
	encounter_indicator = PanelContainer.new()
	encounter_indicator.name = "EncounterIndicator"
	encounter_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	encounter_indicator.anchor_left = 0.0
	encounter_indicator.anchor_right = 0.0
	encounter_indicator.anchor_top = 0.5
	encounter_indicator.anchor_bottom = 0.5
	encounter_indicator.offset_left = -8.0
	encounter_indicator.offset_right = -8.0
	encounter_indicator.offset_top = -11.0
	encounter_indicator.offset_bottom = 11.0
	encounter_indicator.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	encounter_indicator.grow_vertical = Control.GROW_DIRECTION_BOTH
	_encounter_indicator_style = StyleBoxFlat.new()
	_encounter_indicator_style.set_corner_radius_all(4)
	_encounter_indicator_style.set_border_width_all(1)
	_encounter_indicator_style.content_margin_left = 7.0
	_encounter_indicator_style.content_margin_right = 7.0
	_encounter_indicator_style.content_margin_top = 1.0
	_encounter_indicator_style.content_margin_bottom = 1.0
	encounter_indicator.add_theme_stylebox_override("panel", _encounter_indicator_style)
	encounter_indicator_label = Label.new()
	encounter_indicator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	encounter_indicator_label.add_theme_font_size_override("font_size", 12)
	encounter_indicator.add_child(encounter_indicator_label)
	hp_bar.add_child(encounter_indicator)
	_update_encounter_indicator()

	hp_bar_label = Label.new()
	hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_label.add_theme_font_size_override("font_size", WORLD_HUD_LABEL_FONT_SIZE)
	wrap.add_child(hp_bar_label)

var encounter_indicator: PanelContainer
var encounter_indicator_label: Label
var _encounter_indicator_style: StyleBoxFlat
var _encounter_indicator_state := ""

# Bright when on, dim when off; shorter label on narrow screens.
func _update_encounter_indicator() -> void:
	if encounter_indicator == null:
		return
	var narrow := get_viewport().get_visible_rect().size.x < 640.0
	var state := "%s|%s" % [random_encounters_enabled, narrow]
	if state == _encounter_indicator_state:
		return
	_encounter_indicator_state = state
	var on := random_encounters_enabled
	encounter_indicator_label.text = ("Enc %s" if narrow else "Random Encounters: %s") % ("ON" if on else "OFF")
	_encounter_indicator_style.bg_color = Color(0.13, 0.42, 0.85, 0.92) if on else Color(0.08, 0.14, 0.26, 0.85)
	_encounter_indicator_style.border_color = Color(0.55, 0.78, 1.0) if on else Color(0.25, 0.36, 0.55)
	encounter_indicator_label.add_theme_color_override("font_color", Color.WHITE if on else Color(0.55, 0.65, 0.8))

# Non-active divers' HP/O2 down the left edge; rebuilt on TAB.
var _party_bars_box: VBoxContainer
var _party_bar_rows: Array[Dictionary] = []

func _build_party_bars() -> void:
	_party_bars_box = VBoxContainer.new()
	_party_bars_box.name = "PartyBars"
	_party_bars_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_bars_box.add_theme_constant_override("separation", 14)
	_party_bars_box.position = Vector2(16.0, 76.0)
	$HUD.add_child(_party_bars_box)
	for i in range(divers.size()):
		# Same shape and look as the active diver's bottom-centre pair: the O2
		# bar with its "O2   x / y" label, then the HP bar with "Name   x / y".
		var row := VBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		var o2 := _party_bar(Color(0.25, 0.65, 0.85), 14.0)
		row.add_child(o2)
		var o2_label := _party_bar_label()
		row.add_child(o2_label)
		var hp := _party_bar(Color(0.78, 0.15, 0.15), 20.0)
		row.add_child(hp)
		var hp_label := _party_bar_label()
		row.add_child(hp_label)
		_party_bars_box.add_child(row)
		_party_bar_rows.append({"row": row, "hp": hp, "hp_label": hp_label, "o2": o2, "o2_label": o2_label})

func _party_bar(fill_color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220.0, height)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _party_bar_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = 220.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", WORLD_HUD_LABEL_FONT_SIZE)
	return label

# Bottom of the top-left controls text (maze's or the world's wrapped label).
func _controls_text_bottom() -> float:
	if embedded_maze != null and embedded_maze.maze_active:
		var block := embedded_maze.get_node_or_null("HUD/MazeExplorationControls") as Control
		if block != null:
			var bottom := block.get_global_rect().end.y
			for child in block.get_children():
				if child is Control and (child as Control).visible:
					bottom = maxf(bottom, (child as Control).get_global_rect().end.y)
			return bottom
	if hud == null or not hud.visible:
		return 0.0
	var lines := maxi(1, hud.get_line_count())
	var spacing := float(hud.get_theme_constant("line_spacing"))
	var text_height := lines * hud.get_line_height() + maxi(0, lines - 1) * spacing
	return hud.global_position.y + maxf(text_height, 0.0)

# Bars hide while a full-screen surface is open.
func _sync_overlay_hud() -> void:
	if not is_inside_tree() or hp_bar == null:
		return
	var covered := (inventory_menu != null and inventory_menu.visible) \
		or (save_point_menu != null and save_point_menu.visible) \
		or _maze_nav_map_open() or _maze_menu_open()
	for wrap in [hp_bar.get_parent(), oxygen_bar.get_parent() if oxygen_bar != null else null, _party_bars_box]:
		if wrap != null and is_instance_valid(wrap):
			(wrap as CanvasItem).visible = not covered

# The maze runs its own Esc inventory menu and save menu instances.
func _maze_menu_open() -> bool:
	if embedded_maze == null or not embedded_maze.maze_active:
		return false
	var menu := embedded_maze.get("inventory_menu") as Control
	var save_menu := embedded_maze.get("_save_menu") as Control
	return (menu != null and menu.visible) or (save_menu != null and save_menu.visible)

func _maze_nav_map_open() -> bool:
	if embedded_maze == null or not embedded_maze.maze_active:
		return false
	var nav := embedded_maze.get_node_or_null("HUD/MazeMiniMap")
	return nav != null and nav.get("main_map") != null and (nav.main_map as Control).visible

func _update_party_bars() -> void:
	if _party_bars_box == null:
		return
	# Follow the controls text down if it wraps.
	_party_bars_box.position.y = maxf(76.0, _controls_text_bottom() + 10.0)
	for i in range(_party_bar_rows.size()):
		var row := _party_bar_rows[i]
		var d := divers[i] as Diver
		(row.row as Control).visible = i != active
		if i == active:
			continue
		var hp := row.hp as ProgressBar
		hp.max_value = d.stats.hp_max
		hp.value = d.stats.hp
		(row.hp_label as Label).text = "%s   %d / %d" % [_display_name(d.model_name), d.stats.hp, d.stats.hp_max]
		var o2 := row.o2 as ProgressBar
		o2.max_value = d.stats.oxygen_max
		o2.value = d.stats.oxygen
		(row.o2_label as Label).text = "O2   %d / %d" % [int(d.stats.oxygen), int(d.stats.oxygen_max)]

func _update_hp_bar() -> void:
	_update_encounter_indicator()
	_update_party_bars()
	var d: Diver = divers[active]
	hp_bar.max_value = d.stats.hp_max
	hp_bar.value = d.stats.hp
	hp_bar_label.text = "%s   %d / %d" % [_display_name(d.model_name), d.stats.hp, d.stats.hp_max]

# O2 bar above the HP bar, updated every physics frame.
var oxygen_bar: ProgressBar
var oxygen_bar_label: Label

func _build_oxygen_bar() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# 40px band with an 8px gap above the HP bar.
	wrap.offset_top = -104.0
	wrap.offset_bottom = -64.0
	wrap.add_theme_constant_override("separation", 4)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	# Informational; must not eat mouse input.
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(wrap)

	oxygen_bar = ProgressBar.new()
	oxygen_bar.custom_minimum_size = Vector2(220, 14)
	oxygen_bar.show_percentage = false
	oxygen_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# IGNORE doesn't cascade to children.
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

# Green cone marking the active diver (same shape as TargetSelector's cursor).
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

# Follows the active diver each frame; hidden while selecting, aiming or battling.
func _update_active_cursor() -> void:
	if battling or aiming or target_selector.selecting or divers.is_empty():
		_active_cursor.visible = false
		return
	var d: Diver = divers[active]
	_active_cursor.visible = true
	_active_cursor.global_position = d.global_position + Vector3.UP * (d.height + 0.5)

# Brief extra flash on top of the value drop.
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
