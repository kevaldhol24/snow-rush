extends Node
## Persistent player data + shop catalogue.

const PATH := "user://save.cfg"

# Boards: tier stats. jump = jump velocity multiplier, trick = trick score multiplier,
# handling = lane-switch speed multiplier, coin = coin value.
const BOARDS := [
	{"id": "plank", "name": "Pine Plank", "price": 0, "color": Color(0.62, 0.40, 0.22), "accent": Color(0.95, 0.85, 0.6), "glow": 0.0,
		"jump": 1.00, "trick": 1.0, "handling": 1.00, "coin": 1, "desc": "Trusty starter board."},
	{"id": "frost", "name": "Frost Runner", "price": 600, "color": Color(0.35, 0.75, 1.0), "accent": Color(1, 1, 1), "glow": 0.25,
		"jump": 1.06, "trick": 1.25, "handling": 1.10, "coin": 1, "desc": "+6% jump, x1.25 tricks"},
	{"id": "lava", "name": "Lava Rider", "price": 1800, "color": Color(1.0, 0.38, 0.08), "accent": Color(1.0, 0.85, 0.2), "glow": 0.8,
		"jump": 1.10, "trick": 1.5, "handling": 1.18, "coin": 1, "desc": "+10% jump, x1.5 tricks"},
	{"id": "aurora", "name": "Aurora", "price": 4500, "color": Color(0.55, 0.25, 0.95), "accent": Color(0.3, 1.0, 0.75), "glow": 1.0,
		"jump": 1.14, "trick": 2.0, "handling": 1.25, "coin": 1, "desc": "+14% jump, x2 tricks"},
	{"id": "gold", "name": "Golden Legend", "price": 12000, "color": Color(1.0, 0.78, 0.15), "accent": Color(1, 1, 0.85), "glow": 0.6,
		"jump": 1.18, "trick": 2.5, "handling": 1.32, "coin": 2, "desc": "+18% jump, x2.5 tricks, 2x coins"},
]

const UPGRADES := [
	{"id": "magnet", "name": "Coin Magnet", "desc": "Longer magnet", "base": 6.0, "step": 2.0, "max": 5},
	{"id": "boost", "name": "Avalanche Boost", "desc": "Longer boost", "base": 4.0, "step": 1.2, "max": 5},
	{"id": "x2", "name": "Double Score", "desc": "Longer 2x score", "base": 8.0, "step": 2.5, "max": 5},
]

var coins := 0
var best := 0
var owned := ["plank"]
var equipped := "plank"
var levels := {"magnet": 0, "boost": 0, "x2": 0}
var total_runs := 0
var sound_on := true
# sens: 0 low,1 med,2 high steering sensitivity; quality: 0 low,1 high; fps: show perf overlay
var settings := {"sens": 1, "quality": 1, "fps": false}

func _ready() -> void:
	load_data()

func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	coins = cf.get_value("p", "coins", 0)
	best = cf.get_value("p", "best", 0)
	owned = cf.get_value("p", "owned", ["plank"])
	equipped = cf.get_value("p", "equipped", "plank")
	var lv: Dictionary = cf.get_value("p", "levels", {})
	for k in levels.keys():
		levels[k] = int(lv.get(k, 0))
	total_runs = cf.get_value("p", "runs", 0)
	sound_on = cf.get_value("p", "sound", true)
	var st: Dictionary = cf.get_value("p", "settings", {})
	for k in settings.keys():
		if st.has(k):
			settings[k] = st[k]

func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "coins", coins)
	cf.set_value("p", "best", best)
	cf.set_value("p", "owned", owned)
	cf.set_value("p", "equipped", equipped)
	cf.set_value("p", "levels", levels)
	cf.set_value("p", "runs", total_runs)
	cf.set_value("p", "sound", sound_on)
	cf.set_value("p", "settings", settings)
	cf.set_value("p", "version", 2)
	cf.save(PATH)

func board() -> Dictionary:
	for b in BOARDS:
		if b.id == equipped:
			return b
	return BOARDS[0]

func board_by_id(id: String) -> Dictionary:
	for b in BOARDS:
		if b.id == id:
			return b
	return BOARDS[0]

func upgrade_def(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}

func duration(id: String) -> float:
	var u := upgrade_def(id)
	return u.base + u.step * levels[id]

func upgrade_cost(id: String) -> int:
	var l: int = levels[id]
	return int(round(250.0 * pow(l + 1, 1.7) / 10.0) * 10)

func try_buy_board(id: String) -> bool:
	var b := board_by_id(id)
	if id in owned or coins < b.price:
		return false
	coins -= b.price
	owned.append(id)
	equipped = id
	save_data()
	return true

func try_upgrade(id: String) -> bool:
	var u := upgrade_def(id)
	if levels[id] >= u.max:
		return false
	var c := upgrade_cost(id)
	if coins < c:
		return false
	coins -= c
	levels[id] += 1
	save_data()
	return true
