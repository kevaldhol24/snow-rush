class_name Player
extends Node3D
## Rider on a board. Handles lanes, jumping/ramps, tricks and animation. Position x/y only;
## forward motion is the world scrolling.

signal trick_done(name: String, points: int, combo: int)
signal landed(air_time: float)
signal jumped

const GRAVITY := 27.0
const JUMP_V := 9.6
const SLAM_V := -24.0
const LANE_SPEED := 15.0

var lane := 1
var x := 0.0
var y := 0.0
var vy := 0.0
var grounded := true
var air_time := 0.0
var crashed := false
var board_def: Dictionary
var jump_mult := 1.0
var handling := 1.0

# tricks
var trick := "" # "", "flip", "spin_l", "spin_r"
var trick_t := 0.0
var trick_dur := 0.5
var combo := 0
var pending_points := 0
var trick_names: Array = []

var pivot: Node3D # rotates for tricks (pivot at body centre)
var lean: Node3D # lean / slope pitch
var model: Node3D
var board_mi: MeshInstance3D
var anim: AnimationPlayer
var spray: CPUParticles3D
var trail: CPUParticles3D
var shadow_blob: MeshInstance3D
var _cur_anim := ""
var ride_anim := "Jump_Idle"
var _land_timer := 0.0
var _visual_x_prev := 0.0

func _ready() -> void:
	lean = Node3D.new()
	add_child(lean)
	pivot = Node3D.new()
	pivot.position.y = 0.9
	lean.add_child(pivot)
	var inner := Node3D.new()
	inner.position.y = -0.9
	pivot.add_child(inner)
	model = preload("res://assets/models/rider.glb").instantiate()
	model.rotation.y = PI
	model.scale = Vector3.ONE * 0.78
	model.position.y = 0.12
	inner.add_child(model)
	for nm in ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]:
		var n := model.find_child(nm, true, false)
		if n:
			n.visible = false
	anim = model.find_child("AnimationPlayer", true, false)
	board_mi = MeshInstance3D.new()
	board_mi.position.y = 0.05
	inner.add_child(board_mi)
	_make_particles()
	set_board(Save.board())
	play_anim("Idle")

func _make_shadow() -> void:
	shadow_blob = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 2.0)
	q.orientation = PlaneMesh.FACE_Y
	shadow_blob.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var g := Gradient.new()
	g.set_color(0, Color(0.1, 0.15, 0.3, 0.45))
	g.set_color(1, Color(0.1, 0.15, 0.3, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	m.albedo_texture = gt
	shadow_blob.material_override = m
	add_child(shadow_blob)

func _make_particles() -> void:
	spray = CPUParticles3D.new()
	spray.amount = 28
	spray.lifetime = 0.45
	spray.local_coords = false
	spray.position = Vector3(0, 0.05, 0.85)
	spray.direction = Vector3(0, 0.5, 1)
	spray.spread = 35.0
	spray.initial_velocity_min = 3.0
	spray.initial_velocity_max = 6.0
	spray.gravity = Vector3(0, -9, 0)
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 1.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.28, 0.28)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.albedo_color = Color(0.95, 0.97, 1.0, 0.95)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_texture = Meshes.dot_texture()
	qm.material = pm
	spray.mesh = qm
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	spray.scale_amount_curve = curve
	add_child(spray)
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
	tq.material = tm
	trail.mesh = tq
	trail.emitting = false
	add_child(trail)

func set_board(b: Dictionary) -> void:
	board_def = b
	board_mi.mesh = Meshes.board(b)
	jump_mult = b.jump
	handling = b.handling

func play_anim(n: String, speed := 1.0, blend := 0.15) -> void:
	if anim == null or _cur_anim == n:
		return
	if not anim.has_animation(n):
		return
	_cur_anim = n
	anim.play(n, blend, speed)

func reset() -> void:
	lane = 1
	x = 0.0
	y = 0.0
	vy = 0.0
	grounded = true
	crashed = false
	trick = ""
	combo = 0
	pending_points = 0
	pivot.rotation = Vector3.ZERO
	lean.rotation = Vector3.ZERO
	position = Vector3.ZERO
	_cur_anim = ""
	play_anim(ride_anim)
	spray.emitting = true

# --------------------------------------------------------------- input actions
func move(dir: int) -> void:
	if crashed:
		return
	var nl: int = clamp(lane + dir, 0, 2)
	if not grounded and trick == "" and time_to_land() > 0.46 * 0.8:
		start_trick("spin_l" if dir < 0 else "spin_r")
	lane = nl

func jump() -> void:
	if crashed:
		return
	if grounded:
		vy = JUMP_V * jump_mult + max(vy, 0.0) * 0.5
		grounded = false
		air_time = 0.0
		combo = 0
		jumped.emit()
		play_anim("Jump_Start", 1.6)
	elif trick == "":
		start_trick("flip")

## Rough time until touching y=0 again (ignores ramps).
func time_to_land() -> float:
	var disc: float = vy * vy + 2.0 * GRAVITY * max(y, 0.0)
	return (vy + sqrt(disc)) / GRAVITY

func slam() -> void:
	if crashed or grounded:
		return
	vy = min(vy, SLAM_V)

func start_trick(t: String) -> void:
	trick = t
	trick_t = 0.0
	trick_dur = 0.52 if t == "flip" else 0.46
	combo += 1

# --------------------------------------------------------------- simulation
## Advances physics. ground = surface height under player; ramp_slope = dy/da of ramp under player.
func step(delta: float, speed: float, ground: float, ramp_slope: float) -> String:
	# lane movement
	var tx: float = Level.LANES[lane]
	var px := x
	x = move_toward(x, tx, LANE_SPEED * handling * delta * (1.0 + abs(tx - x) * 0.6))
	var vx: float = (x - px) / max(delta, 0.0001)
	var result := ""
	if grounded:
		if ground < -50.0:
			grounded = false # rode into the river
			vy = 0.0
		elif ramp_slope > 0.0:
			y = ground
			vy = ramp_slope * speed
		else:
			if y > ground + 0.05:
				grounded = false # left the top of a ramp
			else:
				y = ground
				vy = 0.0
	if not grounded:
		air_time += delta
		vy -= GRAVITY * delta
		y += vy * delta
		if ground > -50.0 and y <= ground and vy <= 0.0:
			y = ground
			result = _land()
		elif ground < -50.0 and y < -0.6:
			result = "river"
	# tricks
	if trick != "":
		trick_t += delta
		var k: float = clamp(trick_t / trick_dur, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		match trick:
			"flip": pivot.rotation = Vector3(-TAU * e, 0, 0)
			"spin_l": pivot.rotation = Vector3(0, TAU * e, 0)
			"spin_r": pivot.rotation = Vector3(0, -TAU * e, 0)
		if k >= 1.0:
			_complete_trick()
	_update_visual(delta, vx, ramp_slope)
	return result

func _complete_trick() -> void:
	var base := 400 if trick == "flip" else 250
	var nm := "BACKFLIP" if trick == "flip" else "360 SPIN"
	var pts := int(base * combo * board_def.trick)
	pending_points += pts
	trick_done.emit(nm, pts, combo)
	pivot.rotation = Vector3.ZERO
	trick = ""
	if not grounded:
		play_anim(ride_anim)

func _land() -> String:
	grounded = true
	vy = 0.0
	if trick != "":
		var k := trick_t / trick_dur
		if k < 0.65:
			return "bad_landing"
		_complete_trick()
	landed.emit(air_time)
	combo = 0
	_land_timer = 0.25
	play_anim("Jump_Land", 1.4, 0.05)
	return "landed"

func _update_visual(delta: float, vx: float, ramp_slope: float) -> void:
	position = Vector3(x, y, 0)
	var target_roll: float = clamp(-vx * 0.035, -0.45, 0.45)
	var target_pitch := 0.0
	if grounded and ramp_slope > 0.0:
		target_pitch = atan(ramp_slope)
	elif not grounded:
		target_pitch = clamp(vy * 0.025, -0.35, 0.35)
	lean.rotation.z = lerp(lean.rotation.z, target_roll, 1.0 - exp(-12.0 * delta))
	lean.rotation.x = lerp(lean.rotation.x, target_pitch, 1.0 - exp(-14.0 * delta))
	spray.emitting = grounded and not crashed
	if _land_timer > 0.0:
		_land_timer -= delta
		if _land_timer <= 0.0:
			play_anim(ride_anim)
	elif grounded and _cur_anim == "Jump_Start":
		play_anim(ride_anim)
	if not grounded and _cur_anim == "Jump_Land":
		play_anim(ride_anim)

var _shadow_ground := 0.0
func set_shadow_ground(g: float) -> void:
	_shadow_ground = g if g > -50.0 else Terrain.WATER_Y

func crash() -> void:
	crashed = true
	trick = ""
	spray.emitting = false
	trail.emitting = false
	_cur_anim = ""
	play_anim("Death_A", 1.2, 0.05)

func revive() -> void:
	crashed = false
	y = max(y, 0.0)
	vy = 0.0
	grounded = true
	pivot.rotation = Vector3.ZERO
	_cur_anim = ""
	play_anim(ride_anim)
