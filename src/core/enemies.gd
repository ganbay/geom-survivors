class_name Enemies
extends Node2D
## All enemies live in flat arrays (no nodes, no physics) and are drawn with one batch per type.
## Dead enemies are only flagged during the frame and removed in compact().

enum { CHASE, DASH, SHOOT, SPLIT, ELITE, BOSS }

const CELL := 48.0
const GW := 48
const GH := 48
const BIG_RADIUS := 32.0

var game: Game

# --- per-type tables
var type_ids: Array[String] = []
var type_index := {}
var t_sides := PackedInt32Array()
var t_radius := PackedFloat32Array()
var t_hp := PackedFloat32Array()
var t_speed := PackedFloat32Array()
var t_damage := PackedFloat32Array()
var t_xp := PackedInt32Array()
var t_mass := PackedFloat32Array()
var t_armor := PackedFloat32Array()
var t_cap := PackedFloat32Array()
var t_behavior := PackedInt32Array()
var t_color: Array[Color] = []
var batches: Array[ShapeBatch] = []

# --- per-enemy arrays
var n := 0
var cap := 0
var px := PackedFloat32Array()
var py := PackedFloat32Array()
var kx := PackedFloat32Array()
var ky := PackedFloat32Array()
var hp := PackedFloat32Array()
var mhp := PackedFloat32Array()
var typ := PackedInt32Array()
var uid := PackedInt32Array()
var flash := PackedFloat32Array()
var tmr := PackedFloat32Array()
var tmr2 := PackedFloat32Array()
var st := PackedInt32Array()
var rot := PackedFloat32Array()
var dx := PackedFloat32Array()
var dy := PackedFloat32Array()
var slow := PackedFloat32Array()
var pd2 := PackedFloat32Array()  # distance² to player, refreshed every frame
var dead := PackedByteArray()
var _next_uid := 1

# --- spatial grid (linked lists in flat arrays)
var cell_head := PackedInt32Array()
var cell_next := PackedInt32Array()
var grid_ox := 0.0
var grid_oy := 0.0
var bigs := PackedInt32Array()  # enemies too large for the grid (elites, bosses)
var qbuf := PackedInt32Array()

var boss_idx := -1
var frame := 0
var speed_mult := 1.0
var damage_mult := 1.0


func setup(g: Game) -> void:
	game = g
	for id in Balance.ENEMIES:
		var d: Dictionary = Balance.ENEMIES[id]
		type_index[id] = type_ids.size()
		type_ids.append(id)
		t_sides.append(d.sides)
		t_radius.append(d.radius)
		t_hp.append(d.hp)
		t_speed.append(d.speed)
		t_damage.append(d.damage)
		t_xp.append(d.xp)
		t_mass.append(d.mass)
		t_armor.append(d.armor)
		t_cap.append(d.cap)
		t_color.append(d.color)
		t_behavior.append(["chase", "dash", "shoot", "split", "elite", "boss"].find(d.behavior))
		var b := ShapeBatch.new()
		var glow := 10.0 if d.radius > 25.0 else 6.0
		b.setup(Shapes.poly_mesh(d.sides, d.radius, 2.5 if d.radius < 12.0 else 3.0, glow, 0.16), 64)
		add_child(b)
		batches.append(b)
	cell_head.resize(GW * GH)
	qbuf.resize(256)
	_grow(512)


func _grow(new_cap: int) -> void:
	cap = new_cap
	for arr in ["px", "py", "kx", "ky", "hp", "mhp", "typ", "uid", "flash", "tmr", "tmr2", "st", "rot", "dx", "dy", "slow", "pd2", "dead", "cell_next"]:
		var a = get(arr)
		a.resize(cap)
		set(arr, a)


func spawn(type_id: String, x: float, y: float, hp_mult := 1.0) -> int:
	if n >= cap:
		_grow(cap * 2)
	var t: int = type_index[type_id]
	var i := n
	n += 1
	px[i] = x
	py[i] = y
	kx[i] = 0.0
	ky[i] = 0.0
	hp[i] = t_hp[t] * hp_mult
	mhp[i] = hp[i]
	typ[i] = t
	uid[i] = _next_uid
	_next_uid += 1
	flash[i] = 0.0
	tmr[i] = randf_range(0.5, 1.0) * (Balance.DARTER_COOLDOWN if t_behavior[t] == DASH else Balance.SHOOTER_COOLDOWN)
	tmr2[i] = 0.0
	st[i] = 0
	rot[i] = randf() * TAU
	dx[i] = 0.0
	dy[i] = 0.0
	slow[i] = 0.0
	pd2[i] = 1e9
	dead[i] = 0
	if t_behavior[t] == BOSS:
		tmr[i] = 2.0
		boss_idx = i
	return i


func is_boss(i: int) -> bool:
	return t_behavior[typ[i]] == BOSS


func radius(i: int) -> float:
	return t_radius[typ[i]]


# ------------------------------------------------------------------ update

func update(delta: float) -> void:
	frame += 1
	_build_grid()
	var ppx := game.player.position.x
	var ppy := game.player.position.y
	var pr := Balance.PLAYER_RADIUS
	var recycle_d2 := pow(game.view_radius() + 320.0, 2.0)
	var decay := exp(-8.0 * delta)
	boss_idx = -1
	for i in n:
		if dead[i]:
			continue
		var t := typ[i]
		var ex := px[i]
		var ey := py[i]
		var ddx := ppx - ex
		var ddy := ppy - ey
		var d2 := ddx * ddx + ddy * ddy
		pd2[i] = d2
		var d := sqrt(d2) + 0.001
		var sp := t_speed[t] * speed_mult
		if slow[i] > 0.0:
			slow[i] -= delta
			sp *= 0.5
		var vx := ddx / d * sp
		var vy := ddy / d * sp
		match t_behavior[t]:
			DASH:
				tmr[i] -= delta
				if st[i] == 0:
					if tmr[i] <= 0.0 and d < 520.0:
						st[i] = 1
						tmr[i] = Balance.DARTER_TELEGRAPH
						dx[i] = ddx / d
						dy[i] = ddy / d
				elif st[i] == 1:
					vx = 0.0
					vy = 0.0
					if tmr[i] <= 0.0:
						st[i] = 2
						tmr[i] = Balance.DARTER_DASH_TIME
				else:
					vx = dx[i] * Balance.DARTER_DASH_SPEED * speed_mult
					vy = dy[i] * Balance.DARTER_DASH_SPEED * speed_mult
					if tmr[i] <= 0.0:
						st[i] = 0
						tmr[i] = Balance.DARTER_COOLDOWN
				rot[i] = atan2(vy if st[i] != 1 else dy[i], vx if st[i] != 1 else dx[i]) + PI / 2.0
			SHOOT:
				var keep := Balance.SHOOTER_RANGE
				if d < keep * 0.8:
					vx = -vx
					vy = -vy
				elif d < keep * 1.15:
					# strafe around the player
					var s := 0.6 if uid[i] % 2 == 0 else -0.6
					var tx := vx
					vx = -vy * s
					vy = tx * s
				tmr[i] -= delta
				if tmr[i] <= 0.0 and d < keep * 1.6:
					tmr[i] = Balance.SHOOTER_COOLDOWN
					var bs := Balance.ENEMY_BULLET_SPEED
					game.hostile.spawn(ex, ey, ddx / d * bs, ddy / d * bs, t_damage[t] * damage_mult, 7.0)
				rot[i] += delta * 1.5
			BOSS:
				boss_idx = i
				var v := _boss_update(i, delta, ddx / d, ddy / d, d)
				vx = v.x
				vy = v.y
			_:
				if t_sides[t] == 3:
					rot[i] = atan2(vy, vx) + PI / 2.0
				else:
					rot[i] += delta * (0.6 if t_radius[t] > 20.0 else 1.2)
		# separation (staggered: each enemy every other frame, only against its own cell)
		if t_radius[t] < BIG_RADIUS and ((i + frame) & 1) == 0:
			var c := _cell_of(ex, ey)
			if c >= 0:
				var j := cell_head[c]
				var checks := 0
				var r2 := t_radius[t] * 2.0
				while j >= 0 and checks < 5:
					if j != i:
						var ox := ex - px[j]
						var oy := ey - py[j]
						var od2 := ox * ox + oy * oy
						if od2 < r2 * r2 and od2 > 0.01:
							var od := sqrt(od2)
							var push := (r2 - od) / od * 9.0
							vx += ox * push
							vy += oy * push
						checks += 1
					j = cell_next[j]
		ex += (vx + kx[i]) * delta
		ey += (vy + ky[i]) * delta
		kx[i] *= decay
		ky[i] *= decay
		px[i] = ex
		py[i] = ey
		if flash[i] > 0.0:
			flash[i] -= delta
		# contact damage
		var reach := t_radius[t] + pr
		if d < reach:
			game.player.contact(t_damage[t] * damage_mult)
		# enemies left far behind are brought back ahead of the player
		elif d2 > recycle_d2:
			var p := game.director.spawn_point(t_radius[t])
			px[i] = p.x
			py[i] = p.y
	queue_redraw()


func _boss_update(i: int, delta: float, nx: float, ny: float, d: float) -> Vector2:
	var id := type_ids[typ[i]]
	var sp := t_speed[typ[i]] * speed_mult
	var v := Vector2(nx, ny) * sp
	tmr[i] -= delta
	var frac := hp[i] / mhp[i]
	var sides := t_sides[typ[i]]
	if id == "boss_final":
		sides = 3 + int((1.0 - frac) * 6.0)
		sides = mini(sides, 8)
		if sides != int(tmr2[i]):
			if tmr2[i] > 0.0:
				_bullet_ring(px[i], py[i], sides * 4, 0.0, 1.1)
				game.fx.shake(10.0)
				Sfx.play("boss", 0.8)
			tmr2[i] = sides
		sp *= 1.0 + (sides - 3) * 0.06
		v = Vector2(nx, ny) * sp
	rot[i] += delta * (0.5 + (sides - 3) * 0.15)
	var dmg := t_damage[typ[i]] * damage_mult * 0.6
	match st[i]:
		0:  # chase
			if tmr[i] <= 0.0:
				st[i] = 1
				tmr[i] = 0.8
				dx[i] = nx
				dy[i] = ny
		1:  # telegraph charge
			v = Vector2.ZERO
			if tmr[i] <= 0.0:
				st[i] = 2
				tmr[i] = 0.75
				Sfx.play("dash", 0.7)
		2:  # charge
			v = Vector2(dx[i], dy[i]) * 540.0 * speed_mult
			if tmr[i] <= 0.0:
				if id == "boss_tetra":
					_bullet_ring(px[i], py[i], 12, rot[i], 1.0)
					for k in 5:
						var a := TAU * k / 5.0
						spawn("dot", px[i] + cos(a) * 90.0, py[i] + sin(a) * 90.0, game.director.hp_mult)
					st[i] = 0
					tmr[i] = 2.6
				else:
					st[i] = 3
					tmr[i] = 2.8
					tmr2[i] = floorf(tmr2[i])  # fractional part = spiral fire timer
		3:  # spiral
			v *= 0.3
			var arms := 2 if id == "boss_hex" else maxi(2, sides / 2)
			dx[i] -= delta
			if dx[i] <= 0.0:
				dx[i] = 0.11
				for a in arms:
					var ang := rot[i] * 2.2 + TAU * a / arms
					game.hostile.spawn(px[i], py[i], cos(ang) * 200.0, sin(ang) * 200.0, dmg, 8.0)
			if tmr[i] <= 0.0:
				st[i] = 0
				tmr[i] = 2.4
				_bullet_ring(px[i], py[i], 16 if id == "boss_hex" else sides * 3, 0.0, 0.9)
				var summon := "hexagon" if id == "boss_hex" else ("brute" if sides > 5 else "darter")
				for k in 3:
					var a := TAU * k / 3.0 + rot[i]
					spawn(summon, px[i] + cos(a) * 110.0, py[i] + sin(a) * 110.0, game.director.hp_mult)
	return v


func _bullet_ring(x: float, y: float, count: int, offset: float, speed_scale: float) -> void:
	var dmg := 12.0 * damage_mult
	for k in count:
		var a := offset + TAU * k / count
		game.hostile.spawn(x, y, cos(a) * 170.0 * speed_scale, sin(a) * 170.0 * speed_scale, dmg, 8.0)


# ------------------------------------------------------------------ damage

## Returns damage actually dealt.
func hit(i: int, amount: float, push_x: float, push_y: float, source: String) -> float:
	if dead[i]:
		return 0.0
	var t := typ[i]
	var a := amount
	if t_armor[t] > 0.0:
		a = maxf(a - t_armor[t], a * 0.1)
	if t_cap[t] > 0.0:
		a = minf(a, t_cap[t])
	hp[i] -= a
	flash[i] = 0.09
	var m := t_mass[t]
	kx[i] += push_x / m
	ky[i] += push_y / m
	game.on_damage(a, source)
	if hp[i] <= 0.0:
		_kill(i, source)
	else:
		game.on_hit(i, a, source)
	return a


func _kill(i: int, source: String) -> void:
	dead[i] = 1
	var t := typ[i]
	var x := px[i]
	var y := py[i]
	var beh := t_behavior[t]
	game.fx.burst(x, y, t_color[t], 5 if t_radius[t] < 20.0 else 12, t_radius[t])
	if t_xp[t] > 0:
		game.gems.drop_xp(x, y, t_xp[t])
	match beh:
		SPLIT:
			for k in Balance.HEX_SPLIT_COUNT:
				var a := rot[i] + TAU * k / Balance.HEX_SPLIT_COUNT
				var c := spawn("shard", x + cos(a) * 12.0, y + sin(a) * 12.0, game.director.hp_mult)
				kx[c] = cos(a) * 160.0
				ky[c] = sin(a) * 160.0
		ELITE:
			game.gems.drop_core(x, y)
		BOSS:
			game.on_boss_killed(type_ids[t], x, y)
	game.on_kill(x, y, source)


func compact() -> void:
	var i := n - 1
	while i >= 0:
		if dead[i]:
			var last := n - 1
			if i != last:
				_move(last, i)
			n -= 1
		i -= 1


func _move(from: int, to: int) -> void:
	px[to] = px[from]
	py[to] = py[from]
	kx[to] = kx[from]
	ky[to] = ky[from]
	hp[to] = hp[from]
	mhp[to] = mhp[from]
	typ[to] = typ[from]
	uid[to] = uid[from]
	flash[to] = flash[from]
	tmr[to] = tmr[from]
	tmr2[to] = tmr2[from]
	st[to] = st[from]
	rot[to] = rot[from]
	dx[to] = dx[from]
	dy[to] = dy[from]
	slow[to] = slow[from]
	pd2[to] = pd2[from]
	dead[to] = dead[from]


func clear_all() -> void:
	n = 0


# ------------------------------------------------------------------ queries

func _build_grid() -> void:
	cell_head.fill(-1)
	bigs.clear()
	grid_ox = game.player.position.x - GW * CELL * 0.5
	grid_oy = game.player.position.y - GH * CELL * 0.5
	for i in n:
		if t_radius[typ[i]] >= BIG_RADIUS:
			bigs.append(i)
			continue
		var c := _cell_of(px[i], py[i])
		if c >= 0:
			cell_next[i] = cell_head[c]
			cell_head[c] = i


func _cell_of(x: float, y: float) -> int:
	var cx := int((x - grid_ox) / CELL)
	var cy := int((y - grid_oy) / CELL)
	if cx < 0 or cy < 0 or cx >= GW or cy >= GH:
		return -1
	return cy * GW + cx


## Fills qbuf with alive enemies overlapping the circle; returns how many.
func query(x: float, y: float, r: float) -> int:
	var count := 0
	var reach := r + BIG_RADIUS
	var cx0 := maxi(int((x - reach - grid_ox) / CELL), 0)
	var cy0 := maxi(int((y - reach - grid_oy) / CELL), 0)
	var cx1 := mini(int((x + reach - grid_ox) / CELL), GW - 1)
	var cy1 := mini(int((y + reach - grid_oy) / CELL), GH - 1)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var j := cell_head[cy * GW + cx]
			while j >= 0:
				if not dead[j]:
					var rr := r + t_radius[typ[j]]
					var ox := px[j] - x
					var oy := py[j] - y
					if ox * ox + oy * oy < rr * rr:
						if count >= qbuf.size():
							qbuf.resize(count * 2)
						qbuf[count] = j
						count += 1
				j = cell_next[j]
	for j in bigs:
		if not dead[j]:
			var rr := r + t_radius[typ[j]]
			var ox := px[j] - x
			var oy := py[j] - y
			if ox * ox + oy * oy < rr * rr:
				if count >= qbuf.size():
					qbuf.resize(count * 2)
				qbuf[count] = j
				count += 1
	return count


## Up to k nearest alive enemies to the player within max_dist.
func nearest_to_player(k: int, max_dist: float) -> PackedInt32Array:
	var best := PackedInt32Array()
	var best_d := PackedFloat32Array()
	var lim := max_dist * max_dist
	for i in n:
		var d := pd2[i]
		if dead[i] or d > lim:
			continue
		if best.size() < k:
			best.append(i)
			best_d.append(d)
		else:
			var worst := 0
			for w in range(1, best.size()):
				if best_d[w] > best_d[worst]:
					worst = w
			if d < best_d[worst]:
				best[worst] = i
				best_d[worst] = d
	return best


## Nearest alive enemy to a point (using the grid), excluding uids in `skip`. -1 if none.
func nearest_to(x: float, y: float, r: float, skip: PackedInt32Array) -> int:
	var c := query(x, y, r)
	var best := -1
	var bd := 1e12
	for q in c:
		var j := qbuf[q]
		if skip.has(uid[j]):
			continue
		var ox := px[j] - x
		var oy := py[j] - y
		var d := ox * ox + oy * oy
		if d < bd:
			bd = d
			best = j
	return best


# ------------------------------------------------------------------ render

func render() -> void:
	for b in batches:
		b.begin()
	for i in n:
		if dead[i]:
			continue
		var t := typ[i]
		if t_behavior[t] == BOSS:
			continue
		var f := flash[i]
		var col := Color(1, 1, 1) if f > 0.0 else t_color[t]
		batches[t].add(px[i], py[i], rot[i], 1.0 + maxf(f, 0.0) * 2.5, col)
	for b in batches:
		b.commit()


func _draw() -> void:
	# telegraphs and bosses: few, unique -> immediate drawing
	for i in n:
		if dead[i]:
			continue
		var t := typ[i]
		var beh := t_behavior[t]
		if beh == DASH and st[i] == 1:
			var a := Vector2(px[i], py[i])
			var blink := 0.35 + 0.35 * sin(tmr[i] * 40.0)
			Shapes.draw_neon_line(self, a, a + Vector2(dx[i], dy[i]) * Balance.DARTER_DASH_SPEED * Balance.DARTER_DASH_TIME,
					Color(Balance.C_DANGER, blink), 2.0)
		elif beh == BOSS:
			var c := Vector2(px[i], py[i])
			var sides := t_sides[t]
			if type_ids[t] == "boss_final":
				sides = maxi(3, int(tmr2[i]))
			var col := Color(1, 1, 1) if flash[i] > 0.0 else t_color[t]
			var r := t_radius[t]
			Shapes.draw_neon_poly(self, Shapes.points(sides, r, rot[i]), col, 4.0, 0.12)
			Shapes.draw_neon_poly(self, Shapes.points(sides, r * 0.55, -rot[i] * 1.7), Color(col, 0.7), 2.5)
			if st[i] == 1:
				var blink := 0.4 + 0.4 * sin(tmr[i] * 30.0)
				Shapes.draw_neon_line(self, c, c + Vector2(dx[i], dy[i]) * 405.0, Color(Balance.C_DANGER, blink), 3.0)
