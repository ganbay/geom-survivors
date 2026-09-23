class_name HistoryUI
extends RefCounted
## Run history pop-up: one compact row per run, tap a row for the full report.

const TAP_SLOP := 14.0  # finger travel (px) that still counts as a tap, not a scroll

var modal: Modal
var runs: Array


static func open(parent: Control) -> Modal:
	var h := HistoryUI.new()
	h.runs = Save.history()
	h.modal = Modal.new("RUN HISTORY", true)
	parent.add_child(h.modal)
	# the modal holds the only reference to this helper, via its button/row callbacks
	h.modal.set_meta("history", h)
	h.show_list()
	return h.modal


static func result_color(r: String) -> Color:
	match r:
		"win":
			return Balance.C_GOLD
		"dead":
			return Balance.C_DANGER
	return Balance.C_TEXT_DIM


static func result_text(r: String) -> String:
	match r:
		"win":
			return "VICTORY"
		"dead":
			return "SHATTERED"
	return "ABANDONED"


## "just now", "12m ago", "3h ago", "yesterday", else a local date like "Sep 4, 14:05".
static func when_text(ts: int) -> String:
	var ago := int(Time.get_unix_time_from_system()) - ts
	if ago < 60:
		return "just now"
	if ago < 3600:
		return "%dm ago" % (ago / 60)
	if ago < 86400:
		return "%dh ago" % (ago / 3600)
	if ago < 172800:
		return "yesterday"
	return date_text(ts)


static func date_text(ts: int) -> String:
	var local := ts + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %02d:%02d" % [MONTHS[d.month - 1], d.day, d.hour, d.minute]


# ------------------------------------------------------------------ list

func show_list() -> void:
	modal.clear_body()
	modal.title_label.text = "RUN HISTORY"
	var body := modal.body
	if runs.is_empty():
		var empty := UI.wrap_label("No runs yet.\nFinished runs show up here with their build and damage breakdown.", 22, Balance.C_TEXT_DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(empty)
		return
	var wins := 0
	var best_time := 0.0
	var kills := 0
	for r in runs:
		wins += 1 if r.result == "win" else 0
		best_time = maxf(best_time, r.time)
		kills += int(r.kills)
	body.add_child(UI.stat_row([["RUNS", str(runs.size())], ["WINS", str(wins), Balance.C_GOLD],
			["LONGEST", UI.fmt_time(best_time)], ["KILLS", UI.fmt_num(kills)]], 8))
	body.add_child(UI.header("RECENT"))
	for i in runs.size():
		body.add_child(_row(i))


func _row(i: int) -> PanelContainer:
	var r: Dictionary = runs[i]
	var col := result_color(r.result)
	var p := PanelContainer.new()
	var normal := UI.box(Color(col, 0.45), 0.03)
	normal.border_width_left = 5
	normal.set_content_margin_all(12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(col.darkened(0.6), 0.95)
	p.add_theme_stylebox_override("panel", normal)
	p.mouse_filter = Control.MOUSE_FILTER_PASS  # let drags through to the scroll area
	var down := [Vector2.ZERO, false]
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				down[0] = e.global_position
				down[1] = true
				p.add_theme_stylebox_override("panel", pressed)
			else:
				p.add_theme_stylebox_override("panel", normal)
				if down[1] and e.global_position.distance_to(down[0]) < TAP_SLOP:
					Sfx.play("click")
					show_detail(i)
				down[1] = false
		elif e is InputEventMouseMotion and down[1] and e.global_position.distance_to(down[0]) >= TAP_SLOP:
			down[1] = false
			p.add_theme_stylebox_override("panel", normal))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ch: Dictionary = Balance.CHARACTERS.get(r.character, Balance.CHARACTERS.triangle)
	h.add_child(UI.shape_icon(ch.sides, 52.0, col))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var name_l := UI.label("%s  ·  D%d" % [ch.name, r.depth], 22, Color.WHITE)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	top.add_child(UI.label(result_text(r.result), 16, col))
	var sub := HBoxContainer.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sub)
	var stats := UI.label("%s  ·  %s KILLS  ·  LV %d" % [UI.fmt_time(r.time), UI.fmt_num(r.kills), r.level], 18, Balance.C_TEXT)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_child(stats)
	sub.add_child(UI.label(when_text(r.ts), 16, Balance.C_TEXT_DIM))
	# weapon strip: the build at a glance
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 4)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for w in r.weapons:
		icons.add_child(ItemIcon.new("weapon", w.id, w.level, w.evo != "", 28.0))
	v.add_child(icons)
	return p


# ------------------------------------------------------------------ detail

func show_detail(i: int) -> void:
	var r: Dictionary = runs[i]
	modal.clear_body()
	modal.title_label.text = "RUN REPORT"
	var back := UI.button("◀ BACK", show_list, 56)
	back.add_theme_font_size_override("font_size", 20)
	back.custom_minimum_size.x = 120
	modal.header_extra.add_child(back)
	build_report(modal.body, r)


## Full report of one run. Also usable for any history-shaped Dictionary.
static func build_report(body: VBoxContainer, r: Dictionary) -> void:
	var col := result_color(r.result)
	var ch: Dictionary = Balance.CHARACTERS.get(r.character, Balance.CHARACTERS.triangle)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	body.add_child(head)
	head.add_child(UI.shape_icon(ch.sides, 76.0, col, 0.2))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(UI.glow_label(result_text(r.result), 34, col, HORIZONTAL_ALIGNMENT_LEFT, 3))
	hv.add_child(UI.label("%s  ·  DEPTH %d" % [ch.name, r.depth], 20, Color.WHITE))
	hv.add_child(UI.label(date_text(r.ts), 16, Balance.C_TEXT_DIM))

	var total := 0.0
	for w in r.weapons:
		total += w.damage
	for src in r.other_damage:
		total += r.other_damage[src]
	body.add_child(UI.stat_row([["SURVIVED", UI.fmt_time(r.time)], ["KILLS", UI.fmt_num(r.kills)], ["LEVEL", str(r.level)]], 8))
	body.add_child(UI.stat_row([["DAMAGE", UI.fmt_num(total), Balance.C_PLAYER], ["DPS", UI.fmt_num(total / maxf(r.time, 1.0)), Balance.C_PLAYER],
			["TAKEN", UI.fmt_num(r.damage_taken), Balance.C_HEAL]], 8))

	body.add_child(UI.header("WEAPONS  ·  DAMAGE DEALT"))
	var top_dmg := 1.0
	for w in r.weapons:
		top_dmg = maxf(top_dmg, w.damage)
	for src in r.other_damage:
		top_dmg = maxf(top_dmg, r.other_damage[src])
	var sorted: Array = r.weapons.duplicate()
	sorted.sort_custom(func(a, b): return a.damage > b.damage)
	for w in sorted:
		body.add_child(_damage_row(ItemIcon.new("weapon", w.id, w.level, w.evo != "", 44.0),
				"%s  LV%d" % [w.name, w.level], w.damage, total, top_dmg, r.time,
				Balance.C_GOLD if w.evo != "" else Balance.C_WEAPON))
	for src in r.other_damage:
		var d: float = r.other_damage[src]
		var tag := "CHAIN" if src == "Arc" else ("FRACTURE" if src == "Fracture" else "")
		var c: Color = Balance.TAG_COLORS.get(tag, Balance.C_TEXT_DIM)
		var dot := UI.shape_icon(0, 44.0, c)
		body.add_child(_damage_row(dot, src + "  (resonance)" if tag != "" else src, d, total, top_dmg, r.time, c))

	if not r.passives.is_empty():
		body.add_child(UI.header("PASSIVES"))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 16)
		flow.add_theme_constant_override("v_separation", 8)
		for id in r.passives:
			var item := HBoxContainer.new()
			item.add_child(ItemIcon.new("passive", id, r.passives[id], false, 36.0))
			item.add_child(UI.label("%s %d/%d" % [Balance.PASSIVES[id].name, r.passives[id], Balance.PASSIVES[id].max], 20))
			flow.add_child(item)
		body.add_child(flow)
	if not r.overclocks.is_empty():
		body.add_child(UI.header("OVERCLOCKS", Color(1.0, 0.55, 0.25)))
		for id in r.overclocks:
			var oc: Dictionary = Balance.OVERCLOCKS[id]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(ItemIcon.new("overclock", id, 1, false, 36.0))
			var l := UI.wrap_label("%s  ·  %s %s" % [oc.name, oc.desc, oc.cost], 18, Color(1.0, 0.7, 0.45))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			body.add_child(row)


static func _damage_row(icon: Control, title: String, dmg: float, total: float, top: float, time: float, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	row.add_child(v)
	var line := HBoxContainer.new()
	v.add_child(line)
	var t := UI.label(title, 20, Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	line.add_child(t)
	var pct := dmg / maxf(total, 1.0) * 100.0
	line.add_child(UI.label("%s  %d%%" % [UI.fmt_num(dmg), roundi(pct)], 18, color))
	v.add_child(UI.meter(dmg / top, color, 5.0))
	v.add_child(UI.label("%s DPS" % UI.fmt_num(dmg / maxf(time, 1.0)), 14, Balance.C_TEXT_DIM))
	return row
