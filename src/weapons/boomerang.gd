extends Weapon
## Rhombuses fly out toward enemies and get pulled back, piercing everything.
## Evolutions: magnet = Möbius (larger, flies out twice, collects XP) · velocity = Ricochet Blade (bounces off screen edges)
##             density = Guillotine (one giant grinding blade).


func fire() -> void:
	var p := game.player.position
	var count := int(s.count)
	var sp: float = s.speed
	var flags := Bullets.F_BOOMERANG | game.build.vertex_flags()
	if evo == "density":
		# one giant, slow blade carrying the damage of all of them
		var dir := _aim(p, 0, 1)
		var slow := sp * 0.55
		game.bullets.spawn(p.x, p.y, dir.x * slow, dir.y * slow, slow / (s.duration * 1.6), dmg() * (0.6 + 0.35 * count),
				Bullets.Kind.RHOMBUS, src, 0, flags | Bullets.F_GRIND, s.area * 3.4, s.knockback * 0.3)
		Sfx.play("shoot", 0.4)
		return
	for k in count:
		var dir := _aim(p, k, count)
		match evo:
			"velocity":
				game.bullets.spawn(p.x, p.y, dir.x * sp * 1.4, dir.y * sp * 1.4, 3.5, dmg() * 0.6, Bullets.Kind.RHOMBUS, src,
						0, Bullets.F_SCREEN | game.build.vertex_flags(), s.area, s.knockback)
			"magnet":
				var i := game.bullets.spawn(p.x, p.y, dir.x * sp, dir.y * sp, sp / s.duration, dmg(), Bullets.Kind.RHOMBUS, src,
						0, flags | Bullets.F_GEMS, s.area * 1.4, s.knockback)
				game.bullets.bounce[i] = 1
			_:
				game.bullets.spawn(p.x, p.y, dir.x * sp, dir.y * sp, sp / s.duration, dmg(), Bullets.Kind.RHOMBUS, src,
						0, flags, s.area, s.knockback)
	Sfx.play("shoot", 0.7)


func _aim(p: Vector2, k: int, count: int) -> Vector2:
	var targets := game.enemies.nearest_to_player(count, 520.0)
	var dir := facing().rotated(TAU * k / count)
	if targets.size() > 0:
		var j := targets[k % targets.size()]
		dir = Vector2(game.enemies.px[j] - p.x, game.enemies.py[j] - p.y).normalized()
		if k >= targets.size():
			dir = dir.rotated(0.5 * k)
	return dir
