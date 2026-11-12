extends Node3D
## Main controller: game states, input, scoring, camera, environment, audio.

enum State { MENU, PLAY, PAUSED, DEAD }

const START_SPEED := 13.0
const MAX_SPEED := 30.0
const ACCEL := 0.12 # m/s per second
const BOOST_MULT := 1.45
const REVIVE_COST := 150

var state := State.MENU
var level: Level
var player: Player
var cam: Camera3D
var ui: UI
var sun: DirectionalLight3D
var mountains: MeshInstance3D
var snowfall: CPUParticles3D

var dist := 0.0
var speed := 0.0
var run_time := 0.0
var score := 0.0
var trick_score := 0
var run_coins := 0
var tricks_count := 0
var best_combo := 0
var revives := 0
var magnet_t := 0.0
var boost_t := 0.0
var x2_t := 0.0
var grace_t := 0.0
var shake := 0.0
var menu_t := 0.0
var _cam_x := 0.0
var _cam_y := 0.0
var _touch_start := Vector2.ZERO
var _touch_used := false
var _touching := false
var dead_timer := 0.0
var auto_test := false
var _debug_seed := 0 # set by --autotest for headless smoke runs

var sfx := {}
var wind: AudioStreamPlayer

func _ready() -> void:
	randomize()
	_setup_environment()
	level = Level.new()
	add_child(level)
	player = Player.new()
	add_child(player)
	cam = Camera3D.new()
	cam.fov = 62
	cam.far = 800
	add_child(cam)
	cam.current = true
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
	ui.board_changed.connect(func(): player.set_board(Save.board()))
	player.trick_done.connect(_on_trick)
	player.landed.connect(_on_landed)
	player.jumped.connect(func(): _sfx("jump", -6.0))
	level.reset(randi())
	go_menu()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--force="):
			level.debug_force = Array(a.substr(8).split(","))
		if a.begins_with("--ride_anim="):
			player.ride_anim = a.substr(12)
		if a.begins_with("--seed="):
			_debug_seed = int(a.substr(7))
	if "--autotest" in args:
		auto_test = true
		start_run()
	elif "--run" in args:
		start_run()
	# --shots=dir --shot_times=1,3,5 : capture screenshots then quit (dev tooling)
	for a in args:
		if a.begins_with("--shots="):
			_run_shots(a.substr(8), args)

func _run_shots(dir: String, args: PackedStringArray) -> void:
	var times := [2.0, 6.0, 12.0]
	for a in args:
		if a.begins_with("--shot_times="):
			times = Array(a.substr(13).split(",")).map(func(s): return float(s))
		if a.begins_with("--shop"):
			ui.show_shop()
	var elapsed := 0.0
	for i in times.size():
		await get_tree().create_timer(times[i] - elapsed).timeout
		elapsed = times[i]
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%02d.png" % [dir, i])
		print("SHOT %d state=%d dist=%.0f speed=%.1f score=%d fps=%d" % [i, state, dist, speed, int(score + trick_score), Engine.get_frames_per_second()])
	get_tree().quit()

# ------------------------------------------------------------------ setup
func _setup_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.52, 0.9)
	sm.sky_horizon_color = Color(0.80, 0.88, 0.97)
	sm.ground_bottom_color = Color(0.80, 0.88, 0.97)
	sm.ground_horizon_color = Color(0.80, 0.88, 0.97)
	sm.sun_angle_max = 20.0
	sm.sky_curve = 0.12
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.72, 0.92)
	env.ambient_light_energy = 0.6
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
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 32.0
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
	snowfall.position = Vector3(0, 10, -18)
	add_child(snowfall)

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

var _sfx_pool: Array = []
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

# ------------------------------------------------------------------ states
func go_menu() -> void:
	state = State.MENU
	get_tree().paused = false
	player.reset()
	player.play_anim("Idle")
	player.set_board(Save.board())
	level.reset(randi())
	dist = 0.0
	ui.show_menu()

func start_run() -> void:
	get_tree().paused = false
	level.reset(_debug_seed if _debug_seed != 0 else randi())
	player.reset()
	player.set_board(Save.board())
	dist = 0.0
	speed = START_SPEED
	run_time = 0.0
	score = 0.0
	trick_score = 0
	run_coins = 0
	tricks_count = 0
	best_combo = 0
	revives = 0
	magnet_t = 0.0
	boost_t = 0.0
	x2_t = 0.0
	grace_t = 0.0
	state = State.PLAY
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
	ui.show_hud(false)

func _die(reason: String) -> void:
	if state != State.PLAY:
		return
	state = State.DEAD
	player.crash()
	if reason in ["tree", "snowman", "rock", "log", "ramp_side"]:
		dist -= 1.4 # knocked back off the obstacle
		speed = 0.0
	shake = 0.6
	dead_timer = 0.0
	if reason == "river":
		_sfx("splash")
	else:
		_sfx("fall")
	player.pending_points = 0
	var final := int(score)
	var new_best := final > Save.best
	if new_best:
		Save.best = final
	Save.coins += run_coins
	Save.save_data()
	var msg := {"river": "SPLASH!", "bad_landing": "BAD LANDING!", "tree": "TIMBER!", "rock": "ROCKED!", "log": "TRIPPED!", "snowman": "SNOWMAN'D!", "ramp_side": "OUCH!"}
	await get_tree().create_timer(1.1).timeout
	if state == State.DEAD:
		ui.show_game_over({"title": msg.get(reason, "WIPEOUT!"), "score": final, "best": Save.best, "new_best": new_best,
			"coins": run_coins, "dist": int(dist), "tricks": tricks_count, "can_revive": revives == 0 and Save.coins >= REVIVE_COST, "revive_cost": REVIVE_COST})
	if auto_test:
		for o in level.obstacles:
			if abs(o.a0 - dist) < 25 and not o.get("dead", false):
				print("  obs %s a0=%.1f x=%.1f h=%.1f" % [o.type, o.a0 - dist, o.x, o.h])
		print("  player x=%.2f lane=%d y=%.2f grounded=%s" % [player.x, player.lane, player.y, player.grounded])
		print("AUTOTEST died reason=%s dist=%d t=%.0fs speed=%.1f score=%d coins=%d tricks=%d" % [reason, dist, run_time, speed, final, run_coins, tricks_count])
		if "--quit_on_death" in OS.get_cmdline_user_args():
			get_tree().quit()

func revive() -> void:
	if state != State.DEAD or Save.coins < REVIVE_COST:
		return
	Save.coins -= REVIVE_COST
	Save.save_data()
	revives += 1
	# clear the obstacles right ahead
	for o in level.obstacles:
		if o.a0 < dist + 30.0 and o.a1 > dist - 2.0:
			o.dead = true
			if is_instance_valid(o.node):
				o.node.visible = false
	# if we died in the river, skip past it
	for r in Terrain.rivers:
		if dist > r[0] - 2.0 and dist < r[1] + 1.0:
			dist = r[1] + 1.0
	player.revive()
	grace_t = 2.5
	state = State.PLAY
	ui.show_hud(false)

# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAY:
		if event.is_action_pressed("ui_accept") and state == State.MENU:
			start_run()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_used = false
			_touching = true
		else:
			_touching = false
	elif event is InputEventScreenDrag and _touching and not _touch_used:
		var d: Vector2 = event.position - _touch_start
		if d.length() > 45.0:
			_touch_used = true
			if abs(d.x) > abs(d.y):
				_act("right" if d.x > 0 else "left")
			else:
				_act("down" if d.y > 0 else "up")
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A: _act("left")
			KEY_RIGHT, KEY_D: _act("right")
			KEY_UP, KEY_W, KEY_SPACE: _act("up")
			KEY_DOWN, KEY_S: _act("down")
			KEY_ESCAPE, KEY_P: pause()

func _act(a: String) -> void:
	match a:
		"left": player.move(-1)
		"right": player.move(1)
		"up": player.jump()
		"down": player.slam()
	if a != "down" and not player.grounded and player.trick != "":
		_sfx("whoosh", -8.0, randf_range(0.9, 1.15))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match state:
			State.PLAY: pause()
			State.PAUSED: resume()
			State.DEAD: go_menu()
			State.MENU:
				if ui.shop.visible:
					ui.show_menu()
				else:
					get_tree().quit()

# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	delta = min(delta, 0.05)
	var t := Time.get_ticks_msec() / 1000.0
	match state:
		State.MENU:
			menu_t += delta
			dist += 5.0 * delta
			level.update_world(dist)
			player.step(delta, 5.0, 0.0, 0.0)
		State.PLAY:
			_play_step(delta)
		State.DEAD:
			dead_timer += delta
			var slow: float = max(0.0, speed * (1.0 - dead_timer * 2.5))
			dist += slow * delta
			player.position.y = lerp(player.position.y, max(level.ground_at(player.x, dist), Terrain.WATER_Y - 0.6), 1.0 - exp(-8.0 * delta))
			level.update_world(dist)
		State.PAUSED:
			pass
	if state != State.PAUSED:
		level.animate(delta, t)
	_update_curve()
	_update_camera(delta)
	_update_fx(delta)

func _play_step(delta: float) -> void:
	run_time += delta
	speed = min(MAX_SPEED, START_SPEED + ACCEL * run_time)
	var eff_speed := speed * (BOOST_MULT if boost_t > 0.0 else 1.0)
	dist += eff_speed * delta
	level.speed_hint = eff_speed
	level.update_world(dist)
	# ground under player
	var ground := level.ground_at(player.x, dist)
	var slope := 0.0
	var r := level.ramp_at(player.x, dist)
	if not r.is_empty() and player.y <= ground + 0.3:
		slope = r.h / (r.a1 - r.a0) * player.jump_mult
	player.set_shadow_ground(ground)
	var res := player.step(delta, eff_speed, ground, slope)
	if auto_test:
		_autopilot()
	if res == "river":
		_die("river")
		return
	if res == "bad_landing":
		_die("bad_landing")
		return
	if res == "landed":
		_bank_tricks()
	# obstacle collisions
	var hit := level.hit_test(player.x, dist, player.y)
	if not hit.is_empty():
		if boost_t > 0.0 or grace_t > 0.0:
			if boost_t > 0.0 and is_instance_valid(hit.node):
				_smash(hit)
		else:
			_die(hit.type)
			return
	# pickups
	_collect()
	# timers
	magnet_t = max(0.0, magnet_t - delta)
	x2_t = max(0.0, x2_t - delta)
	grace_t = max(0.0, grace_t - delta)
	if boost_t > 0.0:
		boost_t -= delta
		if boost_t <= 0.0:
			grace_t = 1.0
	var mult := 2.0 if x2_t > 0.0 else 1.0
	score += eff_speed * delta * mult
	ui.update_hud(int(score + trick_score), run_coins, int(dist), eff_speed,
		{"magnet": [magnet_t, Save.duration("magnet")], "boost": [max(boost_t, 0.0), Save.duration("boost")], "x2": [x2_t, Save.duration("x2")]},
		player.pending_points)

func _smash(hit: Dictionary) -> void:
	hit.dead = true
	var n: Node3D = hit.node
	_sfx("break", -2.0)
	score += 50
	ui.popup("SMASH! +50", Color(0.5, 0.9, 1.0))
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3(1.4, 0.05, 1.4), 0.15)
	tw.tween_callback(n.hide)

func _bank_tricks() -> void:
	if player.pending_points > 0:
		var mult := 2 if x2_t > 0.0 else 1
		trick_score += player.pending_points * mult
		ui.popup("+%d" % (player.pending_points * mult), Color(1.0, 0.85, 0.2), true)
		player.pending_points = 0

func _collect() -> void:
	var px := player.x
	var py := player.y + 0.9
	var pz_local := -(dist - level.base)
	var magnet := magnet_t > 0.0
	var coin_val: int = Save.board().coin
	for p in level.pickups:
		if p.taken:
			continue
		var da: float = p.a - dist
		if da > 30.0 or da < -3.0:
			continue
		if magnet and p.type == "coin" and da < 16.0 and da > -1.0:
			var node: Node3D = p.node
			var target := Vector3(px, py, pz_local)
			node.position = node.position.lerp(target, 0.25)
			if node.position.distance_to(target) < 1.0:
				_take(p, coin_val)
			continue
		if abs(da) < 1.0 and abs(p.x - px) < 1.0 and abs(p.y - py) < 1.4:
			_take(p, coin_val)

func _take(p: Dictionary, coin_val: int) -> void:
	p.taken = true
	if is_instance_valid(p.node):
		p.node.hide()
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
	best_combo = max(best_combo, combo)
	var txt := nm if combo <= 1 else "%s  x%d" % [nm, combo]
	ui.trick(txt, pts)

func _on_landed(air: float) -> void:
	_sfx("land", -6.0)
	if air > 1.1:
		shake = 0.25
		var bonus := int(air * 100)
		player.pending_points += bonus
		ui.popup("BIG AIR +%d" % bonus, Color(0.7, 1.0, 0.7))

# ------------------------------------------------------------------ autopilot (headless smoke test)
func _autopilot() -> void:
	# naive: dodge to a lane without blocking obstacles ahead, jump low ones
	var best_lane := player.lane
	var best_clear := -1.0
	for l in 3:
		var clear := 60.0
		for o in level.obstacles:
			if o.get("dead", false) or o.h < 50.0:
				continue
			if o.a1 > dist - 0.6 and max(o.a0 - dist, 0.0) < clear and abs(Level.LANES[l] - o.x) < o.hw + 0.5:
				clear = max(o.a0 - dist, 0.0)
		if clear > best_clear + 0.1 or (abs(clear - best_clear) < 0.1 and l == player.lane):
			best_clear = clear
			best_lane = l
	if best_lane != player.lane:
		player.move(sign(best_lane - player.lane))
	for o in level.obstacles:
		if not o.get("dead", false) and o.h < 50.0 and o.a0 - dist > 0.0 and o.a0 - dist < speed * 0.32 and abs(player.x - o.x) < o.hw + 0.5:
			player.jump()
	for rv in Terrain.rivers:
		if rv[0] - dist > 0.0 and rv[0] - dist < speed * 0.25 and player.grounded:
			player.jump()
	if not player.grounded and player.vy > 2.0 and player.trick == "" and player.y > 2.5:
		player.jump() # flip

# ------------------------------------------------------------------ visuals
func _update_curve() -> void:
	var cx := sin(dist * 0.0042) * 0.0026 + sin(dist * 0.0013 + 1.7) * 0.0016
	var cy := 0.0017 + sin(dist * 0.0021) * 0.0006
	RenderingServer.global_shader_parameter_set("curve_x", cx)
	RenderingServer.global_shader_parameter_set("curve_y", cy)

func _update_camera(delta: float) -> void:
	var k := 1.0 - exp(-6.0 * delta)
	var target_x := player.x * 0.7
	_cam_x = lerp(_cam_x, target_x, k)
	_cam_y = lerp(_cam_y, max(player.y, 0.0) * 0.55, 1.0 - exp(-4.0 * delta))
	var shake_off := Vector3.ZERO
	if shake > 0.0:
		shake = max(0.0, shake - delta)
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.35
	if state == State.MENU:
		var a := sin(menu_t * 0.3) * 0.3 + 0.35
		if ui.shop.visible:
			cam.position = cam.position.lerp(Vector3(sin(a) * 4.2, 2.4, -cos(a) * 4.2), k)
			cam.look_at(Vector3(0, -0.2, 0))
		else:
			cam.position = cam.position.lerp(Vector3(sin(a) * 6.0, 2.0, -cos(a) * 6.0), k)
			cam.look_at(Vector3(0, 0.55, 0))
		cam.fov = lerp(cam.fov, 55.0, k)
		return
	if state == State.DEAD:
		var cp := Vector3(player.x * 0.5 + 2.5, 5.5, 7.5)
		cam.position = cam.position.lerp(cp, 1.0 - exp(-2.5 * delta)) + shake_off
		cam.look_at(Vector3(player.x, 0.8, -0.5))
		return
	cam.position = Vector3(_cam_x, 3.9 + _cam_y, 6.4) + shake_off
	cam.look_at(Vector3(_cam_x * 0.8, 1.1 + _cam_y * 0.8, -8.0))
	cam.rotate_object_local(Vector3.FORWARD, -(player.x - _cam_x) * 0.03)
	var target_fov := 60.0 + (speed - START_SPEED) * 0.55 + (9.0 if boost_t > 0.0 else 0.0)
	cam.fov = lerp(cam.fov, target_fov, 1.0 - exp(-3.0 * delta))

func _update_fx(delta: float) -> void:
	mountains.position = Vector3(cam.position.x, 0, cam.position.z)
	snowfall.gravity = Vector3(0, -1.0, speed * 0.9 if state == State.PLAY else 2.0)
	player.trail.emitting = boost_t > 0.0 and state == State.PLAY
	var target_db: float = -34.0 + clamp((speed - 10.0) / 20.0, 0.0, 1.0) * 18.0 if state == State.PLAY else -34.0
	if not Save.sound_on:
		target_db = -80.0
	wind.volume_db = lerp(wind.volume_db, target_db, 1.0 - exp(-2.0 * delta))
	wind.pitch_scale = 0.8 + clamp(speed / MAX_SPEED, 0.0, 1.0) * 0.5
