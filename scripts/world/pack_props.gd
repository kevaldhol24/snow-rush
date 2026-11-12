class_name PackProps
extends RefCounted
## Third-party prop pipeline (Phase 2, ASSETS.md "Pipeline"). Loads a pack GLB from
## assets/models/env/kenney/, bakes its node transform + a target size + base-centred origin into a new
## ArrayMesh, and puts every surface on the shared world.gdshader so pack props get the same distance
## fog, lighting and (optionally) snow cap as everything else. Summer colours from the Kenney Nature Kit
## are remapped for winter. Results are cached: build once, reuse for pooled nodes and MultiMeshes.

const DIR := "res://assets/models/env/kenney/"

## Kenney Nature Kit material name -> winter colour (Holiday Kit uses a texture atlas instead).
const RECOLOR := {
	"leafsDark": Color(0.12, 0.33, 0.27), # deep pine green (ART_DIRECTION pine #1F5E4A)
	"leafs": Color(0.15, 0.38, 0.30),
	"woodBarkDark": Color(0.33, 0.24, 0.20),
	"woodBark": Color(0.42, 0.30, 0.22),
	"woodInner": Color(0.82, 0.70, 0.54),
	"dirt": Color(0.31, 0.32, 0.38), # rock body (slate, readable against snow)
	"_defaultMat": Color(0.38, 0.39, 0.45),
	"grass": Color(0.93, 0.95, 1.0), # Kenney rock "grass" tops become snow caps
}

static var _cache := {}
static var _mats := {}

## size: (width x, height y, depth z) in metres. Components <= 0 follow the height uniformly.
static func mesh(model: String, size: Vector3, snow_cap := 0.0) -> ArrayMesh:
	var key := "%s|%s|%.2f" % [model, str(size), snow_cap]
	if _cache.has(key):
		return _cache[key]
	var sc: Node = load(DIR + model + ".glb").instantiate()
	var mis: Array = sc.find_children("*", "MeshInstance3D", true, false)
	# gather surfaces with their node transform (relative to the scene root)
	var parts := []
	var ab := AABB()
	var first := true
	for mi in mis:
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != sc:
			if p is Node3D:
				xf = p.transform * xf
			p = p.get_parent()
		var src: Mesh = mi.mesh
		for s in src.get_surface_count():
			var arr: Array = src.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in v.size():
				v[i] = xf * v[i]
				if first:
					ab = AABB(v[i], Vector3.ZERO)
					first = false
				else:
					ab = ab.expand(v[i])
			arr[Mesh.ARRAY_VERTEX] = v
			var nrm = arr[Mesh.ARRAY_NORMAL]
			if nrm != null:
				var n: PackedVector3Array = nrm
				for i in n.size():
					n[i] = (xf.basis * n[i]).normalized()
				arr[Mesh.ARRAY_NORMAL] = n
			arr[Mesh.ARRAY_TANGENT] = null
			parts.append({"arr": arr, "mat": src.surface_get_material(s)})
	sc.free()
	# scale to the requested size, origin at the base centre
	var h: float = max(ab.size.y, 0.001)
	var uni := size.y / h
	var k := Vector3(
		size.x / max(ab.size.x, 0.001) if size.x > 0.0 else uni,
		uni,
		size.z / max(ab.size.z, 0.001) if size.z > 0.0 else uni)
	var off := Vector3(-(ab.position.x + ab.size.x * 0.5), -ab.position.y, -(ab.position.z + ab.size.z * 0.5))
	var out := ArrayMesh.new()
	for part in parts:
		var arr: Array = part.arr
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in v.size():
			v[i] = (v[i] + off) * k
		arr[Mesh.ARRAY_VERTEX] = v
		var nrm = arr[Mesh.ARRAY_NORMAL]
		if nrm != null:
			var n: PackedVector3Array = nrm
			for i in n.size():
				n[i] = (n[i] / k).normalized() # inverse-transpose for non-uniform scale
			arr[Mesh.ARRAY_NORMAL] = n
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, _material(part.mat, snow_cap))
	_cache[key] = out
	return out

static func _material(src: Material, snow_cap: float) -> ShaderMaterial:
	var name := ""
	var col := Color.WHITE
	var tex: Texture2D = null
	if src is BaseMaterial3D:
		name = src.resource_name
		col = src.albedo_color
		tex = src.albedo_texture
	if RECOLOR.has(name):
		col = RECOLOR[name]
	var key := "%s|%s|%s|%.2f" % [name, col.to_html(), str(tex.get_rid()) if tex else "-", snow_cap]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = Meshes.world_shader
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("use_vertex_color", false)
	m.set_shader_parameter("roughness", 0.9)
	m.set_shader_parameter("snow_cap", snow_cap)
	if tex:
		m.set_shader_parameter("use_tex", true)
		m.set_shader_parameter("albedo_tex", tex)
	_mats[key] = m
	return m
