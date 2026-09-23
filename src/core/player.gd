class_name Player
extends Node2D
## The player shape. Movement comes from the joystick; weapons fire on their own.

var game: Game
var sides := 3
var hp := 100.0
var iframes := 0.0
var facing := Vector2.UP
var velocity := Vector2.ZERO
var spin := 0.0
var hurt_flash := 0.0


func setup(g: Game, char_id: String) -> void:
	game = g
	sides = Balance.CHARACTERS[char_id].sides


func on_max_hp_changed(old_max: float, new_max: float) -> void:
	if new_max > old_max:
		hp += new_max - old_max
	hp = minf(hp, new_max)


func update(delta: float, input: Vector2) -> void:
	var b := game.build
	velocity = input * b.move_speed
	position += velocity * delta
	if input.length_squared() > 0.04:
		facing = facing.lerp(input.normalized(), minf(1.0, delta * 14.0)).normalized()
	spin += delta * (1.0 + velocity.length() / 120.0)
	if iframes > 0.0:
		iframes -= delta
	if hurt_flash > 0.0:
		hurt_flash -= delta
	if b.regen > 0.0:
		heal(b.regen * delta)
	queue_redraw()


func is_still() -> bool:
	return velocity.length_squared() < 100.0


func contact(dmg: float) -> void:
	if iframes > 0.0 or hp <= 0.0 or game.god_mode:
		return
	var d := maxf(dmg - game.build.armor, 1.0) * game.build.taken_mult
	hp -= d
	game.damage_taken += d
	iframes = Balance.PLAYER_IFRAMES
	hurt_flash = 0.25
	for w in game.build.weapons:
		w.on_player_hurt()
	game.fx.shake(7.0)
	game.hud.flash_damage()
	Sfx.play("hurt")
	if Save.get_setting("vibration", true):
		Input.vibrate_handheld(40)
	if hp <= 0.0:
		hp = 0.0
		game.on_player_died()


func heal(amount: float) -> void:
	if hp > 0.0:
		hp = minf(hp + amount, game.build.max_hp)


func _draw() -> void:
	var col := Balance.C_PLAYER
	if hurt_flash > 0.0:
		col = Color(1, 1, 1)
	if iframes > 0.0 and fmod(iframes, 0.12) < 0.06:
		col.a = 0.35
	var r := Balance.PLAYER_RADIUS
	var rot := facing.angle() + PI / 2.0 if sides == 3 else spin * 0.6
	Shapes.draw_neon_poly(self, Shapes.points(sides, r + 2.0, rot - PI / 2.0 if sides == 3 else rot), col, 3.0, 0.25)
	# inner core
	Shapes.draw_neon_poly(self, Shapes.points(sides, r * 0.4, -spin * 1.5), Color(col, 0.8), 1.5)
	# facing tick
	Shapes.draw_neon_line(self, facing * (r + 8.0), facing * (r + 14.0), Color(col, 0.7), 2.0)
	# HP bar
	var frac := hp / game.build.max_hp
	var w := 40.0
	var y := r + 14.0
	draw_rect(Rect2(-w / 2.0, y, w, 4.0), Color(0.2, 0.05, 0.1, 0.8))
	draw_rect(Rect2(-w / 2.0, y, w * frac, 4.0), Balance.C_DANGER.lerp(Balance.C_XP, frac))
