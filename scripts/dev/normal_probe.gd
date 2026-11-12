extends Node
## Dev probe: average normal.y of the upper vertices of procedural meshes (should be > 0 = facing up).
func _ready() -> void:
	var meshes := {"rock0": Meshes.rock(0), "rock2": Meshes.rock(2), "pine0": Meshes.pine(0), "snowman": Meshes.snowman()}
	for k in meshes:
		var arr: Array = meshes[k].surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var top := 0.0
		var cnt := 0
		var maxy := -1e9
		for i in v.size():
			maxy = max(maxy, v[i].y)
		for i in v.size():
			if v[i].y > maxy * 0.8:
				top += n[i].y
				cnt += 1
		print("%s: top normal.y avg = %.2f (n=%d)" % [k, top / max(cnt, 1), cnt])
	get_tree().quit()
