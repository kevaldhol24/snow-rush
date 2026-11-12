class_name DevShots
extends RefCounted
## --shots=<abs dir> --shot_times=2,6,12 [--shop] [--settings] : capture PNGs then quit.

static func run(game, dir: String, args: PackedStringArray) -> void:
	var times := [2.0, 6.0, 12.0]
	for a in args:
		if a.begins_with("--shot_times="):
			times = Array(a.substr(13).split(",")).map(func(s): return float(s))
		if a == "--shop":
			game.ui.show_shop()
		if a == "--settings":
			game.ui.show_settings()
	var elapsed := 0.0
	for i in times.size():
		await game.get_tree().create_timer(times[i] - elapsed).timeout
		elapsed = times[i]
		var img: Image = game.get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%02d.png" % [dir, i])
		print("SHOT %d state=%d a=%.0f speed=%.1f score=%d fps=%d" % [i, game.state, game.rider.a, game.speed,
			int(game.score + game.trick_score), Engine.get_frames_per_second()])
	game.get_tree().quit()
