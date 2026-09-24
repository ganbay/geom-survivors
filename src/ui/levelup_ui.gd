class_name LevelUpUI
extends CanvasLayer
## Card picker used for level-ups and overclock cores.

const INPUT_GRACE := 0.4  # ignore taps right after opening (thumb is still on the joystick)

var game: Game
var root: Control
var title: Label
var subtitle: Label
var cards: VBoxContainer
var res_row: HFlowContainer
var tools: HBoxContainer
var reroll_btn: Button
var banish_btn: Button
var skip_btn: Button
var offers: Array = []
var banish_mode := false
var with_tools := true
var opened_at := 0


func setup(g: Game) -> void:
	game = g
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	root.add_child(UI.dim(0.8))
	var col := UI.column(root, 14, 22)
	title = UI.label("LEVEL UP", 46, Balance.C_XP, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(title)
	subtitle = UI.label("", 22, Balance.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(subtitle)
	res_row = HFlowContainer.new()
	res_row.alignment = FlowContainer.ALIGNMENT_CENTER
	res_row.add_theme_constant_override("h_separation", 8)
	res_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(res_row)
	cards = VBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	col.add_child(cards)
	tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	col.add_child(tools)
	reroll_btn = UI.button("", _on_reroll, 64)
	banish_btn = UI.button("", _on_banish, 64)
	skip_btn = UI.button("", _on_skip, 64)
	for b in [reroll_btn, banish_btn, skip_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		tools.add_child(b)
	visible = false


func open(p_title: String, p_sub: String, p_offers: Array, p_tools: bool, color := Balance.C_XP) -> void:
	title.text = p_title
	title.add_theme_color_override("font_color", color)
	subtitle.text = p_sub
	offers = p_offers
	with_tools = p_tools
	banish_mode = false
	opened_at = Time.get_ticks_msec()
	visible = true
	_render()


func close() -> void:
	visible = false


func _render() -> void:
	for c in cards.get_children():
		c.queue_free()
	for c in res_row.get_children():
		c.queue_free()
	var counts := game.build.tag_counts
	for tag in Balance.TAG_COLORS:
		if counts.get(tag, 0) > 0:
			var t := game.build.tier(tag)
			var chip := UI.tag_chip("%s %d%s" % [tag, counts[tag], " ★".repeat(t)])
			res_row.add_child(chip)
	for o in offers:
		cards.add_child(_card(o))
	tools.visible = with_tools
	var b := game.build
	reroll_btn.text = "REROLL %d" % b.rerolls
	reroll_btn.disabled = b.rerolls <= 0
	banish_btn.text = ("TAP A CARD" if banish_mode else "BANISH %d" % b.banishes)
	banish_btn.disabled = b.banishes <= 0
	skip_btn.text = "SKIP %d" % b.skips
	skip_btn.disabled = b.skips <= 0


func _card(o: Dictionary) -> PanelContainer:
	var accent := Balance.C_PLAYER
	var icon_kind: String = o.kind
	var nm := ""
	var sub := ""
	var desc := ""
	var cost := ""
	var tags: Array = []
	var evolved := false
	match o.kind:
		"weapon":
			var d: Dictionary = Balance.WEAPONS[o.id]
			nm = d.name
			sub = "NEW WEAPON" if o.new else "LV %d → %d" % [o.level - 1, o.level]
			desc = d.desc if o.new else Weapon.level_text(o.id, o.level)
			tags = d.tags
		"passive":
			var d: Dictionary = Balance.PASSIVES[o.id]
			nm = d.name
			sub = "NEW PASSIVE" if o.new else "LV %d → %d" % [o.level - 1, o.level]
			desc = d.desc
			tags = d.tags
			accent = Color(0.6, 0.75, 1.0)
		"overclock":
			var d: Dictionary = Balance.OVERCLOCKS[o.id]
			nm = d.name
			sub = "OVERCLOCK · PERMANENT TRADE-OFF"
			desc = "+ " + d.desc.trim_prefix("+")
			cost = "− " + d.cost.trim_prefix("-")
			accent = Color(1.0, 0.5, 0.2)
		"evolve":
			var d: Dictionary = Balance.WEAPONS[o.id]
			var e: Dictionary = d.evolutions[o.passive]
			nm = e.name
			sub = "EVOLUTION · %s + %s  ·  CLAIMS %s" % [d.name.to_upper(), Balance.PASSIVES[o.passive].name.to_upper(), Balance.PASSIVES[o.passive].name.to_upper()]
			desc = e.desc
			accent = Balance.C_GOLD
			icon_kind = "weapon"
			evolved = true
		"bonus":
			nm = "Vent Core"
			sub = "DECLINE THE OVERCLOCK"
			desc = "Gain a free level-up and heal 30%."
			accent = Balance.C_GOLD
			icon_kind = "heal"
		"heal":
			nm = "Repair"
			sub = "BUILD COMPLETE"
			desc = "Heal 30% HP."
			accent = Balance.C_HEAL
	var card := PanelContainer.new()
	var border := Balance.C_DANGER if banish_mode else accent
	var normal := UI.box(border, 0.07 if not banish_mode else 0.14)
	var pressed := UI.box(border, 0.3)
	card.add_theme_stylebox_override("panel", normal)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				card.add_theme_stylebox_override("panel", pressed)
			else:
				card.add_theme_stylebox_override("panel", normal)
				if Rect2(Vector2.ZERO, card.size).has_point(e.position):
					_on_card(o))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(ItemIcon.new(icon_kind, o.get("id", ""), o.get("level", 1), evolved, 76.0))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var top := HFlowContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("h_separation", 8)
	v.add_child(top)
	top.add_child(UI.label(nm, 28, Color.WHITE))
	for tag in tags:
		top.add_child(UI.tag_chip(tag))
	v.add_child(UI.label(sub, 17, accent))
	v.add_child(UI.wrap_label(desc, 21, Balance.C_TEXT))
	if cost != "":
		v.add_child(UI.wrap_label(cost, 21, Color(1.0, 0.4, 0.35)))
	if o.kind in ["weapon", "passive"]:
		for h in game.build.offer_hints(o):
			v.add_child(UI.wrap_label(h, 18, UI.hint_color(h)))
	elif o.kind == "evolve":
		# what this choice costs: the other weapons that also wanted this passive
		for wid in Balance.WEAPONS:
			if wid != o.id and Balance.WEAPONS[wid].evolutions.has(o.passive) and game.build.weapon(wid):
				v.add_child(UI.wrap_label("✗ %s loses %s" % [Balance.WEAPONS[wid].name, Balance.WEAPONS[wid].evolutions[o.passive].name], 18, Color(1.0, 0.45, 0.4)))
	return card


func _ready_for_input() -> bool:
	return Time.get_ticks_msec() - opened_at > INPUT_GRACE * 1000.0


func _on_card(o: Dictionary) -> void:
	if not _ready_for_input():
		return
	if banish_mode:
		if not o.kind in ["weapon", "passive"]:
			return  # evolutions and fallback cards can't be banished
		banish_mode = false
		game.build.banishes -= 1
		game.build.banished[o.id] = true
		Sfx.play("dash")
		offers = game.build.make_offers()
		_render()
		return
	Sfx.play("select")
	game.on_offer_chosen(o)


func _on_reroll() -> void:
	if not _ready_for_input() or game.build.rerolls <= 0:
		return
	game.build.rerolls -= 1
	banish_mode = false
	offers = game.build.make_offers()
	_render()


func _on_banish() -> void:
	if game.build.banishes <= 0:
		return
	banish_mode = not banish_mode
	_render()


func _on_skip() -> void:
	if not _ready_for_input() or game.build.skips <= 0:
		return
	game.build.skips -= 1
	game.player.heal(game.build.max_hp * 0.15)
	game.on_offer_chosen({"kind": "skip"})
