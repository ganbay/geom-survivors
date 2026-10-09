class_name Player
extends Node2D
## The player shape. Movement comes from the joystick; weapons fire on their own.

var game: Game
var character: Dictionary
var sides := 3
var hp := 100.0
var iframes := 0.0
var facing := Vector2.UP
var aim := Vector2.UP    # where the Triangle's tip points: at its target, or `facing` with none in range
var body_rot := 0.0      # the Square's rotation, driven by its rods
var velocity := Vector2.ZERO
var spin := 0.0
var hurt_flash := 0.0

const AIM_RANGE := 620.0


func setup(g: Game, char_id: String) -> void:
	game = g
	character = Balance.CHARACTERS[char_id]
	sides = character.sides


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
	if sides == 3:
		var want := facing
		var en := game.enemies
		var best := -1
		for j in en.nearest_to_player(1, AIM_RANGE):
			best = j
		if best >= 0:
			want = (Vector2(en.px[best], en.py[best]) - position).normalized()
		aim = aim.lerp(want, minf(1.0, delta * 18.0)).normalized()
	if iframes > 0.0:
		iframes -= delta
	if hurt_flash > 0.0:
		hurt_flash -= delta
	if b.regen > 0.0:
		heal(b.regen * delta)
	queue_redraw()


func is_still() -> bool:
	return velocity.length_squared() < 100.0


## The body outline in local space.
func outline() -> PackedVector2Array:
	var r := Balance.PLAYER_RADIUS + 2.0
	match sides:
		3:
			return Shapes.points(3, r, aim.angle())
		4:
			return Shapes.points(4, r, body_rot)
	return Shapes.character_points(character, r, spin * 0.6)


## World position of the Triangle's front tip (the centre for shapes without one).
func tip() -> Vector2:
	return position + aim * (Balance.PLAYER_RADIUS + 2.0) if sides == 3 else position


## World position of the pointy part closest to `target`: one of the Spark's two tips.
func tip_near(target: Vector2) -> Vector2:
	if character.get("shape", "") != "spark":
		return tip()
	var pts := outline()
	var a := position + pts[0]
	var b := position + pts[3]
	return a if a.distance_squared_to(target) < b.distance_squared_to(target) else b


func contact(dmg: float) -> void:
	if iframes > 0.0 or hp <= 0.0 or game.god_mode:
		return
	var b := game.build
	if randf() < b.stat("dodge"):
		iframes = 0.25
		game.fx.ring(position.x, position.y, 40.0, Color(Balance.C_PLAYER, 0.6), 0.2, 2.0)
		return
	var d := maxf(dmg - b.armor, 1.0) * b.taken_mult
	hp -= d
	game.damage_taken += d
	iframes = Balance.PLAYER_IFRAMES + b.stat("iframes")
	hurt_flash = 0.25
	for w in b.weapons:
		w.on_player_hurt()
	game.on_player_hurt()
	game.fx.shake(7.0)
	game.hud.flash_damage()
	Sfx.play("hurt")
	if Save.get_setting("vibration", true):
		Input.vibrate_handheld(40)
	if hp <= 0.0:
		if b.has_revive and not b.revive_used:
			# Last Stand overclock
			b.revive_used = true
			hp = b.max_hp * 0.5
			iframes = Balance.REVIVE_IFRAMES
			game.hostile.destroy_near(position.x, position.y, 220.0)
			game.fx.ring(position.x, position.y, 220.0, Balance.C_GOLD, 0.6, 5.0)
			game.hud.banner("LAST STAND", Balance.C_GOLD, 1.5)
			Sfx.play("heal")
			return
		hp = 0.0
		game.on_player_died()


func heal(amount: float) -> void:
	if hp > 0.0:
		hp = minf(hp + amount * game.build.heal_mult, game.build.max_hp)


func _draw() -> void:
	var col := Balance.C_PLAYER
	if hurt_flash > 0.0:
		col = Color(1, 1, 1)
	if iframes > 0.0 and fmod(iframes, 0.12) < 0.06:
		col.a = 0.35
	var r := Balance.PLAYER_RADIUS
	Shapes.draw_neon_poly(self, outline(), col, 3.0, 0.25)
	# inner core
	Shapes.draw_neon_poly(self, Shapes.points(sides, r * 0.4, -spin * 1.5), Color(col, 0.8), 1.5)
	if sides == 3:
		# aim tick
		Shapes.draw_neon_line(self, aim * (r + 8.0), aim * (r + 14.0), Color(col, 0.7), 2.0)
	# HP bar
	var frac := hp / game.build.max_hp
	var w := 40.0
	var y := r + 14.0
	draw_rect(Rect2(-w / 2.0, y, w, 4.0), Color(0.2, 0.05, 0.1, 0.8))
	draw_rect(Rect2(-w / 2.0, y, w * frac, 4.0), Balance.C_DANGER.lerp(Balance.C_HEAL, frac))
