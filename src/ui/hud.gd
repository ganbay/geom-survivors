class_name Hud
extends CanvasLayer
## In-run HUD: XP bar, timer, level, kills, build strip, boss bar, banners.

var game: Game
var root: Control
var bars: Control
var timer_label: Label
var level_label: Label
var kills_label: Label
var fps_label: Label
var banner_label: Label
var boss_label: Label
var hurt_rect: ColorRect
var hint_label: Label
var banner_t := 0.0
var hurt_t := 0.0


func setup(g: Game) -> void:
	game = g
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()

	# the damage flash covers the whole screen; everything else stays inside the safe area
	hurt_rect = ColorRect.new()
	hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_rect.color = Color(1, 0.1, 0.15, 0.0)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hurt_rect)
	UI.fit_safe_area(root)
	add_child(root)

	bars = Control.new()
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(_draw_bars)
	root.add_child(bars)

	level_label = UI.label("LV 1", 26)
	level_label.position = Vector2(16, 20)
	root.add_child(level_label)

	timer_label = UI.label("00:00", 40, Balance.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.position.y = 16
	timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(timer_label)

	kills_label = UI.label("0", 22, Balance.C_TEXT_DIM)
	kills_label.position = Vector2(16, 52)
	root.add_child(kills_label)

	fps_label = UI.label("", 18, Balance.C_TEXT_DIM)
	fps_label.position = Vector2(16, 80)
	fps_label.visible = Save.get_setting("show_fps", false)
	root.add_child(fps_label)

	var pause := UI.button("II", func(): game.open_pause(), 64)
	pause.custom_minimum_size = Vector2(64, 64)
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.position = Vector2(-80, 18)
	pause.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(pause)

	boss_label = UI.label("", 22, Balance.C_DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	boss_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_label.position.y = 150
	root.add_child(boss_label)

	banner_label = UI.label("", 40, Balance.C_DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	banner_label.set_anchors_preset(Control.PRESET_CENTER)
	banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_label.position.y = -260
	banner_label.modulate.a = 0.0
	root.add_child(banner_label)

	hint_label = UI.label("DRAG ANYWHERE TO MOVE", 28, Color(Balance.C_TEXT, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label.position.y = -220
	root.add_child(hint_label)


func banner(text: String, color: Color, dur: float) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	banner_t = dur
	banner_label.modulate.a = 1.0


func flash_damage() -> void:
	hurt_t = 0.25


func update(delta: float) -> void:
	timer_label.text = UI.fmt_time(game.time)
	level_label.text = "LV %d" % game.level
	kills_label.text = "%d KILLS" % game.kills
	if fps_label.visible:
		fps_label.text = "%d FPS  %d EN  CAP %d" % [Engine.get_frames_per_second(), game.enemies.n, game.director.cap]
	if banner_t > 0.0:
		banner_t -= delta
		banner_label.modulate.a = clampf(banner_t / 0.4, 0.0, 1.0)
	if hurt_t > 0.0:
		hurt_t -= delta
	hurt_rect.color.a = maxf(hurt_t, 0.0) * 0.5
	if hint_label.visible and (not game.joystick.idle_hint or game.time > 6.0):
		hint_label.visible = false
	var bi := game.enemies.boss_idx
	boss_label.visible = bi >= 0
	if bi >= 0:
		boss_label.text = Director.BOSS_NAMES.get(game.enemies.type_ids[game.enemies.typ[bi]], "BOSS")
	bars.queue_redraw()


func _draw_bars() -> void:
	var w := bars.size.x
	# XP bar
	var frac := float(game.xp) / float(game.xp_next)
	bars.draw_rect(Rect2(0, 0, w, 10), Color(0.05, 0.12, 0.08))
	bars.draw_rect(Rect2(0, 0, w * frac, 10), Balance.C_XP)
	bars.draw_rect(Rect2(0, 10, w * frac, 2), Color(Balance.C_XP, 0.35))
	# build strip: weapons then passives, shapes gain sides with level
	var x := 16.0
	var y := 118.0
	for wpn in game.build.weapons:
		var col := ItemIcon.icon_color("weapon", wpn.evolved)
		ItemIcon.draw_icon(bars, "weapon", wpn.id, wpn.level, wpn.evolved, Vector2(x + 15, y), 14.0, col, 2.0)
		x += 36.0
	x += 10.0
	for id in game.build.passives:
		var lv: int = game.build.passives[id]
		var col := ItemIcon.icon_color("passive", false)
		ItemIcon.draw_icon(bars, "passive", id, lv, false, Vector2(x + 13, y), 12.0, col, 2.0)
		for k in lv:
			bars.draw_rect(Rect2(x + 3 + k * 4.5, y + 17, 3, 3), col)
		x += 32.0
	# boss bar
	var bi := game.enemies.boss_idx
	if bi >= 0:
		var bw := w * 0.7
		var bx := (w - bw) / 2.0
		var f := game.enemies.hp[bi] / game.enemies.mhp[bi]
		bars.draw_rect(Rect2(bx, 184, bw, 12), Color(0.2, 0.03, 0.06))
		bars.draw_rect(Rect2(bx, 184, bw * clampf(f, 0.0, 1.0), 12), Balance.C_DANGER)
		bars.draw_rect(Rect2(bx, 184, bw, 12), Color(Balance.C_DANGER, 0.8), false, 2.0)
