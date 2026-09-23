class_name GridBackground
extends Node2D
## Infinite neon grid drawn around the camera (a few dozen lines per frame).

const STEP := 64.0
const MAJOR := 4

var center := Vector2.ZERO


func _ready() -> void:
	z_index = -10


func _draw() -> void:
	var half := get_viewport_rect().size * 0.5 + Vector2(STEP, STEP)
	var x0 := floorf((center.x - half.x) / STEP)
	var x1 := ceilf((center.x + half.x) / STEP)
	var y0 := floorf((center.y - half.y) / STEP)
	var y1 := ceilf((center.y + half.y) / STEP)
	var minor := PackedVector2Array()
	var major := PackedVector2Array()
	for gx in range(int(x0), int(x1) + 1):
		var x := gx * STEP
		var arr := major if posmod(gx, MAJOR) == 0 else minor
		arr.append(Vector2(x, center.y - half.y))
		arr.append(Vector2(x, center.y + half.y))
	for gy in range(int(y0), int(y1) + 1):
		var y := gy * STEP
		var arr := major if posmod(gy, MAJOR) == 0 else minor
		arr.append(Vector2(center.x - half.x, y))
		arr.append(Vector2(center.x + half.x, y))
	if minor.size() > 0:
		draw_multiline(minor, Balance.C_GRID, 1.0)
	if major.size() > 0:
		draw_multiline(major, Balance.C_GRID_MAJOR, 2.0)
