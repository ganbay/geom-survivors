extends Weapon
## Expanding ring around the Circle that hits everything it crosses once.
## Level-10 forms: shockwave = Shockwave (slow + damage) · metronome = Metronome (fast beats, every 4th huge)
##                 implosion = Implosion (ring collapses inward, dragging enemies and XP).

const RADIUS := 170.0

# each ring: [radius, max_radius, hit_uids(Dictionary), delay, k]
var rings: Array = []
var beat := 0


func fire() -> void:
	var count := int(s.count)
	var max_r: float = RADIUS * s.area
	var mult := 1.0
	match evo:
		"shockwave":
			mult = 1.5
		"metronome":
			beat += 1
			timer = cooldown() * 0.45
			if beat % 4 == 0:
				max_r *= 1.6
				mult = 2.2
				game.fx.shake(5.0)
			else:
				max_r *= 0.75
				mult = 0.4
		"implosion":
			mult = 1.8
			game.gems.magnetize_near(game.player.position.x, game.player.position.y, max_r * 1.2)
	for i in count:
		var start := max_r if evo == "implosion" else 0.0
		rings.append([start, max_r, {}, i * 0.22, k(mult)])
	Sfx.play("pulse", 1.4 if evo == "metronome" and beat % 4 != 0 else 1.0)


func update(delta: float) -> void:
	super.update(delta)
	var en := game.enemies
	var p := game.player.position
	var implode := evo == "implosion"
	var kb: float = -absf(s.knockback) * 1.2 if implode else s.knockback
	for i in range(rings.size() - 1, -1, -1):
		var ring: Array = rings[i]
		if ring[3] > 0.0:
			ring[3] -= delta
			continue
		var max_r: float = ring[1]
		var speed: float = max_r / 0.42 * s.speed
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
			strike(j, ring[4], dir.x * kb, dir.y * kb)
			if evo == "shockwave":
				en.slow[j] = 2.0
		if done:
			rings.remove_at(i)


func draw(ci: CanvasItem) -> void:
	var p := game.player.position
	var col := Balance.C_WEAPON.lerp(Color.WHITE, 0.3) if evolved else Balance.C_WEAPON
	for ring in rings:
		if ring[3] > 0.0:
			continue
		var f: float = clampf(ring[0] / ring[1], 0.0, 1.0)
		var fade := f if evo == "implosion" else 1.0 - f
		var w := 3.0 + fade * 3.0 + (2.0 if ring[4] >= 2.0 else 0.0)
		Shapes.draw_neon_ring(ci, p, maxf(ring[0], 1.0), Color(col, 0.3 + fade * 0.7), w, 48)


func clear() -> void:
	rings.clear()
