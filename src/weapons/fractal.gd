extends Weapon
## Slow shot that splits into three on hit, `bounces` times deep.
## Evolutions: entropy = Mandelbrot (extra depth, splits always crit) · radius = Supernova (swells, then explodes)
##             magnet = Attractor (homing vortex that pulls enemies in, then splits).


func fire() -> void:
	var p := game.player.position
	var count := int(s.count)
	var targets := game.enemies.nearest_to_player(count, 560.0)
	var sp: float = s.speed
	for k in count:
		var dir := facing().rotated(k * 0.3)
		if targets.size() > 0:
			var j := targets[k % targets.size()]
			dir = Vector2(game.enemies.px[j] - p.x, game.enemies.py[j] - p.y).normalized()
		var i: int
		match evo:
			"radius":
				i = game.bullets.spawn(p.x, p.y, dir.x * sp * 0.8, dir.y * sp * 0.8, s.duration, dmg() * 1.5, Bullets.Kind.FRACTAL, src,
						0, Bullets.F_NOVA, s.area, s.knockback)
			"magnet":
				i = game.bullets.spawn(p.x, p.y, dir.x * 170.0, dir.y * 170.0, 2.6, dmg() * 0.5, Bullets.Kind.ORB, src,
						0, Bullets.F_VORTEX | game.build.vertex_flags(), s.area, 10.0)
				game.bullets.depth[i] = int(s.bounces)
			_:
				var flags := Bullets.F_FRACTAL | game.build.vertex_flags()
				var depth := int(s.bounces)
				if evo == "entropy":
					flags |= Bullets.F_CHILD_CRIT
					depth += 1
				i = game.bullets.spawn(p.x, p.y, dir.x * sp, dir.y * sp, s.duration, dmg(), Bullets.Kind.FRACTAL, src,
						int(s.pierce), flags, s.area, s.knockback)
				game.bullets.depth[i] = depth
	Sfx.play("shoot", 0.6)
