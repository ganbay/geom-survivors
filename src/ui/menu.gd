extends Control
## Main menu: pick a shape, pick a depth, play. Settings and run history open as pop-ups.

const STATS := [["HP", "hp"], ["SPEED", "speed"], ["ARMOR", "armor"], ["CRIT", "crit"]]

var selected := "triangle"
var depth := 0
var char_cards := {}
var char_name: Label
var char_desc: Label
var start_row: HBoxContainer
var stat_meters := {}
var depth_label: Label
var depth_desc: Label
var best_label: Label
var modal: Modal
var bg: Control
var t := 0.0
# drifting background shapes: [pos, vel, sides, radius, rot, spin, color]
var floaters: Array = []


func _ready() -> void:
	theme = UI.theme()
	Shapes.low_quality = Save.get_setting("low_quality", false)
	RenderingServer.set_default_clear_color(Balance.C_BG)
	selected = Save.run_config.get("character", "triangle")
	depth = mini(Save.run_config.get("depth", 0), Save.depth_unlocked())

	bg = Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = Shapes.get_add_material()
	bg.draw.connect(_draw_bg)
	add_child(bg)
	for i in 14:
		floaters.append([Vector2(randf(), randf()) * get_viewport_rect().size, Vector2(randf_range(-15, 15), randf_range(-25, -8)),
				[0, 3, 4, 5, 6, -5].pick_random(), randf_range(10.0, 34.0), randf() * TAU, randf_range(-0.6, 0.6),
				[Color(1.0, 0.25, 0.75), Color(1.0, 0.55, 0.15), Color(0.75, 0.4, 1.0), Balance.C_PLAYER].pick_random()])

	var col := UI.column(self, 16, 32)
	col.add_child(UI.glow_label("GEOM", 104, Balance.C_PLAYER, HORIZONTAL_ALIGNMENT_CENTER, 14))
	var sub := UI.glow_label("SURVIVORS", 34, Color(1.0, 0.3, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 16)
	col.add_child(sub)
	col.add_child(_spacer(18))

	col.add_child(UI.header("SELECT SHAPE"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	for id in Balance.CHARACTERS:
		var card := _char_card(id)
		row.add_child(card)
		char_cards[id] = card
	col.add_child(_char_panel())

	col.add_child(UI.header("DEPTH"))
	col.add_child(_depth_panel())
	col.add_child(_spacer(4))

	var play := UI.button("PLAY", _play, 104, true)
	play.add_theme_font_size_override("font_size", 42)
	col.add_child(play)
	best_label = UI.label("", 18, Balance.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(best_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	col.add_child(bottom)
	for pair in [["HISTORY", _open_history], ["SETTINGS", _open_settings]]:
		var b := UI.button(pair[0], pair[1], 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_font_override("font", UI.wide_font(3))
		bottom.add_child(b)

	_select(selected)
	_set_depth(depth)
	Sfx.play_music("menu")


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _char_card(id: String) -> Control:
	var d: Dictionary = Balance.CHARACTERS[id]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		Sfx.play("click")
		_select(id))
	var icon := Control.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func():
		var c := icon.size / 2.0 - Vector2(0, 14)
		var on := selected == id
		var col := Balance.C_PLAYER if on else Balance.C_TEXT_DIM
		var rot := t * (0.8 if on else 0.0)
		var base := PI / 4.0 if d.sides == 4 else -PI / 2.0
		if on:
			Shapes.draw_neon_ring(icon, c, 50.0 + sin(t * 3.0) * 2.0, Color(col, 0.25), 1.5)
		Shapes.draw_neon_poly(icon, Transform2D(0.0, c) * Shapes.points(d.sides, 34.0, base + rot), col, 3.0, 0.18 if on else 0.05))
	b.add_child(icon)
	var l := UI.label(d.name, 16, Balance.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", UI.wide_font(3))
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.position.y = -34
	b.add_child(l)
	return b


func _char_panel() -> PanelContainer:
	var p := UI.panel(Color(0.3, 0.5, 0.8, 0.7))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	char_name = UI.glow_label("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 3)
	char_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(char_name)
	start_row = HBoxContainer.new()
	start_row.add_theme_constant_override("separation", 6)
	top.add_child(start_row)
	char_desc = UI.wrap_label("", 20, Balance.C_TEXT)
	v.add_child(char_desc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for st in STATS:
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 8)
		var cap := UI.label(st[0], 14, Balance.C_TEXT_DIM)
		cap.add_theme_font_override("font", UI.wide_font(2))
		cap.custom_minimum_size.x = 64
		cell.add_child(cap)
		var holder := MarginContainer.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(holder)
		var val := UI.label("", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		val.custom_minimum_size.x = 44
		cell.add_child(val)
		grid.add_child(cell)
		stat_meters[st[1]] = [holder, val]
	return p


func _depth_panel() -> PanelContainer:
	var p := UI.panel(Color(0.3, 0.5, 0.8, 0.7), 0.0, 10)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 12)
	p.add_child(drow)
	var left := UI.button("◀", func(): _set_depth(depth - 1), 64)
	left.custom_minimum_size.x = 64
	drow.add_child(left)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 2)
	drow.add_child(mid)
	depth_label = UI.glow_label("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4)
	mid.add_child(depth_label)
	depth_desc = UI.wrap_label("", 17, Balance.C_TEXT_DIM)
	depth_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(depth_desc)
	var right := UI.button("▶", func(): _set_depth(depth + 1), 64)
	right.custom_minimum_size.x = 64
	drow.add_child(right)
	return p


func _select(id: String) -> void:
	selected = id
	var d: Dictionary = Balance.CHARACTERS[id]
	char_name.text = d.name
	char_desc.text = d.desc
	for c in start_row.get_children():
		c.queue_free()
	var start_cap := UI.label("STARTS WITH", 13, Balance.C_TEXT_DIM)
	start_cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_cap.size_flags_vertical = Control.SIZE_FILL
	start_row.add_child(start_cap)
	start_row.add_child(ItemIcon.new("weapon", d.start, 1, false, 34.0))
	var wl := UI.label(Balance.WEAPONS[d.start].name, 18, Balance.C_WEAPON)
	wl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wl.size_flags_vertical = Control.SIZE_FILL
	start_row.add_child(wl)
	for st in STATS:
		var key: String = st[1]
		var top := 0.0
		for cid in Balance.CHARACTERS:
			top = maxf(top, Balance.CHARACTERS[cid].get(key, 0.0))
		var v: float = d.get(key, 0.0)
		var holder: Control = stat_meters[key][0]
		for c in holder.get_children():
			c.queue_free()
		holder.add_child(UI.meter(v / top if top > 0.0 else 0.0, Balance.C_PLAYER, 6.0))
		stat_meters[key][1].text = ("%d%%" % roundi(v * 100.0)) if key == "crit" else str(int(v))
	for k in char_cards:
		var on: bool = k == id
		var sb := UI.box(Balance.C_PLAYER, 0.14, 12.0) if on else UI.box(Color(0.3, 0.4, 0.6, 0.6), 0.0)
		for state in ["normal", "hover", "pressed"]:
			char_cards[k].add_theme_stylebox_override(state, sb)
	var best := Save.best(id)
	best_label.text = "" if best.is_empty() else "BEST  ·  DEPTH %d  ·  %s%s" % [best.depth, UI.fmt_time(best.time), "  ·  CLEARED" if best.won else ""]


func _set_depth(d: int) -> void:
	depth = clampi(d, 0, Save.depth_unlocked())
	depth_label.text = "DEPTH %d" % depth
	var lines: PackedStringArray = []
	for i in range(1, depth + 1):
		lines.append(Balance.DEPTHS[i].desc)
	if lines.is_empty():
		depth_desc.text = "Base game. Win to unlock Depth 1." if Save.depth_unlocked() == 0 else "Base game."
	else:
		depth_desc.text = " ".join(lines)


# ------------------------------------------------------------------ pop-ups

func _show_modal(m: Modal) -> void:
	if modal:
		modal.queue_free()
	modal = m
	if m.get_parent() == null:
		add_child(m)
	m.closed.connect(func():
		if modal == m:
			modal = null)


func _open_history() -> void:
	_show_modal(HistoryUI.open(self))


func _open_settings() -> void:
	var m := Modal.new("SETTINGS")
	_show_modal(m)
	_setting_toggle(m.body, "Sound effects", "sfx", 0.8, true)
	_setting_toggle(m.body, "Music", "music", 0.7, true)
	_setting_toggle(m.body, "Vibration", "vibration", true)
	_setting_toggle(m.body, "Screen shake", "shake", true)
	_setting_toggle(m.body, "Low graphics (faster)", "low_quality", false)
	_setting_toggle(m.body, "Show FPS", "show_fps", false)
	var done := UI.button("DONE", m.close, 64, true)
	done.add_theme_font_size_override("font_size", 24)
	m.body.add_child(_spacer(4))
	m.body.add_child(done)


## One settings row: name on the left, ON/OFF switch on the right.
func _setting_toggle(into: Control, text: String, key: String, default: Variant, is_volume := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := UI.label(text, 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	row.add_child(l)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_font_override("font", UI.wide_font(3))
	row.add_child(b)
	var refresh := func():
		var v = Save.get_setting(key, default)
		var on: bool = v > 0.0 if is_volume else v
		b.text = "ON" if on else "OFF"
		b.theme_type_variation = UI.PRIMARY if on else ""
	refresh.call()
	b.pressed.connect(func():
		var v = Save.get_setting(key, default)
		if is_volume:
			Save.set_setting(key, 0.0 if v > 0.0 else default)
			Sfx.apply_volume()
		else:
			Save.set_setting(key, not v)
			if key == "low_quality":
				Shapes.low_quality = not v
				Shapes._mesh_cache.clear()
		Sfx.play("click")
		refresh.call())
	into.add_child(row)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if modal:
			modal.close()
		else:
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if modal and event.is_action_pressed("ui_cancel"):
		modal.close()


func _play() -> void:
	Save.run_config = {"character": selected, "depth": depth}
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _process(delta: float) -> void:
	t += delta
	var h := size.y + 100.0
	for f in floaters:
		f[0] += f[1] * delta
		f[4] += f[5] * delta
		if f[0].y < -60.0:
			f[0].y = h
			f[0].x = randf() * size.x
	bg.queue_redraw()
	for k in char_cards:
		char_cards[k].get_child(0).queue_redraw()


func _draw_bg() -> void:
	for f in floaters:
		Shapes.draw_neon_poly(bg, Transform2D(0.0, f[0]) * Shapes.points(f[2], f[3], f[4]), Color(f[6], 0.3), 2.0)
