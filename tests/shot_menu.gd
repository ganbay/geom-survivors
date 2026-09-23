extends Node
## Captures the main menu. Usage: godot res://tests/shot_menu.tscn -- out=<dir>

var frames := 0
var out := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	add_child(load("res://scenes/main.tscn").instantiate())


func _process(_d: float) -> void:
	frames += 1
	if frames == 30:
		get_viewport().get_texture().get_image().save_png(out + "/menu.png")
		get_tree().quit()
