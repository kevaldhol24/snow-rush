class_name CarveTrail
extends MeshInstance3D
## Board carve marks on the snow (Phase 2). Each sample's two edge vertices are computed ONCE, in this
## node's local space. The node lives under World.root, which World shifts on floating-origin rebases,
## so cached vertices stay valid and a rebuild is just a copy. One ribbon, shaded by
## shaders/carve_trail.gdshader (two edge grooves). Breaks in the air and over openings.
## No allocations in play: fixed-size ring of point dictionaries is reused.

const SPACING := 0.6 # m between samples
const LENGTH := 70.0 # m of trail kept (fades out over it)
const MAX_PTS := 128

var track: Track
var _pts: Array = [] # {a, l(Vector3), r(Vector3), k(strength), brk(bool)}
var _head := 0 # ring write index
var _count := 0
var _last_a := -1.0e9
var _was_grounded := false
var _im: ImmediateMesh

func _ready() -> void:
	_im = ImmediateMesh.new()
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/carve_trail.gdshader")
	material_override = m
	for i in MAX_PTS:
		_pts.append({"a": 0.0, "l": Vector3.ZERO, "r": Vector3.ZERO, "k": 0.0, "brk": true})

func reset(t: Track) -> void:
	track = t
	_count = 0
	_head = 0
	_last_a = -1.0e9
	_was_grounded = false
	_im.clear_surfaces()

## Call once per frame after the rider moved.
func feed(r: Rider, speed: float) -> void:
	if track == null:
		return
	var on_snow := r.grounded and not r.crashed and track.ground(r.u, r.a) > Track.OPEN * 0.5
	if on_snow and (r.a - _last_a >= SPACING or not _was_grounded):
		var carve_k: float = clamp(abs(speed * r.yaw_rate) / 25.0, 0.0, 1.0)
		var p: Dictionary = _pts[_head]
		var w := 0.17 + 0.10 * carve_k
		var cu: float = cos(r.heading) * w
		var ca: float = -sin(r.heading) * w
		p.a = r.a
		p.l = track.to_render(r.u - cu, r.a - ca, track.height(r.u - cu, r.a - ca) + 0.025) - position
		p.r = track.to_render(r.u + cu, r.a + ca, track.height(r.u + cu, r.a + ca) + 0.025) - position
		p.k = 0.45 + 0.45 * carve_k
		p.brk = not _was_grounded # first point after air starts a new strip
		_head = (_head + 1) % MAX_PTS
		_count = min(_count + 1, MAX_PTS)
		_last_a = r.a
	_was_grounded = on_snow
	_rebuild(r.a)

func _rebuild(rider_a: float) -> void:
	_im.clear_surfaces()
	if _count < 2:
		return
	# split live points into strips (a break starts a new one); emit only strips with >= 2 samples
	var start := (_head - _count + MAX_PTS) % MAX_PTS
	var strip_from := -1
	var strip_len := 0
	for n in _count + 1:
		var idx := (start + n) % MAX_PTS
		var live := false
		var brk := true
		if n < _count:
			var p: Dictionary = _pts[idx]
			var age: float = rider_a - p.a
			live = age <= LENGTH and age >= -1.0
			brk = p.brk
		if not live or brk:
			if strip_len >= 2:
				_emit(strip_from, strip_len, rider_a)
			strip_len = 0
			strip_from = -1
		if live:
			if strip_from < 0:
				strip_from = idx
			strip_len += 1

func _emit(from: int, n: int, rider_a: float) -> void:
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in n:
		var p: Dictionary = _pts[(from + k) % MAX_PTS]
		var fade: float = 1.0 - clamp((rider_a - p.a) / LENGTH, 0.0, 1.0)
		var c := Color(1, 1, 1, p.k * fade * fade)
		_im.surface_set_color(c)
		_im.surface_set_uv(Vector2(0, 0))
		_im.surface_add_vertex(p.l)
		_im.surface_set_color(c)
		_im.surface_set_uv(Vector2(1, 0))
		_im.surface_add_vertex(p.r)
	_im.surface_end()
