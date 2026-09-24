extends Weapon
## Fires triangles at the nearest enemies.
## Evolutions: sides = Star Burst (double projectile count) · velocity = Railgun (big shots, infinite pierce, x2.2 speed, +60% damage)
##             entropy = Ricochet (bouncing shots).


func fire() -> void:
	var p := game.player.position
	var count := int(s.count) * (2 if evo == "sides" else 1)
	var targets := game.enemies.nearest_to_player(count, 620.0)
	var flags := game.build.vertex_flags()
	var sp: float = s.speed
	var pierce := int(s.pierce)
	var bounces := 0
	var d := dmg()
	match evo:
		"entropy":
			flags |= Bullets.F_RICOCHET
			bounces = 2
		"velocity":
			sp *= 2.2
			pierce = 999
			d *= 1.6
	for k in count:
		var dir := facing()
		if targets.size() > 0:
			var j := targets[k % targets.size()]
			dir = Vector2(game.enemies.px[j] - p.x, game.enemies.py[j] - p.y).normalized()
		if k >= targets.size() and targets.size() > 0:
			dir = dir.rotated((k - targets.size() + 1) * 0.18 * (1 if k % 2 == 0 else -1))
		var i := game.bullets.spawn(p.x, p.y, dir.x * sp, dir.y * sp, s.duration, d, Bullets.Kind.TRI, src,
				pierce, flags, s.area * (1.5 if evo == "velocity" else 1.0), s.knockback)
		game.bullets.bounce[i] = bounces
	Sfx.play("shoot", 1.0 + randf() * 0.1)
