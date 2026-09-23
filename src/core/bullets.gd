class_name Bullets
extends Node2D
## Player projectiles: flat arrays + one batch per visual kind.

enum Kind { TRI, SHARD, RHOMBUS, FRACTAL, SPARK, ORB }

const KIND_RADIUS := [8.0, 5.0, 14.0, 10.0, 5.0, 16.0]

const F_SPLIT_KILL := 1   # VERTEX resonance: split into shards on kill
const F_FRACTAL := 2      # split into 3 on hit while depth > 0
const F_BOOMERANG := 4    # pulled back to the player; pierces everything
const F_CRIT := 8         # guaranteed crit
const F_CHILD_CRIT := 16  # fractal children are guaranteed crits
const F_RICOCHET := 32    # on hit, redirect to a new enemy while bounce > 0
const F_SCREEN := 64      # bounces off the screen edges; pierces everything
const F_GRIND := 128      # forgets its hits every 0.2s -> hits overlapping enemies repeatedly
const F_NOVA := 256       # grows while flying, explodes on first hit or at end of life
const F_VORTEX := 512     # homes, pulls enemies in, grinds, splits at end of life
const F_GEMS := 1024      # collects XP gems it passes

const PIERCE_ALL := F_BOOMERANG | F_SCREEN | F_GRIND | F_VORTEX
const HIT_MEM := 8        # remembered enemy uids per bullet

var game: Game
var batches: Array[ShapeBatch] = []
var kind_color: Array[Color] = [
	Color(0.35, 0.95, 1.0), Color(0.85, 0.9, 1.0), Color(0.45, 0.7, 1.0), Color(0.75, 0.85, 1.0),
	Color(1.0, 0.95, 0.55), Color(0.65, 0.6, 1.0)]

var n := 0
var x := PackedFloat32Array()
var y := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var life := PackedFloat32Array()
var age := PackedFloat32Array()
var dmg := PackedFloat32Array()
var rad := PackedFloat32Array()
var scl := PackedFloat32Array()
var knock := PackedFloat32Array()
var aux := PackedFloat32Array()     # per-behavior timer (grind reset, homing)
var pierce := PackedInt32Array()
var kind := PackedInt32Array()
var flags := PackedInt32Array()
var depth := PackedInt32Array()
var bounce := PackedInt32Array()
var src := PackedInt32Array()
var hits := PackedInt32Array()      # HIT_MEM uids per bullet (ring buffer)
var hit_pos := PackedInt32Array()

var sources: Array[String] = []
var _source_idx := {}
var _cap := 0


func setup(g: Game) -> void:
	game = g
	var rhombus := PackedVector2Array([Vector2(0, -16), Vector2(8, 0), Vector2(0, 16), Vector2(-8, 0)])
	var meshes: Array[Mesh] = [
		Shapes.poly_mesh(3, 9.0, 2.5, 5.0, 0.3),
		Shapes.poly_mesh(3, 5.5, 2.0, 4.0, 0.4),
		Shapes.outline_mesh(rhombus, 3.0, 6.0, 0.25),
		Shapes.poly_mesh(6, 11.0, 2.5, 6.0, 0.3),
		Shapes.poly_mesh(0, 4.0, 2.0, 5.0, 0.6),
		Shapes.poly_mesh(-7, 16.0, 2.5, 8.0, 0.35),
	]
	for m in meshes:
		var b := ShapeBatch.new().setup(m, 64)
		add_child(b)
		batches.append(b)
	_resize(256)


func _resize(c: int) -> void:
	_cap = c
	for arr in ["x", "y", "vx", "vy", "life", "age", "dmg", "rad", "scl", "knock", "aux", "pierce", "kind", "flags", "depth", "bounce", "src", "hit_pos"]:
		var a = get(arr)
		a.resize(c)
		set(arr, a)
	hits.resize(c * HIT_MEM)


func source_id(name: String) -> int:
	if not _source_idx.has(name):
		_source_idx[name] = sources.size()
		sources.append(name)
	return _source_idx[name]


func spawn(px: float, py: float, pvx: float, pvy: float, p_life: float, p_dmg: float, p_kind: int, source: int,
		p_pierce := 0, p_flags := 0, p_scale := 1.0, p_knock := 60.0) -> int:
	if n >= _cap:
		_resize(_cap * 2)
	var i := n
	n += 1
	x[i] = px
	y[i] = py
	vx[i] = pvx
	vy[i] = pvy
	life[i] = p_life
	age[i] = 0.0
	dmg[i] = p_dmg
	scl[i] = p_scale
	rad[i] = KIND_RADIUS[p_kind] * p_scale
	knock[i] = p_knock
	aux[i] = 0.0
	pierce[i] = p_pierce
	kind[i] = p_kind
	flags[i] = p_flags
	depth[i] = 0
	bounce[i] = 0
	src[i] = source
	clear_hits(i)
	return i


func clear_hits(i: int) -> void:
	var o := i * HIT_MEM
	for k in HIT_MEM:
		hits[o + k] = 0
	hit_pos[i] = 0


func _has_hit(i: int, u: int) -> bool:
	var o := i * HIT_MEM
	for k in HIT_MEM:
		if hits[o + k] == u:
			return true
	return false


func _add_hit(i: int, u: int) -> void:
	hits[i * HIT_MEM + hit_pos[i]] = u
	hit_pos[i] = (hit_pos[i] + 1) % HIT_MEM


func clear_all() -> void:
	n = 0


func update(delta: float) -> void:
	var en := game.enemies
	var ppos := game.player.position
	var half := game.view_size() * 0.5
	var i := 0
	while i < n:
		var remove := false
		var f := flags[i]
		age[i] += delta
		if f & F_BOOMERANG:
			# fly out, get pulled back to the player
			var tx := ppos.x - x[i]
			var ty := ppos.y - y[i]
			var td := sqrt(tx * tx + ty * ty) + 0.001
			var pull := life[i]  # for boomerangs, life holds the pull-back acceleration
			vx[i] += tx / td * pull * delta
			vy[i] += ty / td * pull * delta
			if age[i] > 0.3 and td < 26.0:
				if bounce[i] > 0:
					bounce[i] -= 1
					age[i] = 0.0
					clear_hits(i)
					vx[i] = -vx[i]
					vy[i] = -vy[i]
				else:
					remove = true
			if age[i] > 6.0:
				remove = true
		elif age[i] >= life[i]:
			remove = true
			if f & F_NOVA:
				_nova(i)
			elif f & F_VORTEX:
				_vortex_split(i)
		if f & F_SCREEN:
			if (x[i] < ppos.x - half.x and vx[i] < 0.0) or (x[i] > ppos.x + half.x and vx[i] > 0.0):
				vx[i] = -vx[i]
				clear_hits(i)
			if (y[i] < ppos.y - half.y and vy[i] < 0.0) or (y[i] > ppos.y + half.y and vy[i] > 0.0):
				vy[i] = -vy[i]
				clear_hits(i)
		if f & (F_GRIND | F_VORTEX):
			aux[i] -= delta
			if aux[i] <= 0.0:
				aux[i] = 0.2 if f & F_GRIND else 0.3
				clear_hits(i)
		if f & F_NOVA:
			var grow := 1.0 + age[i] * 0.9
			rad[i] = KIND_RADIUS[kind[i]] * scl[i] * grow
		if f & F_VORTEX and not remove:
			_vortex_pull(i, delta)
		if f & F_GEMS:
			game.gems.magnetize_near(x[i], y[i], rad[i] + 30.0)
		x[i] += vx[i] * delta
		y[i] += vy[i] * delta
		if not remove:
			var explode := false
			var c := en.query(x[i], y[i], rad[i])
			for q in c:
				var j := en.qbuf[q]
				var u := en.uid[j]
				if en.dead[j] or _has_hit(i, u):
					continue
				var d := dmg[i]
				var crit := (f & F_CRIT) != 0 or randf() < game.build.crit
				if crit:
					d *= Balance.CRIT_MULT
				var sp := sqrt(vx[i] * vx[i] + vy[i] * vy[i]) + 0.001
				en.hit(j, d, vx[i] / sp * knock[i], vy[i] / sp * knock[i], sources[src[i]])
				if crit:
					game.fx.crit_spark(x[i], y[i])
				_add_hit(i, u)
				var killed := en.dead[j] == 1
				if killed and (f & F_SPLIT_KILL):
					var a := atan2(vy[i], vx[i])
					for s in [-0.45, 0.45]:
						spawn(x[i], y[i], cos(a + s) * sp, sin(a + s) * sp, 0.45, dmg[i] * 0.5, Kind.SHARD, src[i], 0, 0, 1.0, 20.0)
				if f & F_NOVA:
					explode = true
					break
				if (f & F_FRACTAL) and not (f & F_VORTEX) and depth[i] > 0:
					_fractal_split(i)
					remove = true
					break
				if (f & F_RICOCHET) and bounce[i] > 0:
					if crit:
						bounce[i] = mini(bounce[i] + 1, 10)
					bounce[i] -= 1
					var skip := PackedInt32Array([u])
					var t := en.nearest_to(x[i], y[i], 280.0, skip)  # reuses qbuf: must break after
					if t >= 0:
						var dir := Vector2(en.px[t] - x[i], en.py[t] - y[i]).normalized()
						vx[i] = dir.x * sp
						vy[i] = dir.y * sp
						age[i] = 0.0
						break
				if f & PIERCE_ALL:
					continue
				if pierce[i] > 0:
					pierce[i] -= 1
				else:
					remove = true
					break
			if explode:
				_nova(i)
				remove = true
		if remove:
			_remove(i)
		else:
			i += 1


func _fractal_split(i: int) -> void:
	var a := atan2(vy[i], vx[i])
	var sp := sqrt(vx[i] * vx[i] + vy[i] * vy[i])
	var child_flags := flags[i]
	if child_flags & F_CHILD_CRIT:
		child_flags |= F_CRIT
	for s in [-0.6, 0.0, 0.6]:
		var c := spawn(x[i], y[i], cos(a + s) * sp, sin(a + s) * sp, life[i] * 0.6, dmg[i] * 0.6, Kind.FRACTAL, src[i],
				0, child_flags, scl[i] * 0.72, knock[i] * 0.5)
		depth[c] = depth[i] - 1
		for k in HIT_MEM:
			hits[c * HIT_MEM + k] = hits[i * HIT_MEM + k]
	game.fx.ring(x[i], y[i], 18.0 * scl[i], Color(0.75, 0.85, 1.0), 0.18)


## Supernova: blast around the bullet, then scatter fragments.
func _nova(i: int) -> void:
	var en := game.enemies
	var r := rad[i] * 5.0
	var c := en.query(x[i], y[i], r)
	var targets := en.qbuf.slice(0, c)
	for j in targets:
		var dir := Vector2(en.px[j] - x[i], en.py[j] - y[i]).normalized()
		var crit := randf() < game.build.crit
		en.hit(j, dmg[i] * 2.2 * (Balance.CRIT_MULT if crit else 1.0), dir.x * 180.0, dir.y * 180.0, sources[src[i]])
	game.fx.ring(x[i], y[i], r, Color(0.8, 0.9, 1.0), 0.35, 5.0)
	game.fx.burst(x[i], y[i], Color(0.8, 0.9, 1.0), 10, 20.0)
	var off := randf() * TAU
	var px := x[i]
	var py := y[i]
	var d := dmg[i] * 0.4
	var s := src[i]
	for k in 8:
		var a := off + TAU * k / 8.0
		spawn(px, py, cos(a) * 380.0, sin(a) * 380.0, 0.5, d, Kind.FRACTAL, s, 0, 0, 0.6, 30.0)
	Sfx.play("boom")


## Attractor: steer toward the nearest enemy and drag nearby enemies inward.
func _vortex_pull(i: int, delta: float) -> void:
	var en := game.enemies
	var sp := sqrt(vx[i] * vx[i] + vy[i] * vy[i])
	var t := en.nearest_to(x[i], y[i], 320.0, PackedInt32Array())
	if t >= 0:
		var dir := Vector2(en.px[t] - x[i], en.py[t] - y[i]).normalized()
		var v := Vector2(vx[i], vy[i]).lerp(dir * sp, minf(1.0, delta * 2.5))
		vx[i] = v.x
		vy[i] = v.y
	var r := 150.0 * scl[i]
	var c := en.query(x[i], y[i], r)
	for q in c:
		var j := en.qbuf[q]
		if en.is_boss(j):
			continue
		var ox := x[i] - en.px[j]
		var oy := y[i] - en.py[j]
		var d := sqrt(ox * ox + oy * oy) + 0.001
		var pull := 900.0 * delta / en.t_mass[en.typ[j]]
		en.kx[j] += ox / d * pull
		en.ky[j] += oy / d * pull


func _vortex_split(i: int) -> void:
	var off := randf() * TAU
	var count := 3 + depth[i]
	var child := F_FRACTAL | (flags[i] & (F_SPLIT_KILL | F_CHILD_CRIT))
	for k in count:
		var a := off + TAU * k / count
		var c := spawn(x[i], y[i], cos(a) * 340.0, sin(a) * 340.0, 0.9, dmg[i] * 0.8, Kind.FRACTAL, src[i], 0, child, 0.8, 40.0)
		depth[c] = maxi(depth[i] - 1, 0)
	game.fx.ring(x[i], y[i], 60.0, kind_color[Kind.ORB], 0.3)


func _remove(i: int) -> void:
	n -= 1
	if i == n:
		return
	x[i] = x[n]
	y[i] = y[n]
	vx[i] = vx[n]
	vy[i] = vy[n]
	life[i] = life[n]
	age[i] = age[n]
	dmg[i] = dmg[n]
	rad[i] = rad[n]
	scl[i] = scl[n]
	knock[i] = knock[n]
	aux[i] = aux[n]
	pierce[i] = pierce[n]
	kind[i] = kind[n]
	flags[i] = flags[n]
	depth[i] = depth[n]
	bounce[i] = bounce[n]
	src[i] = src[n]
	hit_pos[i] = hit_pos[n]
	for k in HIT_MEM:
		hits[i * HIT_MEM + k] = hits[n * HIT_MEM + k]


func render() -> void:
	for b in batches:
		b.begin()
	for i in n:
		var k := kind[i]
		var r: float
		var s := scl[i]
		if k == Kind.RHOMBUS or k == Kind.ORB:
			r = age[i] * (14.0 if k == Kind.RHOMBUS else -4.0)
		else:
			r = atan2(vy[i], vx[i]) + PI / 2.0
		if flags[i] & F_NOVA:
			s = rad[i] / KIND_RADIUS[k]
		batches[k].add(x[i], y[i], r, s, kind_color[k])
	for b in batches:
		b.commit()
