extends Weapon
## Instant piercing beam(s) in the movement direction.
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
	var base := facing().angle()
	var angles: Array[float] = []
	for k in count:
		var a := base + TAU * k / count
		if evo == "density":
			angles.append_array([a - 0.28, a, a + 0.28])
		else:
			angles.append(a)
	var length: float = 480.0 * s.area
	var width: float = 10.0 * s.area
	var d := dmg()
	for a in angles:
		var dir := Vector2(cos(a), sin(a))
		_beam_hit(p, dir, length, width, d)
		game.fx.line(PackedVector2Array([p, p + dir * length]), Color(0.6, 1.0, 1.0), 0.18, width)
	Sfx.play("laser")


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
	var d := dmg() * 0.4
	for k in count:
		var a := sweep + TAU * k / count
		_beam_hit(p, Vector2(cos(a), sin(a)), 400.0 * s.area, 9.0 * s.area, d)


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
	var d := dmg() * 0.55
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
				Shapes.draw_neon_line(ci, p, p + Vector2(cos(a), sin(a)) * 400.0 * s.area, Color(0.6, 1.0, 1.0, 0.8), 5.0 * s.area)
		"sides":
			if cage_t > 0.0:
				var f := minf(cage_t / 0.3, 1.0)
				Shapes.draw_neon_poly(ci, _cage_points(), Color(0.6, 1.0, 1.0, f), 4.0 * s.area)
