extends Node
## Dev probe: rider body landmarks in skeleton space (head bone rest, eyes/brows AABB, foot bones).
func _ready() -> void:
	var sc: Node = load("res://assets/models/rider_q/Superhero_Male_FullBody.gltf").instantiate()
	var sk: Skeleton3D = sc.find_children("*", "Skeleton3D", true, false)[0]
	for n in ["Head", "neck_01", "foot_l", "foot_r", "ball_l", "pelvis", "hand_l"]:
		var b := sk.find_bone(n)
		print(n, " rest_global=", sk.get_bone_global_rest(b).origin.snapped(Vector3.ONE * 0.001), " basis_y=", sk.get_bone_global_rest(b).basis.y.snapped(Vector3.ONE * 0.01))
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = mi.get_aabb()
		print(mi.name, " aabb_center=", (ab.position + ab.size * 0.5).snapped(Vector3.ONE * 0.001), " size=", ab.size.snapped(Vector3.ONE * 0.001))
	sc.free()
	get_tree().quit()
