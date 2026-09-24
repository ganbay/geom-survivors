extends Weapon
## Instant piercing beam(s): the first aims at the closest enemy, extra beams at random nearby enemies.
## Evolutions: density = Prism (3-beam fans) · frequency = Lighthouse (permanent sweeping beams)
##             sides = Polygon Cage (laser walls around you).

const CAGE_TIME := 1.4
const CAGE_TICK := 0.15

var sweep := 0.0
var tick := 0.0
var cage_t := 0.0
var cage_tick := 0.0
var cage_rot := 0.0


func update(delta: float) -> void:
	match evo:
		"frequency":
			_lighthouse(delta)
		"sides":
			super.update(delta)
			_cage(delta)
		_:
			super.update(delta)


func fire() -> void:
	if evo == "sides":
		cage_t = CAGE_TIME
		cage_tick = 0.0
		Sfx.play("laser", 0.7)
		return
	var p := game.player.position
	var count := int(s.count)
	var length := 480.0
	var angles: Array[float] = []
	for a in _aim_angles(p, count, length):
		if evo == "density":
			angles.append_array([a - 0.28, a, a + 0.28])
		else:
			angles.append(a)
	var width: float = 10.0 * s.area
	var d := dmg()
	for a in angles:
		var dir := Vector2(cos(a), sin(a))
		_beam_hit(p, dir, length, width, d)
		game.fx.line(PackedVector2Array([p, p + dir * length]), Color(0.6, 1.0, 1.0), 0.18, width)
	Sfx.play("laser")


## One angle per beam. Beam 0 locks the closest enemy, the rest pick random enemies among
## the nearby pack (distinct while there are enough). With no enemy in reach, beams fan
## out evenly from the movement direction.
func _aim_angles(p: Vector2, count: int, length: float) -> Array[float]:
	var en := game.enemies
	var near := en.nearest_to_player(maxi(count * 3, 8), length)
	var out: Array[float] = []
	if near.is_empty():
		var base := facing().angle()
		for k in count:
			out.append(base + TAU * k / count)
		return out
	var closest := 0
	for k in range(1, near.size()):
		if en.pd2[near[k]] < en.pd2[near[closest]]:
			closest = k
	var picks: Array = [near[closest]]
	var rest: Array = Array(near)
	rest.remove_at(closest)
	rest.shuffle()
	for k in count - 1:
		picks.append(rest[k] if k < rest.size() else near[randi() % near.size()])
	for j in picks:
		out.append(Vector2(en.px[j] - p.x, en.py[j] - p.y).angle())
	return out


func _beam_hit(p: Vector2, dir: Vector2, length: float, width: float, d: float) -> void:
	var en := game.enemies
	for j in en.n:
		if en.dead[j]:
			continue
		var ex := en.px[j] - p.x
		var ey := en.py[j] - p.y
		var along := ex * dir.x + ey * dir.y
		if along < 0.0 or along > length:
			continue
		var perp := absf(ex * dir.y - ey * dir.x)
		if perp < width + en.t_radius[en.typ[j]]:
			var crit := randf() < game.build.crit
			en.hit(j, d * (Balance.CRIT_MULT if crit else 1.0), dir.x * s.knockback, dir.y * s.knockback, display_name())


## Lighthouse: beams never switch off and rotate around the player.
func _lighthouse(delta: float) -> void:
	sweep += delta * 2.4
	tick -= delta
	if tick > 0.0:
		return
	tick = 0.1
	var p := game.player.position
	var count := int(s.count)
	var d := dmg() * 0.7
	for k in count:
		var a := sweep + TAU * k / count
		_beam_hit(p, Vector2(cos(a), sin(a)), 400.0, 9.0 * s.area, d)


## Polygon Cage: a laser polygon follows the player and burns enemies touching its edges.
func _cage(delta: float) -> void:
	cage_rot += delta * 0.6
	if cage_t <= 0.0:
		return
	cage_t -= delta
	cage_tick -= delta
	if cage_tick > 0.0:
		return
	cage_tick = CAGE_TICK
	var p := game.player.position
	var pts := _cage_points()
	var en := game.enemies
	var r: float = 175.0 * s.area
	var c := en.query(p.x, p.y, r + 40.0)
	var width: float = 10.0 * s.area
	var d := dmg() * 0.7
	var targets := en.qbuf.slice(0, c)
	for j in targets:
		var e := Vector2(en.px[j], en.py[j])
		var er := en.t_radius[en.typ[j]]
		for k in pts.size():
			var a := pts[k]
			var b := pts[(k + 1) % pts.size()]
			if Geometry2D.get_closest_point_to_segment(e, a, b).distance_to(e) < width + er:
				var crit := randf() < game.build.crit
				var out := (e - p).normalized()
				en.hit(j, d * (Balance.CRIT_MULT if crit else 1.0), out.x * 60.0, out.y * 60.0, display_name())
				break


func _cage_points() -> PackedVector2Array:
	var sides := 5 + int(s.count)
	return Transform2D(0.0, game.player.position) * Shapes.points(sides, 175.0 * s.area, cage_rot)


func draw(ci: CanvasItem) -> void:
	match evo:
		"frequency":
			var p := game.player.position
			for k in int(s.count):
				var a := sweep + TAU * k / int(s.count)
				Shapes.draw_neon_line(ci, p, p + Vector2(cos(a), sin(a)) * 400.0, Color(0.6, 1.0, 1.0, 0.8), 5.0 * s.area)
		"sides":
			if cage_t > 0.0:
				var f := minf(cage_t / 0.3, 1.0)
				Shapes.draw_neon_poly(ci, _cage_points(), Color(0.6, 1.0, 1.0, f), 4.0 * s.area)
