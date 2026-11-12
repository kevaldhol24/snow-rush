class_name Autopilot
extends RefCounted
## Dev bot for headless regression runs (--autotest). Follows the generator's safe line,
## dodges obstacles near it, and throws tricks when there is enough air time.

var _trick_cd := 0.0

func drive(g, delta: float) -> void:
	var r: Rider = g.rider
	var w: World = g.world
	var look: float = r.a + max(g.speed * 0.45, 8.0)
	var target: float = w.gen.safe_u(look)
	# nudge away from an obstacle right in front
	for o in w.obstacles:
		if o.dead or o.a < r.a:
			continue
		if o.a > r.a + g.speed * 0.6:
			break
		if abs(o.u - r.u) < o.r + 0.8 and o.h > 1.5:
			target = o.u + (o.r + 1.4) * (1.0 if r.u >= o.u else -1.0)
	# --weave: carve S-turns across the run (for screenshots of the carve look)
	if "--weave" in OS.get_cmdline_user_args():
		target = sin(g.run_time * 0.55) * (Track.HALF_W - 3.0)
	# carve steering (D-014): aim the board at the target point ahead
	var aim_dist: float = max(g.speed * 0.55, 12.0)
	var want_head := atan2(target - r.u, aim_dist)
	r.steer = clamp(want_head / Rider.MAX_HEAD, -1.0, 1.0)
	_trick_cd -= delta
	if not r.grounded and r.trick == "" and _trick_cd <= 0.0:
		var ttl := r.time_to_land(g.speed)
		if ttl > 0.75:
			if randf() < 0.6:
				r.jump() # backflip
			else:
				r.spin(1 if randf() < 0.5 else -1)
			_trick_cd = 0.1
