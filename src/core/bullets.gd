class_name Bullets
extends Node2D
## Player projectiles: flat arrays + one batch per visual kind.

enum Kind { TRI, SHARD }

const KIND_RADIUS := [8.0, 5.0]

const F_REDIRECT := 1     # Focus Fire: after a hit, turn toward another enemy while pierce is left
const F_CRIT_PIERCE := 2  # Deadeye: a crit doesn't use up pierce
const REDIRECT_RANGE := 280.0

const HIT_MEM := 8        # remembered enemy uids per bullet

var game: Game
var batches: Array[ShapeBatch] = []
var kind_color: Array[Color] = []

var n := 0
var x := PackedFloat32Array()
var y := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var life := PackedFloat32Array()
var age := PackedFloat32Array()
var dmg := PackedFloat32Array()     # weapon damage when fired; the hit is rolled on impact
var kf := PackedFloat32Array()      # sub-hit factor k
var rad := PackedFloat32Array()
var scl := PackedFloat32Array()
var knock := PackedFloat32Array()
var pierce := PackedInt32Array()
var kind := PackedInt32Array()
var flags := PackedInt32Array()
var src := PackedInt32Array()
var hits := PackedInt32Array()      # HIT_MEM uids per bullet (ring buffer)
var hit_pos := PackedInt32Array()

var sources: Array[String] = []
var _source_idx := {}
var _cap := 0


func setup(g: Game) -> void:
	game = g
	kind_color = [Balance.C_WEAPON, Balance.C_WEAPON.lerp(Color.WHITE, 0.5)]
	var meshes: Array[Mesh] = [
		Shapes.poly_mesh(3, 9.0, 2.5, 5.0, 0.3),
		Shapes.poly_mesh(3, 5.5, 2.0, 4.0, 0.4),
	]
	for m in meshes:
		var b := ShapeBatch.new().setup(m, 64)
		add_child(b)
		batches.append(b)
	_resize(256)


func _resize(c: int) -> void:
	_cap = c
	for arr in ["x", "y", "vx", "vy", "life", "age", "dmg", "kf", "rad", "scl", "knock", "pierce", "kind", "flags", "src", "hit_pos"]:
		var a = get(arr)
		a.resize(c)
		set(arr, a)
	hits.resize(c * HIT_MEM)


func source_id(name: String) -> int:
	if not _source_idx.has(name):
		_source_idx[name] = sources.size()
		sources.append(name)
	return _source_idx[name]


## `p_dmg` is weapon damage and `p_k` its sub-hit factor: Build.roll_hit turns them into a hit on impact.
func spawn(px: float, py: float, pvx: float, pvy: float, p_life: float, p_dmg: float, p_kind: int, source: int,
		p_pierce := 0, p_flags := 0, p_scale := 1.0, p_knock := 60.0, p_k := 1.0) -> int:
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
	kf[i] = p_k
	scl[i] = p_scale
	rad[i] = KIND_RADIUS[p_kind] * p_scale
	knock[i] = p_knock
	pierce[i] = p_pierce
	kind[i] = p_kind
	flags[i] = p_flags
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
	var build := game.build
	var i := 0
	while i < n:
		age[i] += delta
		var remove := age[i] >= life[i]
		var step_x := vx[i] * delta
		var step_y := vy[i] * delta
		x[i] += step_x
		y[i] += step_y
		if not remove:
			# fast bullets would tunnel through small enemies: test a circle around the whole step instead
			var step := sqrt(step_x * step_x + step_y * step_y)
			var c: int
			if step > rad[i] + 7.0:
				c = en.query(x[i] - step_x * 0.5, y[i] - step_y * 0.5, rad[i] + step * 0.5)
			else:
				c = en.query(x[i], y[i], rad[i])
			for q in c:
				var j := en.qbuf[q]
				var u := en.uid[j]
				if en.dead[j] or _has_hit(i, u):
					continue
				var sp := sqrt(vx[i] * vx[i] + vy[i] * vy[i]) + 0.001
				var crit := build.strike(j, dmg[i], kf[i], vx[i] / sp * knock[i], vy[i] / sp * knock[i], sources[src[i]])
				if crit:
					game.fx.crit_spark(x[i], y[i])
				_add_hit(i, u)
				if crit and (flags[i] & F_CRIT_PIERCE):
					continue
				if pierce[i] <= 0:
					remove = true
					break
				pierce[i] -= 1
				if flags[i] & F_REDIRECT:
					# only the enemy just hit is off limits, so a shot can go back and forth between two
					clear_hits(i)
					_add_hit(i, u)
					var t := en.nearest_to(x[i], y[i], REDIRECT_RANGE, PackedInt32Array([u]))  # reuses qbuf: must break after
					if t >= 0:
						var dir := Vector2(en.px[t] - x[i], en.py[t] - y[i]).normalized()
						vx[i] = dir.x * sp
						vy[i] = dir.y * sp
						age[i] = 0.0
					break
		if remove:
			_remove(i)
		else:
			i += 1


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
	kf[i] = kf[n]
	rad[i] = rad[n]
	scl[i] = scl[n]
	knock[i] = knock[n]
	pierce[i] = pierce[n]
	kind[i] = kind[n]
	flags[i] = flags[n]
	src[i] = src[n]
	hit_pos[i] = hit_pos[n]
	for k in HIT_MEM:
		hits[i * HIT_MEM + k] = hits[n * HIT_MEM + k]


func render() -> void:
	for b in batches:
		b.begin()
	for i in n:
		var k := kind[i]
		batches[k].add(x[i], y[i], atan2(vy[i], vx[i]) + PI / 2.0, scl[i], kind_color[k])
	for b in batches:
		b.commit()
