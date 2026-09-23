class_name UI
extends RefCounted
## Shared neon UI theme and small widget factories.
## Panels and buttons are chamfered (two cut corners) with a soft neon glow.
## Custom font: drop a file at res://assets/font.ttf (or .otf) and it is used everywhere.

const C_PANEL := Color(0.035, 0.045, 0.085)
const CHAMFER := 14
const PRIMARY := "PrimaryButton"

static var _theme: Theme
static var _wide: FontVariation
## Test hook: when non-zero, used instead of the device safe area (see tests/shot_ui.gd).
static var force_insets := Vector4.ZERO


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

	# default (secondary) buttons: dark glass with a cyan outline
	var c := Balance.C_PLAYER
	var normal := box(Color(c, 0.5), 0.0)
	var hover := box(c, 0.1, 6.0)
	var pressed := box(c, 0.28, 12.0)
	var disabled := box(Color(Balance.C_TEXT_DIM, 0.35), 0.0)
	disabled.bg_color = Color(C_PANEL, 0.6)
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["focus", StyleBoxEmpty.new()]]:
		t.set_stylebox(pair[0], "Button", pair[1])
	t.set_color("font_color", "Button", Balance.C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(Balance.C_TEXT_DIM, 0.6))
	t.set_font_size("font_size", "Button", 28)

	# primary buttons: solid neon fill, dark text, strong glow
	t.set_type_variation(PRIMARY, "Button")
	var p_normal := box(c, 1.0, 10.0)
	p_normal.bg_color = Color(c, 0.9)
	var p_hover := box(Color(0.7, 1.0, 1.0), 1.0, 16.0)
	p_hover.bg_color = Color(0.55, 1.0, 1.0)
	var p_pressed := box(c, 1.0, 22.0)
	p_pressed.bg_color = Color(0.15, 0.7, 0.8)
	for pair in [["normal", p_normal], ["hover", p_hover], ["pressed", p_pressed], ["focus", StyleBoxEmpty.new()]]:
		t.set_stylebox(pair[0], PRIMARY, pair[1])
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(k, PRIMARY, Balance.C_BG)

	t.set_stylebox("panel", "PanelContainer", box(Color(0.3, 0.5, 0.8), 0.0))
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(c, 0.35)
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	_theme = t
	return t


## Chamfered neon panel. `bg_alpha` tints the dark glass with the border color,
## `glow` adds an outer halo of that size.
static func box(border: Color, bg_alpha: float, glow := 0.0, bg := C_PANEL) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg.lerp(Color(border, 1.0), clampf(bg_alpha, 0.0, 1.0) * 0.6), 0.94)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = CHAMFER
	sb.corner_radius_bottom_right = CHAMFER
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_detail = 1  # straight cuts instead of rounded corners
	sb.set_content_margin_all(14)
	sb.anti_aliasing = true
	if glow > 0.0:
		sb.shadow_color = Color(border, 0.28)
		sb.shadow_size = int(glow)
	return sb


static func panel(accent := Color(0.3, 0.5, 0.8), glow := 0.0, margin := 18) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(accent, 0.03, glow)
	sb.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", sb)
	return p


## Letter-spaced version of the UI font, for headers and titles.
static func wide_font(spacing := 4) -> FontVariation:
	if not _wide:
		_wide = FontVariation.new()
		_wide.base_font = theme().default_font if theme().default_font else ThemeDB.fallback_font
	var f := _wide.duplicate() as FontVariation
	f.spacing_glyph = spacing
	return f


static func label(text: String, size := 26, color := Balance.C_TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Label with a neon halo, for titles.
static func glow_label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, spacing := 0) -> Label:
	var l := label(text, size, color, align)
	l.add_theme_color_override("font_shadow_color", Color(color, 0.22))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", maxi(6, size / 5))
	if spacing > 0:
		l.add_theme_font_override("font", wide_font(spacing))
	return l


static func wrap_label(text: String, size := 22, color := Balance.C_TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	return l


## Small letter-spaced section header followed by a thin fading rule.
static func header(text: String, color := Balance.C_TEXT_DIM, size := 18) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, color)
	l.add_theme_font_override("font", wide_font(3))
	h.add_child(l)
	var line := Control.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y / 2.0
		line.draw_line(Vector2(0, y), Vector2(line.size.x, y), Color(color, 0.35), 1.0)
		line.draw_rect(Rect2(0, y - 2, 4, 4), Color(color, 0.8)))
	h.add_child(line)
	return h


static func button(text: String, on_press: Callable, min_h := 72.0, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.theme_type_variation = PRIMARY
		b.add_theme_font_override("font", wide_font(4))
	b.pressed.connect(func():
		Sfx.play("click")
		on_press.call())
	return b


## Stat tile: small dim caption over a big value.
static func stat_tile(caption: String, value: String, color := Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(color, 0.35), 0.04)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var cap := label(caption, 14, Balance.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	cap.add_theme_font_override("font", wide_font(2))
	v.add_child(cap)
	v.add_child(label(value, 28, color, HORIZONTAL_ALIGNMENT_CENTER))
	return p


## Row of stat tiles from [[caption, value, color?], ...].
static func stat_row(stats: Array, sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for st in stats:
		h.add_child(stat_tile(st[0], st[1], st[2] if st.size() > 2 else Color.WHITE))
	return h


## Thin horizontal meter (0..1), used for stats and damage shares.
static func meter(frac: float, color: Color, h := 6.0) -> Control:
	var m := Control.new()
	m.custom_minimum_size.y = h
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.draw.connect(func():
		m.draw_rect(Rect2(Vector2.ZERO, m.size), Color(color, 0.12))
		m.draw_rect(Rect2(0, 0, m.size.x * clampf(frac, 0.0, 1.0), m.size.y), color))
	return m


## Outline of a player shape (sides 0 = circle), drawn at the control's center.
static func shape_icon(sides: int, size: float, color: Color, fill := 0.15) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var base := PI / 4.0 if sides == 4 else -PI / 2.0
		Shapes.draw_neon_poly(c, Transform2D(0.0, c.size / 2.0) * Shapes.points(sides, size * 0.36, base), color, 2.5, fill))
	return c


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


## Compact big-number format: 950, 12.4K, 3.1M.
static func fmt_num(v: float) -> String:
	if v >= 1e6:
		return "%.1fM" % (v / 1e6)
	if v >= 1e4:
		return "%dK" % int(v / 1e3)
	if v >= 1e3:
		return "%.1fK" % (v / 1e3)
	return "%d" % int(v)


## Screen insets (left, top, right, bottom) in canvas units that keep content clear of
## notches, camera holes and rounded corners. Zero on desktop.
static func safe_insets(vp: Viewport) -> Vector4:
	if force_insets != Vector4.ZERO:
		return force_insets
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0.0 or safe.size.x <= 0.0:
		return Vector4.ZERO
	var k := vp.get_visible_rect().size.x / win.x
	return Vector4(maxf(safe.position.x, 0.0), maxf(safe.position.y, 0.0),
			maxf(win.x - safe.end.x, 0.0), maxf(win.y - safe.end.y, 0.0)) * k


## Shrinks a full-rect control to the safe area, and keeps it there if the screen changes
## (e.g. a foldable opening). Backgrounds should stay outside it so they still reach the edges.
static func fit_safe_area(c: Control) -> void:
	var apply := func():
		if not c.is_inside_tree():
			return
		var ins := safe_insets(c.get_viewport())
		c.offset_left = ins.x
		c.offset_top = ins.y
		c.offset_right = -ins.z
		c.offset_bottom = -ins.w
	c.ready.connect(func():
		apply.call()
		c.get_viewport().size_changed.connect(apply))


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
	fit_safe_area(m)
	parent.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	return v


## Vertical scroll area that takes the column's leftover height, so long content
## never pushes the buttons below it off screen. Returns the inner VBox to fill.
static func scroll_body(parent: Control, sep := 8) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", sep)
	sc.add_child(v)
	return v


static func tag_chip(tag: String) -> Label:
	var c: Color = Balance.TAG_COLORS.get(tag, Balance.C_TEXT)
	var l := label(tag, 16, c)
	var sb := box(c, 0.12)
	sb.corner_radius_top_left = 6
	sb.corner_radius_bottom_right = 6
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	l.add_theme_stylebox_override("normal", sb)
	return l
