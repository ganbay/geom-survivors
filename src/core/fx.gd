class_name Fx
extends Node2D
## Particles (batched streaks), expanding rings, beams/arcs and screen shake.

const MAX_PARTICLES := 500

var game: Game
var batch: ShapeBatch
var n := 0
var x := PackedFloat32Array()
var y := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var life := PackedFloat32Array()
var max_life := PackedFloat32Array()
var col: Array[Color] = []

# rings: [x, y, radius, color, life, max_life, width]
var rings: Array = []
# lines: [PackedVector2Array, color, life, max_life, width]
var lines: Array = []

var shake_amount := 0.0
var shake_offset := Vector2.ZERO
var particle_budget := 1.0  # lowered on slow devices


func setup(g: Game) -> void:
	game = g
	material = Shapes.get_add_material()
	batch = ShapeBatch.new().setup(Shapes.streak_mesh(), 256)
	add_child(batch)
	for arr in ["x", "y", "vx", "vy", "life", "max_life"]:
		var a = get(arr)
		a.resize(MAX_PARTICLES)
		set(arr, a)
	col.resize(MAX_PARTICLES)


func particle(px: float, py: float, pvx: float, pvy: float, l: float, c: Color) -> void:
	if n >= MAX_PARTICLES:
		return
	x[n] = px
	y[n] = py
	vx[n] = pvx
	vy[n] = pvy
	life[n] = l
	max_life[n] = l
	col[n] = c
	n += 1


func burst(px: float, py: float, c: Color, count: int, r: float) -> void:
	count = int(count * particle_budget)
	for k in count:
		var a := randf() * TAU
		var s := randf_range(80.0, 260.0) * (1.0 + r / 40.0)
		particle(px + cos(a) * r * 0.5, py + sin(a) * r * 0.5, cos(a) * s, sin(a) * s, randf_range(0.25, 0.5), c)
	if r > 25.0:
		ring(px, py, r * 2.5, c, 0.35)


func crit_spark(px: float, py: float) -> void:
	if particle_budget < 0.6:
		return
	for k in 2:
		var a := randf() * TAU
		particle(px, py, cos(a) * 300.0, sin(a) * 300.0, 0.15, Balance.C_GOLD)


func ring(px: float, py: float, radius: float, c: Color, l: float, width := 3.0) -> void:
	rings.append([px, py, radius, c, l, l, width])


func line(pts: PackedVector2Array, c: Color, l: float, width := 3.0) -> void:
	lines.append([pts, c, l, l, width])


func shake(amount: float) -> void:
	if Save.get_setting("shake", true):
		shake_amount = maxf(shake_amount, amount)


func clear_all() -> void:
	n = 0
	rings.clear()
	lines.clear()


func update(delta: float) -> void:
	var drag := exp(-5.0 * delta)
	var i := 0
	while i < n:
		life[i] -= delta
		if life[i] <= 0.0:
			n -= 1
			x[i] = x[n]
			y[i] = y[n]
			vx[i] = vx[n]
			vy[i] = vy[n]
			life[i] = life[n]
			max_life[i] = max_life[n]
			col[i] = col[n]
			continue
		x[i] += vx[i] * delta
		y[i] += vy[i] * delta
		vx[i] *= drag
		vy[i] *= drag
		i += 1
	for k in range(rings.size() - 1, -1, -1):
		rings[k][4] -= delta
		if rings[k][4] <= 0.0:
			rings.remove_at(k)
	for k in range(lines.size() - 1, -1, -1):
		lines[k][2] -= delta
		if lines[k][2] <= 0.0:
			lines.remove_at(k)
	if shake_amount > 0.1:
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
		shake_amount *= exp(-12.0 * delta)
	else:
		shake_amount = 0.0
		shake_offset = Vector2.ZERO
	queue_redraw()


func render() -> void:
	batch.begin()
	for i in n:
		var f := life[i] / max_life[i]
		var c := col[i]
		c.a = f
		batch.add_stretched(x[i], y[i], atan2(vy[i], vx[i]), 0.6 + f * 1.2, 1.0, c)
	batch.commit()


func _draw() -> void:
	for r in rings:
		var f: float = r[4] / r[5]
		var rad: float = r[2] * (1.0 - f * f * 0.6)
		var c: Color = r[3]
		Shapes.draw_neon_ring(self, Vector2(r[0], r[1]), rad, Color(c, f), r[6] * f + 0.5, 32)
	for l in lines:
		var f: float = l[2] / l[3]
		var c: Color = l[1]
		Shapes.draw_neon_polyline(self, l[0], Color(c, f), l[4] * (0.4 + f * 0.6))
