extends Node
## Captures the menu screens, pop-ups and in-run overlays at phone resolution (720x1280),
## using an in-memory save with sample history. Never writes the real save.
## Usage: godot res://tests/shot_ui.tscn -- out=<dir> [size=720x1280] [char=triangle]
## `size` is the stretched viewport: 720x1560 ≈ 19.5:9 phone, 960x1280 ≈ 3:4 tablet.
## `notch=1` fakes a 90px top cutout and a 60px bottom gesture bar.

var out := ""
var sv: SubViewport
var frames := 0
var menu: Control
var game: Game
var tag := ""
var size_arg := ""
var char_id := "triangle"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a == "notch=1":
			UI.force_insets = Vector4(0, 90, 0, 60)
		elif a.begins_with("size="):
			size_arg = a.substr(5)
		elif a.begins_with("char="):
			char_id = a.substr(5)
	if char_id != "triangle":
		tag = "_" + char_id
	if size_arg != "":
		tag += "_" + size_arg
	if UI.force_insets != Vector4.ZERO:
		tag += "_notch"
	Save.read_only = true
	Save.cfg = ConfigFile.new()
	Save.run_config = {"character": char_id, "depth": 0}
	Save.cfg.set_value("history", "runs", _sample_runs())
	Save.cfg.set_value("best", "triangle", {"depth": 1, "time": 742.0, "won": false})
	sv = SubViewport.new()
	var dims := size_arg.split("x") if size_arg != "" else PackedStringArray(["720", "1280"])
	sv.size = Vector2i(int(dims[0]), int(dims[1]))
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	menu = load("res://scenes/main.tscn").instantiate()
	sv.add_child(menu)


func _process(_d: float) -> void:
	frames += 1
	match frames:
		20:
			_shot("ui_menu")
			menu._open_settings()
		45:
			_shot("ui_settings")
			menu.modal.close()
		60:
			menu._open_history()
		85:
			_shot("ui_history")
			menu.modal.get_meta("history").show_detail(0)
		110:
			_shot("ui_report")
			menu.queue_free()
			game = load("res://scenes/game.tscn").instantiate()
			sv.add_child(game)
		115:
			game.god_mode = true
			var b := game.build
			var w := b.weapons[0]
			w.level = 9
			b.choices = {"%s:4" % w.id: 0, "%s:7" % w.id: 1, "damage:5": 1}
			b.passives = {"damage": 6, "cooldown": 3, "area": 2}
			b.recompute()
		230:
			_shot("ui_hud")
			var w := game.build.weapons[0]
			game.on_offer_chosen({"kind": "weapon", "id": w.id, "level": 10, "new": false})
		245:
			_shot("ui_milestone")
			game.on_offer_chosen(game.levelup.offers[0])
		300:
			_shot("ui_evolved")
			game.open_pause()
		315:
			_shot("ui_pause")
			game.close_pause()
			game._end_run(false)
		335:
			_shot("ui_gameover")
			get_tree().quit()


func _shot(nm: String) -> void:
	sv.get_texture().get_image().save_png("%s/%s%s.png" % [out, nm, tag])
	print("shot ", nm)


func _sample_runs() -> Array:
	var now := int(Time.get_unix_time_from_system())
	return [
		{"ts": now - 1500, "result": "dead", "character": "triangle", "depth": 1, "time": 742.0, "level": 31, "kills": 6120,
		 "damage_taken": 612.0, "weapons": [
			{"id": "vertex_shot", "evo": "burst", "name": "Star Burst", "level": 10, "damage": 284000.0}],
		 "other_damage": {"Arc": 12300.0, "Volatile": 5100.0},
		 "passives": {"damage": 10, "cooldown": 6, "crit": 3, "magnet": 1}, "overclocks": ["glass"],
		 "choices": {"vertex_shot:4": 0, "vertex_shot:7": 1, "vertex_shot:10": 1, "damage:5": 0, "damage:10": 2, "cooldown:5": 0}},
		{"ts": now - 90000, "result": "win", "character": "square", "depth": 0, "time": 900.0, "level": 38, "kills": 9412,
		 "damage_taken": 1204.0, "weapons": [
			{"id": "orbitals", "evo": "saturn", "name": "Saturn", "level": 10, "damage": 370000.0}],
		 "other_damage": {}, "passives": {"velocity": 10, "hull": 8}, "overclocks": [], "choices": {}},
		{"ts": now - 400000, "result": "quit", "character": "spark", "depth": 0, "time": 95.0, "level": 5, "kills": 180,
		 "damage_taken": 20.0, "weapons": [{"id": "chain_arc", "evo": "", "name": "Chain Arc", "level": 3, "damage": 2400.0}],
		 "other_damage": {}, "passives": {}, "overclocks": [], "choices": {}},
	]
