class_name UI
extends CanvasLayer
## All menus + HUD, built in code. Portrait 720x1280 reference.

signal play_pressed
signal retry_pressed
signal menu_pressed
signal revive_pressed
signal pause_pressed
signal resume_pressed
signal board_changed

const FONT := preload("res://assets/fonts/lilita_one_regular.ttf")
const C_BLUE := Color(0.16, 0.5, 0.95)
const C_ORANGE := Color(1.0, 0.55, 0.1)
const C_GREEN := Color(0.25, 0.8, 0.35)
const C_PURPLE := Color(0.55, 0.3, 0.9)
const C_GOLD := Color(1.0, 0.82, 0.2)
const C_DARK := Color(0.07, 0.15, 0.32)

var root: Control
var menu: Control
var hud: Control
var pause_s: Control
var over: Control
var shop: Control

# hud refs
var score_l: Label
var dist_l: Label
var coins_l: Label
var trick_l: Label
var pending_l: Label
var hint_l: Label
var popups: VBoxContainer
var pu_bars := {}
# menu refs
var m_coins: Label
var m_best: Label
var sound_b: Button
# over refs
var o_title: Label
var o_score: Label
var o_newbest: Label
var o_stats: Label
var o_revive: Button
# shop refs
var shop_list: VBoxContainer
var shop_coins: Label
var shop_tab := "boards"

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 34
	root.theme = th
	add_child(root)
	_build_hud()
	_build_menu()
	_build_shop()
	_build_pause()
	_build_over()

# ------------------------------------------------------------------ helpers
func _ls(size: int, col := Color.WHITE, outline := 10, oc := C_DARK) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = FONT
	s.font_size = size
	s.font_color = col
	s.outline_size = outline
	s.outline_color = oc
	s.shadow_size = 0 if outline == 0 else 2
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_offset = Vector2(0, 5)
	return s

func _label(txt: String, size: int, col := Color.WHITE, outline := 10) -> Label:
	var l := Label.new()
	l.text = txt
	l.label_settings = _ls(size, col, outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _sb(col: Color, radius := 26, border := 0, bcol := Color.BLACK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	if border > 0:
		s.border_width_bottom = border
		s.border_color = bcol
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 12
	s.content_margin_bottom = 12 + border
	return s

func _button(txt: String, col: Color, size := 46, min_w := 420.0, h := 104.0) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(min_w, h)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.85))
	b.add_theme_color_override("font_outline_color", col.darkened(0.55))
	b.add_theme_constant_override("outline_size", 8)
	b.add_theme_stylebox_override("normal", _sb(col, 28, 10, col.darkened(0.4)))
	b.add_theme_stylebox_override("hover", _sb(col.lightened(0.08), 28, 10, col.darkened(0.4)))
	var p := _sb(col.darkened(0.08), 28, 3, col.darkened(0.4))
	p.content_margin_top = 19
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): _press_anim(b))
	return b

func _press_anim(b: Control) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.05)
	tw.tween_property(b, "scale", Vector2.ONE, 0.1)

func _coin_icon(sz := 44) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.7, 0.72, 1.0])
	g.colors = PackedColorArray([Color(1, 0.95, 0.55), Color(1, 0.8, 0.15), Color(0.85, 0.55, 0.05), Color(0.85, 0.55, 0.05, 0), Color(0, 0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(sz, sz)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _pill(content: Control, col := Color(0.05, 0.12, 0.3, 0.55)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _sb(col, 40)
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.content_margin_left = 16
	s.content_margin_right = 22
	p.add_theme_stylebox_override("panel", s)
	p.add_child(content)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _coin_row(lbl: Label, sz := 44) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(_coin_icon(sz))
	h.add_child(lbl)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

func _screen() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	root.add_child(c)
	return c

func _hide_all() -> void:
	for s in [menu, hud, pause_s, over, shop]:
		s.visible = false

func _fade_in(c: Control) -> void:
	c.visible = true
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, 0.2)

# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	hud = _screen()
	var pb := _button("II", Color(0.1, 0.25, 0.55, 0.85), 40, 92, 92)
	pb.position = Vector2(26, 56)
	pb.pressed.connect(func(): pause_pressed.emit())
	hud.add_child(pb)
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-26, 50)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(right)
	score_l = _label("0", 64)
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(score_l)
	coins_l = _label("0", 40, C_GOLD, 8)
	var cr := _coin_row(coins_l, 40)
	cr.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(cr)
	dist_l = _label("0 m", 30, Color(0.9, 0.95, 1.0), 7)
	dist_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(dist_l)
	# powerup bars under pause button
	var pv := VBoxContainer.new()
	pv.position = Vector2(26, 170)
	pv.add_theme_constant_override("separation", 10)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(pv)
	for k in [["magnet", "MAGNET", Color(1, 0.3, 0.35)], ["boost", "BOOST", Color(0.3, 0.85, 1)], ["x2", "2X", Color(1, 0.4, 0.9)]]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_label(k[1], 26, k[2], 6))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(170, 16)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.add_theme_stylebox_override("background", _sb(Color(0, 0, 0, 0.35), 8))
		var fill := _sb(k[2], 8)
		fill.content_margin_top = 0
		fill.content_margin_bottom = 0
		bar.add_theme_stylebox_override("fill", fill)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bar)
		box.visible = false
		pv.add_child(box)
		pu_bars[k[0]] = [box, bar]
	trick_l = _label("", 64, Color.WHITE, 12)
	trick_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	trick_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trick_l.position = Vector2(-300, 330)
	trick_l.size = Vector2(600, 80)
	hud.add_child(trick_l)
	pending_l = _label("", 44, C_GOLD, 9)
	pending_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pending_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pending_l.position = Vector2(-300, 410)
	pending_l.size = Vector2(600, 60)
	hud.add_child(pending_l)
	popups = VBoxContainer.new()
	popups.set_anchors_preset(Control.PRESET_CENTER_TOP)
	popups.position = Vector2(-300, 480)
	popups.size = Vector2(600, 200)
	popups.alignment = BoxContainer.ALIGNMENT_BEGIN
	popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(popups)
	hint_l = _label("", 40, Color.WHITE, 10)
	hint_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint_l.position = Vector2(-320, -330)
	hint_l.size = Vector2(640, 200)
	hud.add_child(hint_l)

func show_hud(tutorial: bool) -> void:
	_hide_all()
	hud.visible = true
	trick_l.text = ""
	pending_l.text = ""
	for c in popups.get_children():
		c.queue_free()
	if tutorial:
		_run_tutorial()
	else:
		hint_l.text = ""

func _run_tutorial() -> void:
	var steps := ["Swipe LEFT / RIGHT\nto dodge trees", "Swipe UP to jump\nrocks, logs & rivers", "In the air: swipe UP to BACKFLIP\nLEFT/RIGHT to SPIN", "Land your tricks clean!\nHit ramps for big air"]
	for s in steps:
		hint_l.text = s
		hint_l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(hint_l, "modulate:a", 1.0, 0.25)
		await get_tree().create_timer(3.2).timeout
		if not hud.visible:
			return
	var tw2 := create_tween()
	tw2.tween_property(hint_l, "modulate:a", 0.0, 0.3)

func update_hud(score: int, coins: int, dist: int, _speed: float, pus: Dictionary, pending: int) -> void:
	score_l.text = str(score)
	coins_l.text = str(coins)
	dist_l.text = "%d m" % dist
	for k in pus:
		var v: Array = pus[k]
		var on: bool = v[0] > 0.0
		pu_bars[k][0].visible = on
		if on:
			pu_bars[k][1].value = v[0] / v[1]
	pending_l.text = "+%d" % pending if pending > 0 else ""

func trick(txt: String, pts: int) -> void:
	trick_l.text = txt
	trick_l.pivot_offset = trick_l.size * 0.5
	trick_l.scale = Vector2(1.6, 1.6)
	trick_l.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(trick_l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(trick_l, "modulate:a", 0.0, 0.25)

func popup(txt: String, col: Color, big := false) -> void:
	var l := _label(txt, 50 if big else 40, col, 9)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popups.add_child(l)
	if popups.get_child_count() > 3:
		popups.get_child(0).queue_free()
	var tw := create_tween()
	l.modulate.a = 0.0
	tw.tween_property(l, "modulate:a", 1.0, 0.1)
	tw.tween_interval(0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)

# ------------------------------------------------------------------ MENU
func _build_menu() -> void:
	menu = _screen()
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 26
	top.offset_right = -26
	top.offset_top = 56
	top.offset_bottom = 126
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(top)
	m_best = _label("BEST 0", 36, Color.WHITE, 8)
	top.add_child(_pill(m_best))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp)
	m_coins = _label("0", 38, C_GOLD, 8)
	top.add_child(_pill(_coin_row(m_coins, 40)))
	var title := _label("SNOW\nRUSH", 150, Color.WHITE, 26)
	title.label_settings.outline_color = Color(0.1, 0.35, 0.8)
	title.label_settings.line_spacing = -40
	title.label_settings.shadow_size = 6
	title.label_settings.shadow_offset = Vector2(0, 12)
	title.label_settings.shadow_color = Color(0.05, 0.15, 0.4, 0.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-340, 150)
	title.size = Vector2(680, 330)
	menu.add_child(title)
	var sub := _label("ENDLESS DOWNHILL", 34, Color(0.85, 0.95, 1.0), 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(-340, 470)
	sub.size = Vector2(680, 50)
	menu.add_child(sub)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.position = Vector2(-230, -380)
	v.size = Vector2(460, 320)
	v.add_theme_constant_override("separation", 22)
	v.alignment = BoxContainer.ALIGNMENT_END
	menu.add_child(v)
	var play := _button("PLAY", C_ORANGE, 64, 460, 130)
	play.pressed.connect(func(): play_pressed.emit())
	v.add_child(play)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	var shop_b := _button("SHOP", C_BLUE, 42, 320, 100)
	shop_b.pressed.connect(show_shop)
	h.add_child(shop_b)
	sound_b = _button("SND", C_PURPLE, 32, 120, 100)
	sound_b.pressed.connect(_toggle_sound)
	h.add_child(sound_b)
	# idle pulse on play button
	play.pivot_offset = Vector2(230, 65)
	var tw := create_tween().set_loops()
	tw.tween_property(play, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(play, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

func _toggle_sound() -> void:
	Save.sound_on = not Save.sound_on
	Save.save_data()
	_refresh_sound()

func _refresh_sound() -> void:
	sound_b.text = "SND" if Save.sound_on else "OFF"

func show_menu() -> void:
	_hide_all()
	m_coins.text = str(Save.coins)
	m_best.text = "BEST %d" % Save.best
	_refresh_sound()
	_fade_in(menu)

# ------------------------------------------------------------------ SHOP
func _build_shop() -> void:
	shop = _screen()
	shop.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top = 0.42
	panel.offset_top = 0
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_bottom = -16
	var ps := _sb(Color(0.93, 0.96, 1.0, 0.97), 36)
	ps.content_margin_left = 22
	ps.content_margin_right = 22
	ps.content_margin_top = 20
	ps.content_margin_bottom = 20
	ps.shadow_color = Color(0, 0.1, 0.3, 0.3)
	ps.shadow_size = 18
	panel.add_theme_stylebox_override("panel", ps)
	shop.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var back := _button("<", C_BLUE, 44, 90, 84)
	back.pressed.connect(show_menu)
	head.add_child(back)
	var t := _label("  SHOP", 56, C_DARK, 0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	shop_coins = _label("0", 40, C_GOLD, 8)
	head.add_child(_pill(_coin_row(shop_coins, 40), C_DARK))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 14)
	v.add_child(tabs)
	var tb := _button("BOARDS", C_ORANGE, 34, 300, 76)
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.pressed.connect(func(): shop_tab = "boards"; _refresh_shop())
	tabs.add_child(tb)
	var tu := _button("UPGRADES", C_GREEN, 34, 300, 76)
	tu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tu.pressed.connect(func(): shop_tab = "upgrades"; _refresh_shop())
	tabs.add_child(tu)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 12)
	sc.add_child(shop_list)

func show_shop() -> void:
	_hide_all()
	menu.visible = false
	_refresh_shop()
	_fade_in(shop)

func _card(col: Color) -> Array:
	var p := PanelContainer.new()
	var s := _sb(Color.WHITE, 24, 6, Color(0.75, 0.82, 0.92))
	s.content_margin_left = 16
	s.content_margin_right = 16
	p.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var sw := Panel.new()
	sw.custom_minimum_size = Vector2(70, 70)
	var ss := _sb(col, 18, 6, col.darkened(0.35))
	sw.add_theme_stylebox_override("panel", ss)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	h.add_child(info)
	return [p, h, info]

func _refresh_shop() -> void:
	shop_coins.text = str(Save.coins)
	for c in shop_list.get_children():
		c.queue_free()
	if shop_tab == "boards":
		for b in Save.BOARDS:
			var parts := _card(b.color)
			var info: VBoxContainer = parts[2]
			info.add_child(_label(b.name, 36, C_DARK, 0))
			var d := _label(b.desc, 24, Color(0.35, 0.42, 0.55), 0)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD
			info.add_child(d)
			var btn: Button
			if b.id == Save.equipped:
				btn = _button("ON", Color(0.55, 0.6, 0.7), 30, 150, 80)
				btn.disabled = true
			elif b.id in Save.owned:
				btn = _button("USE", C_BLUE, 30, 150, 80)
				btn.pressed.connect(func(): Save.equipped = b.id; Save.save_data(); board_changed.emit(); _refresh_shop())
			else:
				btn = _button(str(b.price), C_GREEN if Save.coins >= b.price else Color(0.6, 0.62, 0.68), 30, 150, 80)
				btn.pressed.connect(func():
					if Save.try_buy_board(b.id):
						board_changed.emit()
					_refresh_shop())
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			parts[1].add_child(btn)
			shop_list.add_child(parts[0])
	else:
		var cols := {"magnet": Color(1, 0.3, 0.35), "boost": Color(0.3, 0.8, 1.0), "x2": Color(1, 0.4, 0.9)}
		for u in Save.UPGRADES:
			var parts := _card(cols[u.id])
			var info: VBoxContainer = parts[2]
			info.add_child(_label(u.name, 34, C_DARK, 0))
			var lv: int = Save.levels[u.id]
			var d := _label("%s  %.0fs   LV %d/%d" % [u.desc, Save.duration(u.id), lv, u.max], 26, Color(0.35, 0.42, 0.55), 0)
			info.add_child(d)
			var btn: Button
			if lv >= u.max:
				btn = _button("MAX", Color(0.55, 0.6, 0.7), 30, 150, 80)
				btn.disabled = true
			else:
				var cost := Save.upgrade_cost(u.id)
				btn = _button(str(cost), C_GREEN if Save.coins >= cost else Color(0.6, 0.62, 0.68), 30, 150, 80)
				btn.pressed.connect(func(): Save.try_upgrade(u.id); _refresh_shop())
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			parts[1].add_child(btn)
			shop_list.add_child(parts[0])

# ------------------------------------------------------------------ PAUSE
func _build_pause() -> void:
	pause_s = _screen()
	pause_s.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.2, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_s.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-220, -200)
	v.size = Vector2(440, 400)
	v.add_theme_constant_override("separation", 26)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_s.add_child(v)
	var t := _label("PAUSED", 90)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var r := _button("RESUME", C_ORANGE, 50, 440, 116)
	r.pressed.connect(func(): resume_pressed.emit())
	v.add_child(r)
	var m := _button("MENU", C_BLUE, 44, 440, 104)
	m.pressed.connect(func(): menu_pressed.emit())
	v.add_child(m)

func show_pause() -> void:
	_hide_all()
	_fade_in(pause_s)

# ------------------------------------------------------------------ GAME OVER
func _build_over() -> void:
	over = _screen()
	over.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.2, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 40
	v.offset_right = -40
	v.offset_top = 150
	v.offset_bottom = -60
	v.add_theme_constant_override("separation", 14)
	over.add_child(v)
	o_title = _label("WIPEOUT!", 96, Color.WHITE, 18)
	o_title.label_settings.outline_color = Color(0.85, 0.2, 0.25)
	o_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(o_title)
	var card := PanelContainer.new()
	var cs := _sb(Color(0.95, 0.97, 1.0, 0.97), 36)
	cs.content_margin_top = 24
	cs.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", cs)
	v.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	card.add_child(cv)
	var sl := _label("SCORE", 34, Color(0.4, 0.5, 0.65), 0)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(sl)
	o_score = _label("0", 110, C_DARK, 0)
	o_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(o_score)
	o_newbest = _label("NEW BEST!", 44, C_ORANGE, 0)
	o_newbest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(o_newbest)
	o_stats = _label("", 34, Color(0.25, 0.32, 0.45), 0)
	o_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(o_stats)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	o_revive = _button("REVIVE  (150)", C_GREEN, 44, 640, 110)
	o_revive.pressed.connect(func(): revive_pressed.emit())
	v.add_child(o_revive)
	var again := _button("PLAY AGAIN", C_ORANGE, 52, 640, 124)
	again.pressed.connect(func(): retry_pressed.emit())
	v.add_child(again)
	var m := _button("MENU", C_BLUE, 40, 640, 96)
	m.pressed.connect(func(): menu_pressed.emit())
	v.add_child(m)

func show_game_over(d: Dictionary) -> void:
	_hide_all()
	o_title.text = d.title
	o_score.text = str(d.score)
	o_newbest.visible = d.new_best
	o_newbest.text = "NEW BEST!" if d.new_best else ""
	o_stats.text = "%d m    %d coins    %d tricks\nBEST  %d" % [d.dist, d.coins, d.tricks, d.best]
	o_revive.visible = d.can_revive
	o_revive.text = "REVIVE  (%d coins)" % d.revive_cost
	_fade_in(over)
	# count-up
	var tw := create_tween()
	tw.tween_method(func(x): o_score.text = str(int(x)), 0.0, float(d.score), 0.6)
