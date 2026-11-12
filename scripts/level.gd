class_name Level
extends Node3D
## Infinite procedural downhill: terrain chunks, obstacle patterns, pickups.
## Everything lives under `scroller`, which moves toward the camera as the player travels.

const LANES := [-2.6, 0.0, 2.6]
const CHUNKS_AHEAD := 9
const GEN_AHEAD := 240.0
const REBASE := 1000.0

var scroller: Node3D
var base := 0.0 # origin offset to keep local coordinates small
var dist := 0.0
var rng := RandomNumberGenerator.new()

var chunks := {} # index -> Node3D
var obstacles: Array = [] # {type,a0,a1,x,hw,h,node}
var ramps: Array = [] # {a0,a1,x,hw,h,node}
var pickups: Array = [] # {type,a,x,y,node,taken}
var waters: Array = [] # {a0,a1,node}

var next_a := 70.0
var last_river := 0.0
var speed_hint := 14.0
var powerup_chance := 0.06
var debug_force: Array = []
var _dbg_i := 0

var _water_shader: Shader = preload("res://shaders/water.gdshader")
var _water_mat: ShaderMaterial

func _ready() -> void:
	scroller = Node3D.new()
	scroller.name = "Scroller"
	add_child(scroller)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = _water_shader

func reset(seed_v: int) -> void:
	for c in scroller.get_children():
		c.queue_free()
	chunks.clear()
	obstacles.clear()
	ramps.clear()
	pickups.clear()
	waters.clear()
	rng.seed = seed_v
	Terrain.setup(seed_v)
	base = 0.0
	dist = 0.0
	next_a = 70.0
	last_river = 0.0
	# a few starter coins so the first seconds feel alive
	coin_line(28.0, 1, 8, 3.0)
	update_world(0.0)

func local_z(a: float) -> float:
	return -(a - base)

func update_world(d: float) -> void:
	dist = d
	if dist - base > REBASE:
		base += REBASE
		for c in scroller.get_children():
			c.position.z += REBASE
	scroller.position.z = dist - base
	# generate gameplay ahead (before terrain so rivers carve correctly)
	while next_a < dist + GEN_AHEAD:
		_gen_pattern()
	# terrain chunks
	var ci := int(floor(dist / Terrain.CHUNK_LEN))
	for i in range(ci - 1, ci + CHUNKS_AHEAD):
		if i >= 0 and not chunks.has(i):
			chunks[i] = _make_chunk(i)
	for k in chunks.keys():
		if k < ci - 1:
			chunks[k].queue_free()
			chunks.erase(k)
	# cleanup passed objects
	var cut := dist - 20.0
	obstacles = obstacles.filter(func(o): return _keep(o, o.a1, cut))
	ramps = ramps.filter(func(o): return _keep(o, o.a1, cut))
	pickups = pickups.filter(func(o): return _keep(o, o.a, cut))
	waters = waters.filter(func(o): return _keep(o, o.a1, cut))
	Terrain.rivers = Terrain.rivers.filter(func(r): return r[1] > dist - 60.0)

func _keep(o: Dictionary, a: float, cut: float) -> bool:
	if a < cut:
		if is_instance_valid(o.node):
			o.node.queue_free()
		return false
	return true

# ------------------------------------------------------------------ queries
## Height of the ridable surface (track, ramps). Returns -INF over open river water.
func ground_at(x: float, a: float) -> float:
	var g := 0.0
	for r in Terrain.rivers:
		if a > r[0] and a < r[1]:
			g = -100.0
			break
	for r in ramps:
		if a >= r.a0 and a <= r.a1 and abs(x - r.x) < r.hw:
			var t: float = (a - r.a0) / (r.a1 - r.a0)
			g = max(g, r.h * t)
	return g

## Returns the ramp under the player (or {}).
func ramp_at(x: float, a: float) -> Dictionary:
	for r in ramps:
		if a >= r.a0 and a <= r.a1 and abs(x - r.x) < r.hw:
			return r
	return {}

func in_river(a: float) -> bool:
	for r in Terrain.rivers:
		if a > r[0] + 0.4 and a < r[1] - 0.4:
			return true
	return false

## First obstacle colliding with a player box at (x, a, y).
func hit_test(x: float, a: float, y: float, pw: float = 0.45) -> Dictionary:
	for o in obstacles:
		if o.get("dead", false):
			continue
		if a + 0.4 < o.a0 or a - 0.4 > o.a1:
			continue
		if abs(x - o.x) > o.hw + pw:
			continue
		if y > o.h:
			continue
		return o
	# side impact with ramp walls (switching lanes into a ramp while low)
	for r in ramps:
		if a > r.a0 + 1.5 and a < r.a1 and abs(x - r.x) < r.hw + pw * 0.3 and abs(x - r.x) > r.hw - 0.5:
			var surf: float = r.h * (a - r.a0) / (r.a1 - r.a0)
			if y < surf - 0.9:
				return {"type": "ramp_side", "a0": a, "a1": a, "x": r.x, "hw": r.hw, "h": surf, "node": null}
	return {}

# ------------------------------------------------------------------ building blocks
func _place(node: Node3D, a: float, x: float, y: float = 0.0) -> void:
	scroller.add_child(node)
	node.position = Vector3(x, y, local_z(a))

func _mi(mesh: Mesh) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	return m

func add_tree(a: float, lane: int) -> void:
	var n := _mi(Meshes.pine(rng.randi() % 3))
	var s := rng.randf_range(0.95, 1.2)
	n.scale = Vector3(s, s * rng.randf_range(0.95, 1.15), s)
	n.rotation.y = rng.randf() * TAU
	_place(n, a, LANES[lane] + rng.randf_range(-0.2, 0.2))
	obstacles.append({"type": "tree", "a0": a - 0.6, "a1": a + 0.6, "x": n.position.x, "hw": 0.75, "h": 99.0, "node": n})

func add_rock(a: float, lane: int) -> void:
	var n := _mi(Meshes.rock(rng.randi() % 4))
	n.scale = Vector3(1.15, 1.0, 1.0) * rng.randf_range(0.95, 1.1)
	n.rotation.y = rng.randf() * TAU
	_place(n, a, LANES[lane])
	obstacles.append({"type": "rock", "a0": a - 0.9, "a1": a + 0.9, "x": LANES[lane], "hw": 1.0, "h": 0.95, "node": n})

func add_snowman(a: float, lane: int) -> void:
	var n := _mi(Meshes.snowman())
	_place(n, a, LANES[lane])
	n.rotation.y = rng.randf_range(-0.4, 0.4)
	obstacles.append({"type": "snowman", "a0": a - 0.7, "a1": a + 0.7, "x": LANES[lane], "hw": 0.75, "h": 99.0, "node": n, "smash": true})

func add_log(a: float) -> void:
	var n := _mi(Meshes.log_mesh(9.0))
	n.rotation.y = rng.randf_range(-0.05, 0.05)
	_place(n, a, 0.0)
	obstacles.append({"type": "log", "a0": a - 0.5, "a1": a + 0.5, "x": 0.0, "hw": 4.5, "h": 0.95, "node": n})

func add_ramp(a: float, lane: int, wide := false) -> Dictionary:
	var w := 8.6 if wide else 2.5
	var l := 8.0 if wide else 6.5
	var h := 2.4 if wide else 2.0
	var n := _mi(Meshes.ramp(w, l, h, rng.randi() % 3))
	var x: float = 0.0 if wide else LANES[lane]
	_place(n, a, x)
	var r := {"a0": a, "a1": a + l, "x": x, "hw": w * 0.5, "h": h, "node": n}
	ramps.append(r)
	return r

func add_river(a: float, width: float) -> void:
	Terrain.rivers.append([a, a + width])
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, width + 3.0)
	plane.subdivide_width = 24
	plane.subdivide_depth = 2
	var n := _mi(plane)
	n.material_override = _water_mat
	_place(n, a + width * 0.5, 0.0, Terrain.WATER_Y)
	waters.append({"a0": a, "a1": a + width, "node": n})
	last_river = a

func add_pickup(type: String, a: float, x: float, y: float = 1.0) -> void:
	var mesh: Mesh
	match type:
		"coin": mesh = Meshes.coin()
		"magnet": mesh = Meshes.magnet()
		"boost": mesh = Meshes.crystal(Color(0.2, 0.85, 1.0))
		"x2": mesh = Meshes.crystal(Color(1.0, 0.3, 0.85))
	var n := _mi(mesh)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if type != "coin":
		n.scale = Vector3.ONE * 1.3
	_place(n, a, x, y)
	pickups.append({"type": type, "a": a, "x": x, "y": y, "node": n, "taken": false})

func coin_line(a: float, lane: int, count: int, spacing: float, y: float = 0.9) -> void:
	for i in count:
		add_pickup("coin", a + i * spacing, LANES[lane], y)

## Coins following a jump arc starting at a, using jump velocity vy from height y0.
func coin_arc(a: float, x: float, vy: float, y0: float, speed: float, count: int = 7) -> void:
	var g := Player.GRAVITY
	# time to land back at 0
	var t_end := (vy + sqrt(vy * vy + 2.0 * g * y0)) / g
	for i in count:
		var t := t_end * (float(i) + 0.5) / count
		var y := y0 + vy * t - 0.5 * g * t * t + 0.9
		add_pickup("coin", a + speed * t, x, y)

# ------------------------------------------------------------------ patterns
func _difficulty() -> float:
	return clamp(next_a / 3500.0, 0.0, 1.0)

func _gen_pattern() -> void:
	var d := _difficulty()
	var s := speed_hint
	var a := next_a
	var len := 2.0
	var roll := rng.randf()
	var can_river := a - last_river > 260.0 and a > 380.0
	if not debug_force.is_empty():
		var f: String = debug_force[_dbg_i % debug_force.size()]
		_dbg_i += 1
		match f:
			"river": len = _p_river(a, s)
			"ramp": len = _p_ramp(a, s)
			"trees": len = _p_trees(a, 2)
			"rocks": len = _p_rocks(a, s)
			"log": len = _p_log(a, s)
			"slalom": len = _p_slalom(a, s)
			"mixed": len = _p_mixed(a, s)
			"coins": len = _p_coins(a)
	elif can_river and roll < 0.14 + d * 0.06:
		len = _p_river(a, s)
	elif roll < 0.30:
		len = _p_trees(a, rng.randi_range(1, 2) if d < 0.3 else 2)
	elif roll < 0.42:
		len = _p_rocks(a, s)
	elif roll < 0.52:
		len = _p_log(a, s)
	elif roll < 0.66:
		len = _p_ramp(a, s)
	elif roll < 0.76 and d > 0.12:
		len = _p_slalom(a, s)
	elif roll < 0.88:
		len = _p_mixed(a, s)
	else:
		len = _p_coins(a)
	# reaction gap scales with speed so it stays fair
	var gap: float = s * lerp(1.45, 0.95, d) + rng.randf_range(0.0, 6.0)
	next_a = a + len + gap

func _free_lane_except(blocked: Array) -> int:
	var free := []
	for i in 3:
		if not i in blocked:
			free.append(i)
	return free[rng.randi() % free.size()] if free.size() > 0 else 1

func _maybe_powerup(a: float, lane: int) -> bool:
	if rng.randf() < powerup_chance:
		var types := ["magnet", "boost", "x2"]
		add_pickup(types[rng.randi() % 3], a, LANES[lane], 1.1)
		return true
	return false

func _p_trees(a: float, n: int) -> float:
	var lanes := [0, 1, 2]
	lanes.shuffle()
	var blocked := lanes.slice(0, n)
	for l in blocked:
		if rng.randf() < 0.18:
			add_snowman(a, l)
		else:
			add_tree(a, l)
	var free := _free_lane_except(blocked)
	if not _maybe_powerup(a, free):
		coin_line(a - 9.0, free, 6, 2.6)
	return 2.0

func _p_rocks(a: float, s: float) -> float:
	var n := rng.randi_range(1, 3)
	var lanes := [0, 1, 2]
	lanes.shuffle()
	for i in n:
		add_rock(a, lanes[i])
	# coin arc over the first rock
	coin_arc(a - s * 0.36, LANES[lanes[0]], Player.JUMP_V, 0.0, s, 6)
	return 2.0

func _p_log(a: float, s: float) -> float:
	add_log(a)
	var lane := rng.randi() % 3
	coin_arc(a - s * 0.36, LANES[lane], Player.JUMP_V, 0.0, s, 6)
	return 2.0

func _p_ramp(a: float, s: float) -> float:
	var lane := rng.randi() % 3
	var r := add_ramp(a, lane)
	# block another lane with trees sometimes so the ramp is the fun choice
	if rng.randf() < 0.6:
		var other := (lane + 1 + rng.randi() % 2) % 3
		add_tree(a + 5.0, other)
	var vy: float = s * r.h / (r.a1 - r.a0)
	coin_line(a - 8.0, lane, 3, 2.6)
	coin_arc(r.a1, r.x, vy, r.h, s, 9)
	return r.a1 - a + s * 0.6

func _p_river(a: float, s: float) -> float:
	var width := rng.randf_range(5.5, 8.0)
	# can a plain jump clear it? airtime * speed with margin
	var jump_ok := (2.0 * Player.JUMP_V / Player.GRAVITY) * s > width + 2.0
	var lanes := [0, 1, 2]
	lanes.shuffle()
	var n_ramps := 1 if jump_ok else 3
	if jump_ok and rng.randf() < 0.35:
		n_ramps = 0
	var end_a := a
	for i in n_ramps:
		var r := add_ramp(a, lanes[i])
		end_a = r.a1
		var vy: float = s * r.h / (r.a1 - r.a0)
		coin_arc(r.a1, r.x, vy, r.h, s, 9)
	var start := end_a + 2.0
	if n_ramps < 3:
		var free_lane: int = lanes[2]
		coin_arc(start - s * 0.3, LANES[free_lane], Player.JUMP_V, 0.0, s, 7)
	add_river(start, width)
	# warning poles beside the river
	for side in [-1, 1]:
		var p := _mi(Meshes.pole(Color(1.0, 0.25, 0.15)))
		_place(p, start - 3.0, side * (Terrain.TRACK_HALF - 0.2))
		obstacles.append({"type": "deco", "a0": -1, "a1": start - 3.0, "x": 999, "hw": 0, "h": 0, "node": p, "dead": true})
	return start + width - a + 3.0

func _p_slalom(a: float, s: float) -> float:
	var lane := rng.randi() % 3
	var step := s * 0.75
	for i in 3:
		var blocked := [lane, (lane + 1) % 3] if i % 2 == 0 else [lane]
		for l in blocked:
			add_tree(a + i * step, l)
		var free := _free_lane_except(blocked)
		add_pickup("coin", a + i * step, LANES[free], 0.9)
		lane = (lane + 1 + rng.randi() % 2) % 3
	return step * 2.0 + 2.0

func _p_mixed(a: float, s: float) -> float:
	var lanes := [0, 1, 2]
	lanes.shuffle()
	add_tree(a, lanes[0])
	add_rock(a, lanes[1])
	if rng.randf() < 0.5:
		var r := add_ramp(a - 4.0, lanes[2])
		var vy: float = s * r.h / (r.a1 - r.a0)
		coin_arc(r.a1, r.x, vy, r.h, s, 7)
		return 8.0
	coin_arc(a - s * 0.36, LANES[lanes[1]], Player.JUMP_V, 0.0, s, 6)
	if not _maybe_powerup(a, lanes[2]):
		coin_line(a - 6.0, lanes[2], 4, 2.5)
	return 2.0

func _p_coins(a: float) -> float:
	var lane := rng.randi() % 3
	var count := 0
	var aa := a
	for seg in 3:
		coin_line(aa, lane, 5, 2.6)
		aa += 5 * 2.6 + 3.0
		count += 5
		lane = clamp(lane + (1 if rng.randf() < 0.5 else -1), 0, 2)
	_maybe_powerup(aa, lane)
	return aa - a

# ------------------------------------------------------------------ chunks
func _make_chunk(i: int) -> Node3D:
	var a0 := i * Terrain.CHUNK_LEN
	var root := Node3D.new()
	var t := _mi(Terrain.build_chunk(a0))
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(t)
	_scatter_decor(root, a0, i)
	_place(root, a0, 0.0)
	return root

func _scatter_decor(root: Node3D, a0: float, i: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(i * 7919 + int(Terrain.noise.seed))
	var mm_trees := []
	for v in 3:
		mm_trees.append([])
	var rocks := []
	var poles := []
	# forest on the banks: denser near the track edge
	for n in 26:
		var side := -1.0 if r.randf() < 0.5 else 1.0
		var ax := Terrain.TRACK_HALF + 2.2 + pow(r.randf(), 1.6) * 62.0
		var x := side * ax
		var a := a0 + r.randf() * Terrain.CHUNK_LEN
		if Terrain.river_factor(a) > 0.0:
			continue
		var y := Terrain.height(x, a)
		var s := r.randf_range(0.8, 1.6) * (1.0 + ax * 0.012)
		var tr := Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.9, 1.25), s)), Vector3(x, y - 0.2, -(a - a0)))
		mm_trees[r.randi() % 3].append(tr)
	for n in 5:
		var side := -1.0 if r.randf() < 0.5 else 1.0
		var x := side * (Terrain.TRACK_HALF + 1.0 + r.randf() * 25.0)
		var a := a0 + r.randf() * Terrain.CHUNK_LEN
		if Terrain.river_factor(a) > 0.0:
			continue
		var s := r.randf_range(0.6, 2.2)
		rocks.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * 0.8, s)), Vector3(x, Terrain.height(x, a) - 0.15, -(a - a0))))
	# course marker poles along the edges
	for k in 2:
		var a := a0 + k * Terrain.CHUNK_LEN * 0.5
		if Terrain.river_factor(a) > 0.0:
			continue
		for side in [-1, 1]:
			poles.append(Transform3D(Basis(), Vector3(side * (Terrain.TRACK_HALF + 0.3), 0, -(a - a0))))
	for v in 3:
		_add_mm(root, Meshes.pine(v), mm_trees[v])
	_add_mm(root, Meshes.rock(r.randi() % 4), rocks)
	_add_mm(root, Meshes.pole(Color(0.95, 0.35, 0.1) if i % 2 == 0 else Color(0.15, 0.4, 0.95)), poles)

func _add_mm(root: Node3D, mesh: Mesh, xforms: Array) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)

# ------------------------------------------------------------------ per-frame visuals
func animate(delta: float, t: float) -> void:
	for p in pickups:
		if p.taken or not is_instance_valid(p.node):
			continue
		p.node.rotation.y = t * 3.0 + p.a * 0.2
		if p.type != "coin":
			p.node.position.y = p.y + sin(t * 3.0 + p.a) * 0.15
