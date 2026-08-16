# One rigged character on the battle stage.
#
# The rigged FBX carries three characters and a single AnimationPlayer whose
# track paths are relative to that file's own tree. Splitting the rigs apart
# breaks every path, so each actor instantiates the whole file and hides the
# meshes it is not. Meshes and animations are shared resources, so three
# instances of a 31 MB file is three node trees, not three copies of the art.
#
# All 15 clips exist under every rig prefix, so any character can play any
# motion. Which clip belongs to which ability is a table, not a guess:
# SALVAGE named its abilities after these clips deliberately.
class_name RiggedActor
extends Node3D

var anim: AnimationPlayer
var prefix := ""
var idle_clip := ""
var height := 1.8
var _busy_until := 0.0
var _clock := 0.0

func setup(packed: PackedScene, keep_mesh: String, clip_prefix: String, idle: String, carries: Array = []) -> void:
	var inst: Node = packed.instantiate()
	add_child(inst)
	prefix = clip_prefix
	idle_clip = idle

	var kept: MeshInstance3D = null
	for m in _meshes(inst):
		# what the character carries is skinned to the same rig and animates
		# with them, so it stays visible. Hiding it is what left the staff
		# floating on its own beside her.
		var mine: bool = keep_mesh == "" or String(m.name) == keep_mesh
		var carried: bool = String(m.name) in carries
		(m as MeshInstance3D).visible = mine or carried
		if mine:
			kept = m
	if kept == null:
		push_error("NO MESH '%s' in this model" % keep_mesh)
		return

	anim = _find_anim(inst)
	if anim == null:
		push_error("NO AnimationPlayer in this model")
	else:
		# the tree has to settle before a pose means anything
		play(idle_clip, true)

	# stand the feet on y=0 so a station position means the floor, not the
	# middle of a torso
	var box: AABB = _world_aabb(kept)
	height = box.size.y
	inst.position.y -= box.position.y

# The rigged models arrived without textures. One override per actor is the
# cheapest way to tell three clay figures apart, and it is deliberately not
# hidden inside the art: when a textured rig lands, this call goes away.
func tint(c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	for mesh in _meshes(self):
		if (mesh as MeshInstance3D).visible:
			(mesh as MeshInstance3D).material_override = m

# Each delivery names its armature node differently (rig, rig_001, rig_002),
# so clip names arrive prefixed differently per file. Ask for the motion by
# its stem and let the actor find whichever prefix this file happens to use.
func resolve(stem: String) -> String:
	if anim == null or stem == "":
		return ""
	if anim.has_animation(stem):
		return stem
	if prefix != "" and anim.has_animation(prefix + stem):
		return prefix + stem
	for a in anim.get_animation_list():
		var name := String(a)
		var bar := name.rfind("|")
		if (name.substr(bar + 1) if bar >= 0 else name) == stem:
			return name
	return ""

func play(clip: String, loop := true) -> void:
	if anim == null or clip == "":
		return
	var full := resolve(clip)
	if full == "":
		push_error("NO CLIP '%s'" % clip)
		return
	var a: Animation = anim.get_animation(full)
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim.play(full)
	if not loop:
		_busy_until = _clock + a.length

# play a one-shot and fall back to idle when it is done
func act(clip: String) -> float:
	play(clip, false)
	var full := resolve(clip)
	var a: Animation = anim.get_animation(full) if full != "" else null
	return a.length if a != null else 0.0

func _process(dt: float) -> void:
	_clock += dt
	if _busy_until > 0.0 and _clock >= _busy_until:
		_busy_until = 0.0
		play(idle_clip, true)

func face(target: Vector3) -> void:
	# the models face +Z and Godot's forward is -Z, so aim the back at the
	# target and the front lands on it
	var flat := Vector3(target.x, global_position.y, target.z)
	if flat.is_equal_approx(global_position):
		return
	look_at(flat, Vector3.UP)
	rotate_y(PI)

func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null

func _world_aabb(m: MeshInstance3D) -> AABB:
	var a: AABB = m.get_aabb()
	var t: Transform3D = m.transform
	var p: Node = m.get_parent()
	while p != null and p is Node3D and p != self:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	var out := AABB(t * a.get_endpoint(0), Vector3.ZERO)
	for i in range(8):
		out = out.expand(t * a.get_endpoint(i))
	return out
