extends Node
## Settings and persistent progress: unlocked depth, best results and run history.

const PATH := "user://save.cfg"
const HISTORY_MAX := 60

var cfg := ConfigFile.new()
## Parameters for the next run, set by the menu.
var run_config := {"character": "triangle", "depth": 0}
## Test harnesses set this so bot runs never touch the player's save.
var read_only := false


func _init() -> void:
	cfg.load(PATH)


func get_setting(key: String, default: Variant) -> Variant:
	return cfg.get_value("settings", key, default)


func set_setting(key: String, value: Variant) -> void:
	cfg.set_value("settings", key, value)
	cfg.save(PATH)


func depth_unlocked() -> int:
	return cfg.get_value("progress", "depth_unlocked", 0)


func record_win(depth: int) -> void:
	if read_only:
		return
	if depth >= depth_unlocked() and depth + 1 < Balance.DEPTHS.size():
		cfg.set_value("progress", "depth_unlocked", depth + 1)
	cfg.save(PATH)


func best(char_id: String) -> Dictionary:
	return cfg.get_value("best", char_id, {})


func record_run(char_id: String, depth: int, time: float, won: bool) -> void:
	if read_only:
		return
	var b := best(char_id)
	if depth > b.get("depth", -1) or (depth == b.get("depth", -1) and time > b.get("time", 0.0)):
		cfg.set_value("best", char_id, {"depth": depth, "time": time, "won": won})
	cfg.save(PATH)


## Past runs, newest first. Entry layout is built by Game.history_entry().
func history() -> Array:
	return cfg.get_value("history", "runs", [])


func record_history(entry: Dictionary) -> void:
	if read_only:
		return
	var runs := history()
	runs.push_front(entry)
	if runs.size() > HISTORY_MAX:
		runs.resize(HISTORY_MAX)
	cfg.set_value("history", "runs", runs)
	cfg.save(PATH)
