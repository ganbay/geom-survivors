extends Weapon
## Fires triangles from the Triangle's tip at the nearest enemies.
## Level-10 forms: focus = Focus Fire (every shot at the closest enemy) · burst = Star Burst (double count)
##                 deadeye = Deadeye (crits ricochet to another enemy).

const RANGE := 620.0
const RICOCHETS := 3  # Deadeye: redirects per shot


func fire() -> void:
	var p := game.player.tip()
	var count := int(s.count) * (2 if evo == "burst" else 1)
	var en := game.enemies
	var targets := en.nearest_to_player(count, RANGE)
	if evo == "focus" and targets.size() > 1:
		var closest := targets[0]
		for j in targets:
			if en.pd2[j] < en.pd2[closest]:
				closest = j
		targets = PackedInt32Array([closest])
	var flags := Bullets.F_RICOCHET if evo == "deadeye" else 0
	var spread := 0.05 if evo == "focus" else 0.18
	for i in count:
		var dir := game.player.aim
		if targets.size() > 0:
			var j := targets[i % targets.size()]
			dir = (Vector2(en.px[j], en.py[j]) - p).normalized()
		if i >= targets.size() and targets.size() > 0:
			# extra shots fan out around the ones already aimed
			var extra := i - targets.size() + 1
			dir = dir.rotated(ceili(extra / 2.0) * spread * (1.0 if extra % 2 == 1 else -1.0))
		var b := game.bullets.spawn(p.x, p.y, dir.x * s.speed, dir.y * s.speed, s.duration, s.damage, Bullets.Kind.TRI, src,
				int(s.pierce), flags, s.area, s.knockback, k())
		game.bullets.bounce[b] = RICOCHETS
	Sfx.play("shoot", 1.0 + randf() * 0.1)
