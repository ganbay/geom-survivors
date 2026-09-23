class_name UI
extends RefCounted
## Shared neon UI theme and small widget factories.
## Custom font: drop a file at res://assets/font.ttf (or .otf) and it is used everywhere.

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	for path in ["res://assets/font.ttf", "res://assets/font.otf"]:
		if ResourceLoader.exists(path):
			t.default_font = load(path)
			break
	t.default_font_size = 26
	t.set_color("font_color", "Label", Balance.C_TEXT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := box(Balance.C_PLAYER, 0.08)
		match state:
			"hover":
				sb.bg_color = Color(Balance.C_PLAYER, 0.16)
			"pressed":
				sb.bg_color = Color(Balance.C_PLAYER, 0.28)
			"focus":
				sb.draw_center = false
			"disabled":
				sb.border_color = Color(Balance.C_TEXT_DIM, 0.4)
				sb.bg_color = Color(0, 0, 0, 0.3)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", Balance.C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Balance.C_TEXT_DIM)
	t.set_font_size("font_size", "Button", 28)
	t.set_stylebox("panel", "PanelContainer", box(Color(0.3, 0.5, 0.8), 0.9, Color(0.03, 0.035, 0.08)))
	_theme = t
	return t


static func box(border: Color, bg_alpha: float, bg := Color(-1, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(border, bg_alpha) if bg.r < 0.0 else Color(bg, bg_alpha)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	sb.anti_aliasing = false
	return sb


static func label(text: String, size := 26, color := Balance.C_TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, size := 22, color := Balance.C_TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	return l


static func button(text: String, on_press: Callable, min_h := 72.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("click")
		on_press.call())
	return b


## Colors for build hint lines by their leading symbol.
static func hint_color(h: String) -> Color:
	if h.begins_with("★") or h.begins_with("✦"):
		return Balance.C_GOLD
	if h.begins_with("✓"):
		return Balance.C_XP
	if h.begins_with("✗"):
		return Color(1.0, 0.45, 0.4)
	return Balance.C_TEXT_DIM


static func fmt_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]


## Full-screen dim layer that blocks input to the game below.
static func dim(alpha := 0.75) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.01, 0.01, 0.03, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


## Centered column with side margins that adapts to the screen width.
static func column(parent: Control, sep := 16, margin := 28) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, margin)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_bottom", 40)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	return v


static func tag_chip(tag: String) -> Label:
	var c: Color = Balance.TAG_COLORS.get(tag, Balance.C_TEXT)
	var l := label(tag, 18, c)
	var sb := box(c, 0.12)
	sb.set_content_margin_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	l.add_theme_stylebox_override("normal", sb)
	return l
