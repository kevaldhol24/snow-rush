class_name Rider
extends Node3D
## The snowboarder. Physics in path space: u (lateral), a (along path, owned by Game), y (absolute height).
## Launches happen naturally: when the ground falls away faster than gravity can follow (lips, crests,
## cliffs) the rider becomes airborne. Tricks: backflip / 360 spins in the air. Landing graded.

signal trick_done(name: String, points: int, combo: int)
signal landed(grade: String, air_time: float, points: int)
signal jumped

const GRAVITY := 27.0
const STICK := 14.0 # extra downforce used only for the take-off test (keeps us glued over small bumps)
const JUMP_V := 9.0
const SLAM_V := -26.0
## Carve steering (D-014): the board has a heading relative to the fall line and you travel along it.
## steer -1..1 sets the TARGET heading; the board arcs toward it at a turn rate limited like a real
## carve (radius ~ v / rate). Let go -> it swings back down the fall line.
const MAX_HEAD := deg_to_rad(55.0)
const TURN_K := 4.0 # how eagerly the board chases the target heading (1/s); 6.5 was twitchy
const TURN_RATE := 1.6 # max yaw rate on the ground (rad/s); 2.4 was twitchy
const AIR_TURN := 0.25 # fraction of turn authority in the air

var u := 0.0
var a := 0.0
var y := 0.0
var vy := 0.0
var vu := 0.0 # lateral speed, derived: speed * sin(heading)
var heading := 0.0 # board/travel direction vs the fall line (rad, + = toward +u)
var yaw_rate := 0.0
var grounded := true
var air_time := 0.0
var crashed := false
var steer := 0.0 # -1..1 from input
var board_def: Dictionary
var jump_mult := 1.0
var handling := 1.0
var track: Track

# tricks
var trick := "" # "", "flip", "spin_l", "spin_r"
var trick_t := 0.0
var trick_dur := 0.5
var combo := 0
var pending_points := 0
var last_trick_end := -10.0
var _clock := 0.0

# visuals
var yaw_node: Node3D
var lean: Node3D
var pivot: Node3D
var model: Node3D
var board_mi: MeshInstance3D
var anim: AnimationPlayer
var spray: CPUParticles3D
var trail: CPUParticles3D
var burst: CPUParticles3D
var _cur_anim := ""
var ride_anim := "Jump_Idle"
var _land_timer := 0.0
var _vis_yaw := 0.0

func _ready() -> void:
	yaw_node = Node3D.new()
	add_child(yaw_node)
	lean = Node3D.new()
	yaw_node.add_child(lean)
	pivot = Node3D.new()
	pivot.position.y = 0.9
	lean.add_child(pivot)
	var inner := Node3D.new()
	inner.position.y = -0.9
	pivot.add_child(inner)
	model = _build_body()
	inner.add_child(model)
	board_mi = MeshInstance3D.new()
	board_mi.position.y = 0.05
	inner.add_child(board_mi)
	_make_particles()
	set_board(Save.board())
	play_anim("Idle")

func _make_particles() -> void:
	spray = CPUParticles3D.new()
	spray.amount = 36
	spray.lifetime = 0.5
	spray.local_coords = false
	spray.direction = Vector3(0, 0.6, 1)
	spray.spread = 30.0
	spray.initial_velocity_min = 2.5
	spray.initial_velocity_max = 5.0
	spray.gravity = Vector3(0, -8, 0)
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 1.1
	var qm := QuadMesh.new()
	qm.size = Vector2(0.3, 0.3)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.albedo_color = Color(0.95, 0.97, 1.0, 0.9)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_texture = Meshes.dot_texture()
	qm.material = pm
	spray.mesh = qm
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	spray.scale_amount_curve = curve
	lean.add_child(spray)
	spray.position = Vector3(0, 0.05, 0.8)
	trail = spray.duplicate()
	trail.amount = 50
	trail.lifetime = 0.4
	trail.position = Vector3(0, 0.6, 0.5)
	trail.direction = Vector3(0, 0, 1)
	trail.spread = 10.0
	trail.gravity = Vector3.ZERO
	var tm: StandardMaterial3D = pm.duplicate()
	tm.albedo_color = Color(0.4, 0.9, 1.0)
	var tq := QuadMesh.new()
	tq.size = Vector2(0.3, 0.3)
	tq.material = tm
	trail.mesh = tq
	trail.emitting = false
	lean.add_child(trail)
	burst = spray.duplicate()
	burst.amount = 40
	burst.lifetime = 0.7
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 80.0
	burst.initial_velocity_min = 3.0
	burst.initial_velocity_max = 7.0
	burst.emitting = false
	add_child(burst)

func set_board(b: Dictionary) -> void:
	board_def = b
	board_mi.mesh = Meshes.board(b)
	jump_mult = b.jump
	handling = b.handling

func play_anim(n: String, speed := 1.0, blend := 0.15) -> void:
	var real: String = ANIM_MAP.get(n, n)
	if anim == null or _cur_anim == n or not anim.has_animation(real):
		return
	_cur_anim = n
	anim.play(real, blend, speed)

# ------------------------------------------------------------------ body (Phase 2 rider, ★ gate)
## Game-side animation names -> Universal Animation Library clips (Quaternius, CC0).
## Clips live in rider_anims.res (extracted by scenes/dev/extract_rider_anims.tscn).
const ANIM_MAP := {
	"Idle": "ual1_Idle",
	"Jump_Idle": "ual1_Idle", # riding stance = Idle + RiderPose crouch (Crouch_Idle is a kneeling sneak)
	"Jump_Start": "ual2_NinjaJump_Start",
	"Air": "ual2_NinjaJump_Idle",
	"Jump_Land": "ual2_NinjaJump_Land",
	"Death_A": "ual1_Death01",
}
const LOOPING := ["ual1_Idle", "ual2_NinjaJump_Idle"]
const BODY_SCALE := 1.05 # 1.82 m model -> ~1.9 m: slightly heroic so the rider reads on a phone
const STANCE_YAW := -PI * 0.5 # regular stance: body sideways on the board, left foot forward
static var _libs := {}

var pose: RiderPose

func _build_body() -> Node3D:
	var body: Node3D = preload("res://assets/models/rider_q/Superhero_Male_FullBody.gltf").instantiate()
	body.rotation.y = PI + STANCE_YAW
	body.scale = Vector3.ONE * BODY_SCALE
	body.position.y = 0.07 # board thickness + bindings
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	# winter outfit painted onto the base body's texture (tools/paint_outfit.py), plus rim light so the
	# rider always reads against bright snow (ART_DIRECTION §3)
	for mi in sk.find_children("*", "MeshInstance3D", false, false):
		for si in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(si)
			if m is StandardMaterial3D:
				var d: StandardMaterial3D = m.duplicate()
				if mi.name == "SuperHero_Male":
					d.albedo_texture = preload("res://assets/models/rider_q/T_Rider_Outfit.png")
				d.rim_enabled = true
				d.rim = 0.35
				d.rim_tint = 0.4
				mi.set_surface_override_material(si, d)
	# animations: both libraries share this exact skeleton (65 bones, same names and node path)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	body.add_child(ap)
	ap.add_animation_library("", _library())
	anim = ap
	# snowboard stance overrides (after animation)
	pose = RiderPose.new()
	sk.add_child(pose)
	_add_gear(sk)
	return body

static func _library() -> AnimationLibrary:
	if _libs.has("main"):
		return _libs["main"]
	var lib: AnimationLibrary = preload("res://assets/models/rider_q/rider_anims.res")
	for nm in LOOPING:
		if lib.has_animation(nm):
			lib.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
	_libs["main"] = lib
	return lib

## Beanie + goggles on the head bone. Positions are in skeleton space at rest (face = +Z, eyes y 1.70).
func _add_gear(sk: Skeleton3D) -> void:
	var head := sk.find_bone("Head")
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	sk.add_child(att)
	var to_head := sk.get_bone_global_rest(head).affine_inverse()
	var beanie_c := Color(0.95, 0.80, 0.18)
	var parts := [
		# [mesh, skeleton-space position, scale, colour]
		[_hemi(0.104), Vector3(0, 1.722, -0.018), Vector3(1.07, 1.12, 1.12), beanie_c],
		[_cyl(0.110, 0.042), Vector3(0, 1.738, -0.016), Vector3(1.0, 1.0, 1.06), beanie_c.darkened(0.15)],
		[_ball(0.034), Vector3(0, 1.855, -0.03), Vector3.ONE, Color(0.97, 0.97, 1.0)],
		[_cyl(0.108, 0.034), Vector3(0, 1.70, -0.014), Vector3(1.0, 1.0, 1.05), Color(0.12, 0.12, 0.15)],
		[_box(Vector3(0.150, 0.056, 0.03)), Vector3(0, 1.702, 0.083), Vector3.ONE, Color(0.25, 0.75, 0.95)],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		var m := StandardMaterial3D.new()
		m.albedo_color = p[3]
		m.roughness = 0.6
		if p[3] == Color(0.25, 0.75, 0.95): # goggle lens: glossy, slight glow so it reads from behind
			m.metallic = 0.6
			m.roughness = 0.15
			m.emission_enabled = true
			m.emission = p[3]
			m.emission_energy_multiplier = 0.35
		mi.material_override = m
		mi.transform = to_head * Transform3D(Basis.from_scale(p[2]), p[1])
		att.add_child(mi)

static func _hemi(r: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r
	m.is_hemisphere = true
	return m

static func _cyl(r: float, h: float) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	return m

static func _ball(r: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m

static func _box(sz: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = sz
	return m

func reset(t: Track, start_a: float) -> void:
	track = t
	u = 0.0
	a = start_a
	y = track.height(u, a)
	vy = 0.0
	vu = 0.0
	heading = 0.0
	yaw_rate = 0.0
	steer = 0.0
	grounded = true
	crashed = false
	trick = ""
	combo = 0
	pending_points = 0
	pivot.rotation = Vector3.ZERO
	lean.rotation = Vector3.ZERO
	_cur_anim = ""
	play_anim(ride_anim)
	spray.emitting = true

# --------------------------------------------------------------- actions
func jump() -> void:
	if crashed:
		return
	if grounded:
		vy = vy + JUMP_V * jump_mult
		grounded = false
		air_time = 0.0
		combo = 0
		jumped.emit()
		play_anim("Jump_Start", 1.6)
	elif trick == "" and time_to_land() > 0.34:
		# >= 0.34 s: lands at worst "sketchy" (crash needs > 35% of the 0.52 s flip left).
		# Shorter hops ignore the flick: a flip there was a guaranteed crash.
		start_trick("flip")

func spin(dir: int) -> void:
	if crashed or grounded or trick != "":
		return
	if time_to_land() > 0.36:
		start_trick("spin_l" if dir < 0 else "spin_r")

func slam() -> void:
	if crashed or grounded:
		return
	vy = min(vy, SLAM_V)

func start_trick(t: String) -> void:
	trick = t
	trick_t = 0.0
	trick_dur = 0.52 if t == "flip" else 0.46
	combo += 1

## Seconds until touching ground on the current ballistic path (approx, steps along the track).
func time_to_land(speed: float = 25.0) -> float:
	if grounded:
		return 0.0
	var t := 0.0
	var yy := y
	var v := vy
	while t < 3.0:
		t += 0.04
		v -= GRAVITY * 0.04
		yy += v * 0.04
		var g := track.ground(u + vu * t, a + speed * cos(heading) * t)
		if g > Track.OPEN * 0.5 and yy <= g:
			return t
	return 3.0

# --------------------------------------------------------------- physics (shared with generator ghost)
## Vertical step for a state dict {u, a, y, vy, grounded, air}. u/a must already be advanced.
## Returns "", "takeoff", "land" or "fell".
static func surface_step(st: Dictionary, tr: Track, dt: float) -> String:
	var gnd := tr.ground(st.u, st.a)
	var open := gnd < Track.OPEN * 0.5
	if st.grounded:
		var y_ball: float = st.y + st.vy * dt - 0.5 * (GRAVITY + STICK) * dt * dt
		if open or y_ball > gnd + 0.03:
			st.grounded = false
			st.air = 0.0
			st.vy -= GRAVITY * dt
			st.y += st.vy * dt
			return "takeoff"
		st.vy = (gnd - st.y) / dt
		st.y = gnd
		# don't carry huge vertical speeds from table steps
		st.vy = clamp(st.vy, -60.0, 30.0)
		return ""
	st.air += dt
	st.vy -= GRAVITY * dt
	st.y += st.vy * dt
	if not open and st.y <= gnd:
		st.y = gnd
		st.grounded = true
		return "land"
	if open and st.y < tr.opening_floor(st.u, st.a) - 1.5:
		return "fell"
	return ""

## Turns the board; call before step(). Game uses `heading` to split speed into da / du.
func steer_step(delta: float) -> void:
	var target := steer * MAX_HEAD
	var rate := TURN_RATE * handling * (1.0 if grounded else AIR_TURN)
	var w: float = clamp((target - heading) * TURN_K, -rate, rate)
	# at the side of the run the bank pushes the board back toward the middle
	if abs(u) > Track.EDGE - 0.6 and sign(heading) == sign(u):
		w = min(w, -heading * 6.0) if heading > 0.0 else max(w, -heading * 6.0)
	heading = clamp(heading + w * delta, -MAX_HEAD, MAX_HEAD)
	yaw_rate = w

## Full step. da = distance moved down the fall line this frame, speed = speed along the board.
## Returns "", "landed", "bad_landing", "fell".
func step(delta: float, da: float, speed: float) -> String:
	_clock += delta
	vu = speed * sin(heading)
	u += vu * delta
	if abs(u) > Track.EDGE:
		u = sign(u) * Track.EDGE
	a += da
	var st := {"u": u, "a": a, "y": y, "vy": vy, "grounded": grounded, "air": air_time}
	var res := surface_step(st, track, delta)
	y = st.y
	vy = st.vy
	grounded = st.grounded
	air_time = st.air
	var out := ""
	match res:
		"takeoff":
			combo = 0
			if _cur_anim != "Jump_Start":
				play_anim(ride_anim)
		"land":
			out = _land()
		"fell":
			out = "fell"
	_update_trick(delta)
	_update_visual(delta, speed)
	return out

func _update_trick(delta: float) -> void:
	if trick == "":
		return
	trick_t += delta
	var k: float = clamp(trick_t / trick_dur, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	match trick:
		"flip": pivot.rotation = Vector3(-TAU * e, 0, 0)
		"spin_l": pivot.rotation = Vector3(0, TAU * e, 0)
		"spin_r": pivot.rotation = Vector3(0, -TAU * e, 0)
	if k >= 1.0:
		_complete_trick()

func _complete_trick() -> void:
	var base := 400 if trick == "flip" else 250
	var nm := "BACKFLIP" if trick == "flip" else "360"
	var pts := int(base * combo * board_def.trick)
	pending_points += pts
	trick_done.emit(nm, pts, combo)
	pivot.rotation = Vector3.ZERO
	trick = ""
	last_trick_end = _clock

## Landing grade: Crash (>35% of a trick left), Sketchy (some left), Perfect (trick finished just
## before touchdown), Good (otherwise).
func _land() -> String:
	var grade := "good"
	if trick != "":
		var left := 1.0 - trick_t / trick_dur
		if left > 0.35:
			return "bad_landing"
		grade = "sketchy"
		_complete_trick()
	elif pending_points > 0 and _clock - last_trick_end < 0.45:
		grade = "perfect"
	var pts := pending_points
	if grade == "perfect":
		pts = int(pts * 1.5)
	elif grade == "sketchy":
		pts = int(pts * 0.5)
	landed.emit(grade, air_time, pts)
	pending_points = 0
	combo = 0
	if air_time > 0.35:
		_land_timer = 0.25
		play_anim("Jump_Land", 1.4, 0.05)
		burst.restart()
		burst.emitting = true
	return "landed"

func _update_visual(delta: float, speed: float) -> void:
	position = track.to_render(u, a, y)
	# face along the path + carve direction
	# board/body point where we travel
	_vis_yaw = lerp_angle(_vis_yaw, -track.heading(a) - heading, 1.0 - exp(-12.0 * delta))
	yaw_node.rotation.y = _vis_yaw
	# lean comes from the turn itself (centripetal accel v*w), not from sideways speed;
	# damped so it reads as a carve, not a motorbike lean (Keval, 2026-11-12)
	var target_roll: float = clamp(-atan(speed * yaw_rate / 9.8) * 0.45, -0.32, 0.32) if grounded else 0.0
	var target_pitch := 0.0
	if grounded:
		var g0 := track.height(u, a - 0.8)
		var g1 := track.height(u, a + 0.8)
		target_pitch = atan((g1 - g0) / 1.6)
	else:
		target_pitch = clamp(atan2(vy, max(speed, 1.0)) * 0.8, -0.6, 0.5)
	lean.rotation.z = lerp(lean.rotation.z, target_roll, 1.0 - exp(-10.0 * delta))
	lean.rotation.x = lerp(lean.rotation.x, target_pitch, 1.0 - exp(-12.0 * delta))
	spray.emitting = grounded and not crashed
	spray.amount = 36
	# spray scales with how hard we carve (centripetal accel), thrown to the outside of the turn
	var carve_k: float = clamp(abs(speed * yaw_rate) / 25.0, 0.0, 1.0)
	spray.initial_velocity_max = 5.0 + carve_k * 9.0
	spray.direction = Vector3(-sign(yaw_rate) * carve_k, 0.6, 1)
	if _land_timer > 0.0:
		_land_timer -= delta
		if _land_timer <= 0.0:
			play_anim(ride_anim)
	elif grounded and _cur_anim == "Jump_Start":
		play_anim(ride_anim)
	if not grounded and _cur_anim == "Jump_Land":
		play_anim(ride_anim)

func crash() -> void:
	crashed = true
	trick = ""
	pivot.rotation = Vector3.ZERO
	spray.emitting = false
	trail.emitting = false
	_cur_anim = ""
	play_anim("Death_A", 1.2, 0.05)
	burst.restart()
	burst.emitting = true

func revive(new_a: float, new_u: float) -> void:
	crashed = false
	a = new_a
	u = new_u
	y = track.height(u, a)
	vy = 0.0
	vu = 0.0
	grounded = true
	pivot.rotation = Vector3.ZERO
	_cur_anim = ""
	play_anim(ride_anim)
