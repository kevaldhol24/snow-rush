extends Node
## Dev probe: list pack models (assets/models/env/kenney) with AABB size, surfaces and material info.
func _ready() -> void:
	var dir := "res://assets/models/env/kenney/"
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".glb"):
			continue
		var sc: Node = load(dir + f).instantiate()
		var mis: Array = sc.find_children("*", "MeshInstance3D", true, false)
		var line := "%s: %d meshes" % [f, mis.size()]
		for mi in mis:
			var m: Mesh = mi.mesh
			var ab: AABB = mi.get_aabb()
			line += " | size=%s pos=%s xf=%s surf=%d" % [str(ab.size.snapped(Vector3.ONE * 0.01)), str(ab.position.snapped(Vector3.ONE * 0.01)), str(mi.transform.origin.snapped(Vector3.ONE*0.01)), m.get_surface_count()]
			for s in m.get_surface_count():
				var mat: Material = m.surface_get_material(s)
				if mat is BaseMaterial3D:
					line += " [%s c=%s tex=%s vc=%s]" % [mat.resource_name, mat.albedo_color.to_html(false), str(mat.albedo_texture != null), str(mat.vertex_color_use_as_albedo)]
		print(line)
		sc.free()
	get_tree().quit()
