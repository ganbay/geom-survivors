class_name Enemies
extends Node2D
## All enemies live in flat arrays (no nodes, no physics) and are drawn with one batch per type.
## Dead enemies are only flagged during the frame and removed in compact().

enum { CHASE, DASH, SHOOT, SPLIT, ELITE, BOSS }

const CELL := 48.0
const GW := 48
const GH := 48
const BIG_RADIUS := 32.0
const TETRA_CHARGE_SPEED := 620.0
const TETRA_CHARGE_TIME := 0.5
const POLY_CHARGE_SPEED := 540.0
const POLY_CHARGE_TIME := 0.75
const PRISM_BEAM_LEN := 900.0
const PRISM_BEAM_WIDTH := 10.0
const PRISM_SPIN := 0.55
const VOID_PULL := 40.0
const VOID_HORIZON_PULL := 115.0
const BOSS_LEASH := 420.0
const BOSS_CATCHUP_SPEED := 270.0

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
var boss_state := {}   # uid -> Dictionary of per-boss pattern state
var hazards: Array = []  # boss telegraphs that go off after a delay, see _update_hazards()


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
	_update_hazards(delta)
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
				# leash: a boss left far behind closes the gap fast, so it can't simply be outrun
				if d > BOSS_LEASH:
					v = v.lerp(Vector2(ddx, ddy) / d * BOSS_CATCHUP_SPEED * speed_mult, clampf((d - BOSS_LEASH) / 200.0, 0.0, 1.0))
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


# ------------------------------------------------------------------ bosses
# Every boss has its own pattern. Shared per-enemy fields: st = phase, tmr = phase timer,
# dx/dy = charge direction. Anything else lives in boss_state[uid].

func _bs(i: int) -> Dictionary:
	var u := uid[i]
	if not boss_state.has(u):
		boss_state[u] = {}
	return boss_state[u]


func _boss_update(i: int, delta: float, nx: float, ny: float, d: float) -> Vector2:
	tmr[i] -= delta
	match type_ids[typ[i]]:
		"boss_tetra":
			return _boss_tetra(i, delta, nx, ny)
		"boss_penta":
			return _boss_penta(i, delta, nx, ny, d)
		"boss_hex":
			return _boss_hex(i, delta, nx, ny)
		"boss_prism":
			return _boss_prism(i, delta, nx, ny, d)
		"boss_void":
			return _boss_void(i, delta, nx, ny, d)
	return _boss_polygon(i, delta, nx, ny)


func _boss_dmg(i: int) -> float:
	return t_damage[typ[i]] * damage_mult * 0.6


func _boss_speed(i: int) -> float:
	return t_speed[typ[i]] * speed_mult


func _boss_windup(i: int, nx: float, ny: float, wind: float) -> void:
	st[i] = 1
	tmr[i] = wind
	_bs(i).wind = wind
	dx[i] = nx
	dy[i] = ny


func _boss_summon(i: int, id: String, count: int, dist: float) -> void:
	for k in count:
		var a := TAU * k / count + rot[i]
		spawn(id, px[i] + cos(a) * dist, py[i] + sin(a) * dist, game.director.hp_mult)


## TETRAGON PRIME: three charges in a row, each re-aimed with a shorter wind-up, then a slam.
func _boss_tetra(i: int, delta: float, nx: float, ny: float) -> Vector2:
	var bs := _bs(i)
	rot[i] += delta * 0.6
	match st[i]:
		0:  # chase
			if tmr[i] <= 0.0:
				bs.combo = 0
				_boss_windup(i, nx, ny, 0.8)
			return Vector2(nx, ny) * _boss_speed(i)
		1:  # wind-up
			if tmr[i] <= 0.0:
				st[i] = 2
				tmr[i] = TETRA_CHARGE_TIME
				Sfx.play("dash", 0.7)
			return Vector2.ZERO
		2:  # charge
			if tmr[i] <= 0.0:
				bs.combo += 1
				_bullet_ring(px[i], py[i], 6, rot[i], 0.8)
				if bs.combo < 3:
					_boss_windup(i, nx, ny, 0.42)
				else:
					st[i] = 3
					tmr[i] = 0.7
			return Vector2(dx[i], dy[i]) * TETRA_CHARGE_SPEED * speed_mult
		_:  # slam
			if tmr[i] <= 0.0:
				_bullet_ring(px[i], py[i], 16, rot[i], 1.0)
				game.fx.ring(px[i], py[i], 170.0, t_color[typ[i]], 0.4, 5.0)
				game.fx.shake(8.0)
				_boss_summon(i, "dot", 5, 90.0)
				st[i] = 0
				tmr[i] = 2.6
			return Vector2.ZERO


## PENTARCH: circles you at mid range and shells you. Mortars land where you are and where you're heading,
## aimed five-shot fans, and every third volley a pentagram of blasts closes around you.
func _boss_penta(i: int, delta: float, nx: float, ny: float, d: float) -> Vector2:
	var bs := _bs(i)
	rot[i] += delta * 0.8
	var sp := _boss_speed(i)
	var v := Vector2(nx, ny) * sp
	if d < 220.0:
		v = Vector2(-ny, nx) * sp * 0.6  # circles you instead of retreating: melee builds can still reach it
	var dmg := _boss_dmg(i)
	if bs.get("fans", 0) > 0:
		bs.fan_t -= delta
		if bs.fan_t <= 0.0:
			bs.fans -= 1
			bs.fan_t = 0.28
			_bullet_fan(px[i], py[i], atan2(ny, nx), 5, 0.55, 230.0, dmg)
	if tmr[i] <= 0.0:
		var cycle: int = bs.get("cycle", 0)
		bs.cycle = cycle + 1
		var pp := game.player.position
		match cycle % 3:
			0:  # mortars: on you, ahead of you, and somewhere between
				var lead := game.player.velocity
				_add_blast(pp, 75.0, 1.1, dmg * 1.5)
				_add_blast(pp + lead, 75.0, 1.35, dmg * 1.5)
				_add_blast(pp + lead * 0.5 + Vector2.from_angle(randf() * TAU) * 130.0, 75.0, 1.6, dmg * 1.5)
				tmr[i] = 2.4
			1:  # fans
				bs.fans = 3
				bs.fan_t = 0.0
				tmr[i] = 2.2
			_:  # pentagram: stay inside until the outer blasts go off, then get out
				for k in 5:
					_add_blast(pp + Vector2.from_angle(-PI / 2.0 + TAU * k / 5.0) * 130.0, 70.0, 1.0, dmg * 1.5)
				_add_blast(pp, 80.0, 1.9, dmg * 1.5)
				tmr[i] = 3.0
				if hp[i] < mhp[i] * 0.5:
					_boss_summon(i, "darter", 3, 100.0)
		Sfx.play("shoot", 0.5)
	return v


## HEXCORE: a slow fortress. Creeps forward firing a spiral (direction flips every time, 4 arms when hurt),
## then vents a ring and summons hexagons.
func _boss_hex(i: int, delta: float, nx: float, ny: float) -> Vector2:
	var bs := _bs(i)
	match st[i]:
		0:
			rot[i] += delta * 0.4
			if tmr[i] <= 0.0:
				st[i] = 1
				tmr[i] = 3.2
				bs.dir = -bs.get("dir", 1.0)
				bs.fire_t = 0.0
			return Vector2(nx, ny) * _boss_speed(i)
		_:
			rot[i] += delta * 2.4 * bs.dir
			bs.fire_t -= delta
			if bs.fire_t <= 0.0:
				bs.fire_t = 0.1
				var arms := 4 if hp[i] < mhp[i] * 0.5 else 3
				for a in arms:
					var ang := rot[i] + TAU * a / arms
					game.hostile.spawn(px[i], py[i], cos(ang) * 200.0, sin(ang) * 200.0, _boss_dmg(i), 8.0)
			if tmr[i] <= 0.0:
				_bullet_ring(px[i], py[i], 18, rot[i], 0.9)
				_boss_summon(i, "hexagon", 3, 110.0)
				st[i] = 0
				tmr[i] = 2.6
			return Vector2(nx, ny) * _boss_speed(i) * 0.35  # keeps creeping while it fires


## OCTAPRISM: laser beams (4, or 8 below half HP) that show a warning, then sweep around it.
## Every other cycle it blinks next to you instead.
func _boss_prism(i: int, delta: float, nx: float, ny: float, d: float) -> Vector2:
	var bs := _bs(i)
	match st[i]:
		0:  # drift to mid range
			rot[i] += delta * 0.5
			if tmr[i] <= 0.0:
				var cycle: int = bs.get("cycle", 0)
				bs.cycle = cycle + 1
				if cycle % 2 == 1:
					st[i] = 3
					tmr[i] = 0.8
					bs.target = game.player.position + Vector2.from_angle(randf() * TAU) * 190.0
				else:
					st[i] = 1
					tmr[i] = 1.1
					bs.beams = 8 if hp[i] < mhp[i] * 0.5 else 4
					bs.ang = atan2(ny, nx) + PI / bs.beams  # start between beams: you see them coming
					bs.spin = PRISM_SPIN * (1.0 if randf() < 0.5 else -1.0)
			return Vector2(nx, ny) * _boss_speed(i) * (1.0 if d > 200.0 else 0.0)
		1:  # beam warning
			if tmr[i] <= 0.0:
				st[i] = 2
				tmr[i] = 3.2
				Sfx.play("laser", 0.6)
			return Vector2.ZERO
		2:  # beams sweep
			bs.ang += bs.spin * delta
			rot[i] = bs.ang
			var pp := game.player.position - Vector2(px[i], py[i])
			for k in bs.beams:
				var dir := Vector2.from_angle(bs.ang + TAU * k / bs.beams)
				var along := pp.dot(dir)
				if along > 0.0 and along < PRISM_BEAM_LEN and absf(pp.cross(dir)) < PRISM_BEAM_WIDTH + Balance.PLAYER_RADIUS * 0.6:
					game.player.contact(_boss_dmg(i) * 1.3)
			if tmr[i] <= 0.0:
				st[i] = 0
				tmr[i] = 1.6
			return Vector2.ZERO
		_:  # blink
			if tmr[i] <= 0.0:
				var to: Vector2 = bs.target
				game.fx.burst(px[i], py[i], t_color[typ[i]], 16, t_radius[typ[i]])
				px[i] = to.x
				py[i] = to.y
				_bullet_ring(to.x, to.y, 16, rot[i], 0.9)
				game.fx.ring(to.x, to.y, 120.0, t_color[typ[i]], 0.35, 4.0)
				Sfx.play("dash", 0.5)
				st[i] = 0
				tmr[i] = 1.4
			return Vector2.ZERO


## THE SINGULARITY: always drags you in a little. Alternates between a collapsing bullet ring around you
## (one gap to escape through) and an event horizon: a strong pull while it sprays outward rings.
func _boss_void(i: int, delta: float, nx: float, ny: float, d: float) -> Vector2:
	var bs := _bs(i)
	rot[i] += delta * 0.7
	var pull := VOID_PULL
	var v := Vector2(nx, ny) * _boss_speed(i)
	match st[i]:
		0:
			if tmr[i] <= 0.0:
				var cycle: int = bs.get("cycle", 0)
				bs.cycle = cycle + 1
				if hp[i] < mhp[i] * 0.5:
					_boss_summon(i, "shard", 5, 90.0)
				if cycle % 2 == 0:
					var pp := game.player.position
					hazards.append({"kind": "collapse", "x": pp.x, "y": pp.y, "r": 310.0, "t": 1.0, "warn": 1.0,
							"dmg": _boss_dmg(i), "count": 30, "gap": randi() % 30, "gap_n": 4})
					tmr[i] = 2.6
				else:
					st[i] = 1
					tmr[i] = 0.9
		1:  # horizon forming
			v = Vector2.ZERO
			if tmr[i] <= 0.0:
				st[i] = 2
				tmr[i] = 2.8
				bs.fire_t = 0.0
				Sfx.play("boss", 1.4)
		_:  # event horizon
			v = Vector2.ZERO
			pull = VOID_HORIZON_PULL
			bs.fire_t -= delta
			if bs.fire_t <= 0.0:
				bs.fire_t = 0.55
				bs.flip = not bs.get("flip", false)
				_bullet_ring(px[i], py[i], 14, PI / 14.0 if bs.flip else 0.0, 0.7)
			if tmr[i] <= 0.0:
				st[i] = 0
				tmr[i] = 2.2
	if d < 900.0:
		game.player.position -= Vector2(nx, ny) * pull * delta
	return v


## THE POLYGON: gains a side for every sixth of its HP lost (bullet burst on each change),
## charges, then fires a spiral whose arm count grows with its sides.
func _boss_polygon(i: int, delta: float, nx: float, ny: float) -> Vector2:
	var frac := hp[i] / mhp[i]
	var sides := mini(3 + int((1.0 - frac) * 6.0), 8)
	if sides != int(tmr2[i]):
		if tmr2[i] > 0.0:
			_bullet_ring(px[i], py[i], sides * 4, 0.0, 1.1)
			game.fx.shake(10.0)
			Sfx.play("boss", 0.8)
		tmr2[i] = sides
	var sp := _boss_speed(i) * (1.0 + (sides - 3) * 0.06)
	rot[i] += delta * (0.5 + (sides - 3) * 0.15)
	match st[i]:
		0:  # chase
			if tmr[i] <= 0.0:
				_boss_windup(i, nx, ny, 0.8)
			return Vector2(nx, ny) * sp
		1:  # wind-up
			if tmr[i] <= 0.0:
				st[i] = 2
				tmr[i] = POLY_CHARGE_TIME
				Sfx.play("dash", 0.7)
			return Vector2.ZERO
		2:  # charge
			if tmr[i] <= 0.0:
				st[i] = 3
				tmr[i] = 2.8
				_bs(i).fire_t = 0.0
			return Vector2(dx[i], dy[i]) * POLY_CHARGE_SPEED * speed_mult
		_:  # spiral
			var bs := _bs(i)
			var arms := maxi(2, sides / 2)
			bs.fire_t -= delta
			if bs.fire_t <= 0.0:
				bs.fire_t = 0.11
				for a in arms:
					var ang := rot[i] * 2.2 + TAU * a / arms
					game.hostile.spawn(px[i], py[i], cos(ang) * 200.0, sin(ang) * 200.0, _boss_dmg(i), 8.0)
			if tmr[i] <= 0.0:
				st[i] = 0
				tmr[i] = 2.4
				_bullet_ring(px[i], py[i], sides * 3, 0.0, 0.9)
				_boss_summon(i, "brute" if sides > 5 else "darter", 3, 110.0)
			return Vector2(nx, ny) * sp * 0.3


func _bullet_ring(x: float, y: float, count: int, offset: float, speed_scale: float) -> void:
	var dmg := 12.0 * damage_mult
	for k in count:
		var a := offset + TAU * k / count
		game.hostile.spawn(x, y, cos(a) * 170.0 * speed_scale, sin(a) * 170.0 * speed_scale, dmg, 8.0)


func _bullet_fan(x: float, y: float, ang: float, count: int, spread: float, speed: float, dmg: float) -> void:
	for k in count:
		var a := ang + spread * (float(k) / (count - 1) - 0.5)
		game.hostile.spawn(x, y, cos(a) * speed, sin(a) * speed, dmg, 7.0)


# ------------------------------------------------------------------ boss hazards (telegraphed attacks)

func _add_blast(p: Vector2, r: float, warn: float, dmg: float) -> void:
	hazards.append({"kind": "blast", "x": p.x, "y": p.y, "r": r, "t": warn, "warn": warn, "dmg": dmg})


func _update_hazards(delta: float) -> void:
	var k := hazards.size() - 1
	while k >= 0:
		var h: Dictionary = hazards[k]
		h.t -= delta
		if h.t <= 0.0:
			hazards.remove_at(k)
			_trigger_hazard(h)
		k -= 1


func _trigger_hazard(h: Dictionary) -> void:
	match h.kind:
		"blast":
			game.fx.ring(h.x, h.y, h.r, Balance.C_DANGER, 0.3, 5.0)
			game.fx.burst(h.x, h.y, Color(1.0, 0.5, 0.2), 8, h.r * 0.5)
			game.fx.shake(3.0)
			if game.player.position.distance_to(Vector2(h.x, h.y)) < h.r + Balance.PLAYER_RADIUS * 0.5:
				game.player.contact(h.dmg)
		"collapse":
			var sp := 150.0
			for k in h.count:
				if _in_gap(h, k):
					continue
				var dir := Vector2.from_angle(TAU * k / h.count)
				var p: Vector2 = Vector2(h.x, h.y) + dir * h.r
				game.hostile.spawn(p.x, p.y, -dir.x * sp, -dir.y * sp, h.dmg, 8.0, h.r * 1.7 / sp)


func _in_gap(h: Dictionary, k: int) -> bool:
	return posmod(k - int(h.gap), int(h.count)) < int(h.gap_n)


func _draw_hazards() -> void:
	for h in hazards:
		var c := Vector2(h.x, h.y)
		var prog := 1.0 - clampf(h.t / h.warn, 0.0, 1.0)
		match h.kind:
			"blast":
				draw_circle(c, h.r * prog, Color(Balance.C_DANGER, 0.16))
				Shapes.draw_neon_ring(self, c, h.r, Color(Balance.C_DANGER, 0.35 + 0.4 * prog), 2.0, 32)
			"collapse":
				var blink := 0.35 + 0.35 * sin(h.t * 30.0)
				for k in h.count:
					if not _in_gap(h, k):
						draw_circle(c + Vector2.from_angle(TAU * k / h.count) * h.r, 4.0 + prog * 3.0, Color(Balance.C_DANGER, blink))


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
			boss_state.erase(uid[i])
			game.on_boss_killed(type_ids[t], x, y)
	game.on_kill(x, y, source)


func compact() -> void:
	var i := n - 1
	while i >= 0:
		if dead[i]:
			var last := n - 1
			if i == boss_idx:
				boss_idx = -1
			if i != last:
				_move(last, i)
				if boss_idx == last:
					boss_idx = i
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
	hazards.clear()


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
	_draw_hazards()
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
			_draw_boss(i)


## Bosses are drawn by hand (they are few): a breathing hull, a counter-rotating core,
## sparks orbiting the vertices, cracks as HP drops, and each boss's own telegraphs.
func _draw_boss(i: int) -> void:
	var t := typ[i]
	var id := type_ids[t]
	var c := Vector2(px[i], py[i])
	var sides := t_sides[t]
	if id == "boss_final":
		sides = maxi(3, int(tmr2[i]))
	var base_col := t_color[t]
	var col := Color(1, 1, 1) if flash[i] > 0.0 else base_col
	var r := t_radius[t]
	var now := game.time
	var frac := clampf(hp[i] / mhp[i], 0.0, 1.0)
	var state := st[i]
	var bs := _bs(i)
	var charger := id == "boss_tetra" or id == "boss_final"
	# breathing: faster and deeper when hurt, squashes while winding up a charge
	var pulse := 1.0 + sin(now * (3.0 + (1.0 - frac) * 4.0)) * 0.05
	var squash := Vector2.ONE
	if charger and state == 1:
		var k := 1.0 - clampf(tmr[i] / bs.get("wind", 0.8), 0.0, 1.0)
		squash = Vector2(1.0 + k * 0.18, 1.0 - k * 0.12)
	elif charger and state == 2:
		pulse *= 1.08
	var xf := Transform2D(rot[i], squash * pulse, 0.0, c)

	# outer aura ring: hot while attacking
	var attacking := state >= 1 and (state <= 2 or not charger)
	var aura_col := Balance.C_DANGER if attacking else base_col
	Shapes.draw_neon_ring(self, c, r * (1.35 + sin(now * 2.0) * 0.06), Color(aura_col, 0.25 + (0.35 if state == 1 else 0.0)), 2.0, 48)
	# hull and counter-rotating core
	Shapes.draw_neon_poly(self, xf * Shapes.points(sides, r, 0.0), col, 4.0, 0.14 + (1.0 - frac) * 0.12)
	var core_xf := Transform2D(-rot[i] * 2.7 - now, Vector2.ONE * pulse, 0.0, c)
	Shapes.draw_neon_poly(self, core_xf * Shapes.points(sides, r * 0.5, 0.0), Color(col, 0.8), 2.5)
	Shapes.draw_neon_ring(self, c, r * (0.16 + 0.04 * sin(now * 8.0)), Color(1, 1, 1, 0.85), 2.0, 16)
	# spokes from core to hull vertices, and sparks orbiting just outside
	var sparks := 8 if sides == 0 else sides
	if sides > 0:
		for v in xf * Shapes.points(sides, r, 0.0):
			draw_line(c, c.lerp(v, 0.9), Color(col, 0.25), 1.5)
	for k in sparks:
		var a := rot[i] + TAU * k / sparks + now * 1.6
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 1.18 * pulse, 3.5, Color(col, 0.9))
	# cracks: one jagged line per quarter of HP lost
	var cracks := int((1.0 - frac) * 4.0)
	for k in cracks:
		var a0 := rot[i] + k * 1.9 + 0.4
		var pts := PackedVector2Array([c + Vector2(cos(a0), sin(a0)) * r * 0.2])
		for step in 3:
			var rr := r * (0.4 + step * 0.25)
			var aj := a0 + (0.25 if step % 2 == 0 else -0.25)
			pts.append(c + Vector2(cos(aj), sin(aj)) * rr * pulse)
		draw_polyline(pts, Color(1, 1, 1, 0.55), 1.5)

	match id:
		"boss_tetra", "boss_final":
			if state == 1:
				var reach := TETRA_CHARGE_SPEED * TETRA_CHARGE_TIME if id == "boss_tetra" else POLY_CHARGE_SPEED * POLY_CHARGE_TIME
				var blink := 0.4 + 0.4 * sin(tmr[i] * 30.0)
				Shapes.draw_neon_line(self, c, c + Vector2(dx[i], dy[i]) * reach, Color(Balance.C_DANGER, blink), 3.0)
		"boss_prism":
			if state == 1 or state == 2:
				for k in bs.beams:
					var dir := Vector2.from_angle(bs.ang + TAU * k / bs.beams)
					var end := c + dir * PRISM_BEAM_LEN
					if state == 1:
						var blink := 0.3 + 0.3 * sin(tmr[i] * 30.0)
						draw_line(c, end, Color(Balance.C_DANGER, blink), 2.0)
					else:
						Shapes.draw_neon_line(self, c, end, Color(base_col, 0.9), PRISM_BEAM_WIDTH * 1.2)
						draw_line(c, end, Color(1, 1, 1, 0.8), 3.0)
			elif state == 3:
				var to: Vector2 = bs.target
				var k := 1.0 - clampf(tmr[i] / 0.8, 0.0, 1.0)
				Shapes.draw_neon_poly(self, Transform2D(-now * 3.0, to) * Shapes.points(8, r * (1.6 - k * 0.6)), Color(Balance.C_DANGER, 0.3 + k * 0.5), 2.0)
		"boss_void":
			# rings falling inward show the pull; much brighter during the event horizon
			var strength := 0.8 if state == 2 else (0.45 if state == 1 else 0.18)
			for k in 3:
				var f := fmod(now * (0.9 if state == 2 else 0.4) + k / 3.0, 1.0)
				Shapes.draw_neon_ring(self, c, r * (1.3 + (1.0 - f) * 3.2), Color(base_col, strength * f), 2.0, 48)
			draw_circle(c, r * 0.42, Color(0, 0, 0, 0.9))
