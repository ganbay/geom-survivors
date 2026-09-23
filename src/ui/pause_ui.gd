class_name PauseUI
extends CanvasLayer
## Pause screen: full build overview so players can plan their next picks.

var game: Game
var root: Control
var body: VBoxContainer


func setup(g: Game) -> void:
	game = g
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	root.add_child(UI.dim(0.88))
	var col := UI.column(root, 14, 28)
	col.add_child(UI.label("PAUSED", 46, Balance.C_PLAYER, HORIZONTAL_ALIGNMENT_CENTER))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	col.add_child(body)
	col.add_child(UI.button("RESUME", func(): game.close_pause()))
	col.add_child(UI.button("QUIT RUN", func(): game.quit_to_menu(), 60))
	visible = false


func open() -> void:
	for c in body.get_children():
		c.queue_free()
	build_summary(game, body)
	visible = true


static func build_summary(game: Game, into: VBoxContainer) -> void:
	var b := game.build
	into.add_child(UI.label("WEAPONS   %d/%d" % [b.weapons.size(), Balance.MAX_WEAPONS], 22, Balance.C_TEXT_DIM))
	for w in b.weapons:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(ItemIcon.new("weapon", w.id, w.level, w.evolved, 44.0))
		var dealt: float = game.damage_by.get(w.display_name(), 0.0)
		var dps := dealt / maxf(game.time, 1.0)
		var l := UI.label("%s  LV%d" % [w.display_name(), w.level], 24, Balance.C_GOLD if w.evolved else Color.WHITE)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.label("%d DPS" % dps, 20, Balance.C_TEXT_DIM))
		into.add_child(row)
		if not w.evolved:
			for pid in w.data.evolutions:
				var h := b.evolution_status(w.id, pid)
				var l2 := UI.label("      " + h, 17, UI.hint_color(h))
				into.add_child(l2)
	into.add_child(UI.label("PASSIVES   %d/%d" % [b.passives.size(), Balance.MAX_PASSIVES], 22, Balance.C_TEXT_DIM))
	var prow := HFlowContainer.new()
	prow.add_theme_constant_override("h_separation", 16)
	for id in b.passives:
		var item := HBoxContainer.new()
		item.add_child(ItemIcon.new("passive", id, b.passives[id], false, 36.0))
		item.add_child(UI.label("%s %d/%d" % [Balance.PASSIVES[id].name, b.passives[id], Balance.PASSIVES[id].max], 22))
		prow.add_child(item)
	into.add_child(prow)
	if not b.overclocks.is_empty():
		var names: PackedStringArray = []
		for id in b.overclocks:
			names.append(Balance.OVERCLOCKS[id].name)
		into.add_child(UI.wrap_label("OVERCLOCKS: " + ", ".join(names), 20, Color(1.0, 0.55, 0.25)))
	into.add_child(UI.label("RESONANCE", 22, Balance.C_TEXT_DIM))
	for tag in Balance.TAG_COLORS:
		var c: int = b.tag_counts.get(tag, 0)
		if c == 0:
			continue
		var t := b.tier(tag)
		var th: Array = Balance.RESONANCE_THRESHOLDS
		var line := "%s %d" % [tag, c]
		for k in th.size():
			var mark := "✓" if t > k else "%d:" % th[k]
			line += "\n  %s %s" % [mark, Balance.RESONANCE[tag][k]]
		into.add_child(UI.wrap_label(line, 19, Balance.TAG_COLORS[tag] if t > 0 else Balance.C_TEXT_DIM))
