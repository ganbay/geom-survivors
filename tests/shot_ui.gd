extends Node
## Captures the menu screens, pop-ups and in-run overlays at phone resolution (720x1280),
## using an in-memory save with sample history. Never writes the real save.
## Usage: godot res://tests/shot_ui.tscn -- out=<dir>

var out := ""
var sv: SubViewport
var frames := 0
var menu: Control
var game: Game


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	Save.read_only = true
	Save.cfg = ConfigFile.new()
	Save.cfg.set_value("history", "runs", _sample_runs())
	Save.cfg.set_value("best", "triangle", {"depth": 1, "time": 742.0, "won": false})
	sv = SubViewport.new()
	sv.size = Vector2i(720, 1280)
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
			for id in ["line_laser", "orbitals", "pulse_ring"]:
				game.build.add_weapon(id)
			game.build.passives = {"radius": 3, "frequency": 2, "sides": 1}
			game.build.recompute()
		240:
			game.open_pause()
		255:
			_shot("ui_pause")
			game.close_pause()
			game._end_run(false)
		275:
			_shot("ui_gameover")
			get_tree().quit()


func _shot(nm: String) -> void:
	sv.get_texture().get_image().save_png("%s/%s.png" % [out, nm])
	print("shot ", nm)


func _sample_runs() -> Array:
	var now := int(Time.get_unix_time_from_system())
	return [
		{"ts": now - 1500, "result": "dead", "character": "triangle", "depth": 1, "time": 742.0, "level": 31, "kills": 6120,
		 "damage_taken": 612.0, "weapons": [
			{"id": "vertex_shot", "evo": "velocity", "name": "Railgun", "level": 6, "damage": 184000.0},
			{"id": "line_laser", "evo": "", "name": "Line Laser", "level": 5, "damage": 96500.0},
			{"id": "orbitals", "evo": "", "name": "Orbitals", "level": 3, "damage": 8100.0},
			{"id": "pulse_ring", "evo": "", "name": "Pulse Ring", "level": 4, "damage": 41200.0}],
		 "other_damage": {"Arc": 12300.0, "Fracture": 5100.0},
		 "passives": {"velocity": 5, "radius": 3, "frequency": 2, "sides": 1}, "overclocks": ["glass"]},
		{"ts": now - 90000, "result": "win", "character": "square", "depth": 0, "time": 900.0, "level": 38, "kills": 9412,
		 "damage_taken": 1204.0, "weapons": [
			{"id": "orbitals", "evo": "velocity", "name": "Saturn", "level": 6, "damage": 220000.0},
			{"id": "pulse_ring", "evo": "frequency", "name": "Metronome", "level": 6, "damage": 150000.0}],
		 "other_damage": {}, "passives": {"velocity": 5, "frequency": 5}, "overclocks": []},
		{"ts": now - 400000, "result": "quit", "character": "circle", "depth": 0, "time": 95.0, "level": 5, "kills": 180,
		 "damage_taken": 20.0, "weapons": [{"id": "pulse_ring", "evo": "", "name": "Pulse Ring", "level": 3, "damage": 2400.0}],
		 "other_damage": {}, "passives": {}, "overclocks": []},
	]
