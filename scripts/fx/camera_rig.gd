class_name CameraRig
extends Camera3D
## Chase camera that looks DOWN the fall line. Smoothed in render space; shift() on world rebase.

var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _init_done := false
var shake := 0.0
var menu_t := 0.0

func shift(v: Vector3) -> void:
	_pos += v
	_look += v

func snap() -> void:
	_init_done = false

func follow(r: Rider, tr: Track, speed: float, boost: bool, dead: bool, delta: float) -> void:
	# desired camera: behind (uphill) and above the rider, looking at a point down the slope
	# framing: rider at ~70% screen height, horizon high (~20%) -> you look DOWN the fall line
	var back := 7.6
	if dead:
		back = 10.5
	# swing partly behind the board's heading (D-014): you see where you're carving, but the
	# fall line stays readable. Full lateral follow (at 0.75 the rider slid toward the edge).
	var sw: float = r.heading * 0.4
	var cam_u: float = r.u - back * sin(sw)
	var cam_a: float = r.a - back * cos(sw)
	var behind_ground := tr.height(cam_u, cam_a)
	var rider_y := r.y
	var cy: float = max(behind_ground, rider_y) + 3.7
	if dead:
		cy += 2.5
	var want_pos := tr.to_render(cam_u, cam_a, cy)
	# look point: well ahead, a fixed amount below the rider -> stable pitch, rider sits low on screen
	var want_look := tr.to_render(r.u + 18.0 * sin(sw), r.a + 18.0 * cos(sw), rider_y - 5.2)
	if not _init_done:
		_pos = want_pos
		_look = want_look
		_init_done = true
	var kp := 1.0 - exp(-(4.0 if dead else 9.0) * delta)
	var kl := 1.0 - exp(-10.0 * delta)
	# vertical follows a bit slower (cliff drops feel dramatic)
	_pos = Vector3(lerp(_pos.x, want_pos.x, kp), lerp(_pos.y, want_pos.y, kp * 0.7), lerp(_pos.z, want_pos.z, kp))
	_look = _look.lerp(want_look, kl)
	var off := Vector3.ZERO
	if shake > 0.0:
		shake = max(0.0, shake - delta)
		off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.3
	position = _pos + off
	look_at(_look, Vector3.UP)
	# lean into carves
	rotate_object_local(Vector3.FORWARD, clamp(-r.yaw_rate * 0.035, -0.06, 0.06))
	var target_fov: float = 64.0 + clamp((speed - 26.0) / 24.0, 0.0, 1.0) * 12.0 + (8.0 if boost else 0.0)
	fov = lerp(fov, target_fov, 1.0 - exp(-3.0 * delta))

func menu_orbit(r: Rider, delta: float, shop_open: bool) -> void:
	menu_t += delta
	var ang := sin(menu_t * 0.3) * 0.3 + 0.35
	var dist := 4.2 if shop_open else 6.0
	var h := 2.4 if shop_open else 2.0
	var center := r.position
	var fwd := -r.yaw_node.global_transform.basis.z
	var side := r.yaw_node.global_transform.basis.x
	var want := center + (fwd * cos(ang) + side * sin(ang)) * dist + Vector3.UP * h
	_pos = want if not _init_done else _pos.lerp(want, 1.0 - exp(-4.0 * delta))
	_init_done = true
	position = _pos
	look_at(center + Vector3.UP * (-0.2 if shop_open else 0.55), Vector3.UP)
	fov = lerp(fov, 55.0, 1.0 - exp(-3.0 * delta))
