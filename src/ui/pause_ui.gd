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
	into.add_child(UI.header("WEAPONS  %d/%d" % [b.weapons.size(), Balance.MAX_WEAPONS]))
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
			# All evolution routes on one wrapping row under the weapon.
			var indent := MarginContainer.new()
			indent.add_theme_constant_override("margin_left", 54)
			var evo_row := HFlowContainer.new()
			evo_row.add_theme_constant_override("h_separation", 18)
			indent.add_child(evo_row)
			for pid in w.data.evolutions:
				var h := _short_evo(b, w.id, pid)
				evo_row.add_child(UI.label(h, 17, UI.hint_color(h)))
			into.add_child(indent)
	into.add_child(UI.header("PASSIVES  %d/%d" % [b.passives.size(), Balance.MAX_PASSIVES]))
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
	into.add_child(UI.header("RESONANCE"))
	var th: Array = Balance.RESONANCE_THRESHOLDS
	for tag in Balance.TAG_COLORS:
		var c: int = b.tag_counts.get(tag, 0)
		if c == 0:
			continue
		var t := b.tier(tag)
		# One line per tag: count, active tiers, and only the next unlock.
		var line := "%s %d %s" % [tag, c, "✓".repeat(t)]
		if t < th.size():
			line += "  next %d: %s" % [th[t], Balance.RESONANCE[tag][t]]
		into.add_child(UI.wrap_label(line, 18, Balance.TAG_COLORS[tag] if t > 0 else Balance.C_TEXT_DIM))


## Compact evolution hint: same leading symbol as Build.evolution_status, fewer words.
static func _short_evo(b: Build, weapon_id: String, pid: String) -> String:
	var evo_name: String = Balance.WEAPONS[weapon_id].evolutions[pid].name
	var pname: String = Balance.PASSIVES[pid].name
	if b.claimed.has(pid):
		return "✦ %s" % evo_name if b.claimed[pid] == weapon_id else "✗ %s (%s taken)" % [evo_name, pname]
	if b.passive_maxed(pid):
		return "✓ %s ← %s" % [evo_name, pname]
	if b.passives.has(pid):
		return "· %s ← %s %d/%d" % [evo_name, pname, b.passives[pid], Balance.PASSIVES[pid].max]
	return "· %s ← %s" % [evo_name, pname]
