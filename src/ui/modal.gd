class_name Modal
extends Control
## Pop-up window over the current screen: dim backdrop, chamfered panel, title bar with ✕.
## Tapping the backdrop or ✕ closes it. `tall` modals fill most of the screen and scroll.

signal closed

var body: VBoxContainer
var title_label: Label
var header_extra: HBoxContainer  # right side of the title bar, before ✕ (e.g. a BACK button)
var panel: PanelContainer
var _closing := false


func _init(title: String, tall := false, accent := Balance.C_PLAYER) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var backdrop := UI.dim(0.72)
	backdrop.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(backdrop)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 28)
	m.add_theme_constant_override("margin_top", 70 if tall else 40)
	m.add_theme_constant_override("margin_bottom", 70 if tall else 40)
	UI.fit_safe_area(m)
	add_child(m)
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(center)

	panel = UI.panel(accent, 18.0, 22)
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a = 0.99
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # taps inside never reach the backdrop
	if tall:
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	v.add_child(bar)
	title_label = UI.glow_label(title, 32, accent, HORIZONTAL_ALIGNMENT_LEFT, 4)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title_label)
	header_extra = HBoxContainer.new()
	bar.add_child(header_extra)
	var x := UI.button("✕", close, 56)
	x.custom_minimum_size.x = 56
	x.add_theme_font_size_override("font_size", 24)
	bar.add_child(x)
	v.add_child(UI.meter(1.0, Color(accent, 0.3), 1.0))

	if tall:
		body = UI.scroll_body(v, 10)
	else:
		body = VBoxContainer.new()
		body.add_theme_constant_override("separation", 10)
		v.add_child(body)


func _ready() -> void:
	# pop in: fade + slight grow from the center
	modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 1.0, 0.14)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18)
	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2.0)


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func clear_body() -> void:
	for c in body.get_children():
		c.queue_free()
	for c in header_extra.get_children():
		c.queue_free()
	var sc := body.get_parent() as ScrollContainer
	if sc:
		sc.scroll_vertical = 0
