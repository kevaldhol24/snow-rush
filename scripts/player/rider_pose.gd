class_name RiderPose
extends SkeletonModifier3D
## Snowboard stance on top of the base animation (Phase 2 rider, ART_DIRECTION §6).
## The body stands sideways on the board (the model is turned 90°); this modifier turns the head and
## shoulders back toward the direction of travel, opens the arms for balance, and adds the
## crouch/air poses procedurally. Runs after the AnimationPlayer (Godot 4.3 SkeletonModifier3D).

## Positive = toward the travel direction (the rider's lead side). Radians.
var head_turn := deg_to_rad(70.0)
var shoulder_turn := deg_to_rad(28.0)
var arm_open := deg_to_rad(38.0)
var crouch := 0.0 # 0..1 extra knee bend (tuck / landing absorb)
var stance_open := deg_to_rad(6.0) # spread the feet along the board (base pose has them 0.23 m apart)

var _ids := {}

func _bone(n: String) -> int:
	if not _ids.has(n):
		_ids[n] = get_skeleton().find_bone(n) if get_skeleton() else -1
	return _ids[n]

## Rotate a bone around an axis given in SKELETON space, keeping its children attached.
func _rot(n: String, axis: Vector3, ang: float) -> void:
	var sk := get_skeleton()
	var b := _bone(n)
	if b < 0 or abs(ang) < 0.0001:
		return
	var gp := sk.get_bone_global_pose(b)
	gp.basis = Basis(axis.normalized(), ang) * gp.basis
	sk.set_bone_global_pose(b, gp)

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	# skeleton space: +Y up, the body faces +Z (glTF), lead side = +X after our 90° stance turn
	_rot("spine_02", Vector3.UP, shoulder_turn * 0.5)
	_rot("spine_03", Vector3.UP, shoulder_turn * 0.5)
	_rot("neck_01", Vector3.UP, head_turn * 0.4)
	_rot("Head", Vector3.UP, head_turn * 0.6)
	# wider stance: feet apart along the board (body faces +Z, so sideways is X -> rotate about Z)
	_rot("thigh_l", Vector3.BACK, stance_open)
	_rot("thigh_r", Vector3.BACK, -stance_open)
	# arms out from the body for balance (around the body's forward axis)
	_rot("upperarm_l", Vector3.FORWARD, -arm_open)
	_rot("upperarm_r", Vector3.FORWARD, arm_open)
	# riding crouch: hips drop, knees bend, ankles flex so the feet stay flat on the board.
	# (Thigh down vector rotated about X by -a swings the knee toward +Z = the body's front.)
	var a := deg_to_rad(20.0) + crouch * deg_to_rad(22.0)
	var drop := 0.9 * (1.0 - cos(a)) # two ~0.45 m leg segments
	var pb := _bone("pelvis")
	if pb >= 0:
		var gp := sk.get_bone_global_pose(pb)
		gp.origin.y -= drop
		gp.origin.z -= 0.06 + 0.06 * crouch # hips back
		sk.set_bone_global_pose(pb, gp)
	for side in ["_l", "_r"]:
		_rot("thigh" + side, Vector3.RIGHT, -a)
		_rot("calf" + side, Vector3.RIGHT, 2.0 * a)
		_rot("foot" + side, Vector3.RIGHT, -a)
	_rot("spine_01", Vector3.RIGHT, -0.25 - 0.2 * crouch) # chest over the board
