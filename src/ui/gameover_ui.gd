class_name GameOverUI
extends CanvasLayer
## End-of-run summary.

var game: Game
var root: Control


func setup(g: Game) -> void:
	game = g
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open(won: bool, unlocked_depth: int) -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	root.add_child(UI.dim(0.9))
	var col := UI.column(root, 12, 28)
	col.add_child(UI.label("VICTORY" if won else "SHATTERED", 56, Balance.C_GOLD if won else Balance.C_DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UI.label("%s · DEPTH %d" % [Balance.CHARACTERS[game.character_id].name, game.depth], 24, Balance.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UI.label("TIME %s   LV %d   %d KILLS" % [UI.fmt_time(game.time), game.level, game.kills], 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	if unlocked_depth > 0:
		col.add_child(UI.label("DEPTH %d UNLOCKED" % unlocked_depth, 30, Balance.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	col.add_child(body)
	PauseUI.build_summary(game, body)
	col.add_child(UI.button("RETRY", func(): game.restart()))
	col.add_child(UI.button("MENU", func(): game.quit_to_menu(), 60))
	visible = true
