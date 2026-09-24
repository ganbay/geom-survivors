extends Weapon
## Circles orbit the player and hit what they touch; each enemy can be hit again after `cooldown` seconds.
## Evolutions: velocity = Saturn (second ring) · radius = Event Horizon (wider ring, bigger orbiters + gravity)
##             hull = Aegis (tight ring that eats enemy bullets and heals).
## ORBIT resonance tier 2: every orbiter shoots a spark once per second.

var angle := 0.0
var rehit := {}  # enemy uid -> time when it can be hit again
var prune_t := 5.0
var spark_timer := 1.0
var positions := PackedVector2Array()
var r_ball := 12.0


func update(delta: float) -> void:
	angle += s.speed * delta * (1.3 if evo in ["hull", "velocity"] else 1.0)
	var p := game.player.position
	var count := int(s.count)
	var r_orbit: float = 88.0 * s.area
	r_ball = 12.0 * s.area
	var kb: float = s.knockback
	match evo:
		"radius":
			r_orbit *= 1.25
			r_ball *= 1.6
		"velocity":
			r_ball *= 1.3
		"hull":
			r_orbit *= 0.72
			r_ball *= 1.3
			kb *= 2.0
	positions.clear()
	for k in count:
		var a := angle + TAU * k / count
		positions.append(p + Vector2(cos(a), sin(a)) * r_orbit)
	if evo == "velocity":
		for k in count + 2:
			var a := -angle * 0.8 + TAU * (k + 0.5) / (count + 2)
			positions.append(p + Vector2(cos(a), sin(a)) * r_orbit * 1.7)
	var en := game.enemies
	if evo == "radius":
		_gravity(p, r_orbit, delta)
	var now := game.time
	var d: float = dmg() * {"hull": 1.5, "radius": 1.25}.get(evo, 1.0)
	var cd: float = maxf(s.cooldown, 0.12)
	for pos in positions:
		var c := en.query(pos.x, pos.y, r_ball)
		for q in c:
			var j := en.qbuf[q]
			var u := en.uid[j]
			if rehit.get(u, 0.0) > now:
				continue
			rehit[u] = now + cd
			var dir := Vector2(en.px[j] - p.x, en.py[j] - p.y).normalized()
			var crit := randf() < game.build.crit
			en.hit(j, d * (Balance.CRIT_MULT if crit else 1.0), dir.x * kb, dir.y * kb, display_name())
		if evo == "hull":
			var blocked := game.hostile.destroy_near(pos.x, pos.y, r_ball + 8.0)
			if blocked > 0:
				game.player.heal(0.5 * blocked)
	prune_t -= delta
	if prune_t <= 0.0:
		prune_t = 5.0
		for u in rehit.keys():
			if rehit[u] < now:
				rehit.erase(u)
	if game.build.tier("ORBIT") >= 2:
		spark_timer -= delta
		if spark_timer <= 0.0:
			spark_timer = 1.0
			var targets := game.enemies.nearest_to_player(1, 500.0)
			if targets.size() > 0:
				var j := targets[0]
				for pos in positions:
					var dir := Vector2(game.enemies.px[j] - pos.x, game.enemies.py[j] - pos.y).normalized()
					game.bullets.spawn(pos.x, pos.y, dir.x * 520.0, dir.y * 520.0, 1.0, dmg() * 0.5, Bullets.Kind.SPARK, src, 0, 0, 1.0, 20.0)


## Event Horizon: enemies near the ring fall into it.
func _gravity(p: Vector2, r_orbit: float, delta: float) -> void:
	var en := game.enemies
	var c := en.query(p.x, p.y, r_orbit * 2.0)
	for q in c:
		var j := en.qbuf[q]
		if en.is_boss(j):
			continue
		var ox := en.px[j] - p.x
		var oy := en.py[j] - p.y
		var d := sqrt(ox * ox + oy * oy) + 0.001
		# pull toward the ring radius (from outside inward, from inside outward)
		var toward := -signf(d - r_orbit)
		var pull := 1000.0 * delta / en.t_mass[en.typ[j]]
		en.kx[j] += ox / d * pull * toward
		en.ky[j] += oy / d * pull * toward


func draw(ci: CanvasItem) -> void:
	var col := Balance.C_WEAPON
	match evo:
		"velocity":
			col = Color(0.6, 0.75, 1.0)
		"radius":
			col = Color(0.7, 0.55, 1.0)
			Shapes.draw_neon_ring(ci, game.player.position, 88.0 * s.area * 1.25, Color(col, 0.15), 1.5, 48)
		"hull":
			col = Color(0.8, 1.0, 1.0)
	for pos in positions:
		Shapes.draw_neon_ring(ci, pos, r_ball, col, 2.5, 16)
