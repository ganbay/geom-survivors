extends Weapon
## Rods reach out from the Square, evenly spaced, and sweep around it, hitting each enemy once per pass.
## `area` is rod length; `speed` and cooldown reduction both add spin.
## Level-10 forms: saturn = Saturn (outer rods spinning the other way) · aegis = Aegis (short rods that eat
##                 enemy bullets) · horizon = Event Horizon (rods drag enemies in).

const LENGTH := 90.0
const HALF_WIDTH := 7.0

var angle := 0.0
var rehit := {}  # enemy uid -> time when it can be hit again
var prune_t := 5.0
var rods: Array = []  # [from, to] in world space
var body_rods := 0   # rods[0..body_rods) grow from the body; the rest are Saturn's outer set
var half_w := HALF_WIDTH
var reach := 0.0


func update(delta: float) -> void:
	# a rod has no cooldown of its own: cutting it shortens the sweep instead
	var spin: float = s.speed * data.base.cooldown / cooldown()
	angle += spin * delta
	var pl := game.player
	pl.body_rot = angle
	var p := pl.position
	var count := int(s.count)
	half_w = HALF_WIDTH * s.width
	var inner := Balance.PLAYER_RADIUS + 2.0
	reach = inner + LENGTH * s.area * (0.75 if evo == "aegis" else 1.0)
	rods.clear()
	for i in count:
		var dir := Vector2.from_angle(angle + TAU * i / count)
		rods.append([p + dir * inner * 0.8, p + dir * reach])
	body_rods = rods.size()
	if evo == "saturn":
		for i in count:
			var dir := Vector2.from_angle(-angle * 0.8 + TAU * (i + 0.5) / count)
			rods.append([p + dir * reach * 1.1, p + dir * reach * 1.8])
	if evo == "horizon":
		_gravity(p, delta)
	var en := game.enemies
	var now := game.time
	# an enemy can be hit again once the next rod is about to arrive
	var cd := maxf(TAU / count / spin * 0.5, 0.05)
	var hit_k := 1.5 if evo == "aegis" else 1.0
	var kb: float = s.knockback
	for rod in rods:
		var a: Vector2 = rod[0]
		var ab: Vector2 = rod[1] - a
		var len2 := ab.length_squared()
		var mid := a + ab * 0.5
		var c := en.query(mid.x, mid.y, sqrt(len2) * 0.5 + half_w)
		for q in c:
			var j := en.qbuf[q]
			var u := en.uid[j]
			if rehit.get(u, 0.0) > now:
				continue
			var e := Vector2(en.px[j], en.py[j])
			var lim := half_w + en.t_radius[en.typ[j]]
			if e.distance_squared_to(a + ab * clampf((e - a).dot(ab) / len2, 0.0, 1.0)) > lim * lim:
				continue
			rehit[u] = now + cd
			var push := (e - p).normalized() * kb
			_hit(j, hit_k, push)
		if evo == "aegis":
			for f in [0.2, 0.5, 0.8]:
				var at: Vector2 = a + ab * f
				game.hostile.destroy_near(at.x, at.y, half_w + 10.0)
	prune_t -= delta
	if prune_t <= 0.0:
		prune_t = 5.0
		for u in rehit.keys():
			if rehit[u] < now:
				rehit.erase(u)


## Rods have no attacks to count, so every hit counts as one for Overcharge and Double Tap.
func _hit(j: int, hit_k: float, push: Vector2) -> void:
	var b := game.build
	attacks += 1
	charged = b.overcharge > 0 and attacks % b.overcharge == 0
	strike(j, k(hit_k), push.x, push.y)
	charged = false
	if b.echo > 0 and attacks % b.echo == 0 and not game.enemies.dead[j]:
		strike(j, hit_k, push.x, push.y)


## Event Horizon: enemies around the rods are dragged in until they're well inside the sweep.
func _gravity(p: Vector2, delta: float) -> void:
	var en := game.enemies
	var c := en.query(p.x, p.y, reach * 1.8)
	for q in c:
		var j := en.qbuf[q]
		if en.is_boss(j):
			continue
		var ox := en.px[j] - p.x
		var oy := en.py[j] - p.y
		var d := sqrt(ox * ox + oy * oy) + 0.001
		if d < reach * 0.6:
			continue
		var pull := 1000.0 * delta / en.t_mass[en.typ[j]]
		en.kx[j] -= ox / d * pull
		en.ky[j] -= oy / d * pull


func draw(ci: CanvasItem) -> void:
	var col := Balance.C_WEAPON.lerp(Color.WHITE, 0.3) if evolved else Balance.C_WEAPON
	if evo == "horizon":
		Shapes.draw_neon_ring(ci, game.player.position, reach * 1.8, Color(col, 0.15), 1.5, 48)
	for i in rods.size():
		var c := col if i < body_rods else Color(col, 0.7)
		Shapes.draw_neon_line(ci, rods[i][0], rods[i][1], c, half_w)
