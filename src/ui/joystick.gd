class_name Joystick
extends Node2D
## Floating joystick: the base is placed where the finger first touches (below the HUD bar) and stays there.

const RADIUS := 80.0
const DEADZONE := 0.12
const TOP_BLOCK := 130.0  # ignore touches on the HUD strip

var active := false
var touch_index := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var output := Vector2.ZERO
var idle_hint := true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not active and event.position.y > TOP_BLOCK:
			active = true
			idle_hint = false
			touch_index = event.index
			origin = event.position
			knob = origin
			_update_output()
		elif not event.pressed and event.index == touch_index:
			active = false
			touch_index = -1
			output = Vector2.ZERO
		queue_redraw()
	elif event is InputEventScreenDrag and active and event.index == touch_index:
		knob = event.position
		_update_output()
		queue_redraw()


func release() -> void:
	active = false
	touch_index = -1
	output = Vector2.ZERO
	queue_redraw()


func _update_output() -> void:
	var off := (knob - origin) / RADIUS
	if off.length() < DEADZONE:
		output = Vector2.ZERO
	else:
		output = off.limit_length(1.0)


func _draw() -> void:
	if active:
		Shapes.draw_neon_ring(self, origin, RADIUS, Color(Balance.C_PLAYER, 0.35), 2.0, 40)
		var k := origin + (knob - origin).limit_length(RADIUS)
		Shapes.draw_neon_ring(self, k, 28.0, Color(Balance.C_PLAYER, 0.8), 3.0, 24)
