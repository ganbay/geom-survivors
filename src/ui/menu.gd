extends Control
## Main menu: pick a shape, pick a depth, play. Also settings.

var selected := "triangle"
var depth := 0
var char_cards := {}
var char_desc: Label
var depth_label: Label
var depth_desc: Label
var best_label: Label
var settings_box: VBoxContainer
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
		floaters.append([Vector2(randf() * 720.0, randf() * 1400.0), Vector2(randf_range(-15, 15), randf_range(-25, -8)),
				[0, 3, 4, 5, 6, -5].pick_random(), randf_range(10.0, 34.0), randf() * TAU, randf_range(-0.6, 0.6),
				[Color(1.0, 0.25, 0.75), Color(1.0, 0.55, 0.15), Color(0.75, 0.4, 1.0), Balance.C_PLAYER].pick_random()])

	var col := UI.column(self, 18, 32)
	var title := UI.label("GEOM", 96, Balance.C_PLAYER, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(title)
	col.add_child(UI.label("SURVIVORS", 52, Color(1.0, 0.3, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_spacer(24))

	col.add_child(UI.label("CHOOSE YOUR SHAPE", 22, Balance.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	for id in Balance.CHARACTERS:
		var card := _char_card(id)
		row.add_child(card)
		char_cards[id] = card
	char_desc = UI.wrap_label("", 22)
	char_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_desc.custom_minimum_size.y = 90
	col.add_child(char_desc)

	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 12)
	col.add_child(drow)
	var left := UI.button("◀", func(): _set_depth(depth - 1), 64)
	left.custom_minimum_size.x = 80
	drow.add_child(left)
	depth_label = UI.label("", 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	depth_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depth_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drow.add_child(depth_label)
	var right := UI.button("▶", func(): _set_depth(depth + 1), 64)
	right.custom_minimum_size.x = 80
	drow.add_child(right)
	depth_desc = UI.wrap_label("", 20, Balance.C_TEXT_DIM)
	depth_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	depth_desc.custom_minimum_size.y = 60
	col.add_child(depth_desc)

	var play := UI.button("PLAY", _play, 96)
	play.add_theme_font_size_override("font_size", 40)
	col.add_child(play)
	best_label = UI.label("", 20, Balance.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(best_label)

	col.add_child(UI.button("SETTINGS", func(): settings_box.visible = not settings_box.visible, 60))
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 8)
	settings_box.visible = false
	col.add_child(settings_box)
	_setting_toggle("Sound effects", "sfx", 0.8, true)
	_setting_toggle("Music", "music", 0.7, true)
	_setting_toggle("Vibration", "vibration", true)
	_setting_toggle("Screen shake", "shake", true)
	_setting_toggle("Low graphics (faster)", "low_quality", false)
	_setting_toggle("Show FPS", "show_fps", false)

	_select(selected)
	_set_depth(depth)
	Sfx.play_music("menu")


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _char_card(id: String) -> Control:
	var d: Dictionary = Balance.CHARACTERS[id]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 170)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		Sfx.play("click")
		_select(id))
	var icon := Control.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func():
		var c := icon.size / 2.0 - Vector2(0, 16)
		var col := Balance.C_PLAYER if selected == id else Balance.C_TEXT_DIM
		var rot := t * (0.8 if selected == id else 0.0)
		var base := PI / 4.0 if d.sides == 4 else -PI / 2.0
		Shapes.draw_neon_poly(icon, Transform2D(0.0, c) * Shapes.points(d.sides, 38.0, base + rot), col, 3.0, 0.15))
	b.add_child(icon)
	var l := UI.label(d.name, 20, Balance.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.position.y = -36
	b.add_child(l)
	return b


func _select(id: String) -> void:
	selected = id
	var d: Dictionary = Balance.CHARACTERS[id]
	var weapon: String = Balance.WEAPONS[d.start].name
	char_desc.text = "%s\nHP %d · SPEED %d · STARTS WITH %s" % [d.desc, d.hp, d.speed, weapon.to_upper()]
	for k in char_cards:
		var sb := UI.box(Balance.C_PLAYER if k == id else Color(0.3, 0.4, 0.6), 0.14 if k == id else 0.04)
		char_cards[k].add_theme_stylebox_override("normal", sb)
		char_cards[k].add_theme_stylebox_override("hover", sb)
		char_cards[k].add_theme_stylebox_override("pressed", sb)
	var best := Save.best(id)
	best_label.text = "" if best.is_empty() else "BEST: DEPTH %d · %s%s" % [best.depth, UI.fmt_time(best.time), " · CLEARED" if best.won else ""]


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


func _setting_toggle(label: String, key: String, default: Variant, is_volume := false) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 56
	b.add_theme_font_size_override("font_size", 22)
	var refresh := func():
		var v = Save.get_setting(key, default)
		var on: bool = v > 0.0 if is_volume else v
		b.text = "%s: %s" % [label, "ON" if on else "OFF"]
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
	settings_box.add_child(b)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


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
	# grid
	var step := 64.0
	var off := fmod(t * 10.0, step)
	var lines := PackedVector2Array()
	var x := 0.0
	while x < size.x + step:
		lines.append(Vector2(x, 0))
		lines.append(Vector2(x, size.y))
		x += step
	var y := -off
	while y < size.y + step:
		lines.append(Vector2(0, y))
		lines.append(Vector2(size.x, y))
		y += step
	bg.draw_multiline(lines, Balance.C_GRID, 1.0)
	for f in floaters:
		Shapes.draw_neon_poly(bg, Transform2D(0.0, f[0]) * Shapes.points(f[2], f[3], f[4]), Color(f[6], 0.35), 2.0)
