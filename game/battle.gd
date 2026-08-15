# The fight, in 3D, driven by SALVAGE's combat sim.
#
# The sim is the authority on everything: whose turn it is, what is legal,
# what an attack costs, what the enemy has announced. Nothing here decides a
# rule. This scene's whole job is to put the sim's state where a player can
# see it and to play the motion the models already have.
#
# The stations are the reason this wants to be 3D. FRONT, FLANK, UNDER and
# REAR were abstract positions in a 2D game; here they are places you can
# see somebody standing, and "who is standing where when the gun comes
# round" reads off the screen instead of off a label.
extends Node3D

const RIGGED := preload("res://art/characters/Main_Team_Rigging.fbx")
const GOBLIN := preload("res://GoblinGrunt.fbx")
const ActorScript := preload("res://game/actor.gd")

# Which clip belongs to which diver and which ability. SALVAGE named its
# abilities after these clips on purpose, so this table is a lookup rather
# than an invention. Keyed by roster index, matching sim/combat.gd.
const RIGS := [
	{"mesh": "Diver_Full_Gear", "prefix": "rig|", "idle": "Scuba_Idle1", "hurt": "Scuba_Damaged1",
	 "abilities": {"Axe Kick": "Scuba_Axe_Kick", "Double Knee": "Scuba_Double_Knee"}},
	{"mesh": "Prototype_1(1910)", "prefix": "rig_001|", "idle": "Prototype1_Idle1", "hurt": "Prototype1_Damaged",
	 "abilities": {"Palm Strike": "Prototype1_Palm_Strike", "Dual Palm": "Prototype1_DualPalm"}},
	{"mesh": "Prototype_V(1922)", "prefix": "rig_002|", "idle": "Proto5_Idle", "hurt": "Proto5_damaged",
	 "abilities": {"Piston Swing": "Proto5_Attck1", "Wide Sweep": "Proto5_Attck2"}},
]

# The enemy has Idle, Shooting1, Shooting2, Taunt1, Walking and no damage
# reaction. Getting hit is shown by a flash rather than a clip, because
# inventing a motion nobody authored is how a rig starts lying.
const ENEMY_RIG := {"mesh": "GoblinGrunt", "prefix": "rig|", "idle": "Idle",
	"attacks": ["Shooting1", "Shooting2"], "taunt": "Taunt1"}

# The board, seen from a fixed camera. UNDER used to sit 1.25m below the
# floor, which buried the diver standing there up to the shoulders and read
# as a bug rather than a station. It is in close now instead of underneath,
# which is what the name meant anyway.
const STATION_POS := {
	0: Vector3(0.0, 0.0, 4.0),      # FRONT
	1: Vector3(3.8, 0.0, 1.2),      # FLANK
	2: Vector3(-2.0, 0.0, 1.8),     # UNDER, in close
	3: Vector3(0.0, 0.0, -3.8),     # REAR
	4: Vector3(0.8, 0.0, 7.6),      # BACKLINE
}

# The rigged delivery is a CLAY BAKE: 132 bones and 45 clips, and not one
# texture on any of the three. The textured delivery is the other file, and
# that one has no rig. Until one file has both, the divers are told apart by
# colour rather than by material, which is a stopgap and is meant to look
# like one.
const RIG_TINT := [
	Color(0.42, 0.62, 0.72),   # Scuba, wetsuit
	Color(0.94, 0.58, 0.26),   # Drum, orange hardsuit
	Color(0.72, 0.68, 0.58),   # Brass, the big suit
]

signal finished(outcome: String)

var encounter := "goblin"
var combat: Combat
var actors: Array = []            # index matches combat.divers
var enemy: RiggedActor
var selected := 0
var _phase := "player"            # player | enemy_windup | enemy_settle
var _timer := 0.0
var _hp_before: Array = []
var _popups: Array = []
var _pulse := 0.0

var rings: Dictionary = {}

@onready var cam: Camera3D = $Camera3D
@onready var hud: Control = $HUD/Root

func _ready() -> void:
	combat = Combat.new(encounter)
	_build_stage()
	_build_actors()
	_frame_camera()
	hud.combat = combat
	hud.tint_of = RIG_TINT
	hud.station_dir = Callable(self, "_screen_dir")
	hud.chose.connect(_do)
	hud.ended_turn.connect(_end_turn)
	hud.picked_diver.connect(func(i: int): selected = i; _refresh())
	hud.dismissed.connect(func(): finished.emit(combat.outcome))
	_refresh()

# Which way is that station, on screen, from where this diver stands? The move
# button draws an arrow with it, so the button explains itself by pointing at
# the answer instead of naming it.
func _screen_dir(to_station: int, from_station: int) -> Vector2:
	var a: Vector2 = cam.unproject_position(_place(from_station) + Vector3(0, 0.6, 0))
	var b: Vector2 = cam.unproject_position(_place(to_station) + Vector3(0, 0.6, 0))
	var d := b - a
	return d.normalized() if d.length() > 1.0 else Vector2.RIGHT

# Frame the whole board from the stations themselves, so moving a station
# never quietly pushes somebody out of shot.
func _frame_camera() -> void:
	var box := AABB(Vector3.ZERO, Vector3.ZERO)
	for s in combat.OPEN_STATIONS:
		box = box.expand(_place(int(s)))
	box = box.grow(1.6)
	var centre: Vector3 = box.get_center() + Vector3(0.0, 1.0, 0.0)
	var vp: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var htan: float = tan(deg_to_rad(cam.fov * 0.5)) * (vp.x / maxf(1.0, vp.y))
	var span: float = maxf(box.size.x, box.size.z) * 0.72
	var dist: float = span / htan
	# offset to the right so the readout on the left does not sit on anybody
	cam.position = centre + Vector3(0.66, 0.40, 0.86).normalized() * dist + Vector3(2.2, 0.0, 0.0)
	cam.look_at(centre + Vector3(1.9, 0.1, 0.0), Vector3.UP)

func _build_stage() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.14, 0.21, 0.22)
	fm.roughness = 1.0
	floor_mesh.material_override = fm
	add_child(floor_mesh)

	# a ring marker per open station, so the geography the sim talks about
	# is visible on the floor rather than implied by where somebody stands
	for s in combat.OPEN_STATIONS:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.72
		torus.outer_radius = 0.86
		ring.mesh = torus
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.35, 0.55, 0.6)
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = rm
		ring.position = _place(int(s)) + Vector3(0, 0.03, 0)
		ring.name = "ring_%d" % int(s)
		add_child(ring)
		rings[int(s)] = ring

func _place(station: int) -> Vector3:
	return STATION_POS.get(station, Vector3.ZERO)

func _build_actors() -> void:
	enemy = ActorScript.new()
	add_child(enemy)
	enemy.setup(GOBLIN, ENEMY_RIG.mesh, ENEMY_RIG.prefix, ENEMY_RIG.idle)
	enemy.position = Vector3.ZERO

	actors = []
	for d in combat.divers:
		var r: Dictionary = RIGS[int(d.id) % RIGS.size()]
		var a: RiggedActor = ActorScript.new()
		add_child(a)
		a.setup(RIGGED, String(r.mesh), String(r.prefix), String(r.idle))
		a.tint(RIG_TINT[int(d.id) % RIG_TINT.size()])
		a.position = _place(int(d.station))
		a.face(Vector3.ZERO)
		actors.append(a)
	enemy.face(_place(int(combat.divers[0].station)))

func _process(dt: float) -> void:
	_pulse += dt
	for i in range(actors.size()):
		var d = combat.divers[i]
		var want: Vector3 = _place(int(d.station))
		var a: RiggedActor = actors[i]
		a.position = a.position.lerp(want, clampf(dt * 4.0, 0.0, 1.0))
		a.visible = not d.down
		if not d.down:
			a.face(Vector3.ZERO)

	for n in _popups.duplicate():
		var lab := n as Label3D
		if not is_instance_valid(lab):
			_popups.erase(n)
			continue
		lab.position.y += dt * 1.1
		lab.modulate.a -= dt * 0.8
		if lab.modulate.a <= 0.0:
			_popups.erase(n)
			lab.queue_free()

	_light_rings()

	if _phase == "enemy_windup":
		_timer -= dt
		if _timer <= 0.0:
			_resolve_enemy()
	elif _phase == "enemy_settle":
		_timer -= dt
		if _timer <= 0.0:
			_phase = "player"
			_refresh()

# The announced attack, shown on the floor rather than described in a
# sentence: the ring you are about to be hit on turns red and pulses.
func _light_rings() -> void:
	var hot: Array = combat.threatened_stations() if combat != null else []
	for st in rings.keys():
		var mat: StandardMaterial3D = (rings[st] as MeshInstance3D).material_override
		if int(st) in hot:
			var p := 0.6 + 0.4 * sin(_pulse * 6.0)
			mat.albedo_color = Color(0.96, 0.35, 0.28) * p
		else:
			mat.albedo_color = Color(0.35, 0.55, 0.6)

# ---- turn flow ---------------------------------------------------------

func _do(action: Dictionary) -> void:
	if _phase != "player" or combat.outcome != "ongoing":
		return
	var i := int(action.i)
	var before_hp: Array = _limb_hp()
	if not Bots.apply(combat, action):
		return
	# play the motion the action actually was, not a generic swing
	if String(action.kind) == "attack":
		var d = combat.divers[i]
		var ability := String((d.kit[int(action.get("slot", 0))] as Dictionary).name)
		var clip := String((RIGS[i % RIGS.size()].abilities as Dictionary).get(ability, ""))
		if clip != "":
			(actors[i] as RiggedActor).act(clip)
		var after: Array = _limb_hp()
		for li in range(after.size()):
			var lost: int = int(before_hp[li]) - int(after[li])
			if lost > 0:
				_popup(li, lost)
	_refresh()

func _end_turn() -> void:
	if _phase != "player" or combat.outcome != "ongoing":
		return
	_hp_before = []
	for d in combat.divers:
		_hp_before.append(int(d.hp))
	# the enemy winds up in front of you before anything lands: the sim
	# announced this attack a turn ago and the motion should agree with it
	var pick: String = String(ENEMY_RIG.attacks[combat.turn % (ENEMY_RIG.attacks as Array).size()])
	var threatened: Array = combat.threatened_stations()
	if not threatened.is_empty():
		enemy.face(_place(int(threatened[0])))
	var len_s: float = enemy.act(pick)
	_phase = "enemy_windup"
	_timer = maxf(0.45, len_s * 0.65)
	_refresh()

func _resolve_enemy() -> void:
	combat.end_turn()
	for i in range(combat.divers.size()):
		var d = combat.divers[i]
		if i < _hp_before.size() and int(d.hp) < int(_hp_before[i]) and not d.down:
			var hurt := String(RIGS[i % RIGS.size()].hurt)
			(actors[i] as RiggedActor).act(hurt)
	_phase = "enemy_settle"
	_timer = 0.8
	_refresh()
	if combat.outcome != "ongoing":
		finished.emit(combat.outcome)

# The enemy has no damage-reaction clip, so damage is SHOWN as a number over
# the limb that took it rather than mimed with a motion nobody authored.
func _popup(limb: int, amount: int) -> void:
	var lab := Label3D.new()
	lab.text = "-%d" % amount
	lab.font_size = 64
	lab.pixel_size = 0.004
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1.0, 0.72, 0.4)
	lab.no_depth_test = true
	lab.position = Vector3(0.0, 1.9 + 0.25 * float(limb), 0.0)
	enemy.add_child(lab)
	_popups.append(lab)

func _limb_hp() -> Array:
	return combat.limb_hp.duplicate()

# ---- the readout ------------------------------------------------------
#
# There is nothing to build here any more. game/battle_hud.gd draws the whole
# fight every frame from the sim, so "refresh" is telling it what changed.

func _refresh() -> void:
	hud.combat = combat
	hud.selected = selected
	hud.locked_out = _phase != "player"
