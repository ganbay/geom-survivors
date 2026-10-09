extends Weapon
## Expanding ring around the Circle that hits everything it crosses once.
## Level-10 forms: double = Double Pulse (a second ring per pulse, stats only) · repulsor = Repulsor (every 3rd
##                 ring knocks back and wipes enemy bullets) · tide = Tide (one permanent ring sweeping in and out).

const RADIUS := 170.0
const GROW_TIME := 0.42  # seconds for a ring to reach full size at speed 1
const TIDE_MIN_PASS := 0.12  # Tide: fastest one sweep (out or in) can get

# each ring: [radius, max_radius, hit_uids(Dictionary), delay, k, repulse]
var rings: Array = []
var fired := 0
# Tide: the one ring that never fades
var tide_r := 0.0
var tide_out := true
var tide_hit := {}
var tide_k := 1.0


func fire() -> void:
	var max_r: float = RADIUS * s.area
	for i in int(s.count):
		fired += 1
		var repulse := evo == "repulsor" and fired % Balance.REPULSOR_EVERY == 0
		rings.append([0.0, max_r, {}, i * 0.22, k(), repulse])
	Sfx.play("pulse")


func update(delta: float) -> void:
	if evo == "tide":
		_tide(delta)
		return
	super.update(delta)
	var en := game.enemies
	var p := game.player.position
	for i in range(rings.size() - 1, -1, -1):
		var ring: Array = rings[i]
		if ring[3] > 0.0:
			ring[3] -= delta
			continue
		var max_r: float = ring[1]
		ring[0] += max_r / GROW_TIME * s.speed * delta
		var r: float = ring[0]
		var kb: float = Balance.REPULSOR_KNOCKBACK if ring[5] else s.knockback
		if ring[5]:
			game.hostile.destroy_near(p.x, p.y, r)
		var hit_set: Dictionary = ring[2]
		var c := en.query(p.x, p.y, r)
		for q in c:
			var j := en.qbuf[q]
			var u := en.uid[j]
			if hit_set.has(u):
				continue
			hit_set[u] = true
			var dir := Vector2(en.px[j] - p.x, en.py[j] - p.y).normalized()
			strike(j, ring[4], dir.x * kb, dir.y * kb)
		if r >= max_r:
			rings.remove_at(i)


## Tide: the ring sweeps out to full size and back in, forever. One pass takes half a cooldown at ring
## speed 1, shortened again by how far the cooldown has been cut, so cooldown reduction counts twice.
func _tide(delta: float) -> void:
	var max_r: float = RADIUS * s.area
	var cut: float = cooldown() / data.base.cooldown
	var pass_time: float = maxf(cooldown() * 0.5 * cut / s.speed, TIDE_MIN_PASS)
	# Travel the whole frame's distance, hitting before every turn: however fast the ring gets, each pass
	# still reaches every enemy, and a frame long enough to hold several passes plays all of them.
	var travel := max_r / pass_time * delta
	while travel > 0.0:
		var left := max_r - tide_r if tide_out else tide_r
		var step := minf(travel, left)
		tide_r += step if tide_out else -step
		travel -= step
		_tide_hits(max_r)
		if step >= left:
			# turned around: a new pass counts as a new attack and can hit everyone again
			tide_out = not tide_out
			tide_hit.clear()
			attacks += 1
			tide_k = 2.0 if game.build.overcharge > 0 and attacks % game.build.overcharge == 0 else 1.0
			if tide_out:
				Sfx.play("pulse")


## Hits everything the ring has reached on this pass and hasn't hit yet.
func _tide_hits(max_r: float) -> void:
	var en := game.enemies
	var p := game.player.position
	var c := en.query(p.x, p.y, max_r)
	for q in c:
		var j := en.qbuf[q]
		var u := en.uid[j]
		if tide_hit.has(u):
			continue
		var off := Vector2(en.px[j] - p.x, en.py[j] - p.y)
		var d := off.length()
		var er := en.t_radius[en.typ[j]]
		# the ring has to have reached the enemy: from inside on the way out, from outside on the way in
		if (tide_out and d - er > tide_r) or (not tide_out and d + er < tide_r):
			continue
		tide_hit[u] = true
		var dir := off / maxf(d, 0.001)
		strike(j, tide_k, dir.x * s.knockback, dir.y * s.knockback)


func draw(ci: CanvasItem) -> void:
	var p := game.player.position
	var col := Balance.C_WEAPON.lerp(Color.WHITE, 0.3) if evolved else Balance.C_WEAPON
	if evo == "tide":
		Shapes.draw_neon_ring(ci, p, maxf(tide_r, 1.0), col, 5.0, 48)
		return
	for ring in rings:
		if ring[3] > 0.0:
			continue
		var fade: float = 1.0 - clampf(ring[0] / ring[1], 0.0, 1.0)
		var w := 3.0 + fade * 3.0 + (3.0 if ring[5] else 0.0)
		Shapes.draw_neon_ring(ci, p, maxf(ring[0], 1.0), Color(Color.WHITE if ring[5] else col, 0.3 + fade * 0.7), w, 48)


func clear() -> void:
	rings.clear()
