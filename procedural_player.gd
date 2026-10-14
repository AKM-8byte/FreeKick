extends Node3D

const Geo = preload("res://geometry.gd")
@export var scene_bindings: Dictionary = {}
@export var rig_rest_parts: Dictionary = {}
var visual_skeleton: Skeleton3D
var rig_bones: Dictionary = {}
@export_group("Procedural IK")
@export_range(0.35, 0.7) var thigh_length := 0.53
@export_range(0.35, 0.7) var shin_length := 0.53
@export_range(0.2, 0.45) var upper_arm_length := 0.30
@export_range(0.2, 0.45) var forearm_length := 0.30
@export_range(0.8, 1.2) var idle_pelvis_height := 1.02
@export var knee_pole := Vector3(0, 0, -1)
@export_range(0, 1, 0.01) var rig_ik_weight := 1.0
@export_range(0, 120, 1, "suffix:Hz") var visual_update_hz := 0.0
var visual_clock := 0.0
var cached_parts: Dictionary = {}
var cached_rest_inverse: Dictionary = {}
var cached_bone_rest: Dictionary = {}
var cached_transforms: Dictionary = {}
var actor_to_skeleton := Transform3D.IDENTITY
var skeleton_to_actor := Transform3D.IDENTITY
var cached_weight := -1.0
var bone_upload_count := 0

const THIGH := 0.53
const SHIN := 0.53
var pelvis := Vector3(0.0, 1.02, 0.0)
var torso: MeshInstance3D
var head: MeshInstance3D
var hips: MeshInstance3D
var thighs: Array[MeshInstance3D] = []
var shins: Array[MeshInstance3D] = []
var boots: Array[MeshInstance3D] = []
var upper_arms: Array[MeshInstance3D] = []
var forearms: Array[MeshInstance3D] = []
var hands: Array[MeshInstance3D] = []
var feet: Array[Vector3] = [Vector3(-0.16, 0.07, 0), Vector3(0.16, 0.07, 0)]
var hand_targets: Array[Vector3] = [Vector3(-0.38, 1.0, 0), Vector3(0.38, 1.0, 0)]
var lean := 0.0
var twist := 0.0
var knee_positions: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var knee_caps: Array[MeshInstance3D] = []
var elbows: Array[MeshInstance3D] = []

func build(color: Color, dark_uniform: bool = false, goalkeeper: bool = false) -> void:
	if not scene_bindings.is_empty():
		preload("res://scripts/scene_bindings.gd").restore(self, scene_bindings)
		update_pose()
		initialize_rig()
		return
	var shirt := Geo.material(color)
	var skin := Geo.material(Color("d8a27b"))
	var shorts := Geo.material(Color("20252b") if dark_uniform else Color("16243c"))
	var socks := Geo.material(Color("30363e") if dark_uniform else Color("e5eaf1"))
	var shoe := Geo.material(Color("eceee9") if dark_uniform else Color("df6372"))
	var torso_mesh := CylinderMesh.new()
	torso_mesh.top_radius = 0.235
	torso_mesh.bottom_radius = 0.18
	torso_mesh.height = 0.48
	torso_mesh.radial_segments = 16
	torso = Geo.mesh(self, torso_mesh, shirt)
	torso.scale.z = 0.63
	var hips_mesh := CylinderMesh.new()
	hips_mesh.top_radius = 0.18
	hips_mesh.bottom_radius = 0.20
	hips_mesh.height = 0.22
	hips_mesh.radial_segments = 16
	hips = Geo.mesh(self, hips_mesh, shorts)
	hips.scale.z = 0.66
	head = Geo.sphere(self, 0.12, skin)
	head.scale = Vector3(0.93, 1.08, 0.96)
	var neck := Geo.rod(torso, 0.055, skin)
	neck.scale = Vector3(1, 0.10, 1)
	neck.position.y = 0.27
	var collar := Geo.box(torso, Vector3(0.15, 0.025, 0.08), shorts, Vector3(0, 0.23, -0.08))
	collar.rotation.z = 0.05
	Geo.box(torso, Vector3(0.035, 0.20, 0.015), socks, Vector3(-0.12, 0.035, -0.153))
	Geo.box(torso, Vector3(0.035, 0.20, 0.015), socks, Vector3(0.12, 0.035, -0.153))
	Geo.sphere(torso, 0.028, shoe, Vector3(-0.07, 0.10, -0.154)).scale.z = 0.18
	Geo.sphere(head, 0.123, Geo.material(Color("253041")), Vector3(0, 0.04, 0.025)).scale = Vector3(1, 0.55, 1)
	Geo.sphere(head, 0.02, skin, Vector3(0, -0.015, -0.117))
	for x in [-0.048, 0.048]:
		Geo.sphere(head, 0.009, skin, Vector3(x * 2.35, 0, 0))
		Geo.sphere(head, 0.008, Geo.material(Color("20252b")), Vector3(x, 0.017, -0.109))
	Geo.box(head, Vector3(0.039, 0.005, 0.009), shorts, Vector3(0, -0.052, -0.107))
	for side in range(2):
		thighs.append(Geo.rod(self, 0.083, skin))
		var hem := Geo.rod(thighs[side], 0.113, shorts)
		hem.position.y = -0.30
		hem.scale.y = 0.46
		shins.append(Geo.rod(self, 0.062, socks))
		knee_caps.append(Geo.sphere(self, 0.075, skin))
		Geo.box(shins[side], Vector3(0.06, 0.07, 0.015), shirt, Vector3(0, 0.30, -0.055))
		boots.append(Geo.box(self, Vector3(0.12, 0.10, 0.24), shoe))
		Geo.box(boots[side], Vector3(0.13, 0.018, 0.245), shorts, Vector3(0, -0.045, 0))
		Geo.sphere(boots[side], 0.053, shoe, Vector3(0, 0, -0.083)).scale = Vector3(1.10, 0.72, 1.12)
		for lace in range(3):
			Geo.box(boots[side], Vector3(0.075, 0.008, 0.009), socks, Vector3(0, 0.052, -0.04 + lace * 0.025))
		upper_arms.append(Geo.rod(self, 0.065, shirt))
		forearms.append(Geo.rod(self, 0.047, skin))
		elbows.append(Geo.sphere(self, 0.047, skin))
		hands.append(Geo.sphere(self, 0.08 if goalkeeper else 0.06, Geo.material(Color("f3f5db")) if goalkeeper else skin))
		if goalkeeper:
			for finger in range(4):
				Geo.sphere(hands[side], 0.016, socks, Vector3((finger - 1.5) * 0.026, 0.078, 0)).scale = Vector3(1, 2, 0.85)
			Geo.box(hands[side], Vector3(0.11, 0.025, 0.10), shirt, Vector3(0, -0.06, 0))
	preload("res://scripts/character_meshes.gd").apply(self)
	update_pose()

func add_number(number: int) -> void:
	var badge := Label3D.new()
	badge.text = str(number)
	badge.font_size = 64
	badge.pixel_size = 0.0014
	badge.outline_size = 0
	badge.position = Vector3(0, 0, -0.25)
	badge.rotation.y = PI
	torso.add_child(badge)

static func solve_joint(root: Vector3, target: Vector3, pole: Vector3, first: float, second: float) -> Vector3:
	var delta := target - root
	var distance := clampf(delta.length(), 0.02, first + second - 0.001)
	var axis := delta.normalized() if delta.length() > 0.001 else Vector3.DOWN
	var bend := pole - axis * pole.dot(axis)
	if bend.length_squared() < 0.0001:
		var fallback := Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.UP
		bend = fallback - axis * fallback.dot(axis)
	bend = bend.normalized()
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	return root + axis * along + bend * sqrt(maxf(0.0, first * first - along * along))

func update_pose() -> void:
	if torso == null:
		return
	var center := pelvis
	for side in range(2):
		var hip := center + Vector3(-0.14 if side == 0 else 0.14, 0, 0)
		var horizontal := Vector2(feet[side].x - hip.x, feet[side].z - hip.z).length()
		var height := sqrt(maxf(0.04, pow(thigh_length + shin_length - 0.015, 2) - horizontal * horizontal))
		center.y = minf(center.y, feet[side].y + height)
	hips.position = center
	torso.position = center + Vector3(0, 0.30, -lean * 0.16)
	torso.rotation.x = -lean * 0.3
	torso.rotation.y = twist
	head.position = center + Vector3(0, 0.72, -lean * 0.24)
	for side in range(2):
		var sign_x := -1.0 if side == 0 else 1.0
		var hip := center + Vector3(sign_x * 0.14, 0, 0)
		var endpoint := hip + (feet[side] - hip).limit_length(thigh_length + shin_length - 0.001)
		var knee := solve_joint(hip, endpoint, knee_pole, thigh_length, shin_length)
		knee_positions[side] = knee
		knee_caps[side].position = knee
		Geo.between(thighs[side], hip, knee)
		Geo.between(shins[side], knee, endpoint)
		boots[side].position = endpoint + Vector3(0, -0.015, -0.025)
		var shoulder := torso.position + Basis(Vector3.UP, twist) * Vector3(sign_x * 0.26, 0.15, 0)
		var hand := shoulder + (hand_targets[side] - shoulder).limit_length(upper_arm_length + forearm_length - 0.01)
		var elbow := solve_joint(shoulder, hand, Vector3(sign_x, 0, 0.4), upper_arm_length, forearm_length)
		elbows[side].position = elbow
		Geo.between(upper_arms[side], shoulder, elbow)
		Geo.between(forearms[side], elbow, hand)
		hands[side].position = hand
		hands[side].quaternion = Quaternion(Vector3.UP, (hand - elbow).normalized())

func pose_idle() -> void:
	pelvis = Vector3(0, idle_pelvis_height, 0)
	feet = [Vector3(-0.16, 0.07, 0), Vector3(0.16, 0.07, 0)]
	hand_targets = [Vector3(-0.38, 1.0, 0), Vector3(0.38, 1.0, 0)]
	lean = 0
	twist = 0
	head.rotation = Vector3.ZERO
	update_pose()

func body_parts() -> Dictionary:
	return {"hips": hips, "torso": torso, "head": head,
		"thigh_l": thighs[0], "thigh_r": thighs[1],
		"shin_l": shins[0], "shin_r": shins[1],
		"upper_arm_l": upper_arms[0], "upper_arm_r": upper_arms[1],
		"forearm_l": forearms[0], "forearm_r": forearms[1],
		"boot_l": boots[0], "boot_r": boots[1],
		"hand_l": hands[0], "hand_r": hands[1]}

func initialize_rig() -> void:
	if visual_skeleton != null or not has_node("VisualRig"):
		return
	cached_transforms.clear()
	cached_parts.clear()
	cached_rest_inverse.clear()
	cached_bone_rest.clear()
	cached_weight = -1.0
	var skeletons := get_node("VisualRig").find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	visual_skeleton = skeletons[0]
	cached_parts = body_parts()
	actor_to_skeleton = visual_skeleton.global_transform.affine_inverse() * global_transform
	skeleton_to_actor = actor_to_skeleton.affine_inverse()
	for key in cached_parts:
		var index := visual_skeleton.find_bone(key)
		if index >= 0:
			rig_bones[key] = index
			if not rig_rest_parts.has(key):
				rig_rest_parts[key] = cached_parts[key].transform
			cached_rest_inverse[key] = rig_rest_parts[key].affine_inverse()
			cached_bone_rest[key] = visual_skeleton.get_bone_global_rest(index)
	sync_rig()

func sync_rig() -> void:
	if visual_skeleton == null or torso == null:
		return
	for key in rig_bones:
		var transform: Transform3D = cached_parts[key].transform
		if cached_transforms.has(key) and cached_transforms[key].is_equal_approx(transform) and is_equal_approx(cached_weight, rig_ik_weight):
			continue
		cached_transforms[key] = transform
		var relative: Transform3D = transform * cached_rest_inverse[key]
		var index: int = rig_bones[key]
		var bone_pose: Transform3D = actor_to_skeleton * relative * skeleton_to_actor * cached_bone_rest[key]
		visual_skeleton.set_bone_global_pose_override(index, bone_pose, rig_ik_weight, true)
		bone_upload_count += 1
	cached_weight = rig_ik_weight

func _process(delta: float) -> void:
	# Include head/boot adjustments performed after the physical IK solve,
	# including poses restored by cinematic replay.
	if not is_visible_in_tree(): return
	visual_clock += delta
	if visual_update_hz > 0 and visual_clock < 1.0 / visual_update_hz: return
	visual_clock = fmod(visual_clock, 1.0 / visual_update_hz) if visual_update_hz > 0 else 0
	sync_rig()
