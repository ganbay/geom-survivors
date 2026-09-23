extends Weapon
## Fires triangles at the nearest enemies.
## Evolutions: sides = Star Burst (radial rings) · velocity = Railgun (one huge bolt) · entropy = Ricochet (bouncing shots).

var _burst_toggle := false


func fire() -> void:
	match evo:
		"velocity":
			_railgun()
		_:
			_volley()
	Sfx.play("shoot", 1.0 + randf() * 0.1)


func _volley() -> void:
	var p := game.player.position
	var count := int(s.count)
	var targets := game.enemies.nearest_to_player(count, 620.0)
	var flags := game.build.vertex_flags()
	var sp: float = s.speed
	var bounces := 0
	if evo == "entropy":
		flags |= Bullets.F_RICOCHET
		bounces = 2
	for k in count:
		var dir := facing()
		if targets.size() > 0:
			var j := targets[k % targets.size()]
			dir = Vector2(game.enemies.px[j] - p.x, game.enemies.py[j] - p.y).normalized()
		if k >= targets.size() and targets.size() > 0:
			dir = dir.rotated((k - targets.size() + 1) * 0.18 * (1 if k % 2 == 0 else -1))
		var i := game.bullets.spawn(p.x, p.y, dir.x * sp, dir.y * sp, s.duration, dmg(), Bullets.Kind.TRI, src,
				int(s.pierce), flags, s.area, s.knockback)
		game.bullets.bounce[i] = bounces
	if evo == "sides":
		_burst_toggle = not _burst_toggle
		if _burst_toggle:
			var rays := 6 + count
			var off := randf() * TAU
			for k in rays:
				var a := off + TAU * k / rays
				game.bullets.spawn(p.x, p.y, cos(a) * sp, sin(a) * sp, s.duration * 0.8, dmg() * 0.7, Bullets.Kind.TRI, src,
						int(s.pierce), flags, s.area * 0.9, s.knockback)


## Railgun: every projectile fuses into one big, fast, infinitely piercing bolt.
func _railgun() -> void:
	var p := game.player.position
	var targets := game.enemies.nearest_to_player(1, 800.0)
	var dir := facing()
	if targets.size() > 0:
		var j := targets[0]
		dir = Vector2(game.enemies.px[j] - p.x, game.enemies.py[j] - p.y).normalized()
	var sp: float = s.speed * 2.2
	var d := dmg() * int(s.count) * 1.5
	game.bullets.spawn(p.x, p.y, dir.x * sp, dir.y * sp, s.duration, d, Bullets.Kind.TRI, src,
			999, game.build.vertex_flags(), s.area * 2.2, s.knockback * 3.0)
	game.fx.line(PackedVector2Array([p, p + dir * 900.0]), Color(0.6, 1.0, 1.0), 0.12, 3.0)
	timer += s.cooldown * 0.8  # heavier weapon: fires less often
