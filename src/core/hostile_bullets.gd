class_name HostileBullets
extends Node2D
## Enemy bullets. Slow, readable, red.

var game: Game
var batch: ShapeBatch
var n := 0
var x := PackedFloat32Array()
var y := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var life := PackedFloat32Array()
var dmg := PackedFloat32Array()
var rad := PackedFloat32Array()


func setup(g: Game) -> void:
	game = g
	batch = ShapeBatch.new().setup(Shapes.poly_mesh(0, 7.0, 3.0, 7.0, 0.95), 64)
	add_child(batch)
	_resize(128)


func _resize(c: int) -> void:
	for arr in ["x", "y", "vx", "vy", "life", "dmg", "rad"]:
		var a = get(arr)
		a.resize(c)
		set(arr, a)


func spawn(px: float, py: float, pvx: float, pvy: float, p_dmg: float, r: float) -> void:
	if n >= x.size():
		_resize(x.size() * 2)
	x[n] = px
	y[n] = py
	vx[n] = pvx
	vy[n] = pvy
	life[n] = 4.5
	dmg[n] = p_dmg
	rad[n] = r
	n += 1


## Removes enemy bullets within r of a point; returns how many.
func destroy_near(px: float, py: float, r: float) -> int:
	var removed := 0
	var i := 0
	while i < n:
		var ox := x[i] - px
		var oy := y[i] - py
		var rr := r + rad[i]
		if ox * ox + oy * oy < rr * rr:
			removed += 1
			game.fx.burst(x[i], y[i], Color(1.0, 0.4, 0.3), 3, 4.0)
			n -= 1
			x[i] = x[n]
			y[i] = y[n]
			vx[i] = vx[n]
			vy[i] = vy[n]
			life[i] = life[n]
			dmg[i] = dmg[n]
			rad[i] = rad[n]
		else:
			i += 1
	return removed


func clear_all() -> void:
	n = 0


func update(delta: float) -> void:
	var p := game.player.position
	var pr := Balance.PLAYER_RADIUS * 0.8  # forgiving hitbox
	var i := 0
	while i < n:
		x[i] += vx[i] * delta
		y[i] += vy[i] * delta
		life[i] -= delta
		var ox := x[i] - p.x
		var oy := y[i] - p.y
		var rr := rad[i] + pr
		var hit := ox * ox + oy * oy < rr * rr
		if hit:
			game.player.contact(dmg[i])
		if hit or life[i] <= 0.0:
			n -= 1
			x[i] = x[n]
			y[i] = y[n]
			vx[i] = vx[n]
			vy[i] = vy[n]
			life[i] = life[n]
			dmg[i] = dmg[n]
			rad[i] = rad[n]
		else:
			i += 1


func render() -> void:
	batch.begin()
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.02)
	for i in n:
		batch.add(x[i], y[i], 0.0, rad[i] / 7.0, Color(1.0, 0.3 * pulse, 0.15))
	batch.commit()
