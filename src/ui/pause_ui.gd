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
	col.add_child(UI.glow_label("PAUSED", 46, Balance.C_PLAYER, HORIZONTAL_ALIGNMENT_CENTER, 8))
	body = UI.scroll_body(col)
	col.add_child(UI.button("RESUME", func(): game.close_pause(), 80, true))
	col.add_child(UI.button("QUIT RUN", func(): game.quit_to_menu(), 60))
	visible = false


func open() -> void:
	for c in body.get_children():
		c.queue_free()
	build_summary(game, body)
	visible = true


static func build_summary(game: Game, into: VBoxContainer) -> void:
	var b := game.build
	into.add_child(UI.header("WEAPON"))
	for w in b.weapons:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(ItemIcon.new("weapon", w.id, w.level, w.evolved, 44.0))
		var dealt: float = game.damage_by.get(w.display_name(), 0.0)
		if w.evolved:
			dealt += game.damage_by.get(w.data.name, 0.0)
		var dps := dealt / maxf(game.time, 1.0)
		var l := UI.label("%s  LV%d" % [w.display_name(), w.level], 24, Balance.C_GOLD if w.evolved else Color.WHITE)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.label("%d DPS" % dps, 20, Balance.C_TEXT_DIM))
		into.add_child(row)
		_milestones(b, "weapon", w.id, w.level, Balance.WEAPON_MAX_LEVEL, into)
	into.add_child(UI.header("PASSIVES  %d/%d" % [b.passives.size(), Balance.MAX_PASSIVES]))
	for id in b.passives:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 10)
		item.add_child(ItemIcon.new("passive", id, b.passives[id], false, 36.0))
		item.add_child(UI.label("%s %d/%d" % [Balance.PASSIVES[id].name, b.passives[id], Balance.PASSIVE_MAX_LEVEL], 22))
		into.add_child(item)
		_milestones(b, "passive", id, b.passives[id], Balance.PASSIVE_MAX_LEVEL, into)
	if not b.overclocks.is_empty():
		var names: PackedStringArray = []
		for id in b.overclocks:
			names.append(Balance.OVERCLOCKS[id].name)
		into.add_child(UI.wrap_label("OVERCLOCKS: " + ", ".join(names), 20, Balance.C_OVERCLOCK))


## One line per milestone of an item: the option taken, or the level it unlocks at.
static func _milestones(b: Build, kind: String, id: String, level: int, max_level: int, into: VBoxContainer) -> void:
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 54)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	indent.add_child(flow)
	for l in range(1, max_level + 1):
		if Build.level_options(kind, id, l).is_empty():
			continue
		var taken := b.picked(kind, id, l)
		if l <= level and not taken.is_empty():
			flow.add_child(UI.label("✓ LV%d %s" % [l, taken.name], 17, Balance.C_GOLD if taken.has("evo") else Balance.C_XP))
		else:
			flow.add_child(UI.label("· LV%d choice" % l, 17, Balance.C_TEXT_DIM))
	into.add_child(indent)
