extends Node3D
## Main controller: states, scoring, speed, pickups, environment, audio. Wires World, Rider, Input, UI.

enum State { MENU, PLAY, PAUSED, DEAD }

const START_SPEED := 26.0 # D-015 (was 20)
const MAX_SPEED := 50.0 # D-015 (was 36)
const ACCEL := 6.0 # m/s^2 toward the target speed when pointing downhill
const SCRUB := 10.0 # m/s^2 speed bleed when carving across the slope
const BOOST_MULT := 1.35
const REVIVE_COST := 150
const START_A := 8.0

var state := State.MENU
var world: World
var rider: Rider
var cam: CameraRig
var ui: UI
var input: TouchInput
var sun: DirectionalLight3D
var mountains: MeshInstance3D
var snowfall: CPUParticles3D
var env: Environment
var perf: Label

var speed := 0.0
var speed_mod := 1.0 # landing/carve penalties recover toward 1
var tuck_t := 0.0
var run_time := 0.0
var score := 0.0
var trick_score := 0
var run_coins := 0
var tricks_count := 0
var perfects := 0
var revives := 0
var magnet_t := 0.0
var boost_t := 0.0
var x2_t := 0.0
var grace_t := 0.0
var dead_timer := 0.0
var _slope_bonus := 0.0
var _seed := 0
var _debug_seed := 0
var auto_test := false
var autopilot: Autopilot

var sfx := {}
var wind: AudioStreamPlayer
var _sfx_pool: Array = []

func _ready() -> void:
	randomize()
	_setup_environment()
	world = World.new()
	add_child(world)
	rider = Rider.new()
	world.root.add_child(rider)
	cam = CameraRig.new()
	cam.fov = 64
	cam.far = 900
	add_child(cam)
	cam.current = true
	input = TouchInput.new()
	add_child(input)
	input.flick.connect(_on_flick)
	_setup_snowfall()
	_setup_audio()
	ui = UI.new()
	add_child(ui)
	ui.play_pressed.connect(start_run)
	ui.retry_pressed.connect(start_run)
	ui.menu_pressed.connect(go_menu)
	ui.revive_pressed.connect(revive)
	ui.pause_pressed.connect(pause)
	ui.resume_pressed.connect(resume)
	ui.board_changed.connect(func(): rider.set_board(Save.board()))
	ui.settings_changed.connect(apply_settings)
	rider.trick_done.connect(_on_trick)
	rider.landed.connect(_on_landed)
	rider.jumped.connect(func(): _sfx("jump", -6.0))
	perf = Label.new()
	perf.position = Vector2(250, 8)
	perf.add_theme_font_size_override("font_size", 22)
	perf.add_theme_color_override("font_outline_color", Color.BLACK)
	perf.add_theme_constant_override("outline_size", 6)
	ui.add_child(perf)
	apply_settings()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--section="):
			_forced = Array(a.substr(10).split(","))
		if a.begins_with("--seed="):
			_debug_seed = int(a.substr(7))
		if a.begins_with("--ride_anim="):
			rider.ride_anim = a.substr(12)
	go_menu()
	if "--autotest" in args:
		auto_test = true
		autopilot = Autopilot.new()
		start_run()
	elif "--run" in args:
		start_run()
	for a in args:
		if a.begins_with("--shots="):
			DevShots.run(self, a.substr(8), args)

var _forced: Array = []

# ------------------------------------------------------------------ setup
func _setup_environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.50, 0.88)
	sm.sky_horizon_color = Color(0.80, 0.88, 0.97)
	sm.ground_bottom_color = Color(0.50, 0.60, 0.75) # below the horizon = hazy valley, never snow-white
	sm.ground_horizon_color = Color(0.70, 0.79, 0.92)
	sm.sun_angle_max = 20.0
	sm.sky_curve = 0.12
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.66, 0.95)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 160, 0) # low sun from ahead-left: long shadows toward camera
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 34.0
	sun.shadow_bias = 0.06
	sun.shadow_blur = 2.5
	add_child(sun)
	mountains = MeshInstance3D.new()
	mountains.mesh = Meshes.mountains()
	mountains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mountains)

func _setup_snowfall() -> void:
	snowfall = CPUParticles3D.new()
	snowfall.amount = 160
	snowfall.lifetime = 2.6
	snowfall.preprocess = 2.5
	snowfall.local_coords = false
	snowfall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snowfall.emission_box_extents = Vector3(16, 1, 22)
	snowfall.direction = Vector3(0, -1, 0)
	snowfall.spread = 10
	snowfall.initial_velocity_min = 1.5
	snowfall.initial_velocity_max = 3.0
	snowfall.gravity = Vector3(0, -1.0, 0)
	snowfall.scale_amount_min = 0.6
	snowfall.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Meshes.dot_texture()
	m.albedo_color = Color(1, 1, 1, 0.9)
	q.material = m
	snowfall.mesh = q
	cam.add_child(snowfall)
	snowfall.position = Vector3(0, 8, -16)

func _setup_audio() -> void:
	for n in ["coin", "jump", "land", "fall", "break"]:
		sfx[n] = load("res://assets/sounds/%s.ogg" % n)
	for n in ["whoosh", "splash", "powerup"]:
		sfx[n] = load("res://assets/sounds/%s.wav" % n)
	wind = AudioStreamPlayer.new()
	var ws: AudioStreamWAV = load("res://assets/sounds/wind.wav")
	ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ws.loop_end = ws.data.size() / 2
	wind.stream = ws
	wind.volume_db = -30
	add_child(wind)
	wind.play()

func _sfx(n: String, vol := 0.0, pitch := 1.0) -> void:
	if not Save.sound_on or not sfx.has(n):
		return
	var p: AudioStreamPlayer = null
	for q in _sfx_pool:
		if not q.playing:
			p = q
			break
	if p == null:
		if _sfx_pool.size() > 10:
			return
		p = AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	p.stream = sfx[n]
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()

func apply_settings() -> void:
	var hi: bool = Save.settings.quality >= 1
	sun.shadow_enabled = hi
	get_viewport().msaa_3d = Viewport.MSAA_2X if hi else Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = 1.0 if hi else 0.8
	snowfall.amount = 160 if hi else 70
	world.decor_density = 1.0 if hi else 0.6
	perf.visible = Save.settings.fps

# ------------------------------------------------------------------ states
func _new_world() -> void:
	_seed = _debug_seed if _debug_seed != 0 else randi()
	world.forced_sections = _forced
	world.reset(_seed)
	rider.reset(world.track, START_A)
	cam.snap()

func go_menu() -> void:
	state = State.MENU
	input.enabled = false
	_new_world()
	rider.play_anim("Idle")
	rider.position = world.track.to_render(rider.u, rider.a, rider.y)
	rider.yaw_node.rotation.y = -world.track.heading(rider.a)
	speed = 0.0
	ui.show_menu()

func start_run() -> void:
	_new_world()
	speed = START_SPEED
	speed_mod = 1.0
	tuck_t = 0.0
	run_time = 0.0
	score = 0.0
	trick_score = 0
	run_coins = 0
	tricks_count = 0
	perfects = 0
	revives = 0
	magnet_t = 0.0
	boost_t = 0.0
	x2_t = 0.0
	grace_t = 0.0
	state = State.PLAY
	input.enabled = true
	input.reset()
	Save.total_runs += 1
	ui.show_hud(Save.total_runs <= 3)

func pause() -> void:
	if state != State.PLAY:
		return
	state = State.PAUSED
	ui.show_pause()

func resume() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAY
	input.reset()
	ui.show_hud(false)

func _die(reason: String) -> void:
	if state != State.PLAY:
		return
	state = State.DEAD
	input.enabled = false
	rider.crash()
	cam.shake = 0.6
	dead_timer = 0.0
	_sfx("splash" if reason == "water" else "fall")
	var final := int(score + trick_score)
	var new_best := final > Save.best
	if new_best:
		Save.best = final
	Save.coins += run_coins
	Save.save_data()
	if auto_test:
		_autotest_report(reason)
	var msg := {"water": "SPLASH!", "crevasse": "INTO THE ICE!", "bad_landing": "BAD LANDING!", "pine": "TIMBER!", "rock": "ROCKED!",
		"boulder": "BOULDERED!", "log": "TRIPPED!", "snowman": "SNOWMAN'D!"}
	await get_tree().create_timer(1.1).timeout
	if state == State.DEAD:
		ui.show_game_over({"title": msg.get(reason, "WIPEOUT!"), "score": final, "best": Save.best, "new_best": new_best,
			"coins": run_coins, "dist": int(rider.a), "tricks": tricks_count,
			"can_revive": revives == 0 and Save.coins >= REVIVE_COST, "revive_cost": REVIVE_COST})

func revive() -> void:
	if state != State.DEAD or Save.coins < REVIVE_COST:
		return
	Save.coins -= REVIVE_COST
	Save.save_data()
	revives += 1
	var tr := world.track
	var a := rider.a
	# step past any opening we fell into
	var f := tr.feature_at(a, "river")
	if f.is_empty():
		f = tr.feature_at(a, "crevasse")
	if not f.is_empty():
		a = f.a1 + 3.0
	var u := world.gen.safe_u(a)
	for o in world.obstacles:
		if o.a > a - 2.0 and o.a < a + 40.0:
			o.dead = true
			o.node.visible = false
	rider.revive(a, u)
	grace_t = 2.5
	state = State.PLAY
	input.enabled = true
	input.reset()
	cam.snap()
	ui.show_hud(false)

# ------------------------------------------------------------------ input
func _on_flick(dir: String) -> void:
	if state != State.PLAY:
		return
	match dir:
		"up":
			rider.jump()
		"down":
			if rider.grounded:
				tuck_t = 1.5
				ui.popup("TUCK!", Color(0.7, 0.9, 1.0))
			else:
				rider.slam()
		"left": rider.spin(-1)
		"right": rider.spin(1)
	if not rider.grounded and rider.trick != "":
		_sfx("whoosh", -8.0, randf_range(0.9, 1.15))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_P]:
			pause()
		elif state == State.MENU and event.keycode in [KEY_SPACE, KEY_ENTER]:
			start_run()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match state:
			State.PLAY: pause()
			State.PAUSED: resume()
			State.DEAD: go_menu()
			State.MENU:
				if ui.shop.visible or ui.settings_s.visible:
					ui.show_menu()
				else:
					get_tree().quit()

# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	delta = min(delta, 0.05)
	var t := Time.get_ticks_msec() / 1000.0
	match state:
		State.MENU:
			_update_world(0.0)
			cam.menu_orbit(rider, delta, ui.shop.visible)
		State.PLAY:
			_play_step(delta)
			cam.follow(rider, world.track, speed, boost_t > 0.0, false, delta)
		State.DEAD:
			dead_timer += delta
			cam.follow(rider, world.track, speed, false, true, delta)
		State.PAUSED:
			pass
	if state != State.PAUSED:
		world.animate(t)
	_update_fx(delta)
	if perf.visible:
		perf.text = "%d fps  %d dc  %dk tri" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000]

func _update_world(spd: float) -> void:
	var shift := world.update(rider.a, max(spd, START_SPEED))
	if shift != Vector3.ZERO:
		cam.shift(shift)

func _target_speed() -> float:
	# fast from the first second, then a long climb to the cap (~4 min)
	return min(MAX_SPEED, START_SPEED + 8.0 * (1.0 - exp(-run_time / 10.0)) + 0.07 * run_time)

func _play_step(delta: float) -> void:
	run_time += delta
	var tr := world.track
	# speed: base curve + steepness + tuck + boost, minus carve/landing penalties
	var th := rad_to_deg(tr.slope_at(rider.a))
	_slope_bonus = lerp(_slope_bonus, clamp((th - 19.0) * 0.45, -4.0, 4.0), 1.0 - exp(-1.5 * delta))
	if tuck_t > 0.0:
		tuck_t -= delta
	speed_mod = move_toward(speed_mod, 1.0, 0.35 * delta)
	# D-014: carving across the fall line bleeds speed (gravity only pulls along the fall line);
	# pointing straight down lets it climb back. Speed is a state, not a direct curve.
	var across: float = 1.0 - cos(rider.heading)
	var want := (_target_speed() + _slope_bonus + (4.0 if tuck_t > 0.0 else 0.0)) * speed_mod * (1.0 - 0.45 * across)
	if rider.grounded:
		speed = move_toward(speed, want, (ACCEL if speed < want else SCRUB) * delta)
	var eff := speed * (BOOST_MULT if boost_t > 0.0 else 1.0)
	if auto_test:
		autopilot.drive(self, delta)
		if int(run_time / 20.0) != int((run_time - delta) / 20.0):
			print("AUTOTEST t=%.0f a=%.0f speed=%.1f u=%.1f score=%d tricks=%d perfect=%d ghost_fail=%d obs=%d pk=%d pool=%d" % [run_time, rider.a, speed, rider.u,
				int(score + trick_score), tricks_count, perfects, world.gen.ghost_failures, world.obstacles.size(), world.pickups.size(), world.pool.created])
	else:
		rider.steer = input.steer
	rider.steer_step(delta)
	var res := rider.step(delta, eff * cos(rider.heading) * delta, eff)
	_update_world(eff)
	match res:
		"fell":
			_die("crevasse" if not tr.feature_at(rider.a, "crevasse").is_empty() else "water")
			return
		"bad_landing":
			_die("bad_landing")
			return
	var hit := world.hit_test(rider.u, rider.a, rider.y)
	if not hit.is_empty():
		if boost_t > 0.0 or grace_t > 0.0:
			if boost_t > 0.0:
				_smash(hit)
		else:
			_die(hit.type)
			return
	var nm := world.near_miss(rider.u, rider.a, rider.y)
	if not nm.is_empty() and rider.grounded:
		score += 25
		ui.popup("NEAR MISS +25", Color(0.75, 1.0, 0.75))
	_collect()
	magnet_t = max(0.0, magnet_t - delta)
	x2_t = max(0.0, x2_t - delta)
	grace_t = max(0.0, grace_t - delta)
	if boost_t > 0.0:
		boost_t -= delta
		if boost_t <= 0.0:
			grace_t = 1.0
	var mult := 2.0 if x2_t > 0.0 else 1.0
	score += eff * delta * mult
	ui.update_hud(int(score + trick_score), run_coins, int(rider.a), eff,
		{"magnet": [magnet_t, Save.duration("magnet")], "boost": [max(boost_t, 0.0), Save.duration("boost")], "x2": [x2_t, Save.duration("x2")]},
		rider.pending_points)

func _smash(hit: Dictionary) -> void:
	hit.dead = true
	var n: Node3D = hit.node
	_sfx("break", -2.0)
	score += 50
	ui.popup("SMASH! +50", Color(0.5, 0.9, 1.0))
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3(1.4, 0.05, 1.4), 0.15)
	tw.tween_callback(n.hide)

func _collect() -> void:
	var tr := world.track
	var py := rider.y + 0.9
	var magnet := magnet_t > 0.0
	var coin_val: int = Save.board().coin
	var rpos := rider.position + Vector3.UP * 0.9
	for p in world.pickups:
		if p.taken:
			continue
		var da: float = p.a - rider.a
		if da > 30.0:
			break
		if da < -3.0:
			continue
		if magnet and p.type == "coin" and da < 18.0:
			var node: Node3D = p.node
			node.position = node.position.lerp(rpos, 0.25)
			if node.position.distance_to(rpos) < 1.2:
				_take(p, coin_val)
			continue
		if abs(da) < 1.1 and abs(p.u - rider.u) < 1.1 and abs(p.y - py) < 1.5:
			_take(p, coin_val)

func _take(p: Dictionary, coin_val: int) -> void:
	p.taken = true
	p.node.visible = false
	match p.type:
		"coin":
			run_coins += coin_val
			_sfx("coin", -10.0, randf_range(0.95, 1.1))
		"magnet":
			magnet_t = Save.duration("magnet")
			_sfx("powerup")
			ui.popup("MAGNET!", Color(1, 0.35, 0.4))
		"boost":
			boost_t = Save.duration("boost")
			_sfx("powerup")
			ui.popup("AVALANCHE BOOST!", Color(0.4, 0.9, 1.0))
		"x2":
			x2_t = Save.duration("x2")
			_sfx("powerup")
			ui.popup("2X SCORE!", Color(1, 0.45, 0.9))

func _on_trick(nm: String, pts: int, combo: int) -> void:
	tricks_count += 1
	var txt := nm if combo <= 1 else "%s  x%d" % [nm, combo]
	ui.trick(txt, pts)

func _on_landed(grade: String, air: float, pts: int) -> void:
	if air > 0.3:
		_sfx("land", -6.0 if air > 0.8 else -12.0)
	if air > 1.0:
		cam.shake = clamp(air * 0.15, 0.15, 0.45)
	var bonus := int(air * 100) if air > 1.1 else 0
	var mult := 2 if x2_t > 0.0 else 1
	var total := (pts + bonus) * mult
	if total > 0:
		trick_score += total
		ui.popup("+%d" % total, Color(1.0, 0.85, 0.2), true)
	match grade:
		"perfect":
			perfects += 1
			speed_mod = 1.08
			ui.stamp("PERFECT!", Color(0.45, 1.0, 0.55))
		"sketchy":
			speed_mod = 0.85
			ui.stamp("SKETCHY", Color(1.0, 0.6, 0.3))
		"good":
			if pts > 0:
				ui.stamp("CLEAN", Color(0.8, 0.95, 1.0))
	if bonus > 0:
		ui.popup("BIG AIR %.1fs" % air, Color(0.7, 1.0, 0.7))

func _autotest_report(reason: String) -> void:
	print("AUTOTEST died reason=%s dist=%d t=%.0fs speed=%.1f score=%d coins=%d tricks=%d perfect=%d ghost_fail=%d sections=%s" % [
		reason, rider.a, run_time, speed, int(score + trick_score), run_coins, tricks_count, perfects,
		world.gen.ghost_failures, str(world.gen.sections_made.slice(-4))])
	if "--quit_on_death" in OS.get_cmdline_user_args():
		get_tree().quit()

# ------------------------------------------------------------------ visuals
func _update_fx(delta: float) -> void:
	mountains.position = cam.position # backdrop is baked camera-relative (Meshes.VALLEY_Y)
	snowfall.gravity = Vector3(0, -1.0, 0) + cam.global_transform.basis.z * (speed * 0.6 if state == State.PLAY else 1.0)
	rider.trail.emitting = boost_t > 0.0 and state == State.PLAY
	var target_db := -34.0
	if state == State.PLAY:
		target_db = -34.0 + clamp((speed - 15.0) / 20.0, 0.0, 1.0) * 18.0
	if not Save.sound_on:
		target_db = -80.0
	wind.volume_db = lerp(wind.volume_db, target_db, 1.0 - exp(-2.0 * delta))
	wind.pitch_scale = 0.8 + clamp(speed / MAX_SPEED, 0.0, 1.0) * 0.5
