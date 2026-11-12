class_name TerrainBuilder
extends RefCounted
## Builds terrain chunk meshes (direct arrays, analytic normals) + decor scatter for a Track segment.

const CHUNK_LEN := 32
const DZ := 1.0

static var _us := PackedFloat32Array()

static func lateral_samples() -> PackedFloat32Array:
	if not _us.is_empty():
		return _us
	var u := -95.0
	while u <= 95.01:
		_us.append(u)
		var au: float = abs(u)
		if au < Track.HALF_W + 3.0:
			u += 1.0
		elif au < 30.0:
			u += 2.5
		else:
			u += 6.0
	return _us

## Returns {mesh, origin(Vector3 render)}; vertices are relative to origin.
static func build(track: Track, a0: float, mat: Material) -> Dictionary:
	var us := lateral_samples()
	var nu := us.size()
	var nr := int(CHUNK_LEN / DZ) + 1
	var origin := track.to_render(0.0, a0, -track.drop_at(a0))
	# heights with a 1-sample border for normals
	var hs := PackedFloat32Array()
	hs.resize((nr + 2) * nu)
	for r in nr + 2:
		var a := a0 + (r - 1) * DZ
		for k in nu:
			hs[r * nu + k] = track.height(us[k], a)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(nr * nu); norms.resize(nr * nu); cols.resize(nr * nu); uvs.resize(nr * nu)
	for r in nr:
		var a := a0 + r * DZ
		var fwd := track.forward(a)
		var rgt := track.right(a)
		var crev := track.feature_at(a, "crevasse")
		var river := track.feature_at(a, "river")
		for k in nu:
			var idx := r * nu + k
			var h := hs[(r + 1) * nu + k]
			var p := track.to_render(us[k], a, h)
			verts[idx] = p - origin
			var k0 := maxi(k - 1, 0)
			var k1 := mini(k + 1, nu - 1)
			var hu := (hs[(r + 1) * nu + k1] - hs[(r + 1) * nu + k0]) / (us[k1] - us[k0])
			var ha := (hs[(r + 2) * nu + k] - hs[r * nu + k]) / (2.0 * DZ)
			var n := (Vector3.UP - rgt * hu - fwd * ha).normalized()
			norms[idx] = n
			# colour: snow, steep = bluish, openings = ice
			var steep: float = clamp((1.0 - n.y) * 2.2, 0.0, 1.0)
			var c := Color(0.88, 0.92, 0.99).lerp(Color(0.64, 0.73, 0.92), steep)
			var loc := h + track.drop_at(a)
			if not crev.is_empty() and abs(us[k] - crev.u) < crev.w + 0.5 and loc < -0.8:
				c = Color(0.35, 0.62, 0.9).lerp(Color(0.08, 0.2, 0.45), clamp(-loc / crev.depth, 0.0, 1.0))
			elif not river.is_empty() and loc < -0.3:
				c = Color(0.6, 0.72, 0.85)
			cols[idx] = c
			uvs[idx] = Vector2(us[k], a)
	var idxs := PackedInt32Array()
	idxs.resize((nr - 1) * (nu - 1) * 6)
	var w := 0
	for r in nr - 1:
		for k in nu - 1:
			var i0 := r * nu + k
			var i1 := i0 + 1
			var i2 := i0 + nu
			var i3 := i2 + 1
			# rows advance downhill (forward); keep clockwise winding seen from above
			idxs[w] = i0; idxs[w + 1] = i2; idxs[w + 2] = i1
			idxs[w + 3] = i1; idxs[w + 4] = i2; idxs[w + 5] = i3
			w += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idxs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	return {"mesh": m, "origin": origin}

## Decor scatter outside the run (non-colliding). Returns {key: [Transform3D,...]} relative to origin.
static func decor(track: Track, a0: float, origin: Vector3, seed_v: int, density: float) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := {"pine0": [], "pine1": [], "pine2": [], "rock": [], "pole": []}
	var n := int(46 * density)
	for i in n:
		var side := -1.0 if r.randf() < 0.5 else 1.0
		var e := pow(r.randf(), 1.5) * 70.0
		var s := r.randf_range(0.85, 1.5) * (1.0 + e * 0.012)
		# decor has no collision: keep the whole canopy (radius ~2.1*s) beyond the rider clamp
		var u := side * (Track.EDGE + 0.5 + 2.1 * s + e)
		var a := a0 + r.randf() * CHUNK_LEN
		if not track.feature_at(a, "river").is_empty():
			continue
		var y := track.height(u, a)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.9, 1.3), s))
		out["pine%d" % (r.randi() % 3)].append(Transform3D(b, track.to_render(u, a, y - 0.25) - origin))
	for i in int(6 * density):
		var side := -1.0 if r.randf() < 0.5 else 1.0
		var s := r.randf_range(0.6, 2.4)
		var u := side * (Track.EDGE + 0.5 + 1.35 * s + r.randf() * 30.0)
		var a := a0 + r.randf() * CHUNK_LEN
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * 0.75, s))
		out["rock"].append(Transform3D(b, track.to_render(u, a, track.height(u, a) - 0.2) - origin))
	# course marker poles every 16 m
	for k in 2:
		var a := a0 + k * 16.0
		if not track.feature_at(a, "river").is_empty() or not track.feature_at(a, "cliff").is_empty():
			continue
		for side in [-1.0, 1.0]:
			var u: float = side * (Track.EDGE + 0.6)
			var b := Basis(Vector3.UP, -track.heading(a))
			out["pole"].append(Transform3D(b, track.to_render(u, a, track.height(u, a)) - origin))
	return out
