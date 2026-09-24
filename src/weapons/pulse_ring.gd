extends Weapon
## Expanding ring around the player that hits everything it crosses once.
## Evolutions: radius = Shockwave (slow + damage) · frequency = Metronome (fast beats, every 4th huge)
##             magnet = Implosion (ring collapses inward, dragging enemies and XP).
## PULSE resonance tier 2: pulls enemies inward.

# each ring: [radius, max_radius, hit_uids(Dictionary), delay, damage_mult]
var rings: Array = []
var beat := 0


func fire() -> void:
	var count := int(s.count)
	var max_r: float = 170.0 * s.area
	var mult := 1.0
	match evo:
		"radius":
			mult = 1.5
		"frequency":
			beat += 1
			timer = s.cooldown * 0.45
			if beat % 4 == 0:
				max_r *= 1.6
				mult = 2.2
				game.fx.shake(5.0)
			else:
				max_r *= 0.75
				mult = 0.4
		"magnet":
			mult = 1.8
			game.gems.magnetize_near(game.player.position.x, game.player.position.y, max_r * 1.2)
	for k in count:
		var start := max_r if evo == "magnet" else 0.0
		rings.append([start, max_r, {}, k * 0.22, mult])
	Sfx.play("pulse", 1.4 if evo == "frequency" and beat % 4 != 0 else 1.0)


func update(delta: float) -> void:
	super.update(delta)
	var en := game.enemies
	var p := game.player.position
	var pull := game.build.tier("PULSE") >= 2 or evo == "magnet"
	var implode := evo == "magnet"
	for k in range(rings.size() - 1, -1, -1):
		var ring: Array = rings[k]
		if ring[3] > 0.0:
			ring[3] -= delta
			continue
		var max_r: float = ring[1]
		var speed: float = max_r / 0.42 * s.speed
		var d := dmg() * float(ring[4])
		var hit_set: Dictionary = ring[2]
		var done := false
		var r: float
		var c: int
		if implode:
			ring[0] -= speed * delta
			r = maxf(ring[0], 0.0)
			c = en.query(p.x, p.y, max_r)
			done = ring[0] <= 0.0
		else:
			ring[0] += speed * delta
			r = ring[0]
			c = en.query(p.x, p.y, r)
			done = r >= max_r
		for q in c:
			var j := en.qbuf[q]
			var u := en.uid[j]
			if hit_set.has(u):
				continue
			var dir := Vector2(en.px[j] - p.x, en.py[j] - p.y)
			if implode and dir.length() < r - en.t_radius[en.typ[j]]:
				continue  # the collapsing ring hasn't reached it yet
			hit_set[u] = true
			dir = dir.normalized()
			var kb: float = s.knockback * (-1.2 if pull else 1.0)
			var crit := randf() < game.build.crit
			en.hit(j, d * (Balance.CRIT_MULT if crit else 1.0), dir.x * kb, dir.y * kb, display_name())
			if evo == "radius":
				en.slow[j] = 2.0
		if done:
			rings.remove_at(k)


func draw(ci: CanvasItem) -> void:
	var p := game.player.position
	var col := Color(0.3, 1.0, 0.75)
	match evo:
		"radius": col = Color(0.5, 0.9, 1.0)
		"frequency": col = Color(0.5, 1.0, 0.55)
		"magnet": col = Color(0.55, 0.65, 1.0)
	for ring in rings:
		if ring[3] > 0.0:
			continue
		var f: float = clampf(ring[0] / ring[1], 0.0, 1.0)
		var fade := f if evo == "magnet" else 1.0 - f
		var w := 3.0 + fade * 3.0 + (2.0 if ring[4] >= 3.0 else 0.0)
		Shapes.draw_neon_ring(ci, p, maxf(ring[0], 1.0), Color(col, 0.3 + fade * 0.7), w, 48)


func clear() -> void:
	rings.clear()
