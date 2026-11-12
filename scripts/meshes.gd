class_name Meshes
extends RefCounted
## Procedural low-poly meshes (flat shaded, vertex coloured). All meshes are cached.

const SNOW := Color(0.90, 0.94, 1.0)
const SNOW_SHADE := Color(0.76, 0.84, 0.97)
const PINE := Color(0.13, 0.42, 0.30)
const PINE_DARK := Color(0.09, 0.30, 0.24)
const BARK := Color(0.42, 0.26, 0.16)
const ROCK := Color(0.47, 0.50, 0.56)
const ROCK_DARK := Color(0.34, 0.36, 0.42)

static var _cache := {}
static var _mats := {}
static var world_shader: Shader = preload("res://shaders/world.gdshader")

# ---------------------------------------------------------------- materials
static func mat(key: String = "vc") -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = world_shader
	match key:
		"vc":
			pass
		"snow":
			m.set_shader_parameter("sparkle", 0.9)
			m.set_shader_parameter("track", true)
		"coin":
			m.set_shader_parameter("emission", Color(1.0, 0.75, 0.15))
			m.set_shader_parameter("emission_energy", 0.45)
			m.set_shader_parameter("metallic", 0.6)
			m.set_shader_parameter("roughness", 0.3)
			m.set_shader_parameter("rim_strength", 0.35)
		"glow":
			m.set_shader_parameter("emission", Color(1, 1, 1))
			m.set_shader_parameter("emission_energy", 0.6)
			m.set_shader_parameter("rim_strength", 0.5)
		"ice":
			m.set_shader_parameter("roughness", 0.15)
			m.set_shader_parameter("rim_strength", 0.25)
	_mats[key] = m
	return m

static func plain_mat(c: Color, emis: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	m.roughness = 0.7
	return m

static var _dot: Texture2D
static func dot_texture() -> Texture2D:
	if _dot:
		return _dot
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.9))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	_dot = t
	return t

# ---------------------------------------------------------------- primitives
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	# counter-clockwise when looking from outside -> Godot front face is clockwise; we emit a,c,b
	st.set_color(col); st.add_vertex(a)
	st.set_color(col); st.add_vertex(c)
	st.set_color(col); st.add_vertex(b)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)

static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1) # flat shading
	return st

static func _ring(center: Vector3, r: float, segs: int, phase: float = 0.0, jitter: float = 0.0, rng: RandomNumberGenerator = null) -> Array:
	var pts := []
	for i in segs:
		var a := TAU * float(i) / segs + phase
		var rr := r
		if rng and jitter > 0.0:
			rr *= 1.0 + rng.randf_range(-jitter, jitter)
		pts.append(center + Vector3(cos(a) * rr, 0, sin(a) * rr))
	return pts

static func _frustum(st: SurfaceTool, c0: Vector3, r0: float, c1: Vector3, r1: float, segs: int, col: Color, phase := 0.0) -> void:
	var a := _ring(c0, r0, segs, phase)
	var b := _ring(c1, r1, segs, phase)
	for i in segs:
		var j := (i + 1) % segs
		_quad(st, a[i], a[j], b[j], b[i], col)

static func _cone(st: SurfaceTool, c0: Vector3, r: float, h: float, segs: int, col: Color, phase := 0.0, bottom := true) -> void:
	var ring := _ring(c0, r, segs, phase)
	var tip := c0 + Vector3(0, h, 0)
	for i in segs:
		var j := (i + 1) % segs
		_tri(st, ring[i], ring[j], tip, col)
		if bottom:
			_tri(st, ring[j], ring[i], c0, col.darkened(0.3))

# ---------------------------------------------------------------- objects
## Pine with snow-covered tiers. variant 0..2
static func pine(variant: int = 0, snowy: bool = true) -> ArrayMesh:
	var key := "pine%d%s" % [variant, snowy]
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	var segs := 7
	var tiers := 3 + (variant % 2)
	var trunk_h := 0.9
	_frustum(st, Vector3.ZERO, 0.28, Vector3(0, trunk_h + 0.4, 0), 0.2, 6, BARK)
	var y := trunk_h
	var r := 1.75 + 0.15 * variant
	var tier_h := 1.8
	for t in tiers:
		var phase := t * 0.45
		var green := PINE if t % 2 == 0 else PINE_DARK
		# lower green skirt
		var mid_r := r * 0.55
		var mid_y := y + tier_h * 0.45
		_frustum(st, Vector3(0, y, 0), r, Vector3(0, mid_y, 0), mid_r, segs, green, phase)
		# underside
		var ring := _ring(Vector3(0, y, 0), r, segs, phase)
		for i in segs:
			_tri(st, ring[(i + 1) % segs], ring[i], Vector3(0, y + 0.25, 0), green.darkened(0.35))
		# snow cap
		var cap_col := SNOW if snowy else green.lightened(0.1)
		var ring2 := _ring(Vector3(0, mid_y, 0), mid_r, segs, phase)
		var tip := Vector3(0, y + tier_h, 0)
		for i in segs:
			_tri(st, ring2[i], ring2[(i + 1) % segs], tip, cap_col if i % 3 != 0 else SNOW_SHADE)
		y += tier_h * 0.62
		r *= 0.74
		tier_h *= 0.88
	var m := _finish(st)
	m.surface_set_material(0, mat("vc"))
	_cache[key] = m
	return m

## Rock lump with snow on top. size ~1
static func rock(seed_v: int = 0) -> ArrayMesh:
	var key := "rock%d" % seed_v
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + seed_v
	var st := _begin()
	var rings := 4
	var segs := 7
	var pts := []
	for ri in rings + 1:
		var v := float(ri) / rings
		var phi := v * PI * 0.5 # hemisphere-ish (flat bottom)
		var row := []
		for si in segs:
			var th := TAU * si / segs
			var rr := cos(phi)
			var p := Vector3(cos(th) * rr, sin(phi) * 0.85, sin(th) * rr)
			if ri < rings:
				p *= 1.0 + rng.randf_range(-0.22, 0.22)
			row.append(p)
		pts.append(row)
	for ri in rings:
		for si in segs:
			var sj := (si + 1) % segs
			var a: Vector3 = pts[ri][si]
			var b: Vector3 = pts[ri][sj]
			var c: Vector3 = pts[ri + 1][sj]
			var d: Vector3 = pts[ri + 1][si]
			var col := ROCK if (si + ri) % 2 == 0 else ROCK_DARK
			if ri >= rings - 2:
				col = SNOW if ri == rings - 1 else (SNOW_SHADE if si % 2 == 0 else ROCK)
			_quad(st, a, b, c, d, col)
	var m := _finish(st)
	m.surface_set_material(0, mat("vc"))
	_cache[key] = m
	return m

## Natural rocky ramp. Front edge at z=0 (y=0) rising to z=-length (y=height).
static func ramp(width: float, length: float, height: float, seed_v: int = 0) -> ArrayMesh:
	var key := "ramp%.1f_%.1f_%.1f_%d" % [width, length, height, seed_v]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + seed_v
	var st := _begin()
	var hw := width * 0.5
	var nz := 5
	var nx := 3
	var top := []
	for iz in nz + 1:
		var t := float(iz) / nz
		var row := []
		for ix in nx + 1:
			var x: float = lerp(-hw, hw, float(ix) / nx)
			var y := height * t
			if ix > 0 and ix < nx and iz > 0 and iz < nz:
				y += rng.randf_range(-0.05, 0.05)
			row.append(Vector3(x, y, -length * t))
		top.append(row)
	for iz in nz:
		for ix in nx:
			var c := Color(0.62, 0.78, 0.97) if iz % 2 == 0 else Color(0.80, 0.89, 1.0)
			if iz == nz - 1:
				c = Color(1.0, 0.55, 0.15) if ix % 2 == 0 else Color(1, 1, 1) # lip warning stripe
			_quad(st, top[iz][ix], top[iz][ix + 1], top[iz + 1][ix + 1], top[iz + 1][ix], c)
	# boulders hugging the sides
	for side in [-1, 1]:
		for k in 3:
			var t := (k + 0.5) / 3.0
			var c := Vector3(side * (hw + 0.2), 0.0, -length * t)
			var rr := 0.3 + height * t * 0.3
			var ring := _ring(c, rr, 6, rng.randf() * TAU, 0.25, rng)
			var tip := c + Vector3(rng.randf_range(-0.2, 0.2), rr * 0.8 + height * t * 0.25, rng.randf_range(-0.2, 0.2))
			for i in 6:
				var col := ROCK if i % 2 == 0 else ROCK_DARK
				_tri(st, ring[i], ring[(i + 1) % 6], tip, col)
	# rocky sides: bulge outward
	for side in [-1, 1]:
		var ix := 0 if side < 0 else nx
		for iz in nz:
			var a: Vector3 = top[iz][ix]
			var b: Vector3 = top[iz + 1][ix]
			var bulge := Vector3(side * rng.randf_range(0.25, 0.5), 0, 0)
			var a0 := Vector3(a.x, 0, a.z) + bulge
			var b0 := Vector3(b.x, 0, b.z) + bulge
			var am := (a + a0) * 0.5 + bulge * 0.8
			var bm := (b + b0) * 0.5 + bulge * 0.8
			var col := ROCK if iz % 2 == 0 else ROCK_DARK
			if side > 0:
				_quad(st, a, am, bm, b, col)
				_quad(st, am, a0, b0, bm, col.darkened(0.1))
			else:
				_quad(st, a, b, bm, am, col)
				_quad(st, am, bm, b0, a0, col.darkened(0.1))
	# back face (the drop) - jagged rock
	var back: Array = top[nz]
	for ix in nx:
		var a: Vector3 = back[ix]
		var b: Vector3 = back[ix + 1]
		var a0 := Vector3(a.x, 0, a.z + 0.3)
		var b0 := Vector3(b.x, 0, b.z + 0.3)
		_quad(st, a, a0, b0, b, ROCK_DARK)
	var m := _finish(st)
	m.surface_set_material(0, mat("vc"))
	_cache[key] = m
	return m

## Fallen log spanning the track along X.
static func log_mesh(length: float) -> ArrayMesh:
	var key := "log%.1f" % length
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	var segs := 8
	var r := 0.48
	var hl := length * 0.5
	var ring_a := []
	var ring_b := []
	for i in segs:
		var a := TAU * i / segs
		var off := Vector3(0, sin(a) * r + r, cos(a) * r)
		ring_a.append(Vector3(-hl, 0, 0) + off)
		ring_b.append(Vector3(hl, 0, 0) + off)
	for i in segs:
		var j := (i + 1) % segs
		var up: bool = (ring_a[i].y + ring_a[j].y) * 0.5 > r * 1.55
		_quad(st, ring_a[i], ring_b[i], ring_b[j], ring_a[j], SNOW if up else (BARK if i % 2 == 0 else BARK.darkened(0.15)))
	var end_col := Color(0.78, 0.6, 0.4)
	for i in segs:
		var j := (i + 1) % segs
		_tri(st, ring_a[j], ring_a[i], Vector3(-hl, r, 0), end_col)
		_tri(st, ring_b[i], ring_b[j], Vector3(hl, r, 0), end_col)
	# a couple of stubs/branches
	_cone(st, Vector3(-hl * 0.4, r * 1.8, 0), 0.12, 0.7, 5, BARK)
	_cone(st, Vector3(hl * 0.5, r * 1.8, 0.05), 0.1, 0.55, 5, BARK)
	var m := _finish(st)
	m.surface_set_material(0, mat("vc"))
	_cache[key] = m
	return m

static func _sphere(st: SurfaceTool, c: Vector3, r: float, col: Color, rings := 5, segs := 8) -> void:
	var pts := []
	for ri in rings + 1:
		var phi := PI * float(ri) / rings - PI * 0.5
		var row := []
		for si in segs:
			var th := TAU * si / segs
			row.append(c + Vector3(cos(th) * cos(phi) * r, sin(phi) * r, sin(th) * cos(phi) * r))
		pts.append(row)
	for ri in rings:
		for si in segs:
			var sj := (si + 1) % segs
			var cc := col if (si + ri) % 2 == 0 else col.darkened(0.06)
			_quad(st, pts[ri][si], pts[ri][sj], pts[ri + 1][sj], pts[ri + 1][si], cc)

static func snowman() -> ArrayMesh:
	if _cache.has("snowman"):
		return _cache["snowman"]
	var st := _begin()
	_sphere(st, Vector3(0, 0.75, 0), 0.8, SNOW)
	_sphere(st, Vector3(0, 1.85, 0), 0.58, SNOW)
	_sphere(st, Vector3(0, 2.7, 0), 0.42, SNOW)
	# scarf
	_frustum(st, Vector3(0, 2.25, 0), 0.47, Vector3(0, 2.42, 0), 0.43, 8, Color(0.9, 0.15, 0.2))
	# carrot nose (points toward +z = toward player)
	var ring := _ring(Vector3.ZERO, 0.08, 5)
	var tip := Vector3(0, 2.72, 0.85)
	for i in 5:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 5]
		_tri(st, Vector3(a.x, a.z + 2.72, 0.38), Vector3(b.x, b.z + 2.72, 0.38), tip, Color(1.0, 0.5, 0.1))
	# eyes / buttons
	for p in [Vector3(-0.15, 2.85, 0.37), Vector3(0.15, 2.85, 0.37), Vector3(0, 1.95, 0.57), Vector3(0, 1.7, 0.57)]:
		_sphere(st, p, 0.06, Color(0.08, 0.08, 0.1), 2, 4)
	# hat
	_frustum(st, Vector3(0, 3.0, 0), 0.45, Vector3(0, 3.06, 0), 0.45, 8, Color(0.12, 0.12, 0.15))
	_frustum(st, Vector3(0, 3.06, 0), 0.3, Vector3(0, 3.5, 0), 0.3, 8, Color(0.15, 0.15, 0.18))
	_cone(st, Vector3(0, 3.5, 0), 0.3, 0.001, 8, Color(0.15, 0.15, 0.18), 0.0, false)
	# stick arms
	_frustum(st, Vector3(-0.5, 1.9, 0), 0.05, Vector3(-1.3, 2.4, 0), 0.03, 4, BARK)
	_frustum(st, Vector3(0.5, 1.9, 0), 0.05, Vector3(1.3, 2.5, 0), 0.03, 4, BARK)
	var m := _finish(st)
	m.surface_set_material(0, mat("vc"))
	_cache["snowman"] = m
	return m

static func coin() -> ArrayMesh:
	if _cache.has("coin"):
		return _cache["coin"]
	var st := _begin()
	var segs := 12
	var r := 0.42
	var t := 0.09
	var gold := Color(1.0, 0.8, 0.2)
	var a := _ring(Vector3.ZERO, r, segs)
	var inner := _ring(Vector3.ZERO, r * 0.68, segs)
	# rotate rings so coin faces +z
	for arr in [a, inner]:
		for i in arr.size():
			var p: Vector3 = arr[i]
			arr[i] = Vector3(p.x, p.z, 0)
	for i in segs:
		var j := (i + 1) % segs
		var fz := Vector3(0, 0, t)
		var bz := Vector3(0, 0, -t)
		# rim
		_quad(st, a[i] + bz, a[j] + bz, a[j] + fz, a[i] + fz, gold.darkened(0.15))
		# faces: outer ring band + raised inner
		_quad(st, a[i] + fz, a[j] + fz, inner[j] + fz * 1.4, inner[i] + fz * 1.4, gold)
		_tri(st, inner[i] + fz * 1.4, inner[j] + fz * 1.4, fz * 1.4, Color(1.0, 0.9, 0.35))
		_quad(st, a[j] + bz, a[i] + bz, inner[i] + bz * 1.4, inner[j] + bz * 1.4, gold)
		_tri(st, inner[j] + bz * 1.4, inner[i] + bz * 1.4, bz * 1.4, Color(1.0, 0.9, 0.35))
	var m := _finish(st)
	m.surface_set_material(0, mat("coin"))
	_cache["coin"] = m
	return m

static func magnet() -> ArrayMesh:
	if _cache.has("magnet"):
		return _cache["magnet"]
	var st := _begin()
	var red := Color(0.95, 0.15, 0.2)
	var steel := Color(0.85, 0.88, 0.95)
	var segs := 8
	var r0 := 0.38
	var r1 := 0.62
	var hz := 0.16
	for i in segs:
		var a0 := PI * i / segs
		var a1 := PI * (i + 1) / segs
		var p0 := Vector3(cos(a0), sin(a0), 0)
		var p1 := Vector3(cos(a1), sin(a1), 0)
		var o0 := p0 * r1; var o1 := p1 * r1; var i0 := p0 * r0; var i1 := p1 * r0
		var f := Vector3(0, 0, hz); var b := -f
		_quad(st, o0 + f, o1 + f, i1 + f, i0 + f, red)
		_quad(st, o1 + b, o0 + b, i0 + b, i1 + b, red)
		_quad(st, o0 + b, o1 + b, o1 + f, o0 + f, red.darkened(0.1))
		_quad(st, i1 + b, i0 + b, i0 + f, i1 + f, red.darkened(0.2))
	for side in [-1, 1]:
		var x0: float = r0 * side
		var x1: float = r1 * side
		var xa: float = min(x0, x1)
		var xb: float = max(x0, x1)
		_box(st, Vector3(xa, -0.35, -hz), Vector3(xb, 0.0, hz), steel)
	var m := _finish(st)
	m.surface_set_material(0, mat("glow"))
	_cache["magnet"] = m
	return m

static func _box(st: SurfaceTool, mn: Vector3, mx: Vector3, col: Color) -> void:
	var p := [Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z),
		Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z)]
	_quad(st, p[4], p[5], p[6], p[7], col) # front +z
	_quad(st, p[1], p[0], p[3], p[2], col.darkened(0.1)) # back
	_quad(st, p[0], p[4], p[7], p[3], col.darkened(0.15)) # left
	_quad(st, p[5], p[1], p[2], p[6], col.darkened(0.15)) # right
	_quad(st, p[7], p[6], p[2], p[3], col.lightened(0.1)) # top
	_quad(st, p[0], p[1], p[5], p[4], col.darkened(0.3)) # bottom

static func crystal(col: Color) -> ArrayMesh:
	var key := "crystal%s" % col.to_html()
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	var ring := _ring(Vector3.ZERO, 0.4, 6)
	var top := Vector3(0, 0.75, 0)
	var bot := Vector3(0, -0.55, 0)
	for i in 6:
		var j := (i + 1) % 6
		var c := col if i % 2 == 0 else col.lightened(0.25)
		_tri(st, ring[i], ring[j], top, c)
		_tri(st, ring[j], ring[i], bot, c.darkened(0.2))
	var m := _finish(st)
	var mt := ShaderMaterial.new()
	mt.shader = world_shader
	mt.set_shader_parameter("emission", col)
	mt.set_shader_parameter("emission_energy", 0.8)
	mt.set_shader_parameter("rim_strength", 0.6)
	m.surface_set_material(0, mt)
	_cache[key] = m
	return m

static func pole(col: Color) -> ArrayMesh:
	var key := "pole%s" % col.to_html()
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	_frustum(st, Vector3.ZERO, 0.07, Vector3(0, 0.6, 0), 0.07, 5, col)
	_frustum(st, Vector3(0, 0.6, 0), 0.07, Vector3(0, 0.9, 0), 0.07, 5, Color(1, 1, 1))
	_frustum(st, Vector3(0, 0.9, 0), 0.07, Vector3(0, 1.6, 0), 0.06, 5, col)
	# little flag
	_tri(st, Vector3(0, 1.6, 0), Vector3(0, 1.15, 0), Vector3(0.55, 1.4, 0), col)
	_tri(st, Vector3(0, 1.15, 0), Vector3(0, 1.6, 0), Vector3(0.55, 1.4, 0), col)
	var m := _finish(st)
	m.surface_set_material(0, mat("vc"))
	_cache[key] = m
	return m

## Snowboard for the rider (local: long axis Z). Uses StandardMaterial (player is not curved).
static func board(b: Dictionary) -> ArrayMesh:
	var st := _begin()
	var col: Color = b.color
	var acc: Color = b.accent
	var hl := 1.0
	var hw := 0.34
	var th := 0.05
	var pts := []
	var n := 16
	for i in n:
		var a := TAU * i / n
		var x := cos(a) * hw
		var z := sin(a) * hl
		# squarer outline
		x = sign(x) * pow(abs(cos(a)), 0.55) * hw
		z = sign(z) * pow(abs(sin(a)), 0.55) * hl
		pts.append(Vector3(x, 0, z))
	var top := Vector3(0, th, 0)
	for i in n:
		var j := (i + 1) % n
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[j]
		var stripe: bool = abs((p0.z + p1.z) * 0.5) < 0.18
		# nose/tail kick up
		var k0 := Vector3(0, max(0.0, abs(p0.z) - 0.6) * 0.5, 0)
		var k1 := Vector3(0, max(0.0, abs(p1.z) - 0.6) * 0.5, 0)
		_tri(st, top + Vector3(0, 0, 0), p1 + top + k1, p0 + top + k0, acc if stripe else col)
		_tri(st, Vector3.ZERO, p0 + k0, p1 + k1, col.darkened(0.4))
		_quad(st, p0 + k0, p0 + top + k0, p1 + top + k1, p1 + k1, acc.darkened(0.2))
	var m := _finish(st)
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.roughness = 0.4
	mt.metallic = 0.2 if b.id != "gold" else 0.8
	if b.glow > 0.0:
		mt.emission_enabled = true
		mt.emission = col
		mt.emission_energy_multiplier = b.glow
	m.surface_set_material(0, mt)
	return m

## Distant mountain range ring (not curved, follows camera).
static func mountains() -> ArrayMesh:
	var st := _begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var segs := 64
	var r := 420.0
	var peaks := []
	for i in segs:
		peaks.append(rng.randf_range(50, 150) * (1.0 if i % 3 != 0 else 1.5))
	for i in segs:
		var j := (i + 1) % segs
		var a0 := TAU * i / segs
		var a1 := TAU * j / segs
		var am := (a0 + a1) * 0.5 if j != 0 else (a0 + TAU) * 0.5
		var b0 := Vector3(cos(a0) * r, -60, sin(a0) * r)
		var b1 := Vector3(cos(a1) * r, -60, sin(a1) * r)
		var pk := Vector3(cos(am) * r * 0.98, peaks[i], sin(am) * r * 0.98)
		var mid0 := b0.lerp(pk, 0.62)
		var mid1 := b1.lerp(pk, 0.62)
		var rock_c := Color(0.55, 0.62, 0.78)
		_quad(st, b0, b1, mid1, mid0, rock_c if i % 2 == 0 else rock_c.darkened(0.08))
		_tri(st, mid0, mid1, pk, Color(0.93, 0.96, 1.0) if i % 2 == 0 else Color(0.84, 0.9, 1.0))
	var m := _finish(st)
	# faces point inward toward camera
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.disable_fog = true
	m.surface_set_material(0, mt)
	return m
