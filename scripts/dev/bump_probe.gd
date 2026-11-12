extends Node
## Dev probe: ride featureless terrain (rollers + noise only) at fixed speeds and report how
## "bumpy" it is. ## Run: godot --headless --path . res://scenes/dev/bump_probe.tscn
## Reports per km: unwanted take-offs (tiny hops), RMS vertical acceleration while grounded.

func _ready() -> void:
	for spd in [22.0, 30.0, 36.0]:
		var hops := 0
		var tot_air := 0.0
		var acc_sq := 0.0
		var n := 0
		var dist := 0.0
		for s in [1, 2, 3]:
			var tr := Track.new(s)
			tr.roll_target = 0.3
			tr.extend_to(2200.0)
			var st := {"u": 0.0, "a": 20.0, "y": tr.ground(0.0, 20.0), "vy": 0.0, "grounded": true, "air": 0.0}
			var dt := 1.0 / 60.0
			var prev_vy := 0.0
			while st.a < 2000.0:
				st.u = sin(st.a / 37.0) * 6.0 # weave across the run like a player
				st.a += spd * dt
				var was: bool = st.grounded
				var res := Rider.surface_step(st, tr, dt)
				if res == "takeoff":
					hops += 1
				if res == "land":
					tot_air += st.air
				if was and st.grounded:
					# vertical acceleration relative to the nominal slope (what the camera/rider feel)
					var acc: float = (st.vy - prev_vy) / dt
					acc_sq += acc * acc
					n += 1
				prev_vy = st.vy
			dist += 1980.0
		print("speed %.0f m/s: hops/km=%.1f  mean_air=%.2fs  rms_vert_acc=%.1f m/s^2" % [spd, hops / (dist / 1000.0), tot_air / max(hops, 1), sqrt(acc_sq / max(n, 1))])
	get_tree().quit()
