class_name Generator
extends RefCounted
## Builds the mountain ahead of the rider in sections.
## 1. A smooth SAFE LINE (lateral offset u(a)) is laid down first: it is always rideable without jumping.
## 2. Each section sets the slope profile and adds terrain features (lips, cliffs, crevasses, rivers).
## 3. Obstacles are scattered away from the safe line and feature zones.
## 4. A ghost rider follows the safe line with the real physics and drops coins along its path
##    (so coin arcs over lips/cliffs match real trajectories). If the ghost ever falls, the
##    section was unfair: it is logged as a generator bug (the autotest checks this).

const SAFE_CLEAR := 2.6
const MIN_SPACING := 3.0

var world # World
var track: Track
var rng := RandomNumberGenerator.new()
var seed_v := 0

var next_a := 0.0 # start of next section
var safe_pts: Array = [] # Vector2(a, u), increasing a
var zones: Array = [] # [a0, a1, u0, u1] exclusion boxes for obstacles
var coin_ranges: Array = [] # [a0, a1]
var powerups: Array = [] # [a, type]
var forced: Array = []
var _forced_i := 0
var speed_hint := 22.0
var sections_made: Array = []

# ghost
var g := {}
var ghost_failures := 0
var _next_coin := 0.0

func _init(w, t: Track, s: int) -> void:
	world = w
	track = t
	seed_v = s
	rng.seed = s
	safe_pts = [Vector2(-60, 0), Vector2(0, 0), Vector2(60, 0)]
	g = {"u": 0.0, "a": 2.0, "y": 0.0, "vy": 0.0, "grounded": true, "air": 0.0}

func difficulty(a: float) -> float:
	return clamp(a / 4000.0, 0.0, 1.0)

# ------------------------------------------------------------------ safe line
func safe_u(a: float) -> float:
	var n := safe_pts.size()
	var i := 1
	while i < n - 2 and safe_pts[i + 1].x < a:
		i += 1
	var p0: Vector2 = safe_pts[i - 1]
	var p1: Vector2 = safe_pts[i]
	var p2: Vector2 = safe_pts[min(i + 1, n - 1)]
	var p3: Vector2 = safe_pts[min(i + 2, n - 1)]
	var t: float = clamp((a - p1.x) / max(p2.x - p1.x, 0.001), 0.0, 1.0)
	var t2 := t * t
	var t3 := t2 * t
	var u := 0.5 * ((2.0 * p1.y) + (-p0.y + p2.y) * t + (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 + (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3)
	return clamp(u, -Track.HALF_W + 2.0, Track.HALF_W - 2.0)

## Adds safe-line points up to a_end. wiggle = max lateral offset change per 40 m.
func _extend_safe(a_end: float, wiggle: float, center_bias := 0.0) -> void:
	# keep max lateral slope rideable at the expected speed (lateral max ~7 m/s, use 55%)
	var max_slope: float = 7.0 * 0.55 / max(speed_hint, 10.0)
	var last: Vector2 = safe_pts[-1]
	while last.x < a_end + 60.0:
		var step := rng.randf_range(34.0, 48.0)
		var lim: float = min(wiggle, max_slope * step)
		var u: float = last.y + rng.randf_range(-lim, lim)
		u = lerp(u, 0.0, center_bias)
		u = clamp(u, -Track.HALF_W + 3.0, Track.HALF_W - 3.0)
		last = Vector2(last.x + step, u)
		safe_pts.append(last)

func _pin_safe(a0: float, a1: float, u: float) -> void:
	# force the safe line to u over [a0, a1] (replace points in range)
	safe_pts = safe_pts.filter(func(p): return p.x < a0 - 20.0 or p.x > a1 + 20.0)
	safe_pts.append(Vector2(a0 - 20.0, u))
	safe_pts.append(Vector2(a0, u))
	safe_pts.append(Vector2((a0 + a1) * 0.5, u))
	safe_pts.append(Vector2(a1, u))
	safe_pts.sort_custom(func(p, q): return p.x < q.x)

# ------------------------------------------------------------------ main
func generate_to(a_target: float) -> void:
	while next_a < a_target:
		_make_section()
	# ghost needs ground ahead of itself
	_run_ghost(track.front - 60.0)

func _pick() -> String:
	if not forced.is_empty():
		var f: String = forced[_forced_i % forced.size()]
		_forced_i += 1
		return f
	if next_a < 50.0:
		return "intro"
	var d := difficulty(next_a)
	var w := {
		"cruise": 1.0 - d * 0.5,
		"forest": 0.8 + d * 0.6,
		"lips": 1.0,
		"rocks": 0.6 + d * 0.4,
		"logs": 0.4 + d * 0.3,
		"steep": 0.5,
		"flat": 0.35,
		"cliff": 0.0 if next_a < 250.0 else 0.75,
		"crevasse": 0.0 if next_a < 400.0 else 0.5 + d * 0.4,
		"river": 0.0 if next_a < 600.0 else 0.4,
	}
	# avoid repeating the same section twice
	if not sections_made.is_empty():
		w[sections_made[-1]] = w.get(sections_made[-1], 0.0) * 0.25
	var total := 0.0
	for k in w:
		total += w[k]
	var r := rng.randf() * total
	for k in w:
		r -= w[k]
		if r <= 0.0:
			return k
	return "cruise"

func _make_section() -> void:
	var kind := _pick()
	var a := next_a
	var d := difficulty(a)
	var len := 120.0
	track.theta_target = deg_to_rad(19.0)
	track.roll_target = 0.3
	match kind:
		"intro":
			len = 70.0
			_extend_safe(a + len, 1.0, 1.0)
			coin_ranges.append([a + 25.0, a + 55.0])
		"cruise":
			len = rng.randf_range(110, 150)
			track.theta_target = deg_to_rad(rng.randf_range(18, 21))
			track.roll_target = 0.4
			_extend_safe(a + len, 5.0)
			_scatter(a, a + len, 0.035 + d * 0.03, {"pine": 0.7, "rock": 0.3})
			_coins(a + 10, a + len - 10, 2)
		"forest":
			len = rng.randf_range(100, 140)
			track.roll_target = 0.25
			_extend_safe(a + len, 7.0)
			_scatter(a, a + len, 0.10 + d * 0.09, {"pine": 0.85, "snowman": 0.05, "rock": 0.1})
			_coins(a + 10, a + len - 10, 3)
		"lips":
			len = rng.randf_range(100, 130)
			track.roll_target = 0.15
			_extend_safe(a + len, 4.0)
			var n := rng.randi_range(2, 3)
			for i in n:
				var top := a + 30.0 + i * (len - 40.0) / n
				_lip(top, safe_u(top), rng.randf_range(3.5, 7.0), rng.randf_range(1.5, 2.5) + d * 0.5, rng.randf() < 0.5)
			_scatter(a, a + len, 0.03 + d * 0.03, {"pine": 0.8, "rock": 0.2})
			coin_ranges.append([a + 15.0, a + len - 5.0])
		"cliff":
			len = 140.0
			var lead: float = max(30.0, speed_hint * 1.5)
			var ac := a + lead
			var h := rng.randf_range(4.5, 7.0) + d * 5.0
			_extend_safe(a + len, 2.0, 0.4)
			track.add_cliff(ac, h)
			track.roll_target = 0.0
			track.extend_to(ac + 3.0)
			track.theta_target = deg_to_rad(27.0) # steep landing run-out
			track.extend_to(ac + 45.0)
			track.theta_target = deg_to_rad(19.0)
			track.roll_target = 0.3
			zones.append([ac - lead + 5.0, ac + 45.0, -99.0, 99.0])
			_scatter(ac + 45.0, a + len, 0.04, {"pine": 0.8, "rock": 0.2})
			coin_ranges.append([ac - 18.0, ac + 40.0])
		"rocks":
			len = rng.randf_range(90, 120)
			_extend_safe(a + len, 5.0)
			_scatter(a, a + len, 0.08 + d * 0.06, {"rock": 0.6, "boulder": 0.3, "pine": 0.1})
			_coins(a + 10, a + len - 10, 2)
		"logs":
			len = rng.randf_range(90, 120)
			_extend_safe(a + len, 4.0)
			var n2 := rng.randi_range(2, 4)
			for i in n2:
				var la := a + 20.0 + i * (len - 30.0) / n2
				var su := safe_u(la)
				var side := -1.0 if su > 0.0 else 1.0
				if rng.randf() < 0.35:
					side = -side
				var half := rng.randf_range(2.5, 4.5)
				var cu: float = su + side * (SAFE_CLEAR + half)
				world.spawn_obstacle("log", cu, la, {"half": half})
			_scatter(a, a + len, 0.03, {"pine": 1.0})
			_coins(a + 10, a + len - 10, 2)
		"steep":
			len = rng.randf_range(100, 140)
			track.theta_target = deg_to_rad(26.0 + d * 3.0)
			track.roll_target = 0.2
			_extend_safe(a + len, 3.0)
			_scatter(a, a + len, 0.03 + d * 0.02, {"pine": 0.7, "rock": 0.3})
			_coins(a + 10, a + len - 10, 1)
		"flat":
			len = rng.randf_range(70, 90)
			track.theta_target = deg_to_rad(12.0)
			track.roll_target = 0.5
			_extend_safe(a + len, 5.0)
			_scatter(a, a + len, 0.02, {"pine": 1.0})
			coin_ranges.append([a + 10.0, a + len - 10.0])
			powerups.append([a + len * 0.6, ["magnet", "boost", "x2"][rng.randi() % 3]])
		"crevasse":
			len = rng.randf_range(90, 120)
			_extend_safe(a + len, 3.0)
			var n3 := rng.randi_range(1, 2)
			for i in n3:
				var ca := a + 30.0 + i * 40.0
				var su := safe_u(ca + 3.0)
				# crevasse covers the side away from the safe line, up to SAFE_CLEAR of it
				var side := -1.0 if su > 0.0 else 1.0
				var edge: float = side * Track.EDGE
				var near: float = su + side * (SAFE_CLEAR + 0.4)
				var cu := (edge + near) * 0.5
				var hw: float = abs(edge - near) * 0.5
				if hw < 2.0:
					continue
				var clen := rng.randf_range(4.0, 6.5)
				var f := {"kind": "crevasse", "a0": ca, "a1": ca + clen, "u": cu, "w": hw, "depth": 9.0}
				track.add_feature(f)
				world.on_feature(f)
				zones.append([ca - 6.0, ca + clen + 6.0, cu - hw - 1.5, cu + hw + 1.5])
			_scatter(a, a + len, 0.04, {"pine": 0.8, "rock": 0.2})
			_coins(a + 10, a + len - 10, 2)
		"river":
			len = 90.0
			_extend_safe(a + len, 2.0, 0.3)
			var lip_top := a + 35.0
			_lip(lip_top, 0.0, 30.0, 1.5, false)
			var width := rng.randf_range(5.5, 8.5)
			var r0 := lip_top + 5.0
			var f2 := {"kind": "river", "a0": r0, "a1": r0 + width, "depth": 1.8}
			track.add_feature(f2)
			world.on_feature(f2)
			zones.append([lip_top - 20.0, r0 + width + 25.0, -99.0, 99.0])
			coin_ranges.append([lip_top - 15.0, r0 + width + 20.0])
	sections_made.append(kind)
	track.extend_to(a + len + 2.0)
	for f in track.features:
		if f.kind == "cliff" and not f.has("shown"):
			f.shown = true
			world.on_feature(f)
	next_a = a + len

func _lip(top: float, u: float, w: float, h: float, rocky: bool) -> void:
	var rise := 5.5 + h * 1.6
	var f := {"kind": "lip", "a0": top - rise, "top": top, "a1": top + 1.6, "u": u, "w": w, "h": h, "rocky": rocky}
	track.add_feature(f)
	world.on_feature(f)
	zones.append([f.a0 - 3.0, top + 22.0, u - w - 2.0, u + w + 2.0])

func _coins(a0: float, a1: float, groups: int) -> void:
	var span := (a1 - a0) / groups
	for i in groups:
		var s := a0 + i * span + rng.randf_range(0.0, span * 0.4)
		coin_ranges.append([s, s + 26.0])
		if rng.randf() < 0.07:
			powerups.append([s + 34.0, ["magnet", "boost", "x2"][rng.randi() % 3]])

func _blocked(u: float, a: float) -> bool:
	if abs(u - safe_u(a)) < SAFE_CLEAR:
		return true
	for z in zones:
		if a > z[0] and a < z[1] and u > z[2] and u < z[3]:
			return true
	return false

func _scatter(a0: float, a1: float, per_m: float, mix: Dictionary) -> void:
	var count := int((a1 - a0) * per_m)
	var placed: Array = []
	var tries := count * 6
	while count > 0 and tries > 0:
		tries -= 1
		var a := rng.randf_range(a0, a1)
		var u := rng.randf_range(-Track.HALF_W + 0.8, Track.HALF_W - 0.8)
		if _blocked(u, a):
			continue
		var ok := true
		for p in placed:
			if abs(p.x - u) < MIN_SPACING and abs(p.y - a) < MIN_SPACING * 1.5:
				ok = false
				break
		if not ok:
			continue
		placed.append(Vector2(u, a))
		var r := rng.randf()
		var t := "pine"
		for k in mix:
			r -= mix[k]
			if r <= 0.0:
				t = k
				break
		world.spawn_obstacle(t, u, a, {})
		count -= 1

# ------------------------------------------------------------------ ghost
func _run_ghost(a_to: float) -> void:
	var dt := 1.0 / 30.0
	var v: float = speed_hint + 1.0
	while g.a < a_to:
		g.a += v * dt
		g.u = safe_u(g.a)
		var res := Rider.surface_step(g, track, dt)
		if res == "fell":
			ghost_failures += 1
			push_warning("GEN: ghost fell at a=%.0f (section %s)" % [g.a, str(sections_made.slice(-3))])
			g.y = track.height(g.u, g.a + 12.0)
			g.a += 12.0
			g.vy = 0.0
			g.grounded = true
		# coins
		var in_range := false
		for c in coin_ranges:
			if g.a >= c[0] and g.a <= c[1]:
				in_range = true
				break
		if in_range and g.a >= _next_coin:
			world.spawn_pickup("coin", g.u, g.a, g.y + 0.9)
			_next_coin = g.a + 3.3
		for p in powerups:
			if p[0] <= g.a and p.size() == 2:
				world.spawn_pickup(p[1], g.u, g.a, g.y + 1.1)
				p.append(true)
	coin_ranges = coin_ranges.filter(func(c): return c[1] > g.a)
	powerups = powerups.filter(func(p): return p.size() == 2)
	zones = zones.filter(func(z): return z[1] > g.a - 100.0)
