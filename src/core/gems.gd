class_name Gems
extends Node2D
## Pickups: XP gems, heals, magnets and evolution cores.

enum { XP_S, XP_M, XP_L, HEAL, MAGNET, CORE }

var game: Game
var batches: Array[ShapeBatch] = []
var colors: Array[Color] = [Balance.C_XP, Balance.C_XP_BIG, Color(0.45, 1.0, 0.75), Color(1.0, 0.6, 0.7), Color(0.4, 0.6, 1.0), Balance.C_GOLD]

var n := 0
var x := PackedFloat32Array()
var y := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var val := PackedInt32Array()
var kind := PackedInt32Array()
var flying := PackedByteArray()
var t := 0.0
var overflow := 0  # XP from gems left far behind


func setup(g: Game) -> void:
	game = g
	var meshes: Array[Mesh] = [
		Shapes.poly_mesh(4, 5.0, 2.0, 4.0, 0.35),
		Shapes.poly_mesh(4, 7.5, 2.5, 5.0, 0.35),
		Shapes.poly_mesh(6, 10.0, 3.0, 7.0, 0.4),
		Shapes.outline_mesh(Shapes.cross_points(10.0), 2.5, 6.0, 0.35),
		Shapes.poly_mesh(0, 10.0, 3.0, 7.0, 0.25),
		Shapes.poly_mesh(-6, 16.0, 3.0, 10.0, 0.3),
	]
	for m in meshes:
		var b := ShapeBatch.new().setup(m, 128)
		add_child(b)
		batches.append(b)
	_resize(512)


func _resize(c: int) -> void:
	for arr in ["x", "y", "vx", "vy", "val", "kind", "flying"]:
		var a = get(arr)
		a.resize(c)
		set(arr, a)


func _add(px: float, py: float, k: int, v: int) -> void:
	if n >= x.size():
		_resize(x.size() * 2)
	x[n] = px
	y[n] = py
	vx[n] = 0.0
	vy[n] = 0.0
	val[n] = v
	kind[n] = k
	flying[n] = 0
	n += 1


static func _xp_kind(v: int) -> int:
	return XP_S if v < 3 else (XP_M if v < 10 else XP_L)


func drop_xp(px: float, py: float, v: int) -> void:
	if n >= Balance.GEM_MERGE_LIMIT:
		# too many gems on the floor: fold the value into the closest XP gem
		var best := -1
		var bd := 1e12
		for j in n:
			if kind[j] > XP_L:
				continue
			var d := (x[j] - px) * (x[j] - px) + (y[j] - py) * (y[j] - py)
			if d < bd:
				bd = d
				best = j
		if best >= 0:
			val[best] += v
			kind[best] = _xp_kind(val[best])
			return
	_add(px, py, _xp_kind(v), v)
	if not game.build.no_heal and randf() < Balance.HEAL_DROP_CHANCE:
		_add(px + 10.0, py, HEAL, 0)
	elif randf() < Balance.MAGNET_DROP_CHANCE:
		_add(px + 10.0, py, MAGNET, 0)


func drop_core(px: float, py: float) -> void:
	_add(px, py, CORE, 0)


func drop_heal(px: float, py: float) -> void:
	if not game.build.no_heal:
		_add(px, py, HEAL, 0)


func magnetize_near(px: float, py: float, r: float) -> void:
	var r2 := r * r
	for i in n:
		if kind[i] <= XP_L and not flying[i]:
			var ox := x[i] - px
			var oy := y[i] - py
			if ox * ox + oy * oy < r2:
				flying[i] = 1


func magnetize_all() -> void:
	for i in n:
		if kind[i] <= XP_L:
			flying[i] = 1


func clear_all() -> void:
	n = 0
	overflow = 0


func update(delta: float) -> void:
	t += delta
	var p := game.player.position
	var pick := game.build.pickup_radius
	var pick2 := pick * pick
	var collect2 := pow(Balance.PLAYER_RADIUS + 10.0, 2.0)
	var far2 := pow(game.view_radius() * 1.6, 2.0)
	var i := 0
	while i < n:
		var ox := p.x - x[i]
		var oy := p.y - y[i]
		var d2 := ox * ox + oy * oy
		if d2 > far2 and kind[i] <= XP_L:
			# left far behind: condense into the overflow pool instead of being lost
			overflow += val[i]
			_remove(i)
			continue
		if flying[i]:
			var d := sqrt(d2) + 0.001
			var sp := sqrt(vx[i] * vx[i] + vy[i] * vy[i]) + 900.0 * delta
			sp = minf(sp, 1100.0)
			vx[i] = ox / d * sp
			vy[i] = oy / d * sp
			x[i] += vx[i] * delta
			y[i] += vy[i] * delta
		elif d2 < pick2 or kind[i] == CORE and d2 < 3600.0:
			flying[i] = 1
			# small hop away first, like a magnet snapping on
			var d := sqrt(d2) + 0.001
			vx[i] = -ox / d * 120.0
			vy[i] = -oy / d * 120.0
		if d2 < collect2:
			_collect(i)
			_remove(i)
		else:
			i += 1
	if overflow >= 25:
		# drop the condensed XP somewhere on screen, ahead of the player
		var half := game.view_size() * 0.35
		var dir := game.player.facing
		_add(p.x + dir.x * half.x, p.y + dir.y * half.y, XP_L, overflow)
		overflow = 0


func _remove(i: int) -> void:
	n -= 1
	x[i] = x[n]
	y[i] = y[n]
	vx[i] = vx[n]
	vy[i] = vy[n]
	val[i] = val[n]
	kind[i] = kind[n]
	flying[i] = flying[n]


func _collect(i: int) -> void:
	match kind[i]:
		HEAL:
			game.player.heal(25.0)
			Sfx.play("heal")
		MAGNET:
			magnetize_all()
			Sfx.play("magnet")
		CORE:
			game.on_core_collected()
		_:
			game.add_xp(val[i])


func render() -> void:
	for b in batches:
		b.begin()
	var bob := sin(t * 5.0)
	for i in n:
		var k := kind[i]
		var r := t * 2.0 if k == CORE else (bob * 0.3 if k <= XP_L else 0.0)
		batches[k].add(x[i], y[i], r, 1.0, colors[k])
	for b in batches:
		b.commit()
