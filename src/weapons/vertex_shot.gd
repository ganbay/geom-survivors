extends Weapon
## Fires triangles from the Triangle's tip at the nearest enemies.
## Level-10 forms: focus = Focus Fire (shots turn toward another enemy after each hit) · burst = Star Burst
##                 (double count) · deadeye = Deadeye (crits don't use up pierce).

const RANGE := 620.0
const SPREAD := 0.18


func fire() -> void:
	var p := game.player.tip()
	var count := int(s.count) * (2 if evo == "burst" else 1)
	var en := game.enemies
	var targets := en.nearest_to_player(count, RANGE)
	var flags := 0
	match evo:
		"focus":
			flags = Bullets.F_REDIRECT
		"deadeye":
			flags = Bullets.F_CRIT_PIERCE
	for i in count:
		var dir := game.player.aim
		if targets.size() > 0:
			var j := targets[i % targets.size()]
			dir = (Vector2(en.px[j], en.py[j]) - p).normalized()
		if i >= targets.size() and targets.size() > 0:
			# extra shots fan out around the ones already aimed
			var extra := i - targets.size() + 1
			dir = dir.rotated(ceili(extra / 2.0) * SPREAD * (1.0 if extra % 2 == 1 else -1.0))
		game.bullets.spawn(p.x, p.y, dir.x * s.speed, dir.y * s.speed, s.duration, s.damage, Bullets.Kind.TRI, src,
				int(s.pierce), flags, s.area, s.knockback, k())
	Sfx.play("shoot", 1.0 + randf() * 0.1)
