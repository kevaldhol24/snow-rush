class_name Pool
extends RefCounted
## Reuses MeshInstance3D nodes per mesh so gameplay never allocates/frees nodes.

var parent: Node3D
var free_lists := {} # key -> Array[MeshInstance3D]
var created := 0

func _init(p: Node3D) -> void:
	parent = p

func take(key: String, mesh: Mesh) -> MeshInstance3D:
	var lst: Array = free_lists.get(key, [])
	var n: MeshInstance3D
	if lst.is_empty():
		n = MeshInstance3D.new()
		n.mesh = mesh
		n.set_meta("pool_key", key)
		parent.add_child(n)
		created += 1
	else:
		n = lst.pop_back()
		n.visible = true
	n.scale = Vector3.ONE
	n.rotation = Vector3.ZERO
	return n

func give(n: Node3D) -> void:
	if not is_instance_valid(n):
		return
	n.visible = false
	var key: String = n.get_meta("pool_key", "")
	if not free_lists.has(key):
		free_lists[key] = []
	free_lists[key].append(n)

func clear_all() -> void:
	for k in free_lists:
		for n in free_lists[k]:
			n.queue_free()
	free_lists.clear()
