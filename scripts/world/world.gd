class_name World
extends Node3D
## Streams the mountain around the rider: terrain chunks, decor, obstacles, pickups, feature visuals.
## Owns the floating origin. All gameplay queries are in path space (u, a, absolute y).

const CHUNKS_AHEAD := 8
const GEN_AHEAD := 300.0
const REBASE_EVERY := 300.0

var track: Track
var gen: Generator
var root: Node3D # everything placed in render space lives here (shifted on rebase)
var pool: Pool
var chunks := {} # index -> {node, mmis}
var _chunk_free: Array = []
var obstacles: Array = [] # {type,u,a,r,ra,h,node,dead}
var pickups: Array = [] # {type,u,a,y,node,taken}
var feature_nodes: Array = [] # {a1, node}
var origin_a := 0.0
var decor_density := 1.0
var seed_v := 0
var forced_sections: Array = [] # dev: --section=a,b

var snow_mat: ShaderMaterial
var _water_mat: ShaderMaterial

func _ready() -> void:
	root = Node3D.new()
	root.name = "Render"
	add_child(root)
	pool = Pool.new(root)
	snow_mat = Meshes.mat("snow")
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = preload("res://shaders/water.gdshader")

func reset(s: int) -> void:
	seed_v = s
	for c in chunks.values():
		_release_chunk(c)
	chunks.clear()
	for o in obstacles:
		pool.give(o.node)
	for p in pickups:
		pool.give(p.node)
	for f in feature_nodes:
		f.node.queue_free()
	obstacles.clear()
	pickups.clear()
	feature_nodes.clear()
	track = Track.new(s)
	gen = Generator.new(self, track, s)
	gen.forced = forced_sections
	origin_a = 0.0
	track.extend_to(GEN_AHEAD + 40.0)
	track.rebase(0.0)
	update(0.0, 22.0)

## Call every frame. Returns the render-space shift applied by a rebase (usually ZERO).
func update(a: float, speed: float) -> Vector3:
	gen.speed_hint = speed
	gen.generate_to(a + GEN_AHEAD)
	var shift := Vector3.ZERO
	if a - origin_a > REBASE_EVERY:
		shift = track.rebase(a)
		origin_a = a
		for c in root.get_children():
			c.position += shift
	# chunks
	var ci := int(floor(a / TerrainBuilder.CHUNK_LEN))
	for i in range(ci - 1, ci + CHUNKS_AHEAD):
		if i >= 0 and not chunks.has(i):
			chunks[i] = _make_chunk(i)
	for k in chunks.keys():
		if k < ci - 1:
			_release_chunk(chunks[k])
			chunks.erase(k)
	# cleanup passed objects (back to pools)
	var cut := a - 25.0
	if not obstacles.is_empty() and obstacles[0].a < cut:
		obstacles = obstacles.filter(func(o):
			if o.a < cut:
				pool.give(o.node)
				return false
			return true)
	if not pickups.is_empty():
		pickups = pickups.filter(func(p):
			if p.a < cut:
				pool.give(p.node)
				return false
			return true)
	feature_nodes = feature_nodes.filter(func(f):
		if f.a1 < cut - 40.0:
			f.node.queue_free()
			return false
		return true)
	track.prune(a - 120.0)
	return shift

# ------------------------------------------------------------------ chunks
func _make_chunk(i: int) -> Dictionary:
	var a0 := float(i * TerrainBuilder.CHUNK_LEN)
	var c: Dictionary
	if _chunk_free.is_empty():
		var node := Node3D.new()
		root.add_child(node)
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		var mmis := {}
		for key in ["pine0", "pine1", "pine2", "rock", "pole"]:
			var mmi := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _decor_mesh(key)
			mmi.multimesh = mm
			if key == "pole":
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mmi)
			mmis[key] = mmi
		c = {"node": node, "mi": mi, "mmis": mmis}
	else:
		c = _chunk_free.pop_back()
		c.node.visible = true
	var built := TerrainBuilder.build(track, a0, snow_mat)
	c.mi.mesh = built.mesh
	c.node.position = built.origin
	var dec := TerrainBuilder.decor(track, a0, built.origin, hash(i * 7919 + seed_v), decor_density)
	for key in c.mmis:
		var mm: MultiMesh = c.mmis[key].multimesh
		var xs: Array = dec[key]
		mm.instance_count = xs.size()
		for k in xs.size():
			mm.set_instance_transform(k, xs[k])
	return c

func _release_chunk(c: Dictionary) -> void:
	c.node.visible = false
	c.mi.mesh = null
	_chunk_free.append(c)

func _decor_mesh(key: String) -> Mesh:
	match key:
		"pine0": return Meshes.pine(0)
		"pine1": return Meshes.pine(1)
		"pine2": return Meshes.pine(2)
		"rock": return Meshes.rock(5)
		"pole": return Meshes.pole(Color(0.95, 0.35, 0.1))
	return null

# ------------------------------------------------------------------ spawning (called by Generator)
func spawn_obstacle(t: String, u: float, a: float, opt: Dictionary) -> void:
	var rng := gen.rng
	var key := t
	var mesh: Mesh
	var r := 0.7
	var ra := 0.7
	var h := 99.0
	var sc := Vector3.ONE
	var yaw := rng.randf() * TAU
	match t:
		"pine":
			var v := rng.randi() % 3
			key = "pine%d" % v
			mesh = Meshes.pine(v)
			var s := rng.randf_range(0.95, 1.3)
			sc = Vector3(s, s * rng.randf_range(0.95, 1.15), s)
			r = 0.65
			ra = 0.65
		"rock":
			var v2 := rng.randi() % 4
			key = "rock%d" % v2
			mesh = Meshes.rock(v2)
			var s2 := rng.randf_range(0.85, 1.05)
			sc = Vector3(1.2, 0.9, 1.1) * s2
			r = 1.0 * s2
			ra = 0.9 * s2
			h = 0.85 * s2
		"boulder":
			var v3 := rng.randi() % 4
			key = "rock%d" % v3
			mesh = Meshes.rock(v3)
			var s3 := rng.randf_range(1.7, 2.3)
			sc = Vector3(1.0, 1.1, 1.0) * s3
			r = 0.95 * s3
			ra = 0.85 * s3
		"snowman":
			mesh = Meshes.snowman()
			yaw = -track.heading(a) + PI + rng.randf_range(-0.4, 0.4)
			r = 0.75
			ra = 0.75
		"log":
			var half: float = opt.get("half", 3.0)
			key = "log%.1f" % (half * 2.0)
			mesh = Meshes.log_mesh(half * 2.0)
			yaw = -track.heading(a) + rng.randf_range(-0.06, 0.06)
			r = half
			ra = 0.55
			h = 0.95
	var n := pool.take(key, mesh)
	n.scale = sc
	n.rotation.y = yaw
	n.position = track.to_render(u, a, track.height(u, a) - 0.1)
	var o := {"type": t, "u": u, "a": a, "r": r, "ra": ra, "h": h, "node": n, "dead": false}
	# keep sorted by a (queries early-out on it)
	var i := obstacles.bsearch_custom(a, func(x, val): return x.a < val)
	obstacles.insert(i, o)

func spawn_pickup(t: String, u: float, a: float, y: float) -> void:
	var mesh: Mesh
	match t:
		"coin": mesh = Meshes.coin()
		"magnet": mesh = Meshes.magnet()
		"boost": mesh = Meshes.crystal(Color(0.2, 0.85, 1.0))
		"x2": mesh = Meshes.crystal(Color(1.0, 0.3, 0.85))
	var n := pool.take("pk_" + t, mesh)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if t != "coin":
		n.scale = Vector3.ONE * 1.3
	n.position = track.to_render(u, a, y)
	n.rotation.y = -track.heading(a)
	pickups.append({"type": t, "u": u, "a": a, "y": y, "node": n, "taken": false})

## Visuals for terrain features (rock bands for cliffs/lips, water for rivers).
func on_feature(f: Dictionary) -> void:
	var node: Node3D
	match f.kind:
		"cliff":
			node = Meshes.cliff_band(track, f.a0, f.a1, f.h)
		"lip":
			if f.rocky:
				node = Meshes.lip_rocks(track, f)
		"river":
			var plane := PlaneMesh.new()
			plane.size = Vector2(200, f.a1 - f.a0 + 4.0)
			plane.subdivide_width = 20
			var mi := MeshInstance3D.new()
			mi.mesh = plane
			mi.material_override = _water_mat
			var am: float = (f.a0 + f.a1) * 0.5
			mi.position = track.to_render(0.0, am, -track.drop_at(am) - 1.0)
			mi.rotation.y = -track.heading(am)
			node = mi
		"crevasse":
			pass
	if node:
		if node.get_parent() == null:
			root.add_child(node)
		feature_nodes.append({"a1": f.a1, "node": node})

# ------------------------------------------------------------------ queries
func hit_test(u: float, a: float, y: float) -> Dictionary:
	for o in obstacles:
		if o.dead:
			continue
		var da: float = abs(o.a - a)
		if da > o.ra + 0.45:
			if o.a > a + 5.0:
				break
			continue
		if abs(o.u - u) > o.r + 0.35:
			continue
		var gy := track.height(o.u, o.a)
		if y - gy > o.h:
			continue
		return o
	return {}

## Nearest obstacle passed within this lateral gap (for near-miss bonus). Returns {} if none.
func near_miss(u: float, a: float, y: float) -> Dictionary:
	for o in obstacles:
		if o.dead or o.get("missed", false) or o.h < 50.0:
			continue
		if o.a > a:
			break
		if a - o.a < 1.2 and abs(o.u - u) < o.r + 1.0 and y - track.height(o.u, o.a) < 3.0:
			o.missed = true
			return o
	return {}

func animate(t: float) -> void:
	for p in pickups:
		if p.taken:
			continue
		var n: Node3D = p.node
		n.rotation.y = t * 3.0 + p.a * 0.2
