class_name Track
extends RefCounted
## The mountain: a meandering path down a slope.
##
## Path space: `a` = distance along the path (m), `u` = lateral offset from the path centre (m, +right),
## heights are ABSOLUTE world heights (negative and growing as we descend).
## Per-metre tables (64-bit) hold the path centre (px, pz), heading psi and accumulated drop D(a).
## Local terrain (banks, rollers, lips, crevasses, rivers) is added on top: height = -D(a) + local(u, a).
## Render coordinates = world coordinates minus a floating origin (see to_render / rebase).

const HALF_W := 12.0 # playable half width of the run
const EDGE := 13.5 # rider is clamped here (banks start at HALF_W)
const OPEN := -1.0e9 # ground value meaning "no ground here" (crevasse / open water)

var i0 := 0 # absolute metre index of table element 0
var px := PackedFloat64Array()
var pz := PackedFloat64Array()
var psi := PackedFloat64Array()
var drop := PackedFloat64Array()
var roll := PackedFloat32Array() # roller amplitude per metre
var front := 0 # tables valid for a in [i0, front]

var theta := deg_to_rad(19.0) # current slope angle while extending
var theta_target := deg_to_rad(19.0)
var roll_target := 0.3
var _roll_cur := 0.3

var features: Array = [] # dicts sorted by a0: lip / crevasse / river / cliff
var cliffs: Array = [] # [a_c, face_len, H] used while extending the drop table

var noise: FastNoiseLite
var hills: FastNoiseLite
var _phase := []

# floating origin (absolute world coords)
var ox := 0.0
var oy := 0.0
var oz := 0.0

func _init(seed_v: int) -> void:
	noise = FastNoiseLite.new()
	noise.seed = seed_v
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.08
	hills = FastNoiseLite.new()
	hills.seed = seed_v + 7
	hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills.frequency = 0.02
	hills.fractal_octaves = 3
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	_phase = [r.randf() * TAU, r.randf() * TAU, r.randf() * TAU]
	px.append(0.0); pz.append(0.0); psi.append(_heading(0.0)); drop.append(0.0); roll.append(0.0)
	front = 0

# ------------------------------------------------------------------ generation
func _heading(a: float) -> float:
	# gentle meander: radius of curvature stays > ~250 m
	return 0.30 * sin(a / 210.0 + _phase[0]) + 0.16 * sin(a / 83.0 + _phase[1]) + 0.05 * sin(a / 37.0 + _phase[2])

## Queue a cliff drop of height h starting at a_c (must be called before extending past it).
func add_cliff(a_c: float, h: float) -> void:
	var face: float = clamp(h * 0.22, 1.5, 3.0)
	cliffs.append([a_c, face, h])
	add_feature({"kind": "cliff", "a0": a_c, "a1": a_c + face, "h": h})

func add_feature(f: Dictionary) -> void:
	features.append(f)
	features.sort_custom(func(x, y): return x.a0 < y.a0)

func extend_to(a_end: float) -> void:
	while front < int(a_end):
		var i := front - i0
		var a := float(front)
		# ease slope + roller amplitude toward targets
		theta = move_toward(theta, theta_target, deg_to_rad(0.35))
		_roll_cur = move_toward(_roll_cur, roll_target, 0.01)
		var d := tan(theta)
		for c in cliffs:
			if a >= c[0] and a < c[0] + c[1]:
				d += c[2] / c[1]
		var h := _heading(a + 0.5)
		px.append(px[i] + sin(h))
		pz.append(pz[i] - cos(h))
		psi.append(_heading(a + 1.0))
		drop.append(drop[i] + d)
		roll.append(_roll_cur)
		front += 1

## Forget data far behind the rider.
func prune(a_keep: float) -> void:
	var n := int(a_keep) - i0
	if n < 200:
		return
	px = px.slice(n); pz = pz.slice(n); psi = psi.slice(n); drop = drop.slice(n); roll = roll.slice(n)
	i0 += n
	features = features.filter(func(f): return f.a1 > a_keep)
	cliffs = cliffs.filter(func(c): return c[0] + c[1] > a_keep)

# ------------------------------------------------------------------ sampling
func _lerp_tab(tab, a: float) -> float:
	var f := a - i0
	var i := int(floor(f))
	i = clampi(i, 0, tab.size() - 2)
	var t: float = clamp(f - i, 0.0, 1.0)
	return lerp(tab[i], tab[i + 1], t)

func heading(a: float) -> float:
	return _lerp_tab(psi, a)

func drop_at(a: float) -> float:
	return _lerp_tab(drop, a)

func forward(a: float) -> Vector3:
	var h := heading(a)
	return Vector3(sin(h), 0, -cos(h))

func right(a: float) -> Vector3:
	var h := heading(a)
	return Vector3(cos(h), 0, sin(h))

## Slope angle (positive = descending) of the nominal profile at a.
func slope_at(a: float) -> float:
	return atan((drop_at(a + 1.0) - drop_at(a - 1.0)) * 0.5)

func rollers(a: float) -> float:
	var amp := _lerp_tab(roll, a)
	return amp * (sin(a * TAU / 21.0) + 0.35 * sin(a * TAU / 8.5 + 1.3))

## Local terrain height relative to the nominal slope (no opening checks).
func local(u: float, a: float) -> float:
	var au: float = abs(u)
	var edge_fade: float = 1.0 - smoothstep(HALF_W - 3.0, HALF_W + 4.0, au) * 0.6
	var h := rollers(a) * edge_fade + noise.get_noise_2d(u, a) * 0.18
	var e: float = au - HALF_W
	if e > 0.0:
		h += min(e * 0.25, 2.5) + (hills.get_noise_2d(u, a) * 0.5 + 0.5) * smoothstep(0.0, 40.0, e) * 6.0
	for f in features:
		if f.a0 - 2.0 > a:
			break
		if f.a1 + 2.0 < a:
			continue
		match f.kind:
			"lip":
				h += _lip(f, u, a)
			"crevasse":
				var du: float = abs(u - f.u)
				var k: float = (1.0 - smoothstep(f.w - 0.6, f.w, du)) * (smoothstep(f.a0 - 0.6, f.a0, a) - smoothstep(f.a1, f.a1 + 0.6, a))
				h -= f.depth * k
			"river":
				var k2: float = smoothstep(f.a0 - 1.2, f.a0, a) - smoothstep(f.a1, f.a1 + 1.2, a)
				h = lerp(h, -f.depth, k2)
	return h

func _lip(f: Dictionary, u: float, a: float) -> float:
	var lat: float = 1.0 - smoothstep(f.w - 2.5, f.w, abs(u - f.u))
	if lat <= 0.0:
		return 0.0
	var prof := 0.0
	if a <= f.top:
		var t: float = clamp((a - f.a0) / (f.top - f.a0), 0.0, 1.0)
		prof = pow(t, 1.7)
	else:
		var t2: float = clamp((a - f.top) / (f.a1 - f.top), 0.0, 1.0)
		prof = 1.0 - t2 * t2 * (3.0 - 2.0 * t2)
	return f.h * prof * lat

## Absolute terrain height (visual surface).
func height(u: float, a: float) -> float:
	return -drop_at(a) + local(u, a)

## Ridable ground (OPEN over crevasses and open water).
func ground(u: float, a: float) -> float:
	for f in features:
		if f.a0 > a:
			break
		if a > f.a1:
			continue
		if f.kind == "crevasse" and abs(u - f.u) < f.w - 0.3 and a > f.a0 + 0.2 and a < f.a1 - 0.2:
			return OPEN
		if f.kind == "river" and a > f.a0 + 0.3 and a < f.a1 - 0.3:
			return OPEN
	return height(u, a)

## Depth (absolute) at which a rider in an opening counts as "fallen in".
func opening_floor(u: float, a: float) -> float:
	return height(u, a) + 0.4

func feature_at(a: float, kind: String) -> Dictionary:
	for f in features:
		if f.a0 > a:
			break
		if f.kind == kind and a <= f.a1:
			return f
	return {}

# ------------------------------------------------------------------ render space
func to_render(u: float, a: float, y: float) -> Vector3:
	var cx := _lerp_tab(px, a)
	var cz := _lerp_tab(pz, a)
	var h := heading(a)
	return Vector3(cx + cos(h) * u - ox, y - oy, cz + sin(h) * u - oz)

## Moves the floating origin to path point a; returns the shift to apply to existing render nodes.
func rebase(a: float) -> Vector3:
	var nx := _lerp_tab(px, a)
	var ny := -drop_at(a)
	var nz := _lerp_tab(pz, a)
	var shift := Vector3(ox - nx, oy - ny, oz - nz)
	ox = nx; oy = ny; oz = nz
	return shift

## Surface normal in world space at (u, a).
func normal(u: float, a: float) -> Vector3:
	var hu := (height(u + 0.5, a) - height(u - 0.5, a))
	var ha := (height(u, a + 0.5) - height(u, a - 0.5))
	return (Vector3.UP - right(a) * hu - forward(a) * ha).normalized()
