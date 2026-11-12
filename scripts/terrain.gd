class_name Terrain
extends RefCounted
## Snowy valley terrain. Track (|x| < TRACK_HALF) is flat at y = 0, banks rise to hills.
## Rivers carve a channel across the full width.

const TRACK_HALF := 5.6
const CHUNK_LEN := 24.0
const RIVER_DEPTH := 0.8
const WATER_Y := -0.4

static var noise: FastNoiseLite
static var rivers: Array = [] # [[a0, a1], ...] in absolute distance

static func setup(seed_v: int) -> void:
	noise = FastNoiseLite.new()
	noise.seed = seed_v
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	rivers.clear()

static func river_factor(a: float) -> float:
	# 1 inside river channel, 0 outside; 1m soft bank
	for r in rivers:
		if a > r[0] - 1.5 and a < r[1] + 1.5:
			var e: float = min(a - (r[0] - 1.5), (r[1] + 1.5) - a)
			return clamp(e / 1.5, 0.0, 1.0)
	return 0.0

static func height(x: float, a: float) -> float:
	var ax: float = abs(x)
	var h := 0.0
	if ax > TRACK_HALF:
		var t: float = ax - TRACK_HALF
		var bank: float = min(t * t * 0.05 + t * 0.22, 3.0 + t * 0.35)
		var n := noise.get_noise_2d(x, a) * 0.5 + 0.5
		h = bank + n * smoothstep(0.0, 18.0, t) * 9.0
	var rf := river_factor(a)
	if rf > 0.0:
		h = lerp(h, -RIVER_DEPTH, rf)
	return h

static func _xs() -> PackedFloat32Array:
	var xs := PackedFloat32Array()
	var x := -80.0
	while x < 80.01:
		xs.append(x)
		var ax: float = abs(x)
		if ax < TRACK_HALF + 2.0:
			x += 1.4
		elif ax < 20.0:
			x += 2.5
		else:
			x += 5.0
	return xs

static var _xs_cache := PackedFloat32Array()

## Builds terrain mesh for chunk starting at absolute distance a0. Local z = -(a - a0).
static func build_chunk(a0: float) -> ArrayMesh:
	if _xs_cache.is_empty():
		_xs_cache = _xs()
	var xs := _xs_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zstep := 1.5
	var nz := int(CHUNK_LEN / zstep)
	var nx := xs.size()
	for iz in nz + 1:
		var a := a0 + iz * zstep
		for ix in nx:
			var x := xs[ix]
			var h := height(x, a)
			var col := Meshes.SNOW
			var ax: float = abs(x)
			if ax < TRACK_HALF:
				# groomed track: faint corduroy stripes + lane hints
				col = Color(1, 1, 1)
			else:
				var hn := height(x + 1.0, a) - h
				var steep: float = clamp(abs(hn) * 0.6, 0.0, 1.0)
				col = Meshes.SNOW.lerp(Color(0.72, 0.82, 0.96), steep)
			if river_factor(a) > 0.2:
				col = Color(0.75, 0.84, 0.95)
			st.set_color(col)
			st.set_uv(Vector2(x, a))
			st.add_vertex(Vector3(x, h, -(a - a0)))
	for iz in nz:
		for ix in nx - 1:
			var i0 := iz * nx + ix
			var i1 := i0 + 1
			var i2 := i0 + nx
			var i3 := i2 + 1
			st.add_index(i0); st.add_index(i2); st.add_index(i1)
			st.add_index(i1); st.add_index(i2); st.add_index(i3)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, Meshes.mat("snow"))
	return m
