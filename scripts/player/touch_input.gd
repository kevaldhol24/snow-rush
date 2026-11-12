class_name TouchInput
extends Node
## Drag-to-carve steering + flick gestures. Keyboard fallback for desktop testing.
## steer: -1..1, relative to where the finger went down (anchor follows if you overshoot,
## so reversing direction responds instantly). Flicks: fast short swipes.

signal flick(dir: String) # "up", "down", "left", "right"

const FLICK_WINDOW := 0.13 # seconds
const FLICK_MIN_PX := 70.0
const FRESH_TOUCH := 0.3 # sideways flicks (spins) only from a new touch, never mid-steer
const SENS_RANGE := [0.24, 0.17, 0.12] # fraction of screen width for full lock (low/med/high sensitivity)

var steer := 0.0
var enabled := true
var _idx := -1
var _anchor := 0.0
var _samples: Array = [] # [time, Vector2]
var _flicked_at := -1.0
var _down_at := 0.0
var _key_steer := 0.0

func _range_px() -> float:
	var w := get_viewport().get_visible_rect().size.x
	return w * SENS_RANGE[clampi(Save.settings.sens, 0, 2)]

func reset() -> void:
	steer = 0.0
	_idx = -1
	_samples.clear()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _idx == -1:
			_idx = event.index
			_anchor = event.position.x
			_down_at = _now()
			_samples = [[_now(), event.position]]
		elif not event.pressed and event.index == _idx:
			_idx = -1
			steer = 0.0
			_samples.clear()
	elif event is InputEventScreenDrag and event.index == _idx:
		var range_px := _range_px()
		var dx: float = event.position.x - _anchor
		if dx > range_px:
			_anchor = event.position.x - range_px
		elif dx < -range_px:
			_anchor = event.position.x + range_px
		steer = clamp((event.position.x - _anchor) / range_px, -1.0, 1.0)
		var t := _now()
		_samples.append([t, event.position])
		while _samples.size() > 2 and t - _samples[0][0] > FLICK_WINDOW:
			_samples.pop_front()
		_check_flick(t)
	elif event is InputEventKey and not event.echo:
		_key(event)

func _check_flick(t: float) -> void:
	if t - _flicked_at < 0.25 or _samples.size() < 2:
		return
	var d: Vector2 = _samples[-1][1] - _samples[0][1]
	if abs(d.y) > FLICK_MIN_PX and abs(d.y) > abs(d.x) * 1.8:
		_flicked_at = t
		flick.emit("down" if d.y > 0 else "up")
	elif t - _down_at < FRESH_TOUCH and abs(d.x) > FLICK_MIN_PX * 1.3 and abs(d.x) > abs(d.y) * 1.4:
		_flicked_at = t
		flick.emit("right" if d.x > 0 else "left")

func _key(e: InputEventKey) -> void:
	var held := e.pressed
	match e.keycode:
		KEY_LEFT, KEY_A:
			_key_steer = -1.0 if held else (0.0 if _key_steer < 0 else _key_steer)
		KEY_RIGHT, KEY_D:
			_key_steer = 1.0 if held else (0.0 if _key_steer > 0 else _key_steer)
		KEY_UP, KEY_W, KEY_SPACE:
			if held: flick.emit("up")
		KEY_DOWN, KEY_S:
			if held: flick.emit("down")
		KEY_Q:
			if held: flick.emit("left")
		KEY_E:
			if held: flick.emit("right")
	if _idx == -1:
		steer = _key_steer
